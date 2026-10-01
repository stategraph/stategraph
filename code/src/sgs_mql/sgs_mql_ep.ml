let src = Logs.Src.create "mql_ep"

module Logs = (val Logs.src_log src : Logs.LOG)
module Br = Sgs_api_components.Bad_request_err

(* Parse the query string, then run it through the MQL core. *)
let run_query config storage user q tz page =
  let open Abbs_fc.Infix_result_monad in
  Abb.Future.return (Mql.Ast.of_string q)
  >>= fun ast -> Sgs_mql_paged.query ?tz ?page config storage user ast

(* Respond with [rows] as a JSON array, optionally attaching [headers]. *)
let respond_rows ?headers ctx rows =
  let body = Yojson.Safe.to_string (`List rows) in
  Abb.Future.return (Brtl_ctx.set_response (Brtl_rspnc.create ?headers ~status:`OK body) ctx)

(* Respond with a 400 carrying a [Bad_request_err]. *)
let respond_bad_request ctx id data =
  let body = Yojson.Safe.pretty_to_string @@ Br.to_yojson { Br.id; data } in
  Abb.Future.return (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Bad_request body) ctx)

(* Log an MQL error [err] with [pp], then respond with a 400 [Bad_request_err]. *)
let log_mql_bad ctx id pp err data =
  Logs.info (fun m -> m "%s : %a" (Brtl_ctx.token ctx) pp err);
  respond_bad_request ctx id data

(* Respond with a 500 and an empty body. *)
let respond_internal_error ctx = Abb.Future.return (Sgs_eplib.respond_internal_error ctx)
let pagination_error_headers err = Cohttp.Header.of_list [ ("mql-pagination-error", err) ]

(* When the result was truncated by [default_limit] (the caller named no LIMIT
   and more rows existed), advertise it so a client can tell a server-default cap
   from its own explicit-LIMIT page boundary -- the response is otherwise
   byte-identical. Additive: existing cursor consumers ignore the header. *)
let with_default_limit_header ~default_limit_applied headers =
  if default_limit_applied then
    Cohttp.Header.add
      headers
      "mql-default-limit-applied"
      (string_of_int Sgs_mql_paged.default_limit)
  else headers

