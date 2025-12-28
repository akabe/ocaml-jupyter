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
open Jupyter

let buffer = Buffer.create 256
let buffer_ppf = formatter_of_buffer buffer

(** {2 Initialization} *)

let replace_out_phrase () =
  let re = Str.regexp ".*ocamltoplevel\\.cma.*" in
  let old_out_phrase = !Oprint.out_phrase in
  let print_out_phrase ppf = function
    (* Ignore the exception raised at ocaml/toplevel/toploop.ml *)
    | Outcometree.Ophr_exception (Invalid_argument msg, _)
      when Str.string_match re msg 0 -> ()
    | ophr -> old_out_phrase ppf ophr
  in
  Oprint.out_phrase := print_out_phrase

let init_toploop () =
  try
    Toploop.initialize_toplevel_env ()
  with Env.Error _ | Typetexp.Error _ as exn ->
    Location.report_exception buffer_ppf exn ;
    exit 2

let init ?(preinit = ignore) ?init_file () =
  let ppf = Format.err_formatter in
  Clflags.debug := true ;
  Location.formatter_for_warnings := ppf ;
  Sys.catch_break true ;
  replace_out_phrase () ;
  Compenv.readenv ppf Compenv.Before_link ;
  if not (Caml_args.prepare ppf) then exit 2 ;
  init_toploop () ;
  Dir_trace.add_directives buffer_ppf ;
  preinit () ;
  begin match init_file with
    | None -> ()
    | Some path ->
      ignore (Toploop.use_silently Format.std_formatter (Toploop.File path))
  end

let setvalue name value = Toploop.setvalue name (Obj.repr value)

(** {2 Communication} *)

let iopub_success ?metadata ~count msg =
  Iopub.execute_result ?metadata ~count (`Assoc ["text/plain", `String msg])

let iopub_interrupt () =
  Iopub.error ~name:"interrupt" ~value:"intterupt" [
    sprintf "%sException: Sys.Break.%s"
      AnsiCode.FG.red AnsiCode.reset
  ]

(** {2 Execution} *)

let eval_phrase ~filename phrase =
  Compat.reset_fatal_warnings () ;
  let phrase' = Compat.preprocess_phrase ~filename phrase in (* apply PPX *)
  let phrase' = Lwt_async_rewrite.rewrite phrase' in
  Env.reset_cache_toplevel () ;
  let is_ok = Toploop.execute_phrase true buffer_ppf phrase' in
  let message = Buffer.contents buffer in
  Buffer.clear buffer ;
  (is_ok, message)

let eval ?(error_ctx_size = 1) ~send ~count code =
  let filename = sprintf "[%d]" count in
  let rec loop status = function
    | [] -> status
    | phrase :: tl ->
      match eval_phrase ~filename phrase with
      | true, "" -> loop status tl
      | true, msg -> send (iopub_success ~count msg) ; loop status tl
      | false, msg ->
        send (Iopub.error ~value:"runtime_error"
                [AnsiCode.FG.red ^ msg ^ AnsiCode.reset]) ;
        Shell.SHELL_ERROR
  in
  try
    let lexbuf = Lexing.from_string (code ^ "\n") in
    Location.init lexbuf filename ;
    Location.input_name := filename ;
    Location.input_lexbuf := Some lexbuf ;
    loop Shell.SHELL_OK (!Toploop.parse_use_file lexbuf)
  with
  | Sys.Break ->
    send (iopub_interrupt ()) ;
    Shell.SHELL_ABORT
  | exn ->
    let msg = Error.to_string_hum ~ctx_size:error_ctx_size exn in
    send (Iopub.error ~value:"compile_error" [msg]) ;
    Shell.SHELL_ERROR
