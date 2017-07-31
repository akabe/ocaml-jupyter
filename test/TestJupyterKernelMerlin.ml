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

open Lwt.Infix
open OUnit2
open JupyterKernelMerlin

let test_extract_prefix__uident ctxt =
  let actual = extract_prefix "let _ = Lwt_m " 13 in
  let expected = Some (8, 13) in
  assert_equal ~ctxt ~printer:[%show: (int * int) option] expected actual

let test_extract_prefix__lident ctxt =
  let actual = extract_prefix "let _ = Lwt_io.read_ " 20 in
  let expected = Some (8, 20) in
  assert_equal ~ctxt ~printer:[%show: (int * int) option] expected actual

let merlin = create ~dot_merlin:"../.merlin" ()

let result_to_yojson f g = function
  | Result.Ok x -> `List [`String "Ok"; f x]
  | Result.Error y -> `List [`String "Error"; g y]

let printer reply =
  [%to_yojson: (complete_reply, Yojson.Safe.json) result] reply
  |> Yojson.Safe.to_string

let run_complete ?context merlin code pos =
  complete ?context merlin code pos
  |> Lwt_main.run
  |> function
  | Result.Ok reply -> Result.Ok { reply with entries = List.sort compare reply.entries }
  | Result.Error e -> Result.Error e

let test_complete__value ctxt =
  let actual = run_complete merlin "let _ = read_ " 13 in
  let expected = Result.Ok {
      entries = [
        {
          name = "read_float";
          kind = `Value;
          desc = "unit -> float";
          info = "";
        };
        {
          name = "read_int";
          kind = `Value;
          desc = "unit -> int";
          info = "";
        };
        {
          name = "read_line";
          kind = `Value;
          desc = "unit -> string";
          info = "";
        };
      ];
      cursor_start = 8;
      cursor_end = 13;
    } in
  assert_equal ~ctxt ~printer expected actual

let test_complete__module ctxt =
  let actual = run_complete merlin "Lis " 3 in
  let expected = Result.Ok {
      entries = [
        {
          name = "List";
          kind = `Module;
          desc = "";
          info = "";
        };
        {
          name = "ListLabels";
          kind = `Module;
          desc = "";
          info = "";
        };
      ];
      cursor_start = 0;
      cursor_end = 3;
    } in
  assert_equal ~ctxt ~printer expected actual

let test_complete__exn ctxt =
  let actual = run_complete merlin "let _ = raise Sys.Bre " 21 in
  let expected = Result.Ok {
      entries = [
        {
          name = "Break";
          kind = `Constructor;
          desc = "exn";
          info = "";
        };
      ];
      cursor_start = 18;
      cursor_end = 21;
    } in
  assert_equal ~ctxt ~printer expected actual

let test_complete__context ctxt =
  let actual = run_complete ~context:"open Array" merlin "mapi" 4 in
  let expected = Result.Ok {
      entries = [
        {
          name = "mapi";
          kind = `Value;
          desc = "(int -> 'a -> 'b) -> 'a array -> 'b array";
          info = "";
        };
      ];
      cursor_start = 0;
      cursor_end = 4;
    } in
  assert_equal ~ctxt ~printer expected actual

let test_complete__no_bin ctxt =
  let merlin = create ~bin_path:"dummy_ocamlmerlin" () in
  let actual = Lwt_main.run @@ complete merlin "let _ = read_ " 13 in
  let expected = Result.Error (`String "merlin crashed or not found ocamlmerlin") in
  assert_equal ~ctxt ~printer expected actual

let suite =
  "JupyterKernelMerlin" >::: [
    "extract_prefix" >::: [
      "uident" >:: test_extract_prefix__uident;
      "lident" >:: test_extract_prefix__lident;
    ];
    "complete" >::: [
      "value" >:: test_complete__value;
      "module" >:: test_complete__module;
      "exn" >:: test_complete__exn;
      "context" >:: test_complete__context;
      "no_bin" >:: test_complete__no_bin;
    ];
  ]
