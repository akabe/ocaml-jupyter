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
open JupyterKernelMessage

let exec = TestJupyterNotebookUnsafe.exec

let ctx =
  {
    zmq_ids = []; buffers = []; metadata = ""; parent_header = None;
    header = {
      msg_id = "";
      msg_type = "execute_request";
      session = "";
      date = None;
      username = "";
      version = "";
    };
    content = `Execute_request JupyterShellMessage.({
        code = "";
        silent = false;
        store_history = true;
        user_expressions = `Null;
        allow_stdin = true;
        stop_on_error = true;
      });
  }

(** {2 Test suite} *)

let test_display__rawdata ctxt =
  let expected_content =
    `Display_data JupyterIopubMessage.({
        data = `Assoc ["text", `String "Hello"];
        metadata = `Assoc [];
        transient = None;
      })
  in
  match exec ~ctx {|JupyterNotebook.display "text" "Hello"|} with
  | `Iopub { parent_header = Some ph; content; _ } :: _ ->
    assert_equal ~ctxt ctx.header ph ;
    assert_equal ~ctxt expected_content content
  | xs ->
    assert_failure ("Unexpected sequence: " ^ TestJupyterReplProcess.printer xs)

let test_display__base64 ctxt =
  let expected_content =
    `Display_data JupyterIopubMessage.({
        data = `Assoc ["text", `String "SGVsbG8="];
        metadata = `Assoc [];
        transient = None;
      })
  in
  match exec ~ctx {|JupyterNotebook.display ~base64:true "text" "Hello"|} with
  | `Iopub { parent_header = Some ph; content; _ } :: _ ->
    assert_equal ~ctxt ctx.header ph ;
    assert_equal ~ctxt expected_content content
  | xs ->
    assert_failure ("Unexpected sequence: " ^ TestJupyterReplProcess.printer xs)

let test_display_cell ctxt =
  let expected_content =
    `Display_data JupyterIopubMessage.({
        data = `Assoc ["text", `String "Hello"];
        metadata = `Assoc [];
        transient = None;
      })
  in
  match exec ~ctx {|output_string JupyterNotebook.cellout "Hello" ;
                    JupyterNotebook.display_cell "text"|} with
  | `Iopub { parent_header = Some ph; content; _ } :: _ ->
    assert_equal ~ctxt ctx.header ph ;
    assert_equal ~ctxt expected_content content
  | xs ->
    assert_failure ("Unexpected sequence: " ^ TestJupyterReplProcess.printer xs)

let test_clear_output ctxt =
  let expected_content =
    `Clear_output JupyterIopubMessage.({ wait = false }) in
  match exec ~ctx {|JupyterNotebook.clear_output ~wait:false ()|} with
  | `Iopub { parent_header = Some ph; content; _ } :: _ ->
    assert_equal ~ctxt ctx.header ph ;
    assert_equal ~ctxt expected_content content
  | xs ->
    assert_failure ("Unexpected sequence: " ^ TestJupyterReplProcess.printer xs)

let suite =
  "JupyterNotebook" >::: [
    "display" >::: [
      "rawdata" >:: test_display__rawdata;
      "base64" >:: test_display__base64;
    ];
    "display_cell" >:: test_display_cell;
    "clear_output" >:: test_clear_output;
  ]
