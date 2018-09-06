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
      |> ShellChannel.create ?key ~ctx ~kind:Zmq.Socket.router
    in
    let control =
      Connection_info.(make_address info info.control_port)
      |> ShellChannel.create ?key ~ctx ~kind:Zmq.Socket.router
    in
    let iopub =
      Connection_info.(make_address info info.iopub_port)
      |> IopubChannel.create ?key ~ctx ~kind:Zmq.Socket.pub
    in
    let stdin =
      Connection_info.(make_address info info.stdin_port)
      |> StdinChannel.create ?key ~ctx ~kind:Zmq.Socket.router
    in
    let heartbeat =
      Connection_info.(make_address info info.hb_port)
      |> HeartbeatChannel.create ~ctx ~kind:Zmq.Socket.rep
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

  let send_iopub_exec_input ?parent client code =
    send_iopub ?parent client (IOPUB_EXECUTE_INPUT {
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
    let%lwt () = send_iopub_status ~parent client IOPUB_BUSY in
    let%lwt () = send_iopub_exec_input ~parent client code in
    let%lwt () =
      Repl.eval ~ctx:parent ~count client.repl code >|= function
      | SHELL_OK -> Completor.add_context client.completor code
      | _ -> () in
    send_iopub_status ~parent client IOPUB_IDLE

  let handle_complete_request ~parent client shell body =
    let%lwt Completor.{cmpl_candidates; cmpl_start; cmpl_end} =
      Completor.complete
        client.completor body.cmpl_code ~pos:body.cmpl_pos in
    let shell_reply =
      {
        cmpl_status = SHELL_OK;
        cmpl_metadata = `Assoc [];
        cmpl_start = cmpl_start;
        cmpl_end = cmpl_end;
        cmpl_matches = List.map (fun c -> c.Completor.cmpl_name) cmpl_candidates;
      }
    in
    let%lwt () = send_iopub_status ~parent client IOPUB_BUSY in
    let%lwt () =
      ShellChannel.reply shell ~parent (SHELL_COMPLETE_REP shell_reply) in
    send_iopub_status ~parent client IOPUB_IDLE

  let handle_inspect_request ~parent client shell body =
    let format c =
      let kind = match c.Completor.cmpl_kind with
        | Completor.CMPL_VALUE -> "Value"
        | Completor.CMPL_VARIANT -> "Variant"
        | Completor.CMPL_CONSTR -> "Constructor"
        | Completor.CMPL_LABEL -> "Label"
        | Completor.CMPL_MODULE -> "Module"
        | Completor.CMPL_SIG -> "Signature"
        | Completor.CMPL_TYPE -> "Type"
        | Completor.CMPL_METHOD
        | Completor.CMPL_METHOD_CALL -> "Method"
        | Completor.CMPL_EXN -> "Exception"
        | Completor.CMPL_CLASS -> "Class" in
      let left_len = 11 in
      let doc = String.trim c.Completor.cmpl_doc in (* remove extra spaces *)
      sprintf "%s%s: %*s%s\n\
               %sType:        %s%s\n\
               %sDocstring:   %s%s"
        AnsiCode.FG.red kind left_len AnsiCode.FG.default c.Completor.cmpl_name
        AnsiCode.FG.red AnsiCode.FG.default c.Completor.cmpl_type
        AnsiCode.FG.red AnsiCode.FG.default doc
    in
    let%lwt raw_reply =
      Completor.complete
        ~doc:true ~types:true
        client.completor body.insp_code ~pos:body.insp_pos in
    let shell_reply =
      let data = List.map format raw_reply.Completor.cmpl_candidates
                 |> String.concat "\n\n" in
      {
        insp_status = SHELL_OK;
        insp_found = (raw_reply.Completor.cmpl_candidates <> []);
        insp_data = `Assoc ["text/plain", `String data];
        insp_metadata = `Assoc [];
      }
    in
    let%lwt () = send_iopub_status ~parent client IOPUB_BUSY in
    let%lwt () =
      ShellChannel.reply shell ~parent (SHELL_INSPECT_REP shell_reply) in
    send_iopub_status ~parent client IOPUB_IDLE

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
      | SHELL_INSPECT_REQ body ->
        handle_inspect_request ~parent client shell body >>= loop
      | SHELL_CONNECT_REQ ->
        error (fun pp -> pp "Unsupported request: connect_request \
                             (deprected since protocol v5.1)") ;
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
    app (fun pp -> pp "OCaml kernel main loop is exited.")
end
