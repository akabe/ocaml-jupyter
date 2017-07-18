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

(** Routing messages from/to ZeroMQ channels *)

open Lwt.Infix

module M = JupyterMessage
module ShellBody = JupyterShellContent
module IopubBody = JupyterIopubContent
module StdinBody = JupyterStdinContent

module Make
    (ShellChannel : JupyterChannelIntf.Shell)
    (IopubChannel : JupyterChannelIntf.Iopub)
    (StdinChannel : JupyterChannelIntf.Stdin)
    (Repl : JupyterChannelIntf.Repl) =
struct
  type t =
    {
      repl : Repl.t;
      shell : ShellChannel.t;
      control : ShellChannel.t;
      iopub : IopubChannel.t;
      stdin : StdinChannel.t;
    }

  let create ~repl ~ctx info =
    let key = info.JupyterConnectionInfo.key in
    let shell =
      JupyterConnectionInfo.(make_address info info.shell_port)
      |> ShellChannel.create ?key ~ctx ~kind:ZMQ.Socket.router
    in
    let control =
      JupyterConnectionInfo.(make_address info info.control_port)
      |> ShellChannel.create ?key ~ctx ~kind:ZMQ.Socket.router
    in
    let iopub =
      JupyterConnectionInfo.(make_address info info.iopub_port)
      |> IopubChannel.create ?key ~ctx ~kind:ZMQ.Socket.pub
    in
    let stdin =
      JupyterConnectionInfo.(make_address info info.stdin_port)
      |> StdinChannel.create ?key ~ctx ~kind:ZMQ.Socket.router
    in
    { repl; shell; control; iopub; stdin; }

  let close server =
    Lwt.join [
      Repl.close server.repl;
      ShellChannel.close server.shell;
      ShellChannel.close server.control;
      IopubChannel.close server.iopub;
      StdinChannel.close server.stdin;
    ]

  (** {2 Main routine} *)

  let kernel_info_request ~parent shell =
    ShellBody.(`Kernel_info_reply kernel_info_reply)
    |> ShellChannel.reply shell ~parent

  let shutdown_request ~parent shell body =
    ShellBody.(`Shutdown_reply body)
    |> ShellChannel.reply shell ~parent

  let start_kernel server shell =
    let rec reply parent = function
      | `Kernel_info_request -> kernel_info_request ~parent shell >>= loop
      | `Shutdown_request body -> shutdown_request ~parent shell body
      | _ ->
        JupyterLog.error "Unsupported request" ;
        assert false
    and loop () =
      ShellChannel.recv shell >>= fun req -> reply req req.M.content
    in
    loop ()

  let start server =
    Lwt.choose [
      start_kernel server server.shell;
      start_kernel server server.control;
    ]
end
