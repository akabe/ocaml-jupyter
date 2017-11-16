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
open Jupyter.Message
open Jupyter.Iopub
open Jupyter.Shell
open Jupyter_repl
open Eval_util

let pp_reply ppf reply =
  [%to_yojson: Jupyter.Message.reply] reply
  |> Yojson.Safe.to_string
  |> pp_print_string ppf

let eval = eval ~init_file:"fixtures/nbinit.ml"

(** {2 Test suite} *)

let test_display__rawdata ctxt =
  {|Jupyter_notebook.display "text" "Hello"|}
  |> eval |> function
  | IOPUB_REP { parent_header = Some p; content = IOPUB_DISPLAY_DATA d; _ } :: _ ->
    assert_equal ~ctxt default_ctx.header p ;
    assert_equal ~ctxt (`Assoc ["text", `String "Hello"]) d.display_data ;
    assert_equal ~ctxt (`Assoc []) d.display_metadata
  | xs ->
    assert_failure ("Unexpected sequence: " ^ [%show: reply list] xs)

let test_display__base64 ctxt =
  {|Jupyter_notebook.display ~base64:true "text" "Hello"|}
  |> eval |> function
  | IOPUB_REP { parent_header = Some p; content = IOPUB_DISPLAY_DATA d; _ } :: _ ->
    assert_equal ~ctxt default_ctx.header p ;
    assert_equal ~ctxt (`Assoc ["text", `String "SGVsbG8="]) d.display_data ;
    assert_equal ~ctxt (`Assoc []) d.display_metadata
  | xs ->
    assert_failure ("Unexpected sequence: " ^ [%show: reply list] xs)

let test_display__update ctxt =
  {|Jupyter_notebook.display ~display_id:(Obj.magic "abcd") "text" "Hello"|}
  |> eval |> function
  | IOPUB_REP { parent_header = Some p; content = IOPUB_UPDATE_DISPLAY_DATA d; _ } :: _ ->
    assert_equal ~ctxt default_ctx.header p ;
    assert_equal ~ctxt (`Assoc ["text", `String "Hello"]) d.display_data ;
    assert_equal ~ctxt (`Assoc []) d.display_metadata ;
    assert_equal ~ctxt (Some { display_id = Obj.magic "abcd" }) d.display_transient
  | xs ->
    assert_failure ("Unexpected sequence: " ^ [%show: reply list] xs)

let test_display_file ctxt =
  {|Jupyter_notebook.display_file ~base64:true "text" "fixtures/file.bin"|}
  |> eval |> function
  | IOPUB_REP { parent_header = Some p; content = IOPUB_DISPLAY_DATA d; _ } :: _ ->
    assert_equal ~ctxt default_ctx.header p ;
    assert_equal ~ctxt (`Assoc ["text", `String "oTIA5/8="]) d.display_data ;
    assert_equal ~ctxt (`Assoc []) d.display_metadata
  | xs ->
    assert_failure ("Unexpected sequence: " ^ [%show: reply list] xs)

let test_clear_output ctxt =
  let expected_content = IOPUB_CLEAR_OUTPUT { clear_wait = false } in
  {|Jupyter_notebook.clear_output ~wait:false ()|}
  |> eval |> function
  | IOPUB_REP { parent_header = Some p; content; _ } :: _ ->
    assert_equal ~ctxt default_ctx.header p ;
    assert_equal ~ctxt expected_content content
  | xs ->
    assert_failure ("Unexpected sequence: " ^ [%show: reply list] xs)

let suite =
  "Jupyter_notebook" >::: [
    "display" >::: [
      "rawdata" >:: test_display__rawdata;
      "base64" >:: test_display__base64;
      "update" >:: test_display__update;
    ];
    "display_file" >:: test_display_file;
    "clear_output" >:: test_clear_output;
  ]

let () = run_test_tt_main suite
