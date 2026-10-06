(* OAuth2 Session Storage Endpoints

   These endpoints implement the HTTP session storage API for oauth2-proxy.
   They allow oauth2-proxy to store, retrieve, and delete session data
   during the OAuth flow.

   API:
   - PUT /internal/oauth2-sessions/{namespace}/sessions/{key}
     Body: {"data": "base64", "ttl_seconds": int}
   - GET /internal/oauth2-sessions/{namespace}/sessions/{key}
     Returns: {"data": "base64"} or 404
   - DELETE /internal/oauth2-sessions/{namespace}/sessions/{key}
   - GET /internal/oauth2-sessions/{namespace}/health
*)

let src = Logs.Src.create "ep_oauth2_sessions"

module Logs = (val Logs.src_log src : Logs.LOG)

module Sql = struct
  let insert_session () =
    Pgsql_io.Typed_sql.(
      sql
      /^ [%blob "./sql/insert_oauth2_session.sql"]
      /% Var.text "key"
      /% Var.text "namespace"
      /% Var.text "config_hash"
      /% Var.text "data"
      /% Var.text "ttl_seconds")

  let select_session () =
    Pgsql_io.Typed_sql.(
      sql
      // Ret.text
      /^ [%blob "./sql/select_oauth2_session.sql"]
      /% Var.text "namespace"
      /% Var.text "key")

  let delete_session () =
    Pgsql_io.Typed_sql.(
      sql /^ [%blob "./sql/delete_oauth2_session.sql"] /% Var.text "namespace" /% Var.text "key")
end

(* Request body for PUT /sessions/{key} *)
module Put_request = struct
  type t = {
    data : string;
    ttl_seconds : int;
  }
  [@@deriving yojson { strict = false }]
end

(* Response body for GET /sessions/{key} *)
module Get_response = struct
  type t = { data : string } [@@deriving yojson]
end

(* Validate the API key from the Authorization header *)
let validate_api_key config ctx =
  let headers = Cohttp.Request.headers @@ Brtl_ctx.request ctx in
  match Cohttp.Header.get headers "authorization" with
  | Some auth_header -> (
      (* Parse "Bearer <token>" format *)
      match CCString.Split.left ~by:" " auth_header with
      | Some ("Bearer", token) ->
          let expected_key = Sgs_config.oauth2_api_key config in
          if String.equal token expected_key then Ok () else Error `Unauthorized
      | _ -> Error `Unauthorized)
  | None -> Error `Unauthorized

(* PUT /internal/oauth2-sessions/{namespace}/sessions/{key} *)
module Put = struct
  let run config storage namespace key body =
    Brtl_ep.run_json ~f:(fun ctx ->
        match validate_api_key config ctx with
        | Ok () -> (
            (* TODO: Get config_hash from config in Phase 3 *)
            let config_hash = "default" in
            let ttl_seconds = string_of_int body.Put_request.ttl_seconds in
            let run =
              Pgsql_pool.with_conn storage ~f:(fun db ->
                  Pgsql_io.Prepared_stmt.execute
                    db
                    (Sql.insert_session ())
                    key
                    namespace
                    config_hash
                    body.Put_request.data
                    ttl_seconds)
            in
            let open Abb.Future.Infix_monad in
            run
            >>= function
            | Ok () ->
                Abb.Future.return (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`OK "") ctx)
            | Error (#Pgsql_io.err as err) ->
                Logs.err (fun m -> m "%s : %a" (Brtl_ctx.token ctx) Pgsql_io.pp_err err);
                Abb.Future.return (Sgs_eplib.respond_internal_error ctx)
            | Error (#Pgsql_pool.err as err) ->
                Logs.err (fun m -> m "%s : %a" (Brtl_ctx.token ctx) Pgsql_pool.pp_err err);
                Abb.Future.return (Sgs_eplib.respond_internal_error ctx))
        | Error `Unauthorized ->
            Abb.Future.return
              (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Unauthorized "") ctx))
end

(* GET /internal/oauth2-sessions/{namespace}/sessions/{key} *)
module Get = struct
  let run config storage namespace key =
    Brtl_ep.run_json ~f:(fun ctx ->
        match validate_api_key config ctx with
        | Ok () -> (
            let run =
              Pgsql_pool.with_conn storage ~f:(fun db ->
                  Pgsql_io.Prepared_stmt.fetch
                    db
                    (Sql.select_session ())
                    ~f:(fun data -> data)
                    namespace
                    key)
            in
            let open Abb.Future.Infix_monad in
            run
            >>= function
            | Ok [] ->
                Abb.Future.return
                  (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Not_found "") ctx)
            | Ok (data :: _) ->
                let body = Yojson.Safe.to_string (Get_response.to_yojson { Get_response.data }) in
                Abb.Future.return (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`OK body) ctx)
            | Error (#Pgsql_io.err as err) ->
                Logs.err (fun m -> m "%s : %a" (Brtl_ctx.token ctx) Pgsql_io.pp_err err);
                Abb.Future.return (Sgs_eplib.respond_internal_error ctx)
            | Error (#Pgsql_pool.err as err) ->
                Logs.err (fun m -> m "%s : %a" (Brtl_ctx.token ctx) Pgsql_pool.pp_err err);
                Abb.Future.return (Sgs_eplib.respond_internal_error ctx))
        | Error `Unauthorized ->
            Abb.Future.return
              (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Unauthorized "") ctx))
end

(* DELETE /internal/oauth2-sessions/{namespace}/sessions/{key} *)
module Delete = struct
  let run config storage namespace key =
    Brtl_ep.run_json ~f:(fun ctx ->
        match validate_api_key config ctx with
        | Ok () -> (
            let run =
              Pgsql_pool.with_conn storage ~f:(fun db ->
                  Pgsql_io.Prepared_stmt.execute db (Sql.delete_session ()) namespace key)
            in
            let open Abb.Future.Infix_monad in
            run
            >>= function
            | Ok () ->
                Abb.Future.return (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`OK "") ctx)
            | Error (#Pgsql_io.err as err) ->
                Logs.err (fun m -> m "%s : %a" (Brtl_ctx.token ctx) Pgsql_io.pp_err err);
                Abb.Future.return (Sgs_eplib.respond_internal_error ctx)
            | Error (#Pgsql_pool.err as err) ->
                Logs.err (fun m -> m "%s : %a" (Brtl_ctx.token ctx) Pgsql_pool.pp_err err);
                Abb.Future.return (Sgs_eplib.respond_internal_error ctx))
        | Error `Unauthorized ->
            Abb.Future.return
              (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Unauthorized "") ctx))
end

(* GET /internal/oauth2-sessions/{namespace}/health *)
module Health = struct
  let run _config _storage _namespace =
    Brtl_ep.run_json ~f:(fun ctx ->
        Abb.Future.return (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`OK "") ctx))
end
