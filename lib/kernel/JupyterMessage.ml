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

(** Messaging in Jupyter *)

(** The Jupyter protocol version currently supported. *)
let protocol_version = "5.2"

(** {2 Headers} *)

type header =
  {
    msg_id : string; (** typically UUID, must be unique per message *)
    msg_type : string; (** the kind of message *)
    session : string; (** typically UUID, should be unique per session *)
    date : string option [@default None]; (** ISO8601 timestamp for when
                                              the message is created *)
    username : string; (** the current username *)
    version : string; (** the message protocol version *)
  } [@@deriving yojson { strict = false }]

let header_of_string str =
  Yojson.Safe.from_string str
  |> [%of_yojson: header]
  |> JupyterJson.or_die

let header_opt_of_string s =
  Yojson.Safe.from_string s
  |> [%of_yojson: header]
  |> JupyterJson.or_none

let string_of_header hdr =
  [%to_yojson: header] hdr
  |> Yojson.Safe.to_string

let string_of_header_opt = function
  | None -> "{}"
  | Some header -> string_of_header header

(** {2 Top-level message} *)

type 'a t =
  {
    zmq_ids : string list;

    header : header;
    (** The message header contains a pair of unique identifiers for the
        originating session and the actual message id, in addition to the
        username for the process that generated the message.  This is useful in
        collaborative settings where multiple users may be interacting with the
        same kernel simultaneously, so that frontends can label the various
        messages in a meaningful way. *)

    parent_header : header option;
    (** In a chain of messages, the header from the parent is copied so that
        clients can track where messages come from. *)

    metadata : string;
    (** Any metadata associated with the message. *)

    content : 'a;
    (** The actual content of the message must be a dict, whose structure
        depends on the message type. *)

    buffers : string list;
    (** optional: buffers is a list of binary data buffers for implementations
        that support binary extensions to the protocol. *)
  } [@@deriving yojson { strict = false }]
