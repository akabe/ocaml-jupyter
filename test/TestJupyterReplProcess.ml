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
open Lwt.Infix
open OUnit2
open JupyterRepl
open Jupyter.ReplMessage
open TestUtil

let exec code =
  let repl = Process.create () in
  let rec recv_all acc =
    Process.recv repl >>= function
    | Prompt -> Lwt.return (List.rev acc)
    | reply -> recv_all (reply :: acc)
  in
  Lwt_main.run begin
    let%lwt () = Process.(send repl (Exec ("//toplevel//", code))) in
    let%lwt resp1 = recv_all [] in
    let%lwt () = Process.close repl in
    let%lwt resp2 = Lwt_stream.to_list (Process.stream repl) in
    Lwt.return (resp1, resp2)
  end

(** {2 Test suite} *)

let test__capture_stdout ctxt =
  let actual_ctrl, actual_out = exec "print_endline \"Hello World\"" in
  assert_equal ~ctxt [Ok "- : unit = ()\n"] actual_ctrl ;
  assert_equal ~ctxt [Stdout "Hello World"] actual_out

let test__capture_stderr ctxt =
  let actual_ctrl, actual_out = exec "prerr_endline \"Hello World\"" in
  assert_equal ~ctxt [Ok "- : unit = ()\n"] actual_ctrl ;
  assert_equal ~ctxt [Stderr "Hello World"] actual_out

let suite =
  "Process" >::: [
    "capture_stdout" >:: test__capture_stdout;
    "capture_stderr" >:: test__capture_stderr;
  ]
