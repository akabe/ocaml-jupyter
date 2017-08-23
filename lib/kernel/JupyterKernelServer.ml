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

(** Kernel server *)

open Format
open Lwt.Infix

module Log = JupyterKernelLog
module M = JupyterKernelMessage
module ShC = Jupyter.ShellMessage
module IoC = Jupyter.IopubMessage

module Make
    (ShellChannel : JupyterKernelChannelIntf.Shell)
    (IopubChannel : JupyterKernelChannelIntf.Iopub)
    (StdinChannel : JupyterKernelChannelIntf.Stdin)
    (Repl : module type of JupyterRepl.Process) =
struct
  type t =
    {
      merlin : JupyterKernelMerlin.t;
      repl : Repl.t;
      shell : ShellChannel.t;
      control : ShellChannel.t;
      iopub : IopubChannel.t;
      stdin : StdinChannel.t;
      code : Buffer.t; (* code that have been executed ever *)

      mutable execution_count : int;
      mutable current_parent : ShellChannel.input option;
    }

  let create ~merlin ~repl ~ctx info =
    let key = info.JupyterKernelConnectionInfo.key in
    let shell =
      JupyterKernelConnectionInfo.(make_address info info.shell_port)
      |> ShellChannel.create ?key ~ctx ~kind:ZMQ.Socket.router
    in
    let control =
      JupyterKernelConnectionInfo.(make_address info info.control_port)
      |> ShellChannel.create ?key ~ctx ~kind:ZMQ.Socket.router
    in
    let iopub =
      JupyterKernelConnectionInfo.(make_address info info.iopub_port)
      |> IopubChannel.create ?key ~ctx ~kind:ZMQ.Socket.pub
    in
    let stdin =
      JupyterKernelConnectionInfo.(make_address info info.stdin_port)
      |> StdinChannel.create ?key ~ctx ~kind:ZMQ.Socket.router
    in
    {
      merlin; repl; shell; control; iopub; stdin;
      execution_count = 0;
      current_parent = None;
      code = Buffer.create 256;
    }

  let close server =
    Lwt.join [
      Repl.close server.repl;
      ShellChannel.close server.shell;
      ShellChannel.close server.control;
      IopubChannel.close server.iopub;
      StdinChannel.close server.stdin;
    ]

  (** {2 IOPUB utility} *)

  let send_iopub server content =
    match server.current_parent with
    | Some parent -> IopubChannel.reply server.iopub ~parent content
    | None -> Lwt.return ()

  let send_iopub_stream server ~name text =
    send_iopub server IoC.(`Stream { name; text; })

  let send_iopub_status server execution_state =
    send_iopub server IoC.(`Status { execution_state; })

  let send_iopub_exec_input server code =
    let execution_count = server.execution_count in
    send_iopub server IoC.(`Execute_input { code; execution_count; })

  let send_iopub_exec_success server msg =
    send_iopub server IoC.(`Execute_result {
        execution_count = server.execution_count;
        data = `Assoc ["text/plain", `String msg];
        metadata = `Assoc [];
      })

  let send_iopub_exec_error server msg =
    send_iopub server IoC.(`Execute_error {
        ename = "error";
        evalue = "error";
        traceback = [sprintf "\x1b[31m%s\x1b[0m" msg];
      })

  (** {2 Execute request} *)

  let execute_request ~parent server (body : ShC.execute_request) =
    server.execution_count <- succ server.execution_count ;
    server.current_parent <- Some parent ;
    let code = body.ShC.code in
    let%lwt () = send_iopub_status server `Busy in
    let%lwt () = send_iopub_exec_input server code in
    let filename = sprintf "[%d]" server.execution_count in
    Repl.run ~ctx:parent ~filename server.repl code

  (** {2 Kernel info request} *)

  let kernel_info_request ~parent shell =
    ShC.(`Kernel_info_reply kernel_info_reply)
    |> ShellChannel.reply shell ~parent

  (** {2 Shutdown request} *)

  let shutdown_request ~parent shell body =
    ShC.(`Shutdown_reply body)
    |> ShellChannel.reply shell ~parent

  (** {2 Complete request} *)

  let string_of_complete_entry entry = entry.JupyterKernelMerlin.name

  let hint_of_complete_entry entry =
    let left = match entry.JupyterKernelMerlin.kind with
      | `Value -> "V"
      | `Variant -> "C"
      | `Constructor -> "C"
      | `Label -> "V"
      | `Module -> "M"
      | `Sig -> "S"
      | `Type -> "T"
      | `Method -> "M"
      | `Method_call -> "#"
      | `Exn -> "E"
      | `Class -> "C" in
    let right = entry.JupyterKernelMerlin.desc in
    let hint = `Assoc [
        "hint_left", `String left;
        "hint_right", `String right;
      ] in
    (entry.JupyterKernelMerlin.name, hint)

  let complete_request ~parent server shell body =
    let open JupyterKernelMerlin in
    let context = Buffer.contents server.code in
    let code = body.ShC.code in
    let cursor_pos = body.ShC.cursor_pos in
    let%lwt result = complete ~context server.merlin code cursor_pos in
    let reply = match result with
      | Result.Ok { entries = []; _ } -> (* no candidates *)
        ShC.{
          status = `Ok; metadata = `Assoc [];
          matches = []; cursor_start = None; cursor_end = None;
        }
      | Result.Ok { entries; cursor_start; cursor_end; } -> (* non-empty candidates *)
        let matches = List.map string_of_complete_entry entries in
        let metadata : Yojson.Safe.json = `Assoc (List.map hint_of_complete_entry entries) in
        ShC.{
          status = `Ok; matches; metadata;
          cursor_start = Some cursor_start;
          cursor_end = Some cursor_end;
        }
      | Result.Error j -> (* merlin returns an error *)
        Log.info "Merlin Error: %s" (Yojson.Safe.to_string j) ;
        ShC.{
          status = `Error; metadata = `Assoc [];
          matches = []; cursor_start = None; cursor_end = None;
        }
    in
    ShellChannel.reply shell ~parent (`Complete_reply reply)

  (** {2 Main routine} *)

  let append_code server = function
    | None -> ()
    | Some code ->
      Buffer.add_string server.code code ;
      Buffer.add_string server.code " ;; "

  let send_execute_reply server status =
    let%lwt () = send_iopub_status server `Idle in
    match server.current_parent with
    | None -> Lwt.return_unit
    | Some parent ->
      ShC.(`Execute_reply {
          execution_count = server.execution_count;
          status;
        })
      |> ShellChannel.reply server.shell ~parent

  (** a thread capturing stdout and stderr from a REPL. *)
  let propagate_repl_to_iopub server =
    let strm = Repl.stream server.repl in
    let rec loop status =
      match%lwt Lwt_stream.get strm with
      | None -> Lwt.return_unit (* done *)
      | Some (`Shell msg) -> (* propagate an SHELL message to Jupyter *)
        let%lwt () = ShellChannel.send server.shell msg in
        loop status
      | Some (`Iopub msg) -> (* propagate an IOPUB message to Jupyter *)
        let%lwt () = IopubChannel.send server.iopub msg in
        loop status
      | Some (`Stdin msg) -> (* propagate an STDIN message to Jupyter *)
        let%lwt () = StdinChannel.send server.stdin msg in
        loop status
      | Some (`Stdout s) ->
        let%lwt () = send_iopub_stream server ~name:`Stdout s in
        loop status
      | Some (`Stderr s) ->
        let%lwt () = send_iopub_stream server ~name:`Stderr s in
        loop status
      | Some (`Ok s) ->
        let%lwt () = send_iopub_exec_success server s in
        loop status
      | Some (`Runtime_error s) | Some (`Compile_error s) ->
        let%lwt () = send_iopub_exec_error server s in
        loop `Error
      | Some `Aborted ->
        let%lwt () = send_iopub_exec_error server "Interrupted." in
        loop `Abort
      | Some (`Prompt code_opt) ->
        let%lwt () = send_execute_reply server status in
        append_code server code_opt ;
        loop `Ok (* Reset the current status to OK *)
    in
    loop `Ok

  let propagate_stdin server =
    let rec loop () =
      StdinChannel.recv server.stdin >>= fun req ->
      Repl.send server.repl (`Stdin req) >>= loop
    in
    loop ()

  let start_kernel server shell =
    let rec reply parent = function
      | `Shutdown_request body -> shutdown_request ~parent shell body
      | `Kernel_info_request -> kernel_info_request ~parent shell >>= loop
      | `Execute_request body -> execute_request ~parent server body >>= loop
      | `Comm_open _ | `Comm_msg _ | `Comm_close _ | `Comm_info_request _ ->
        Repl.send server.repl (`Shell parent) >>= loop (* propagete to REPL *)
      | `Complete_request body -> complete_request ~parent server shell body >>= loop
      | `Inspect_request _
      | `Connect_request -> (* Deprecated since v5.1 *)
        Log.error "Unsupported request" ;
        loop ()
    and loop () =
      ShellChannel.recv shell >>= fun req -> reply req req.M.content
    in
    loop ()

  let start server =
    Lwt.pick [
      propagate_repl_to_iopub server;
      propagate_stdin server;
      start_kernel server server.shell;
      start_kernel server server.control;
    ]
end
