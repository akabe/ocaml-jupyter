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

(** ZeroMQ sockets *)

open Lwt.Infix

type t = C : _ Lwt_zmq.Socket.t -> t

type input = string list
type output = string list

let create ~ctx ~kind addr =
  let socket = ZMQ.Socket.create ctx kind in
  ZMQ.Socket.bind socket addr ;
  JupyterKernelLog.info "Open ZMQ socket to %s" addr ;
  C (Lwt_zmq.Socket.of_socket socket)

let recv (C socket) = Lwt_zmq.Socket.recv_all socket

let send (C socket) strs =
  Lwt_zmq.Socket.send_all socket strs

let close (C socket) =
  Lwt_zmq.Socket.to_socket socket
  |> ZMQ.Socket.close
  |> Lwt.return
