let src = Logs.Src.create "vcs_service_github_ep_events"

module Logs = (val Logs.src_log src : Logs.LOG)

module Metrics = struct
  module DefaultHistogram = Prmths.Histogram (struct
    let spec = Prmths.Histogram_spec.of_list [ 0.005; 0.5; 1.0; 5.0; 10.0; 15.0; 20.0 ]
  end)

  let namespace = "terrat"
  let subsystem = "ep_github_events"

  let events_duration_seconds =
    let help = "Number of seconds that handling an incoming event takes" in
    DefaultHistogram.v ~help ~namespace ~subsystem "events_duration_seconds"

  let events_total_family =
    let help = "Number of events that the system has received" in
    Prmths.Counter.v_labels
      ~label_names:[ "type"; "action" ]
      ~help
      ~namespace
      ~subsystem
      "events_total"

  let comment_events_total action = Prmths.Counter.labels events_total_family [ "comment"; action ]
  let pr_events_total action = Prmths.Counter.labels events_total_family [ "pr"; action ]

  let installation_events_total typ =
    Prmths.Counter.labels events_total_family [ "installation"; typ ]

  let events_concurrent =
    let help = "Number of events being handled right now" in
    Prmths.Gauge.v ~help ~namespace ~subsystem "events_concurrent"

  let pgsql_pool_errors_total = Terrat_metrics.errors_total ~m:"ep_github_events" ~t:"pgsql_pool"
  let pgsql_errors_total = Terrat_metrics.errors_total ~m:"ep_github_events" ~t:"pgsql"
  let github_errors_total = Terrat_metrics.errors_total ~m:"ep_github_events" ~t:"github"

  let github_webhook_decode_errors_total =
    Terrat_metrics.errors_total ~m:"ep_github_events" ~t:"github_webhook_decode"
end

