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
