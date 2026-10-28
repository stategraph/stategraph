module Http = Cohttp_abb.Make (Abb)
module Http_tls = Cohttp_abb_tls.Make (Abb)

module Metrics = struct
  let namespace = "terrat"
  let subsystem = "nginx"

  let active_connections =
    let help = "Number of current active connections" in
    Prmths.Gauge.v ~help ~namespace ~subsystem "active_connections"

  let accepts_count =
    let help = "Number of accepted connections" in
    Prmths.Gauge.v ~help ~namespace ~subsystem "accepts_count"

  let handled_count =
    let help = "Number of handled connections" in
    Prmths.Gauge.v ~help ~namespace ~subsystem "handled_count"

  let requests_count =
    let help = "Number of requests" in
    Prmths.Gauge.v ~help ~namespace ~subsystem "requests_count"

  let reading =
    let help = "Number of current reading" in
    Prmths.Gauge.v ~help ~namespace ~subsystem "reading"

  let writing =
    let help = "Number of current writing" in
    Prmths.Gauge.v ~help ~namespace ~subsystem "writing"

  let waiting =
    let help = "Number of current waiting" in
    Prmths.Gauge.v ~help ~namespace ~subsystem "waiting"
end

let parse_and_update_metrics body =
  match CCString.split_on_char '\n' body with
  | active :: _ :: server_accepts :: reading_writing_waiting :: _ -> (
      (match CCString.Split.left ~by:": " (CCString.trim active) with
      | Some ("Active connections", count) -> (
          match CCInt.of_string count with
          | Some count -> Prmths.Gauge.set Metrics.active_connections (CCFloat.of_int count)
          | None -> Logs.warn (fun m -> m "NGINX_METRICS : PARSE_FAIL : 1 : %S" active))
      | _ -> Logs.warn (fun m -> m "NGINX_METRICS : PARSE_FAIL : 1 : %S" active));
      (match CCString.split_on_char ' ' (CCString.trim server_accepts) with
      | [ accepted; handled; requests ] -> (
          match
            CCOption.Infix.(
              CCInt.of_string accepted
              >>= fun accepted ->
              CCInt.of_string handled
              >>= fun handled ->
              CCInt.of_string requests >>= fun requests -> Some (accepted, handled, requests))
          with
          | Some (accepted, handled, requests) ->
              Prmths.Gauge.set Metrics.accepts_count (CCFloat.of_int accepted);
              Prmths.Gauge.set Metrics.handled_count (CCFloat.of_int handled);
              Prmths.Gauge.set Metrics.requests_count (CCFloat.of_int requests)
          | None -> Logs.warn (fun m -> m "NGINX_METRICS : PARSE_FAIL : 3 : %S" server_accepts))
      | _ -> Logs.warn (fun m -> m "NGINX_METRICS : PARSE_FAIL : 4 : %S" server_accepts));
      match CCString.split_on_char ' ' (CCString.trim reading_writing_waiting) with
      | [ "Reading:"; reading; "Writing:"; writing; "Waiting:"; waiting ] -> (
          match
            CCOption.Infix.(
              CCInt.of_string reading
              >>= fun reading ->
              CCInt.of_string writing
              >>= fun writing ->
              CCInt.of_string waiting >>= fun waiting -> Some (reading, writing, waiting))
          with
          | Some (reading, writing, waiting) ->
              Prmths.Gauge.set Metrics.reading (CCFloat.of_int reading);
              Prmths.Gauge.set Metrics.writing (CCFloat.of_int writing);
              Prmths.Gauge.set Metrics.waiting (CCFloat.of_int waiting)
          | None ->
              Logs.warn (fun m -> m "NGINX_METRICS : PARSE_FAIL : 5 : %S" reading_writing_waiting))
      | _ -> Logs.warn (fun m -> m "NGINX_METRICS : PARSE_FAIL : 6 : %S" reading_writing_waiting))
  | _ -> Logs.warn (fun m -> m "NGINX_METRICS : PARSE_FAIL : 7 : %S" body)

let rec start uri =
  let open Abb.Future.Infix_monad in
  Abb.Sys.sleep 10.0
  >>= fun () ->
  Http.Client.call ~connector:(Http_tls.connector ()) `GET uri
  >>= function
  | Ok (resp, body) when Http.Response.status resp = `OK ->
      parse_and_update_metrics body;
      start uri
  | Ok (_resp, _) ->
      Logs.err (fun m -> m "NGINX_METRICS : FAILED");
      start uri
  | Error (#Cohttp_abb.request_err as err) ->
      Logs.err (fun m -> m "NGINX_METRICS : FAILED : %a" Cohttp_abb.pp_request_err err);
      start uri
