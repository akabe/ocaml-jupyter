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
open Jupyter.Message
open Jupyter.Iopub
open Jupyter.Shell
open Jupyter.Comm
open Jupyter_repl
open Eval_util

let pp_reply ppf reply =
  [%to_yojson: Jupyter.Message.reply] reply
  |> Yojson.Safe.to_string
  |> pp_print_string ppf

let eval = eval ~init_file:"fixtures/nbcomminit.ml"

(** {2 Test suite} *)

let test_send ctxt =
  {| let t = Jupyter_comm.Manager.Target.create "comm-test" in
     let c = Jupyter_comm.Manager.Comm.create t ~data:(`String "OPEN") in
     Jupyter_comm.Manager.Comm.send c (`String "MSG") ;
     Jupyter_comm.Manager.Comm.close c ~data:(`String "CLOSE") |}
  |> eval |> function
  | [IOPUB_REP { parent_header = Some ph1; content = IOPUB_COMM_OPEN co; _ };
     IOPUB_REP { parent_header = Some ph2; content = IOPUB_COMM_MSG cm; _ };
     IOPUB_REP { parent_header = Some ph3; content = IOPUB_COMM_CLOSE cc; _ };
     IOPUB_REP { parent_header = Some ph4; content = c1; _ };
     SHELL_REP { parent_header = Some ph5; content = c2; _ }] ->
    assert_equal ~ctxt default_ctx.header ph1 ;
    assert_equal ~ctxt default_ctx.header ph2 ;
    assert_equal ~ctxt default_ctx.header ph3 ;
    assert_equal ~ctxt default_ctx.header ph4 ;
    assert_equal ~ctxt default_ctx.header ph5 ;
    assert_equal ~ctxt (Some "comm-test") co.comm_target ;
    assert_equal ~ctxt (`String "OPEN") co.comm_data ;
    assert_equal ~ctxt None cm.comm_target ;
    assert_equal ~ctxt co.comm_id cm.comm_id ;
    assert_equal ~ctxt (`String "MSG") cm.comm_data ;
    assert_equal ~ctxt None cc.comm_target ;
    assert_equal ~ctxt co.comm_id cc.comm_id ;
    assert_equal ~ctxt (`String "CLOSE") cc.comm_data ;
    assert_equal ~ctxt (Evaluation.iopub_success ~count:0 "- : unit = ()\n") c1 ;
    assert_equal ~ctxt (execute_reply ~count:0 SHELL_OK) c2
  | xs ->
    assert_failure ("Unexpected sequence: " ^ [%show: reply list] xs)

let make_comm msg_type content =
  SHELL_REQ {
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
    let%lwt () = Process.send repl
        (make_comm "comm_open" (SHELL_COMM_OPEN {
             comm_target = Some "comm-test";
             comm_id;
             comm_data = `String "OPEN";
           })) in
    let%lwt () = Process.send repl
        (make_comm "comm_msg" (SHELL_COMM_MSG {
             comm_target = None;
             comm_id;
             comm_data = `String "MSG";
           })) in
    let%lwt () = Process.send repl
        (make_comm "comm_close" (SHELL_COMM_CLOSE {
             comm_target = None;
             comm_id;
             comm_data = `String "CLOSE";
           })) in
    Lwt_unix.sleep 1.0 (* wait for receiving in notebook. *)
  in
  {| let recv _ j = print_endline (Yojson.Safe.to_string j) in
     Jupyter_comm.Manager.Target.create "comm-test"
       ~recv_open:recv ~recv_msg:recv ~recv_close:recv |}
  |> eval ~post_exec
  |> List.sort compare
  |> function
  | [SHELL_REP { parent_header = Some ph1; content = c1; _ };
     IOPUB_REP { parent_header = Some ph2; content = c2; _ };
     IOPUB_REP { parent_header = Some ph3; content = c3; _ };
     IOPUB_REP { parent_header = Some ph4; content = c4; _ };
     IOPUB_REP { parent_header = Some ph5; content = c5; _ }] ->
    assert_equal ~ctxt default_ctx.header ph1 ;
    assert_equal ~ctxt default_ctx.header ph2 ;
    assert_equal ~ctxt default_ctx.header ph3 ;
    assert_equal ~ctxt default_ctx.header ph4 ;
    assert_equal ~ctxt default_ctx.header ph5 ;
    assert_equal ~ctxt (execute_reply ~count:0 SHELL_OK) c1 ;
    assert_equal ~ctxt (stream ~name:IOPUB_STDOUT "\"CLOSE\"\n") c2 ;
    assert_equal ~ctxt (stream ~name:IOPUB_STDOUT "\"MSG\"\n") c3 ;
    assert_equal ~ctxt (stream ~name:IOPUB_STDOUT "\"OPEN\"\n") c4 ;
    assert_equal ~ctxt (Evaluation.iopub_success ~count:0 "- : Jupyter_comm.Manager.Target.t = <abstr>\n") c5
  | xs ->
    assert_failure ("Unexpected sequence: " ^ [%show: reply list] xs)

let suite =
  "Jupyter_comm.Manager" >::: [
    "send" >:: test_send;
    "recv" >:: test_recv;
  ]

let () = run_test_tt_main suite
