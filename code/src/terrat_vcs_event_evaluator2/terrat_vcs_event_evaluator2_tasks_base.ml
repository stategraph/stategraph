module Metrics = struct
  module Task_exec_duration = Prmths.Histogram (struct
    let spec = Prmths.Histogram_spec.of_list [ 0.0; 1.0; 2.0; 5.0; 10.0; 20.0; 50.0; 100.0 ]
  end)

  let namespace = "terrat"
  let subsystem = "vcs_event_evaluator2_task_base"

  let exec_duration =
    let help = "Time scheduler spends processing a task." in
    Task_exec_duration.v_label ~label_name:"task" ~help ~namespace ~subsystem "exec_duration"
end

module Msg = Terrat_vcs_provider2.Msg

module Make
    (S : Terrat_vcs_provider2.S)
    (Keys : module type of Terrat_vcs_event_evaluator2_targets.Make (S)) =
struct
  let src = Logs.Src.create ("vcs_event_evaluator2_tasks_base." ^ S.name)

  module Logs = (val Logs.src_log src : Logs.LOG)
  module Builder = Terrat_vcs_event_evaluator2_builder.Make (S)

  let run ~name f path s fetcher =
    Abb.Future.await_bind (function
      | `Det r -> Abb.Future.return r
      | `Exn (Buildsys.Error.Fetch_cycle_exn exn, bt_opt) ->
          Logs.err (fun m -> m "%s : %a" (Builder.log_id s) Buildsys.Error.pp exn);
          CCOption.iter
            (fun bt ->
              Logs.err (fun m ->
                  m "%s : BACKTRACE: %s" (Builder.log_id s) (Printexc.raw_backtrace_to_string bt)))
            bt_opt;
          Abbs_future_combinators.return_err `Error
      | `Exn (exn, bt_opt) ->
          Logs.err (fun m -> m "%s : %s" (Builder.log_id s) (Printexc.to_string exn));
          CCOption.iter
            (fun bt ->
              Logs.err (fun m ->
                  m "%s : BACKTRACE: %s" (Builder.log_id s) (Printexc.raw_backtrace_to_string bt)))
            bt_opt;
          Abbs_future_combinators.return_err `Error
      | `Aborted ->
          Logs.err (fun m -> m "%s : ABORTED" (Builder.log_id s));
          Abbs_future_combinators.return_err `Error)
    @@ Abbs_time_it.run'
         (fun ret t ->
           Metrics.Task_exec_duration.observe (Metrics.exec_duration name) t;
           match ret with
           | Ok _ ->
               Logs.info (fun m ->
                   m "%s : TASK : END : SUCCESS : name=%s : time=%f" (Builder.log_id s) name t)
           | Error (`Suspend_eval _) ->
               Logs.info (fun m ->
                   m "%s : TASK : END: SUSPEND : name=%s : time=%f" (Builder.log_id s) name t)
           | Error `Noop ->
               Logs.info (fun m ->
                   m "%s : TASK : END: NOOP : name=%s : time=%f" (Builder.log_id s) name t)
           | Error (`Rerun _) ->
               (* Not a failure: the task committed something and asked for a
                  fresh transaction, so every task on the path back up would
                  otherwise read as FAIL. *)
               Logs.info (fun m ->
                   m "%s : TASK : END: RERUN : name=%s : time=%f" (Builder.log_id s) name t)
           | Error #Builder.err ->
               Logs.info (fun m ->
                   m "%s : TASK : END: FAIL : name=%s : time=%f" (Builder.log_id s) name t))
         (fun () ->
           Logs.info (fun m ->
               m
                 "%s : TASK : START : name=%s : path=[%s]"
                 (Builder.log_id s)
                 name
                 (CCString.concat ", " path));
           f (Builder.State.set_path path s) fetcher)

  (* Publishing a comment is the last thing we can do for a user.  If it fails,
     the failure is [`Silent_failure]: retrying the publish from an error
     handler would fail for the same reason and, if it did not, would publish a
     second comment. *)
  let publish_comment' f msg =
    let open Abb.Future.Infix_monad in
    f msg
    >>= function
    | Ok () -> Abbs_future_combinators.return_ok ()
    | Error `Error -> Abbs_future_combinators.return_err `Silent_failure

  (* Commit checks are not the user's only channel, so unlike [publish_comment']
     a failure here is worth a comment of its own.

     Creating no checks is a no-op: performing it would dirty the commit checks,
     forcing anyone that reads them afterwards to fetch them again for no
     benefit. *)
  let create_commit_checks' f branch_ref = function
    | [] -> Abbs_future_combinators.return_ok ()
    | checks -> (
        let open Abb.Future.Infix_monad in
        f branch_ref checks
        >>= function
        | Ok () -> Abbs_future_combinators.return_ok ()
        | Error ((`Vcs_api_rate_limit_err _ | `Vcs_api_timeout_err _) as err) ->
            Abbs_future_combinators.return_err err
        | Error `Error -> Abbs_future_combinators.return_err (`Vcs_api_err "CREATE_COMMIT_CHECKS"))

  (* A precheck answers before the tree, the config and the index exist, and a
     read of the matches would build all three. *)
  let create_completed_apply_check s { Builder.Bs.Fetcher.fetch } =
    let open Abbs_future_combinators.Infix_result_monad in
    fetch Keys.account
    >>= fun account ->
    fetch Keys.repo
    >>= fun repo ->
    let checks =
      [
        S.Commit_check.make_str
          ~config:(Builder.State.config s)
          ~description:"Completed"
          ~status:Terrat_commit_check.Status.Completed
          ~repo
          ~account
          "terrateam apply";
      ]
    in
    fetch Keys.branch_ref
    >>= fun branch_ref ->
    fetch Keys.create_commit_checks
    >>= fun create_commit_checks -> create_commit_checks' create_commit_checks branch_ref checks

  (* The comment, if any, a user should see for an evaluation error.  [None]
     means say nothing: either nothing went wrong ([`Noop], [`Suspend_eval],
     [`Rerun]) or everything worth saying has already been said
     ([`Silent_failure]).

     Every constructor is listed rather than falling back on a [#Builder.err]
     catch-all, so that adding a member to [Keys.err] fails the build until
     someone decides what the user is told. *)
  let msg_of_err : Builder.err -> Keys.msg option = function
    | #Terrat_base_repo_config_v1.of_version_1_err as err -> Some (Msg.Repo_config_err err)
    | #Terrat_change_match3.synthesize_config_err as err -> Some (Msg.Synthesize_config_err err)
    | #Str_template.err as err -> Some (Msg.Str_template_err err)
    | `Json_decode_err (fname, err) | `Yaml_decode_err (fname, err) ->
        Some (Msg.Repo_config_parse_failure (fname, err))
    | `Repo_config_schema_err (fname, err) -> Some (Msg.Repo_config_schema_err (fname, err))
    | `Premium_feature_err feature -> Some (Msg.Premium_feature_err feature)
    | `Config_merge_err details -> Some (Msg.Repo_config_merge_err details)
    | `Branch_not_found_err branch -> Some (Msg.Operation_failed (`Branch_not_found_err branch))
    | `Compute_aborted_err num_aborts ->
        Some (Msg.Operation_failed (`Compute_aborted_err num_aborts))
    | `Vcs_api_err operation -> Some (Msg.Operation_failed (`Vcs_api_err operation))
    | `Vcs_api_rate_limit_err operation ->
        Some (Msg.Operation_failed (`Vcs_api_rate_limit_err operation))
    | `Vcs_api_timeout_err operation -> Some (Msg.Operation_failed (`Vcs_api_timeout_err operation))
    | `Closed | #Pgsql_io.err | #Pgsql_pool.err -> Some (Msg.Operation_failed `Db_err)
    | `Missing_dep_err tag | `Msg_err tag | `Unexpected_err tag ->
        Some (Msg.Operation_failed (`Internal_err tag))
    | `No_matching_token_err token ->
        Some (Msg.Operation_failed (`Internal_err ("GATE_TOKEN:" ^ token)))
    | `Work_manifest_err id ->
        Some (Msg.Operation_failed (`Internal_err ("WORK_MANIFEST:" ^ Uuidm.to_string id)))
    | `Error -> Some (Msg.Operation_failed (`Internal_err "UNKNOWN"))
    | `Noop | `Suspend_eval _ | `Rerun _ | `Silent_failure -> None

  let forward_std_keys s store = store |> Builder.State.forward_store_value Keys.pull_request s
end
