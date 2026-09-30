let src = Logs.Src.create "vcs_service_gitlab_ep_events"

module Logs = (val Logs.src_log src : Logs.LOG)

module Metrics = struct
  module DefaultHistogram = Prmths.Histogram (struct
    let spec = Prmths.Histogram_spec.of_list [ 0.005; 0.5; 1.0; 5.0; 10.0; 15.0; 20.0 ]
  end)

  let namespace = "terrat"
  let subsystem = "ep_gitlab_events"

  let events_duration_seconds =
    let help = "Number of seconds that handling an incoming event takes" in
    DefaultHistogram.v ~help ~namespace ~subsystem "events_duration_seconds"

  let events_concurrent =
    let help = "Number of events being handled right now" in
    Prmths.Gauge.v ~help ~namespace ~subsystem "events_concurrent"
end

module Sql = struct
  let read s = Pgsql_io.clean_string s

  let select_installation_by_webhook_secret () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* id *)
      Ret.bigint
      //
      (* state *)
      Ret.text
      /^ read [%blob "sql/select_installation_by_webhook_secret.sql"]
      /% Var.text "webhook_secret")

  let update_installation_to_installed () =
    Pgsql_io.Typed_sql.(
      sql /^ read [%blob "sql/update_installation_to_installed.sql"] /% Var.bigint "installation_id")

  let insert_installation_repository () =
    Pgsql_io.Typed_sql.(
      sql
      /^ read [%blob "sql/insert_installation_repository.sql"]
      /% Var.bigint "id"
      /% Var.bigint "installation_id"
      /% Var.text "owner"
      /% Var.text "name")
end

