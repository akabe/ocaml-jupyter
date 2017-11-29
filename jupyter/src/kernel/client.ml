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

(** Kernel client *)

open Format
open Lwt.Infix
open Jupyter
open Jupyter.Message
open Jupyter.Iopub
open Jupyter.Shell
open Jupyter_repl
open Jupyter_log

module Make
    (ShellChannel : Channel_intf.Shell)
    (IopubChannel : Channel_intf.Iopub)
    (StdinChannel : Channel_intf.Stdin)
    (HeartbeatChannel : Channel_intf.Zmq)
    (Repl : module type of Jupyter_repl.Process)
    (Completor : Jupyter_completor.Intf.S) =
struct
  type t =
    {
      completor : Completor.t;
      repl : Repl.t;
      shell : ShellChannel.t;
      control : ShellChannel.t;
      iopub : IopubChannel.t;
      stdin : StdinChannel.t;
      heartbeat : HeartbeatChannel.t;

      mutable execution_count : int;
      mutable current_parent : ShellChannel.input option;
    }

  let create ~completor ~repl ~ctx info =
    let key = info.Connection_info.key in
    let shell =
      Connection_info.(make_address info info.shell_port)
      |> ShellChannel.create ?key ~ctx ~kind:ZMQ.Socket.router
    in
    let control =
      Connection_info.(make_address info info.control_port)
      |> ShellChannel.create ?key ~ctx ~kind:ZMQ.Socket.router
    in
    let iopub =
      Connection_info.(make_address info info.iopub_port)
      |> IopubChannel.create ?key ~ctx ~kind:ZMQ.Socket.pub
    in
    let stdin =
      Connection_info.(make_address info info.stdin_port)
      |> StdinChannel.create ?key ~ctx ~kind:ZMQ.Socket.router
    in
    let heartbeat =
      Connection_info.(make_address info info.hb_port)
      |> HeartbeatChannel.create ~ctx ~kind:ZMQ.Socket.rep
    in
    {
      completor; repl; shell; control; iopub; stdin; heartbeat;
      execution_count = 0;
      current_parent = None;
    }

  let close client =
    Lwt.join [
      Repl.close client.repl;
      ShellChannel.close client.shell;
      ShellChannel.close client.control;
      IopubChannel.close client.iopub;
      StdinChannel.close client.stdin;
      HeartbeatChannel.close client.heartbeat;
    ]

  (** {2 Heatbeat} *)

  let heartbeat client =
    let rec loop () =
      let%lwt data = HeartbeatChannel.recv client.heartbeat in
      Repl.heartbeat client.repl ;
      let%lwt () = HeartbeatChannel.send client.heartbeat data in
      loop ()
    in
    loop ()

  (** {2 IOPUB utility} *)

  let send_iopub ?parent client content =
    match parent, client.current_parent with
    | Some parent, _
    | None, Some parent -> IopubChannel.reply client.iopub ~parent content
    | None, None -> Lwt.return ()

  let send_iopub_status ?parent client kernel_state =
    send_iopub ?parent client (IOPUB_STATUS { kernel_state })

  let send_iopub_exec_input client code =
    send_iopub client (IOPUB_EXECUTE_INPUT {
        exin_code = code;
        exin_count = client.execution_count;
      })

  (** {2 Request handling} *)

  let handle_kernel_info_request ~parent client shell =
    let%lwt () = send_iopub_status ~parent client IOPUB_BUSY in
    let%lwt () =
      SHELL_KERNEL_INFO_REP Shell.kernel_info_reply
      |> ShellChannel.reply shell ~parent in
    send_iopub_status ~parent client IOPUB_IDLE

  let handle_shutdown_request ~parent shell body =
    SHELL_SHUTDOWN_REP body
    |> ShellChannel.reply shell ~parent

  let handle_execute_request ~parent client body =
    client.execution_count <- succ client.execution_count ;
    client.current_parent <- Some parent ;
    let count = client.execution_count in
    let code = body.exec_code in
    let%lwt () = send_iopub_status client IOPUB_BUSY in
    let%lwt () = send_iopub_exec_input client code in
    let%lwt () =
      Repl.eval ~ctx:parent ~count client.repl code >|= function
      | SHELL_OK -> Completor.add_context client.completor code
      | _ -> () in
    send_iopub_status ~parent client IOPUB_IDLE

  let handle_complete_request ~parent client shell body =
    let%lwt raw_reply =
      Completor.complete
        client.completor body.cmpl_code ~pos:body.cmpl_pos in
    let shell_reply =
      match raw_reply with
      | { Completor.cmpl_candidates = []; _ } -> (* No candidates *)
        {
          cmpl_status = SHELL_OK;
          cmpl_metadata = `Assoc [];
          cmpl_start = None;
          cmpl_end = None;
          cmpl_matches = [];
        }
      | { Completor.cmpl_candidates = cands;
          Completor.cmpl_start; Completor.cmpl_end; } ->
        {
          cmpl_status = SHELL_OK;
          cmpl_metadata = `Assoc [];
          cmpl_start = Some cmpl_start;
          cmpl_end = Some cmpl_end;
          cmpl_matches = List.map (fun c -> c.Completor.cmpl_name) cands;
        }
    in
    ShellChannel.reply shell ~parent (SHELL_COMPLETE_REP shell_reply)

  (** [is_complete code] checks whether OCaml program [code] can be immediately
      evaluated, or not. The check is sometimes wrong due to simpleness, e.g.,
      [is_complete "let x = \" ;;"] is [true] while it causes syntax error. *)
  let is_complete =
    let is_cmpl = Str.regexp ";;[ \t]*$" in
    fun code ->
      try ignore (Str.search_forward is_cmpl code 0) ; true
      with Not_found -> false

  let handle_is_complete_request ~parent shell req =
    let status, indent =
      if is_complete req.is_cmpl_code
      then ("complete", None) else ("incomplete", Some "")
    in
    SHELL_IS_COMPLETE_REP { is_cmpl_status = status; is_cmpl_indent = indent; }
    |> ShellChannel.reply shell ~parent

  let handle_history_request ~parent shell =
    SHELL_HISTORY_REP { history = [] } (* Returns an empty response *)
    |> ShellChannel.reply shell ~parent

  (** {2 Main routine} *)

  (** a thread capturing stdout and stderr from a REPL. *)
  let propagate_repl client =
    let strm = Repl.stream client.repl in
    let rec loop () =
      match%lwt Lwt_stream.get strm with
      | None -> Lwt.return_unit (* done *)
      | Some (Message.SHELL_REP reply) -> (* propagate an SHELL message to Jupyter *)
        let%lwt () = ShellChannel.send client.shell reply in
        loop ()
      | Some (Message.IOPUB_REP reply) -> (* propagate an IOPUB message to Jupyter *)
        let%lwt () = IopubChannel.send client.iopub reply in
        loop ()
      | Some (Message.STDIN_REP reply) -> (* propagate an STDIN message to Jupyter *)
        let%lwt () = StdinChannel.send client.stdin reply in
        loop ()
    in
    loop ()

  let propagate_stdin client =
    let rec loop () =
      let%lwt req = StdinChannel.recv client.stdin in
      let%lwt () = Repl.send client.repl (STDIN_REQ req) in
      loop ()
    in
    loop ()

  let start_kernel client shell =
    let rec reply parent = match parent.content with
      | SHELL_SHUTDOWN_REQ body ->
        handle_shutdown_request ~parent shell body (* Don't continue loop *)
      | SHELL_KERNEL_INFO_REQ ->
        handle_kernel_info_request ~parent client shell >>= loop
      | SHELL_EXEC_REQ body ->
        handle_execute_request ~parent client body >>= loop
      | SHELL_COMPLETE_REQ body ->
        handle_complete_request ~parent client shell body >>= loop
      | SHELL_INSPECT_REQ _
      | SHELL_CONNECT_REQ -> (* Deprecated since v5.1 *)
        error "Unsupported request" ;
        loop ()
      (* Following messages are required by jupyter-console, not jupyter notebook. *)
      | SHELL_HISTORY_REQ _ ->
        handle_history_request shell ~parent >>= loop
      | SHELL_IS_COMPLETE_REQ body ->
        handle_is_complete_request shell ~parent body >>= loop
      (* Propagate to REPL process *)
      | SHELL_COMM_OPEN _
      | SHELL_COMM_MSG _
      | SHELL_COMM_CLOSE _
      | SHELL_COMM_INFO_REQ _ ->
        Repl.send client.repl (SHELL_REQ parent) >>= loop
    and loop () =
      let%lwt req = ShellChannel.recv shell in
      reply req
    in
    loop ()

  let start client =
    Lwt.pick [
      propagate_repl client;
      propagate_stdin client;
      start_kernel client client.shell;
      start_kernel client client.control;
      heartbeat client;
    ] >|= fun () ->
    notice "OCaml kernel main loop is exited."
end
