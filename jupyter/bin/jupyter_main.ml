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
open Jupyter
open Jupyter_kernel
open Jupyter_log

module ShellChannel = Message_channel.Make(Shell)(Zmq_channel)
module IopubChannel = Message_channel.Make(Iopub)(Zmq_channel)
module StdinChannel = Message_channel.Make(Stdin)(Zmq_channel)
module Client =
  Client.Make
    (ShellChannel)(IopubChannel)(StdinChannel)(Zmq_channel)
    (Jupyter_repl.Process)(Jupyter_completor.Merlin)

let () =
  Printexc.record_backtrace true ;
  let () = Jupyter_args.parse () in
  (* Fork OCaml REPL before starting a server!
     A few Lwt_unix functions (such as Lwt_unix.getservbyname, getaddrinfo)
     sometimes never returns on a REPL due to use of Lwt at the caller side of
     Toploop (compiler-libs). *)
  let repl =
    Jupyter_repl.Process.create
      ~preload:!Jupyter_args.preload_objs
      ~init_file:!Jupyter_args.init_file
      ~error_ctx_size:!Jupyter_args.error_ctx_size () in
  let completor =
    Jupyter_completor.Merlin.create
      ~bin_path:!Jupyter_args.merlin
      ~dot_merlin:!Jupyter_args.dot_merlin () in
  (* Start a kernel server. *)
  let conn_info = Connection_info.from_file !Jupyter_args.connection_file in
  let ctx = ZMQ.Context.create () in
  let client = Client.create ~completor ~repl ~ctx conn_info in
  let client_thread = Client.start client in
  Sys.catch_break true ; (* Catch `Interrupt' signal *)
  let rec main () =
    try
      Lwt_main.run begin
        let%lwt () = client_thread in
        Client.close client
      end
    with Sys.Break ->
      Jupyter_repl.Process.interrupt repl ;
      main ()
  in
  main () ;
  ZMQ.Context.terminate ctx
