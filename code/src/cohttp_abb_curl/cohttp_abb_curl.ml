module Abb = Abb_scheduler_select
module Fut_comb = Abb_fc.Make (Abb.Future)
module Http = Cohttp_abb.Make (Abb)
module Http_tls = Cohttp_abb_tls.Make (Abb)

let run_client () =
  let open Abb.Future.Infix_monad in
  let url = Sys.argv.(1) in
  let uri = Uri.of_string url in
  Fut_comb.timeout
    ~timeout:(Abb.Sys.sleep 10.0)
    (Http.Client.call ~connector:(Http_tls.connector ()) `GET uri)
  >>= function
  | `Ok (Ok (resp, body)) ->
      Printf.printf "Status: %s\n" (Cohttp.Code.string_of_status resp.Http.Response.status);
      CCList.iter
        (fun (name, value) -> Printf.printf "%s: %s\n" name value)
        (Cohttp.Header.to_list (Http.Response.headers resp));
      print_endline "";
      print_endline body;
      Abb.Future.return ()
  | `Ok (Error (#Cohttp_abb.connect_err as err)) ->
      Printf.printf "%s\n%!" (Cohttp_abb.show_connect_err err);
      Abb.Future.return ()
  | `Ok (Error (#Cohttp_abb.request_err as err)) ->
      Printf.printf "%s\n%!" (Cohttp_abb.show_request_err err);
      Abb.Future.return ()
  | `Timeout ->
      Printf.printf "Timeout\n";
      Abb.Sys.sleep 1.0

let main () =
  match Abb.Scheduler.run_with_state run_client with
  | `Det () -> ()
  (* | `Det (Error err)   ->
   *     Printf.eprintf "Error: %s" (Cohttp_abb.show_request_err err);
   *     failwith "Error" *)
  | `Aborted -> failwith "Aborted"
  | `Exn (exn, bt_opt) ->
      Printf.eprintf "Exn = %s\n" (Printexc.to_string exn);
      CCOption.iter (fun bt -> Printf.eprintf "%s\n" (Printexc.raw_backtrace_to_string bt)) bt_opt;
      raise exn

let () = main ()
