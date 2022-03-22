(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*             Xavier Leroy, projet Cristal, INRIA Rocquencourt           *)
(*                                                                        *)
(*   Copyright 1996 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)


(** The trace for OCaml 4.13.0 or above.

    [#trace] directive implemented at

    - [toplevel/topdirs.ml] on 4.12.0-, and
    - [toplevel/byte/trace.ml] and [toplevel/byte/topmain.ml] on 4.13.0+.

    This file is a part of [toplevel/byte/topmain.ml], migrated for
    ocaml-jupyter. *)

open Types
open Trace
open Toploop

external current_environment: unit -> Obj.t = "caml_get_current_environment"

let tracing_function_ptr =
  get_code_pointer
    (Obj.repr (fun arg -> Trace.print_trace (current_environment()) arg))

let dir_trace ppf lid =
  match Env.find_value_by_name lid !toplevel_env with
  | (path, desc) -> begin
      (* Check if this is a primitive *)
      match desc.Types.val_kind with
      | Types.Val_prim _ ->
        Format.fprintf ppf
          "%a is an external function and cannot be traced.@."
          Printtyp.longident lid
      | _ ->
        let clos = Toploop.eval_value_path !toplevel_env path in
        (* Nothing to do if it's not a closure *)
        if Obj.is_block clos
        && (Obj.tag clos = Obj.closure_tag || Obj.tag clos = Obj.infix_tag)
        && (match
              Compat.types_get_desc
                (Ctype.expand_head !toplevel_env desc.val_type)
            with Tarrow _ -> true | _ -> false)
        then begin
          match is_traced clos with
          | Some opath ->
            Format.fprintf ppf "%a is already traced (under the name %a).@."
              Printtyp.path path
              Printtyp.path opath
          | None ->
            (* Instrument the old closure *)
            traced_functions :=
              { path = path;
                closure = clos;
                actual_code = get_code_pointer clos;
                instrumented_fun =
                  instrument_closure
                    !toplevel_env lid ppf desc.val_type }
              :: !traced_functions;
            (* Redirect the code field of the closure to point
               to the instrumentation function *)
            set_code_pointer clos tracing_function_ptr;
            Format.fprintf ppf "%a is now traced.@." Printtyp.longident lid
        end else
          Format.fprintf ppf "%a is not a function.@." Printtyp.longident lid
    end
  | exception Not_found ->
    Format.fprintf ppf "Unbound value %a.@." Printtyp.longident lid

let dir_untrace ppf lid =
  match Env.find_value_by_name lid !toplevel_env with
  | (path, _desc) ->
    let rec remove = function
      | [] ->
        Format.fprintf ppf "%a was not traced.@." Printtyp.longident lid;
        []
      | f :: rem ->
        if Path.same f.path path then begin
          set_code_pointer f.closure f.actual_code;
          Format.fprintf ppf "%a is no longer traced.@."
            Printtyp.longident lid;
          rem
        end else f :: remove rem in
    traced_functions := remove !traced_functions
  | exception Not_found ->
    Format.fprintf ppf "Unbound value %a.@." Printtyp.longident lid

let dir_untrace_all ppf () =
  List.iter
    (fun f ->
       set_code_pointer f.closure f.actual_code;
       Format.fprintf ppf "%a is no longer traced.@." Printtyp.path f.path)
    !traced_functions;
  traced_functions := []

let add_directives ppf =
  let _ = add_directive "trace"
      (Directive_ident (dir_trace ppf))
      {
        section = Compat.section_trace;
        doc = "All calls to the function \
               named function-name will be traced.";
      } in

  let _ = add_directive "untrace"
      (Directive_ident (dir_untrace ppf))
      {
        section = Compat.section_trace;
        doc = "Stop tracing the given function.";
      } in

  let _ = add_directive "untrace_all"
      (Directive_none (dir_untrace_all ppf))
      {
        section = Compat.section_trace;
        doc = "Stop tracing all functions traced so far.";
      } in
  ()
