module Batch = Terrat_vcs_event_evaluator2_batch
module Ee2_fc = Terrat_vcs_event_evaluator2_fc
module Fc = Abbs_future_combinators
module Irm = Fc.Infix_result_monad
module Tjc = Terrat_job_context
module Exec = Abb_bounded_suspendable_executor.Make (Abb) (CCString)

module Queue_time_histogram = Prmths.Histogram (struct
  let spec = Prmths.Histogram_spec.of_list [ 0.01; 0.1; 0.25; 0.5; 1.0; 2.5; 5.0; 7.5; 10.0; 15.0 ]
end)

module Metrics = struct
  let namespace = "terrat"
  let subsystem = "vcs_event_evaluator2"

  let tasks_concurrent =
    let help = "Number of tasks running right now" in
    Prmths.Gauge.v ~help ~namespace ~subsystem "tasks_concurrent"

  let tasks_suspended =
    let help = "Number of tasks suspended right now" in
    Prmths.Gauge.v ~help ~namespace ~subsystem "tasks_suspended"

  let tasks_concurrent_max =
    let help = "Maximum number of concurrent tasks running" in
    Prmths.Gauge.v ~help ~namespace ~subsystem "tasks_concurrent_max"

  let queue_time =
    let help = "Time spent waiting in the task queue" in
    Queue_time_histogram.v ~help ~namespace ~subsystem "queue_time"
end

module Exec_logger = struct
  let tasks_concurrent_max = ref 0

  (* let logger = *)
  (*   { *)
  (*     Exec.Logger.exec_task = *)
  (*       (fun path -> Logs.info (fun m -> m "EXEC : [%s]" (CCString.concat ", " path))); *)
  (*     complete_task = *)
  (*       (fun path -> Logs.info (fun m -> m "COMPLETE : [%s]" (CCString.concat ", " path))); *)
  (*     work_done = *)
  (*       (fun path -> Logs.info (fun m -> m "WORK_DONE : [%s]" (CCString.concat ", " path))); *)
  (*     running_tasks = *)
  (*       (fun count -> *)
  (*         if !tasks_concurrent_max < count then ( *)
  (*           tasks_concurrent_max := count; *)
  (*           Prmths.Gauge.set Metrics.tasks_concurrent_max (CCFloat.of_int count)); *)
  (*         Prmths.Gauge.set Metrics.tasks_concurrent (CCFloat.of_int count); *)
  (*         Logs.info (fun m -> m "RUNNING : %d" count)); *)
  (*     suspended_tasks = *)
  (*       (fun count tasks -> *)
  (*         Prmths.Gauge.set Metrics.tasks_suspended (CCFloat.of_int count); *)
  (*         Logs.info (fun m -> m "SUSPENDED : %d" count); *)
  (*         Iter.iter *)
  (*           (fun task -> Logs.info (fun m -> m "SUSPENDED : %s" (CCString.concat ", " task))) *)
  (*           tasks); *)
  (*     suspend_task = *)
  (*       (fun name -> Logs.info (fun m -> m "SUSPEND : [%s]" (CCString.concat ", " name))); *)
  (*     unsuspend_task = *)
  (*       (fun name -> Logs.info (fun m -> m "UNSUSPEND : [%s]" (CCString.concat ", " name))); *)
  (*     enqueue = (fun path -> Logs.info (fun m -> m "ENQUEUE : [%s]" (CCString.concat ", " path))); *)
  (*   } *)

  let metrics =
    {
      Exec.Logger.exec_task = CCFun.const ();
      complete_task = CCFun.const ();
      work_done = (fun _ -> Prmths.Gauge.dec_one Metrics.tasks_concurrent);
      running_tasks =
        (fun count ->
          if !tasks_concurrent_max < count then (
            tasks_concurrent_max := count;
            Prmths.Gauge.set Metrics.tasks_concurrent_max (CCFloat.of_int count));
          Prmths.Gauge.set Metrics.tasks_concurrent (CCFloat.of_int count));
      suspended_tasks =
        (fun count _ -> Prmths.Gauge.set Metrics.tasks_suspended (CCFloat.of_int count));
      suspend_task = CCFun.const ();
      unsuspend_task = CCFun.const ();
      enqueue = CCFun.const ();
      queue_time = Queue_time_histogram.observe Metrics.queue_time;
    }
end

let create_exec ~slots () = Exec.create ~logger:Exec_logger.metrics ~slots ()

