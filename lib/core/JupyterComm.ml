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

(** User-defined communication *)

open Format

module Msg = JupyterCommMessage

type 'ctx handler =
  {
    on_open : JupyterCommMessage.comm -> 'ctx;
    on_msg : JupyterCommMessage.comm -> 'ctx -> 'ctx;
    on_close : JupyterCommMessage.comm -> 'ctx -> unit;
  }

type target = T : 'a handler -> target
type comm = C : 'a ref * 'a handler -> comm

type t =
  {
    target_tbl : (string, target) Hashtbl.t;
    comm_tbl : (string, comm) Hashtbl.t;
  }

let create () =
  {
    target_tbl = Hashtbl.create 8;
    comm_tbl = Hashtbl.create 8;
  }

let register cm target_name handler =
  Hashtbl.replace cm.target_tbl target_name (T handler)

let unregister cm target_name = Hashtbl.remove cm.target_tbl target_name

(** {2 Receivers} *)

let recv_open cm req =
  match req.Msg.target_name with
  | None -> eprintf "[ERROR] comm_open requires field \"target_name\"\n%!"
  | Some target_name ->
    try
      let (T target) = Hashtbl.find cm.target_tbl target_name in
      let acc = target.on_open req in
      Hashtbl.replace cm.comm_tbl req.Msg.comm_id (C (ref acc, target))
    with Not_found ->
      eprintf "[ERROR] No such comm target %S\n%!" target_name

let recv_close cm req =
  try
    let (C (acc, comm)) = Hashtbl.find cm.comm_tbl req.Msg.comm_id in
    comm.on_close req !acc ;
    Hashtbl.remove cm.comm_tbl req.Msg.comm_id
  with Not_found ->
    eprintf "[ERROR] No such comm_id %S\n%!" req.Msg.comm_id

let recv_msg cm req =
  try
    let (C (acc, comm)) = Hashtbl.find cm.comm_tbl req.Msg.comm_id in
    acc := comm.on_msg req !acc
  with Not_found ->
    eprintf "[ERROR] No such comm_id %S\n%!" req.Msg.comm_id
