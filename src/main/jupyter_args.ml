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

(** Command-line arguments *)

let connection_file = ref ""

let merlin = ref "ocamlmerlin"

let dot_merlin = ref "./.merlin"

let error_ctx_size = ref 1

let set_level_from_env () =
  try
    let lev = Sys.getenv "OCAML_JUPYTER_LOG" in
    if lev <> "" then Jupyter_log.set_level lev
  with Not_found -> ()

let parse () =
  let open Arg in
  let specs = align [
      "--connection-file",
      Set_string connection_file,
      "<file> Connection information to Jupyter";
      "--init",
      String (fun s -> Clflags.init_file := Some s),
      "<file> An alias of -init"; (* for compatibility with ocaml-jupyter v2.3.5 or below *)
      "--merlin",
      Set_string merlin,
      "<file> Path to ocamlmerlin";
      "--dot-merlin",
      Set_string dot_merlin,
      "<file> Path to .merlin";
      "--verbosity",
      Symbol (["debug"; "info"; "warning"; "error"; "app"], Jupyter_log.set_level),
      "Set log level";
      "--error-ctx",
      Set_int error_ctx_size,
      "<num> The number of context lines in error messages";
    ] in
  Jupyter_repl.Caml_args.parse
    Format.err_formatter
    ~usage:"Usage: ocaml-jupyter-kernel <options> <object-files> [script-file [arguments]]\n\
            options are:"
    ~specs ;
  set_level_from_env ()