module Make (S : Terrat_vcs_provider2.S) = struct
  module Legacy = Terrat_vcs_event_evaluator.Make (S)

  let src = Logs.Src.create ("vcs_event_evaluator2." ^ S.name)

  module Logs = (val Logs.src_log src : Logs.LOG)
  module Keys = Terrat_vcs_event_evaluator2_targets.Make (S)
  module Hmap = Keys.Hmap
  module Builder = Terrat_vcs_event_evaluator2_builder.Make (S)
  module Tasks = Terrat_vcs_event_evaluator2_tasks.Make (S) (Keys)
  module Tasks_base = Terrat_vcs_event_evaluator2_tasks_base.Make (S) (Keys)
  module Tasks_pr = Terrat_vcs_event_evaluator2_tasks_pr.Make (S) (Keys)
  module Tasks_branch = Terrat_vcs_event_evaluator2_tasks_branch.Make (S) (Keys)

  type err = Builder.err

  module Pull_request_event = Keys.Pull_request_event

  (* The default set of tasks *)
  let tasks = Tasks.default_tasks ()

  let with_conn storage ~f =
    (* If executing fails for any reason, then destroy the connection.  This is
       kind of a belts-and-suspends situation but there could still be work
       executing in the build system because one part threw an exception but
       another hasn't finished it's work and we return early because of the
       exception.  So for now, on failure, we just kill the connection. *)
    Pgsql_pool.with_conn storage ~f:(fun db ->
        Fc.on_failure (fun () -> f db) ~failure:(fun () -> Pgsql_io.destroy db))

  (* Because it's just simpler to work with, we have builds return a [result],
     that way we already have a monad that can short circuit when we do not want
     to continue.  But not all [Error] branches are actually errors. But if we
     return [Error] in a [tx], it gets rolledback.  So this function turns those
     [Error] branches tat are not actually errors into [Ok] branches. *)
  let tx_safe ~request_id build =
    let open Abb.Future.Infix_monad in
    build
    >>= function
    | Ok v -> Abbs_future_combinators.return_ok (`Ok v)
    | Error (`Suspend_eval _ as err) ->
        Logs.info (fun m -> m "%s : %a" request_id Builder.pp_err err);
        Abbs_future_combinators.return_ok err
    | Error (`Noop as err) ->
        (* A Noop isn't an error, it just means tehre is nothing to do *)
        Logs.info (fun m -> m "%s : %a" request_id Builder.pp_err err);
        Abbs_future_combinators.return_ok `Noop
    | Error (`Rerun _ as err) ->
        (* A Rerun isn't an error either.  It has to become an [Ok] here or the
           [tx] rolls back the very write the evaluation asked to commit, and
           then the next pass finds nothing and asks again, forever. *)
        Logs.info (fun m -> m "%s : %a" request_id Builder.pp_err err);
        Abbs_future_combinators.return_ok err
    | Error #err as err -> Abb.Future.return err

  let log_err ~request_id fut =
    Abb.Future.await_bind
      (function
        | `Det (Ok ret) -> Abbs_future_combinators.return_ok ret
        | `Det (Error (`Suspend_eval _) as err) -> Abb.Future.return err
        (* Not an error: the evaluation committed something and asked for a
           fresh transaction.  Logging it through the error path below would
           report a working evaluation as a failure. *)
        | `Det (Error (`Rerun _) as err) -> Abb.Future.return err
        | `Det (Error (#Builder.err as err)) ->
            Logs.err (fun m -> m "%s : %a" request_id Builder.pp_err err);
            Abbs_future_combinators.return_err err
        | `Exn (Buildsys.Error.Fetch_cycle_exn exn, bt_opt) ->
            Logs.err (fun m -> m "%s : %a" request_id Buildsys.Error.pp exn);
            CCOption.iter
              (fun bt ->
                Logs.err (fun m ->
                    m "%s : BACKTRACE: %s" request_id (Printexc.raw_backtrace_to_string bt)))
              bt_opt;
            Abbs_future_combinators.return_err `Error
        | `Exn (exn, bt_opt) ->
            Logs.err (fun m -> m "%s : %s" request_id (Printexc.to_string exn));
            CCOption.iter
              (fun bt ->
                Logs.err (fun m ->
                    m "%s : BACKTRACE: %s" request_id (Printexc.raw_backtrace_to_string bt)))
              bt_opt;
            Abbs_future_combinators.return_err `Error
        | `Aborted ->
            Logs.err (fun m -> m "%s : ABORTED" request_id);
            Abbs_future_combinators.return_err `Error)
      fut

  let run_work_manifest_event ~request_id ~config ~exec ~db event =
    let run =
      let open Abb.Future.Infix_monad in
      let target = Keys.eval_work_manifest_event in
      let store = Hmap.empty |> Keys.Key.add Keys.work_manifest_event (Some event) in
      Builder.State.make ~log_id:request_id ~config ~store ~exec ~db ~tasks ()
      >>= fun s ->
      Logs.info (fun m -> m "%s : target=%s" (Builder.log_id s) (Hmap.Key.info target));
      Builder.eval s target
    in
    log_err ~request_id run

  let rec run_next_pending_compute ~request_id ~config ~storage ~exec () =
    let module Wm = Terrat_work_manifest3 in
    let open Irm in
    Abbs_time_it.run
      (fun t -> Logs.info (fun m -> m "%s : RUN_WORK_MANIFEST : time=%f" request_id t))
      (fun () ->
        with_conn storage ~f:(fun db ->
            Pgsql_io.tx db ~f:(fun () ->
                S.Db.query_next_pending_work_manifest ~new_age:true ~request_id db
                >>= function
                | Some wm -> (
                    Logs.info (fun m ->
                        m "%s : RUN_WORK_MANIFEST : id=%a" request_id Uuidm.pp wm.Wm.id);
                    S.Job_context.Compute_node.create
                      ~request_id
                      ~id:wm.Wm.id
                      ~capabilities:
                        { Tjc.Compute_node.Capabilities.flags = []; sha = wm.Wm.branch_ref }
                      db
                    >>= fun compute_node ->
                    S.Api.create_client ~request_id config wm.Wm.account db
                    >>= fun client ->
                    let open Abb.Future.Infix_monad in
                    S.Work_manifest.run ~request_id config client wm
                    >>= function
                    | Ok () ->
                        let open Fc.Infix_result_monad in
                        S.Work_manifest.update_state ~request_id db wm.Wm.id Wm.State.Running
                        >>| fun () -> `Cont
                    | Error err ->
                        let open Fc.Infix_result_monad in
                        S.Work_manifest.update_state ~request_id db wm.Wm.id Wm.State.Aborted
                        >>= fun () ->
                        S.Job_context.Compute_node.update_state
                          ~request_id
                          ~compute_node_id:compute_node.Tjc.Compute_node.id
                          db
                          Tjc.Compute_node.State.Terminated
                        >>= fun () ->
                        let open Abb.Future.Infix_monad in
                        run_work_manifest_event
                          ~request_id
                          ~config
                          ~db
                          ~exec
                          (Keys.Work_manifest_event.Fail { work_manifest = wm; error = err })
                        >>= fun _ -> Abbs_future_combinators.return_ok `Cont)
                | None -> Abbs_future_combinators.return_ok `Done)))
    >>= function
    | `Cont -> run_next_pending_compute ~request_id ~config ~storage ~exec ()
    | `Done -> Abbs_future_combinators.return_ok ()

  let run_pull_request_event
      ~request_id
      ~config
      ~storage
      ~exec
      ~account
      ~repo
      ~pull_request_id
      ~user
      ~event
      ~store
      () =
    let store =
      store
      |> Keys.Key.add Keys.account account
      |> Keys.Key.add Keys.user (Some user)
      |> Keys.Key.add Keys.repo repo
      |> Keys.Key.add Keys.pull_request_id pull_request_id
      |> Keys.Key.add Keys.pull_request_event event
    in
    Fc.with_finally
      (fun () ->
        let run =
          let open Irm in
          with_conn storage ~f:(fun db ->
              let open Irm in
              Pgsql_io.tx db ~f:(fun () ->
                  S.Db.store_account_repository ~request_id db account repo)
              >>= fun () ->
              let open Abb.Future.Infix_monad in
              Builder.State.make
                ~log_id:request_id
                ~config
                ~store
                ~db
                ~exec
                ~tasks:(Tasks_pr.tasks tasks)
                ()
              >>= fun s ->
              let open Irm in
              Builder.eval s Keys.update_context_branch_hashes
              >>= fun () ->
              Pgsql_io.tx db ~f:(fun () ->
                  let open Abb.Future.Infix_monad in
                  Builder.State.make
                    ~log_id:request_id
                    ~config
                    ~store
                    ~db
                    ~exec
                    ~tasks:(Tasks_pr.tasks tasks)
                    ()
                  >>= fun s ->
                  let open Irm in
                  Builder.eval s Keys.get_context_for_pull_request
                  >>| fun context ->
                  let s =
                    s
                    |> Builder.State.orig_store
                    |> Keys.Key.add Keys.context context
                    |> CCFun.flip Builder.State.set_orig_store s
                  in
                  s)
              >>= fun s ->
              Pgsql_io.tx db ~f:(fun () ->
                  Logs.info (fun m ->
                      m
                        "%s : target=%s"
                        (Builder.log_id s)
                        (Hmap.Key.info Keys.eval_pull_request_event));
                  Builder.eval s Keys.eval_pull_request_event))
          >>= fun job ->
          let open Abb.Future.Infix_monad in
          with_conn storage ~f:(fun db ->
              Pgsql_io.tx db ~f:(fun () ->
                  let open Abb.Future.Infix_monad in
                  let store = store |> Keys.Key.add Keys.job job in
                  Builder.State.make
                    ~log_id:(Builder.mk_log_id ~request_id job.Tjc.Job.id)
                    ~config
                    ~store
                    ~db
                    ~exec
                    ~tasks:(Tasks_pr.tasks tasks)
                    ()
                  >>= fun s ->
                  let open Irm in
                  tx_safe ~request_id @@ Builder.eval s Keys.iter_job >>| fun r -> (s, r)))
          >>= function
          | Ok (s, (`Ok _ | `Noop)) -> (
              let open Irm in
              (* Call maybe_complete_job in a separate transaction *)
              with_conn storage ~f:(fun db ->
                  Pgsql_io.tx db ~f:(fun () ->
                      let open Abb.Future.Infix_monad in
                      let store =
                        store
                        |> Keys.Key.add Keys.job job
                           (* Make publishing comments a noop so we don't give double messages to the user *)
                        |> Keys.Key.add Keys.publish_comment (fun _ ->
                            Abbs_future_combinators.return_ok ())
                        |> Tasks_base.forward_std_keys s
                      in
                      Builder.State.make
                        ~log_id:(Builder.mk_log_id ~request_id job.Tjc.Job.id)
                        ~config
                        ~store
                        ~db
                        ~exec
                        ~tasks:(Tasks_pr.tasks tasks)
                        ()
                      >>= fun s' -> tx_safe ~request_id @@ Builder.eval s' Keys.maybe_complete_job))
              >>= function
              | `Ok () ->
                  with_conn storage ~f:(fun db ->
                      Pgsql_io.tx db ~f:(fun () ->
                          let store = store |> Keys.Key.add Keys.job job in
                          let open Abb.Future.Infix_monad in
                          let store = store |> Tasks_base.forward_std_keys s in
                          Builder.State.make
                            ~log_id:(Builder.mk_log_id ~request_id job.Tjc.Job.id)
                            ~config
                            ~store
                            ~db
                            ~exec
                            ~tasks:(Tasks_pr.tasks tasks)
                            ()
                          >>= fun s -> tx_safe ~request_id @@ Builder.eval s Keys.run_next_layer))
              | (`Suspend_eval _ | `Noop | `Rerun _) as r -> Abbs_future_combinators.return_ok r)
          (* [`Rerun] is handled like [`Suspend_eval] everywhere except
             [work_manifest_result], which is the only entry point that drives
             the loop: the transaction has committed and the evaluation stops,
             to be re-driven by the next event.  Only a work manifest result can
             raise it today -- a pull request event evaluates the work manifest
             state machines through [create], not [result] -- so these arms are
             a guard against a future task adopting the signal, not a live
             path. *)
          | Ok (_, ((`Suspend_eval _ | `Rerun _) as r)) -> Abbs_future_combinators.return_ok r
          | Error err ->
              let open Irm in
              Logs.info (fun m ->
                  m
                    "%s : JOB : FAILED : job_id= %a : %a"
                    request_id
                    Uuidm.pp
                    job.Tjc.Job.id
                    Builder.pp_err
                    err);
              with_conn storage ~f:(fun db ->
                  S.Job_context.Job.update_state
                    ~request_id
                    db
                    ~job_id:job.Tjc.Job.id
                    Tjc.Job.State.Failed)
              >>| fun () -> `Noop
        in
        log_err ~request_id run)
      ~finally:(fun () ->
        Fc.ignore
        @@ Abb.Future.fork
        @@ run_next_pending_compute ~request_id ~config ~storage ~exec ())

  let pull_request_event
      ~request_id
      ~config
      ~storage
      ~exec
      ~account
      ~repo
      ~pull_request_id
      ~user
      event =
    match Sys.getenv_opt "TERRAT_EVENT_EVALUATOR_MODE" with
    | None | Some ("" | "new-age" | "legacy-drift") -> (
        let store =
          Hmap.empty
          |> Keys.Key.add Keys.account account
          |> Keys.Key.add Keys.pull_request_id pull_request_id
          |> Keys.Key.add Keys.repo repo
          |> Keys.Key.add Keys.user (Some user)
          |> Keys.Key.add Keys.work_manifest_event None
        in
        let open Abb.Future.Infix_monad in
        run_pull_request_event
          ~request_id
          ~config
          ~storage
          ~exec
          ~account
          ~repo
          ~pull_request_id
          ~user
          ~event
          ~store
          ()
        >>= function
        | Ok _ -> Abbs_future_combinators.return_ok ()
        | Error _ -> Abbs_future_combinators.return_err `Error)
    | Some _ ->
        let run =
          let ctx = Legacy.Ctx.make ~config ~storage ~request_id () in
          match event with
          | Pull_request_event.Open ->
              Legacy.run_pull_request_open ~ctx ~account ~user ~repo ~pull_request_id ()
          | Pull_request_event.Close ->
              Legacy.run_pull_request_close ~ctx ~account ~user ~repo ~pull_request_id ()
          | Pull_request_event.Sync ->
              Legacy.run_pull_request_sync ~ctx ~account ~user ~repo ~pull_request_id ()
          | Pull_request_event.Ready_for_review ->
              Legacy.run_pull_request_ready_for_review ~ctx ~account ~user ~repo ~pull_request_id ()
          | Pull_request_event.Comment { comment_id; comment } ->
              Legacy.run_pull_request_comment
                ~ctx
                ~account
                ~user
                ~repo
                ~pull_request_id
                ~comment_id
                ~comment
                ()
        in
        Abb.Future.await_bind
          (function
            | `Det _ -> Abbs_future_combinators.return_ok ()
            | `Exn (exn, _) ->
                Logs.err (fun m -> m "%s : %s" request_id (Printexc.to_string exn));
                Abbs_future_combinators.return_err `Error
            | `Aborted ->
                Logs.err (fun m -> m "%s : ABORTED" request_id);
                Abbs_future_combinators.return_err `Error)
          run

  let work_manifest_job_failed ~request_id ~config ~storage ~exec ~account ~repo ~run_id () =
    let run =
      let open Irm in
      let target = Keys.eval_work_manifest_failure in
      let store =
        Hmap.empty
        |> Keys.Key.add Keys.account account
        |> Keys.Key.add Keys.repo repo
        |> Keys.Key.add Keys.run_id run_id
      in
      with_conn storage ~f:(fun db ->
          S.Work_manifest.query_by_run_id ~request_id db run_id
          >>= function
          | Some work_manifest -> (
              S.Db.query_flow_state ~request_id db work_manifest.Terrat_work_manifest3.id
              >>| function
              | Some _ -> `Legacy work_manifest
              | None -> `New_age)
          | None -> Abbs_future_combinators.return_ok `New_age)
      >>= function
      | `New_age ->
          with_conn storage ~f:(fun db ->
              Pgsql_io.tx db ~f:(fun () ->
                  let open Abb.Future.Infix_monad in
                  Builder.State.make ~log_id:request_id ~config ~store ~db ~exec ~tasks ()
                  >>= fun s ->
                  Logs.info (fun m -> m "%s : target=%s" (Builder.log_id s) (Hmap.Key.info target));
                  tx_safe ~request_id @@ Builder.eval s target))
      | `Legacy work_manifest ->
          let ctx = Legacy.Ctx.make ~config ~storage ~request_id () in
          Legacy.run_work_manifest_failure ~ctx work_manifest.Terrat_work_manifest3.id
          >>| fun _ -> `Ok ()
    in
    let open Abb.Future.Infix_monad in
    log_err ~request_id run
    >>= function
    | Ok _ -> Abbs_future_combinators.return_ok ()
    | Error _ -> Abbs_future_combinators.return_err `Error

  let compute_node_poll ~request_id ~config ~storage ~exec ~compute_node_id offering =
    let open Abb.Future.Infix_monad in
    let run =
      let open Irm in
      with_conn storage ~f:(fun db ->
          S.Db.query_flow_state ~request_id db compute_node_id
          >>| function
          | Some _ -> `Legacy
          | None -> `New_age)
      >>= function
      | `New_age ->
          let module Offering = Terrat_api_components.Work_manifest_initiate in
          let target = Keys.eval_compute_node_poll in
          let store =
            Hmap.empty
            |> Keys.Key.add Keys.compute_node_id compute_node_id
            |> Keys.Key.add Keys.compute_node_offering offering
          in
          with_conn storage ~f:(fun db ->
              let open Abb.Future.Infix_monad in
              Pgsql_io.tx db ~f:(fun () ->
                  Builder.State.make ~log_id:request_id ~config ~store ~db ~exec ~tasks ()
                  >>= fun s ->
                  Logs.info (fun m ->
                      m
                        "%s : COMPUTE_NODE_POLL : compute_node_id = %a : run_id = %s"
                        (Builder.log_id s)
                        Uuidm.pp
                        compute_node_id
                        offering.Offering.run_id);
                  tx_safe ~request_id @@ Builder.eval s target))
      | `Legacy -> (
          let select_encryption_key () =
            (* The hex conversion is so that there are no issues with escaping
               the string *)
            Pgsql_io.Typed_sql.(
              sql
              //
              (* data *)
              Ret.u Ret.text CCFun.(Cstruct.of_hex %> CCOption.return)
              /^ "select encode(data, 'hex') from encryption_keys order by rank limit 1")
          in
          with_conn storage ~f:(fun db ->
              Pgsql_io.Prepared_stmt.fetch db (select_encryption_key ()) ~f:CCFun.id)
          >>= function
          | [] -> assert false
          | encryption_key :: _ -> (
              let open Abb.Future.Infix_monad in
              let ctx = Legacy.Ctx.make ~config ~storage ~request_id () in
              Legacy.run_work_manifest_initiate ~ctx ~encryption_key compute_node_id offering
              >>= function
              | Ok (Some r) -> Abbs_future_combinators.return_ok (`Ok r)
              | Ok None -> Abbs_future_combinators.return_err `Error
              | Error err -> Abbs_future_combinators.return_err err))
    in
    Fc.with_finally
      (fun () ->
        log_err ~request_id run
        >>= function
        | Ok (`Ok r) -> Abbs_future_combinators.return_ok r
        | Ok (`Suspend_eval _) | Ok `Noop | Ok (`Rerun _) | Error _ ->
            Abbs_future_combinators.return_err `Error)
      ~finally:(fun () ->
        Fc.ignore
        @@ Abb.Future.fork
        @@ run_next_pending_compute ~request_id ~config ~storage ~exec ())

  let run_missing_drift_schedules ?request_id ~config ~storage ~exec () =
    let open Abb.Future.Infix_monad in
    let request_id = CCOption.get_lazy CCFun.(Ouuid.v4 %> Uuidm.to_string) request_id in
    Logs.info (fun m -> m "RUN_MISSING_DRIFT_SCHEDULES : %s" request_id);
    let run =
      match Sys.getenv_opt "TERRAT_EVENT_EVALUATOR_MODE" with
      | None | Some ("" | "new-age") ->
          let target = Keys.run_missing_drift_schedules in
          let store = Hmap.empty in
          with_conn storage ~f:(fun db ->
              Fc.retry
                ~f:(fun () ->
                  Pgsql_io.tx db ~f:(fun () ->
                      Builder.State.make
                        ~log_id:request_id
                        ~config
                        ~store
                        ~exec
                        ~db
                        ~tasks:(Tasks_branch.tasks tasks)
                        ()
                      >>= fun s ->
                      Logs.info (fun m ->
                          m "%s : target=%s" (Builder.log_id s) (Hmap.Key.info target));
                      tx_safe ~request_id @@ Builder.eval s target))
                ~while_:
                  (Fc.finite_tries 50 (function
                    | Ok (`Ok n) -> n > 0
                    | Ok (`Noop | `Suspend_eval _ | `Rerun _) | Error _ -> true))
                ~betwixt:(fun _ -> Fc.unit))
      | Some _ ->
          let ctx = Legacy.Ctx.make ~config ~storage ~request_id () in
          Legacy.run_scheduled_drift ctx >>= fun _ -> Abbs_future_combinators.return_ok (`Ok 0)
    in
    Fc.with_finally
      (fun () -> Fc.ignore @@ log_err ~request_id run)
      ~finally:(fun () ->
        Fc.ignore
        @@ Abb.Future.fork
        @@ run_next_pending_compute ~request_id ~config ~storage ~exec ())

  let work_manifest_result ~request_id ~config ~storage ~exec ~work_manifest_id result =
    let query_work_manifest db =
      Abbs_time_it.run
        (fun time ->
          Logs.info (fun m ->
              m
                "%s : QUERY_WORK_MANIIFEST : work_manifest = %a : time=%f"
                request_id
                Uuidm.pp
                work_manifest_id
                time))
        (fun () ->
          let open Irm in
          S.Work_manifest.query ~request_id db work_manifest_id
          >>? function
          | Some work_manifest -> Ok work_manifest
          | None -> Error `Error)
    in
    let query_compute_node db =
      Abbs_time_it.run
        (fun time ->
          Logs.info (fun m ->
              m
                "%s : QUERY_COMPUTE_NODE : compute_node_id = %a : time=%f"
                request_id
                Uuidm.pp
                work_manifest_id
                time))
        (fun () ->
          let open Irm in
          S.Job_context.Compute_node.query ~request_id ~compute_node_id:work_manifest_id db
          >>? function
          | Some compute_node -> Ok compute_node
          | None -> Error `Error)
    in
    let query_job db =
      Abbs_time_it.run
        (fun time ->
          Logs.info (fun m ->
              m
                "%s : QUERY_JOB_BY_WORK_MANIFEST : work_manifest_id = %a : time=%f"
                request_id
                Uuidm.pp
                work_manifest_id
                time))
        (fun () -> S.Job_context.Job.query_by_work_manifest_id ~request_id ~work_manifest_id db ())
    in
    let add_work_manifest_keys work_manifest store =
      let module Wm = Terrat_work_manifest3 in
      let { Wm.id = _; account; target; _ } = work_manifest in
      match target with
      | Terrat_vcs_provider2.Target.Pr pr ->
          store
          |> Keys.Key.add Keys.account account
          |> Keys.Key.add Keys.pull_request_id (S.Api.Pull_request.id pr)
          |> Keys.Key.add Keys.repo (S.Api.Pull_request.repo pr)
      | Terrat_vcs_provider2.Target.Drift { repo; _ } ->
          store |> Keys.Key.add Keys.account account |> Keys.Key.add Keys.repo repo
    in
    let run =
      let open Irm in
      Logs.info (fun m ->
          m "%s : WORK_MANIFEST_RESULT : work_manifest_id= %a" request_id Uuidm.pp work_manifest_id);
      with_conn storage ~f:(fun db ->
          S.Db.query_flow_state ~request_id db work_manifest_id
          >>| function
          | Some _ -> `Legacy
          | None -> `New_age)
      >>= function
      | `New_age -> (
          let open Abb.Future.Infix_monad in
          with_conn storage ~f:(fun db ->
              (* An evaluation that commits something durable ends its
                 transaction there and asks to be re-run, so the rows it wrote
                 are not held for the rest of the job.  Each pass is a fresh
                 transaction on this same connection, as
                 [run_missing_drift_schedules] already does, and [reruns] carries
                 what earlier passes committed.

                 A payload is recorded only after its transaction committed, so
                 seeing one twice means the pass committed nothing new and
                 another would loop.  That is a broken task, not a user error,
                 so it fails loudly. *)
              let rec eval_with_reruns reruns =
                Pgsql_io.tx db ~f:(fun () ->
                    let open Irm in
                    query_job db
                    >>= function
                    | Some job ->
                        query_work_manifest db
                        >>= fun work_manifest ->
                        query_compute_node db
                        >>= fun compute_node ->
                        let work_manifest_event =
                          Keys.Work_manifest_event.Result { work_manifest; result }
                        in
                        let store =
                          Hmap.empty
                          |> Keys.Key.add Keys.compute_node compute_node
                          |> Keys.Key.add Keys.work_manifest_event (Some work_manifest_event)
                          |> Keys.Key.add Keys.reruns reruns
                        in
                        let open Abb.Future.Infix_monad in
                        Builder.State.make ~log_id:request_id ~config ~store ~db ~exec ~tasks ()
                        >>= fun s ->
                        let open Irm in
                        let target = Keys.eval_work_manifest_event in
                        Logs.info (fun m ->
                            m "%s : target=%s" (Builder.log_id s) (Hmap.Key.info target));
                        tx_safe ~request_id @@ Builder.eval s target
                        >>| fun r -> (s, work_manifest, job, r)
                    | None ->
                        Logs.info (fun m ->
                            m
                              "%s : JOB_MISSING_FOR_WORK_MANIFEST : work_manifest_id= %a"
                              request_id
                              Uuidm.pp
                              work_manifest_id);
                        Abbs_future_combinators.return_err `Error)
                >>= function
                (* A guard, not a live path: every producer of [`Rerun] names
                   what it committed, so the list is never empty.  It is checked
                   because an empty one adds nothing to [reruns] and the pass
                   after it would ask for the same nothing, without end. *)
                | Ok (_, _, _, `Rerun []) ->
                    Logs.err (fun m -> m "%s : RERUN : NO_PAYLOAD" request_id);
                    Abbs_future_combinators.return_err `Error
                (* A task only asks to rerun a payload that is not in [reruns]
                   yet, so one that is already there came back without the write
                   it names having landed. *)
                | Ok (_, _, _, `Rerun ids)
                  when CCList.exists (fun id -> Sln_list.String.mem id reruns) ids ->
                    Logs.err (fun m ->
                        m "%s : RERUN : NO_PROGRESS : ids=%s" request_id (CCString.concat "," ids));
                    Abbs_future_combinators.return_err `Error
                | Ok (_, _, _, `Rerun ids) ->
                    Logs.info (fun m ->
                        m "%s : RERUN : ids=%s" request_id (CCString.concat "," ids));
                    eval_with_reruns (ids @ reruns)
                (* Spelled out rather than a wildcard so the loop's result type
                   has no [`Rerun] in it.  The rest of this function then stays
                   exhaustive without an arm for a case the loop has already
                   consumed. *)
                | Ok (s, work_manifest, job, ((`Ok _ | `Suspend_eval _ | `Noop) as r)) ->
                    Abbs_future_combinators.return_ok (s, work_manifest, job, r)
                | Error _ as err -> Abb.Future.return err
              in
              eval_with_reruns [])
          >>= function
          | Ok (s, work_manifest, job, `Ok _) ->
              (* We've calculated the API response, so background running the next
             layer to not holdup giving the response back *)
              let open Abb.Future.Infix_monad in
              Abb.Future.fork
                (Fc.with_finally
                   (fun () ->
                     with_conn storage ~f:(fun db ->
                         Pgsql_io.tx db ~f:(fun () ->
                             let { Tjc.Job.context = { Tjc.Context.scope; _ }; _ } = job in
                             let store =
                               s
                               |> Builder.State.orig_store
                               |> Keys.Key.add Keys.job job
                               |> Tasks_base.forward_std_keys s
                               |> add_work_manifest_keys work_manifest
                             in
                             let open Abb.Future.Infix_monad in
                             Builder.State.make
                               ~log_id:request_id
                               ~config
                               ~store
                               ~db
                               ~exec
                               ~tasks:
                                 (match scope with
                                 | Tjc.Context.Scope.Pull_request _ ->
                                     Tasks_pr.tasks @@ Builder.State.tasks s
                                 | Tjc.Context.Scope.Branch _ ->
                                     Tasks_branch.tasks @@ Builder.State.tasks s)
                               ()
                             >>= fun s -> tx_safe ~request_id @@ Builder.eval s Keys.run_next_layer)))
                   ~finally:(fun () ->
                     Fc.ignore
                     @@ Abb.Future.fork
                     @@ run_next_pending_compute ~request_id ~config ~storage ~exec ()))
              >>= fun _ -> Abbs_future_combinators.return_ok (`Ok ())
          | Ok (s, work_manifest, job, `Suspend_eval _) ->
              let open Abb.Future.Infix_monad in
              Abb.Future.fork
                (Fc.with_finally
                   (fun () ->
                     with_conn storage ~f:(fun db ->
                         let { Tjc.Job.context = { Tjc.Context.scope; _ }; _ } = job in
                         let open Abb.Future.Infix_monad in
                         let store =
                           s |> Builder.State.orig_store |> Tasks_base.forward_std_keys s
                         in
                         Builder.State.make
                           ~log_id:request_id
                           ~config
                           ~store
                           ~db
                           ~exec
                           ~tasks:
                             (match scope with
                             | Tjc.Context.Scope.Pull_request _ ->
                                 Tasks_pr.tasks @@ Builder.State.tasks s
                             | Tjc.Context.Scope.Branch _ ->
                                 Tasks_branch.tasks @@ Builder.State.tasks s)
                           ()
                         >>= fun s ->
                         Pgsql_io.tx db ~f:(fun () ->
                             log_err ~request_id
                             @@ tx_safe ~request_id
                             @@ Builder.eval s Keys.maybe_complete_job_from_work_manifest_event))
                     >>= function
                     | Ok (`Ok ()) ->
                         Fc.with_finally
                           (fun () ->
                             with_conn storage ~f:(fun db ->
                                 let { Tjc.Job.context = { Tjc.Context.scope; _ }; _ } = job in
                                 let store =
                                   s
                                   |> Builder.State.orig_store
                                   |> Keys.Key.add Keys.job job
                                   |> Tasks_base.forward_std_keys s
                                   |> add_work_manifest_keys work_manifest
                                   |> Builder.State.forward_store_value
                                        Keys.work_manifests_for_job
                                        s
                                 in
                                 let open Abb.Future.Infix_monad in
                                 Builder.State.make
                                   ~log_id:request_id
                                   ~config
                                   ~store
                                   ~db
                                   ~exec
                                   ~tasks:
                                     (match scope with
                                     | Tjc.Context.Scope.Pull_request _ ->
                                         Tasks_pr.tasks @@ Builder.State.tasks s
                                     | Tjc.Context.Scope.Branch _ ->
                                         Tasks_branch.tasks @@ Builder.State.tasks s)
                                   ()
                                 >>= fun s ->
                                 Pgsql_io.tx db ~f:(fun () ->
                                     log_err ~request_id
                                     @@ tx_safe ~request_id
                                     @@ Builder.eval s Keys.run_next_layer)))
                           ~finally:(fun () ->
                             Fc.ignore
                             @@ Abb.Future.fork
                             @@ run_next_pending_compute ~request_id ~config ~storage ~exec ())
                     | (Ok (`Suspend_eval _ | `Noop | `Rerun _) | Error _) as r ->
                         Abb.Future.return r)
                   ~finally:(fun () ->
                     Fc.ignore
                     @@ Abb.Future.fork
                     @@ run_next_pending_compute ~request_id ~config ~storage ~exec ()))
              >>= fun _ -> Abbs_future_combinators.return_ok (`Ok ())
          | Ok (_, _, _, `Noop) -> Abbs_future_combinators.return_ok `Noop
          | Error #err as err ->
              let open Abb.Future.Infix_monad in
              with_conn storage ~f:(fun db ->
                  let open Irm in
                  query_work_manifest db
                  >>= fun work_manifest ->
                  S.Work_manifest.update_state
                    ~request_id
                    db
                    work_manifest_id
                    Terrat_work_manifest3.State.Aborted
                  >>= fun () ->
                  run_work_manifest_event
                    ~request_id
                    ~config
                    ~db
                    ~exec
                    (Keys.Work_manifest_event.Fail { work_manifest; error = `Result_handling_err }))
              >>= fun _ -> Abb.Future.return err)
      | `Legacy ->
          let open Abb.Future.Infix_monad in
          let ctx = Legacy.Ctx.make ~config ~storage ~request_id () in
          Legacy.run_work_manifest_result ~ctx work_manifest_id result
          >>= fun _ -> Abbs_future_combinators.return_ok (`Ok ())
    in
    let open Abb.Future.Infix_monad in
    Fc.with_finally
      (fun () ->
        log_err ~request_id run
        >>= function
        | Ok _ -> Abbs_future_combinators.return_ok ()
        | Error _ -> Abbs_future_combinators.return_err `Error)
      ~finally:(fun () ->
        Fc.ignore
        @@ Abb.Future.fork
        @@ run_missing_drift_schedules ~request_id ~config ~storage ~exec ())

  let push ~request_id ~config ~storage ~exec ~account ~repo ~branch ~user () =
    let run =
      let open Irm in
      match Sys.getenv_opt "TERRAT_EVENT_EVALUATOR_MODE" with
      | None | Some ("" | "new-age") ->
          with_conn storage ~f:(fun db ->
              Pgsql_io.tx db ~f:(fun () ->
                  S.Db.store_account_repository ~request_id db account repo)
              >>= fun () ->
              Pgsql_io.tx db ~f:(fun () ->
                  S.Job_context.create_or_get_for_branch ~request_id db account repo branch
                  >>= fun context ->
                  S.Job_context.Job.create ~request_id db Tjc.Job.Type_.Push context (Some user))
              >>= fun job ->
              let store =
                Hmap.empty
                |> Keys.Key.add Keys.account account
                |> Keys.Key.add Keys.repo repo
                |> Keys.Key.add Keys.user (Some user)
                |> Keys.Key.add Keys.job job
              in
              let open Abb.Future.Infix_monad in
              Builder.State.make
                ~log_id:request_id
                ~config
                ~store
                ~db
                ~exec
                ~tasks:(Tasks_branch.tasks tasks)
                ()
              >>= fun s ->
              let open Irm in
              (* For updating the branch hashes we set the branch name.  We make [s'] for this
                 because [eval_push_event] doesn't need it and we don't want to put keys there that
                 it might have its own plans for. *)
              let s' =
                s
                |> Builder.State.orig_store
                |> Keys.Key.add Keys.branch_name branch
                |> Keys.Key.add Keys.dest_branch_name branch
                |> CCFun.flip Builder.State.set_orig_store s
              in
              log_err ~request_id @@ Builder.eval s' Keys.update_context_branch_hashes
              >>= fun () ->
              let target = Keys.eval_push_event in
              Logs.info (fun m -> m "%s : target=%s" (Builder.log_id s) (Hmap.Key.info target));
              Pgsql_io.tx db ~f:(fun () -> tx_safe ~request_id @@ Builder.eval s target))
          >>= fun _ ->
          Fc.to_result
          @@ Fc.ignore
          @@ Abb.Future.fork
          @@ run_missing_drift_schedules ~config ~storage ~exec ()
      | Some _ ->
          with_conn storage ~f:(fun db -> S.Api.create_client ~request_id config account db)
          >>= fun client ->
          S.Api.fetch_remote_repo ~request_id client repo
          >>= fun remote_repo ->
          let default_branch = S.Api.Remote_repo.default_branch remote_repo in
          if branch = default_branch then
            let ctx = Legacy.Ctx.make ~config ~storage ~request_id () in
            Legacy.run_push ~ctx ~account ~user ~repo ~branch ()
          else Abbs_future_combinators.return_ok ()
    in
    Fc.with_finally
      (fun () ->
        let open Abb.Future.Infix_monad in
        log_err ~request_id run
        >>= function
        | Ok _ -> Abbs_future_combinators.return_ok ()
        | Error _ -> Abbs_future_combinators.return_err `Error)
      ~finally:(fun () ->
        Fc.ignore
        @@ Abb.Future.fork
        @@ run_next_pending_compute ~request_id ~config ~storage ~exec ())
end
