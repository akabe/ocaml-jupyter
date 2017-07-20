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

let printer lst =
  [%to_yojson: JupyterReplProcess.reply list] lst
  |> Yojson.Safe.to_string

let exec ?(hook = fun _ -> Lwt.return_unit) code =
  let repl = Process.create () in
  let strm = Process.stream repl in
  let rec recv_all acc =
    Lwt_stream.get strm >>= function
    | None | Some `Prompt -> Lwt.return (List.rev acc)
    | Some reply -> recv_all (reply :: acc)
  in
  Lwt_main.run begin
    let%lwt () = Process.run repl ~filename:"//toplevel//" code in
    let%lwt () = hook repl in
    let%lwt resp1 = recv_all [] in
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
  assert_equal ~ctxt ~printer expected actual

let test__capture_stderr ctxt =
  let actual =
    exec "prerr_endline \"Hello World\""
    |> List.sort compare in (* the order of elements is NOT important *)
  let expected = [`Ok "- : unit = ()\n"; `Stderr "Hello World\n"] in
  assert_equal ~ctxt ~printer expected actual

let test__jupyterout ctxt =
  let actual =
    exec "Marshal.to_channel jupyterout (`Stdout \"Hello\") []"
    |> List.sort compare in (* the order of elements is NOT important *)
  let expected = [`Ok "- : unit = ()\n"; `Stdout "Hello"] in
  assert_equal ~ctxt ~printer expected actual

let test__jupyterin ctxt =
  skip_if
    (not (Sys.file_exists "../_build/lib/core/jupyter.cma"))
    "Not found artifacts" ;
  let hook repl =
    Process.send repl Jupyter.Content.Iopub.(`Comm_open {
        target_name = None;
        comm_id = "abcd";
        data = `Null;
      })
  in
  let actual =
    exec ~hook
      "#directory \"../_build/lib/core\";;\
       #load \"jupyter.cma\";;\
       (Marshal.from_channel jupyterin : Jupyter.Content.Iopub.request)" in
  let expected =
    [
      `Ok "- : Jupyter.Content.Iopub.request =\
           \n`Comm_open\
           \n  {Jupyter.Content.Iopub.target_name = None; comm_id = \"abcd\";\
           \n   data = <abstr>}\n"
    ]
  in
  assert_equal ~ctxt ~printer expected actual

let suite =
  "Process" >::: [
    "capture_stdout" >:: test__capture_stdout;
    "capture_stderr" >:: test__capture_stderr;
    "jupyterout" >:: test__jupyterout;
    "jupyterin" >:: test__jupyterin;
  ]
