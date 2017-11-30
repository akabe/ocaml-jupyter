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

let () =
  let output = ref "" in
  let bindir = ref "" in
  let home = Sys.getenv "HOME" in
  let specs = Arg.[
      "-o", Set_string output, "Output path";
      "-bindir", Set_string bindir, "Path to executable files";
    ] in
  Arg.parse specs failwith "Discover PPX flags" ;
  main ~output:!output ~bindir:!bindir ~home
