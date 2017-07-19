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

(** Messages on SHELL channel *)

type status =
  [
    | `Ok    [@name "ok"]
    | `Error [@name "error"]
    | `Abort [@name "abort"]
  ] JupyterJson.enum [@@deriving yojson]

(** {2 Execute} *)

type execute_request =
  {
    code : string;
    silent : bool;
    store_history : bool;
    user_expressions : Yojson.Safe.json;
    allow_stdin : bool;
    stop_on_error : bool;
  } [@@deriving yojson { strict = false }]

type execute_reply =
  {
    execution_count : int;
    status : status;
  } [@@deriving yojson { strict = false }]

(** {2 Instrospection} *)

type inspect_request =
  {
    code : string;
    cursor_pos : bool;
    detail_level : int [@default 0];
  } [@@deriving yojson { strict = false }]

type inspect_reply =
  {
    status : status;
    found : bool;
    data : Yojson.Safe.json [@default `Null];
    metadata : Yojson.Safe.json [@default `Null];
  } [@@deriving yojson { strict = false }]

(** {2 Completion} *)

type complete_request =
  {
    code : string;
    cursor_pos : int;
  } [@@deriving yojson { strict = false }]

type complete_reply =
  {
    matches : string list;
    cursor_start : int;
    cursor_end : int;
    metadata : Yojson.Safe.json;
    status : status;
    code : string;
    cursor_pos : int;
  } [@@deriving yojson { strict = false }]

(** {2 Connect} *)

type connect_reply =
  {
    shell_port : int;
    iopub_port : int;
    stdin_port : int;
    hb_port : int;
    control_port : int;
  } [@@deriving yojson { strict = false }]

(** {2 Comm info} *)

type comm_info_request =
  {
    target_name : string;
  } [@@deriving yojson { strict = false }]

type comm_info_reply =
  {
    comms : Yojson.Safe.json;
  } [@@deriving yojson { strict = false }]

(** {2 Kernel information} *)

type language_info =
  {
    name : string;
    version : string;
    mimetype : string;
    file_extension : string;
    pygments_lexer : string option;
    codemirror_mode : Yojson.Safe.json;
    nbconverter_exporter : string option;
  } [@@deriving yojson { strict = false }]

type kernel_info_reply =
  {
    protocol_version : string;
    implemenation : string;
    implementation_version : string;
    banner : string option;
    help_links : Yojson.Safe.json;
    language_info : language_info;
    language : string;
  } [@@deriving yojson { strict = false }]

(** The information of this kernel *)
let kernel_info_reply =
  {
    protocol_version = JupyterVersion.protocol_version;
    implemenation = "ocaml-jupyter";
    implementation_version = JupyterVersion.kernel_version;
    banner = None;
    help_links = `Assoc [];
    language = "OCaml";
    language_info =
      {
        name = "OCaml";
        version = JupyterVersion.ocaml_version;
        mimetype = "text/x-ocaml";
        file_extension = ".ml";
        pygments_lexer = Some "OCaml";
        codemirror_mode = `String "text/x-ocaml";
        nbconverter_exporter = None;
      };
  }

(** {2 Kernel shutdown} *)

type shutdown =
  {
    restart : bool;
  } [@@deriving yojson { strict = false }]

(** {2 Request} *)

type request =
  [
    | `Kernel_info_request [@name "kernel_info_request"]
    | `Execute_request of execute_request [@name "execute_request"]
    | `Inspect_request of inspect_request [@name "inspect_request"]
    | `Complete_request of complete_request [@name "complete_request"]
    | `Connect_request [@name "connect_request"]
    | `Comm_info_request of comm_info_request [@name "comm_info_request"]
    | `Shutdown_request of shutdown [@name "shutdown_request"]
  ] [@@deriving yojson { strict = false }]

(** {2 Reply} *)

type reply =
  [
    | `Kernel_info_reply of kernel_info_reply [@name "kernel_info_reply"]
    | `Execute_reply of execute_reply [@name "execute_reply"]
    | `Inspect_reply of inspect_reply [@name "inspect_reply"]
    | `Complete_reply of complete_reply [@name "complete_reply"]
    | `Connect_reply of connect_reply [@name "connect_reply"]
    | `Comm_info_reply of comm_info_reply [@name "comm_info_reply"]
    | `Shutdown_reply of shutdown [@name "shutdown_reply"]
  ] [@@deriving yojson { strict = false }]
