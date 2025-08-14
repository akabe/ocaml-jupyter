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
open OUnit2
open Jupyter_notebook.Process

let test__system_creates_a_process ctxt =
  let res = system "/bin/sh" ["/bin/sh"; "-c"; ":"] in
  assert_equal ~ctxt ~printer:[%show: process_status] (Unix.WEXITED 0) res.exit_status ;
  assert_equal ~ctxt ~printer:[%show: string option] None res.stdout ;
  assert_equal ~ctxt ~printer:[%show: string option] None res.stderr

let test__system_searches_a_program_in_PATH ctxt =
  let res = system "sh" ["sh"; "-c"; ":"] in
  assert_equal ~ctxt ~printer:[%show: process_status] (Unix.WEXITED 0) res.exit_status ;
  assert_equal ~ctxt ~printer:[%show: string option] None res.stdout ;
  assert_equal ~ctxt ~printer:[%show: string option] None res.stderr

let test__system_captures_stdout ctxt =
  let res = system ~capture_stdout:true "echo" ["echo"; "foobaz"] in
  assert_equal ~ctxt ~printer:[%show: process_status] (Unix.WEXITED 0) res.exit_status ;
  assert_equal ~ctxt ~printer:[%show: string option] (Some "foobaz\n") res.stdout ;
  assert_equal ~ctxt ~printer:[%show: string option] None res.stderr

let test__system_captures_stderr ctxt =
  let res = system ~capture_stderr:`Yes "sh" ["sh"; "-c"; "echo foobaz >&2"] in
  assert_equal ~ctxt ~printer:[%show: process_status] (Unix.WEXITED 0) res.exit_status ;
  assert_equal ~ctxt ~printer:[%show: string option] None res.stdout ;
  assert_equal ~ctxt ~printer:[%show: string option] (Some "foobaz\n") res.stderr

let test__system_captures_stderr_redirected_to_stdout ctxt =
  let res = system ~capture_stderr:`Redirect_to_stdout "sh" ["sh"; "-c"; "echo foobaz >&2"] in
  assert_equal ~ctxt ~printer:[%show: process_status] (Unix.WEXITED 0) res.exit_status ;
  assert_equal ~ctxt ~printer:[%show: string option] (Some "foobaz\n") res.stdout ;
  assert_equal ~ctxt ~printer:[%show: string option] None res.stderr

let test__system_returns_nonzero_status_if_check_is_false ctxt =
  let res = system ~check:false "test" ["test"; "1"; "-eq"; "2"] in
  assert_equal ~ctxt ~printer:[%show: process_status] (Unix.WEXITED 1) res.exit_status ;
  assert_equal ~ctxt ~printer:[%show: string option] None res.stdout ;
  assert_equal ~ctxt ~printer:[%show: string option] None res.stderr

let test__system_raises_an_exception_if_check_is_true _ctxt =
  assert_raises
    (Execution_failure {
        exit_status = Unix.WEXITED 1;
        stdout = None;
        stderr = None;
      })
    (fun () -> system ~check:true "test" ["test"; "1"; "-eq"; "2"])

let test__sh ctxt =
  let res = sh ~capture_stdout:true "echo ok" in
  assert_equal ~ctxt ~printer:[%show: process_status] (Unix.WEXITED 0) res.exit_status ;
  assert_equal ~ctxt ~printer:[%show: string option] (Some "ok\n") res.stdout ;
  assert_equal ~ctxt ~printer:[%show: string option] None res.stderr

let test__zsh ctxt =
  let res = zsh ~capture_stdout:true "echo ok" in
  assert_equal ~ctxt ~printer:[%show: process_status] (Unix.WEXITED 0) res.exit_status ;
  assert_equal ~ctxt ~printer:[%show: string option] (Some "ok\n") res.stdout ;
  assert_equal ~ctxt ~printer:[%show: string option] None res.stderr

let test__bash ctxt =
  let res = bash ~capture_stdout:true "echo ok" in
  assert_equal ~ctxt ~printer:[%show: process_status] (Unix.WEXITED 0) res.exit_status ;
  assert_equal ~ctxt ~printer:[%show: string option] (Some "ok\n") res.stdout ;
  assert_equal ~ctxt ~printer:[%show: string option] None res.stderr

let test__python2 ctxt =
   let res = python2 ~capture_stdout:true "print 'ok'" in
   assert_equal ~ctxt ~printer:[%show: process_status] (Unix.WEXITED 0) res.exit_status ;
   assert_equal ~ctxt ~printer:[%show: string option] (Some "ok\n") res.stdout ;
   assert_equal ~ctxt ~printer:[%show: string option] None res.stderr

