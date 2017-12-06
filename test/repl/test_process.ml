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
open OUnit2
open Jupyter.Message
open Jupyter.Iopub
open Jupyter.Shell
open Jupyter_repl.Evaluation
open Eval_util

type reply =
  | Iopub of Jupyter.Iopub.reply
  | Stdin of Jupyter.Stdin.reply
  | Shell of Jupyter.Shell.reply

let pp_reply ppf reply =
  begin
    match reply with
    | Shell shell -> [%to_yojson: Jupyter.Shell.reply] shell
    | Iopub iopub -> [%to_yojson: Jupyter.Iopub.reply] iopub
    | Stdin stdin -> [%to_yojson: Jupyter.Stdin.reply] stdin
  end
  |> Yojson.Safe.to_string
  |> pp_print_string ppf

let map_content replies =
  replies
  |> List.map
    (function
      | SHELL_REP shell -> Shell shell.content
      | IOPUB_REP iopub -> Iopub iopub.content
      | STDIN_REP stdin -> Stdin stdin.content)

let test__simple_phrase ctxt =
  let actual = eval "let x = (4 + 1) * 3" |> map_content in
  let expected = [
    Iopub (iopub_success ~count:0 "val x : int = 15\n");
    Shell (execute_reply ~count:0 SHELL_OK);
  ] in
  assert_equal ~ctxt ~printer:[%show: reply list] expected actual

let test__capture_stdout ctxt =
  let actual =
    eval "print_endline \"Hello World\""
    |> map_content
    |> List.sort compare in (* the order of elements is NOT important *)
  let expected = [
    Iopub (stream ~name:IOPUB_STDOUT "Hello World\n");
    Iopub (iopub_success ~count:0 "- : unit = ()\n");
    Shell (execute_reply ~count:0 SHELL_OK);
  ] in
  assert_equal ~ctxt ~printer:[%show: reply list] expected actual

let test__capture_stderr ctxt =
  let actual =
    eval "prerr_endline \"Hello World\""
    |> map_content
    |> List.sort compare in (* the order of elements is NOT important *)
  let expected = [
    Iopub (stream ~name:IOPUB_STDERR "Hello World\n");
    Iopub (iopub_success ~count:0 "- : unit = ()\n");
    Shell (execute_reply ~count:0 SHELL_OK);
  ] in
  assert_equal ~ctxt ~printer:[%show: reply list] expected actual

(** Check [!Sys.interactive] is [true]. *)
let test__sys_interactive ctxt =
  let actual = eval "!Sys.interactive" |> map_content in
  let expected = [
    Iopub (iopub_success ~count:0 "- : bool = true\n");
    Shell (execute_reply ~count:0 SHELL_OK);
  ] in
  assert_equal ~ctxt ~printer:[%show: reply list] expected actual

let suite =
  "Process" >::: [
    "simple_phrase" >:: test__simple_phrase;
    "capture_stdout" >:: test__capture_stdout;
    "capture_stderr" >:: test__capture_stderr;
    "sys_interactive" >:: test__sys_interactive;
  ]

let () = run_test_tt_main suite
