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

let to_hex_char i =
  if 0 <= i && i <= 9
  then Char.chr (i + Char.code '0')
  else Char.chr (i + Char.code 'a' - 10)

let to_hex_string cstr =
  let n = Cstruct.len cstr in
  let b = Bytes.create (n * 2) in
  for i = 0 to n - 1 do
    let c = Cstruct.get_uint8 cstr i in
    let j = 2 * i in
    Bytes.set b j     @@ to_hex_char (c lsr 4) ;
    Bytes.set b (j+1) @@ to_hex_char (c land 0xf)
  done ;
  Bytes.to_string b

let create ?key ~header ~parent_header ~metadata ~content () =
  match key with
  | None -> ""
  | Some key ->
    (header ^ parent_header ^ metadata ^ content)
    |> Cstruct.of_string
    |> Nocrypto.Hash.SHA256.hmac ~key
    |> to_hex_string

let validate ?key ~hmac ~header ~parent_header ~metadata ~content () =
  match key with
  | None -> () (* don't check HMAC *)
  | Some key ->
    let e_hmac = create ~key ~header ~parent_header ~metadata ~content () in
    if e_hmac <> hmac then failwith "HMAC validation failed"
