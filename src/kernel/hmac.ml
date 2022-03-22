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

(** HMAC verification *)

type t = string

let create key = key

let hexa = Cryptokit.Hexa.encode ()

let encode ?key ~header ~parent_header ~metadata ~content () =
  match key with
  | None -> ""
  | Some key ->
    let hash = Cryptokit.MAC.hmac_sha256 key in
    (header ^ parent_header ^ metadata ^ content)
    |> Cryptokit.hash_string hash
    |> Cryptokit.transform_string hexa

let validate ?key ~hmac ~header ~parent_header ~metadata ~content () =
  match key with
  | None -> () (* don't check HMAC *)
  | Some key ->
    let e_hmac = encode ~key ~header ~parent_header ~metadata ~content () in
    if e_hmac <> hmac then failwith "HMAC validation failed"
