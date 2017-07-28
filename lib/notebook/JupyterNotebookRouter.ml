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

(** {2 Routing messages from Jupyter} *)

let comm_info_request parent target_name =
  let comms =
    JupyterNotebookCommManager.Comm.comms ?target_name ()
    |> List.map
      (fun (comm, target) ->
         let target_name = JupyterNotebookCommManager.Target.to_string target in
         let comm_id = JupyterNotebookCommManager.Comm.to_string comm in
         `Assoc [comm_id, `Assoc ["target_name", `String target_name]])
    |> fun comms -> `List comms
  in
  let content = `Comm_info_reply Jupyter.ShellMessage.{ comms } in
  let message =
    Jupyter.KernelMessage.create_next parent content
      ~content_to_yojson:[%to_yojson: Jupyter.ShellMessage.reply] in
  JupyterNotebookUnsafe.send (`Shell message)

let _ =
  let loop () =
    while true do
      match JupyterNotebookUnsafe.recv () with
      | exception End_of_file -> Thread.exit ()
      | `Shell msg ->
        begin
          match msg.Jupyter.KernelMessage.content with
          | `Comm_open _ | `Comm_msg _ | `Comm_close _ as comm ->
            JupyterNotebookCommManager.Comm.recv comm
          | `Comm_info_request ({ Jupyter.ShellMessage.target_name }) ->
            comm_info_request msg target_name
          | _ -> ()
        end
    done
  in
  Thread.create loop ()
