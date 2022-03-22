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

(** Interface for competion modules *)

module type S =
sig
  type kind =
    | CMPL_VALUE
    | CMPL_VARIANT
    | CMPL_CONSTR
    | CMPL_LABEL
    | CMPL_MODULE
    | CMPL_SIG
    | CMPL_TYPE
    | CMPL_METHOD
    | CMPL_METHOD_CALL
    | CMPL_EXN
    | CMPL_CLASS
  [@@deriving yojson]

  type candidate =
    {
      cmpl_name : string;
      cmpl_kind : kind Jupyter.Json.enum;
      cmpl_type : string;
      cmpl_doc  : string;
    }
  [@@deriving yojson]

  type reply =
    {
      cmpl_candidates : candidate list;
      cmpl_start : int;
      cmpl_end : int;
    }
  [@@deriving yojson]

  type t

  (** [add_context compl code] adds [code] to context of completor [compl]. *)
  val add_context : t -> string -> unit

  (** [complete ?doc ?types ~pos compl code] returns completion results of
      [code] at [pos].
      @param doc    [true] if documentation is returned.
      @param types  [true] if types of identifiers are returned.
      @param pos    the cursor position *)
  val complete :
    ?doc:bool -> ?types:bool -> pos:int -> t -> string -> reply Lwt.t
end
