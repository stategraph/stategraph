let src = Logs.Src.create "ep_capabilities"

let run config storage =
  Sgs_user_session.with_user ~caps:Sgs_user_session.Caps.allow_all ~f:(fun _user ->
      Brtl_ep.run_json ~f:(fun ctx ->
          let open Abb.Future.Infix_monad in
          let module C = Sgs_api_components_capabilities in
          let module Ca = Sgs_api_components_costs_availability in
          let module Da = Sgs_api_components_dedicated_availability in
          let module Ga = Sgs_api_components_github_app_availability in
          let module Oa = Sgs_api_components_orchestration_availability in
          let module Sa = Sgs_api_components_security_availability in
          let costs_enabled = Sgs_config.cost_enabled config in
          let dedicated_enabled = Sgs_config.dedicated_enabled config in
          let security_enabled = Sgs_config.security_enabled config in
          (* Only a server that could have stored an App pays for the read. *)
          (if Sgs_service_orchestration_github_app.channel_available config then
             Pgsql_pool.with_conn storage ~f:(fun db ->
                 Sgs_service_orchestration_github_app.stored config db)
           else Abb.Future.return (Ok None))
          >>= fun stored ->
          (* The console must load whatever the engine's admin channel does:
             a failed read is logged and reported as no stored App. *)
          let stored =
            match stored with
            | Ok stored -> stored
            | Error ((#Pgsql_pool.err | #Pgsql_io.err) as err) ->
                Sgs_eplib.log_db_err ~src ctx err;
                None
          in
          let { Sgs_service_orchestration_github_app.configured; ready } =
            Sgs_service_orchestration_github_app.status_of
              ~env_app_id:(Sgs_config.github_app_id config)
              ~stored
          in
          let body =
            Yojson.Safe.to_string
            @@ C.to_yojson
                 {
                   C.costs = { Ca.enabled = costs_enabled };
                   dedicated = { Da.enabled = dedicated_enabled };
                   github_app =
                     {
                       Ga.configured;
                       creatable = Sgs_service_orchestration_github_app.channel_available config;
                       ready;
                     };
                   github_app_url =
                     Sgs_service_orchestration_github_app.app_url_of
                       ~env_app_url:(Sgs_config.github_app_url config)
                       ~stored;
                   orchestration = { Oa.enabled = Sgs_config.orchestration_enabled config };
                   security = { Sa.enabled = security_enabled };
                 }
          in
          Abb.Future.return (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`OK body) ctx)))
