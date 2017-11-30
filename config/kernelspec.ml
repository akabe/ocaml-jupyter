(** Generate kernel.json *)

open Format

type kernelspec =
  {
    display_name : string;
    language : string;
    argv : string list;
  } [@@deriving to_yojson]

let main ~output ~bindir ~home =
  let oc = open_out output in
  let display_name = sprintf "OCaml %s" Sys.ocaml_version in
  `Assoc [
    "display_name", `String display_name;
    "language", `String "OCaml";
    "argv", `List [
      `String (Filename.concat bindir "ocaml-jupyter-kernel");
      `String "--init";
      `String (Filename.concat home ".ocamlinit");
      `String "--merlin";
      `String (Filename.concat bindir "ocamlmerlin");
      `String "--connection-file";
      `String "{connection_file}";
    ];
  ]
  |> Yojson.Safe.pretty_to_channel oc ;
  close_out oc

let read_command cmd =
  let ic = Unix.open_process_in cmd in
  let rec aux acc = match input_line ic with
    | exception End_of_file -> List.rev acc
    | line -> aux (line :: acc)
  in
  let lines = aux [] in
  match Unix.close_process_in ic with
  | Unix.WEXITED 0 -> lines
  | _ -> failwith cmd

let () =
  let home = Sys.getenv "HOME" in
  let bindir = match read_command "opam config var bin" with
    | [bindir] -> bindir
    | msgs -> failwith (sprintf "[opam config var bin] %s@."
                          (String.concat "\n" msgs)) in
  main ~output:"kernel.json" ~bindir ~home
