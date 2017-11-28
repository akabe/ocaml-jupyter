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

(** Contents on STDIN channel *)

(** {2 Inputs} *)

type input_request =
  {
    stdin_prompt : string [@key "prompt"];
    stdin_password : bool [@key "password"];
  } [@@deriving yojson { strict = false }]

type input_reply =
  {
    stdin_value : string [@key "value"];
  } [@@deriving yojson { strict = false }]

(** {2 Request} *)

type reply =
  | STDIN_INPUT_REQ of input_request [@name "input_request"]
[@@deriving yojson]

(** {2 Reply} *)

type request =
  | STDIN_INPUT_REP of input_reply [@name "input_reply"]
[@@deriving yojson]
