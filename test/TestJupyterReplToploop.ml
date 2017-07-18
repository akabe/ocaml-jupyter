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
open JupyterRepl
open Jupyter.ReplMessage
open TestUtil

let rec cmp xs ys =
  match xs, ys with
  | [], [] -> true
  | x :: xs, y :: ys when x = y -> cmp xs ys
  (* Check a pattern of an error message
     (concrete error messages depend in OCaml versions) *)
  | Runtime_error pattern :: xs, Runtime_error msg :: ys
  | Compile_error pattern :: xs, Compile_error msg :: ys ->
    begin
      try
        ignore (Str.search_forward (Str.regexp pattern) msg 0) ;
        cmp xs ys
      with Not_found -> false
    end
  | _ -> false

let exec code =
  Toploop.run ~filename:"//toplevel//" ~f:(fun rs r -> r :: rs) ~init:[] code
  |> List.rev

(** {2 Test suite} *)

let test__simple_phrase ctxt =
  let actual = exec "let x = (4 + 1) * 3" in
  let expected = [Ok "val x : int = 15\n"] in
  assert_equal ~ctxt ~cmp expected actual

let test__multiple_phrases ctxt =
  let actual = exec
      "let x = (4 + 1) * 3\n\
       let y = \"Hello \" ^ \"World\"\n\
       let z = List.map (fun x -> x * 2) [1; 2; 3]\n" in
  let expected = [
    Ok "val x : int = 15\n";
    Ok "val y : string = \"Hello World\"\n";
    Ok "val z : int list = [2; 4; 6]\n";
  ] in
  assert_equal ~ctxt ~cmp expected actual

let test__directive ctxt =
  let actual = exec "#load \"str.cma\" ;; Str.regexp" in
  let expected = [Ok "- : string -> Str.regexp = <fun>\n"] in
  assert_equal ~ctxt ~cmp expected actual

let test__external_command ctxt =
  let actual = exec "Sys.command \"ls -l >/dev/null 2>/dev/null\"" in
  let expected = [Ok "- : int = 0\n"] in
  assert_equal ~ctxt ~cmp expected actual

let test__syntax_error ctxt =
  let actual = exec "let let let" in
  let expected = [Compile_error "Syntax error"] in
  assert_equal ~ctxt ~cmp expected actual

let test__unbound_value ctxt =
  let actual = exec "foo 42" in
  let expected = [Compile_error "Unbound value foo"] in
  assert_equal ~ctxt ~cmp expected actual

let test__type_error ctxt =
  let actual = exec "42 = true" in
  let expected = [
    Compile_error "Error: This expression has type bool \
                   but an expression was expected of type\
                   \n         int"] in
  assert_equal ~ctxt ~cmp expected actual

let test__exception ctxt =
  let actual = exec "failwith \"FAIL\"" in
  let expected = [Runtime_error "Failure \"FAIL\""] in
  assert_equal ~ctxt ~cmp expected actual

let test__unknown_directive ctxt =
  let actual = exec "#foo" in
  let expected = [Runtime_error "Unknown directive `foo'.\n"] in
  assert_equal ~ctxt ~cmp expected actual

let test__ppx ctxt =
  let actual = exec "#require \"ppx_deriving.show\" ;; \
                     type t = { x : int } [@@deriving show]" in
  let expected = [
    Ok "type t = { x : int; }\n\
        val pp : Format.formatter -> t -> Ppx_deriving_runtime.unit = <fun>\n\
        val show : t -> Ppx_deriving_runtime.string = <fun>\n"
  ] in
  assert_equal ~ctxt ~cmp expected actual

let test__camlp4 ctxt =
  let _ = exec "#camlp4o ;;" in
  let actual = exec "[< '1 ; '2 >]" in
  let expected = [Ok "- : int Stream.t = <abstr>\n"] in
  assert_equal ~ctxt ~cmp expected actual

let () = Toploop.init ~init_file:"fixtures/.ocamlinit" ()

let suite =
  "Toploop" >::: [
    "simple_phrase" >:: test__simple_phrase;
    "multiple_phrase" >:: test__multiple_phrases;
    "directive" >:: test__directive;
    "external_command" >:: test__external_command;
    "syntax_error" >:: test__syntax_error;
    "unbound_value" >:: test__unbound_value;
    "type_error" >:: test__type_error;
    "exception" >:: test__exception;
    "unknown_directive" >:: test__unknown_directive;
    "ppx" >:: test__ppx;
    "camlp4" >:: test__camlp4;
  ]
