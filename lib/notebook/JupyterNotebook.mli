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

(** A library for Jupyter notebooks *)

type ctx

(** The output channel to send displayed data. *)
val cellout : out_channel

(** Returns the current cell context. *)
val cell_context : unit -> ctx

(** [display ?ctx ?base64 mime data] shows [data] at [ctx]. [mime] is the mime
    type of [data].
    @param ctx     default = the current cell.
    @param base64  default = [false]. *)
val display : ?ctx:ctx -> ?base64:bool -> string -> string -> unit

(** [display_cell ?ctx ?base64 mime] shows data written into [cellout] at [ctx].
    [mime] is the mime type of the data.
    @param ctx     default = the current cell.
    @param base64  default = [false]. *)
val display_cell : ?ctx:ctx -> ?base64:bool -> string -> unit

(** User-defined communication *)
module Comm = JupyterNotebookComm
