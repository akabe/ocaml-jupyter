(** Discover PPX flags of ppx_deriving_yojson *)

open Format

let output_file fname data =
  let oc = open_out fname in
  output_string oc data ;
  close_out oc

let input_lines ic =
  let rec aux acc = match input_line ic with
    | line -> aux (line :: acc)
    | exception End_of_file -> List.rev acc
  in
  aux []

let command options =
  let ic = List.map (sprintf "%S") options
           |> String.concat " "
           |> Unix.open_process_in in
  let lines = input_lines ic in
  ignore (Unix.close_process_in ic) ;
  lines

let cons_ref xs x = xs := x :: !xs

let output = ref "ocaml_flags.sexp"
let ocamlfind = ref "ocamlfind"
let ppx = ref []
let ocaml_flag = ref []

let () =
  let specs = Arg.[
      "-o", Set_string output, "Output path";
      "-ocamlfind", Set_string ocamlfind, "Path to ocamlfind";
      "-ppx", String (cons_ref ppx), "Add PPX driver";
      "-ocaml-flag", String (cons_ref ocaml_flag), "Extra ocamlc/ocamlopt flags";
    ] in
  Arg.parse specs failwith "Discover PPX flags" ;
  let ppx_flags = command (!ocamlfind :: "printppx" :: !ppx) in
  (ppx_flags @ !ocaml_flag)
  |> String.concat " "
  |> sprintf "(%s)"
  |> output_file !output
