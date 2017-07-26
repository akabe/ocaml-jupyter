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

open Format
open Lwt.Infix
open OUnit2
open JupyterRepl

let printer lst =
  [%to_yojson: JupyterReplProcess.reply list] lst
  |> Yojson.Safe.to_string

let cmp = TestJupyterReplToploop.cmp

let exec ?hook ?ctx code =
  TestJupyterReplProcess.exec
    ?hook ?ctx ~init_file:"fixtures/notebook.init.ml" code

(** {2 Test suite} *)

let test__jupyterin ctxt =
  let actual = exec "JupyterNotebookUnsafe.jupyterin" in
  let expected = [`Ok "- : in_channel = <abstr>\n"] in
  assert_equal ~ctxt ~printer ~cmp expected actual

let test__jupyterout ctxt =
  let actual = exec "JupyterNotebookUnsafe.jupyterout" in
  let expected = [`Ok "- : out_channel = <abstr>\n"] in
  assert_equal ~ctxt ~printer ~cmp expected actual

let test__jupyterctx ctxt =
  let ctx = Fixture.KernelInfoRequest.message in
  let actual = exec ~ctx "!JupyterNotebookUnsafe.context" in
  let expected = [`Ok "- : JupyterMessage.ctx option =.*"] in
  assert_equal ~ctxt ~printer ~cmp expected actual

let test__send ctxt =
  let actual =
    exec
      "let open JupyterKernelMessage in \
       let content = `Status JupyterIopubMessage.{ execution_state = `Idle } in \
       let header = { msg_id=\"\"; msg_type=\"status\"; session=\"\"; date=None; username=\"\"; version=\"\"; } in \
       let m = { zmq_ids=[]; header; parent_header=None; metadata=\"\"; content; buffers=[]; } in \
       JupyterNotebookUnsafe.send (`Iopub m)"
    |> List.sort compare in (* the order of elements is NOT important *)
  let expected = [
    `Iopub JupyterKernelMessage.{
        zmq_ids = [];
        header = { msg_id=""; msg_type="status"; session="";
                   date=None; username=""; version=""; };
        parent_header = None;
        metadata = "";
        content = `Status JupyterIopubMessage.{ execution_state = `Idle };
        buffers = [];
      };
    `Ok "- : unit = ()\n"
  ] in
  assert_equal ~ctxt ~printer ~cmp expected actual
(*
let test__recv ctxt =
  let msg =
    `Shell (`Comm_open Jupyter.CommMessage.{
        target_name = None;
        comm_id = "abcd";
        data = `Null;
      }) in
  let actual =
    exec ~hook:(fun repl -> Process.send repl msg)
      "JupyterNotebookUnsafe.recv ()" in
  let expected = [`Ok "- : Jupyter\\.Message\\.request =.*"] in
  assert_equal ~ctxt ~printer ~cmp expected actual
  *)
let suite =
  "JupyterNotebook" >::: [
    "Unsafe" >::: [
      "jupyterin" >:: test__jupyterin;
      "jupyterout" >:: test__jupyterout;
      "jupyterctx" >:: test__jupyterctx;
      "send" >:: test__send;
      (* "recv" >:: test__recv; *)
    ]
  ]
