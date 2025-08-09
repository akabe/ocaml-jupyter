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
open Jupyter.Iopub
open Jupyter.Shell
open Jupyter_repl.Evaluation

let pp_status ppf status =
  [%yojson_of: Jupyter.Shell.status] status
  |> Yojson.Safe.to_string
  |> pp_print_string ppf

let pp_reply ppf reply =
  [%yojson_of: Jupyter.Iopub.reply] reply
  |> Yojson.Safe.to_string
  |> pp_print_string ppf

(* starting from 5.03 the error message can have a difference number of new lines probably from a race condition, remove all \n before comparing *)
let remove_newlines s =
String.split_on_char '\n' s
  |> List.filter (fun x -> not (String.trim x = ""))
  |> String.concat ""

let clean_newlines rep =
match rep with
| IOPUB_ERROR error -> IOPUB_ERROR { error with traceback = List.map remove_newlines error.traceback }
(* ppx below can fail too on the newline however it is not IOPUB_ERROR *)
(*| IOPUB_EXECUTE_RESULT result -> IOPUB_EXECUTE_RESULT { result with exres_data = List.map remove_newlines result.exres_data }*)
| other -> other

let eval ?(count = 0) code =
  let replies = ref [] in
  let send r = replies := r :: !replies in
  let status = eval ~send ~count code in
  (status, List.map clean_newlines (List.rev !replies))

let test__simple_phrase ctxt =
  let status, actual = eval "let x = (4 + 1) * 3" in
  let expected = [iopub_success ~count:0 "val x : int = 15\n"] in
  assert_equal ~ctxt ~printer:[%show: status] SHELL_OK status ;
  assert_equal ~ctxt ~printer:[%show: reply list] expected actual

let test__multiple_phrases ctxt =
  let status, actual = eval
      "let x = (4 + 1) * 3\n\
       let y = \"Hello \" ^ \"World\"\n\
       let z = List.map (fun x -> x * 2) [1; 2; 3]\n" in
  let expected = [
    iopub_success ~count:0 "val x : int = 15\n";
    iopub_success ~count:0 "val y : string = \"Hello World\"\n";
    iopub_success ~count:0 "val z : int list = [2; 4; 6]\n";
  ] in
  assert_equal ~ctxt ~printer:[%show: status] SHELL_OK status ;
  assert_equal ~ctxt ~printer:[%show: reply list] expected actual

let test__directive ctxt =
  let status, actual = eval "#directory \"+str\" ;; #load \"str.cma\" ;; Str.regexp \".*\"" in
  let expected = [iopub_success ~count:0 "- : Str.regexp = <abstr>\n" ] in
  assert_equal ~ctxt ~printer:[%show: status] SHELL_OK status ;
  assert_equal ~ctxt ~printer:[%show: reply list] expected actual

