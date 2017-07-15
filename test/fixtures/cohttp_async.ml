#thread ;;
#require "async,cohttp.async" ;;

let _ =
  let open Core.Std in
  let open Async.Std in
  ignore (Thread.create (fun () -> never_returns (Scheduler.go ())) ()) ;
  let t0 = after (Time.Span.of_sec 5.0) >>| fun () -> None in
  let t1 =
    Uri.of_string "http://example.com/"
    |> Cohttp_async.Client.get >>| fun (resp, _) ->
    Some (Cohttp.Response.status resp)
  in
  Thread_safe.block_on_async_exn (fun () -> Deferred.any [t0; t1])
