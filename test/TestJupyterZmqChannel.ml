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

open Format
open Lwt.Infix
open OUnit2
open Jupyter

let ctx = ZMQ.Context.create ()

(** Instead of Jupyter *)
let create_zmq_client data =
  if Unix.fork () = 0 then begin (* child process is a ZMQ client *)
    try
      let socket = ZMQ.Socket.create ctx ZMQ.Socket.req in
      ZMQ.Socket.connect socket "tcp://127.0.0.1:5555" ;
      ZMQ.Socket.send_all socket data ;
      let _ = ZMQ.Socket.recv socket in (* wait shutdown_request *)
      ZMQ.Socket.close socket ;
      exit 0
    with exn ->
      printf "Uncaught exception: %s\nbacktrace: %s\n%!"
        (Printexc.to_string exn) (Printexc.get_backtrace ())
  end

let test_recv_send ctxt =
  let expected = ["This"; "is"; "ZeroMQ"] in
  create_zmq_client expected ;
  Lwt_main.run begin
    let socket = ZmqChannel.create ~ctx ~kind:ZMQ.Socket.rep "tcp://0.0.0.0:5555" in
    ZmqChannel.recv socket >>= fun actual ->
    ZmqChannel.send socket ["shutdown"] >>= fun () ->
    assert_equal ~ctxt ~printer:[%show: string list] actual expected ;
    ZmqChannel.close socket
  end

let suite =
  "ZmqChannel" >:: test_recv_send
