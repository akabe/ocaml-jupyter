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

(** Messaging channel for Jupyter *)

module type ContentType =
sig
  type request [@@deriving yojson]
  type reply [@@deriving yojson]
end

module Make (Content : ContentType) (Socket : JupyterChannelIntf.ZMQ) :
sig

  include JupyterChannelIntf.S
    with type input = Content.request JupyterMessage.t
     and type output = Content.reply JupyterMessage.t

  val create :
    ?key:string ->
    ctx:ZMQ.Context.t ->
    kind:'a ZMQ.Socket.kind ->
    string -> t

  val next : ?time:float -> _ JupyterMessage.t -> Content.reply -> output

  val send_next : t -> parent:_ JupyterMessage.t -> Content.reply -> unit Lwt.t

end
