let src = Logs.Src.create "ep_access_token_revoke"

module Logs = (val Logs.src_log src : Logs.LOG)
module Fc = Abbs_fc

let run' storage ~is_admin user token_id =
  let open Fc.Infix_result_monad in
  let delete_token db =
    if is_admin then Sgs_user_access_token.delete_any ~token_id db
    else Sgs_user_access_token.delete ~token_id user db
  in
  Pgsql_pool.with_conn storage ~f:delete_token
  >>| fun () ->
  let response =
    {
      Sgs_api_components_access_token_revoke_response.id = Uuidm.to_string token_id;
      revoked = true;
    }
  in
  let body =
    Yojson.Safe.to_string @@ Sgs_api_components_access_token_revoke_response.to_yojson response
  in
  body

let run _config storage token_id_str =
  Sgs_user_session.with_session ~caps:Sgs_user_session.Caps.allow_all ~f:(fun session ->
      Brtl_ep.run_json ~f:(fun ctx ->
          let open Abb.Future.Infix_monad in
          let user = Sgs_user_session.Session.user session in
          let is_admin =
            Sgs_user_session.Caps.is_allowed
              (Sgs_user_session.Caps.admin_instance
                 (Sgs_user_session.Session.capabilities session)
                 user)
          in
          match Uuidm.of_string token_id_str with
          | None ->
              Logs.warn (fun m ->
                  m
                    "%s : INVALID_TOKEN_ID : Invalid UUID format for token_id %s"
                    (Brtl_ctx.token ctx)
                    token_id_str);
              let error_response =
                {
                  Sgs_api_components_error_response.id = "INVALID_TOKEN_ID";
                  data = Some "Token ID must be a valid UUID";
                }
              in
              let body =
                Yojson.Safe.to_string @@ Sgs_api_components_error_response.to_yojson error_response
              in
              Abb.Future.return
                (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Bad_request body) ctx)
          | Some token_id -> (
              run' storage ~is_admin user token_id
              >>= function
              | Ok body ->
                  Logs.info (fun m ->
                      m
                        "%s : ACCESS_TOKEN_REVOKED : Revoked token %s"
                        (Brtl_ctx.token ctx)
                        token_id_str);
                  Abb.Future.return (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`OK body) ctx)
              | Error (`Access_token_not_found_err _) ->
                  Logs.warn (fun m ->
                      m
                        "%s : ACCESS_TOKEN_NOT_FOUND : Token %s not found"
                        (Brtl_ctx.token ctx)
                        token_id_str);
                  let error_response =
                    {
                      Sgs_api_components_error_response.id = "ACCESS_TOKEN_NOT_FOUND";
                      data = Some "Access token not found";
                    }
                  in
                  let body =
                    Yojson.Safe.to_string
                    @@ Sgs_api_components_error_response.to_yojson error_response
                  in
                  Abb.Future.return
                    (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Not_found body) ctx)
              | Error (#Pgsql_pool.err as err) ->
                  Logs.err (fun m ->
                      m "%s : DB_ERROR %a" (Brtl_ctx.token ctx) Pgsql_pool.pp_err err);
                  let error_response =
                    {
                      Sgs_api_components_error_response.id = "INTERNAL_SERVER_ERROR";
                      data = Some "Failed to revoke access token";
                    }
                  in
                  let body =
                    Yojson.Safe.to_string
                    @@ Sgs_api_components_error_response.to_yojson error_response
                  in
                  Abb.Future.return (Sgs_eplib.respond_internal_error ~body ctx)
              | Error (#Pgsql_io.err as err) ->
                  Logs.err (fun m -> m "%s : DB_ERROR %a" (Brtl_ctx.token ctx) Pgsql_io.pp_err err);
                  let error_response =
                    {
                      Sgs_api_components_error_response.id = "INTERNAL_SERVER_ERROR";
                      data = Some "Failed to revoke access token";
                    }
                  in
                  let body =
                    Yojson.Safe.to_string
                    @@ Sgs_api_components_error_response.to_yojson error_response
                  in
                  Abb.Future.return (Sgs_eplib.respond_internal_error ~body ctx))))
