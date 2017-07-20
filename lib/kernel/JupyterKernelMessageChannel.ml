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

(** Messaging channel for Jupyter *)

open Format
open Lwt.Infix

let compose_content ~msg_type = function
  | `Null | `Assoc [] -> `List [`String msg_type]
  | content -> `List [`String msg_type; content]

module type ContentType =
sig
  type request [@@deriving yojson]
  type reply [@@deriving yojson]
end

module Make (Content : ContentType) (Socket : JupyterKernelChannelIntf.Zmq) =
struct
  type t =
    {
      socket : Socket.t;
      key : Cstruct.t option;
    }

  type request = Content.request
  type reply = Content.reply
  type input = request JupyterKernelMessage.t
  type output = reply JupyterKernelMessage.t

  let create ?key ~ctx ~kind uri =
    let key = match key with
      | None -> None
      | Some key -> Some (Cstruct.of_string key)
    in
    { socket = Socket.create ~ctx ~kind uri; key; }

  let close ch = Socket.close ch.socket

  (** {2 Read requests} *)

  let parse ?key str_lst =
    let rec aux ids = function
      | [] -> failwith "Cannot find <IDS|MSG> marker"
      | "<IDS|MSG>" :: t -> (List.rev ids, t)
      | h :: t -> aux (h :: ids) t
    in
    match aux [] str_lst with
    | ids, hmac :: header :: parent_header :: metadata :: content :: buffers ->
      let open JupyterKernelMessage in
      JupyterKernelLog.debug
        "RECV: HMAC=%s; header=%s; parent=%s; content=%s; metadata=%s"
        hmac header parent_header content metadata ;
      JupyterKernelHmac.validate ?key ~hmac ~header ~parent_header ~metadata ~content () ;
      let header = header_of_string header in
      let content = Yojson.Safe.from_string content
                    |> compose_content ~msg_type:header.msg_type
                    |> [%of_yojson: Content.request]
                    |> JupyterJson.or_die in
      {
        zmq_ids = ids;
        header;
        parent_header = header_opt_of_string parent_header;
        metadata;
        content;
        buffers;
      }

    | _ ->
      failwith "Jupyter kernel request is ill-formed."

  let recv ch = Socket.recv ch.socket >|= parse ?key:ch.key

  (** {2 Write response} *)

  let send ch resp =
    let open JupyterKernelMessage in
    let header = string_of_header resp.header in
    let parent_header = string_of_header_opt resp.parent_header in
    let content =
      match [%to_yojson: Content.reply] resp.content with
      | `List (_ :: content :: _) -> Yojson.Safe.to_string content
      | _ -> "{}" in
    let hmac =
      JupyterKernelHmac.create ?key:ch.key
        ~header ~parent_header ~metadata:resp.metadata ~content ()
    in
    JupyterKernelLog.debug
      "SEND: HMAC=%s; header=%s; parent=%s; content=%s; metadata=%s"
      hmac header parent_header content resp.metadata ;
    [
      resp.zmq_ids;
      [
        "<IDS|MSG>";
        hmac;
        header;
        parent_header;
        resp.metadata;
        content;
      ];
      resp.buffers;
    ]
    |> List.concat
    |> Socket.send ch.socket

  (** {2 Reply} *)

  let reply ?time ~parent ch content =
    JupyterKernelMessage.create_next
      ~content_to_yojson:[%to_yojson: Content.reply]
      ?time parent content
    |> send ch

end