let test__python3 ctxt =
  let res = python3 ~capture_stdout:true "print('ok')" in
  assert_equal ~ctxt ~printer:[%show: process_status] (Unix.WEXITED 0) res.exit_status ;
  assert_equal ~ctxt ~printer:[%show: string option] (Some "ok\n") res.stdout ;
  assert_equal ~ctxt ~printer:[%show: string option] None res.stderr

let test__ruby ctxt =
  let res = ruby ~capture_stdout:true "print 'ok'" in
  assert_equal ~ctxt ~printer:[%show: process_status] (Unix.WEXITED 0) res.exit_status ;
  assert_equal ~ctxt ~printer:[%show: string option] (Some "ok") res.stdout ;
  assert_equal ~ctxt ~printer:[%show: string option] None res.stderr

let test__perl ctxt =
  let res = ruby ~capture_stdout:true "print 'ok'" in
  assert_equal ~ctxt ~printer:[%show: process_status] (Unix.WEXITED 0) res.exit_status ;
  assert_equal ~ctxt ~printer:[%show: string option] (Some "ok") res.stdout ;
  assert_equal ~ctxt ~printer:[%show: string option] None res.stderr

let test__ls ctxt =
  let res = ls ~capture_stdout:true ["./test_process.ml"] in
  assert_equal ~ctxt ~printer:[%show: process_status] (Unix.WEXITED 0) res.exit_status ;
  assert_equal ~ctxt ~printer:[%show: string option] (Some "./test_process.ml\n") res.stdout ;
  assert_equal ~ctxt ~printer:[%show: string option] None res.stderr

let test__rm ctxt =
  let filename = "./test__rm.txt" in
  let oc = open_out filename in
  close_out oc ;

  let res = rm [filename] in
  assert_equal ~ctxt ~printer:[%show: process_status] (Unix.WEXITED 0) res.exit_status ;

  assert_equal ~msg:"A file doesn't exist after rm."
    ~ctxt ~printer:[%show: bool] false (Sys.file_exists filename)

let test__cp ctxt =
  let src_path = "./test__cp1.txt" in
  let dest_path = "./test__cp2.txt" in
  let oc = open_out src_path in
  output_string oc "Hello" ;
  close_out oc ;

  let res = cp src_path dest_path in
  assert_equal ~ctxt ~printer:[%show: process_status] (Unix.WEXITED 0) res.exit_status ;

  let ic = open_in dest_path in
  let line = input_line ic in
  close_in ic ;
  assert_equal ~msg:"dest_path has the same contents as src_path."
    ~ctxt ~printer:[%show: string] "Hello" line

let test__mv ctxt =
  let src_path = "./test__mv1.txt" in
  let dest_path = "./test__mv2.txt" in
  let oc = open_out src_path in
  output_string oc "Hello" ;
  close_out oc ;

  let res = mv src_path dest_path in
  assert_equal ~ctxt ~printer:[%show: process_status] (Unix.WEXITED 0) res.exit_status ;

  let ic = open_in dest_path in
  let line = input_line ic in
  close_in ic ;
  assert_equal ~msg:"dest_path has the same contents as src_path."
    ~ctxt ~printer:[%show: string] "Hello" line
  ;
  assert_equal ~msg:"src_path doesn't exist after mv."
    ~ctxt ~printer:[%show: bool] false (Sys.file_exists src_path)

let suite =
  "Process" >::: [
    "system" >::: [
      "creates a process" >:: test__system_creates_a_process;
      "searches a program in $PATH" >:: test__system_searches_a_program_in_PATH;
      "captures stdout" >:: test__system_captures_stdout;
      "captures stderr" >:: test__system_captures_stderr;
      "captures stderr redirected to stdout" >:: test__system_captures_stderr_redirected_to_stdout;
      "returns non-zero status if check=false" >:: test__system_returns_nonzero_status_if_check_is_false;
      "raises an exception if check=true" >:: test__system_raises_an_exception_if_check_is_true;
    ];
    "sh" >:: test__sh;
    "zsh" >:: test__zsh;
    "bash" >:: test__bash;
    "python2" >:: test__python2;
    "python3" >:: test__python3;
    "ruby" >:: test__ruby;
    "perl" >:: test__perl;
    "ls" >:: test__ls;
    "rm" >:: test__rm;
    "cp" >:: test__cp;
    "mv" >:: test__mv;
  ]
