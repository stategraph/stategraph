let src = Logs.Src.create "infracost"

module Logs = (val Logs.src_log src : Logs.LOG)
module Http = Cohttp_abb.Make (Abb)
module Http_tls = Cohttp_abb_tls.Make (Abb)
module Exec = Abb_keyed_concurrent_executor.Make (Abb) (CCString)

type backend =
  | Proxy of Terrat_config.Infracost.proxy
  | Price_book of Terrat_storage.t

let create_backend config =
  match Terrat_config.infracost config with
  | Some (Terrat_config.Infracost.Proxy proxy) -> Abb.Future.return (Some (Proxy proxy))
  | Some (Terrat_config.Infracost.Price_book price_book) ->
      Terrat_storage.create_pricing config price_book
      |> Abb.Future.map (fun pricing -> Some (Price_book pricing))
  | None -> Abb.Future.return None

module Metrics = struct
  module DefaultHistogram = Prmths.Histogram (struct
    let spec = Prmths.Histogram_spec.of_list [ 0.005; 0.5; 1.0; 5.0; 10.0; 15.0; 20.0 ]
  end)

  let namespace = "terrat"
  let subsystem = "ep_infracost"

  let duration_seconds =
    let help = "Number of seconds to eval an infracost request" in
    DefaultHistogram.v ~help ~namespace ~subsystem "duration_seconds"

  let requests_total =
    let help = "Total number of requests" in
    Prmths.Counter.v ~help ~namespace ~subsystem "requests_total"

  let responses_total =
    let help = "Total number of responses" in
    Prmths.Counter.v_label ~label_name:"result" ~help ~namespace ~subsystem "responses_total"

  let requests_concurrent =
    let help = "Number of concurrent requests" in
    Prmths.Gauge.v ~help ~namespace ~subsystem "requests_concurrent"

  let pgsql_pool_errors_total = Terrat_metrics.errors_total ~m:"ep_infracost" ~t:"pgsql_pool"
  let pgsql_errors_total = Terrat_metrics.errors_total ~m:"ep_infracost" ~t:"pgsql"
  let http_errors_total = Terrat_metrics.errors_total ~m:"ep_infracost" ~t:"http"
  let timeout_errors_total = Terrat_metrics.errors_total ~m:"ep_infracost" ~t:"timeout"
  let infracost_errors_total = Terrat_metrics.errors_total ~m:"ep_infracost" ~t:"infracost"
end

module Sql = struct
  let verify_work_manifest_sql =
    Mql_sql.read "select id from work_manifests where state = 'running' and id = $id"

  let verify_work_manifest =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* id *)
      Ret.uuid
      /^ verify_work_manifest_sql
      /% Var.uuid "id")
end

(* Limit number of concurrent API calls to infracost *)
let api_call = Exec.create ~slots:10 (fun f -> f ())
let api_call_timeout = Duration.to_f (Duration.of_sec 10)
let header_replace k v h = Cohttp.Header.replace h k v

