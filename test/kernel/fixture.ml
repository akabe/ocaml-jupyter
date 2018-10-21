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

open Jupyter.Shell
open Jupyter.Iopub
open Jupyter.Message

let ctx = Zmq.Context.create ()

module KernelInfoRequest =
struct
  let key = "ecb9a979-64796cba22fc6fe34e179b52"
  let hmac = "f444b4709915556ccfebbcca9729c3b9cf0cc1192f1f9a8077be1f50b4bb8185"
  let header = "{\"msg_type\":\"kernel_info_request\",\
                \"date\":\"2017-07-09T16:15:21.326867Z\",\
                \"session\":\"70603B44BDCD46A2A687C03A44CE6972\",\
                \"version\":\"5.2\",\
                \"username\":\"aabe\",\
                \"msg_id\":\"4144a9a0-084206effad5bfc29c998d69\"}"
  let parent_header = "{}"
  let metadata = "{}"
  let content = "{}"

  let zmq_ids = []
  let buffers = []

  let message =
    {
      zmq_ids; metadata; buffers;
      header = {
        msg_type = "kernel_info_request";
        date = Some "2017-07-09T16:15:21.326867Z";
        session = "70603B44BDCD46A2A687C03A44CE6972";
        version = "5.2";
        username = "aabe";
        msg_id = "4144a9a0-084206effad5bfc29c998d69";
      };
      parent_header = None;
      content = SHELL_KERNEL_INFO_REQ;
    }
end

module KernelInfoReply =
struct
  let key = "167ff8c8-fe494afc147b4fa62758ed82"
  let hmac = "cb3ad6e9e1f39949e212eccf45c216361d64452c39f81bea8e5bef18edcd5569"
  let header = "{\"msg_id\":\"3a21737c-0287-30f3-bfa9-12e193dfd00a\",\
                \"msg_type\":\"kernel_info_reply\",\
                \"session\":\"A32B9A2038D043F2A0718550AAAFC9DA\",\
                \"date\":\"2017-07-11T07:56:15Z\",\
                \"username\":\"aabe\",\
                \"version\":\"5.2\"}"
  let parent_header = "{\"msg_id\":\"b83bf59a-6b1faad93bffba84767d2cf1\",\
                       \"msg_type\":\"kernel_info_request\",\
                       \"session\":\"A32B9A2038D043F2A0718550AAAFC9DA\",\
                       \"date\":\"2017-07-11T07:56:15.369163Z\",\
                       \"username\":\"aabe\",\
                       \"version\":\"5.2\"}"
  let content = "{\"protocol_version\":\"5.2\",\
                 \"implementation\":\"ocaml-jupyter\",\
                 \"implementation_version\":\"5.0.0\",\
                 \"banner\":\"This is banner text.\",\
                 \"help_links\":[],\
                 \"language_info\":{\
                 \"name\":\"OCaml\",\
                 \"version\":\"4.04.1\",\
                 \"mimetype\":\"text/ocaml\",\
                 \"file_extension\":\".ml\",\
                 \"pygments_lexer\":null,\
                 \"codemirror_mode\":\"OCaml\",\
                 \"nbconverter_exporter\":null},\
                 \"language\":\"OCaml\"}"
  let metadata = "{}"
  let buffers = []

  let message =
    {
      zmq_ids = []; metadata; buffers;
      header = {
        msg_id = "3a21737c-0287-30f3-bfa9-12e193dfd00a";
        msg_type = "kernel_info_reply";
        session = "A32B9A2038D043F2A0718550AAAFC9DA";
        date = Some "2017-07-11T07:56:15Z";
        username = "aabe";
        version = "5.2";
      };
      parent_header = Some {
          msg_id = "b83bf59a-6b1faad93bffba84767d2cf1";
          msg_type = "kernel_info_request";
          session = "A32B9A2038D043F2A0718550AAAFC9DA";
          date = Some "2017-07-11T07:56:15.369163Z";
          username = "aabe";
          version = "5.2";
        };
      content = SHELL_KERNEL_INFO_REP {
          kernel_prot_ver = "5.2";
          kernel_impl = "ocaml-jupyter";
          kernel_impl_ver = "5.0.0";
          kernel_banner = "This is banner text.";
          kernel_help_links = [];
          kernel_lang = "OCaml";
          kernel_lang_info =
            {
              lang_name = "OCaml";
              lang_version = "4.04.1";
              lang_mimetype = "text/ocaml";
              lang_file_ext = ".ml";
              lang_lexer = None;
              lang_mode = `String "OCaml";
              lang_exporter = None;
            };
        };
    }
end

module ExecuteRequest =
struct
  let key = "ecb9a979-64796cba22fc6fe34e179b52"
  let hmac = "79e38cb17893b09b6e573224a4af002e2b492957b252e50f4e1de667779acf91"
  let header = "{\"msg_type\":\"execute_request\",\
                \"date\":\"2017-07-09T16:16:49.832051Z\",\
                \"session\":\"70603B44BDCD46A2A687C03A44CE6972\",\
                \"version\":\"5.0\",\
                \"username\":\"username\",\
                \"msg_id\":\"28CF221772134E67887FF10D7A8749DA\"}"
  let parent_header = "{}"
  let metadata = "{}"
  let content = "{\"code\":\"let x = ()\",\
                 \"user_expressions\":{},\
                 \"stop_on_error\":true,\
                 \"store_history\":true,\
                 \"silent\":false,\
                 \"allow_stdin\":true}"
end
