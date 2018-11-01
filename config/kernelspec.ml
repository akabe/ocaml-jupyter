(** Generate kernel.sh and kernel.json *)

open Format

type kernelspec =
  {
    display_name : string;
    language : string;
    argv : string list;
  } [@@deriving to_yojson]

let write_kernelspec_json ~output ~bindir ~sharedir ~switch ~home =
  let oc = open_out output in
  let display_name = sprintf "OCaml %s" switch in
  `Assoc [
    "display_name", `String display_name;
    "language", `String "OCaml";
    "argv", `List [
      `String "/bin/sh";
      `String (Filename.(concat sharedir (concat "jupyter" "kernel.sh")));
      `String "-init";
      `String (Filename.concat home ".ocamlinit");
      `String "--merlin";
      `String (Filename.concat bindir "ocamlmerlin");
      `String "--verbosity";
      `String "app";
      `String "--connection-file";
      `String "{connection_file}";
    ];
  ]
  |> Yojson.Safe.pretty_to_channel oc ;
  close_out oc

let write_kernel_sh ~output ~bindir ~switch =
  let oc = open_out output in
  sprintf "\
  #!/bin/sh\n\
  \n\
  eval `opam config env %S` && %S \"$@\"\n"
    ("--switch=" ^ switch)
    (Filename.concat bindir "ocaml-jupyter-kernel")
  |> output_string oc ;
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

let read_command_line cmd =
  match read_command cmd with
  | [switch] -> switch
  | msgs -> failwith (sprintf "[%s] %s@." cmd (String.concat "\n" msgs))

let () =
  let home = Sys.getenv "HOME" in
  let switch = read_command_line "opam config var switch" in
  let bindir = read_command_line "opam config var bin" in
  let sharedir = read_command_line "opam config var share" in
  write_kernel_sh ~output:"kernel.sh" ~bindir ~switch ;
  write_kernelspec_json ~output:"kernel.json" ~bindir ~sharedir ~switch ~home
