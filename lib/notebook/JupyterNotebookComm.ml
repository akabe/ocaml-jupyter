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

(** User-defined communication *)

type t = string

let create name data =
  let comm_id = Uuidm.(to_string (create `V4)) in
  let msg = JupyterCommMessage.(`Comm_open {
      target_name = Some name;
      comm_id;
      data;
    })
  in
  JupyterNotebookUnsafe.send_iopub msg ;
  comm_id

let close comm_id =
  let msg = JupyterCommMessage.(`Comm_close {
      target_name = None;
      comm_id;
      data = `Assoc [];
    })
  in
  JupyterNotebookUnsafe.send_iopub msg

let send comm_id data =
  let msg = JupyterCommMessage.(`Comm_msg {
      target_name = None;
      comm_id;
      data;
    })
  in
  JupyterNotebookUnsafe.send_iopub msg
