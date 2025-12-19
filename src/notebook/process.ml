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

type t =
  {
    exit_status : process_status;
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

let () = Printexc.register_printer (function
    | Execution_failure r ->
      Some (Format.sprintf "Execution_failure(%s)" ([%show: t] r))
    | _ -> None)

(** {2 Capturing} *)

let run_in_process
    ?(capture_stdin = false)
    ?(capture_stdout = false)
    ?(capture_stderr = `No)
    f
  =
  let stdin_r, stdin_w = Unix.pipe () in
  let stdout_r, stdout_w = Unix.pipe () in
  let stderr_r, stderr_w = Unix.pipe () in
  match Unix.fork () with
  | 0 -> (* in a child process *)
    Unix.close stdin_w ;
    Unix.close stdout_r ;
    Unix.close stderr_r ;
    if capture_stdin then Unix.dup2 stdin_r Unix.stdin ;
    if capture_stdout || capture_stderr = `Redirect_to_stdout then Unix.dup2 stdout_w Unix.stdout ;
    begin
      match capture_stderr with
      | `No -> ()
      | `Yes -> Unix.dup2 stderr_w Unix.stderr
      | `Redirect_to_stdout ->
        Unix.dup2 Unix.stdout Unix.stderr  ;
        Unix.close Unix.stdout
    end ;
    Unix.close stdin_r ;
    Unix.close stdout_w ;
    Unix.close stderr_w ;
    ignore (f ()) ;
    exit 0
  | pid -> (* in the parent process *)
    Unix.close stdin_r ;
    Unix.close stdout_w ;
    Unix.close stderr_w ;
    (pid, stdin_w, stdout_r, stderr_r)

let is_readable fd timeout =
  let l, _, _ = Unix.select [fd] [] [] timeout in
  l <> []

let try_read ~interval fd buffer bytes =
  let rec aux () =
    if is_readable fd interval then begin
      let k = Unix.read fd bytes 0 (Bytes.length bytes) in
      if k > 0 then begin
        Buffer.add_subbytes buffer bytes 0 k ;
        aux ()
      end
    end in
  try aux ()
  with Unix.Unix_error (Unix.EBADF, _, _) -> () (* fd is already closed. *)

let buffer_size = 128

let capture_and_wait
    ?(check = true)
    ?(interval = 0.1)
    ~capture_stdout
    ~capture_stderr
    pid fin fout ferr
  =
  let bytes = Bytes.create buffer_size in
  let out_buf = Buffer.create buffer_size in
  let err_buf = Buffer.create buffer_size in
  let rec loop () =
    (* First, check the current status of a process. *)
    let pid', status = Unix.(waitpid [WNOHANG; WUNTRACED] pid) in
    if pid' <> 0 then status (* terminate the loop *)
    else begin
      (* Second, try to read from pipes. *)
      try_read ~interval fout out_buf bytes ;
      try_read ~interval ferr err_buf bytes ;
      loop () (* continue the loop *)
    end
  in
  let status = loop () in
  (* Try to read remaining data after termination of a process. *)
  try_read ~interval fout out_buf bytes ;
  try_read ~interval ferr err_buf bytes ;
  (* Close file descriptors of pipes. *)
  Unix.close fin ;
  Unix.close fout ;
  Unix.close ferr ;
  (* Construct an execution result of a process. *)
  let using_out = capture_stdout || capture_stderr = `Redirect_to_stdout in
  let using_err = capture_stderr = `Yes in
  let result = {
    exit_status = status;
    stdout = if using_out then Some (Buffer.contents out_buf) else None;
    stderr = if using_err then Some (Buffer.contents err_buf) else None;
  } in
  (* Check a status if necessary. *)
  if check && status <> Unix.WEXITED 0 then raise (Execution_failure result) ;
  result

let capture_in_process
    ?check
    ?(capture_stdout = true)
    ?(capture_stderr = `No)
    ?interval
    f
  =
  let pid, fin, fout, ferr =
    run_in_process ~capture_stdin:true ~capture_stdout ~capture_stderr f in
  capture_and_wait
    ?check ~capture_stdout ~capture_stderr ?interval pid fin fout ferr

(** {2 Command bindings} *)

let system
    ?check
    ?(capture_stdout = false)
    ?(capture_stderr = `No)
    ?interval
    prog args
  =
  let pid, fin, fout, ferr =
    run_in_process ~capture_stdin:true ~capture_stdout ~capture_stderr
      (fun () -> Unix.execvp prog (Array.of_list args)) in
  capture_and_wait
    ?check ~capture_stdout ~capture_stderr ?interval pid fin fout ferr

let pwd = Unix.getcwd

let cd = Unix.chdir

let ls ?check ?capture_stdout ?capture_stderr ?interval ?(args = []) paths =
  system ?check ?capture_stdout ?capture_stderr ?interval
    "ls" ("ls" :: args @ ("--" :: paths))

let rm ?check ?capture_stdout ?capture_stderr ?interval ?(args = []) paths =
  system ?check ?capture_stdout ?capture_stderr ?interval
    "rm" ("rm" :: args @ ("--" :: paths))

let cp ?check ?capture_stdout ?capture_stderr ?interval ?(args = []) src_path dest_path =
  system ?check ?capture_stdout ?capture_stderr ?interval
    "cp" ("cp" :: args @ ["--"; src_path; dest_path])

let mv ?check ?capture_stdout ?capture_stderr ?interval ?(args = []) src_path dest_path =
  system ?check ?capture_stdout ?capture_stderr ?interval
    "mv" ("mv" :: args @ ["--"; src_path; dest_path])

let eval_script
    ?check ?capture_stdout ?capture_stderr ?interval
    ?(args = []) ~opt prog script
  =
  system
    ?check ?capture_stdout ?capture_stderr ?interval
    prog (prog :: opt :: script :: args)

let sh ?check ?capture_stdout ?capture_stderr ?interval ?args script =
  eval_script ?check ?capture_stdout ?capture_stderr ?interval
    ?args ~opt:"-c" "sh" script

let zsh ?check ?capture_stdout ?capture_stderr ?interval ?args script =
  eval_script ?check ?capture_stdout ?capture_stderr ?interval
    ?args ~opt:"-c" "zsh" script

let bash ?check ?capture_stdout ?capture_stderr ?interval ?args script =
  eval_script ?check ?capture_stdout ?capture_stderr ?interval
    ?args ~opt:"-c" "bash" script

let python3 ?check ?capture_stdout ?capture_stderr ?interval ?args script =
  eval_script ?check ?capture_stdout ?capture_stderr ?interval
    ?args ~opt:"-c" "python3" script

let ruby ?check ?capture_stdout ?capture_stderr ?interval ?args script =
  eval_script ?check ?capture_stdout ?capture_stderr ?interval
    ?args ~opt:"-e" "ruby" script

let perl ?check ?capture_stdout ?capture_stderr ?interval ?args script =
  eval_script ?check ?capture_stdout ?capture_stderr ?interval
    ?args ~opt:"-e" "perl" script
