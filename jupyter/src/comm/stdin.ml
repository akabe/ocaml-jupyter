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

open Jupyter
open Jupyter.Stdin

let send_stdin content =
  let parent = match !Jupyter_notebook__Unsafe.context with
    | None -> failwith "Undefined current context"
    | Some ctx -> ctx in
  let reply = Message.create_next_stdin parent content in
  Jupyter_notebook__Unsafe.send (Message.STDIN_REP reply)

let read_line_async ~recv ?(password = false) prompt =
  Router.on_recv := recv ;
  send_stdin (STDIN_INPUT_REQ {
      stdin_prompt = prompt;
      stdin_password = password;
    })

let read_line ?password prompt =
  read_line_async ~recv:Router.blocking_on_recv ?password prompt ;
  input_line Router.stdin
