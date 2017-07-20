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

(** Top-level loop of OCaml code evaluation *)

open Format

type reply =
  [
    | `Ok of string
    | `Runtime_error of string
    | `Compile_error of string
    | `Aborted
  ]
[@@deriving yojson]

module E = JupyterReplError

let buffer = Buffer.create 256
let ppf = formatter_of_buffer buffer

let readenv ppf =
  let open Compenv in
  readenv ppf Before_args ;
  readenv ppf Before_link

let prepare () =
  Toploop.set_paths() ;
  !Toploop.toplevel_startup_hook () ;
  Topdirs.dir_cd (Sys.getcwd ()) (* required for side-effect initialization in Topdirs *)

let init_toploop () =
  try
    Toploop.initialize_toplevel_env ()
  with Env.Error _ | Typetexp.Error _ as exn ->
    Location.report_exception ppf exn ;
    exit 2

let load_ocamlinit = function
  | None -> ()
  | Some path ->
    if Sys.file_exists path
    then ignore (Toploop.use_silently std_formatter path)
    else eprintf "Init file not found: \"%s\".@." path

let init ?(preload = ["stdlib.cma"]) ?(preinit = ignore) ?init_file () =
  let ppf = Format.err_formatter in
  Clflags.debug := true ;
  Location.formatter_for_warnings := ppf ;
  Sys.catch_break true ;
  readenv ppf ;
  prepare () ;
  init_toploop () ;
  List.iter (Topdirs.dir_load ppf) preload ;
  preinit () ;
  load_ocamlinit init_file

let preprocess_phrase ~filename = function
  | Parsetree.Ptop_def str ->
    let str' = (* apply ppx *)
      str
      |> Pparse.apply_rewriters_str ~restore:true ~tool_name:"ocaml"
#if OCAML_VERSION >= (4,04,0)
      |> Pparse.ImplementationHooks.apply_hooks
        { Misc.sourcefile = filename }
#endif
    in
    Parsetree.Ptop_def str'
  | phrase -> phrase

let run_from_lexbuf ~filename ~f ~init lexbuf =
  try
    !Toploop.parse_use_file lexbuf (* parsing *)
    |> List.fold_left
      (fun acc phrase ->
         E.reset_fatal_warnings () ;
         try
           let phrase' = preprocess_phrase ~filename phrase in
           Env.reset_cache_toplevel () ;
           let is_ok = Toploop.execute_phrase true ppf phrase' in
           let message = Buffer.contents buffer in
           Buffer.clear buffer ;
           match is_ok with
           | true when message = "" -> acc
           | true -> f acc (`Ok message)
           | false -> f acc (`Runtime_error message)
         with
         | Sys.Break -> f acc `Aborted
         | exn -> f acc (`Compile_error (E.extract exn)))
      init
  with
  | Sys.Break -> f init `Aborted
  | exn -> f init (`Compile_error (E.extract exn))

let run ~filename ~f ~init code =
  let lexbuf = Lexing.from_string (code ^ "\n") in
  Location.init lexbuf filename ;
  Location.input_name := filename ;
  Location.input_lexbuf := Some lexbuf ;
  run_from_lexbuf ~filename ~f ~init lexbuf
