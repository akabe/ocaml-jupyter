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

open Lwt.Infix
open OUnit2
open Jupyter
open Fixture

module type S =
sig
  val recv : unit -> string list
  val send : string list -> unit
end

module MakeMockChannel(Mock : S) =
  JupyterMessageChannel.Make(ShellContent)(struct
    type t = unit and input = string list and output = string list

    let create ~ctx:_ ~kind:_ _ = ()
    let close () = Lwt.return_unit
    let recv () = Lwt.return @@ Mock.recv ()
    let send () actual = Mock.send actual ; Lwt.return_unit
  end)

let test_recv ctxt =
  let open Fixture.KernelInfoRequest in
  let module Channel = MakeMockChannel(struct
      let send _ = assert false
      let recv () = zmq_ids @ [
          "<IDS|MSG>"; hmac; header; parent_header; metadata; content;
        ] @ buffers
    end) in
  let channel = Channel.create ~key ~ctx ~kind:ZMQ.Socket.rep "" in
  let actual = Lwt_main.run @@ Channel.recv channel in
  assert_equal ~ctxt ~printer:(fun msg ->
      [%to_yojson: ShellContent.request Message.t] msg
      |> Yojson.Safe.to_string)
    message actual

let test_send ctxt =
  let open Fixture.KernelInfoReply in
  let module Channel = MakeMockChannel(struct
      let recv () = assert false
      let send = function
        | ["<IDS|MSG>"; hm; hdr; par; meta; cnt] ->
          assert_equal ~ctxt ~printer:[%show: string] hmac hm ;
          assert_equal ~ctxt ~printer:[%show: string] header hdr ;
          assert_equal ~ctxt ~printer:[%show: string] parent_header par ;
          assert_equal ~ctxt ~printer:[%show: string] metadata meta ;
          assert_equal ~ctxt ~printer:[%show: string] content cnt
        | _ ->
          assert_failure "Unmatched response"
    end) in
  let channel = Channel.create ~key ~ctx ~kind:ZMQ.Socket.rep "" in
  let open Message in
  Lwt_main.run @@ Channel.send channel message

let suite =
  "MessageChannel" >::: [
    "recv" >:: test_recv;
    "send" >:: test_send;
  ]
