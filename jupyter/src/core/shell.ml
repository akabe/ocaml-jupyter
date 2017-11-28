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

(** Contents on SHELL channels *)

type status =
  | SHELL_OK    [@name "ok"]
  | SHELL_ERROR [@name "error"]
  | SHELL_ABORT [@name "abort"]
[@@deriving yojson]

(** {2 Execution requests and replies} *)

type exec_request =
  {
    exec_code : string [@key "code"];
    exec_silent : bool [@key "silent"];
    exec_store_history : bool [@key "store_history"];
    exec_user_expr : Yojson.Safe.json [@key "user_expressions"];
    exec_allow_stdin : bool [@key "allow_stdin"];
    exec_stop_on_error : bool [@key "stop_on_error"];
  } [@@deriving yojson { strict = false }]

type exec_reply =
  {
    exec_count : int [@key "execution_count"];
    exec_status : status Json.enum [@key "status"];
  } [@@deriving yojson { strict = false }]

(** {2 Instrospection} *)

type inspect_request =
  {
    insp_code : string [@key "code"];
    insp_pos : int [@key "cursor_pos"];
    insp_detail : int [@key "detail_level"] [@default 0];
  } [@@deriving yojson { strict = false }]

type inspect_reply =
  {
    insp_status : status Json.enum [@key "status"];
    insp_found : bool [@key "found"];
    insp_data : Yojson.Safe.json [@key "data"] [@default `Null];
    insp_metadata : Yojson.Safe.json [@key "metadata"] [@default `Null];
  } [@@deriving yojson { strict = false }]

(** {2 Completion} *)

type complete_request =
  {
    cmpl_code : string [@key "code"];
    cmpl_pos : int [@key "cursor_pos"];
  } [@@deriving yojson { strict = false }]

type complete_reply =
  {
    cmpl_matches : string list [@key "matches"];
    cmpl_start : int option [@key "cursor_start"];
    cmpl_end : int option [@key "cursor_end"];
    cmpl_metadata : Yojson.Safe.json [@key "metadata"];
    cmpl_status : status Json.enum [@key "status"];
  } [@@deriving yojson { strict = false }]

(** {2 History} *)

type history_request =
  {
    hist_output : bool [@key "output"];
    hist_raw : bool [@key "raw"];
    hist_access_type : string [@key "hist_access_type"];
    hist_session : int option [@key "session"] [@default None];
    hist_start : int option [@key "start"] [@default None];
    hist_stop : int option [@key "stop"] [@default None];
    hist_n : int [@key "n"];
    hist_pattern : string option [@key "pattern"] [@default None];
    hist_unique : bool [@key "unique"] [@default false];
  } [@@deriving yojson { strict = false }]

type history_reply =
  {
    history : (int option * int * string) list;
  } [@@deriving yojson { strict = false }]

(** {2 Code completeness} *)

type is_complete_request =
  {
    is_cmpl_code : string [@key "code"];
  } [@@deriving yojson { strict = false }]

type is_complete_reply =
  {
    is_cmpl_status : string [@key "status"];
    is_cmpl_indent : string option [@key "indent"] [@default None];
  } [@@deriving yojson { strict = false }]

(** {2 Connect} *)

type connect_reply =
  {
    conn_shell_port : int [@key "shell_port"];
    conn_iopub_port : int [@key "iopub_port"];
    conn_stdin_port : int [@key "stdin_port"];
    conn_hb_port : int [@key "hb_port"];
    conn_ctrl_port : int [@key "control_port"];
  } [@@deriving yojson { strict = false }]

(** {2 Comm info} *)

type comm_info_request =
  {
    ci_target : string option [@key "target_name"] [@default None];
  } [@@deriving yojson { strict = false }]

type comm_info_reply =
  {
    ci_comms : Yojson.Safe.json [@key "comms"];
  } [@@deriving yojson { strict = false }]

(** {2 Kernel information} *)

