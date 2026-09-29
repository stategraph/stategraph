let src = Logs.Src.create "service_orchestration_ep_vcs_installation_unclaimed_github"

(* Bounded so one request cannot ask for a whole terrateam database's worth of
   never-claimed installs. Unlike a cap, this truncates nothing: the caller walks
   the rest with the cursor. *)
let max_page_size = 200

let run ~cursor ~limit config storage =
  (* "Unclaimed" installs are linked to NO tenant, so the list is inherently
     instance-wide, not tenant-scoped. Gate on admin_instance — the same
     authority the PUT link/DELETE unlink endpoints require — so seeing an
     install and claiming it need the same grant, and a tenant-scoped admin
     cannot enumerate other orgs' pending installs.

     This is also why the listing is not served through MQL like the other list
     endpoints: every terrateam table in the MQL catalog resolves to a CTE
     anchored on the caller's tenant_vcs_installations rows, and "unclaimed" is
     exactly the complement of that anchor. *)
  Sgs_user_session.with_user ~caps:Sgs_user_session.Caps.admin_instance ~f:(fun _user ->
      Brtl_ep.run_json ~f:(fun ctx ->
          let open Abb.Future.Infix_monad in
          if not (Sgs_config.orchestration_enabled config) then
            Abb.Future.return
              (Sgs_service_orchestration_common.respond_orchestration_unavailable ~src ctx)
          else
            let limit = CCInt.max 1 (CCInt.min max_page_size limit) in
            (* A cursor is only ever one we minted, so anything unparseable is
               the client's to lose: start from the first page rather than
               failing the request. *)
            let cursor = CCOption.flat_map Sgs_eplib.Cursor.decode cursor in
            Pgsql_pool.with_conn storage ~f:(fun db ->
                Sgs_service_orchestration_github_installations.list_unclaimed ~cursor ~limit db)
            >>= function
            | Ok installations ->
                let results =
                  CCList.map Sgs_service_orchestration_github_installations.to_api installations
                in
                (* A full page is the only evidence of more: asking for one extra
                   row would cost a second page's worth of the FDW scan on every
                   request, and an empty final page is cheap by comparison. *)
                let has_more = CCList.length installations = limit in
                let next_cursor =
                  if has_more then
                    CCOption.map
                      (fun t ->
                        Sgs_eplib.Cursor.encode
                          ~timestamp:t.Sgs_service_orchestration_github_installations.created_at
                          ~id:t.Sgs_service_orchestration_github_installations.installation_core_id)
                      (CCList.last_opt installations)
                  else None
                in
                let body =
                  Yojson.Safe.to_string
                  @@ Sgs_api_components.Github_unclaimed_installations.to_yojson
                       {
                         Sgs_api_components.Github_unclaimed_installations.results;
                         limit;
                         has_more;
                         next_cursor;
                       }
                in
                Abb.Future.return (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`OK body) ctx)
            | Error ((#Pgsql_io.err | #Pgsql_pool.err) as err) ->
                Abb.Future.return (Sgs_eplib.respond_db_err ~src ctx err)))
