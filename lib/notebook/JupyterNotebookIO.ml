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

(** IO interface *)

module type S =
sig
  type 'a future

  val bind : ('a -> 'b future) -> 'a future -> 'b future
  val return : 'a -> 'a future

  type in_channel
  type out_channel

  val recv : in_channel -> Jupyter.Message.request future
  val send : out_channel -> Jupyter.Message.reply -> unit future

  type thread

  val async : (unit -> unit future) -> thread
end

(** Implementation by the OCaml standard library. *)
module Std =
struct
  type 'a future = 'a

  let bind f x = f x
  let return x = x

  type in_channel = Pervasives.in_channel
  type out_channel = Pervasives.out_channel

  let send oc (data : Jupyter.Message.reply) =
    Marshal.to_channel oc data [] ;
    flush oc

  let recv ic : Jupyter.Message.request = Marshal.from_channel ic

  type thread = Thread.t

  let async f = Thread.create f ()
end
