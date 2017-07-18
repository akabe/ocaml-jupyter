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

(** The main module for an OCaml kernel *)

open Format
open Lwt.Infix

module Server =
  JupyterServer.Make
    (Jupyter.ShellChannel)
    (Jupyter.IopubChannel)
    (Jupyter.StdinChannel)
    (JupyterRepl.Process)

let start_heartbeat ~ctx info =
  let hb =
    Jupyter.ConnectionInfo.(make_address info info.hb_port)
    |> Jupyter.ZmqChannel.create ~ctx ~kind:ZMQ.Socket.rep
  in
  let rec loop () =
    Jupyter.ZmqChannel.recv hb >>= fun data ->
    JupyterLog.debug "Heartbeat" ;
    Jupyter.ZmqChannel.send hb data >>= loop
  in
  loop ()

let () =
  let () = JupyterArgs.parse () in
  (* Fork OCaml REPL before starting a server!
     A few Lwt_unix functions (such as Lwt_unix.getservbyname, getaddrinfo)
     sometimes never returns on a REPL due to use of Lwt at the caller side of
     Toploop (compiler-libs). *)
  let repl =
    JupyterRepl.Process.create
      ~preload:!JupyterArgs.preload_objs
      ~init_file:!JupyterArgs.init_file () in
  (* Start a kernel server. *)
  let conn_info = Jupyter.ConnectionInfo.from_file !JupyterArgs.connection_file in
  let ctx = ZMQ.Context.create () in
  let heartbeat = start_heartbeat ~ctx conn_info in
  let server = Server.create ~repl ~ctx conn_info in
  Sys.catch_break true ; (* Catch `Interrupt' signal *)
  let rec main () =
    try
      Lwt_main.run begin
        let%lwt () = Server.start server <?> heartbeat in
        Server.close server
      end
    with Sys.Break ->
      JupyterRepl.Process.interrupt repl ;
      main ()
  in
  main () ;
  Lwt.cancel heartbeat ;
  ZMQ.Context.terminate ctx
