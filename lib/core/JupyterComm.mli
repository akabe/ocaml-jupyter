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

(** User-defined communication *)

type t

(** The type of handlers of comm messages. The type parameter ['ctx]
    instantiates to the type of context (or state) of communication. *)
type 'ctx handler =
  {
    on_open : JupyterCommMessage.comm -> 'ctx;
    (** [on_open] is called when a new communication starts, and creates
        a communication context. *)

    on_msg : JupyterCommMessage.comm -> 'ctx -> 'ctx;
    (** [on_msg] is called when a new message is received (after [on_open]),
        and returns an updated context. *)

    on_close : JupyterCommMessage.comm -> 'ctx -> unit;
    (** [on_close] is called when a communication finished. *)
  }

val create : unit -> t

(** [register comm target_name handler] registers [handler] as [target_name]. *)
val register : t -> string -> 'ctx handler -> unit

(** [unregister comm target_name] removes a handler named [target_name]. *)
val unregister : t -> string -> unit

(** {2 Receivers}

    Don't use these functions: they are called from an OCaml kernel. *)

val recv_open : t -> JupyterCommMessage.comm -> unit

val recv_close : t -> JupyterCommMessage.comm -> unit

val recv_msg : t -> JupyterCommMessage.comm -> unit
