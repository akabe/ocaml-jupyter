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
open Jupyter

type cell =
  {
    cell_type : string;
    execution_count : int;
    source : string list;
    outputs : string list;
    metadata : Yojson.Safe.t;
  }
[@@deriving yojson]

type kernelspec =
  {
    display_name : string;
    language : string;
    name : string;
  }
[@@deriving yojson]

type metadata =
  {
    kernelspec : kernelspec;
    language_info : Shell.language_info;
  }
[@@deriving yojson]

type ipynb =
  {
    nbformat : int;
    nbformat_minor : int;
    cells : cell list;
    metadata : metadata;
  }
[@@deriving yojson]

let read_lines fname =
  let ic = open_in fname in
  let rec aux acc = match input_line ic with
    | exception End_of_file -> close_in ic ; List.rev acc
    | line -> aux ((line ^ "\n") :: acc)
  in
  aux []

let ipynb_of_code lines =
  {
    cells = [{
        cell_type = "code";
        execution_count = 1;
        source = lines;
        outputs = [];
        metadata = `Assoc [];
      }];
    nbformat = 4;
    nbformat_minor = 2;
    metadata = {
      kernelspec = {
        display_name = "OCaml";
        language = "OCaml";
        name = "ocaml-jupyter";
      };
      language_info = Shell.language_info;
    };
  }

let runtest ml_fname =
  let ipynb_fname = ml_fname ^ ".ipynb" in
  read_lines ml_fname
  |> ipynb_of_code
  |> [%to_yojson: ipynb]
  |> Yojson.Safe.to_file ipynb_fname ;
  let cmd = sprintf "jupyter nbconvert --to notebook --execute %S" ipynb_fname in
  printf "%s>> %s%s@." AnsiCode.FG.cyan cmd AnsiCode.reset ;
  match Unix.system cmd with
  | Unix.WEXITED 0 -> false
  | _ -> true

let () =
  if Array.length Sys.argv < 2
  then eprintf "Usage: %s ML_FILES...@." Sys.argv.(0)
  else Array.to_list Sys.argv
       |> List.tl
       |> List.filter runtest
       |> function
       | [] ->
         printf "%sAll tests are passed.%s@." AnsiCode.FG.green AnsiCode.reset ;
         exit 0
       | failed_suites ->
         let res = String.concat ", " failed_suites in
         printf "%sFailed: %s%s@." AnsiCode.FG.green res AnsiCode.reset ;
         exit 127
