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

(** Version-dependent compiler-libs functions *)

(** [preprocess_phrase ~filename phrase] apply preprocessors to [phrase].
    @param filename  a filename of an input file. *)
let preprocess_phrase ~filename = function
  | Parsetree.Ptop_def structure ->
    structure
    |> Pparse.apply_rewriters_str ~restore:true ~tool_name:"ocaml"
#if OCAML_VERSION >= (4,04,0)
    |> Pparse.ImplementationHooks.apply_hooks { Misc.sourcefile = filename }
#endif
    |> fun structure' -> Parsetree.Ptop_def structure'
  | phrase -> phrase

let pp_print_error_message ppf msg =
#if OCAML_VERSION >= (4,04,0)
  Format.fprintf ppf "Error: %s" msg
#else
  Format.pp_print_string ppf msg
#endif

let extract_location = function
  | Syntaxerr.Error e -> Some (Syntaxerr.location_of_error e)
  | Lexer.Error (_, loc)
  | Translclass.Error (loc, _)
  | Translcore.Error (loc, _)
  | Translmod.Error (loc, _)
  | Typeclass.Error (loc, _, _)
  | Typecore.Error (loc, _, _)
  | Typedecl.Error (loc, _)
  | Typemod.Error (loc, _, _)
  | Typetexp.Error (loc, _, _) -> Some loc
#if OCAML_VERSION >= (4,02,0)
  | Typecore.Error_forward e
  | Typemod.Error_forward e
  | Typeclass.Error_forward e -> Some e.Location.loc
#endif
#if OCAML_VERSION >= (4,03,0)
  | Attr_helper.Error (loc, _)
  | Primitive.Error (loc, _) -> Some loc
#endif
  | _ -> None

let reset_fatal_warnings () =
#if OCAML_VERSION >= (4,03,0)
  Warnings.reset_fatal ()
#else
  ()
#endif
