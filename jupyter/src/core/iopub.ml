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

(** Contents on IOPUB channels *)

(** {2 Streams} *)

type stream_name =
  | IOPUB_STDOUT [@name "stdout"]
      | IOPUB_STDERR [@name "stderr"]
[@@deriving yojson { strict = false }]

type stream =
  {
    stream_name : stream_name Json.enum [@key "name"];
    stream_text : string [@key "text"];
  } [@@deriving yojson { strict = false }]

(** {2 Display data} *)

type transient =
  {
    display_id : string [@key "display_id"];
  } [@@deriving yojson { strict = false }]

type display_data =
  {
    display_data : Yojson.Safe.json [@key "data"];
    display_metadata : Yojson.Safe.json [@key "metadata"];
    display_transient : transient option [@key "transient"] [@default None];
  } [@@deriving yojson { strict = false }]

(** {2 Code inputs} *)

type exec_input =
  {
    exin_code : string [@key "code"];
    exin_count : int [@key "execution_count"];
  } [@@deriving yojson { strict = false }]

(** {2 Execution results} *)

type exec_result =
  {
    exres_count : int [@key "execution_count"];
    exres_data : Yojson.Safe.json [@key "data"];
    exres_metadata : Yojson.Safe.json [@key "metadata"];
  } [@@deriving yojson { strict = false }]

(** {2 Kernel status} *)

type exec_status =
  | IOPUB_BUSY     [@name "busy"]
      | IOPUB_IDLE     [@name "idle"]
      | IOPUB_STARTING [@name "starting"]
[@@deriving yojson]

type status =
  {
    kernel_state : exec_status Json.enum [@key "execution_state"];
  } [@@deriving yojson { strict = false }]

(** {2 Execution errors} *)

type error =
  {
    ename : string [@key "ename"];
    evalue : string [@key "evalue"];
    traceback : string list [@key "traceback"];
  } [@@deriving yojson { strict = false }]

(** {2 Clear output} *)

type clear_output =
  {
    clear_wait : bool [@key "wait"];
  } [@@deriving yojson { strict = false }]

(** {2 IOPUB Request} *)

type request = unit [@@deriving yojson]

(** {2 IOPUB Reply} *)

type reply =
  | IOPUB_STREAM of stream [@name "stream"]
        | IOPUB_DISPLAY_DATA of display_data [@name "display_data"]
        | IOPUB_UPDATE_DISPLAY_DATA of display_data [@name "update_display_data"]
        | IOPUB_EXECUTE_INPUT of exec_input [@name "execute_input"]
        | IOPUB_EXECUTE_RESULT of exec_result [@name "execute_result"]
        | IOPUB_ERROR of error [@name "error"]
        | IOPUB_STATUS of status [@name "status"]
        | IOPUB_CLEAR_OUTPUT of clear_output [@name "clear_output"]
        | IOPUB_COMM_OPEN of Comm.t [@name "comm_open"]
        | IOPUB_COMM_MSG of Comm.t [@name "comm_msg"]
        | IOPUB_COMM_CLOSE of Comm.t [@name "comm_close"]
[@@deriving yojson]

let stream ~name text =
  IOPUB_STREAM { stream_name = name; stream_text = text; }

let execute_result ?(metadata = `Assoc []) ~count data =
  IOPUB_EXECUTE_RESULT {
    exres_count = count;
    exres_data = data;
    exres_metadata = metadata;
  }

let error ?(name = "error") ~value traceback =
  IOPUB_ERROR {
    ename = name;
    evalue = value;
    traceback;
  }
