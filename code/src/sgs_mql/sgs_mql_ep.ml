let src = Logs.Src.create "mql_ep"

module Logs = (val Logs.src_log src : Logs.LOG)
module Br = Sgs_api_components.Bad_request_err

(* Parse the query string, then run it through the MQL core. *)
let run_query ~unmasked_tenants config storage user q tz page =
  let open Abbs_fc.Infix_result_monad in
  Abb.Future.return (Mql.Ast.of_string q)
  >>= fun ast -> Sgs_mql_paged.query ?tz ?page ~unmasked_tenants config storage user ast

(* The tenants that the preview capability of [caps] reaches.  A session that can preview in a
   tenant gives the values of its sensitive variables to each plan. *)
let unmasked_tenants caps tenants =
  let reach = Sg_caps_ops.reach caps `Preview `Modified in
  CCList.filter_map
    (fun tenant ->
      let id = Sgs_tenant.id tenant in
      if Sg_caps_ops.reaches_tenant reach ~tenant:(Uuidm.to_string id) then Some id else None)
    tenants

(* Respond with [rows] as a JSON array, optionally attaching [headers]. *)
let respond_rows ?headers ctx rows =
  let body = Yojson.Safe.to_string (`List rows) in
  Abb.Future.return (Brtl_ctx.set_response (Brtl_rspnc.create ?headers ~status:`OK body) ctx)

(* Respond with a 400 carrying a [Bad_request_err]. *)
let respond_bad_request ctx id data =
  let body = Yojson.Safe.pretty_to_string @@ Br.to_yojson { Br.id; data } in
  Abb.Future.return (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Bad_request body) ctx)

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

(* How [respond] answers an error: a 400 that carries the id and data of a
   [Bad_request_err], or a 500.  [respond] and [Tests.status_of_err] read this
   one mapping, thus the tests see the status that the endpoint gives. *)
type err_response =
  | Bad_request of {
      id : string;
      data : string option;
    }
  | Internal_error

