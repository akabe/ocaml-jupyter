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

(** Merlin-based completion

    @see https://github.com/ocaml/merlin/blob/master/doc/dev/PROTOCOL.md *)

open Format
open Lwt.Infix
open Jupyter_log

let string_of_bool b = if b then "y" else "n"

(** {2 Merlin} *)

type t =
  {
    server : bool;
    bin_path : string;
    dot_merlin : string;
    context : Buffer.t;
  }

let create ?(server = true) ?(bin_path = "ocamlmerlin") ?(dot_merlin = ".merlin") () =
  let dot_merlin =
    if Filename.is_relative dot_merlin
    then Filename.concat (Sys.getcwd ()) dot_merlin (* relative path *)
    else dot_merlin in (* absolute path *)
  { server; bin_path; dot_merlin; context = Buffer.create 16; }

let add_context merlin code =
  Buffer.add_string merlin.context code ;
  Buffer.add_string merlin.context " ;; "

let call merlin command flags printer =
  let mode = if merlin.server then "server" else "single" in
  let args = merlin.bin_path :: mode :: command
             :: "-dot-merlin" :: merlin.dot_merlin :: flags in
  info (fun pp -> pp "Merlin command: %s" (String.concat " " args)) ;
  let proc = Lwt_process.open_process ("ocamlmerlin", Array.of_list args) in
  let%lwt () = printer proc#stdin in
  let%lwt () = Lwt_io.flush proc#stdin in
  let%lwt () = Lwt_io.close proc#stdin in
  match%lwt Lwt_io.read_line proc#stdout with
  | exception End_of_file ->
    warn (fun pp -> pp "merlin crashed or not found ocamlmerlin") ;
    Lwt.return_none
  | str ->
    let%lwt _ = proc#close in
    debug (fun pp -> pp "Merlin returns: %s" str) ;
    Lwt.return_some str

(** {2 Top-level merlin replies} *)

type 'a merlin_reply =
  | RETURN of 'a [@name "return"]
        | FAILURE of Yojson.Safe.json [@name "failure"]
        | ERROR of Yojson.Safe.json [@name "error"]
        | EXN of Yojson.Safe.json [@name "exception"]
[@@deriving of_yojson]

type 'a merlin_reply_body =
  {
    klass : string [@key "class"];
    value : 'a;
    notifications : string list;
  }
[@@deriving of_yojson { strict = false }]

let parse_merlin_reply ~of_yojson str =
  let error_json msg json =
    error (fun pp -> pp "%s: %s" msg (Yojson.Safe.pretty_to_string json))
  in
  let reply = Yojson.Safe.from_string str
              |> [%of_yojson: Yojson.Safe.json merlin_reply_body]
              |> Jupyter.Json.or_die in
  `List [`String reply.klass; reply.value]
  |> merlin_reply_of_yojson of_yojson
  |> Jupyter.Json.or_die
  |> function
  | RETURN ret -> Some ret
  | FAILURE j -> error_json "Merlin failure" j ; None
  | ERROR j -> error_json "Merlin error" j ; None
  | EXN j -> error_json "Merlin exception" j ; None

(** {2 Detection of identifiers} *)

type ident_position =
  {
    id_line : int [@key "line"];
    id_col : int [@key "col"];
  }
[@@deriving yojson { strict = false }]

type ident_reply =
  {
    id_start : ident_position [@key "start"];
    id_end : ident_position [@key "end"];
  }
[@@deriving yojson { strict = false }]

let occurrences ~pos merlin code =
  let args = ["-identifier-at"; string_of_int pos] in
  let printer oc = Lwt_io.write oc code in
  call merlin "occurrences" args printer
  >|= function
  | None -> []
  | Some s ->
    parse_merlin_reply ~of_yojson:[%of_yojson: ident_reply list] s
    |> function
    | None -> []
    | Some replies -> replies

let abs_position code pos =
  let n = String.length code in
  let rec aux lnum cpos i =
    if i = n then n
    else if lnum = pos.id_line && (cpos = pos.id_col || code.[i] = '\n') then i
    else match code.[i] with
      | '\n' -> aux (succ lnum) 0 (succ i)
      | _ -> aux lnum (succ cpos) (succ i)
  in
  aux 1 0 0

(** {2 Completion} *)

type kind =
  | CMPL_VALUE [@name "Value"]
      | CMPL_VARIANT [@name "Variant"]
      | CMPL_CONSTR [@name "Constructor"]
      | CMPL_LABEL [@name "Label"]
      | CMPL_MODULE [@name "Module"]
      | CMPL_SIG [@name "Signature"]
      | CMPL_TYPE [@name "Type"]
      | CMPL_METHOD [@name "Method"]
      | CMPL_METHOD_CALL [@name "#"]
      | CMPL_EXN [@name "Exn"]
      | CMPL_CLASS [@name "Class"]
[@@deriving yojson]

type candidate =
  {
    cmpl_name : string [@key "name"];
    cmpl_kind : kind Jupyter.Json.enum [@key "kind"];
    cmpl_type : string [@key "desc"];
    cmpl_doc  : string [@key "info"];
  }
[@@deriving yojson { strict = false }]

type reply =
  {
    cmpl_candidates : candidate list [@key "entries"];
    cmpl_start : int [@key "start"] [@default 0];
    cmpl_end : int [@key "end"] [@default 0];
  }
[@@deriving yojson { strict = false }]

let empty = { cmpl_candidates = []; cmpl_start = 0; cmpl_end = 0; }

let rec rfind_prefix_start s = function
  | 0 -> 0
  | pos ->
    match s.[pos - 1] with
    | '0'..'9' | 'a'..'z' | 'A'..'Z' | '_' | '\'' | '`' | '.' -> rfind_prefix_start s (pos - 1)
    | _ -> pos

let rec find_cmpl_end s pos =
  if pos < String.length s then
    match s.[pos] with
    | '0'..'9' | 'a'..'z' | 'A'..'Z' | '_' | '\'' | '`' | '.' -> find_cmpl_end s (pos + 1)
    | _ -> pos
  else pos

let complete ?(doc = false) ?(types = false) ~pos merlin code =
  let context = Buffer.contents merlin.context in
  let offset = String.length context in
  let prefix_start = rfind_prefix_start code pos in
  let prefix_length = pos - prefix_start in
  let prefix = String.sub code prefix_start prefix_length in
  info (fun pp -> pp "completion prefix = %S (%d--%d)" prefix prefix_start pos) ;
  let args = [
    "-position"; string_of_int (offset + pos);
    "-prefix"; prefix;
    "-doc"; string_of_bool doc;
    "-types"; string_of_bool types;
  ] in
  let printer oc =
    let%lwt () = Lwt_io.write oc context in
    Lwt_io.write oc code in
  call merlin "complete-prefix" args printer
  >|= function
  | None -> empty
  | Some s ->
    parse_merlin_reply ~of_yojson:[%of_yojson: reply] s
    |> function
    | None -> empty
    | Some reply ->
      { reply with
        cmpl_start =
          begin match String.rindex_from prefix (prefix_length - 1) '.' with
            | pos -> prefix_start + pos + 1
            | exception Not_found -> prefix_start
          end;
        cmpl_end = find_cmpl_end code pos; }
