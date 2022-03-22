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

(** Kernel server *)

module Make
    (ShellChannel : Channel_intf.Shell)
    (IopubChannel : Channel_intf.Iopub)
    (StdinChannel : Channel_intf.Stdin)
    (HeartbeatChannel : Channel_intf.Zmq)
    (Repl : module type of Jupyter_repl.Process)
    (Completor : Jupyter_completor.Intf.S) :
sig
  type t =
    {
      completor : Completor.t;
      repl : Repl.t;
      shell : ShellChannel.t;
      control : ShellChannel.t;
      iopub : IopubChannel.t;
      stdin : StdinChannel.t;
      heartbeat : HeartbeatChannel.t;

      mutable execution_count : int;
      mutable current_parent : ShellChannel.input option;
    }

  (** Connect to Jupyter. *)
  val create :
    completor:Completor.t ->
    repl:Repl.t ->
    ctx:Zmq.Context.t ->
    Connection_info.t -> t

  (** Close connection to Jupyter. *)
  val close : t -> unit Lwt.t

  (** Start a thread accepting requests from Jupyter. *)
  val start : t -> unit Lwt.t
end
