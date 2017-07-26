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

(** {2 User-defined communication} *)

open Format

module CM = Jupyter.CommMessage

type target = string
type comm = string

type receiver =
  {
    target_name : string;
    recv_open : comm -> Yojson.Safe.json -> unit;
    recv_msg : comm -> Yojson.Safe.json -> unit;
    recv_close : comm -> Yojson.Safe.json -> unit;
  }

module Target =
struct
  type t = target

  let target_tbl = Hashtbl.create 4

  let to_string target_name = target_name

  let default _ _ = ()

  let create
      ?(recv_open = default)
      ?(recv_msg = default)
      ?(recv_close = default)
      target_name =
    let receiver = { target_name; recv_open; recv_msg; recv_close } in
    Hashtbl.replace target_tbl target_name receiver ;
    target_name

  let close target_name = Hashtbl.remove target_tbl target_name
end

module Comm =
struct
  type t = comm

  let comm_tbl = Hashtbl.create 8

  let to_string comm_id = comm_id

  let comms ?target_name () =
    let filter_by_target_name all_comms =
      match target_name with
      | None -> all_comms
      | Some target_name ->
        List.filter
          (fun (_, target_name') -> target_name = target_name')
          all_comms
    in
    Hashtbl.fold
      (fun comm_id receiver acc -> (comm_id, receiver.target_name) :: acc)
      comm_tbl []
    |> filter_by_target_name

  let register target_name comm_id =
    let receiver = Hashtbl.find Target.target_tbl target_name in
    Hashtbl.replace comm_tbl comm_id receiver ;
    receiver

  (** {2 Send} *)

  let default = `Assoc []

  let create ?(data = default) target_name =
    let comm_id = Uuidm.(to_string (create `V4)) in
    ignore (register target_name comm_id) ;
    JupyterNotebookUnsafe.send_iopub
      (`Comm_open CM.{ target_name = Some target_name; comm_id; data; }) ;
    comm_id

  let send comm_id data =
    JupyterNotebookUnsafe.send_iopub
      (`Comm_msg CM.{ target_name = None; comm_id; data; })

  let close ?(data = default) comm_id =
    JupyterNotebookUnsafe.send_iopub
      (`Comm_close CM.{ target_name = None; comm_id; data; })

  (** {2 Receive} *)

  let recv_open comm =
    match comm.CM.target_name with
    | None -> eprintf "Received a comm message without target_name.@."
    | Some target_name ->
      try
        let receiver = register target_name comm.CM.comm_id in
        receiver.recv_open comm.CM.comm_id comm.CM.data
      with Not_found -> ()

  let recv_msg comm =
    try
      let receiver = Hashtbl.find comm_tbl comm.CM.comm_id in
      receiver.recv_msg comm.CM.comm_id comm.CM.data
    with Not_found -> ()

  let recv_close comm =
    try
      let receiver = Hashtbl.find comm_tbl comm.CM.comm_id in
      receiver.recv_close comm.CM.comm_id comm.CM.data ;
      Hashtbl.remove comm_tbl comm.CM.comm_id
    with Not_found -> ()

  let recv = function
    | `Comm_open comm -> recv_open comm
    | `Comm_msg comm -> recv_msg comm
    | `Comm_close comm -> recv_close comm
end