let proxy storage api_key infracost_uri path ctx =
  let open Abb.Future.Infix_monad in
  let request = Brtl_ctx.request ctx in
  let request_id = Brtl_ctx.token ctx in
  match Cohttp.Header.get (Brtl_ctx.Request.headers request) "x-api-key" with
  | Some work_manifest_id -> (
      (match Uuidm.of_string work_manifest_id with
        | Some work_manifest_id ->
            Pgsql_pool.with_conn storage ~f:(fun db ->
                Pgsql_io.Prepared_stmt.fetch
                  db
                  Sql.verify_work_manifest
                  ~f:CCFun.id
                  work_manifest_id)
        | None -> Abbs_fc.return_err `Bad_work_manifest)
      >>= function
      | Ok (_ :: _) -> (
          let uri = Uri.with_path infracost_uri (Uri.path infracost_uri ^ "/" ^ path) in
          let body = Brtl_ctx.body ctx in
          let headers =
            request
            |> Brtl_ctx.Request.headers
            |> CCFun.flip Cohttp.Header.remove "host"
            |> header_replace "x-api-key" api_key
          in
          Logs.debug (fun m ->
              m "%s : work_manifest=%s : URI : %s" request_id work_manifest_id (Uri.to_string uri));
          Abb.Sys.monotonic ()
          >>= fun now ->
          api_call
          >>= fun api_call ->
          let p = Abb.Future.Promise.create () in
          Exec.enqueue api_call ~keys:[] (fun () ->
              Abb.Sys.monotonic ()
              >>= fun now' ->
              let wait_time = now' -. now in
              (if wait_time < api_call_timeout then
                 Abbs_fc.timeout
                   ~timeout:(Abb.Sys.sleep (api_call_timeout -. wait_time))
                   (Http.Client.post ~connector:(Http_tls.connector ()) ~headers ~body uri)
               else Abb.Future.return `Timeout)
              >>= fun ret -> Abb.Future.Promise.set p ret)
          >>= fun _ ->
          Abb.Future.Promise.future p
          >>= function
          | `Ok (Ok (resp, body)) when Cohttp.Response.status resp = `OK ->
              Logs.debug (fun m -> m "%s : work_manifest=%s : SUCCESS" request_id work_manifest_id);
              Prmths.Counter.inc_one (Metrics.responses_total "success");
              Abb.Future.return
                (Brtl_ctx.set_response
                   (Brtl_rspnc.create ~headers:(Cohttp.Response.headers resp) ~status:`OK body)
                   ctx)
          | `Ok (Ok (resp, _)) ->
              Logs.err (fun m ->
                  m
                    "%s : work_manifest=%s : %a"
                    request_id
                    work_manifest_id
                    Cohttp.Response.pp_hum
                    resp);
              Prmths.Counter.inc_one Metrics.infracost_errors_total;
              Prmths.Counter.inc_one (Metrics.responses_total "error");
              Abb.Future.return
                (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Internal_server_error body) ctx)
          | `Ok (Error (#Cohttp_abb.request_err as err)) ->
              Logs.err (fun m ->
                  m
                    "%s : work_manifest=%s : %s"
                    request_id
                    work_manifest_id
                    (Cohttp_abb.show_request_err err));
              Prmths.Counter.inc_one Metrics.http_errors_total;
              Prmths.Counter.inc_one (Metrics.responses_total "error");
              Abb.Future.return
                (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Internal_server_error "") ctx)
          | `Timeout ->
              Logs.info (fun m -> m "%s : work_manifest=%s : TIMEOUT" request_id work_manifest_id);
              Prmths.Counter.inc_one Metrics.timeout_errors_total;
              Prmths.Counter.inc_one (Metrics.responses_total "timeout");
              Abb.Future.return
                (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Internal_server_error "") ctx))
      | Error (#Pgsql_pool.err as err) ->
          Prmths.Counter.inc_one Metrics.pgsql_pool_errors_total;
          Logs.err (fun m ->
              m "%s : work_manifest=%s : %a" request_id work_manifest_id Pgsql_pool.pp_err err);
          Abb.Future.return
            (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Internal_server_error "") ctx)
      | Error (#Pgsql_io.err as err) ->
          Prmths.Counter.inc_one Metrics.pgsql_errors_total;
          Logs.err (fun m ->
              m "%s : work_manifest=%s : %a" request_id work_manifest_id Pgsql_io.pp_err err);
          Abb.Future.return
            (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Internal_server_error "") ctx)
      | Ok [] ->
          Logs.warn (fun m ->
              m "%s : work_manifest=%s : MISSING_WORK_MANIFEST" request_id work_manifest_id);
          Abb.Future.return (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Bad_request "") ctx)
      | Error `Bad_work_manifest ->
          Logs.err (fun m ->
              m "%s : work_manifest=%s : BAD_WORK_MANIFEST" request_id work_manifest_id);
          Abb.Future.return (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Bad_request "") ctx))
  | None ->
      Abb.Future.return (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Bad_request "") ctx)

let invalid_api_key_body =
  Terrat_api_components.Infracost_error.(
    { error = "Invalid API key"; error_code = "invalid_api_key" }
    |> to_yojson
    |> Yojson.Safe.to_string)

let bad_request_body =
  Terrat_api_components.Infracost_error.(
    { error = "Bad request"; error_code = "bad_request" } |> to_yojson |> Yojson.Safe.to_string)

let unsupported_currency_body =
  Terrat_api_components.Infracost_error.(
    { error = "Unsupported currency"; error_code = "unsupported_currency" }
    |> to_yojson
    |> Yojson.Safe.to_string)

let event_body =
  Terrat_api_components.Infracost_event_result.(
    { status = "ok" } |> to_yojson |> Yojson.Safe.to_string)

let response status body ctx =
  Abb.Future.return (Brtl_ctx.set_response (Brtl_rspnc.create ~status body) ctx)

let invalid_api_key ctx =
  Prmths.Counter.inc_one (Metrics.responses_total "invalid_api_key");
  response `Forbidden invalid_api_key_body ctx

