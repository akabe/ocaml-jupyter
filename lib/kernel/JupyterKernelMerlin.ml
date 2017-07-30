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

(** Merlin completion

    https://github.com/ocaml/merlin/blob/master/doc/dev/PROTOCOL.md *)

open Format
open Lwt.Infix

type entry_kind =
  [
    | `Value [@name "Value"]
    | `Variant [@name "Variant"]
    | `Constructor [@name "Constructor"]
    | `Label [@name "Label"]
    | `Module [@name "Module"]
    | `Sig [@name "Signature"]
    | `Type [@name "Type"]
    | `Method [@name "Method"]
    | `Method_call [@name "#"]
    | `Exn [@name "Exn"]
    | `Class [@name "Class"]
  ] [@@deriving yojson]

type complete_entry =
  {
    name : string;
    kind : entry_kind JupyterJson.enum;
    desc : string;
    info : string;
  }
[@@deriving yojson { strict = false }]

type complete_reply =
  {
    entries : complete_entry list;
    cursor_start : int [@default 0];
    cursor_end : int [@default 0];
  }
[@@deriving yojson { strict = false }]

type 'a reply_value =
  | Return of 'a [@name "return"]
  | Failure of Yojson.Safe.json [@name "failure"]
  | Error of Yojson.Safe.json [@name "error"]
  | Exception of Yojson.Safe.json [@name "exception"]
[@@deriving of_yojson { strict = false }]

type 'a reply =
  {
    klass : string [@key "class"];
    value : 'a;
    notifications : string list;
  }
[@@deriving of_yojson { strict = false }]

let parse str =
  let reply =
    Yojson.Safe.from_string str
    |> [%of_yojson: Yojson.Safe.json reply]
    |> JupyterJson.or_die
  in
  `List [`String reply.klass; reply.value]
  |> [%of_yojson: complete_reply reply_value]
  |> JupyterJson.or_die
  |> function
  | Return ret -> Result.Ok ret
  | Failure j -> Result.Error j
  | Error j -> Result.Error j
  | Exception j -> Result.Error j

type t =
  {
    bin_path : string;
    dot_merlin : string;
  }

let create ?(bin_path = "ocamlmerlin") ?(dot_merlin = "./.merlin") () =
  { bin_path; dot_merlin; }

let call merlin command flags printer =
  let args =
    merlin.bin_path :: "single" :: command
    :: "-dot-merlin" :: merlin.dot_merlin
    :: flags
  in
  [%to_yojson: string list] args
  |> Yojson.Safe.to_string
  |> JupyterKernelLog.info "Merlin command: %s" ;
  let array_args = Array.of_list args in
  let proc = Lwt_process.open_process ("ocamlmerlin", array_args) in
  let%lwt () = printer proc#stdin in
  let%lwt () = Lwt_io.flush proc#stdin in
  let%lwt () = Lwt_io.close proc#stdin in
  match%lwt Lwt_io.read_line proc#stdout with
  | exception End_of_file ->
    Lwt.return (Result.Error (`String "merlin crashed or not found ocamlmerlin"))
  | str ->
    let%lwt _ = proc#close in
    JupyterKernelLog.debug "Merlin returns: %s" str ;
    Lwt.return (Result.Ok str)

let extract_prefix s pos =
  let j = min (pos - 1) (String.length s - 1) in
  let rec aux = function
    | 0 -> Some (0, j + 1)
    | i ->
      match s.[i] with
      | '0'..'9' | 'a'..'z' | 'A'..'Z' | '_' | '\''
      | '`' | '?' | '~' | '.' | ':' -> aux (pred i)
      | _ when i = j -> None
      | _ -> Some (i + 1, j + 1)
  in
  aux j

let extract_replacement s pos =
  let j = min (pos - 1) (String.length s - 1) in
  let rec aux = function
    | 0 -> (0, j + 1)
    | i ->
      match s.[i] with
      | '0'..'9' | 'a'..'z' | 'A'..'Z' | '_' | '\'' | '`' -> aux (pred i)
      | _ -> (i + 1, j + 1)
  in
  aux j

let string_of_bool b = if b then "y" else "n"

let complete ?(context = "") ?(doc = false) ?(types = true) merlin code position =
  let sep = " ;; " in
  let offset = String.length context + String.length sep in
  match extract_prefix code position with
  | None ->
    JupyterKernelLog.info "completion prefix is not found." ;
    Lwt.return (Result.Ok { entries = []; cursor_start = 0; cursor_end = 0; })
  | Some (i, j) ->
    let prefix = String.sub code i (j - i) in
    JupyterKernelLog.info "completion prefix = %S" prefix ;
    let args = [
      "-position"; string_of_int (j + offset);
      "-prefix"; prefix;
      "-doc"; string_of_bool doc;
      "-types"; string_of_bool types;
    ] in
    let (cursor_start, cursor_end) = extract_replacement code position in
    let printer oc =
      let%lwt () = Lwt_io.write oc context in
      let%lwt () = Lwt_io.write oc sep in
      Lwt_io.write oc code
    in
    match%lwt call merlin "complete-prefix" args printer with
    | Result.Error _ as e -> Lwt.return e
    | Result.Ok json_str ->
      let reply =
        match parse json_str with
        | Result.Ok reply -> Result.Ok { reply with cursor_start; cursor_end; }
        | Result.Error json -> Result.Error json
      in
      Lwt.return reply
