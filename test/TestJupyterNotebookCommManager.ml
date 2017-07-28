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
open JupyterKernelMessage
open JupyterCommMessage

let exec = TestJupyterNotebookUnsafe.exec

let ctx = TestJupyterNotebook.ctx

(** {2 Test suite} *)

let test_send ctxt =
  match exec ~ctx {|
let t = JupyterNotebook.CommManager.Target.create "comm-test" in
let c = JupyterNotebook.CommManager.Comm.create t ~data:(`String "OPEN") in
JupyterNotebook.CommManager.Comm.send c (`String "MSG") ;
JupyterNotebook.CommManager.Comm.close c ~data:(`String "CLOSE")
|} with
  | [`Iopub { parent_header = Some ph1; content = `Comm_open co; _ };
     `Iopub { parent_header = Some ph2; content = `Comm_msg cm; _ };
     `Iopub { parent_header = Some ph3; content = `Comm_close cc; _ };
     `Ok "- : unit = ()\n"]->
    assert_equal ~ctxt ctx.header ph1 ;
    assert_equal ~ctxt (Some "comm-test") co.target_name ;
    assert_equal ~ctxt (`String "OPEN") co.data ;
    assert_equal ~ctxt ctx.header ph2 ;
    assert_equal ~ctxt None cm.target_name ;
    assert_equal ~ctxt co.comm_id cm.comm_id ;
    assert_equal ~ctxt (`String "MSG") cm.data ;
    assert_equal ~ctxt ctx.header ph3 ;
    assert_equal ~ctxt None cc.target_name ;
    assert_equal ~ctxt co.comm_id cc.comm_id ;
    assert_equal ~ctxt (`String "CLOSE") cc.data ;
  | xs ->
    assert_failure ("Unexpected sequence: " ^ TestJupyterReplProcess.printer xs)

let make_comm msg_type content =
  `Shell {
    zmq_ids = []; buffers = []; metadata = "";
    content; parent_header = None;
    header = {
      msg_id = "";
      msg_type;
      session = "";
      date = None;
      username = "";
      version = "";
    };
  }

let test_recv ctxt =
  let comm_id = "abcd-1234" in
  let post_exec repl =
    let%lwt () = JupyterReplProcess.send repl
        (make_comm "comm_open" (`Comm_open {
             target_name = Some "comm-test";
             comm_id;
             data = `String "OPEN";
           })) in
    let%lwt () = JupyterReplProcess.send repl
        (make_comm "comm_msg" (`Comm_msg {
             target_name = None;
             comm_id;
             data = `String "MSG";
           })) in
    let%lwt () = JupyterReplProcess.send repl
        (make_comm "comm_close" (`Comm_close {
             target_name = None;
             comm_id;
             data = `String "CLOSE";
           })) in
    Lwt_unix.sleep 1.0 (* wait for receiving in notebook. *)
  in
  match exec ~ctx ~post_exec {|
let recv _ j = print_endline (Yojson.Safe.to_string j) in
JupyterNotebook.CommManager.Target.create "comm-test"
  ~recv_open:recv ~recv_msg:recv ~recv_close:recv
|} with
  | [_; `Stdout "\"OPEN\"\n"; `Stdout "\"MSG\"\n"; `Stdout "\"CLOSE\"\n"] -> ()
  | xs ->
    assert_failure ("Unexpected sequence: " ^ TestJupyterReplProcess.printer xs)

let suite =
  "JupyterNotebook.CommManager" >::: [
    "send" >:: test_send;
    "recv" >:: test_recv;
  ]