module Make (P : Terrat_vcs_provider2_gitlab.S) = struct
  module Evaluator2 = Terrat_vcs_event_evaluator2.Make (P)

  let decode ctx = Gitlab_webhooks_decoder.run @@ Brtl_ctx.body ctx

  let parse_path_with_namespace path_with_namespace =
    match CCString.Split.left ~by:"/" path_with_namespace with
    | Some (owner, name) -> (owner, name)
    | None -> raise (Failure "nyi")

  let upsert_installation_repo _config storage installation_id =
    let module E = Gitlab_webhooks.Event in
    let module Pe = Gitlab_webhooks_push_event in
    let module Mre = Gitlab_webhooks_merge_request_event in
    let module Mrce = Gitlab_webhooks_merge_request_comment_event in
    let module Pipee = Gitlab_webhooks_pipeline_event in
    let module Je = Gitlab_webhooks_job_event in
    function
    | E.Push_event { Pe.project; _ }
    | E.Merge_request_event { Mre.project; _ }
    | E.Merge_request_comment_event { Mrce.project; _ }
    | E.Pipeline_event { Pipee.project; _ }
    | E.Job_event { Je.project; _ } ->
        let module P = Gitlab_webhooks_project in
        let { P.id; path_with_namespace; _ } = project in
        let owner, name = parse_path_with_namespace path_with_namespace in
        Pgsql_pool.with_conn storage ~f:(fun db ->
            Pgsql_io.Prepared_stmt.execute
              db
              (Sql.insert_installation_repository ())
              (CCInt64.of_int id)
              installation_id
              owner
              name)

  let dispatch_event request_id config storage exec installation_id =
    let module E = Gitlab_webhooks.Event in
    let module Pr = Gitlab_webhooks_project in
    let module Pe = Gitlab_webhooks_push_event in
    let module Mre = Gitlab_webhooks_merge_request_event in
    let module Mrce = Gitlab_webhooks_merge_request_comment_event in
    let module Je = Gitlab_webhooks_job_event in
    let module User = Gitlab_webhooks_user in
    let module Mreoa = Mre.Object_attributes in
    let module Mrceoa = Mrce.Object_attributes in
    let module Mr = Gitlab_webhooks_merge_request in
    function
    | E.Push_event
        {
          Pe.project = { Pr.id = repo_id; path_with_namespace; default_branch; _ };
          ref_;
          user_username;
          _;
        }
      when ref_ = "refs/heads/" ^ default_branch ->
        let owner, name = parse_path_with_namespace path_with_namespace in
        let account = P.Api.Account.make installation_id in
        let repo = P.Api.Repo.make ~id:repo_id ~name ~owner () in
        let user = P.Api.User.make user_username in
        let branch = P.Api.Ref.of_string default_branch in
        Evaluator2.push ~request_id ~config ~storage ~exec ~account ~repo ~branch ~user ()
    | E.Push_event _ -> Abbs_fc.return_ok ()
    | E.Merge_request_comment_event
        { Mrce.object_attributes = { Mrceoa.note = Some comment_body; _ }; _ }
      when Terrat_comment.is_from_self comment_body ->
        Logs.debug (fun m -> m "%s : NOOP : COMMENT_FROM_SELF" request_id);
        Abbs_fc.return_ok ()
    | E.Merge_request_comment_event
        {
          Mrce.project = { Pr.id = repo_id; path_with_namespace; _ };
          object_attributes =
            { Mrceoa.action = Some `Create; id = Some comment_id; note = Some comment_body; _ };
          user = { User.username; _ };
          merge_request = { Mr.iid = Some pull_request_id; _ };
          _;
        } -> (
        let owner, name = parse_path_with_namespace path_with_namespace in
        let account = P.Api.Account.make installation_id in
        let repo = P.Api.Repo.make ~id:repo_id ~name ~owner () in
        let user = P.Api.User.make username in
        match Terrat_comment.parse comment_body with
        | Ok comment ->
            Logs.info (fun m ->
                m
                  "%s : COMMENT_CREATED_EVENT : owner=%s : repo=%s : pull_number=%d : sender=%s : \
                   body=%s"
                  request_id
                  owner
                  name
                  pull_request_id
                  username
                  comment_body);
            Evaluator2.pull_request_event
              ~request_id
              ~config
              ~storage
              ~exec
              ~account
              ~repo
              ~pull_request_id
              ~user
              (Evaluator2.Pull_request_event.Comment { comment_id; comment })
        | Error _ -> Abbs_fc.return_ok ())
    | E.Merge_request_comment_event _ -> Abbs_fc.return_ok ()
    | E.Merge_request_event
        {
          Mre.project = { Pr.id = repo_id; path_with_namespace; _ };
          user = { User.username; _ };
          object_attributes = { Mreoa.action; iid = pull_request_id; _ };
          _;
        } -> (
        let owner, name = parse_path_with_namespace path_with_namespace in
        let account = P.Api.Account.make installation_id in
        let repo = P.Api.Repo.make ~id:repo_id ~name ~owner () in
        let user = P.Api.User.make username in
        match action with
        | `Open | `Reopen ->
            Logs.info (fun m ->
                m
                  "%s : PULL_REQUEST_EVENT : OPEN : owner=%s : repo=%s : pull_number=%d : sender=%s"
                  request_id
                  owner
                  name
                  pull_request_id
                  username);
            Evaluator2.pull_request_event
              ~request_id
              ~config
              ~storage
              ~exec
              ~account
              ~repo
              ~pull_request_id
              ~user
              Evaluator2.Pull_request_event.Open
        | `Update ->
            Logs.info (fun m ->
                m
                  "%s : PULL_REQUEST_EVENT : SYNC : owner=%s : repo=%s : pull_number=%d : sender=%s"
                  request_id
                  owner
                  name
                  pull_request_id
                  username);
            Evaluator2.pull_request_event
              ~request_id
              ~config
              ~storage
              ~exec
              ~account
              ~repo
              ~pull_request_id
              ~user
              Evaluator2.Pull_request_event.Sync
        | `Merge | `Close ->
            Logs.info (fun m ->
                m
                  "%s : PULL_REQUEST_EVENT : CLOSE : owner=%s : repo=%s : pull_number=%d : \
                   sender=%s"
                  request_id
                  owner
                  name
                  pull_request_id
                  username);
            Evaluator2.pull_request_event
              ~request_id
              ~config
              ~storage
              ~exec
              ~account
              ~repo
              ~pull_request_id
              ~user
              Evaluator2.Pull_request_event.Close
        | _ -> raise (Failure "nyi"))
    | E.Pipeline_event _ -> Abbs_fc.return_ok ()
    (* A canceled job posts no result either, so it leaves the same dead work
       manifest behind as a failed one. *)
    | E.Job_event
        {
          Je.build_id = run_id;
          build_status = "canceled" | "failed";
          project = { Pr.id = repo_id; path_with_namespace; _ };
          _;
        } ->
        let owner, name = parse_path_with_namespace path_with_namespace in
        let account = P.Api.Account.make installation_id in
        let repo = P.Api.Repo.make ~id:repo_id ~name ~owner () in
        Evaluator2.work_manifest_job_failed
          ~request_id
          ~config
          ~storage
          ~exec
          ~account
          ~repo
          ~run_id:(CCInt.to_string run_id)
          ()
    | E.Job_event _ -> Abbs_fc.return_ok ()

  let post' config storage exec webhook_secret ctx =
    let open Abbs_fc.Infix_result_monad in
    Pgsql_pool.with_conn storage ~f:(fun db ->
        Pgsql_io.Prepared_stmt.fetch
          db
          (Sql.select_installation_by_webhook_secret ())
          ~f:(fun id state -> (id, state))
          webhook_secret)
    >>= function
    | [] -> Abbs_fc.return_err `Installation_not_found
    | (installation_id, "pending") :: _ ->
        Logs.info (fun m ->
            m "%s : EVENT : PING : installation_id=%Ld" (Brtl_ctx.token ctx) installation_id);
        Pgsql_pool.with_conn storage ~f:(fun db ->
            Pgsql_io.Prepared_stmt.execute
              db
              (Sql.update_installation_to_installed ())
              installation_id)
        >>= fun () ->
        Abb.Future.return @@ decode ctx
        >>= fun event ->
        (* We insert the repository here so that during onboarding we can verify
           to the user that the webhook was successfully received *)
        upsert_installation_repo config storage installation_id event
    | (installation_id, _) :: _ ->
        Abb.Future.return @@ decode ctx
        >>= fun event ->
        dispatch_event
          (Brtl_ctx.token ctx)
          config
          storage
          exec
          (CCInt64.to_int installation_id)
          event

  let post config storage exec =
    Brtl_ep.run_json ~f:(fun ctx ->
        let headers = Brtl_ctx.Request.headers @@ Brtl_ctx.request ctx in
        Metrics.DefaultHistogram.time Metrics.events_duration_seconds (fun () ->
            Prmths.Gauge.track_inprogress Metrics.events_concurrent (fun () ->
                match Cohttp.Header.get headers "x-gitlab-token" with
                | Some webhook_secret -> (
                    let open Abb.Future.Infix_monad in
                    post' config storage exec webhook_secret ctx
                    >>= function
                    | Ok () ->
                        Abb.Future.return
                          (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`OK "") ctx)
                    | Error `Error ->
                        Logs.err (fun m -> m "");
                        Abb.Future.return
                          (Brtl_ctx.set_response
                             (Brtl_rspnc.create ~status:`Internal_server_error "")
                             ctx)
                    | Error (#Gitlab_webhooks_decoder.err as err) ->
                        Logs.err (fun m -> m "%a" Gitlab_webhooks_decoder.pp_err err);
                        Abb.Future.return
                          (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`OK "") ctx)
                    | Error `Installation_not_found ->
                        Logs.err (fun m -> m "INSTALLATION_NOT_FOUND");
                        Abb.Future.return
                          (Brtl_ctx.set_response
                             (Brtl_rspnc.create ~status:`Internal_server_error "")
                             ctx)
                    | Error (#Pgsql_pool.err as err) ->
                        Logs.err (fun m -> m "%a" Pgsql_pool.pp_err err);
                        Abb.Future.return
                          (Brtl_ctx.set_response
                             (Brtl_rspnc.create ~status:`Internal_server_error "")
                             ctx)
                    | Error (#Pgsql_io.err as err) ->
                        Logs.err (fun m -> m "%a" Pgsql_io.pp_err err);
                        Abb.Future.return
                          (Brtl_ctx.set_response
                             (Brtl_rspnc.create ~status:`Internal_server_error "")
                             ctx))
                | None ->
                    Logs.info (fun m -> m "MISSING_TOKEN_HEADER");
                    Abb.Future.return
                      (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Bad_request "") ctx))))
end
