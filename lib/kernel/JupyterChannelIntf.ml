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

(** Interface for communication modules *)

module type S =
sig
  type t
  type input
  type output

  val recv : t -> input Lwt.t

  val send : t -> output -> unit Lwt.t

  val close : t -> unit Lwt.t
end

module type Zmq =
sig
  include S
    with type input = string list
     and type output = string list

  val create : ctx:ZMQ.Context.t -> kind:'a ZMQ.Socket.kind -> string -> t
end

module type Message =
sig
  type request
  type reply

  include S
    with type input = request JupyterMessage.t
     and type output = reply JupyterMessage.t

  (** [create ?key ~ctx ~kind address] opens connection to [address].
      @param key   a HMAC key. If [None], HMAC verification is disabled.
      @param ctx   ZeroMQ context.
      @param kind  ZeroMQ socket type. *)
  val create :
    ?key:string ->
    ctx:ZMQ.Context.t ->
    kind:'a ZMQ.Socket.kind ->
    string -> t

  (** [reply ?time ~parent channel content] sends a message including [content]
      as a reply of [parent]. *)
  val reply :
    ?time:float ->
    parent:_ JupyterMessage.t ->
    t -> reply -> unit Lwt.t
end

module type Shell =
  Message with type request = JupyterShellContent.request
           and type reply = JupyterShellContent.reply

module type Iopub =
  Message with type reply = JupyterIopubContent.reply

module type Stdin =
  Message with type request = JupyterStdinContent.request
           and type reply = JupyterStdinContent.reply

module type Repl =
sig
  include S
    with type input = JupyterReplMessage.reply
     and type output = JupyterReplMessage.request

  val create : ?preload:string list -> ?init_file:string -> unit -> t

  val stream : t -> JupyterReplMessage.output Lwt_stream.t
end
