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
open Jupyter_completor

(** {2 Merlin.occurrences} *)

let pp_ident_reply ppf reply =
  [%yojson_of: Merlin.ident_reply] reply
  |> Yojson.Safe.to_string
  |> pp_print_string ppf

let occurrences ~pos merlin code =
  Merlin.occurrences merlin code ~pos
  |> Lwt_main.run

let test_occurrences ctxt =
  let require ?msg x y = assert_equal ~ctxt ~printer:[%show: ident_reply list] ?msg x y in
  let merlin = Merlin.create () in
  let code = "let _ = Lwt_m " in
  let expected = Merlin.([
      { id_start = { id_line=1; id_col=8; }; id_end = { id_line=1; id_col=13 } }
    ]) in
  let actual = occurrences merlin code ~pos:13 in
  require expected actual ~msg:"at the end of identifier" ;
  let actual = occurrences merlin code ~pos:10 in
  require expected actual ~msg:"at a middle position in identifier" ;
  let actual = occurrences merlin code ~pos:8 in
  require expected actual ~msg:"at the head of identifier" ;
  let actual = occurrences merlin code ~pos:14 in
  require [] actual ~msg:"not found" ;
  let code = "let x = 15\nlet y = 42\nlet z = Lwt_m \nlet w = 123" in
  let expected = Merlin.([
      { id_start = { id_line=3; id_col=8; }; id_end = { id_line=3; id_col=13 } }
    ]) in
  let actual = occurrences merlin code ~pos:32 in
  require expected actual ~msg:"multi-line code"

let test_abs_position ctxt =
  let require ?msg x y = assert_equal ~ctxt ~printer:[%show: int] ?msg x y in
  let code = "let x = 15\nlet y = 42\nlet z = Lwt_m \nlet w = 123" in
  let actual = Merlin.(abs_position code { id_line = 1; id_col = 0; }) in
  require 0 actual ~msg:"at the head of the first line" ;
  let actual = Merlin.(abs_position code { id_line = 1; id_col = 5; }) in
  require 5 actual ~msg:"at the middle point in the first line" ;
  let actual = Merlin.(abs_position code { id_line = 1; id_col = 10; }) in
  require 10 actual ~msg:"at the end of the first line" ;
  let actual = Merlin.(abs_position code { id_line = 2; id_col = 0; }) in
  require 11 actual ~msg:"at the head of the second line" ;
  let actual = Merlin.(abs_position code { id_line = 4; id_col = 10; }) in
  require 47 actual ~msg:"at the end of the last line" ;
  let actual = Merlin.(abs_position code { id_line = 1; id_col = 11; }) in
  require 10 actual ~msg:"out of range in the first line" ;
  let actual = Merlin.(abs_position code { id_line = 2; id_col = 11; }) in
  require 21 actual ~msg:"out of range in the second line" ;
  let actual = Merlin.(abs_position code { id_line = 4; id_col = 11; }) in
  require 48 actual ~msg:"out of range in the last line"

(** {2 Merlin.complete} *)

let pp_reply ppf reply =
  [%yojson_of: Merlin.reply] reply
  |> Yojson.Safe.to_string
  |> fprintf ppf "%s"

let complete ?doc ?types merlin ~pos code =
  let reply = Lwt_main.run (Merlin.complete ?doc ?types ~pos merlin code) in
  Merlin.({
      reply with cmpl_candidates = List.sort compare reply.cmpl_candidates
    })

