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
open TestUtil

let printer lst =
  [%to_yojson: JupyterReplProcess.reply list] lst
  |> Yojson.Safe.to_string

let cmp = TestJupyterReplToploop.cmp

let default _ = Lwt.return_unit

let exec ?(pre_exec = default) ?(post_exec = default) ?ctx ?init_file code =
  let repl = Process.create ?init_file () in
  let strm = Process.stream repl in
  let rec recv_all acc =
    Lwt_stream.get strm >>= function
    | None | Some `Prompt -> Lwt.return (List.rev acc)
    | Some reply -> recv_all (reply :: acc)
  in
  Lwt_main.run begin
    let%lwt () = pre_exec repl in
    let%lwt () = Process.run ?ctx ~filename:"//toplevel//" repl code in
    let%lwt resp1 = recv_all [] in
    let%lwt () = post_exec repl in
    let%lwt () = Process.close repl in
    let%lwt resp2 = Lwt_stream.to_list (Process.stream repl) in
    Lwt.return (resp1 @ resp2)
  end

(** {2 Test suite} *)

let test__capture_stdout ctxt =
  let actual =
    exec "print_endline \"Hello World\""
    |> List.sort compare in (* the order of elements is NOT important *)
  let expected = [`Ok "- : unit = ()\n"; `Stdout "Hello World\n"] in
  assert_equal ~ctxt ~printer ~cmp expected actual

let test__capture_stderr ctxt =
  let actual =
    exec "prerr_endline \"Hello World\""
    |> List.sort compare in (* the order of elements is NOT important *)
  let expected = [`Ok "- : unit = ()\n"; `Stderr "Hello World\n"] in
  assert_equal ~ctxt ~printer ~cmp expected actual

(** Check [!Sys.interactive] is [true]. *)
let test__sys_interactive ctxt =
  let actual = exec "!Sys.interactive" in
  let expected = [`Ok "- : bool = true\n"] in
  assert_equal ~ctxt ~printer ~cmp expected actual

let suite =
  "Process" >::: [
    "capture_stdout" >:: test__capture_stdout;
    "capture_stderr" >:: test__capture_stderr;
    "Sys.interactive" >:: test__sys_interactive;
  ]