(* Translate the outcome of [run_query] into the endpoint's HTTP response. *)
let respond ctx = function
  | Ok { Sgs_mql_paged.pagination = `Paginate (prev, next); rows; default_limit_applied; limit = _ }
    ->
      respond_rows
        ~headers:
          (with_default_limit_header
             ~default_limit_applied
             (Sgs_mql_paged.mk_pagination_headers ~prev ~next ctx))
        ctx
        rows
  | Ok { Sgs_mql_paged.pagination = `Paginate_err err; rows; default_limit_applied; limit = _ } ->
      respond_rows
        ~headers:(with_default_limit_header ~default_limit_applied (pagination_error_headers err))
        ctx
        rows
  | Ok { Sgs_mql_paged.pagination = `Missing_order_by; rows; default_limit_applied; limit = _ } ->
      respond_rows
        ~headers:
          (with_default_limit_header
             ~default_limit_applied
             (pagination_error_headers "ORDER_BY_MISSING"))
        ctx
        rows
  | Ok { Sgs_mql_paged.pagination = `No_paginate; rows; default_limit_applied = _; limit = _ } ->
      respond_rows ctx rows
  | Error (#Mql_to_pgsql.apply_page_err as err) ->
      log_mql_bad
        ctx
        "APPLY_PAGE_ERR"
        Mql_to_pgsql.pp_apply_page_err
        err
        (Some (Mql_to_pgsql.show_apply_page_err err))
  | Error (`Table_access_err name as err) ->
      log_mql_bad ctx "TABLE_ACCESS_ERR" Mql_to_pgsql.pp_of_mql_err err (Some name)
  | Error (`Func_access_err name as err) ->
      log_mql_bad ctx "FUNC_ACCESS_ERR" Mql_to_pgsql.pp_of_mql_err err (Some name)
  | Error (`Cast_err name as err) ->
      log_mql_bad ctx "CAST_ERR" Mql_to_pgsql.pp_of_mql_err err (Some name)
  | Error (`Type_mismatch_err _ as err) ->
      log_mql_bad
        ctx
        "TYPE_MISMATCH_ERR"
        Mql_to_pgsql.pp_of_mql_err
        err
        (Some (Mql_to_pgsql.show_of_mql_err err))
  | Error (`Unknown_column_err column as err) ->
      log_mql_bad ctx "UNKNOWN_COLUMN_ERR" Mql_to_pgsql.pp_of_mql_err err (Some column)
  | Error (`Invalid_identifier_err name as err) ->
      log_mql_bad ctx "INVALID_IDENTIFIER_ERR" Mql_to_pgsql.pp_of_mql_err err (Some name)
  | Error (`Ambiguous_column_err column as err) ->
      log_mql_bad ctx "AMBIGUOUS_COLUMN_ERR" Mql_to_pgsql.pp_of_mql_err err (Some column)
  | Error (#Mql.Ast.err as err) ->
      log_mql_bad ctx "QUERY_ERR" Mql.Ast.pp_err err (Some (Mql.Ast.show_err err))
  | Error (`Syntax_err { Pgsql_io.message; _ } as err) ->
      Logs.info (fun m -> m "%s : QUERY_SYNTAX_ERR : %a" (Brtl_ctx.token ctx) Pgsql_io.pp_err err);
      respond_bad_request ctx "QUERY_ERR" (Some message)
  | Error (`Pgsql_err { Pgsql_io.message; _ } as err) ->
      Logs.info (fun m -> m "%s : QUERY_PGSQL_ERR : %a" (Brtl_ctx.token ctx) Pgsql_io.pp_err err);
      respond_bad_request ctx "QUERY_ERR" (Some message)
  | Error `Statement_timeout -> respond_bad_request ctx "TIMEOUT_ERR" None
  | Error (#Pgsql_io.err as err) ->
      Logs.err (fun m -> m "%s : %a" (Brtl_ctx.token ctx) Pgsql_io.pp_err err);
      respond_internal_error ctx
  | Error (#Pgsql_pool.err as err) ->
      Logs.err (fun m -> m "%s : %a" (Brtl_ctx.token ctx) Pgsql_pool.pp_err err);
      respond_internal_error ctx

let run config storage q tz page =
  Sgs_user_session.with_user ~caps:Sgs_user_session.Caps.allow_all ~f:(fun user ->
      Brtl_ep.run_json ~f:(fun ctx ->
          let open Abb.Future.Infix_monad in
          run_query config storage user q tz page >>= respond ctx))

module Schema = struct
  (* The schema-endpoint body, built from the compiler's schema plus the
     endpoint's row-limit policy via the generated [mql-schema-response] type so
     the wire shape stays pinned to api.json. The table/column map is reused
     verbatim from [Mql_to_pgsql.Schema.to_yojson] -- its single definition --
     rather than re-walked here; on the (unreachable) parse failure we fall back
     to the legacy tables-only body so the endpoint never fails over a
     serialization quirk. Computed once per variant: the schemas and limits are
     constants, and [run] picks the variant from the config flag so the wire
     schema advertises exactly the tables queries can name. *)
  let response_json_of_schema schema =
    let module R = Sgs_api_components.Mql_schema_response in
    let schema_json = Mql_to_pgsql.Schema.to_yojson schema in
    match R.Tables.of_yojson (Yojson.Safe.Util.member "tables" schema_json) with
    | Ok tables ->
        R.to_yojson
          {
            R.tables;
            default_limit = Sgs_mql_paged.default_limit;
            max_limit = Sgs_mql_paged.max_limit;
          }
    | Error _ -> schema_json

  let response_json = response_json_of_schema Sgs_mql_paged.schema
  let response_json_orchestration = response_json_of_schema Sgs_mql_paged.schema_orchestration

  let run config =
    Sgs_user_session.with_user ~caps:Sgs_user_session.Caps.allow_all ~f:(fun _user ->
        Brtl_ep.run_json ~f:(fun ctx ->
            let body =
              Yojson.Safe.to_string
                (if Sgs_config.orchestration_enabled config then response_json_orchestration
                 else response_json)
            in
            Abb.Future.return @@ Brtl_ctx.set_response (Brtl_rspnc.create ~status:`OK body) ctx))
end

module Tests = struct
  let response_json = Schema.response_json
  let response_json_orchestration = Schema.response_json_orchestration
end