module Make (P : Terrat_vcs_provider2_github.S) = struct
  (* module Evaluator = Terrat_vcs_event_evaluator.Make (P) *)
  module Evaluator2 = Terrat_vcs_event_evaluator2.Make (P)
  module Gw = Terrat_github_webhooks

  module Sql = struct
    let read s = Pgsql_io.clean_string s

    let insert_github_installation =
      Pgsql_io.Typed_sql.(
        sql
        /^ read [%blob "sql/insert_installation.sql"]
        /% Var.bigint "id"
        /% Var.text "login"
        /% Var.uuid "org"
        /% Var.text "target_type"
        /% Var.text "tier"
        /% Var.text "installed_by")

    let update_github_installation_unsuspend =
      Pgsql_io.Typed_sql.(
        sql
        /^ "update github_installations set state = 'installed', last_unsuspended_at = now(), \
            last_unsuspended_by = $unsuspended_by where id = $id"
        /% Var.bigint "id"
        /% Var.text "unsuspended_by")

    let update_github_installation_uninstall =
      Pgsql_io.Typed_sql.(
        sql
        /^ "update github_installations set state = 'uninstalled', uninstalled_at = now(), \
            uninstalled_by = $uninstalled_by where id = $id"
        /% Var.bigint "id"
        /% Var.text "uninstalled_by")

    let update_github_installation_suspended =
      Pgsql_io.Typed_sql.(
        sql
        /^ "update github_installations set state = 'suspended', last_suspended_at = now(), \
            last_suspended_by = $suspended_by where id = $id"
        /% Var.bigint "id"
        /% Var.text "suspended_by")

    let insert_org =
      Pgsql_io.Typed_sql.(
        sql
        //
        (* id *)
        Ret.uuid
        /^ read [%blob "sql/insert_org.sql"]
        /% Var.text "name")

    let select_github_installation =
      Pgsql_io.Typed_sql.(
        sql
        //
        (* id *)
        Ret.bigint
        /^ "select id from github_installations where id = $id"
        /% Var.bigint "id")
  end

  module Tmpl = struct
    let read =
      Terrat_brand.branded (fun s ->
          s
          |> Snabela.Template.of_utf8_string
          |> CCResult.get_exn
          |> fun tmpl -> Snabela.of_template tmpl [])

    let terrateam_comment_tag_query_error =
      read [%blob "tmpl/terrateam_comment_tag_query_error.tmpl"]
  end

  let target_of_user_type = function
    | `Organization -> "Organization"
    | `User -> "User"
    | `Bot -> "Bot"

  (* Reports whether a row had to be created.  [with_installation_recovery]
     needs that answer, not just success: an installation that was there all
     along is not the failure the retry exists for. *)
  let insert_installation_if_missing config storage ~installation_id ~login ~target_type ~sender =
    let open Abbs_future_combinators.Infix_result_monad in
    Pgsql_pool.with_conn storage ~f:(fun db ->
        Pgsql_io.Prepared_stmt.fetch
          db
          Sql.select_github_installation
          ~f:CCFun.id
          (CCInt64.of_int installation_id)
        >>= function
        | [] -> (
            Pgsql_io.Prepared_stmt.fetch db Sql.insert_org ~f:CCFun.id login
            >>= function
            | org_id :: _ ->
                Pgsql_io.Prepared_stmt.execute
                  db
                  Sql.insert_github_installation
                  (Int64.of_int installation_id)
                  login
                  org_id
                  target_type
                  (Terrat_config.default_tier @@ P.Api.Config.config config)
                  sender
                >>= fun () -> Abbs_future_combinators.return_ok `Inserted
            | [] -> assert false)
        | _ :: _ -> Abbs_future_combinators.return_ok `Present)

  (* An event that names an installation this system never recorded fails on the
     missing row, so the row is written and the event evaluated again.  That
     retry is right for that one failure and for no other: [f] is not
     idempotent.  It creates a job, dispatches work manifests and comments on
     the pull request, so an evaluation that fails after it has already spoken
     says the same thing a second time when it is run again -- which is how one
     [terrateam apply] becomes two identical "Missing Plans" comments.  Retry
     only when a row was in fact missing, and give the caller the original
     error otherwise. *)
  let with_installation_recovery config storage ~installation_id ~login ~target_type ~sender f =
    let open Abb.Future.Infix_monad in
    f ()
    >>= function
    | Ok _ as ok -> Abb.Future.return ok
    | Error _ as event_err -> (
        Logs.info (fun m ->
            m "MISSING_INSTALLATION : CHECKING : installation_id=%d" installation_id);
        insert_installation_if_missing config storage ~installation_id ~login ~target_type ~sender
        >>= function
        | Ok `Inserted -> f ()
        | Ok `Present -> Abb.Future.return event_err
        | Error _ as err -> Abb.Future.return err)

  let process_installation _request_id config storage = function
    | Gw.Installation_event.Installation_created created ->
        let open Abbs_future_combinators.Infix_result_monad in
        Prmths.Counter.inc_one (Metrics.installation_events_total "created");
        let installation = created.Gw.Installation_created.installation in
        Logs.info (fun m ->
            m
              "INSTALLATION : CREATE :  account=%d : org=%s : sender=%s"
              installation.Gw.Installation.id
              installation.Gw.Installation.account.Gw.User.login
              created.Gw.Installation_created.sender.Gw.User.login);
        Pgsql_pool.with_conn storage ~f:(fun db ->
            Pgsql_io.Prepared_stmt.fetch
              db
              Sql.select_github_installation
              ~f:CCFun.id
              (CCInt64.of_int installation.Gw.Installation.id)
            >>= function
            | [] -> (
                Pgsql_io.Prepared_stmt.fetch
                  db
                  Sql.insert_org
                  ~f:CCFun.id
                  installation.Gw.Installation.account.Gw.User.login
                >>= function
                | org_id :: _ ->
                    Pgsql_io.Prepared_stmt.execute
                      db
                      Sql.insert_github_installation
                      (Int64.of_int installation.Gw.Installation.id)
                      installation.Gw.Installation.account.Gw.User.login
                      org_id
                      (target_of_user_type installation.Gw.Installation.account.Gw.User.type_)
                      (Terrat_config.default_tier @@ P.Api.Config.config config)
                      created.Gw.Installation_created.sender.Gw.User.login
                | [] -> assert false)
            | _ :: _ -> Abbs_future_combinators.return_ok ())
    | Gw.Installation_event.Installation_deleted deleted ->
        let installation = deleted.Gw.Installation_deleted.installation in
        Logs.info (fun m ->
            m
              "INSTALLATION : UNINSTALL : account=%d : org=%s : sender=%s"
              installation.Gw.Installation.id
              installation.Gw.Installation.account.Gw.User.login
              deleted.Gw.Installation_deleted.sender.Gw.User.login);
        Prmths.Counter.inc_one (Metrics.installation_events_total "deleted");
        Pgsql_pool.with_conn storage ~f:(fun db ->
            Pgsql_io.Prepared_stmt.execute
              db
              Sql.update_github_installation_uninstall
              (Int64.of_int installation.Gw.Installation.id)
              deleted.Gw.Installation_deleted.sender.Gw.User.login)
    | Gw.Installation_event.Installation_new_permissions_accepted installation_event ->
        Prmths.Counter.inc_one (Metrics.installation_events_total "new_permissions_accepted");
        let installation =
          installation_event.Gw.Installation_new_permissions_accepted.installation
        in
        Logs.info (fun m ->
            m
              "INSTALLATION : ACCEPTED_PERMISSIONS : account=%d : org=%s : sender=%s"
              installation.Gw.Installation.id
              installation.Gw.Installation.account.Gw.User.login
              installation_event.Gw.Installation_new_permissions_accepted.sender.Gw.User.login);
        Abbs_future_combinators.return_ok ()
    | Gw.Installation_event.Installation_suspend suspended ->
        let installation = suspended.Gw.Installation_suspend.installation in
        let module I = Gw.Installation_suspend.Installation_ in
        Logs.info (fun m ->
            m
              "INSTALLATION : SUSPENDED : account=%d : org=%s : sender=%s"
              installation.I.T.primary.I.T.Primary.id
              installation.I.T.primary.I.T.Primary.account.Gw.User.login
              suspended.Gw.Installation_suspend.sender.Gw.User.login);
        Prmths.Counter.inc_one (Metrics.installation_events_total "suspended");
        Pgsql_pool.with_conn storage ~f:(fun db ->
            Pgsql_io.Prepared_stmt.execute
              db
              Sql.update_github_installation_suspended
              (Int64.of_int installation.I.T.primary.I.T.Primary.id)
              suspended.Gw.Installation_suspend.sender.Gw.User.login)
    | Gw.Installation_event.Installation_unsuspend unsuspend ->
        let installation = unsuspend.Gw.Installation_unsuspend.installation in
        let module I = Gw.Installation_unsuspend.Installation_ in
        Logs.info (fun m ->
            m
              "INSTALLATION : UNSUSPENDED : account-%d : org=%s : sender=%s"
              installation.I.T.primary.I.T.Primary.id
              installation.I.T.primary.I.T.Primary.account.Gw.User.login
              unsuspend.Gw.Installation_unsuspend.sender.Gw.User.login);
        Prmths.Counter.inc_one (Metrics.installation_events_total "unsuspended");
        Pgsql_pool.with_conn storage ~f:(fun db ->
            Pgsql_io.Prepared_stmt.execute
              db
              Sql.update_github_installation_unsuspend
              (Int64.of_int installation.I.T.primary.I.T.Primary.id)
              unsuspend.Gw.Installation_unsuspend.sender.Gw.User.login)

  let process_pull_request_event request_id config storage exec = function
    | Gw.Pull_request_event.Pull_request_opened
        {
          Gw.Pull_request_opened.installation =
            Some { Gw.Installation_lite.id = installation_id; _ };
          pull_request =
            Gw.Pull_request_opened.Pull_request_.T.
              { primary = Primary.{ number = pull_request_id; _ }; _ };
          repository;
          sender;
          _;
        } ->
        Prmths.Counter.inc_one (Metrics.pr_events_total "open");
        Logs.info (fun m ->
            m
              "%s : PULL_REQUEST_EVENT : OPEN : owner=%s : repo=%s : pull_number=%d : sender=%s"
              request_id
              repository.Gw.Repository.owner.Gw.User.login
              repository.Gw.Repository.name
              pull_request_id
              sender.Gw.User.login);
        let account = P.Api.Account.make installation_id in
        let user = P.Api.User.make sender.Gw.User.login in
        let repo =
          P.Api.Repo.make
            ~id:repository.Gw.Repository.id
            ~name:repository.Gw.Repository.name
            ~owner:repository.Gw.Repository.owner.Gw.User.login
            ()
        in
        with_installation_recovery
          config
          storage
          ~installation_id
          ~login:repository.Gw.Repository.owner.Gw.User.login
          ~target_type:(target_of_user_type repository.Gw.Repository.owner.Gw.User.type_)
          ~sender:sender.Gw.User.login
          (fun () ->
            Evaluator2.pull_request_event
              ~request_id
              ~config
              ~storage
              ~exec
              ~account
              ~repo
              ~pull_request_id
              ~user
              Evaluator2.Pull_request_event.Open)
    | Gw.Pull_request_event.Pull_request_synchronize
        {
          Gw.Pull_request_synchronize.installation =
            Some { Gw.Installation_lite.id = installation_id; _ };
          repository;
          pull_request = Gw.Pull_request.{ number = pull_request_id; _ };
          sender;
          _;
        } ->
        Prmths.Counter.inc_one (Metrics.pr_events_total "sync");
        Logs.info (fun m ->
            m
              "%s : PULL_REQUEST_EVENT : SYNC : owner=%s : repo=%s : pull_number=%d : sender=%s"
              request_id
              repository.Gw.Repository.owner.Gw.User.login
              repository.Gw.Repository.name
              pull_request_id
              sender.Gw.User.login);
        let account = P.Api.Account.make installation_id in
        let user = P.Api.User.make sender.Gw.User.login in
        let repo =
          P.Api.Repo.make
            ~id:repository.Gw.Repository.id
            ~name:repository.Gw.Repository.name
            ~owner:repository.Gw.Repository.owner.Gw.User.login
            ()
        in
        with_installation_recovery
          config
          storage
          ~installation_id
          ~login:repository.Gw.Repository.owner.Gw.User.login
          ~target_type:(target_of_user_type repository.Gw.Repository.owner.Gw.User.type_)
          ~sender:sender.Gw.User.login
          (fun () ->
            Evaluator2.pull_request_event
              ~request_id
              ~config
              ~storage
              ~exec
              ~account
              ~repo
              ~pull_request_id
              ~user
              Evaluator2.Pull_request_event.Sync)
    | Gw.Pull_request_event.Pull_request_reopened
        {
          Gw.Pull_request_reopened.installation =
            Some { Gw.Installation_lite.id = installation_id; _ };
          repository;
          pull_request =
            Gw.Pull_request_reopened.Pull_request_.T.
              { primary = Primary.{ number = pull_request_id; _ }; _ };
          sender;
          _;
        } ->
        Prmths.Counter.inc_one (Metrics.pr_events_total "reopen");
        Logs.info (fun m ->
            m
              "%s : PULL_REQUEST_EVENT : REOPEN : owner=%s : repo=%s : pull_number=%d : sender=%s"
              request_id
              repository.Gw.Repository.owner.Gw.User.login
              repository.Gw.Repository.name
              pull_request_id
              sender.Gw.User.login);
        let account = P.Api.Account.make installation_id in
        let user = P.Api.User.make sender.Gw.User.login in
        let repo =
          P.Api.Repo.make
            ~id:repository.Gw.Repository.id
            ~name:repository.Gw.Repository.name
            ~owner:repository.Gw.Repository.owner.Gw.User.login
            ()
        in
        with_installation_recovery
          config
          storage
          ~installation_id
          ~login:repository.Gw.Repository.owner.Gw.User.login
          ~target_type:(target_of_user_type repository.Gw.Repository.owner.Gw.User.type_)
          ~sender:sender.Gw.User.login
          (fun () ->
            Evaluator2.pull_request_event
              ~request_id
              ~config
              ~storage
              ~exec
              ~account
              ~repo
              ~pull_request_id
              ~user
              Evaluator2.Pull_request_event.Open)
    | Gw.Pull_request_event.Pull_request_ready_for_review
        {
          Gw.Pull_request_ready_for_review.installation =
            Some { Gw.Installation_lite.id = installation_id; _ };
          repository;
          pull_request =
            Gw.Pull_request_ready_for_review.Pull_request_.T.
              { primary = Primary.{ number = pull_request_id; _ }; _ };
          sender;
          _;
        } ->
        Prmths.Counter.inc_one (Metrics.pr_events_total "ready_for_review");
        Logs.info (fun m ->
            m
              "%s : PULL_REQUEST_EVENT : READY_FOR_REVIEW : owner=%s : repo=%s : pull_number=%d : \
               sender=%s"
              request_id
              repository.Gw.Repository.owner.Gw.User.login
              repository.Gw.Repository.name
              pull_request_id
              sender.Gw.User.login);
        let account = P.Api.Account.make installation_id in
        let user = P.Api.User.make sender.Gw.User.login in
        let repo =
          P.Api.Repo.make
            ~id:repository.Gw.Repository.id
            ~name:repository.Gw.Repository.name
            ~owner:repository.Gw.Repository.owner.Gw.User.login
            ()
        in
        with_installation_recovery
          config
          storage
          ~installation_id
          ~login:repository.Gw.Repository.owner.Gw.User.login
          ~target_type:(target_of_user_type repository.Gw.Repository.owner.Gw.User.type_)
          ~sender:sender.Gw.User.login
          (fun () ->
            Evaluator2.pull_request_event
              ~request_id
              ~config
              ~storage
              ~exec
              ~account
              ~repo
              ~pull_request_id
              ~user
              Evaluator2.Pull_request_event.Ready_for_review)
    | Gw.Pull_request_event.Pull_request_opened _ -> failwith "Invalid pull_request_open event"
    | Gw.Pull_request_event.Pull_request_synchronize _ ->
        failwith "Invalid pull_request_synchronize event"
    | Gw.Pull_request_event.Pull_request_reopened _ ->
        failwith "Invalid pull_request_reopened event"
    | Gw.Pull_request_event.Pull_request_closed
        {
          Gw.Pull_request_closed.installation =
            Some { Gw.Installation_lite.id = installation_id; _ };
          pull_request =
            Gw.Pull_request_closed.Pull_request_.T.
              { primary = Primary.{ number = pull_request_id; _ }; _ };
          repository;
          sender;
          _;
        } ->
        Prmths.Counter.inc_one (Metrics.pr_events_total "close");
        Logs.info (fun m ->
            m
              "%s : PULL_REQUEST_EVENT : CLOSE : owner=%s : repo=%s : pull_number=%d : sender=%s"
              request_id
              repository.Gw.Repository.owner.Gw.User.login
              repository.Gw.Repository.name
              pull_request_id
              sender.Gw.User.login);
        let account = P.Api.Account.make installation_id in
        let user = P.Api.User.make sender.Gw.User.login in
        let repo =
          P.Api.Repo.make
            ~id:repository.Gw.Repository.id
            ~name:repository.Gw.Repository.name
            ~owner:repository.Gw.Repository.owner.Gw.User.login
            ()
        in
        (* Should we have a "closed" job type or reuse autoplan which does
           nothing on close? *)
        with_installation_recovery
          config
          storage
          ~installation_id
          ~login:repository.Gw.Repository.owner.Gw.User.login
          ~target_type:(target_of_user_type repository.Gw.Repository.owner.Gw.User.type_)
          ~sender:sender.Gw.User.login
          (fun () ->
            Evaluator2.pull_request_event
              ~request_id
              ~config
              ~storage
              ~exec
              ~account
              ~repo
              ~pull_request_id
              ~user
              Evaluator2.Pull_request_event.Close)
    | Gw.Pull_request_event.Pull_request_closed _ -> failwith "Invalid pull_request_closed event"
    | Gw.Pull_request_event.Pull_request_assigned _ ->
        Logs.debug (fun m -> m "%s : NOOP : PULL_REQUEST_ASSIGNED" request_id);
        Abbs_future_combinators.return_ok ()
    | Gw.Pull_request_event.Pull_request_auto_merge_disabled _ ->
        Logs.debug (fun m -> m "%s : NOOP : PULL_REQUEST_AUTO_MERGE_DISABLED" request_id);
        Abbs_future_combinators.return_ok ()
    | Gw.Pull_request_event.Pull_request_auto_merge_enabled _ ->
        Logs.debug (fun m -> m "%s : NOOP : PULL_REQUEST_AUTO_MERGE_ENABLED" request_id);
        Abbs_future_combinators.return_ok ()
    | Gw.Pull_request_event.Pull_request_converted_to_draft _ ->
        Logs.debug (fun m -> m "%s : NOOP : PULL_REQUEST_CONVERTED_TO_DRAFT" request_id);
        Abbs_future_combinators.return_ok ()
    | Gw.Pull_request_event.Pull_request_edited
        {
          Gw.Pull_request_edited.installation =
            Some { Gw.Installation_lite.id = installation_id; _ };
          changes = Gw.Pull_request_edited.Changes.{ base = Some _; _ };
          number = pull_request_id;
          repository;
          sender;
          _;
        } ->
        (* The base branch moved.  GitHub does that on its own when the layer
           below this one in a stack merges, and it makes every plan of this
           pull request stale, the same as a change of the head does.  Thus this
           takes the same path as a synchronize. *)
        Prmths.Counter.inc_one (Metrics.pr_events_total "base_changed");
        Logs.info (fun m ->
            m
              "%s : PULL_REQUEST_EVENT : BASE_CHANGED : owner=%s : repo=%s : pull_number=%d : \
               sender=%s"
              request_id
              repository.Gw.Repository.owner.Gw.User.login
              repository.Gw.Repository.name
              pull_request_id
              sender.Gw.User.login);
        let account = P.Api.Account.make installation_id in
        let user = P.Api.User.make sender.Gw.User.login in
        let repo =
          P.Api.Repo.make
            ~id:repository.Gw.Repository.id
            ~name:repository.Gw.Repository.name
            ~owner:repository.Gw.Repository.owner.Gw.User.login
            ()
        in
        with_installation_recovery
          config
          storage
          ~installation_id
          ~login:repository.Gw.Repository.owner.Gw.User.login
          ~target_type:(target_of_user_type repository.Gw.Repository.owner.Gw.User.type_)
          ~sender:sender.Gw.User.login
          (fun () ->
            Evaluator2.pull_request_event
              ~request_id
              ~config
              ~storage
              ~exec
              ~account
              ~repo
              ~pull_request_id
              ~user
              Evaluator2.Pull_request_event.Sync)
    | Gw.Pull_request_event.Pull_request_edited _ ->
        Logs.debug (fun m -> m "%s : NOOP : PULL_REQUEST_EDITED" request_id);
        Abbs_future_combinators.return_ok ()
    | Gw.Pull_request_event.Pull_request_labeled _ ->
        Logs.debug (fun m -> m "%s : NOOP : PULL_REQUEST_LABELED" request_id);
        Abbs_future_combinators.return_ok ()
    | Gw.Pull_request_event.Pull_request_locked _ ->
        Logs.debug (fun m -> m "%s : NOOP : PULL_REQUEST_LOCKED" request_id);
        Abbs_future_combinators.return_ok ()
    | Gw.Pull_request_event.Pull_request_milestoned _ ->
        Logs.debug (fun m -> m "%s : NOOP : PULL_REQUEST_MILESTONED" request_id);
        Abbs_future_combinators.return_ok ()
    | Gw.Pull_request_event.Pull_request_ready_for_review _ ->
        Logs.debug (fun m -> m "%s : NOOP : PULL_REQUEST_READY_FOR_REVIEW" request_id);
        Abbs_future_combinators.return_ok ()
    | Gw.Pull_request_event.Pull_request_review_request_removed _ ->
        Logs.debug (fun m -> m "%s : NOOP : PULL_REQUEST_REVIEW_REQUEST_REMOVED" request_id);
        Abbs_future_combinators.return_ok ()
    | Gw.Pull_request_event.Pull_request_review_requested _ ->
        Logs.debug (fun m -> m "%s : NOOP : PULL_REQUEST_REVIEW_REQUESTED" request_id);
        Abbs_future_combinators.return_ok ()
    | Gw.Pull_request_event.Pull_request_stacked _ ->
        (* A pull request joined or left a stack.  Nothing to run: joining a stack
           moves the base branch and leaving one moves it back, and GitHub reports
           each of those as its own event.  The arm has to exist all the same,
           because an action no decoder knows fails the whole payload, which
           answers GitHub with a 500 and makes it deliver the event again. *)
        Logs.debug (fun m -> m "%s : NOOP : PULL_REQUEST_STACKED" request_id);
        Abbs_future_combinators.return_ok ()
    | Gw.Pull_request_event.Pull_request_unassigned _ ->
        Logs.debug (fun m -> m "%s : NOOP : PULL_REQUEST_UNASSIGNED" request_id);
        Abbs_future_combinators.return_ok ()
    | Gw.Pull_request_event.Pull_request_unlabeled _ ->
        Logs.debug (fun m -> m "%s : NOOP : PULL_REQUEST_UNLABELED" request_id);
        Abbs_future_combinators.return_ok ()
    | Gw.Pull_request_event.Pull_request_unlocked _ ->
        Logs.debug (fun m -> m "%s : NOOP : PULL_REQUEST_UNLOCKED" request_id);
        Abbs_future_combinators.return_ok ()
    | Gw.Pull_request_event.Pull_request_review_submitted _ ->
        Logs.debug (fun m -> m "%s : NOOP : PULL_REQUEST_REVIEW_SUBMITTED" request_id);
        Abbs_future_combinators.return_ok ()

  (* A reply that cannot learn the brand of its repository is not published.  The
     provider keeps the answer of a repository for a minute, so a burst of
     replies costs one lookup. *)
  let fetch_brand ~request_id config db ~installation_id repository =
    let open Abb.Future.Infix_monad in
    let account = P.Api.Account.make installation_id in
    let repo =
      P.Api.Repo.make
        ~id:repository.Gw.Repository.id
        ~name:repository.Gw.Repository.name
        ~owner:repository.Gw.Repository.owner.Gw.User.login
        ()
    in
    P.Api.create_client ~request_id config account db
    >>= function
    | Ok client -> (
        P.Repo_config.fetch_brand ~request_id client repo
        >>= function
        | Ok _ as r -> Abb.Future.return r
        | Error _ ->
            Logs.err (fun m -> m "%s : FETCH_BRAND : ERROR" request_id);
            Abbs_future_combinators.return_err `Error)
    | Error _ ->
        Logs.err (fun m -> m "%s : FETCH_BRAND : CREATE_CLIENT : ERROR" request_id);
        Abbs_future_combinators.return_err `Error

  let process_issue_comment request_id config storage exec = function
    | Gw.Issue_comment_event.Issue_comment_created
        { Gw.Issue_comment_created.comment = { Gw.Issue_comment.body = comment_body; _ }; _ }
      when Terrat_comment.is_from_self comment_body ->
        Logs.debug (fun m -> m "%s : NOOP : COMMENT_FROM_SELF" request_id);
        Prmths.Counter.inc_one (Metrics.comment_events_total "from_self");
        Abbs_future_combinators.return_ok ()
    | Gw.Issue_comment_event.Issue_comment_created
        {
          Gw.Issue_comment_created.installation =
            Some { Gw.Installation_lite.id = installation_id; _ };
          repository;
          comment = { Gw.Issue_comment.id = comment_id; body = comment_body; _ };
          issue =
            Gw.Issue_comment_created.Issue_.T.
              { primary = Primary.{ number = pull_request_id; pull_request = Some _; _ }; _ };
          sender;
          _;
        } -> (
        match Terrat_comment.parse comment_body with
        | Ok comment ->
            Logs.info (fun m ->
                m
                  "%s : COMMENT_CREATED_EVENT : owner=%s : repo=%s : pull_number=%d : sender=%s : \
                   body=%s"
                  request_id
                  repository.Gw.Repository.owner.Gw.User.login
                  repository.Gw.Repository.name
                  pull_request_id
                  sender.Gw.User.login
                  comment_body);
            let account = P.Api.Account.make installation_id in
            let user = P.Api.User.make sender.Gw.User.login in
            let repo =
              P.Api.Repo.make
                ~id:repository.Gw.Repository.id
                ~name:repository.Gw.Repository.name
                ~owner:repository.Gw.Repository.owner.Gw.User.login
                ()
            in
            with_installation_recovery
              config
              storage
              ~installation_id
              ~login:repository.Gw.Repository.owner.Gw.User.login
              ~target_type:(target_of_user_type repository.Gw.Repository.owner.Gw.User.type_)
              ~sender:sender.Gw.User.login
              (fun () ->
                Evaluator2.pull_request_event
                  ~request_id
                  ~config
                  ~storage
                  ~exec
                  ~account
                  ~repo
                  ~pull_request_id
                  ~user
                  (Evaluator2.Pull_request_event.Comment { comment_id; comment }))
        | Error `Not_terrateam ->
            Prmths.Counter.inc_one (Metrics.comment_events_total "not_terrateam");
            Abbs_future_combinators.return_ok ()
        | Error (`Tag_query_error (_, err)) -> (
            Prmths.Counter.inc_one (Metrics.comment_events_total "tag_query");
            let open Abbs_future_combinators.Infix_result_monad in
            Abbs_future_combinators.Result.all2
              (Pgsql_pool.with_conn storage ~f:(fun db ->
                   fetch_brand ~request_id config db ~installation_id repository))
              (Terrat_github.get_installation_access_token
                 (P.Api.Config.vcs_config config)
                 installation_id)
            >>= fun (brand, access_token) ->
            let kv = Snabela.Kv.(Map.of_list [ ("err", string err) ]) in
            match Snabela.apply (Tmpl.terrateam_comment_tag_query_error brand) kv with
            | Ok body ->
                Logs.info (fun m -> m "%s : COMMENT_ERROR : TAG_QUERY_ERROR : %s" request_id err);
                Abbs_future_combinators.Result.ignore
                @@ Terrat_github.with_client
                     (P.Api.Config.vcs_config config)
                     (`Token access_token)
                     (Terrat_github.publish_comment
                        ~owner:repository.Gw.Repository.owner.Gw.User.login
                        ~repo:repository.Gw.Repository.name
                        ~pull_number:pull_request_id
                        ~body:(Terrat_comment.add_self_marker body))
            | Error (#Snabela.err as err) ->
                Logs.err (fun m ->
                    m "%s : TMPL_ERROR : TAG_QUERY_ERROR : %s" request_id (Snabela.show_err err));
                Abbs_future_combinators.return_ok ())
        | Error (`Unknown_action action) ->
            Prmths.Counter.inc_one (Metrics.comment_events_total "unknown_action");
            let open Abbs_future_combinators.Infix_result_monad in
            Logs.info (fun m -> m "%s : COMMENT_ERROR : UNKNOWN_ACTION : %s" request_id action);
            Abbs_future_combinators.Result.all2
              (Pgsql_pool.with_conn storage ~f:(fun db ->
                   fetch_brand ~request_id config db ~installation_id repository))
              (Terrat_github.get_installation_access_token
                 (P.Api.Config.vcs_config config)
                 installation_id)
            >>= fun (brand, access_token) ->
            Abbs_future_combinators.Result.ignore
            @@ Terrat_github.with_client
                 (P.Api.Config.vcs_config config)
                 (`Token access_token)
                 (Terrat_github.publish_comment
                    ~owner:repository.Gw.Repository.owner.Gw.User.login
                    ~repo:repository.Gw.Repository.name
                    ~pull_number:pull_request_id
                    ~body:
                      (Terrat_comment.add_self_marker
                         (Terrat_vcs_github_comment_templates.Tmpl.terrateam_comment_unknown_action
                            brand))))
    | Gw.Issue_comment_event.Issue_comment_created _ ->
        Logs.debug (fun m -> m "%s : NOOP : ISSUE_COMMENT_CREATED" request_id);
        Prmths.Counter.inc_one (Metrics.comment_events_total "noop");
        Abbs_future_combinators.return_ok ()
    | Gw.Issue_comment_event.Issue_comment_deleted _ ->
        Logs.debug (fun m -> m "%s : NOOP : ISSUE_COMMENT_DELETED" request_id);
        Prmths.Counter.inc_one (Metrics.comment_events_total "noop");
        Abbs_future_combinators.return_ok ()
    | Gw.Issue_comment_event.Issue_comment_edited _ ->
        Logs.debug (fun m -> m "%s : NOOP : ISSUE_COMMENT_EDITED" request_id);
        Prmths.Counter.inc_one (Metrics.comment_events_total "noop");
        Abbs_future_combinators.return_ok ()
    | Gw.Issue_comment_event.Issue_any _ ->
        Logs.debug (fun m -> m "%s : NOOP : ISSUE" request_id);
        Prmths.Counter.inc_one (Metrics.comment_events_total "noop");
        Abbs_future_combinators.return_ok ()

  (* A job that ends in any of these posts no result, so its work manifest is
     dead and has to be ended.  A concurrency group, a user cancel and a queue
     timeout all report [cancelled], and none of them were heard at all while
     this only matched [failure]. *)
  let is_dead_conclusion = function
    | "cancelled" | "failure" | "stale" | "timed_out" -> true
    | _ -> false

  let process_workflow_job request_id config storage exec event =
    match event with
    | {
     Gw.Workflow_job_event.installation = Some { Gw.Installation_lite.id = installation_id; _ };
     repository;
     workflow_job = { Gw.Workflow_job.run_id; conclusion = Some conclusion; _ };
     sender;
     _;
    }
      when is_dead_conclusion conclusion ->
        Logs.info (fun m ->
            m
              "%s : WORKFLOW_JOB_EVENT : FAILURE : owner = %s : repo = %s : run_id = %d : \
               conclusion = %s"
              request_id
              repository.Gw.Repository.owner.Gw.User.login
              repository.Gw.Repository.name
              run_id
              conclusion);
        let account = P.Api.Account.make installation_id in
        let repo =
          P.Api.Repo.make
            ~id:repository.Gw.Repository.id
            ~name:repository.Gw.Repository.name
            ~owner:repository.Gw.Repository.owner.Gw.User.login
            ()
        in
        with_installation_recovery
          config
          storage
          ~installation_id
          ~login:repository.Gw.Repository.owner.Gw.User.login
          ~target_type:(target_of_user_type repository.Gw.Repository.owner.Gw.User.type_)
          ~sender:sender.Gw.User.login
          (fun () ->
            Evaluator2.work_manifest_job_failed
              ~request_id
              ~config
              ~storage
              ~exec
              ~account
              ~repo
              ~run_id:(CCInt.to_string run_id)
              ())
    | _ -> Abbs_future_combinators.return_ok ()

  let process_push_event request_id config storage exec event =
    let repository = event.Gw.Push_event.repository in
    let default_branch = repository.Gw.Repository.default_branch in
    let ref_ = event.Gw.Push_event.ref_ in
    let default_ref = "refs/heads/" ^ default_branch in
    match event.Gw.Push_event.installation with
    | Some installation_lite when CCString.equal ref_ default_ref ->
        Logs.info (fun m ->
            m
              "%s : PUSH_EVENT : owner=%s : repo=%s : sender=%s"
              request_id
              repository.Gw.Repository.owner.Gw.User.login
              repository.Gw.Repository.name
              event.Gw.Push_event.sender.Gw.User.login);
        let installation_id = installation_lite.Gw.Installation_lite.id in
        let account = P.Api.Account.make installation_id in
        let repo =
          P.Api.Repo.make
            ~id:repository.Gw.Repository.id
            ~name:repository.Gw.Repository.name
            ~owner:repository.Gw.Repository.owner.Gw.User.login
            ()
        in
        let user = P.Api.User.make event.Gw.Push_event.sender.Gw.User.login in
        with_installation_recovery
          config
          storage
          ~installation_id
          ~login:repository.Gw.Repository.owner.Gw.User.login
          ~target_type:(target_of_user_type repository.Gw.Repository.owner.Gw.User.type_)
          ~sender:event.Gw.Push_event.sender.Gw.User.login
          (fun () ->
            Evaluator2.push
              ~request_id
              ~config
              ~storage
              ~exec
              ~account
              ~repo
              ~branch:(P.Api.Ref.of_string default_branch)
              ~user
              ())
    | Some _ | None ->
        Logs.debug (fun m -> m "%s : PUSH_EVENT : NOOP" request_id);
        Abbs_future_combinators.return_ok ()

  let handle_error ctx = function
    | #Pgsql_pool.err as err ->
        Prmths.Counter.inc_one Metrics.pgsql_pool_errors_total;
        Logs.err (fun m -> m "%s : ERROR : %a" (Brtl_ctx.token ctx) Pgsql_pool.pp_err err);
        Abb.Future.return
          (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Internal_server_error "") ctx)
    | #Pgsql_io.err as err ->
        Prmths.Counter.inc_one Metrics.pgsql_errors_total;
        Logs.err (fun m -> m "%s : ERROR : %a" (Brtl_ctx.token ctx) Pgsql_io.pp_err err);
        Abb.Future.return
          (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Internal_server_error "") ctx)
    | #Githubc2_abb.call_err as err ->
        Prmths.Counter.inc_one Metrics.github_errors_total;
        Logs.err (fun m -> m "%s : ERROR : %a" (Brtl_ctx.token ctx) Githubc2_abb.pp_call_err err);
        Abb.Future.return
          (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Internal_server_error "") ctx)
    | #Terrat_github.publish_comment_err as err ->
        Prmths.Counter.inc_one Metrics.github_errors_total;
        Logs.err (fun m ->
            m "%s : ERROR : %a" (Brtl_ctx.token ctx) Terrat_github.pp_publish_comment_err err);
        Abb.Future.return
          (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Internal_server_error "") ctx)
    | #Terrat_github.get_installation_access_token_err as err ->
        Prmths.Counter.inc_one Metrics.github_errors_total;
        Logs.err (fun m ->
            m
              "%s : ERROR : %a"
              (Brtl_ctx.token ctx)
              Terrat_github.pp_get_installation_access_token_err
              err);
        Abb.Future.return
          (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Internal_server_error "") ctx)
    | `Error ->
        Abb.Future.return
          (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Internal_server_error "") ctx)

  let process_event_handler _config _storage ctx f =
    let open Abb.Future.Infix_monad in
    f ()
    >>= function
    | Ok () -> Abb.Future.return (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`OK "") ctx)
    | Error err -> handle_error ctx err

  let post config storage exec =
    Brtl_ep.run_json ~f:(fun ctx ->
        let request = Brtl_ctx.request ctx in
        let headers = Brtl_ctx.Request.headers request in
        let body = Brtl_ctx.body ctx in
        Metrics.DefaultHistogram.time Metrics.events_duration_seconds (fun () ->
            Prmths.Gauge.track_inprogress Metrics.events_concurrent (fun () ->
                match
                  Terrat_github_webhooks_decoder.run
                    ?secret:(Terrat_config.Github.webhook_secret @@ P.Api.Config.vcs_config config)
                    headers
                    body
                with
                | Ok (Gw.Event.Installation_event installation_event) ->
                    process_event_handler config storage ctx (fun () ->
                        process_installation (Brtl_ctx.token ctx) config storage installation_event)
                | Ok (Gw.Event.Pull_request_event pull_request_event) ->
                    process_event_handler config storage ctx (fun () ->
                        process_pull_request_event
                          (Brtl_ctx.token ctx)
                          config
                          storage
                          exec
                          pull_request_event)
                | Ok (Gw.Event.Issue_comment_event event) ->
                    process_event_handler config storage ctx (fun () ->
                        process_issue_comment (Brtl_ctx.token ctx) config storage exec event)
                | Ok (Gw.Event.Workflow_job_event event) ->
                    process_event_handler config storage ctx (fun () ->
                        process_workflow_job (Brtl_ctx.token ctx) config storage exec event)
                | Ok (Gw.Event.Push_event event) ->
                    process_event_handler config storage ctx (fun () ->
                        process_push_event (Brtl_ctx.token ctx) config storage exec event)
                | Ok (Gw.Event.Workflow_run_event _) ->
                    Logs.debug (fun m -> m "%s : NOOP : WORKFLOW_RUN_EVENT" (Brtl_ctx.token ctx));
                    Abb.Future.return (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`OK "") ctx)
                | Ok (Gw.Event.Installation_repositories_event _)
                | Ok (Gw.Event.Workflow_dispatch_event _) ->
                    Logs.debug (fun m ->
                        m "%s : NOOP : INSTALLATION_REPOSITORIES_EVENT" (Brtl_ctx.token ctx));
                    Abb.Future.return (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`OK "") ctx)
                | Error (#Terrat_github_webhooks_decoder.err as err) ->
                    Prmths.Counter.inc_one Metrics.github_webhook_decode_errors_total;
                    Logs.warn (fun m ->
                        m
                          "%s : UNKNOWN_EVENT : %s"
                          (Brtl_ctx.token ctx)
                          (Terrat_github_webhooks_decoder.show_err err));
                    Abb.Future.return
                      (Brtl_ctx.set_response
                         (Brtl_rspnc.create ~status:`Internal_server_error "")
                         ctx))))
end
