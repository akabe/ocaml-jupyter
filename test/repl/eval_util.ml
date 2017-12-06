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
open Jupyter
open Jupyter.Message
open Jupyter.Iopub
open Jupyter_repl

let default_ctx =
  {
    zmq_ids = []; buffers = []; metadata = ""; parent_header = None;
    header = {
      msg_id = "D62CC8AD-F6F8-4FD0-AD4A-DD215A306116";
      msg_type = "execute_request";
      session = "";
      date = None;
      username = "";
      version = "";
    };
    content = Shell.(SHELL_EXEC_REQ {
        exec_code = "";
        exec_silent = false;
        exec_store_history = true;
        exec_user_expr = `Null;
        exec_allow_stdin = true;
        exec_stop_on_error = true;
      });
  }

let lwt_ignore _ = Lwt.return_unit

let is_topfind_log = function
  | IOPUB_REP { content = IOPUB_STREAM {
      stream_name = IOPUB_STDOUT; stream_text;
    }; _ } ->
    begin
      match stream_text with
      | "Findlib has been successfully loaded. Additional directives:\n"
      | "  #require \"package\";;      to load a package\n"
      | "  #list;;                   to list the available packages\n"
      | "  #camlp4o;;                to load camlp4 (standard syntax)\n"
      | "  #camlp4r;;                to load camlp4 (revised syntax)\n"
      | "  #predicates \"p,q,...\";;   to set these predicates\n"
      | "  Topfind.reset();;         to force that packages will be reloaded\n"
      | "  #thread;;                 to enable threads\n"
      | "\n" -> true
      | _ -> false
    end
  | _ -> false

let eval
    ?(ctx = default_ctx)
    ?(post_exec = lwt_ignore)
    ?init_file ?(count = 0) code
  =
  let repl = Process.create ?init_file () in
  let strm = Process.stream repl in
  Lwt_main.run begin
    let%lwt _ = Process.eval ~ctx ~count repl code in
    let%lwt () = post_exec repl in
    let%lwt () = Process.close repl in
    Lwt_stream.to_list strm
  end
  |> List.filter (fun msg -> not (is_topfind_log msg))
