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

open Jupyter.Iopub

type ctx = Unsafe.ctx
type display_id = string

(** {2 Display} *)

let random_state = Random.State.make_self_init ()
let uuid_gen = Uuidm.v4_gen random_state
let next_uuid () = Uuidm.(to_string (uuid_gen ()))

let display ?ctx ?display_id ?(metadata = `Assoc []) ?(base64 = false) mime data =
  let data =
    if base64 then Base64.encode data
                   |> function
                   | Ok result -> result
                   | Error (`Msg erro) -> raise @@ Failure erro
    else data
  in
  let send content = Unsafe.send_iopub ?ctx content in
  match display_id with
  | None ->
    let display_id = next_uuid () in
    send (IOPUB_DISPLAY_DATA {
        display_data = `Assoc [mime, `String data];
        display_metadata = metadata;
        display_transient = Some { display_id };
      }) ;
    display_id
  | Some display_id ->
    send (IOPUB_UPDATE_DISPLAY_DATA {
        display_data = `Assoc [mime, `String data];
        display_metadata = metadata;
        display_transient = Some { display_id };
      }) ;
    display_id

let display_file ?ctx ?display_id ?metadata ?base64 mime filename =
  let ic = open_in_bin filename in
  let n = in_channel_length ic in
  let s = really_input_string ic n in
  close_in ic ;
  display ?ctx ?display_id ?metadata ?base64 mime s

let clear_output ?ctx ?(wait = false) () =
  Unsafe.send_iopub ?ctx (IOPUB_CLEAR_OUTPUT { clear_wait = wait })

let cell_context () =
  match !Unsafe.context with
  | None -> failwith "JupyterNotebook has no execution context"
  | Some ctx -> ctx

(** {2 Printf} *)

let formatter_buf = Buffer.create 128
let formatter = Format.formatter_of_buffer formatter_buf

let printf fmt = Format.fprintf formatter fmt

let display_formatter ?ctx ?display_id ?metadata ?base64 mime =
  Format.pp_print_flush formatter () ;
  let data = Buffer.contents formatter_buf in
  Buffer.clear formatter_buf ;
  display ?ctx ?display_id ?metadata ?base64 mime data

(** {2 Utilities} *)

module Bench = Jupyter_notebook__Bench

module Process = Jupyter_notebook__Process

module Eval = Jupyter_notebook__Eval
