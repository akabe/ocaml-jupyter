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

(** {2 Display} *)

let display ?ctx ?(base64 = false) mime data =
  let data = if base64 then B64.encode data else data in
  JupyterNotebookUnsafe.send_iopub ?ctx
    Jupyter.IopubMessage.(`Display_data {
        data = `Assoc [mime, `String data];
        metadata = `Assoc [];
        transient = None;
      })

let read_as_possible fd =
  let n = 1024 in
  let b = Buffer.create n in
  let bytes = Bytes.create n in
  let rec aux () =
    match Unix.select [fd] [] [] 0.0 with
    | [_], _, _ ->
      let m = Unix.read fd bytes 0 n in
      Buffer.add_subbytes b bytes 0 m ;
      if m = n then aux ()
    | _ -> ()
  in
  aux () ; Buffer.contents b

let cellin, cellout =
  let cell_r, cell_w = Unix.pipe () in
  let cellout = Unix.out_channel_of_descr cell_w in
  set_binary_mode_out cellout true ;
  (cell_r, cellout)

let display_cell ?ctx ?base64 mime =
  flush cellout ;
  read_as_possible cellin
  |> display ?ctx ?base64 mime

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