let test_complete ctxt =
  let require ?msg x y = assert_equal ~ctxt ~printer:[%show: reply] ?msg x y in
  let merlin = Merlin.create () in
  let code = "List" in
  let expected = Merlin.{
      cmpl_start = 0; cmpl_end = 4;
      cmpl_candidates = [
        { cmpl_name = "List"; cmpl_kind = CMPL_MODULE;
          cmpl_type = ""; cmpl_doc = ""; };
        { cmpl_name = "ListLabels"; cmpl_kind = CMPL_MODULE;
          cmpl_type = ""; cmpl_doc = ""; };
      ];
    } in
  let actual = complete merlin code ~pos:4 in
  require expected actual ~msg:"at the first of code" ;
  let code = "let _ = List.ma " in
  let expected = Merlin.{
      cmpl_start = 13; cmpl_end = 15;
      cmpl_candidates = [
        { cmpl_name = "map"; cmpl_kind = CMPL_VALUE;
          cmpl_type = "('a -> 'b) -> 'a list -> 'b list";
          cmpl_doc = ""; };
        { cmpl_name = "map2"; cmpl_kind = CMPL_VALUE;
          cmpl_type = "('a -> 'b -> 'c) -> 'a list -> 'b list -> 'c list";
          cmpl_doc = ""; };
        { cmpl_name = "mapi"; cmpl_kind = CMPL_VALUE;
          cmpl_type = "(int -> 'a -> 'b) -> 'a list -> 'b list";
          cmpl_doc = ""; }
      ];
    } in
  let actual = complete merlin ~types:true code ~pos:15 in
  require expected actual ~msg:"at the last of identifier" ;
  let expected = Merlin.{
      cmpl_start = 13; cmpl_end = 15;
      cmpl_candidates = [
        { cmpl_name = "map"; cmpl_kind = CMPL_VALUE;
          cmpl_type = "('a -> 'b) -> 'a list -> 'b list";
          cmpl_doc = ""; };
        { cmpl_name = "map2"; cmpl_kind = CMPL_VALUE;
          cmpl_type = "('a -> 'b -> 'c) -> 'a list -> 'b list -> 'c list";
          cmpl_doc = ""; };
        { cmpl_name = "mapi"; cmpl_kind = CMPL_VALUE;
          cmpl_type = "(int -> 'a -> 'b) -> 'a list -> 'b list";
          cmpl_doc = ""; };
        { cmpl_name = "mem"; cmpl_kind = CMPL_VALUE;
          cmpl_type = "'a -> 'a list -> bool";
          cmpl_doc = ""; };
        { cmpl_name = "mem_assoc"; cmpl_kind = CMPL_VALUE;
          cmpl_type = "'a -> ('a * 'b) list -> bool";
          cmpl_doc = ""; };
        { cmpl_name = "mem_assq"; cmpl_kind = CMPL_VALUE;
          cmpl_type = "'a -> ('a * 'b) list -> bool";
          cmpl_doc = ""; };
        { cmpl_name = "memq"; cmpl_kind = CMPL_VALUE;
          cmpl_type = "'a -> 'a list -> bool";
          cmpl_doc = ""; };
        { cmpl_name = "merge"; cmpl_kind = CMPL_VALUE;
          cmpl_type = "('a -> 'a -> int) -> 'a list -> 'a list -> 'a list";
          cmpl_doc = ""; };
      ];
    } in
  let actual = complete merlin ~types:true code ~pos:14 in
  require expected actual ~msg:"at the middle point of identifier" ;
  let code = "module M = Comp " in
  let expected = Merlin.{
      cmpl_start = 11; cmpl_end = 15;
      cmpl_candidates = [
        { cmpl_name = "Complex"; cmpl_kind = CMPL_MODULE;
          cmpl_type = ""; cmpl_doc = ""; };
      ];
    } in
  let actual = complete merlin code ~pos:15 in
  require expected actual ~msg:"module" 
  (* ;
  Merlin.add_context merlin "#load \"unix.cma\"" ;
  let code = "let _ = Unix.std " in
  let expected = Merlin.{
      cmpl_start = 13; cmpl_end = 16;
      cmpl_candidates = [
        { cmpl_name = "stderr"; cmpl_kind = CMPL_VALUE;
          cmpl_type = "Unix.file_descr"; cmpl_doc = ""; };
        { cmpl_name = "stdin"; cmpl_kind = CMPL_VALUE;
          cmpl_type = "Unix.file_descr"; cmpl_doc = ""; };
        { cmpl_name = "stdout"; cmpl_kind = CMPL_VALUE;
          cmpl_type = "Unix.file_descr"; cmpl_doc = ""; };
      ];
    } in
  let actual = complete merlin code ~types:true ~pos:16 in
  require expected actual ~msg:"context" ;
  let code = "let _ = Unix.EINP " in
  let expected = Merlin.{
      cmpl_start = 13; cmpl_end = 17;
      cmpl_candidates = [
        { cmpl_name = "EINPROGRESS"; cmpl_kind = CMPL_CONSTR;
          cmpl_type = "Unix.error"; cmpl_doc = ""; };
        { cmpl_name = "EINTR"; cmpl_kind = CMPL_CONSTR;
          cmpl_type = "Unix.error"; cmpl_doc = ""; };
        { cmpl_name = "EINVAL"; cmpl_kind = CMPL_CONSTR;
          cmpl_type = "Unix.error"; cmpl_doc = ""; };
      ];
    } in
  let actual = complete merlin code ~types:true ~pos:16 in
  require expected actual ~msg:"variant constructor" *)

let suite =
  "Merlin" >::: [
    "occurrences" >:: test_occurrences;
    "abs_position" >:: test_abs_position;
    "complete" >:: test_complete;
  ]
