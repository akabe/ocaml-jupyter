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

type ctx = JupyterMessage.ctx
type display_id = string

(** {2 Display} *)

let display ?ctx ?display_id ?(metadata = `Assoc []) ?(base64 = false) mime data =
  let data = if base64 then B64.encode data else data in
  let send content = JupyterNotebookUnsafe.send_iopub ?ctx content in
  match display_id with
  | None ->
    let display_id = Uuidm.(to_string (create `V4)) in
    send Jupyter.IopubMessage.(`Display_data {
        data = `Assoc [mime, `String data];
        metadata;
        transient = Some { display_id };
      }) ;
    display_id
  | Some display_id ->
    send Jupyter.IopubMessage.(`Update_display_data {
        data = `Assoc [mime, `String data];
        metadata;
        transient = Some { display_id };
      }) ;
    display_id

let display_file ?ctx ?display_id ?metadata ?base64 mime filename =
  let ic = open_in_bin filename in
  let n = in_channel_length ic in
  let s = really_input_string ic n in
  close_in ic ;
  display ?ctx ?display_id ?metadata ?base64 mime s

let clear_output ?ctx ?(wait = false) () =
  JupyterNotebookUnsafe.send_iopub ?ctx
    Jupyter.IopubMessage.(`Clear_output { wait })

let cell_context () =
  match !JupyterNotebookUnsafe.context with
  | None -> failwith "JupyterNotebook has no execution context"
  | Some ctx -> ctx

let read_line = JupyterNotebookStdin.read_line

let read_line_async = JupyterNotebookStdin.read_line_async

(** {2 User-defined communication} *)

module CommManager = JupyterNotebookCommManager
