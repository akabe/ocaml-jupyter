let () =
  try Topdirs.dir_directory (Sys.getenv "OCAML_TOPLEVEL_PATH")
  with Not_found -> ()
;;

(* verbose output by interactive mode  *)
(* Sys.interactive := true ;; *)

#use "topfind" ;;
