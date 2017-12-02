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

(** ANSI escape sequence *)

let reset = "\x1b[0m"
let bold = "\x1b[1m"
let faint = "\x1b[2m"
let italic = "\x1b[3m"
let underline = "\x1b[4m"

(** Foreground colors *)
module FG =
struct
  let black = "\x1b[30m"
  let red = "\x1b[31m"
  let green = "\x1b[32m"
  let yellow = "\x1b[33m"
  let blue = "\x1b[34m"
  let magenta = "\x1b[35m"
  let cyan = "\x1b[36m"
  let white = "\x1b[37m"
  let default = "\x1b[39m"
end
