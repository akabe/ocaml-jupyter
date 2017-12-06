(* ocaml-jupyter --- An OCaml kernel for Jupyter

   Copyright (c) 2017 Akinori ABE

   Permission is hereby granted, free of charge, to any person obtaining a copy
   of this software and associated documentation files (the "Software"), to deal
   in the Software without restriction, including without limitation the rights
   to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
   copies of the Software, and to permit persons to whom the Software is
   furnished to do so, subject to the following conditions:

   The above copyright notice and this permission notice shall be included in all
   copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
   SOFTWARE. *)

(** OCaml REPL process *)

open Format
open Lwt.Infix
open Jupyter
open Jupyter_log

type request =
  | REPL_QUIT
  | REPL_CODE of Shell.request Message.t * int * string

let flags = [] (* marshal flags *)

(** {2 Child process} *)

let define_connection ~jupyterin ~jupyterout ~context =
  (* Unsafe definition of channels in REPL *)
  Evaluation.setvalue "$jupyterin" (Unix.in_channel_of_descr jupyterin) ;
  Evaluation.setvalue "$jupyterout" (Unix.out_channel_of_descr jupyterout) ;
  Evaluation.setvalue "$jupyterctx" context

let override_sys_params () =
  (* [Sys.interactive] should be [true] for preventing from loading
     ocamltoplevel.cma inside the OCaml toploop (Issue#78).
     See https://github.com/ocaml/ocaml/blob/4.05.0/toplevel/toploop.ml#L467-L469 *)
  Evaluation.eval ~count:0 ~send:ignore "Sys.interactive := true"
  |> ignore

let create_child_process
    ?preload ?init_file ?error_ctx_size
    ~ctrlin ~ctrlout ~jupyterin
  =
  let context = ref None in
  let preinit () =
    define_connection ~jupyterin ~jupyterout:ctrlout ~context ;
    override_sys_params ()
  in
  Evaluation.init ?preload ~preinit ?init_file () ;
  let ctrlin = Unix.in_channel_of_descr ctrlin in
  let ctrlout = Unix.out_channel_of_descr ctrlout in
  let send (reply : Message.reply) =
    Marshal.to_channel ctrlout reply flags ;
    flush ctrlout
  in
  let send_shell ~ctx reply = send Message.(SHELL_REP (create_next_shell ctx reply)) in
  let send_iopub ~ctx reply = send Message.(IOPUB_REP (create_next_iopub ctx reply)) in
  let rec main_loop prev =
    try
      match Marshal.from_channel ctrlin with
      | exception End_of_file -> exit 0 (* control channel is closed. *)
      | REPL_QUIT -> exit 0 (* control channel is closed. *)
      | REPL_CODE (ctx', count, code) ->
        context := Some ctx' ;
        Evaluation.eval ?error_ctx_size ~count ~send:(send_iopub ~ctx:ctx') code
        |> Shell.execute_reply ~count
        |> send_shell ~ctx:ctx' ;
        main_loop (Some (ctx', count))
    with
    | Sys.Break ->
      match prev with
      | None -> main_loop None
      | Some (ctx, count) ->
        let handler' = Sys.(signal sigint (Signal_handle (fun _ -> ()))) in
        send_iopub ~ctx (Evaluation.iopub_interrupt ()) ;
        send_shell ~ctx Shell.(execute_reply ~count SHELL_ABORT) ;
        ignore Sys.(signal sigint handler') ;
        main_loop prev
  in
  main_loop None

(** {2 Parent process} *)

type t =
  {
    pid : int;
    thread : unit Lwt.t; (** receiver thread *)
    stream : Message.reply Lwt_stream.t; (** asynchronous replies from a REPL process *)
    push : Message.reply option -> unit; (** send a reply to a parent. close a stream in a parent. *)
    jupyterin : Lwt_io.output Lwt_io.channel; (** send Shell/Iopub replies to a child *)
    ctrlin : Lwt_io.output Lwt_io.channel; (** send execution requests to a a child *)
    ctrlout : Lwt_io.input Lwt_io.channel; (** receive Shell/Iopub requests from a parent *)
    stdout : Lwt_io.input Lwt_io.channel; (** STDOUT from a child *)
    stderr : Lwt_io.input Lwt_io.channel; (** STDERR from a child *)
    context : Shell.request Message.t option ref;
    exec_status : Shell.status Lwt_mvar.t;
  }

let forever f =
  let rec loop () = f () >>= loop in
  loop ()

let recv_ctrl_thread ~push ~mvar ic =
  let open Jupyter.Message in
  let open Jupyter.Shell in
  forever (fun () ->
      Lwt_io.read_value ic >>= fun (reply : Message.reply) ->
      push (Some reply) ;
      match reply with
      | SHELL_REP { content = SHELL_EXEC_REP ep; _ } ->
        Lwt_mvar.put mvar ep.Shell.exec_status
      | _ -> Lwt.return_unit)

let recv_stdout_thread ~push ~ctx ~name ic =
  forever (fun () ->
      Lwt_io.read_line ic >|= fun line ->
      match !ctx with
      | Some ctx ->
        let iopub = Iopub.stream ~name (line ^ "\n") in
        let msg = Message.create_next_iopub ctx iopub in
        push (Some (Message.IOPUB_REP msg))
      | None ->
        match name with
        | Iopub.IOPUB_STDOUT -> notice "STDOUT>> %s" line
        | Iopub.IOPUB_STDERR -> notice "STDERR>> %s" line)

let create ?preload ?init_file ?error_ctx_size () =
  let c_jupyterin, p_jupyterin = Unix.pipe () in
  let c_ctrlin, p_ctrlin = Unix.pipe () in
  let p_ctrlout, c_ctrlout = Unix.pipe () in
  let p_stdout, c_stdout = Unix.pipe () in
  let p_stderr, c_stderr = Unix.pipe () in
  match Unix.fork () with
  | 0 ->
    Unix.close p_jupyterin ;
    Unix.close p_ctrlin ;
    Unix.close p_ctrlout ;
    Unix.close p_stdout ;
    Unix.close p_stderr ;
    Unix.dup2 c_stdout Unix.stdout ;
    Unix.dup2 c_stderr Unix.stderr ;
    Unix.close c_stdout ;
    Unix.close c_stderr ;
    create_child_process
      ?preload ?init_file ?error_ctx_size
      ~ctrlin:c_ctrlin ~ctrlout:c_ctrlout ~jupyterin:c_jupyterin
  | pid ->
    Unix.close c_jupyterin ;
    Unix.close c_ctrlin ;
    Unix.close c_ctrlout ;
    Unix.close c_stdout ;
    Unix.close c_stderr ;
    let (stream, push) = Lwt_stream.create () in
    let ctrlout = Lwt_io.(of_unix_fd ~mode:input p_ctrlout) in
    let stdout = Lwt_io.(of_unix_fd ~mode:input p_stdout) in
    let stderr = Lwt_io.(of_unix_fd ~mode:input p_stderr) in
    let ctx = ref None in
    let exec_status = Lwt_mvar.create_empty () in
    {
      pid; stream; push; ctrlout; stdout; stderr;
      jupyterin = Lwt_io.(of_unix_fd ~mode:output p_jupyterin);
      ctrlin = Lwt_io.(of_unix_fd ~mode:output p_ctrlin);
      context = ctx;
      exec_status;
      thread = Lwt.join [
          recv_ctrl_thread ~push ~mvar:exec_status ctrlout;
          recv_stdout_thread ~push ~ctx ~name:Iopub.IOPUB_STDOUT stdout;
          recv_stdout_thread ~push ~ctx ~name:Iopub.IOPUB_STDERR stderr;
        ];
    }

let send_command repl (request : request) =
  let%lwt () = Lwt_io.write_value repl.ctrlin request ~flags in
  Lwt_io.flush repl.ctrlin

let close repl =
  let%lwt () = send_command repl REPL_QUIT in (* Send shutdown request *)
  let%lwt (_, proc_status) = Lwt_unix.(waitpid [WUNTRACED] repl.pid) in
  Lwt.cancel repl.thread ;
  let%lwt () = Lwt.join [
      Lwt_io.close repl.jupyterin;
      Lwt_io.close repl.ctrlin;
      Lwt_io.close repl.ctrlout;
      Lwt_io.close repl.stdout;
      Lwt_io.close repl.stderr;
    ] in
  repl.push None ; (* close a stream *)
  match proc_status with
  | Unix.WEXITED 0 -> Lwt.return_unit (* success *)
  | Unix.WEXITED i -> failwith (sprintf "Exited status %d" i)
  | Unix.WSIGNALED i -> failwith (sprintf "Killed by signal %d" i)
  | Unix.WSTOPPED i -> failwith (sprintf "Stopped by signal %d" i)

let heartbeat repl =
  let open Unix in
  match waitpid [WNOHANG; WUNTRACED] repl.pid with
  | 0, _ -> debug "REPL is healthy"
  | _, WEXITED i -> failwith (sprintf "Exited status %d" i)
  | _, WSIGNALED i -> failwith (sprintf "Killed by signal %d" i)
  | _, WSTOPPED i -> failwith (sprintf "Stopped by signal %d" i)

let interrupt repl =
  heartbeat repl ;
  Unix.kill repl.pid Sys.sigint

let stream repl = repl.stream

let eval ~ctx ~count repl code =
  heartbeat repl ;
  repl.context := Some ctx ;
  let%lwt () = send_command repl (REPL_CODE (ctx, count, code)) in
  Lwt_mvar.take repl.exec_status

let send repl (request : Message.request) =
  heartbeat repl ;
  let%lwt () = Lwt_io.write_value ~flags repl.jupyterin request in
  Lwt_io.flush repl.jupyterin
