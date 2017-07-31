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

(** OCaml REPL process *)

type reply =
  [
    | JupyterReplToploop.reply
    | Jupyter.Message.reply
    | `Stdout of string
    | `Stderr of string
    | `Prompt of string option
  ]
[@@deriving yojson]

type t

val create : ?preload:string list -> ?init_file:string -> unit -> t

val close : t -> unit Lwt.t

(** [run ?ctx ~filename repl code] executes [code] in a REPL process
    asynchronously. *)
val run :
  ?ctx:JupyterMessage.ctx ->
  filename:string ->
  t -> string -> unit Lwt.t

(** Returns a stream of outputs of a REPL process. *)
val stream : t -> reply Lwt_stream.t

(** [send repl req] sends [req] to [jupyterin] channel in a REPL process. *)
val send : t -> Jupyter.Message.request -> unit Lwt.t

(** [interrupt repl] sends [SIGINT] signal (i.e., Ctrl-C) to a REPL process. *)
val interrupt : t -> unit
