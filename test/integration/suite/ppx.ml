#require "ppx_deriving_yojson" ;;

type t = { foo : int; baz : string; } [@@deriving yojson]

let expected = "{\"foo\":42,\"baz\":\"hello\"}"

let actual =
  { foo = 42; baz = "hello"; }
  |> [%to_yojson: t]
  |> Yojson.Safe.to_string

let () = assert (expected = actual)