let err_response = function
  | #Mql_to_pgsql.apply_page_err as err ->
      Bad_request { id = "APPLY_PAGE_ERR"; data = Some (Mql_to_pgsql.show_apply_page_err err) }
  | `Table_access_err name -> Bad_request { id = "TABLE_ACCESS_ERR"; data = Some name }
  | `Func_access_err name -> Bad_request { id = "FUNC_ACCESS_ERR"; data = Some name }
  | `Cast_err name -> Bad_request { id = "CAST_ERR"; data = Some name }
  (* A construct MQL reads so that it can read the SQL of this repository, but
     that a query from outside must not get. *)
  | `Construct_not_allowed_err name ->
      Bad_request { id = "CONSTRUCT_NOT_ALLOWED_ERR"; data = Some name }
  | `Type_mismatch_err _ as err ->
      Bad_request { id = "TYPE_MISMATCH_ERR"; data = Some (Mql_to_pgsql.show_of_mql_err err) }
  | `Unknown_column_err column -> Bad_request { id = "UNKNOWN_COLUMN_ERR"; data = Some column }
  | `Invalid_identifier_err name -> Bad_request { id = "INVALID_IDENTIFIER_ERR"; data = Some name }
  (* Unreachable from this endpoint -- [run_query] parses with the default
     [variables:false], so a [$name] never gets as far as the compiler.  Handled
     for the case an AST reaches [of_mql] by another route. *)
  | `Variable_err name -> Bad_request { id = "VARIABLE_ERR"; data = Some name }
  (* Unreachable from here -- [run_query] parses with no [Mql.Feature] enabled,
     so a locking clause cannot even be lexed into an AST. Handled because
     [of_mql] refuses it independently of that gate. *)
  | `Locking_not_allowed_err -> Bad_request { id = "LOCKING_NOT_ALLOWED_ERR"; data = None }
  (* Also unreachable from here: a write cannot be parsed without the
     [Mql.Feature.Data_modifying] opt-in, which this endpoint never passes. *)
  | `Data_modifying_not_allowed_err ->
      Bad_request { id = "DATA_MODIFYING_NOT_ALLOWED_ERR"; data = None }
  | `Ddl_not_allowed_err -> Bad_request { id = "DDL_NOT_ALLOWED_ERR"; data = None }
  (* The compiler's post-condition audit rejected the compiler's OWN output: a
     guard did not fire and we were about to emit a query naming something
     outside the schema. That is our bug, not the caller's, so it is a 500 and it
     is logged at error level -- this should never appear in a log. *)
  | #Mql_to_pgsql.audit_err -> Internal_error
  | `Ambiguous_column_err column -> Bad_request { id = "AMBIGUOUS_COLUMN_ERR"; data = Some column }
  | #Mql.Ast.err as err -> Bad_request { id = "QUERY_ERR"; data = Some (Mql.Ast.show_err err) }
  | `Syntax_err { Pgsql_io.message; _ } | `Pgsql_err { Pgsql_io.message; _ } ->
      Bad_request { id = "QUERY_ERR"; data = Some message }
  | `Statement_timeout -> Bad_request { id = "TIMEOUT_ERR"; data = None }
  | #Pgsql_io.err | #Pgsql_pool.err -> Internal_error

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
  | Error err -> (
      match err_response err with
      | Bad_request { id; data } ->
          Logs.info (fun m ->
              m "%s : %s : %a" (Brtl_ctx.token ctx) id Sgs_mql_paged.pp_query_err err);
          respond_bad_request ctx id data
      | Internal_error ->
          Logs.err (fun m ->
              m "%s : MQL_INTERNAL_ERR : %a" (Brtl_ctx.token ctx) Sgs_mql_paged.pp_query_err err);
          respond_internal_error ctx)

let respond_unmasked_denied ctx =
  Logs.info (fun m -> m "%s : MQL_UNMASKED_DENIED" (Brtl_ctx.token ctx));
  Abb.Future.return
    (Brtl_ctx.set_response
       (Brtl_rspnc.create
          ~status:`Forbidden
          (Sgs_eplib.error_response_body
             ~id:"MQL_UNMASKED_DENIED"
             ~data:"Unmasked results need the preview capability in a tenant of the user"))
       ctx)

let run config storage q tz page unmasked =
  Sgs_user_session.with_session ~caps:Sgs_user_session.Caps.allow_all ~f:(fun session ->
      Brtl_ep.run_json ~f:(fun ctx ->
          let open Abb.Future.Infix_monad in
          let user = Sgs_user_session.Session.user session in
          match unmasked with
          | None | Some false ->
              run_query ~unmasked_tenants:[] config storage user q tz page >>= respond ctx
          | Some true -> (
              Pgsql_pool.with_conn storage ~f:(Sgs_tenant.list_by_user user)
              >>= function
              | Ok tenants -> (
                  match
                    unmasked_tenants (Sgs_user_session.Session.capabilities session) tenants
                  with
                  | [] -> respond_unmasked_denied ctx
                  | unmasked_tenants ->
                      run_query ~unmasked_tenants config storage user q tz page >>= respond ctx)
              | Error (#Pgsql_io.err as err) ->
                  Logs.err (fun m ->
                      m "%s : MQL_TENANTS_ERR : %a" (Brtl_ctx.token ctx) Pgsql_io.pp_err err);
                  respond_internal_error ctx
              | Error (#Pgsql_pool.err as err) ->
                  Logs.err (fun m ->
                      m "%s : MQL_TENANTS_ERR : %a" (Brtl_ctx.token ctx) Pgsql_pool.pp_err err);
                  respond_internal_error ctx)))

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
  let unmasked_tenants = unmasked_tenants

  let status_of_err err =
    match err_response err with
    | Bad_request _ -> `Bad_request
    | Internal_error -> `Internal_server_error
end
