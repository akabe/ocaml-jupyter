#require "lwt.unix,cohttp.lwt" ;;

let _ =
  let open Lwt.Infix in
  let t0 = Lwt_unix.sleep 5.0 >|= fun () -> None in
  let t1 =
    Uri.of_string "http://example.com/"
    |> Cohttp_lwt_unix.Client.get >|= fun (resp, _) ->
    Some (Cohttp.Response.status resp)
  in
  Lwt_main.run (t0 <?> t1)