type language_info =
  {
    lang_name : string [@key "name"]; (** language name *)
    lang_version : string [@key "version"]; (** language version *)
    lang_mimetype : string [@key "mimetype"]; (** mimetype *)
    lang_file_ext : string [@key "file_extension"]; (** file extension *)
    lang_lexer : string option [@key "pygments_lexer"]; (** pygments lexer *)
    lang_mode : Yojson.Safe.json [@key "codemirror_mode"]; (** codemirror mode *)
    lang_exporter : string option [@key "nbconverter_exporter"];
  } [@@deriving yojson { strict = false }]

let language_info =
  {
    lang_name = "OCaml";
    lang_version = Sys.ocaml_version;
    lang_mimetype = "text/x-ocaml";
    lang_file_ext = ".ml";
    lang_lexer = Some "OCaml";
    lang_mode = `String "text/x-ocaml";
    lang_exporter = None;
  }

type help_link =
  {
    help_text : string [@key "text"];
    help_url : string [@key "url"];
  } [@@deriving yojson { strict = false }]

let help_links =
  [
    {
      help_text = "ocaml-jupyter";
      help_url = "https://akabe.github.io/ocaml-jupyter/";
    }
  ]

type kernel_info_reply =
  {
    kernel_prot_ver : string [@key "protocol_version"]; (** protocol version *)
    kernel_impl : string [@key "implementation"];
    kernel_impl_ver : string [@key "implementation_version"];
    kernel_banner : string option [@key "banner"];
    kernel_help_links : help_link list [@key "help_links"];
    kernel_lang_info : language_info [@key "language_info"];
    kernel_lang : string [@key "language"];
  } [@@deriving yojson { strict = false }]

let kernel_info_reply =
  {
    kernel_prot_ver = Version.protocol_version;
    kernel_impl = "ocaml-jupyter";
    kernel_impl_ver = Version.version;
    kernel_banner = None;
    kernel_help_links = help_links;
    kernel_lang = "OCaml";
    kernel_lang_info = language_info;
  }

(** {2 Kernel shutdown} *)

type shutdown =
  {
    shutdown_restart : bool [@key "restart"];
  } [@@deriving yojson { strict = false }]

(** {2 Request} *)

type request =
  | SHELL_KERNEL_INFO_REQ [@name "kernel_info_request"]
  | SHELL_EXEC_REQ of exec_request [@name "execute_request"]
  | SHELL_INSPECT_REQ of inspect_request [@name "inspect_request"]
  | SHELL_COMPLETE_REQ of complete_request [@name "complete_request"]
  | SHELL_HISTORY_REQ of history_request [@name "history_request"]
  | SHELL_IS_COMPLETE_REQ of is_complete_request [@name "is_complete_request"]
  | SHELL_CONNECT_REQ [@name "connect_request"]
  | SHELL_COMM_INFO_REQ of comm_info_request [@name "comm_info_request"]
  | SHELL_SHUTDOWN_REQ of shutdown [@name "shutdown_request"]
  | SHELL_COMM_OPEN of Comm.t [@name "comm_open"]
  | SHELL_COMM_MSG of Comm.t [@name "comm_msg"]
  | SHELL_COMM_CLOSE of Comm.t [@name "comm_close"]
[@@deriving yojson { strict = false }]

(** {2 Reply} *)

type reply =
  | SHELL_KERNEL_INFO_REP of kernel_info_reply [@name "kernel_info_reply"]
  | SHELL_EXEC_REP of exec_reply [@name "execute_reply"]
  | SHELL_INSPECT_REP of inspect_reply [@name "inspect_reply"]
  | SHELL_COMPLETE_REP of complete_reply [@name "complete_reply"]
  | SHELL_HISTORY_REP of history_reply [@name "history_reply"]
  | SHELL_IS_COMPLETE_REP of is_complete_reply [@name "is_complete_reply"]
  | SHELL_CONNECT_REP of connect_reply [@name "connect_reply"]
  | SHELL_COMM_INFO_REP of comm_info_reply [@name "comm_info_reply"]
  | SHELL_SHUTDOWN_REP of shutdown [@name "shutdown_reply"]
[@@deriving yojson { strict = false }]

let execute_reply ~count status =
  SHELL_EXEC_REP { exec_count = count; exec_status = status; }
