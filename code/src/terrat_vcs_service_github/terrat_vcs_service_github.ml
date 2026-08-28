let src = Logs.Src.create "vcs_service_github"

module Logs = (val Logs.src_log src : Logs.LOG)

module type ROUTES = sig
  type config

  val routes :
    config ->
    Terrat_storage.t ->
    (Brtl_rtng.Method.t * Brtl_rtng.Handler.t Brtl_rtng.Route.Route.t) list
end

module Make
    (Provider :
      Terrat_vcs_provider2_github.S
        with type Api.Config.t = Terrat_vcs_service_github_provider.Api.Config.t)
    (Routes : ROUTES with type config = Provider.Api.Config.t) =
struct
  module Evaluator = Terrat_vcs_event_evaluator.Make (Provider)
  module Evaluator2 = Terrat_vcs_event_evaluator2.Make (Provider)
  module Events = Terrat_vcs_service_github_ep_events3.Make (Provider)
  module Work_manifest = Terrat_vcs_service_github_ep_work_manifest.Make (Provider)

  module Ep_inst = Terrat_vcs_service_github_ep_installations.Make (struct
    module Account_id = Provider.Api.Account.Id

    let enforce_installation_access = Provider.enforce_installation_access
  end)

  module Ep_repo_delete =
    Terrat_vcs_service_github_ep_repo_delete.Make
      (Provider)
      (struct
        let enforce_installation_access = Provider.enforce_installation_access
      end)

  module Ep_user = Terrat_vcs_service_github_ep_user

  module Kv_store =
    Terrat_vcs_kv_store.Make
      (Provider)
      (struct
        module Installation_id = Provider.Api.Account.Id

        let namespace_prefix = Provider.name
        let route_root () = Brtl_rtng.Route.(rel / "api" / "v1" / "github")
        let enforce_installation_access = Provider.enforce_installation_access
      end)

  module Routes = struct
    module Rt = struct
      (* Apparently at some point Malcolm decided that it made sense to have two
         sets of URLs.  Those that look like [/api/github/v1] and those that
         look like [/api/v1/github].  The ones that look like [/api/github/v1]
         are calls that, generally, come from the action, so that is probably
         because we pass an API base URL to the action, and we want it to always
         hit GitHub, and be able to version that URL.  The other APIs are for
         the UI and non-action related.  I'm not sure if it makes sense to
         rewrite these to all be of the form [/api/github/v1]. *)
      let api () = Brtl_rtng.Route.(rel / "api")
      let api_v1 () = Brtl_rtng.Route.(api () / "v1")
      let github_client_id () = Brtl_rtng.Route.(api_v1 () / "github" / "client_id")
      let github_whoami () = Brtl_rtng.Route.(api_v1 () / "github" / "whoami")
      let work_manifest_root base = Brtl_rtng.Route.(base () / "work-manifests")
      let work_manifest base = Brtl_rtng.Route.(work_manifest_root base /% Path.ud Uuidm.of_string)

      let work_manifest_initiate base =
        Brtl_rtng.Route.(
          work_manifest base
          / "initiate"
          /* Body.decode ~json:Terrat_api_work_manifest.Initiate.Request_body.of_yojson ())

      let work_manifest_plan base =
        Brtl_rtng.Route.(
          work_manifest base
          / "plans"
          /* Body.decode ~json:Terrat_api_work_manifest.Plan_create.Request_body.of_yojson ())

      let work_manifest_workspaces base = Brtl_rtng.Route.(work_manifest base / "workspaces")

      let work_manifest_results base =
        Brtl_rtng.Route.(
          work_manifest base
          /* Body.decode ~json:Terrat_api_work_manifest.Results.Request_body.of_yojson ())

      let work_manifest_access_token base = Brtl_rtng.Route.(work_manifest base / "access-token")

      (* This is the other group of URLs, which are [/api/github/v1] *)
      let github () = Brtl_rtng.Route.(api () / "github")
      let github_v1 () = Brtl_rtng.Route.(github () / "v1")
      let github_events () = Brtl_rtng.Route.(github_v1 () / "events")
      let github_work_manifest_plan () = work_manifest_plan github_v1
      let github_work_manifest_workspaces () = work_manifest_workspaces github_v1
      let github_work_manifest_initiate () = work_manifest_initiate github_v1
      let github_work_manifest_results () = work_manifest_results github_v1
      let github_work_manifest_access_token () = work_manifest_access_token github_v1

      let github_get_work_manifest_plan () =
        Brtl_rtng.Route.(
          work_manifest github_v1 / "plans" /? Query.string "path" /? Query.string "workspace")

      let github_callback () =
        Brtl_rtng.Route.(
          github_v1 ()
          / "callback"
          /? Query.string "code"
          /? Query.(option (ud "installation_id" (CCOption.wrap Int64.of_string))))

      (* Legacy Installations API *)
      let legacy_installation_api_rt () = Brtl_rtng.Route.(api_v1 () / "installations")

      let legacy_installation_work_manifests_rt () =
        Brtl_rtng.Route.(
          legacy_installation_api_rt ()
          /% Path.int
          / "work-manifests"
          /? Query.(option (string "q"))
          /? Query.(option (string "tz"))
          /? Query.(
               option
                 (ud_array
                    "page"
                    Brtl_ep_paginate.Param.(of_param Typ.(tuple (string, ud' Uuidm.of_string)))))
          /? Query.(option_default 20 (Query.int "limit")))

      let legacy_installation_work_manifest_outputs_rt () =
        Brtl_rtng.Route.(
          legacy_installation_api_rt ()
          /% Path.int
          / "work-manifests"
          /% Path.ud Uuidm.of_string
          / "outputs"
          /? Query.(option (string "q"))
          /? Query.(option (string "tz"))
          /? Query.(option (ud_array "page" Brtl_ep_paginate.Param.(of_param Typ.int)))
          /? Query.(option_default 20 (Query.int "limit"))
          /? Query.(option_default false (Query.bool "lite")))

      let legacy_installation_dirspaces_rt () =
        Brtl_rtng.Route.(
          legacy_installation_api_rt ()
          /% Path.int
          / "dirspaces"
          /? Query.(option (string "q"))
          /? Query.(option (string "tz"))
          /? Query.(
               option
                 (ud_array
                    "page"
                    Brtl_ep_paginate.Param.(
                      of_param Typ.(tuple4 (string, string, string, ud' Uuidm.of_string)))))
          /? Query.(option_default 20 (Query.int "limit")))

      let legacy_installation_pull_requests_manifests_rt () =
        Brtl_rtng.Route.(
          legacy_installation_api_rt ()
          /% Path.int
          / "pull-requests"
          /? Query.(option (int "pr"))
          /? Query.(
               option
                 (ud_array "page" Brtl_ep_paginate.Param.(of_param Typ.(ud' CCInt64.of_string_opt))))
          /? Query.(option_default 20 (Query.int "limit")))

      let legacy_installation_repos_rt () =
        Brtl_rtng.Route.(
          legacy_installation_api_rt ()
          /% Path.int
          / "repos"
          /? Query.(option (ud_array "page" Brtl_ep_paginate.Param.(of_param Typ.string)))
          /? Query.(option_default 20 (int "limit")))

      let legacy_installation_repos_refresh_rt () =
        Brtl_rtng.Route.(legacy_installation_api_rt () /% Path.int / "repos" / "refresh")

      (* VCS Specific installations API *)
      let installation_api_rt () = Brtl_rtng.Route.(api_v1 () / "github" / "installations")

      let installation_work_manifests_rt () =
        Brtl_rtng.Route.(
          installation_api_rt ()
          /% Path.int
          / "work-manifests"
          /? Query.(option (string "q"))
          /? Query.(option (string "tz"))
          /? Query.(
               option
                 (ud_array
                    "page"
                    Brtl_ep_paginate.Param.(of_param Typ.(tuple (string, ud' Uuidm.of_string)))))
          /? Query.(option_default 20 (Query.int "limit")))

      let installation_work_manifest_outputs_rt () =
        Brtl_rtng.Route.(
          installation_api_rt ()
          /% Path.int
          / "work-manifests"
          /% Path.ud Uuidm.of_string
          / "outputs"
          /? Query.(option (string "q"))
          /? Query.(option (string "tz"))
          /? Query.(option (ud_array "page" Brtl_ep_paginate.Param.(of_param Typ.int)))
          /? Query.(option_default 20 (Query.int "limit"))
          /? Query.(option_default false (Query.bool "lite")))

      let installation_dirspaces_rt () =
        Brtl_rtng.Route.(
          installation_api_rt ()
          /% Path.int
          / "dirspaces"
          /? Query.(option (string "q"))
          /? Query.(option (string "tz"))
          /? Query.(
               option
                 (ud_array
                    "page"
                    Brtl_ep_paginate.Param.(
                      of_param Typ.(tuple4 (string, string, string, ud' Uuidm.of_string)))))
          /? Query.(option_default 20 (Query.int "limit")))

      let installation_pull_requests_manifests_rt () =
        Brtl_rtng.Route.(
          installation_api_rt ()
          /% Path.int
          / "pull-requests"
          /? Query.(option (int "pr"))
          /? Query.(
               option
                 (ud_array "page" Brtl_ep_paginate.Param.(of_param Typ.(ud' CCInt64.of_string_opt))))
          /? Query.(option_default 20 (Query.int "limit")))

      let installation_repos_rt () =
        Brtl_rtng.Route.(
          installation_api_rt ()
          /% Path.int
          / "repos"
          /? Query.(option (ud_array "page" Brtl_ep_paginate.Param.(of_param Typ.string)))
          /? Query.(option_default 20 (int "limit")))

      let installation_repos_refresh_rt () =
        Brtl_rtng.Route.(installation_api_rt () /% Path.int / "repos" / "refresh")

      let installation_repo_delete_rt () =
        Brtl_rtng.Route.(installation_api_rt () /% Path.int / "repos" /% Path.string)

      let legacy_installation_repo_delete_rt () =
        Brtl_rtng.Route.(legacy_installation_api_rt () /% Path.int / "repos" /% Path.string)

      (* User API *)
      let user_api_rt () = Brtl_rtng.Route.(api_v1 () / "user")
      let user_installations_rt () = Brtl_rtng.Route.(user_api_rt () / "github" / "installations")
    end

    let routes config storage exec =
      Routes.routes config storage
      @ Provider.Stacks.routes config storage
      @ Kv_store.routes config storage
      @ Brtl_rtng.Route.
          [
            (* Work manifests *)
            (`POST, Rt.github_work_manifest_plan () --> Work_manifest.Plans.post config storage);
            (`GET, Rt.github_get_work_manifest_plan () --> Work_manifest.Plans.get config storage);
            ( `PUT,
              Rt.github_work_manifest_results () --> Work_manifest.Results.put config storage exec
            );
            ( `POST,
              Rt.github_work_manifest_initiate ()
              --> Work_manifest.Initiate.post config storage exec );
            ( `POST,
              Rt.github_work_manifest_access_token ()
              --> Work_manifest.Access_token.post config storage );
            ( `GET,
              Rt.github_work_manifest_workspaces () --> Work_manifest.Workspaces.get config storage
            );
            (* Github *)
            (`POST, Rt.github_events () --> Events.post config storage exec);
            ( `GET,
              Rt.github_callback () --> Terrat_vcs_service_github_ep_callback.get config storage );
            ( `GET,
              Rt.github_client_id () --> Terrat_vcs_service_github_ep_client_id.get config storage
            );
            ( `GET,
              Rt.github_whoami () --> Terrat_vcs_service_github_ep_user.Whoami.get config storage );
            (* Installations *)
            (`GET, Rt.installation_dirspaces_rt () --> Ep_inst.Dirspaces.get config storage);
            ( `GET,
              Rt.installation_work_manifests_rt () --> Ep_inst.Work_manifests.get config storage );
            ( `GET,
              Rt.installation_work_manifest_outputs_rt ()
              --> Ep_inst.Work_manifests.Outputs.get config storage );
            ( `GET,
              Rt.installation_pull_requests_manifests_rt ()
              --> Ep_inst.Pull_requests.get config storage );
            (`GET, Rt.installation_repos_rt () --> Ep_inst.Repos.get config storage);
            ( `POST,
              Rt.installation_repos_refresh_rt () --> Ep_inst.Repos.Refresh.post config storage );
            (`DELETE, Rt.installation_repo_delete_rt () --> Ep_repo_delete.delete config storage);
            (`GET, Rt.user_installations_rt () --> Ep_user.Installations.get config storage);
            (* Legacy Installations *)
            (`GET, Rt.legacy_installation_dirspaces_rt () --> Ep_inst.Dirspaces.get config storage);
            ( `GET,
              Rt.legacy_installation_work_manifests_rt ()
              --> Ep_inst.Work_manifests.get config storage );
            ( `GET,
              Rt.legacy_installation_work_manifest_outputs_rt ()
              --> Ep_inst.Work_manifests.Outputs.get config storage );
            ( `GET,
              Rt.legacy_installation_pull_requests_manifests_rt ()
              --> Ep_inst.Pull_requests.get config storage );
            (`GET, Rt.legacy_installation_repos_rt () --> Ep_inst.Repos.get config storage);
            ( `POST,
              Rt.legacy_installation_repos_refresh_rt ()
              --> Ep_inst.Repos.Refresh.post config storage );
            ( `DELETE,
              Rt.legacy_installation_repo_delete_rt () --> Ep_repo_delete.delete config storage );
          ]
  end

  module Service = struct
    module Sql = struct
      let read s = Pgsql_io.clean_string s

      let select_github_user2_exists =
        Pgsql_io.Typed_sql.(
          sql
          //
          (* created_at *)
          Ret.text
          /^ read [%blob "sql/select_github_user2_exists.sql"]
          /% Var.uuid "user_id")
    end

    type vcs_config = Provider.Api.Config.vcs_config

    let one_hour = Duration.to_f (Duration.of_hour 1)

    type t = {
      config : Provider.Api.Config.t;
      storage : Terrat_storage.t;
      drift : unit Abb.Future.t;
      flow_state_cleanup : unit Abb.Future.t;
      plan_cleanup : unit Abb.Future.t;
      repo_config_cleanup : unit Abb.Future.t;
      exec : Terrat_vcs_event_evaluator2.Exec.t;
    }

    let rec drift config storage exec =
      let open Abb.Future.Infix_monad in
      Abbs_future_combinators.ignore
        (Evaluator2.run_missing_drift_schedules ~config ~storage ~exec ())
      >>= fun () -> Abb.Sys.sleep one_hour >>= fun () -> drift config storage exec

    let rec flow_state_cleanup config storage =
      let open Abb.Future.Infix_monad in
      Abbs_future_combinators.ignore
        (Evaluator.run_flow_state_cleanup
           (Evaluator.Ctx.make ~config ~storage ~request_id:(Ouuid.to_string (Ouuid.v4 ())) ()))
      >>= fun () -> Abb.Sys.sleep one_hour >>= fun () -> flow_state_cleanup config storage

    let rec plan_cleanup config storage =
      let open Abb.Future.Infix_monad in
      Abbs_future_combinators.ignore
        (Evaluator.run_plan_cleanup
           (Evaluator.Ctx.make ~config ~storage ~request_id:(Ouuid.to_string (Ouuid.v4 ())) ()))
      >>= fun () -> Abb.Sys.sleep one_hour >>= fun () -> plan_cleanup config storage

    let rec repo_config_cleanup config storage =
      let open Abb.Future.Infix_monad in
      Abbs_future_combinators.ignore
        (Evaluator.run_repo_config_cleanup
           (Evaluator.Ctx.make ~config ~storage ~request_id:(Ouuid.to_string (Ouuid.v4 ())) ()))
      >>= fun () -> Abb.Sys.sleep one_hour >>= fun () -> repo_config_cleanup config storage

    let name _ = "github"

    let start config vcs_config storage exec =
      let open Abb.Future.Infix_monad in
      let config = Provider.Api.Config.make ~config ~vcs_config () in
      Abb.Future.Infix_app.(
        (fun drift flow_state_cleanup plan_cleanup repo_config_cleanup ->
          (drift, flow_state_cleanup, plan_cleanup, repo_config_cleanup))
        <$> Abb.Future.fork (drift config storage exec)
        <*> Abb.Future.fork (flow_state_cleanup config storage)
        <*> Abb.Future.fork (plan_cleanup config storage)
        <*> Abb.Future.fork (repo_config_cleanup config storage))
      >>= fun (drift, flow_state_cleanup, plan_cleanup, repo_config_cleanup) ->
      Abbs_future_combinators.return_ok
        { config; storage; drift; flow_state_cleanup; plan_cleanup; repo_config_cleanup; exec }

    let stop t =
      let open Abb.Future.Infix_monad in
      Abb.Future.abort t.drift
      >>= fun () ->
      Abb.Future.abort t.flow_state_cleanup
      >>= fun () ->
      Abb.Future.abort t.plan_cleanup
      >>= fun () -> Abb.Future.abort t.repo_config_cleanup >>= fun () -> Abb.Future.return ()

    let routes t = Routes.routes t.config t.storage t.exec

    let get_user t user_id =
      let run =
        let open Abbs_future_combinators.Infix_result_monad in
        Pgsql_pool.with_conn t.storage ~f:(fun db ->
            Pgsql_io.Prepared_stmt.fetch db Sql.select_github_user2_exists ~f:CCFun.id user_id
            >>| function
            | [] -> None
            | _ :: _ -> Some (Terrat_user.make ~id:user_id ()))
      in
      let open Abb.Future.Infix_monad in
      run
      >>= function
      | Ok _ as ret -> Abb.Future.return ret
      | Error (#Pgsql_pool.err as err) ->
          Logs.err (fun m -> m "GET_USER : user_id=%a : %a" Uuidm.pp user_id Pgsql_pool.pp_err err);
          Abbs_future_combinators.return_err `Error
      | Error (#Pgsql_io.err as err) ->
          Logs.err (fun m -> m "GET_USER : user_id=%a : %a" Uuidm.pp user_id Pgsql_io.pp_err err);
          Abbs_future_combinators.return_err `Error
  end
end
