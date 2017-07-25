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

(** Messages on IOPUB channel *)

(** {2 Streams} *)

type stream_name =
  [
    | `Stdout [@name "stdout"]
    | `Stderr [@name "stderr"]
  ] [@@deriving yojson { strict = false }]

type stream =
  {
    name : stream_name JupyterJson.enum;
    text : string;
  } [@@deriving yojson { strict = false }]

(** {2 Display data} *)

type transient =
  {
    display_id : string;
  } [@@deriving yojson { strict = false }]

type display_data =
  {
    data : Yojson.Safe.json;
    metadata : Yojson.Safe.json;
    transient : transient option [@default None];
  } [@@deriving yojson { strict = false }]

(** {2 Code inputs} *)

type execute_input =
  {
    code : string;
    execution_count : int;
  } [@@deriving yojson { strict = false }]

(** {2 Execution results} *)

type execute_result =
  {
    execution_count : int;
    data : Yojson.Safe.json;
    metadata : Yojson.Safe.json;
  } [@@deriving yojson { strict = false }]

(** {2 Kernel status} *)

type execution_status =
  [
    | `Busy     [@name "busy"]
    | `Idle     [@name "idle"]
    | `Starting [@name "starting"]
  ] [@@deriving yojson]

type status =
  {
    execution_state : execution_status JupyterJson.enum;
  } [@@deriving yojson { strict = false }]

(** {2 Execution errors} *)

type error =
  {
    ename : string;
    evalue : string;
    traceback : string list;
  } [@@deriving yojson { strict = false }]

(** {2 Clear output} *)

type clear_output =
  {
    wait : bool;
  } [@@deriving yojson { strict = false }]

(** {2 Request} *)

type request = unit [@@deriving yojson]

(** {2 Reply} *)

type reply =
  [
    | `Stream of stream [@name "stream"]
    | `Display_data of display_data [@name "display_data"]
    | `Update_display_data of display_data [@name "update_display_data"]
    | `Execute_input of execute_input [@name "execute_input"]
    | `Execute_result of execute_result [@name "execute_result"]
    | `Execute_error of error [@name "error"]
    | `Status of status [@name "status"]
    | `Clear_output of clear_output [@name "clear_output"]
    | JupyterCommMessage.t
  ] [@@deriving yojson]
