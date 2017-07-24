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

(** Communication manager *)

type target_id = string
type comm_id = string

type handler =
  {
    on_open : comm_id -> Yojson.Safe.json -> unit;
    on_recv : comm_id -> Yojson.Safe.json -> unit;
    on_close : comm_id -> Yojson.Safe.json -> unit;
  }

module KM = JupyterKernelMessage
module CM = JupyterCommMessage

module Target =
struct
  let target_tbl : (target_id, handler) Hashtbl.t = Hashtbl.create 4

  let default_handler _ _ = ()

  let register
      ?(on_open = default_handler)
      ?(on_recv = default_handler)
      ?(on_close = default_handler)
      target_name =
    let handler = { on_open; on_recv; on_close; } in
    Hashtbl.replace target_tbl target_name handler ;
    target_name

  let unregister target_name = Hashtbl.remove target_tbl target_name
end

module Comm =
struct
  let comm_tbl : (comm_id, handler) Hashtbl.t = Hashtbl.create 16

  let default = `Assoc []

  let add_comm target_name comm_id =
    let handler = Hashtbl.find Target.target_tbl target_name in
    Hashtbl.replace comm_tbl comm_id handler

  (** {2 Send messages} *)

  let create ?(data = default) target_name =
    let comm_id = Uuidm.(to_string (create `V4)) in
    add_comm target_name comm_id ;
    let msg = JupyterCommMessage.(`Comm_open {
        target_name = Some target_name;
        comm_id; data;
      })
    in
    JupyterNotebookUnsafe.send_iopub msg ;
    comm_id

  let close ?(data = default) comm_id =
    let msg = JupyterCommMessage.(`Comm_close {
        target_name = None;
        comm_id; data;
      })
    in
    JupyterNotebookUnsafe.send_iopub msg

  let send ?(data = default) comm_id =
    let msg = JupyterCommMessage.(`Comm_msg {
        target_name = None;
        comm_id; data;
      })
    in
    JupyterNotebookUnsafe.send_iopub msg
end

let recv_open comm =
  match comm.CM.target_name with
  | None -> ()
  | Some target_name ->
    try
      let handler = Hashtbl.find Target.target_tbl target_name in
      Hashtbl.replace Comm.comm_tbl comm.CM.comm_id handler ;
      handler.on_open comm.CM.comm_id comm.CM.data
    with Not_found -> ()

let recv_close comm =
  try
    let handler = Hashtbl.find Comm.comm_tbl comm.CM.comm_id in
    handler.on_close comm.CM.comm_id comm.CM.data ;
    Hashtbl.remove Comm.comm_tbl comm.CM.comm_id
  with Not_found -> ()

let recv_msg comm =
  try
    let handler = Hashtbl.find Comm.comm_tbl comm.CM.comm_id in
    handler.on_recv comm.CM.comm_id comm.CM.data
  with Not_found -> ()

(*
let _ =
  let rec loop () =
    match JupyterNotebookUnsafe.recv () with
    | `Shell msg ->
      begin
        match msg.KM.content with
        | `Comm_open comm -> recv_open comm
        | `Comm_msg comm -> recv_msg comm
        | `Comm_close comm -> recv_close comm
      end ;
      loop ()
  in
  let main () =
    ignore (Thread.sigmask Unix.SIG_SETMASK [Sys.sigint]) ;
    loop ()
  in
  Thread.create main ()
  *)
