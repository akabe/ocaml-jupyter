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

type t

(** Creates an OCaml REPL process.

    @param preload         a list of pre-loaded [.cma] files.
    @param init_file       read a given file instead of [.ocamlinit].
    @param error_ctx_size  the number of context lines in error messages. *)
val create :
  ?preload:string list ->
  ?init_file:string ->
  ?error_ctx_size:int ->
  unit -> t

val close : t -> unit Lwt.t

(** [interrupt repl] sends [SIGINT] signal (i.e., Ctrl-C) to a REPL process. *)
val interrupt : t -> unit

(** [heartbeat repl] performs health check. *)
val heartbeat : t -> unit

(** [eval ~ctx ~count repl code] executes [code] on a REPL process. *)
val eval :
  ctx:Jupyter.Shell.request Jupyter.Message.t ->
  count:int ->
  t -> string -> Jupyter.Shell.status Lwt.t

(** Returns a stream of outputs of a REPL process. *)
val stream : t -> Jupyter.Message.reply Lwt_stream.t

(** [send repl req] sends [req] to [jupyterin] channel in a REPL process. *)
val send : t -> Jupyter.Message.request -> unit Lwt.t
