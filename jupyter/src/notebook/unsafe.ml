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

(** Unsafe low-level functions used in Jupyter notebooks *)

type ctx = Jupyter.Shell.request Jupyter.Message.t

(** Output channel to send messages to Jupyter or Web browser frontend. *)
let jupyterout : out_channel =
  Obj.obj (Toploop.getvalue "$jupyterout")

(** Input channel to accept messages from Jupyter or Web browser frontend. *)
let jupyterin : in_channel =
  Obj.obj (Toploop.getvalue "$jupyterin")

(** The current [execute_request] message from Jupyter. *)
let context : ctx option ref =
  Obj.obj (Toploop.getvalue "$jupyterctx")

(** [recv ()] receives a message from Jupyter or Web browser frontend. *)
let recv () : Jupyter.Message.request = Marshal.from_channel jupyterin

(** [send data] sends [data] to Jupyter or Web browser frontend. *)
let send (data : Jupyter.Message.reply) =
  Marshal.to_channel jupyterout data [] ;
  flush jupyterout

let send_iopub ?ctx content =
  let parent = match ctx, !context with
    | Some ctx, _ -> ctx
    | None, Some ctx -> ctx
    | None, None -> failwith "Undefined current context"
  in
  let message =
    Jupyter.Message.create_next parent content
      ~content_to_yojson:[%to_yojson: Jupyter.Iopub.reply] in
  send (Jupyter.Message.IOPUB_REP message)
