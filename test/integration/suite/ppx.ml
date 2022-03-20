#require "ppx_yojson_conv" ;;

type t = { foo : int; baz : string; } [@@deriving yojson]

let expected = "{\"foo\":42,\"baz\":\"hello\"}"

let actual =
  { foo = 42; baz = "hello"; }
  |> [%yojson_of: t]
  |> Yojson.Safe.to_string

let () = assert (expected = actual)
