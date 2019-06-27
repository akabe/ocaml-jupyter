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

(** Top-level loop of OCaml code evaluation *)

(** Globally initialize the OCaml REPL on the current process.
    @param preinit    function called before reading [.ocamlinit].
    @param init_file  path to [.ocamlinit].. *)
val init :
  ?preinit:(unit -> unit) ->
  ?init_file:string ->
  unit -> unit

val setvalue : string -> 'a -> unit

(** {2 Communication} *)

val iopub_success :
  ?metadata:Yojson.Safe.t -> count:int -> string -> Jupyter.Iopub.reply

val iopub_interrupt : unit -> Jupyter.Iopub.reply

(** {2 Execution} *)

val eval :
  ?error_ctx_size:int ->
  send:(Jupyter.Iopub.reply -> unit) ->
  count:int -> string -> Jupyter.Shell.status
