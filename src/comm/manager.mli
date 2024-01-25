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

(** User-defined communication

    @since 0.1.0 *)

(** This module provides communication of arbitrary JSON data between the OCaml
    REPL and the Jupyter.
    See {{:https://jupyter-client.readthedocs.io/en/stable/messaging.html#custom-messages}
    Comms (Jupyter Notebook Docs)} for details.

    {2 Opening a comm from the REPL}

    {b OCaml}:

    {[
      let target = Target.create "comm-test" in
      let comm = Comm.create target in   (* Send comm_open to the frontend *)
      Comm.send comm (`String "Hello") ; (* Send comm_msg to the frontend *)
      Comm.close comm                    (* Send comm_close to the frontend *)
    ]}

    {b JavaScript}:

    {[
      Jupyter.notebook.kernel.comm_manager.register_target('comm-test', function(comm, msg){
          console.log('opened comm', msg);
          comm.recv_msg(function (msg) { console.log('got msg', msg); });
        })
    ]}

    {2 Opening a comm from the frontend}

    {b OCaml}:

    {[
      let target = Target.create "comm-test"
          ~recv_open:(fun comm json -> ...) (* Receive json = `String "opening" *)
          ~recv_msg:(fun comm json -> ...) (* Receive json = `String "msg" *)
          ~recv_close:(fun comm json -> ...) (* Receive json = `String "closing" *)
    ]}

    {b JavaScript}:

    {[
      comm = Jupyter.notebook.kernel.comm_manager.new_comm('comm-test', 'opening');
      comm.send('msg');
      comm.close('closing');
    ]} *)

type target
type comm

module Target :
sig
  type t = target

  val to_string : t -> string

  val create :
    ?recv_open:(comm -> Yojson.Safe.t -> unit) ->
    ?recv_msg:(comm -> Yojson.Safe.t -> unit) ->
    ?recv_close:(comm -> Yojson.Safe.t -> unit) ->
    string -> t

  val close : t -> unit
end

module Comm :
sig
  type t = comm

  val to_string : t -> string

  (** Get all opened comms.
      @param target_name filtering by a target name. default = no filter *)
  val comms : ?target_name:string -> unit -> (t * Target.t) list

  (** Send an open message to Jupyter. *)
  val create : ?data:Yojson.Safe.t -> Target.t -> t

  (** Send a close message to Jupyter. *)
  val close : ?data:Yojson.Safe.t -> t -> unit

  (** Send a message to Jupyter. *)
  val send : t -> Yojson.Safe.t -> unit

  (**/**)

  (** Don't use. *)
  val recv : Jupyter.Shell.request -> unit
end
