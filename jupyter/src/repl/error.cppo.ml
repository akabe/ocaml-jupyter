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

(** Error report for OCaml REPL *)

#if OCAML_VERSION < (4,08,0)
open Format
open Lexing
open Location
open Jupyter

let loc_style = AnsiCode.FG.green
let msg_style = AnsiCode.FG.red
let lnum_style = AnsiCode.FG.cyan
let code_style = AnsiCode.FG.black
let highlight_start = AnsiCode.underline

(** for compatibility with 4.03 or below. *)
let split_on_char ~on s =
  let b = Buffer.create 16 in
  let n = String.length s in
  let rec aux i acc =
    if i = n then List.rev (Buffer.contents b :: acc)
    else if s.[i] = on then begin
      let line = Buffer.contents b in
      Buffer.clear b ;
      aux (succ i) (line :: acc)
    end else begin
      Buffer.add_char b s.[i] ;
      aux (succ i) acc
    end
  in
  aux 0 []

let rtrim s =
  let rec aux i =
    if i = 0 then "" else match s.[i] with
      | ' ' | '\t' | '\n' | '\r' -> aux (pred i)
      | _ -> String.sub s 0 (succ i)
  in
  aux (String.length s - 1)

let string_of_lexbuf lexbuf =
  let bytes = lexbuf.lex_buffer in
  let bpos = lexbuf.lex_abs_pos in
  let epos = lexbuf.lex_buffer_len - bpos - 1 in
  Bytes.sub_string bytes bpos (epos - bpos + 1)

let highlight bpos epos s =
  let n = String.length s in
  let b = Buffer.create n in
  let rec aux i internal =
    if i = n then Buffer.contents b (* done *)
    else if i = bpos then begin
      Buffer.add_string b highlight_start ;
      Buffer.add_char b s.[i] ;
      aux (succ i) true
    end
    else if i = epos then begin
      Buffer.add_string b AnsiCode.reset ;
      Buffer.add_string b code_style ;
      Buffer.add_char b s.[i] ;
      aux (succ i) false
    end
    else if s.[i] = '\n' && internal then begin
      Buffer.add_string b AnsiCode.reset ;
      Buffer.add_char b '\n' ;
      Buffer.add_string b highlight_start ;
      aux (succ i) true
    end
    else begin
      Buffer.add_char b s.[i] ;
      aux (succ i) internal
    end
  in
  if bpos < 0 then Buffer.add_string b highlight_start ;
  aux 0 false

let pp_print_highlight_code ~ctx_size ppf loc =
  match !input_lexbuf with
  | None -> ()
  | Some lexbuf ->
    let blnum = loc.loc_start.pos_lnum - ctx_size in
    let elnum = loc.loc_end.pos_lnum + ctx_size in
    string_of_lexbuf lexbuf
    |> rtrim
    |> highlight loc.loc_start.pos_cnum loc.loc_end.pos_cnum
    |> split_on_char ~on:'\n'
    |> List.mapi (fun i line -> (succ i, line))
    |> List.filter (fun (lnum, _) -> blnum <= lnum && lnum <= elnum)
    |> List.map (fun (lnum, line) -> sprintf "%s%4d: %s%s" lnum_style lnum code_style line)
    |> String.concat "\n"
    |> pp_print_string ppf

let rec pp_print_error ~ctx_size ppf (exn, { loc; msg; sub; _ }) =
  let loc =
    match Compat.extract_location exn with
    | Some loc' -> loc'
    | None -> loc
  in
  if loc.loc_start.pos_cnum < 0 || loc.loc_end.pos_cnum < 0
  then fprintf ppf "@[<v>%s%a\n" msg_style Compat.pp_print_error_message msg
  else begin
    fprintf ppf "@[<v>%s%a:\n%s%a\n%a"
      loc_style Location.print_loc loc
      msg_style Compat.pp_print_error_message msg
      (pp_print_highlight_code ~ctx_size) loc
  end ;
  pp_print_string ppf AnsiCode.reset ;
  List.iter
    (fun err -> fprintf ppf "@,@[<2>%a@]" (pp_print_error ~ctx_size) (exn, err))
    sub ;
  fprintf ppf "@]"

let to_string_hum ~ctx_size exn =
  let report ppf err = pp_print_error ~ctx_size ppf (exn, err) in
  Location.error_reporter := report ;
  let b = Buffer.create 256 in
  let ppf = Format.formatter_of_buffer b in
  Errors.report_error ppf exn ;
  Format.pp_print_flush ppf () ;
  Buffer.contents b
#else
let to_string_hum ~ctx_size exn =
  ignore(ctx_size);
  let b = Buffer.create 256 in
  let ppf = Format.formatter_of_buffer b in
  Errors.report_error ppf exn ;
  Format.pp_print_flush ppf () ;
  Buffer.contents b
#endif
