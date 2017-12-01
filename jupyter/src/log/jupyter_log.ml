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

open Format

let name = "ocaml-jupyter"

let logger =
  Lwt_log.channel
    ~template:"$(date).$(milliseconds) $(level) [$(section)]: $(message)"
    ~close_mode:`Keep
    ~channel:Lwt_io.stdout ()

let section = Lwt_log.Section.make name (* log section *)

let set_level level = Lwt_log.add_rule name level

let kasprintf k fmt = (* defined for compatibility with OCaml 4.02 *)
  let b = Buffer.create 16 in
  kfprintf
    (fun ppf ->
       pp_print_flush ppf () ;
       k (Buffer.contents b))
    (formatter_of_buffer b)
    fmt

let printf ~level fmt =
  kasprintf (fun s -> Lwt_log.ign_log ~logger ~section ~level s) fmt

let debug fmt = printf ~level:Lwt_log.Debug fmt

let info fmt = printf ~level:Lwt_log.Info fmt

let notice fmt = printf ~level:Lwt_log.Notice fmt

let warning fmt = printf ~level:Lwt_log.Warning fmt

let error fmt = printf ~level:Lwt_log.Error fmt

let fatal fmt = printf ~level:Lwt_log.Fatal fmt