(* Implementation of [#trace] directive changes after OCaml 4.13.0. *)
let test__trace_directive ctxt =
  let status, actual = eval "let f x = x ;; #trace f ;; f 10 ;;" in
  let expected = [
    iopub_success ~count:0 "val f : 'a -> 'a = <fun>\n";
    iopub_success ~count:0 "f is now traced.\n";
    iopub_success ~count:0 "f <-- <poly>\n\
                            f --> <poly>\n\
                            - : int = 10\n";
  ] in
  assert_equal ~ctxt ~printer:[%show: status] SHELL_OK status ;
  assert_equal ~ctxt ~printer:[%show: reply list] expected actual

let test__external_command ctxt =
  let status, actual = eval "Sys.command \"ls -l >/dev/null 2>/dev/null\"" in
  let expected = [iopub_success ~count:0 "- : int = 0\n"] in
  assert_equal ~ctxt ~printer:[%show: status] SHELL_OK status ;
  assert_equal ~ctxt ~printer:[%show: reply list] expected actual

let test__syntax_error ctxt =
  let status, actual = eval ~count:123 "let let let\nlet" in
  let expected =
    [error ~value:"compile_error"
       [if Sys.ocaml_version >= "4.08"
        then "File \"[123]\", line 1, characters 4-7:\
              \n1 | let let let\
              \n        ^^^\
              \nError: Syntax error\n"
        else "\x1b[32mFile \"[123]\", line 1, characters 4-7:\
              \n\x1b[31mError: Syntax error\
              \n\x1b[36m   1: \x1b[30mlet \x1b[4mlet\x1b[0m\x1b[30m let\
              \n\x1b[36m   2: \x1b[30mlet\x1b[0m\n"]] in
  assert_equal ~ctxt ~printer:[%show: status] SHELL_ERROR status ;
  assert_equal ~ctxt ~printer:[%show: reply list] (List.map clean_newlines expected) actual

let test__unbound_value ctxt =
  let status, actual = eval ~count:123 "foo 42" in
  let expected =
    [error ~value:"compile_error"
       [if Sys.ocaml_version >= "4.08"
        then "File \"[123]\", line 1, characters 0-3:\
              \n1 | foo 42\
              \n    ^^^\
              \nError: Unbound value foo\n"
        else "\x1b[32mFile \"[123]\", line 1, characters 0-3:\
              \n\x1b[31mError: Unbound value foo\
              \n\x1b[36m   1: \x1b[30m\x1b[4mfoo\x1b[0m\x1b[30m 42\x1b[0m\n"]] in
  assert_equal ~ctxt ~printer:[%show: status] SHELL_ERROR status ;
  assert_equal ~ctxt ~printer:[%show: reply list] (List.map clean_newlines expected) actual

let test__type_error ctxt =
  let status, actual = eval ~count:123 "42 = true" in
  let expected =
    [error ~value:"compile_error"
       [if Sys.ocaml_version >= "5.3"
        then "File \"[123]\", line 1, characters 5-9:\n\
              1 | 42 = true\n         \
              ^^^^\nError: The constructor true has type bool\n       but an expression was expected of type int\n"
        else if Sys.ocaml_version >= "5.2"
        then "File \"[123]\", line 1, characters 5-9:\n\
              1 | 42 = true         \
              ^^^^Error: This expression has type bool but an expression was expected of type         int"
        else if Sys.ocaml_version >= "4.08"
        then "File \"[123]\", line 1, characters 5-9:\
              \n1 | 42 = true\
              \n         ^^^^\
              \nError: This expression has type bool but an expression was expected of type\
              \n         int\n"
        else "\x1b[32mFile \"[123]\", line 1, characters 5-9:\
              \n\x1b[31mError: This expression has type bool but an expression was expected of type\
              \n         int\
              \n\x1b[36m   1: \x1b[30m42 = \x1b[4mtrue\x1b[0m\n"]] in
  assert_equal ~ctxt ~printer:[%show: status] SHELL_ERROR status ;
  assert_equal ~ctxt ~printer:[%show: reply list] (List.map clean_newlines expected) actual

let test__long_error_message ctxt =
  let status, actual = eval ~count:123
      "let a = 42 in\n\
       let b = 43 in\n\
       let c = foo in\n\
       let d = 44 in\n\
       ()" in
  let expected =
    [error ~value:"compile_error"
       [if Sys.ocaml_version >= "4.08"
        then "File \"[123]\", line 3, characters 8-11:\
              \n3 | let c = foo in\
              \n            ^^^\
              \nError: Unbound value foo\n"
        else "\x1b[32mFile \"[123]\", line 3, characters 8-11:\
              \n\x1b[31mError: Unbound value foo\
              \n\x1b[36m   2: \x1b[30mlet b = 43 in\
              \n\x1b[36m   3: \x1b[30mlet c = \x1b[4mfoo\x1b[0m\x1b[30m in\
              \n\x1b[36m   4: \x1b[30mlet d = 44 in\x1b[0m\n"]] in
  assert_equal ~ctxt ~printer:[%show: status] SHELL_ERROR status ;
  assert_equal ~ctxt ~printer:[%show: reply list] (List.map clean_newlines expected) actual ;
  let status, actual = eval ~count:123 "List.\n dummy" in
  let expected =
    [error ~value:"compile_error"
       [if Sys.ocaml_version >= "5.00"
        then "\nFile \"[123]\", lines 1-2, characters 0-6:\
              \n1 | List.\
              \n2 |  dummy\
              \nError: Unbound value List.dummy\n"
        else if Sys.ocaml_version >= "4.09"
        then "File \"[123]\", lines 1-2, characters 0-6:\
              \n1 | List.\
              \n2 |  dummy\
              \nError: Unbound value List.dummy\n"
        else if Sys.ocaml_version >= "4.08"
        then "File \"[123]\", line 1, characters 0-12:\
              \n1 | List.\
              \n2 |  dummy\
              \nError: Unbound value List.dummy\n"
        else "\x1b[32mFile \"[123]\", line 1, characters 0-12:\
              \n\x1b[31mError: Unbound value List.dummy\
              \n\x1b[36m   1: \x1b[30m\x1b[4mList.\x1b[0m\
              \n\x1b[36m   2: \x1b[30m\x1b[4m dummy\x1b[0m\n"]] in
  assert_equal ~ctxt ~printer:[%show: status] SHELL_ERROR status ;
  assert_equal ~ctxt ~printer:[%show: reply list] (List.map clean_newlines expected) actual

let test__exception ctxt =
  let status, actual = eval "failwith \"FAIL\"" in
  let msg =
    if Sys.ocaml_version >= "5.03"
    then"\x1b[31mException: Failure \"FAIL\".\n\
          Raised at Stdlib.failwith in file \"stdlib.ml\", line 29, characters 17-33\n\
          Called from <unknown> in file \"[0]\", line 1, characters 0-15\n\
          Called from Topeval.load_lambda in file \"toplevel/byte/topeval.ml\", line 93, characters 4-14\n\
          \x1b[0m"
    else if Sys.ocaml_version >= "5.00"
    then "\x1b[31mException: Failure \"FAIL\".\n\
          Raised at Stdlib.failwith in file \"stdlib.ml\", line 29, characters 17-33\n\
          Called from Topeval.load_lambda in file \"toplevel/byte/topeval.ml\", line 89, characters 4-14\n\
          \x1b[0m"
    else if Sys.ocaml_version >= "4.13"
    then "\x1b[31mException: Failure \"FAIL\".\n\
          Raised at Stdlib.failwith in file \"stdlib.ml\", line 29, characters 17-33\n\
          Called from Stdlib__Fun.protect in file \"fun.ml\", line 33, characters 8-15\n\
          Re-raised at Stdlib__Fun.protect in file \"fun.ml\", line 38, characters 6-52\n\
          Called from Topeval.load_lambda in file \"toplevel/byte/topeval.ml\", line 89, characters 4-150\n\
          \x1b[0m"
    else if Sys.ocaml_version >= "4.12"
    then "\x1b[31mException: Failure \"FAIL\".\n\
          Raised at Stdlib.failwith in file \"stdlib.ml\", line 29, characters 17-33\n\
          Called from Stdlib__fun.protect in file \"fun.ml\", line 33, characters 8-15\n\
          Re-raised at Stdlib__fun.protect in file \"fun.ml\", line 38, characters 6-52\n\
          Called from Toploop.load_lambda in file \"toplevel/toploop.ml\", line 212, characters 4-150\n\
          \x1b[0m"
    else if Sys.ocaml_version >= "4.11"
    then "\x1b[31mException: Failure \"FAIL\".\n\
          Raised at Stdlib.failwith in file \"stdlib.ml\", line 29, characters 17-33\n\
          Called from Toploop.load_lambda in file \"toplevel/toploop.ml\", line 212, characters 17-27\n\x1b[0m"
    else if Sys.ocaml_version >= "4.10"
    then "\x1b[31mException: Failure \"FAIL\".\n\
          Raised at file \"stdlib.ml\", line 29, characters 22-33\n\
          Called from file \"toplevel/toploop.ml\", line 212, characters 17-27\n\x1b[0m"
    else if Sys.ocaml_version >= "4.08"
    then "\x1b[31mException: Failure \"FAIL\".\n\
          Raised at file \"stdlib.ml\", line 29, characters 22-33\n\
          Called from file \"toplevel/toploop.ml\", line 208, characters 17-27\n\x1b[0m"
    else if Sys.ocaml_version <= "4.02.3"
    then "\x1b[31mException: Failure \"FAIL\".\n\x1b[0m"
    else if Sys.ocaml_version <= "4.06.1"
    then "\x1b[31mException: Failure \"FAIL\".\n\
          Raised at file \"pervasives.ml\", line 32, characters 22-33\n\
          Called from file \"toplevel/toploop.ml\", line 180, characters 17-56\n\x1b[0m"
    else "\x1b[31mException: Failure \"FAIL\".\n\
          Raised at file \"stdlib.ml\", line 33, characters 22-33\n\
          Called from file \"toplevel/toploop.ml\", line 180, characters 17-56\n\x1b[0m"
  in
  let expected = [error ~value:"runtime_error" [msg]] in
  assert_equal ~ctxt ~printer:[%show: status] SHELL_ERROR status ;
  assert_equal ~ctxt ~printer:[%show: reply list] (List.map clean_newlines expected) actual

let test__unknown_directive ctxt =
  let status, actual = eval "#foo" in
  let msg =
    if Sys.ocaml_version >= "5.03"
    then "\x1b[31mUnknown directive foo.\x1b[0m"
    else "\x1b[31mUnknown directive `foo'.\x1b[0m" in
  let expected = [error ~value:"runtime_error"
                    [msg]] in
  assert_equal ~ctxt ~printer:[%show: status] SHELL_ERROR status ;
  assert_equal ~ctxt ~printer:[%show: reply list] expected actual

let test__ppx ctxt =
  let status, actual = eval "#require \"ppx_deriving.show\" ;; \
                             type t = { x : int } [@@deriving show]" in
  let expected =
    [iopub_success ~count:0
       "type t = { x : int; }\n\
        val pp :\n  \
        Ppx_deriving_runtime.Format.formatter -> t -> Ppx_deriving_runtime.unit =\n  \
        <fun>\n\
        val show : t -> Ppx_deriving_runtime.string = <fun>\n"] in
  assert_equal ~ctxt ~printer:[%show: status] SHELL_OK status ;
  assert_equal ~ctxt ~printer:[%show: reply list] expected actual

let suite =
  "Evaluation" >::: [
    "eval" >::: [
      "simple_phrase" >:: test__simple_phrase;
      "multiple_phrases" >:: test__multiple_phrases;
      "directive" >:: test__directive;
      "#trace directive" >:: test__trace_directive;
      "external_command" >:: test__external_command;
      "syntax_error" >:: test__syntax_error;
      "unbound_value" >:: test__unbound_value;
      "type_error" >:: test__type_error;
      "long_error_message" >:: test__long_error_message;
      "exception" >:: test__exception;
      "unknown_directive" >:: test__unknown_directive;
      "ppx" >:: test__ppx;
    ]
  ]

let () =
  init ~init_file:"fixtures/ocamlinit.ml" () ;
  run_test_tt_main suite;
  ()
