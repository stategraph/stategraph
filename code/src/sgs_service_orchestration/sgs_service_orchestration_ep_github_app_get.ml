let src = Logs.Src.create "service_orchestration_ep_github_app_get"

let stored_to_api stored =
  let {
    Sgs_service_orchestration_github_app.Stored.id;
    slug;
    client_id = _;
    client_secret = _;
    html_url;
    created_at;
    loaded;
  } =
    stored
  in
  {
    Sgs_api_components_github_app_stored.app_id = Int64.to_int id;
    slug;
    html_url;
    created_at;
    loaded;
  }

let run config storage =
  Sgs_user_session.with_user ~caps:Sgs_user_session.Caps.admin_instance ~f:(fun _user ->
      Brtl_ep.run_json ~f:(fun ctx ->
          let open Abb.Future.Infix_monad in
          let module R = Sgs_api_components_github_app_response in
          (* A deployment that brings its own App manages it where those values
             are set. It has no App of this server's to describe, so the whole
             surface is closed rather than answering about somebody else's. *)
          if Sgs_config.github_app_managed config then
            Abb.Future.return (Sgs_service_orchestration_github_app_common.respond_unavailable ctx)
          else
            (if Sgs_service_orchestration_github_app.channel_available config then
               Pgsql_pool.with_conn storage ~f:(fun db ->
                   Sgs_service_orchestration_github_app.stored config db)
             else Abb.Future.return (Ok None))
            >>= function
            | Ok stored ->
                let source =
                  Sgs_service_orchestration_github_app.source_of
                    ~env_app_id:(Sgs_config.github_app_id config)
                    ~readable:(Sgs_service_orchestration_github_app.channel_available config)
                    ~stored
                in
                let body =
                  Yojson.Safe.to_string
                  @@ R.to_yojson
                       {
                         R.source;
                         (* Only a stored App is described. The environment's App is
                          the operator's own, and its row is hidden anyway. *)
                         app =
                           (match source with
                           | `Stored -> CCOption.map stored_to_api stored
                           | `Environment | `None | `Unknown -> None);
                       }
                in
                Abb.Future.return (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`OK body) ctx)
            | Error ((#Pgsql_pool.err | #Pgsql_io.err) as err) ->
                Sgs_eplib.log_db_err ~src ctx err;
                Abb.Future.return (Sgs_eplib.respond_internal_error ctx)))
