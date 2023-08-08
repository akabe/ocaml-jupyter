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

(** Connection information *)

open Jupyter_log
open Ppx_yojson_conv_lib.Yojson_conv.Primitives

(** The type of connection information.

    See https://ipython.org/ipython-doc/3/development/kernels.html *)
type t =
  {
    control_port : int;
    shell_port : int;
    stdin_port : int;
    iopub_port : int;
    hb_port : int;
    ip : string;
    key : string option [@default None];
    signature_scheme : string;
    transport : string;
  } [@@deriving yojson]
[@@yojson.allow_extra_fields]

let from_file fname =
  if not (Sys.file_exists fname)
  then failwith ("No such file or directory: " ^ fname) ;
  let json = Yojson.Safe.from_file ~fname fname in
  info (fun pp -> pp "Load connection info: %s" (Yojson.Safe.to_string json)) ;
  match [%of_yojson: t] json with
  | info when info.key = Some "" -> { info with key = None }
  | info -> info

(** [make_address info port] returns an address for ZeroMQ communication. *)
let make_address info port =
  Format.sprintf "%s://%s:%d" info.transport info.ip port
