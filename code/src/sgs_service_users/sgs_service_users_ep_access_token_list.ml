let src = Logs.Src.create "ep_access_token_list"

module Logs = (val Logs.src_log src : Logs.LOG)

let run _config storage =
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
          let fetch_tokens db =
            if is_admin then Sgs_user_access_token.list_all db
            else Sgs_user_access_token.list_by_user user db
          in
          Pgsql_pool.with_conn storage ~f:fetch_tokens
          >>= function
          | Ok tokens ->
              Logs.info (fun m ->
                  m
                    "%s : ACCESS_TOKENS_LISTED : Listed %d access tokens"
                    (Brtl_ctx.token ctx)
                    (CCList.length tokens));
              let response = { Sgs_api_components_access_token_list_response.tokens } in
              let body =
                Yojson.Safe.to_string
                @@ Sgs_api_components_access_token_list_response.to_yojson response
              in
              Abb.Future.return (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`OK body) ctx)
          | Error ((#Pgsql_pool.err | #Pgsql_io.err) as err) ->
              Abb.Future.return
                (Sgs_eplib.respond_db_err
                   ~src
                   ~body:
                     (Sgs_eplib.error_response_body
                        ~id:"INTERNAL_SERVER_ERROR"
                        ~data:"Failed to list access tokens")
                   ctx
                   err)))
