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

let version = ref false

let connection_file = ref ""

let init_file = ref "~/.ocamlinit"

let preload_objs = ref ["stdlib.cma"]

let merlin = ref "ocamlmerlin"

let dot_merlin = ref "./.merlin"

let error_ctx_size = ref 1

let parse () =
  let open Arg in
  let specs =
    align [
      "--connection-file",
      Set_string connection_file,
      "<file> connection information to Jupyter";
      "--init",
      Set_string init_file,
      "<file> load a file instead of ~/.ocamlinit";
      "--merlin",
      Set_string merlin,
      "<file> path of ocamlmerlin";
      "--dot-merlin",
      Set_string dot_merlin,
      "<file> path of .merlin";
      "--verbosity",
      Symbol (["debug"; "info"; "warning"; "error"; "app"], Jupyter_log.set_level),
      "set log level";
      "--version",
      Set version,
      "show the version number";
      "--error-ctx",
      Set_int error_ctx_size,
      "<num> the number of context lines in error messages";
    ]
  in
  let doc = "An OCaml kernel for Jupyter (IPython) notebook" in
  parse specs (fun obj -> preload_objs := obj :: !preload_objs) doc ;
  if !version then begin
    print_endline Jupyter.Version.version ;
    exit 0
  end
