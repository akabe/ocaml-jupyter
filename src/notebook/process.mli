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

(** Operations on subprocesses *)

type process_status = Unix.process_status =
  | WEXITED of int
  | WSIGNALED of int
  | WSTOPPED of int
[@@deriving show]

(** The type of execution results of subprocesses. *)
type t =
  {
    exit_status : Unix.process_status;
    stdout : string option;
    stderr : string option;
  }
[@@deriving show]

type capture_stderr_type =
  [
    | `No
    | `Yes
    | `Redirect_to_stdout
  ]

exception Execution_failure of t

(** {2 Command bindings} *)

(** [system prog args] is a rich version of [Unix.system] and [Sys.command] in
    the standard library of OCaml.

    Example:
    {[system "ocaml" ["ocaml"; "-vnum"]]}

    @param check           raises an execption when a process fails (default = [true])
    @param capture_stdout  default = [true]
    @param capture_stderr  default = [`No]
    @param interval        timeout of [Unix.select] for waiting IO (default = [0.1] seconds)
    @param prog            The path or the name of an executable file. If not a path,
                           the environment variable [$PATH] is used for finding the file.
    @param args            The list of arguments given to a command.

    @return an execution result of a subprocess.

    @since 2.8.0 *)
val system :
  ?check:bool ->
  ?capture_stdout:bool ->
  ?capture_stderr:capture_stderr_type ->
  ?interval:float ->
  string -> string list -> t

(** [pwd ()] returns a path to the current directory.

    This is an alias of [Unix.getcwd].

    @since 2.8.0 *)
val pwd : unit -> string

(** [cd path] changes the current directory.

    This is an alias of [Unix.chdir].

    @since 2.8.0 *)
val cd : string -> unit

(** [ls ?check ?capture_stdout ?capture_stderr ?interval ?args paths]
    shows a list of files in [paths].

    @since 2.8.0 *)
val ls :
  ?check:bool ->
  ?capture_stdout:bool ->
  ?capture_stderr:capture_stderr_type ->
  ?interval:float ->
  ?args:string list ->
  string list -> t

(** [rm ?check ?capture_stdout ?capture_stderr ?interval ?args paths]
    removes files in [paths].

    @since 2.8.0 *)
val rm :
  ?check:bool ->
  ?capture_stdout:bool ->
  ?capture_stderr:capture_stderr_type ->
  ?interval:float ->
  ?args:string list ->
  string list -> t

(** [cp ?check ?capture_stdout ?capture_stderr ?interval ?args src_path dest_path]
    copys a file or a directory from [src_path] into [dest_path].

    @since 2.8.0 *)
val cp :
  ?check:bool ->
  ?capture_stdout:bool ->
  ?capture_stderr:capture_stderr_type ->
  ?interval:float ->
  ?args:string list ->
  string -> string -> t

(** [mv ?check ?capture_stdout ?capture_stderr ?interval ?args src_path dest_path]
    moves a file or a directory from [src_path] into [dest_path].

    @since 2.8.0 *)
val mv :
  ?check:bool ->
  ?capture_stdout:bool ->
  ?capture_stderr:capture_stderr_type ->
  ?interval:float ->
  ?args:string list ->
  string -> string -> t

(** [sh ?check ?capture_stdout ?capture_stderr ?interval ?args script]
    evaluates a given code [script] by [sh] command.

    Example:
    {[sh {|
set -eu

VAR=hello
echo "$VAR"|}]}

    @since 2.8.0 *)
val sh :
  ?check:bool ->
  ?capture_stdout:bool ->
  ?capture_stderr:capture_stderr_type ->
  ?interval:float ->
  ?args:string list -> string -> t

(** [zsh ?check ?capture_stdout ?capture_stderr ?interval ?args script]
    evaluates a given code [script] by [zsh] command.

    @since 2.8.0 *)
val zsh :
  ?check:bool ->
  ?capture_stdout:bool ->
  ?capture_stderr:capture_stderr_type ->
  ?interval:float ->
  ?args:string list -> string -> t

(** [bash ?check ?capture_stdout ?capture_stderr ?interval ?args script]
    evaluates a given code [script] by [bash] command.

    @since 2.8.0 *)
val bash :
  ?check:bool ->
  ?capture_stdout:bool ->
  ?capture_stderr:capture_stderr_type ->
  ?interval:float ->
  ?args:string list -> string -> t

(** [python3 ?check ?capture_stdout ?capture_stderr ?interval ?args script]
    evaluates a given code [script] by [python3] command.

    @since 2.8.0 *)
val python3 :
  ?check:bool ->
  ?capture_stdout:bool ->
  ?capture_stderr:capture_stderr_type ->
  ?interval:float ->
  ?args:string list -> string -> t

(** [ruby ?check ?capture_stdout ?capture_stderr ?interval ?args script]
    evaluates a given code [script] by [ruby] command.

    @since 2.8.0 *)
val ruby :
  ?check:bool ->
  ?capture_stdout:bool ->
  ?capture_stderr:capture_stderr_type ->
  ?interval:float ->
  ?args:string list -> string -> t

(** [perl ?check ?capture_stdout ?capture_stderr ?interval ?args script]
    evaluates a given code [script] by [perl] command.

    @since 2.8.0 *)
val perl :
  ?check:bool ->
  ?capture_stdout:bool ->
  ?capture_stderr:capture_stderr_type ->
  ?interval:float ->
  ?args:string list -> string -> t

(** {2 Capturing} *)

(** [capture_in_process ?check ?capture_stdout ?capture_stderr ?interval f]
    captures data output to stdout/stderr during execution of a function [f].

    NOTE: [capture_in_process] creates a new subprocess and evaluates [f] in the
    subprocess. Therefore [f] cannot modify memory of the parent process.
    For example, the following snippet results in [0], not [42].

    {[let r = ref 0 in
      let _ = capture_in_process (fun () -> r := 42) in
      !r (* 0, not 42 *)]}

    @param check           raises an execption when a process fails (default = [true])
    @param capture_stdout  default = [true]
    @param capture_stderr  default = [`No]
    @param interval        timeout of [Unix.select] for waiting IO (default = [0.1] seconds)

    @return an execution result of a subprocess.

    @since 2.8.0 *)
val capture_in_process :
  ?check:bool ->
  ?capture_stdout:bool ->
  ?capture_stderr:capture_stderr_type ->
  ?interval:float ->
  (unit -> 'a) -> t
