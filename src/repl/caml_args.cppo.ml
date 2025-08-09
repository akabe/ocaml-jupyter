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

(** Command-line parameters for OCaml REPL *)

(* Only this file is published under GNU GPL v2.1, not MIT license.

   The following code is written based on toplevel/topmain.ml in the official OCaml
   compiler, distributed under the GNU Lesser General Public License version
   2.1, with the special exception on linking
   described in https://github.com/ocaml/ocaml/blob/trunk/LICENSE. *)

(* Position of the first non expanded argument *)
let first_nonexpanded_pos = ref 0

let current = ref (!Arg.current)

let argv = ref Sys.argv

#if OCAML_VERSION >= (5,0,0)
let preload_objects = ref []
#else
let preload_objects = ref ["stdlib.cma"]
#endif

(* Test whether the option is part of a responsefile *)
let is_expanded pos = pos < !first_nonexpanded_pos

let expand_position pos len =
  if pos < !first_nonexpanded_pos then
    first_nonexpanded_pos := !first_nonexpanded_pos + len (* Shift the position *)
  else
    first_nonexpanded_pos :=  pos + len + 2 (* New last position *)

let prepare ppf =
  Topcommon.set_paths ();
  begin try
    Toploop.initialize_toplevel_env ()
  with Env.Error _ | Typetexp.Error _ as exn ->
    Location.report_exception ppf exn; raise (Compenv.Exit_with_status 2)
  end;
  try
    let res =
      let objects =
        List.rev (!preload_objects @ !Compenv.first_objfiles)
      in
      List.for_all (Topeval.load_file false ppf) objects
    in
    Topcommon.run_hooks Topcommon.Startup;
    res
  with x ->
    try Location.report_exception ppf x; false
    with x ->
      Format.fprintf ppf "Uncaught exception: %s\n" (Printexc.to_string x);
      false

let input_argument name =
  let filename = Toploop.filename_of_input name in
  let ppf = Format.err_formatter in
  if Filename.check_suffix filename ".cmo"
          || Filename.check_suffix filename ".cma"
  then preload_objects := filename :: !preload_objects
  else if is_expanded !current then begin
    (* Script files are not allowed in expand options because otherwise the
       check in override arguments may fail since the new argv can be larger
       than the original argv.
    *)
    Printf.eprintf "For implementation reasons, the toplevel does not support\
   \ having script files (here %S) inside expanded arguments passed through the\
   \ -args{,0} command-line option.\n" filename;
    raise (Compenv.Exit_with_status 2)
  end else begin
      let newargs = Array.sub !argv !current
                              (Array.length !argv - !current)
      in
      Compenv.(readenv ppf Before_link);
      Compmisc.read_clflags_from_env ();
      if prepare ppf &&
         Toploop.run_script ppf name newargs
      then raise (Compenv.Exit_with_status 0)
      else raise (Compenv.Exit_with_status 2)
    end

let file_argument x = input_argument (Toploop.File x)

let print_version () =
  Printf.printf "ocaml-jupyter kernel version %s (OCaml version %s)\n"
    Jupyter.Version.version Sys.ocaml_version ;
  exit 0

let print_version_num () =
  Printf.printf "%s\n" Jupyter.Version.version ;
  exit 0

let wrap_expand f s =
  let start = !current in
  let arr = f s in
  expand_position start (Array.length arr);
  arr

let set r () = r := true
let clear r () = r := false

module Options = Main_args.Make_bytetop_options (struct
#if OCAML_VERSION < (4,08,0)
    let _absname = set Location.absname
#else
    let _absname = set Clflags.absname
#endif
    let _I dir =
      let dir = Misc.expand_directory Config.standard_library dir in
      Clflags.include_dirs := dir :: !Clflags.include_dirs
#if OCAML_VERSION >= (5,02,0)
    let _H dir =
      let dir = Misc.expand_directory Config.standard_library dir in
      Clflags.hidden_include_dirs := dir :: !Clflags.hidden_include_dirs
#endif
    let _init s = Clflags.init_file := Some s
    let _noinit = set Clflags.noinit
    let _labels = clear Clflags.classic
    let _alias_deps = clear Clflags.transparent_modules
    let _no_alias_deps = set Clflags.transparent_modules
    let _app_funct = set Clflags.applicative_functors
    let _no_app_funct = clear Clflags.applicative_functors
    let _noassert = set Clflags.noassert
    let _nolabels = set Clflags.classic
    let _noprompt = set Clflags.noprompt
    let _prompt = clear Clflags.noprompt
    let _nopromptcont = set Clflags.nopromptcont
    let _nostdlib = set Clflags.no_std_include
    let _open s = Clflags.open_modules := s :: !Clflags.open_modules
    let _ppx s = Compenv.first_ppx := s :: !Compenv.first_ppx
    let _principal = set Clflags.principal
    let _no_principal = clear Clflags.principal
    let _rectypes = set Clflags.recursive_types
    let _no_rectypes = clear Clflags.recursive_types
#if OCAML_VERSION >= (5,03,0)
    let _keywords k =
      Clflags.keyword_edition := Some (k)
#endif
#if OCAML_VERSION < (5,0,0)
    let _safe_string = clear Clflags.unsafe_string
#endif
    let _short_paths = clear Clflags.real_paths
    let _stdin () = file_argument ""
    let _strict_sequence = set Clflags.strict_sequence
    let _no_strict_sequence = clear Clflags.strict_sequence
    let _strict_formats = set Clflags.strict_formats
    let _no_strict_formats = clear Clflags.strict_formats
    let _unboxed_types = set Clflags.unboxed_types
    let _no_unboxed_types = clear Clflags.unboxed_types
#if OCAML_VERSION < (4,08,0)
    let _unsafe = set Clflags.fast
#else
    let _unsafe = set Clflags.unsafe
#endif
#if OCAML_VERSION < (5,0,0)
    let _unsafe_string = set Clflags.unsafe_string
#endif
    let _version () = print_version ()
    let _vnum () = print_version_num ()
    let _no_version = set Clflags.noversion
#if OCAML_VERSION < (4,13,0)
    let _w s = Warnings.parse_options false s
#else
    let _w s = Warnings.parse_options false s |> Option.iter Location.(prerr_alert none)
#endif

#if OCAML_VERSION < (4,13,0)
    let _warn_error s = Warnings.parse_options true s
#else
    let _warn_error s = Warnings.parse_options true s |> Option.iter Location.(prerr_alert none)
#endif
    let _warn_help = Warnings.help_warnings
    let _dparsetree = set Clflags.dump_parsetree
    let _dtypedtree = set Clflags.dump_typedtree
    let _dsource = set Clflags.dump_source
    let _drawlambda = set Clflags.dump_rawlambda
    let _dlambda = set Clflags.dump_lambda
    let _dflambda = set Clflags.dump_flambda
    let _dinstr = set Clflags.dump_instr

    let anonymous s = file_argument s

#if OCAML_VERSION >= (4,05,0)
    (* OCaml 4.05 or above *)
    let _args = wrap_expand Arg.read_arg
    let _args0 = wrap_expand Arg.read_arg0
#endif

#if OCAML_VERSION >= (4,06,0)
    (* OCaml 4.06 or above *)
    let _dtimings () = Clflags.profile_columns := [ `Time ]
    let _dprofile () = Clflags.profile_columns := Profile.all_columns
#else
    (* OCaml 4.05 or below *)
    let _plugin p = Compplugin.load p
    let _dtimings = set Clflags.print_timings
#endif

#if OCAML_VERSION >= (4,07,0)
    (* OCaml 4.07 or above *)
    let _dno_unique_ids = clear Clflags.unique_ids
    let _dunique_ids = set Clflags.unique_ids
#endif
#if OCAML_VERSION >= (4,08,0)
    let _error_style = Misc.set_or_ignore Clflags.error_style_reader.Clflags.parse Clflags.error_style
    let _color = Misc.set_or_ignore Clflags.color_reader.Clflags.parse Clflags.color
    let _nopervasives = set Clflags.nopervasives
    let _alert = Warnings.parse_alert_option
#endif

#if OCAML_VERSION >= (4,11,0)
    let _dlocations = set Clflags.locations
    let _dno_locations = clear Clflags.locations
#endif

#if OCAML_VERSION = (4,14,0)
let _force_tmc = set Clflags.force_tmc
#endif
#if OCAML_VERSION >= (4,14,0)
let _dshape = set Clflags.dump_shape
let _eval (_ : string) = ()
#endif
#if OCAML_VERSION >= (5,0,0)
    let _nocwd = set Clflags.no_cwd
    let _no_absname = set Clflags.absname
    let _safer_matching = set Clflags.safer_matching
#endif
end)

#if OCAML_VERSION >= (4,05,0)

(* OCaml 4.05 or above *)
let parse ppf ~usage ~specs =
  Compenv.readenv ppf Compenv.Before_args ;
  let list = ref (specs @ Options.list) in
  begin
    try Arg.parse_and_expand_argv_dynamic current argv list file_argument usage
    with
    | Arg.Bad msg -> Printf.eprintf "%s" msg ; exit 2
    | Arg.Help msg -> Printf.printf "%s" msg ; exit 0
  end

#else

(* OCaml 4.04 *)
let parse ppf ~usage ~specs =
  Compenv.readenv ppf Compenv.Before_args ;
  Arg.parse (specs @ Options.list) file_argument usage

#endif

let get_ocamlinit_path () =
  let check_existence path =
    if Sys.file_exists path then begin
      Jupyter_log.debug (fun fmt -> fmt "Load init file %S." path) ;
      Some path
    end else begin
      Jupyter_log.warn (fun fmt -> fmt "Init file not found: %S." path) ;
      None
    end
  in
  if !Clflags.noinit then None
  else match !Clflags.init_file with
    | Some path -> check_existence path
    | None ->
      if Sys.file_exists ".ocamlinit" then check_existence ".ocamlinit"
      else
        try check_existence @@ Filename.concat (Sys.getenv "HOME") ".ocamlinit"
        with Not_found -> None
