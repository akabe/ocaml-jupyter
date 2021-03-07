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

type display_id

(** Returns the current cell context. *)
val cell_context : unit -> ctx

(** [display ?ctx ?base64 mime data] shows [data] at [ctx]. [mime] is the mime
    type of [data].
    @param ctx        default = the current cell.
    @param display_id default = a fresh ID (since 1.0.0)
    @param metadata   default = nothing (since 1.0.0)
    @param base64     default = [false]. *)
val display :
  ?ctx:ctx ->
  ?display_id:display_id ->
  ?metadata:Yojson.Safe.t ->
  ?base64:bool ->
  string -> string -> display_id

(** [display_file ?ctx ?base64 mime filename] shows data in the file of path
    [filename] at [ctx]. [mime] is the mime type of the data.
    @param ctx        default = the current cell.
    @param display_id default = a fresh ID (since 1.0.0)
    @param metadata   default = nothing (since 1.0.0)
    @param base64     default = [false].
    @since 1.1.0 *)
val display_file :
  ?ctx:ctx ->
  ?display_id:display_id ->
  ?metadata:Yojson.Safe.t ->
  ?base64:bool ->
  string -> string -> display_id

(** [clear_output ?ctx ?wait ()] removes displayed elements from [ctx].
    @param ctx   default = the current cell.
    @param wait  default = [false]. Wait to clear the output until new output is
    available. *)
val clear_output : ?ctx:ctx -> ?wait:bool -> unit -> unit

(** {2 Printf} *)

(** The formatter for displaying data on notebooks.
    @since 1.1.0 *)
val formatter : Format.formatter

(** Same as {!Format.printf}, but output on {!Jupyter_notebook.formatter}.
    @since 1.1.0 *)
val printf : ('a, Format.formatter, unit) format -> 'a

(** [display_formatter ?ctx ?base64 mime] shows data written in
    {!Jupyter_notebook.formatter} at [ctx].
    [mime] is the mime type of the data.

    {!Jupyter_notebook.formatter} is flushed and data in the formatter
    is cleaned by calling this function.

    @param ctx        default = the current cell.
    @param display_id default = a fresh ID (since 1.0.0)
    @param metadata   default = nothing (since 1.0.0)
    @param base64     default = [false].
    @since 1.1.0 *)
val display_formatter :
  ?ctx:ctx ->
  ?display_id:display_id ->
  ?metadata:Yojson.Safe.t ->
  ?base64:bool ->
  string -> display_id
