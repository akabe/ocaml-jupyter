(* ocaml-jupyter --- A OCaml kernel for Jupyter

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

let kasprintf k fmt = (* defined for compatibility with OCaml 4.02 *)
  let b = Buffer.create 16 in
  Format.kfprintf
    (fun ppf ->
       Format.pp_print_flush ppf () ;
       k (Buffer.contents b))
    (Format.formatter_of_buffer b)
    fmt

let reporter =
  let report _ level ~over k msgf =
    let with_timestamp ?header ?tags:_ fmt =
      let k' line =
        Lwt.ignore_result @@ Lwt_io.write_line Lwt_io.stdout line ;
        over () ;
        k ()
      in
      let open Unix in
      let t = localtime @@ time () in
      kasprintf k'
        ("%04d-%02d-%02dT%02d:%02d:%02d %a " ^^ fmt)
        (t.tm_year + 1900) (t.tm_mon + 1) t.tm_mday
        t.tm_hour t.tm_min t.tm_sec
        Logs.pp_header (level, header)
    in
    msgf with_timestamp
  in
  { Logs.report }

let src = Logs.Src.create ~doc:"Jupyter kernel for OCaml" "ocaml-jupyter"

let set_level level_str =
  Logs.set_reporter reporter ;
  match Logs.level_of_string level_str with
  | Result.Ok level -> Logs.set_level level
  | Result.Error (`Msg msg) -> failwith msg

let debug f = Lwt.ignore_result @@ Logs_lwt.debug ~src f

let info f = Lwt.ignore_result @@ Logs_lwt.info ~src f

let app f = Lwt.ignore_result @@ Logs_lwt.app ~src f

let warn f = Lwt.ignore_result @@ Logs_lwt.warn ~src f

let error f = Lwt.ignore_result @@ Logs_lwt.err ~src f
