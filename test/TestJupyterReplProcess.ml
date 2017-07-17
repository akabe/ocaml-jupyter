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
open JupyterRepl
open JupyterRepl.Message
open TestUtil

let printer = TestJupyterReplToploop.printer
let cmp = TestJupyterReplToploop.cmp

let exec code =
  Lwt_main.run begin
    let repl = Process.create () in
    let%lwt () = Process.(send repl { filename = "//toplevel//"; code; }) in
    let%lwt resp1 = Process.recv repl in
    let%lwt () = Process.close repl in
    let%lwt resp2 = Lwt_stream.to_list (Process.stream repl) in
    Lwt.return (resp1 @ resp2)
  end

(** {2 Test suite} *)

let test__capture_stdout ctxt =
  let actual = exec "print_endline \"Hello World\"" in
  let expected = [Stdout "Hello World"; Ok "- : unit = ()\n"; Prompt] in
  assert_equal ~ctxt ~cmp ~printer expected actual

let test__capture_stderr ctxt =
  let actual = exec "prerr_endline \"Hello World\"" in
  let expected = [Stderr "Hello World"; Ok "- : unit = ()\n"; Prompt] in
  assert_equal ~ctxt ~cmp ~printer expected actual

let suite =
  "Process" >::: [
    "capture_stdout" >:: test__capture_stdout;
    "capture_stderr" >:: test__capture_stderr;
  ]
