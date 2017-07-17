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

open OUnit2

module Hmac = JupyterHmac

(** Success patterns of HMAC computation *)
let test_create__normal ctxt =
  let open Fixture.KernelInfoRequest in
  let key = Cstruct.of_string key in
  let actual = Hmac.create ~key ~header ~parent_header ~metadata ~content () in
  assert_equal ~ctxt ~printer:[%show: string] actual hmac ;
  let open Fixture.ExecuteRequest in
  let key = Cstruct.of_string key in
  let actual = Hmac.create ~key ~header ~parent_header ~metadata ~content () in
  assert_equal ~ctxt ~printer:[%show: string] actual hmac

(** Return an empty string if no key is given. *)
let test_create__nokey ctxt =
  let open Fixture.KernelInfoRequest in
  let actual = Hmac.create ~header ~parent_header ~metadata ~content () in
  assert_equal ~ctxt ~printer:[%show: string] actual "" ;
  let open Fixture.ExecuteRequest in
  let actual = Hmac.create ~header ~parent_header ~metadata ~content () in
  assert_equal ~ctxt ~printer:[%show: string] actual ""

(** Success patterns of HMAC validation *)
let test_validate__success _ =
  let open Fixture.KernelInfoRequest in
  let key = Cstruct.of_string key in
  Hmac.validate ~key ~hmac ~header ~parent_header ~metadata ~content () ;
  let open Fixture.ExecuteRequest in
  let key = Cstruct.of_string key in
  Hmac.validate ~key ~hmac ~header ~parent_header ~metadata ~content ()

(** Raises an exception if validation failed. *)
let test_validate__failure _ =
  let open Fixture.KernelInfoRequest in
  let key = Cstruct.of_string key in
  assert_raises (Failure "HMAC validation failed")
    (fun () ->
       Hmac.validate ~key ~hmac:"" ~header ~parent_header ~metadata ~content ()) ;
  let open Fixture.ExecuteRequest in
  let key = Cstruct.of_string key in
  assert_raises (Failure "HMAC validation failed")
    (fun () ->
       Hmac.validate ~key ~hmac:"" ~header ~parent_header ~metadata ~content ())

(** Don't check if no key is given. *)
let test_validate__nokey _ =
  let open Fixture.KernelInfoRequest in
  Hmac.validate ~hmac ~header ~parent_header ~metadata ~content () ;
  let open Fixture.ExecuteRequest in
  Hmac.validate ~hmac ~header ~parent_header ~metadata ~content ()

let suite =
  "Hmac" >::: [
    "create" >::: [
      "normal" >:: test_create__normal;
      "no key" >:: test_create__nokey;
    ];
    "validate" >::: [
      "success" >:: test_validate__success;
      "failure" >:: test_validate__failure;
      "nokey" >:: test_validate__nokey;
    ];
  ]
