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

(** Routing messages from Jupyter *)

open Jupyter
open Jupyter.Shell
open Jupyter.Stdin

(** {2 Stdin} *)

let stdin, stdin_out =
  let fin, fout = Unix.pipe () in
  let ic = Unix.in_channel_of_descr fin in
  let oc = Unix.out_channel_of_descr fout in
  (ic, oc)

let blocking_on_recv value =
  output_string stdin_out value ;
  output_char stdin_out '\n' ;
  flush stdin_out

let on_recv = ref blocking_on_recv

let recv_stdin msg =
  let (STDIN_INPUT_REP { stdin_value }) = msg.Message.content in
  !on_recv stdin_value

(** {2 Comm} *)

let comm_info_request parent target_name =
  let ci_comms =
    Manager.Comm.comms ?target_name ()
    |> List.map
      (fun (comm, target) ->
         let target_name = Manager.Target.to_string target in
         let comm_id = Manager.Comm.to_string comm in
         `Assoc [comm_id, `Assoc ["target_name", `String target_name]])
    |> fun comms -> `List comms
  in
  let content = SHELL_COMM_INFO_REP Shell.{ ci_comms } in
  let message = Message.create_next_shell parent content in
  Jupyter_notebook__Unsafe.send (Message.SHELL_REP message)

let _ =
  let loop () =
    while true do
      match Jupyter_notebook__Unsafe.recv () with
      | exception End_of_file -> Thread.exit ()
      | Message.SHELL_REQ msg ->
        begin
          match msg.Message.content with
          | SHELL_COMM_OPEN _ | SHELL_COMM_MSG _ | SHELL_COMM_CLOSE _ as comm ->
            Manager.Comm.recv comm
          | SHELL_COMM_INFO_REQ ({ Shell.ci_target }) ->
            comm_info_request msg ci_target
          | _ -> ()
        end
      | Message.STDIN_REQ msg -> recv_stdin msg
    done
  in
  Thread.create loop ()