let graphql ~pricing ctx =
  let open Abb.Future.Infix_monad in
  let request_id = Brtl_ctx.token ctx in
  match Infracost_pricing.decode (Yojson.Safe.from_string (Brtl_ctx.body ctx)) with
  | Ok elements -> (
      Infracost_pricing.run pricing elements
      >>= function
      | Ok body ->
          Logs.info (fun m -> m "%s : SUCCESS : %d" request_id (CCList.length elements));
          Prmths.Counter.inc_one (Metrics.responses_total "success");
          response
            `OK
            (Yojson.Safe.to_string
               (Terrat_api_components.Infracost_graphql_batch_response.to_yojson body))
            ctx
      | Error (#Pgsql_pool.err as err) ->
          Logs.err (fun m -> m "%s : PRICING_POOL_ERROR : %a" request_id Pgsql_pool.pp_err err);
          Prmths.Counter.inc_one Metrics.pgsql_pool_errors_total;
          Prmths.Counter.inc_one (Metrics.responses_total "error");
          response `Internal_server_error "" ctx
      | Error (#Pgsql_io.err as err) ->
          Logs.err (fun m -> m "%s : PRICING_DB_ERROR : %a" request_id Pgsql_io.pp_err err);
          Prmths.Counter.inc_one Metrics.pgsql_errors_total;
          Prmths.Counter.inc_one (Metrics.responses_total "error");
          response `Internal_server_error "" ctx)
  | Error `Bad_request_err ->
      Logs.warn (fun m -> m "%s : BAD_REQUEST" request_id);
      Prmths.Counter.inc_one Metrics.infracost_errors_total;
      Prmths.Counter.inc_one (Metrics.responses_total "bad_request");
      response `Bad_request bad_request_body ctx
  | Error `Unsupported_currency_err ->
      Logs.warn (fun m -> m "%s : UNSUPPORTED_CURRENCY" request_id);
      Prmths.Counter.inc_one Metrics.infracost_errors_total;
      Prmths.Counter.inc_one (Metrics.responses_total "unsupported_currency");
      response `Bad_request unsupported_currency_body ctx
  | exception Yojson.Json_error _ ->
      Logs.warn (fun m -> m "%s : MALFORMED_BODY" request_id);
      Prmths.Counter.inc_one Metrics.infracost_errors_total;
      Prmths.Counter.inc_one (Metrics.responses_total "bad_request");
      response `Bad_request bad_request_body ctx

let price_book ~pricing storage path ctx =
  let open Abb.Future.Infix_monad in
  let request_id = Brtl_ctx.token ctx in
  match Cohttp.Header.get (Brtl_ctx.Request.headers (Brtl_ctx.request ctx)) "x-api-key" with
  | Some work_manifest_id -> (
      (match Uuidm.of_string work_manifest_id with
        | Some work_manifest_id ->
            Pgsql_pool.with_conn storage ~f:(fun db ->
                Pgsql_io.Prepared_stmt.fetch
                  db
                  Sql.verify_work_manifest
                  ~f:CCFun.id
                  work_manifest_id)
        | None -> Abbs_fc.return_err `Bad_work_manifest)
      >>= function
      | Ok (_ :: _) -> (
          match path with
          | "graphql" -> graphql ~pricing ctx
          | "event" ->
              Prmths.Counter.inc_one (Metrics.responses_total "success");
              response `OK event_body ctx
          | _ ->
              Logs.warn (fun m -> m "%s : UNKNOWN_PATH : %s" request_id path);
              Prmths.Counter.inc_one (Metrics.responses_total "not_found");
              response `Not_found "" ctx)
      | Ok [] ->
          Logs.warn (fun m -> m "%s : MISSING_WORK_MANIFEST : %s" request_id work_manifest_id);
          invalid_api_key ctx
      | Error `Bad_work_manifest ->
          Logs.warn (fun m -> m "%s : BAD_WORK_MANIFEST : %s" request_id work_manifest_id);
          invalid_api_key ctx
      | Error (#Pgsql_pool.err as err) ->
          Logs.err (fun m -> m "%s : POOL_ERROR : %a" request_id Pgsql_pool.pp_err err);
          Prmths.Counter.inc_one Metrics.pgsql_pool_errors_total;
          Prmths.Counter.inc_one (Metrics.responses_total "error");
          response `Internal_server_error "" ctx
      | Error (#Pgsql_io.err as err) ->
          Logs.err (fun m -> m "%s : DB_ERROR : %a" request_id Pgsql_io.pp_err err);
          Prmths.Counter.inc_one Metrics.pgsql_errors_total;
          Prmths.Counter.inc_one (Metrics.responses_total "error");
          response `Internal_server_error "" ctx)
  | None ->
      Logs.warn (fun m -> m "%s : MISSING_API_KEY" request_id);
      invalid_api_key ctx

let post' backend storage path ctx =
  match backend with
  | Proxy { Terrat_config.Infracost.endpoint; api_key } -> proxy storage api_key endpoint path ctx
  | Price_book pricing -> price_book ~pricing storage path ctx

let post infracost storage path =
  Brtl_ep.run_json ~f:(fun ctx ->
      let request_id = Brtl_ctx.token ctx in
      match infracost with
      | Some backend ->
          Logs.info (fun m -> m "%s : START : %s" request_id path);
          Prmths.Counter.inc_one Metrics.requests_total;
          Metrics.DefaultHistogram.time Metrics.duration_seconds (fun () ->
              Prmths.Gauge.track_inprogress Metrics.requests_concurrent (fun () ->
                  Abbs_fc.with_finally
                    (fun () -> post' backend storage path ctx)
                    ~finally:(fun () ->
                      Logs.info (fun m -> m "%s : FINISH" request_id);
                      Abbs_fc.unit)))
      | None ->
          Logs.info (fun m -> m "%s : DISABLED" request_id);
          response `Bad_request "" ctx)
