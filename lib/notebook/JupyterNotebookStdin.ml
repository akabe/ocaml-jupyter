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

(** Jupyter stdin *)

let stdin, stdin_out =
  let fin, fout = Unix.pipe () in
  let ic = Unix.in_channel_of_descr fin in
  let oc = Unix.out_channel_of_descr fout in
  (ic, oc)

let blocking_on_recv value =
  output_string stdin_out value ;
  output_char stdin_out '\n' ;
  flush stdin_out

let on_recv = ref blocking_on_recv

let send_stdin content =
  let parent = match !JupyterNotebookUnsafe.context with
    | None -> failwith "Undefined current context"
    | Some ctx -> ctx in
  let message =
    Jupyter.KernelMessage.create_next parent content
      ~content_to_yojson:[%to_yojson: Jupyter.StdinMessage.reply] in
  JupyterNotebookUnsafe.send (`Stdin message)

let recv msg =
  let open Jupyter in
  let (`Input_reply { StdinMessage.value }) = msg.KernelMessage.content in
  !on_recv value

let read_line_async on_recv_ ?(password = false) prompt =
  on_recv := on_recv_ ;
  send_stdin JupyterStdinMessage.(`Input_request { prompt; password; })

let read_line ?password prompt =
  read_line_async blocking_on_recv ?password prompt ;
  input_line stdin
