module Irm = Abbs_future_combinators.Infix_result_monad
module Msg = Terrat_vcs_provider2.Msg

module Make
    (S : Terrat_vcs_provider2.S)
    (Keys : module type of Terrat_vcs_event_evaluator2_targets.Make (S)) =
struct
  let src = Logs.Src.create ("vcs_event_evaluator2_wm_sm_repo_tree." ^ S.name)

  module Logs = (val Logs.src_log src : Logs.LOG)
  module Builder = Terrat_vcs_event_evaluator2_builder.Make (S)
  module Tasks_base = Terrat_vcs_event_evaluator2_tasks_base.Make (S) (Keys)

  let time_it s l f =
    Abbs_time_it.run (fun time -> Logs.info (fun m -> l m (Builder.log_id s) time)) f

  module Bs = Builder.Bs
  module Wm_sm = Terrat_vcs_event_evaluator2_wm_sm.Make (S) (Keys)
  module Wm = Terrat_work_manifest3

  let query_repo_tree s db account branch_ref dest_branch_ref =
    time_it
      s
      (fun m log_id time -> m "%s : QUERY_REPO_TREE : time=%f" log_id time)
      (fun () ->
        S.Db.query_repo_tree
          ~request_id:(Builder.log_id s)
          ~base_ref:dest_branch_ref
          db
          account
          branch_ref)

  let create_work_manifest s db work_manifest =
    time_it
      s
      (fun m log_id time -> m "%s : WORK_MANIFEST : CREATE : time=%f" log_id time)
      (fun () -> S.Work_manifest.create ~request_id:(Builder.log_id s) db work_manifest)

  let create_token s db account id =
    time_it
      s
      (fun m log_id time -> m "%s : CREATE_TOKEN : wm=%a : time=%f" log_id Uuidm.pp id time)
      (fun () -> Wm_sm.create_token' ~log_id:(Builder.log_id s) (S.Api.Account.id account) id db)

  let store_repo_tree s db account branch_ref files =
    time_it
      s
      (fun m log_id time -> m "%s : STORE_REPO_TREE : time=%f" log_id time)
      (fun () -> S.Db.store_repo_tree ~request_id:(Builder.log_id s) db account branch_ref files)

  module Wmr = Terrat_api_components.Work_manifest_result
  module Bt = Terrat_api_components.Work_manifest_build_tree_result
  module Bf = Terrat_api_components.Work_manifest_build_result_failure

  let publish_comment' f msg = Tasks_base.publish_comment' f msg

  let create_commit_checks' f branch_ref checks =
    Tasks_base.create_commit_checks' f branch_ref checks

  let eq base_ref' branch_ref' { Wm.base_ref; branch_ref; steps; _ } =
    base_ref = S.Api.Ref.to_string base_ref'
    && branch_ref = S.Api.Ref.to_string branch_ref'
    && steps = [ Wm.Step.Build_tree ]

  let status_name ~branch ~branch_name =
    let branch = S.Api.Ref.to_string branch in
    let branch_name = S.Api.Ref.to_string branch_name in
    if branch = branch_name then "terrateam build-tree" else "terrateam build-tree " ^ branch

  let create ~dest_branch_ref ~branch_ref ~branch s { Bs.Fetcher.fetch } =
    let open Irm in
    fetch Keys.account
    >>= fun account ->
    (* Check to see if the tree already exists, if so we don't have to do anything. *)
    Builder.run_db s ~f:(fun db -> query_repo_tree s db account branch_ref dest_branch_ref)
    >>= function
    | None ->
        fetch Keys.repo
        >>= fun repo ->
        fetch Keys.initiator
        >>= fun initiator ->
        fetch Keys.target
        >>= fun target ->
        let work_manifest =
          {
            Wm.account;
            base_ref = S.Api.Ref.to_string dest_branch_ref;
            branch = Some (S.Api.Ref.to_string branch);
            branch_ref = S.Api.Ref.to_string branch_ref;
            changes = [];
            completed_at = None;
            created_at = ();
            denied_dirspaces = [];
            environment = None;
            id = ();
            initiator;
            run_id = ();
            runs_on = None;
            state = ();
            steps = [ Wm.Step.Build_tree ];
            tag_query = Terrat_tag_query.any;
            target;
          }
        in
        Builder.run_db s ~f:(fun db -> create_work_manifest s db work_manifest)
        >>= fun work_manifest ->
        fetch Keys.branch_ref
        >>= fun branch_ref ->
        fetch Keys.branch_name
        >>= fun branch_name ->
        let module Status = Terrat_commit_check.Status in
        let check =
          S.Commit_check.make_str
            ~config:(Builder.State.config s)
            ~description:"Queued"
            ~status:Status.Queued
            ~work_manifest
            ~repo
            ~account
            (status_name ~branch ~branch_name)
        in
        fetch Keys.create_commit_checks
        >>= fun create_commit_checks ->
        create_commit_checks' create_commit_checks branch_ref [ check ]
        >>| fun () -> [ work_manifest ]
    | Some _ ->
        fetch Keys.commit_checks
        >>= fun commit_checks ->
        fetch Keys.branch_ref
        >>= fun branch_ref ->
        fetch Keys.branch_name
        >>= fun branch_name ->
        let module Ch = Terrat_commit_check in
        let check_title = status_name ~branch ~branch_name in
        let unfinished_checks =
          CCList.filter_map
            (function
              | { Ch.status = Ch.Status.(Completed | Failed | Canceled); _ } -> None
              | { Ch.status = Ch.Status.(Queued | Running); title; _ } as c when title = check_title
                -> Some { c with Ch.status = Ch.Status.Completed; description = "Completed" }
              | _ -> None)
            commit_checks
        in
        fetch Keys.create_commit_checks
        >>= fun create_commit_checks ->
        create_commit_checks' create_commit_checks branch_ref unfinished_checks >>| fun () -> []

  let initiate ~branch ({ Wm.id; _ } as work_manifest) s { Bs.Fetcher.fetch } =
    let open Irm in
    fetch Keys.account
    >>= fun account ->
    fetch Keys.repo
    >>= fun repo ->
    fetch Keys.branch_ref
    >>= fun branch_ref ->
    fetch Keys.branch_name
    >>= fun branch_name ->
    let module Status = Terrat_commit_check.Status in
    let check =
      S.Commit_check.make_str
        ~config:(Builder.State.config s)
        ~description:"Running"
        ~status:Status.Running
        ~work_manifest
        ~repo
        ~account
        (status_name ~branch ~branch_name)
    in
    fetch Keys.create_commit_checks
    >>= fun create_commit_checks ->
    create_commit_checks' create_commit_checks branch_ref [ check ]
    >>= fun () ->
    fetch Keys.dest_branch_name
    >>= fun dest_branch_name ->
    fetch Keys.branch_name
    >>= fun branch_name ->
    let repo_config_raw' =
      if branch = branch_name then Keys.repo_config_raw' else Keys.repo_config_dest_branch_raw'
    in
    fetch repo_config_raw'
    >>= fun (_, repo_config_raw) ->
    (* The two trees are compared through the ids that the script writes, so the
       same script has to build both.  The rest of the configuration stays the
       one of the branch being built, but the tree builder -- both the flag and
       the script -- comes from the working branch, matching the branch that
       decided the tree would be built at all. *)
    fetch Keys.repo_config_raw'
    >>= fun (_, working_repo_config_raw) ->
    let module V1 = Terrat_base_repo_config_v1 in
    let repo_config_raw =
      V1.of_view
        {
          (V1.to_view repo_config_raw) with
          V1.View.tree_builder = V1.tree_builder working_repo_config_raw;
        }
    in
    Builder.run_db s ~f:(fun db -> create_token s db account id)
    >>| fun token ->
    let module B = Terrat_api_components.Work_manifest_build_tree in
    let config =
      repo_config_raw
      |> Terrat_base_repo_config_v1.to_version_1
      |> Terrat_repo_config.Version_1.to_yojson
    in
    let response =
      Terrat_api_components.Work_manifest.Work_manifest_build_tree
        { B.base_ref = S.Api.Ref.to_string dest_branch_name; token; type_ = `Build_tree; config }
    in
    response

  let fail ~branch work_manifest s { Bs.Fetcher.fetch } =
    let open Irm in
    fetch Keys.account
    >>= fun account ->
    fetch Keys.repo
    >>= fun repo ->
    fetch Keys.client
    >>= fun _client ->
    fetch Keys.branch_ref
    >>= fun branch_ref ->
    fetch Keys.branch_name
    >>= fun branch_name ->
    let module Status = Terrat_commit_check.Status in
    let check =
      S.Commit_check.make_str
        ~config:(Builder.State.config s)
        ~description:"Failed"
        ~status:Status.Failed
        ~work_manifest
        ~repo
        ~account
        (status_name ~branch ~branch_name)
    in
    fetch Keys.create_commit_checks
    >>= fun create_commit_checks -> create_commit_checks' create_commit_checks branch_ref [ check ]

  let result ~branch ~branch_ref work_manifest result s { Bs.Fetcher.fetch } =
    let open Irm in
    match result with
    | Wmr.Work_manifest_build_tree_result { Bt.files } ->
        fetch Keys.account
        >>= fun account ->
        fetch Keys.reruns
        >>= fun reruns ->
        (* The tree of a commit is written in blocks of 500 rows and can run to
           tens of thousands of them, all keyed by the commit, so every other
           job that needs the same tree waits on those rows until this
           transaction commits -- which is after the rest of the job, GitHub
           calls included.  Commit the tree on its own and ask to be re-run, so
           the rows are held for the write and nothing more.

           On the second pass the payload is in [reruns], which the driver only
           records after the transaction committed, so the tree is durable and
           the rest of this branch runs exactly once. *)
        let rerun_id =
          Printf.sprintf
            "repo_tree:%s:%s"
            (S.Api.Account.Id.to_string @@ S.Api.Account.id account)
            (S.Api.Ref.to_string branch_ref)
        in
        (if CCList.mem ~eq:CCString.equal rerun_id reruns then Abbs_future_combinators.return_ok ()
         else (
           Logs.info (fun m ->
               m
                 "%s : REPO_TREE : STORE : branch_ref=%s"
                 (Builder.log_id s)
                 (S.Api.Ref.to_string branch_ref));
           Builder.run_db s ~f:(fun db -> store_repo_tree s db account branch_ref files)
           >>? fun () -> Error (`Rerun [ rerun_id ])))
        >>= fun () ->
        fetch Keys.repo
        >>= fun repo ->
        fetch Keys.branch_ref
        >>= fun branch_ref ->
        fetch Keys.branch_name
        >>= fun branch_name ->
        let module Status = Terrat_commit_check.Status in
        let check =
          S.Commit_check.make_str
            ~config:(Builder.State.config s)
            ~description:"Completed"
            ~status:Status.Completed
            ~work_manifest
            ~repo
            ~account
            (status_name ~branch ~branch_name)
        in
        fetch Keys.create_commit_checks
        >>= fun create_commit_checks ->
        create_commit_checks' create_commit_checks branch_ref [ check ]
    | Wmr.Work_manifest_build_result_failure { Bf.msg } ->
        fetch Keys.account
        >>= fun account ->
        fetch Keys.repo
        >>= fun repo ->
        fetch Keys.branch_ref
        >>= fun branch_ref ->
        fetch Keys.branch_name
        >>= fun branch_name ->
        let module Status = Terrat_commit_check.Status in
        let check =
          S.Commit_check.make_str
            ~config:(Builder.State.config s)
            ~description:"Failed"
            ~status:Status.Failed
            ~work_manifest
            ~repo
            ~account
            (status_name ~branch ~branch_name)
        in
        fetch Keys.create_commit_checks
        >>= fun create_commit_checks ->
        create_commit_checks' create_commit_checks branch_ref [ check ]
        >>= fun () ->
        fetch Keys.publish_comment
        >>= fun publish_comment ->
        publish_comment' publish_comment (Msg.Build_tree_failure msg)
        >>? fun () ->
        (* The tree was not built.  Stop here rather than return [Ok], which
           marks the work manifest completed and sends whoever wanted the tree
           looking for one that does not exist. *)
        Error `Silent_failure
    | Wmr.Work_manifest_build_config_result _ -> assert false
    | Terrat_api_components_work_manifest_result.Work_manifest_tf_operation_result _ -> assert false
    | Terrat_api_components_work_manifest_result.Work_manifest_tf_operation_result2 _ ->
        assert false
    | Terrat_api_components_work_manifest_result.Work_manifest_index_result _ -> assert false

  let run ~dest_branch_ref ~branch_ref ~branch ~name =
    Wm_sm.run
      ~name
      ~eq:(eq dest_branch_ref branch_ref)
      ~dest_branch_ref
      ~branch_ref
      ~branch
      ~create
      ~initiate:(initiate ~branch)
      ~fail:(fail ~branch)
      ~result:(result ~branch ~branch_ref)
end
