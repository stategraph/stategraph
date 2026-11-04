module Irm = Abbs_fc.Infix_result_monad
module Tjc = Terrat_job_context

let unreasonable_number_of_aborts = 10

module Make
    (S : Terrat_vcs_provider2.S)
    (Keys : module type of Terrat_vcs_event_evaluator2_targets.Make (S)) =
struct
  let src = Logs.Src.create ("vcs_event_evaluator2_wm_sm." ^ S.name)

  module Logs = (val Logs.src_log src : Logs.LOG)
  module Compute_node = Terrat_vcs_event_evaluator2_compute_node
  module Wm = Terrat_work_manifest3
  module Builder = Terrat_vcs_event_evaluator2_builder.Make (S)
  module Tasks_base = Terrat_vcs_event_evaluator2_tasks_base.Make (S) (Keys)

  let time_it s l f =
    Abbs_time_it.run (fun time -> Logs.info (fun m -> l m (Builder.log_id s) time)) f

  type existing_wm =
    ( S.Api.Account.t,
      (unit S.Api.Pull_request.t, S.Api.Repo.t) Terrat_vcs_provider2.Target.t )
    Terrat_work_manifest3.Existing.t
  [@@deriving show]

  let publish_comment' f msg = Tasks_base.publish_comment' f msg

  let create_token installation_id work_manifest_id db =
    let open Abbs_fc.Infix_result_monad in
    Terrat_user.create_system_user
      ~access_token_id:work_manifest_id
      ~capabilities:
        Terrat_user.Capability.
          [
            Installation_id (S.Api.Account.Id.to_string installation_id);
            Kv_store_read;
            Kv_store_write;
          ]
      db
    >>= fun user -> Terrat_user.Token.to_token db user

  let create_token' ~log_id installation_id work_manifest_id db =
    let open Abb.Future.Infix_monad in
    create_token installation_id work_manifest_id db
    >>= function
    | Ok _ as r -> Abb.Future.return r
    | Error (#Terrat_user.Token.to_token_err as err) ->
        Logs.err (fun m -> m "%s : CREATE_TOKEN : %a" log_id Terrat_user.Token.pp_to_token_err err);
        Abbs_fc.return_err (`Msg_err "CREATE_TOKEN")

  let match_tag_queries ~accessor ~changes queries =
    CCList.map
      (fun change ->
        ( change,
          CCList.find_idx
            (fun q -> Terrat_change_match3.match_tag_query ~tag_query:(accessor q) change)
            queries ))
      changes

  let replace_stack_vars vars s = Str_template.apply (CCFun.flip Sln_map.String.find_opt vars) s

  let apply_stack_vars_to_workflow stack workflow =
    let module R = Terrat_base_repo_config_v1 in
    let module E = R.Workflows.Entry in
    let module S = R.Stacks.Stack in
    let {
      E.apply = _;
      engine = _;
      environment;
      integrations = _;
      lock_policy = _;
      plan = _;
      runs_on = _;
      storage = _;
      tag_query = _;
    } =
      workflow
    in
    let open CCResult.Infix in
    CCResult.opt_map (replace_stack_vars stack.S.variables) environment
    >>= fun environment -> Ok { workflow with E.environment }

  let dirspaceflows_of_changes_with_branch_target repo_config changes =
    let module R = Terrat_base_repo_config_v1 in
    let module S = R.Stacks in
    let workflows = R.workflows repo_config in
    CCResult.map_l
      (fun ( {
               Terrat_change_match3.Dirspace_config.dirspace;
               lock_branch_target;
               stack_config = { S.Stack.variables; _ } as stack_config;
               _;
             },
             workflow )
         ->
        let open CCResult.Infix in
        let module Dsf = Terrat_change.Dirspaceflow in
        CCResult.opt_map
          (fun (idx, workflow) ->
            let open CCResult.Infix in
            apply_stack_vars_to_workflow stack_config workflow
            >>= fun workflow -> Ok { Dsf.Workflow.idx; workflow })
          workflow
        >>= fun workflow ->
        Ok { Dsf.dirspace; workflow = (lock_branch_target, workflow); variables = Some variables })
      (match_tag_queries
         ~accessor:(fun { R.Workflows.Entry.tag_query; _ } -> tag_query)
         ~changes
         workflows)

  let strip_lock_branch_target dsfs =
    let module Dsf = Terrat_change.Dirspaceflow in
    CCList.map (fun ({ Dsf.workflow = _, workflow; _ } as dsf) -> { dsf with Dsf.workflow }) dsfs

  let dirspaceflows_of_changes repo_config changes =
    let open CCResult.Infix in
    dirspaceflows_of_changes_with_branch_target repo_config changes
    >>= fun dirspaceflows -> Ok (strip_lock_branch_target dirspaceflows)

  let update_wm_state ~request_id ~name work_manifest_id state db =
    Logs.info (fun m ->
        m
          "%s : WM : UPDATE_STATE : name=%s : wm=%a : state=%s"
          request_id
          name
          Uuidm.pp
          work_manifest_id
          (Terrat_work_manifest3.State.to_string state));
    S.Work_manifest.update_state ~request_id db work_manifest_id state

  let update_run_id s name id run_id db =
    time_it
      s
      (fun m log_id time ->
        m
          "%s : WM : UPDATE_RUN_ID : name=%s : wm=%a : run_id=%s : time=%f"
          log_id
          name
          Uuidm.pp
          id
          run_id
          time)
      (fun () ->
        let open Irm in
        S.Work_manifest.update_run_id ~request_id:(Builder.log_id s) db id run_id
        >>= fun () -> update_wm_state ~request_id:(Builder.log_id s) ~name id Wm.State.Running db)

  let set_work s compute_node_id id response db =
    time_it
      s
      (fun m log_id time ->
        m "%s : WM : SET_WORK : compute_node_id=%a : time=%f" log_id Uuidm.pp compute_node_id time)
      (fun () ->
        S.Job_context.Compute_node.set_work
          ~request_id:(Builder.log_id s)
          ~compute_node_id
          ~work_manifest:id
          db
          response)

  (* Every new work manifest gets a compute node in the state [queued], and a
     row in [compute_node_work] with no work.  The dispatcher starts a node that
     is [queued], and the first poll of the run fills the row.  The database
     chooses the id of the node, so it has nothing to do with the id of the work
     manifest. *)
  (* [Compute_node] holds the two rules that need no VCS: what a node made for
     one work manifest can do, and whether a node that is going can take one
     more.  They sit outside this functor so that a test can ask them without
     standing up a provider. *)
  let capabilities_of = Compute_node.capabilities_of

  let create_compute_node s ({ Wm.id; _ } as work_manifest) db =
    time_it
      s
      (fun m log_id time ->
        m "%s : WM : CREATE_COMPUTE_NODE : work_manifest_id=%a : time=%f" log_id Uuidm.pp id time)
      (fun () ->
        let open Irm in
        S.Job_context.Compute_node.create
          ~request_id:(Builder.log_id s)
          ~capabilities:(capabilities_of work_manifest)
          db
        >>= fun ({ Tjc.Compute_node.id = compute_node_id; _ } as compute_node) ->
        S.Job_context.Compute_node.add_work
          ~request_id:(Builder.log_id s)
          ~compute_node_id
          ~work_manifest:id
          db
        >>| fun () -> compute_node)

  (* The configuration that the repository holds gives the limit.  A step that
     prepares a job runs before a built configuration exists, thus the built
     configuration cannot give it, and the limit must be the same for each step
     of a job. *)
  let merge_steps_of repo_config =
    let module V1 = Terrat_base_repo_config_v1 in
    (V1.batch_runs repo_config).V1.Batch_runs.merge_steps

  (* The cap is read from the same configuration value as [merge_steps], and for
     the same reason: a step that prepares a job runs before a built configuration
     exists.  [batch_runs.enabled] does not gate it, as it does not gate
     [merge_steps].

     The configuration bounds the value between one and nine, so the answer is
     already the cap a node may use.  The unique index
     [compute_node_work_wm_state_idx] is gone
     ([migrations/2026-10-23-drop-compute-node-work-wm-state-index.sql]), so a
     node may hold several rows in the state [created]. *)
  let max_work_manifests_per_node_of repo_config =
    let module V1 = Terrat_base_repo_config_v1 in
    (V1.batch_runs repo_config).V1.Batch_runs.max_work_manifests_per_node

  let can_run = Compute_node.can_run

  (* Give a compute node another work manifest.  Only [node_that_can_take_it] may
     answer for this, because it re-reads the node under its row lock and asks
     [can_run], which is what bounds how much work a node takes.

     The work manifest that ran before this one leaves the state [created] on its
     own.  The [Result] branch of [run] calls [update_state_completed] for it,
     and that write fires the trigger
     [work_manifest_compute_node_work_state_trigger], which moves the row of the
     node out of [created]. *)
  let attach_to_compute_node s compute_node { Wm.id; _ } db =
    let module C = Tjc.Compute_node in
    let module Cap = C.Capabilities in
    time_it
      s
      (fun m log_id time ->
        m
          "%s : WM : ATTACH_COMPUTE_NODE : compute_node_id=%a : work_manifest_id=%a : time=%f"
          log_id
          Uuidm.pp
          compute_node.C.id
          Uuidm.pp
          id
          time)
      (fun () ->
        let open Irm in
        S.Job_context.Compute_node.add_work
          ~request_id:(Builder.log_id s)
          ~compute_node_id:compute_node.C.id
          ~work_manifest:id
          db
        >>= fun () ->
        S.Job_context.Compute_node.update_capabilities
          ~request_id:(Builder.log_id s)
          ~compute_node_id:compute_node.C.id
          db
          {
            compute_node.C.capabilities with
            Cap.used_work_manifests = compute_node.C.capabilities.Cap.used_work_manifests + 1;
          })

  (* The compute node of this evaluation, when that node can take this work
     manifest as well.

     Ask the database, and not the node in the store.  That node is a snapshot of
     the transaction that put it there.  The chain of layers evaluates the next
     layer in a transaction of its own, so the snapshot is one transaction old:
     the node may have taken work since, and its count may have moved.

     The read takes the row lock of the node: [select_compute_node.sql] ends in
     [for update of cn], so the count that [can_run] reads is the count of the
     committed transaction, and two evaluations cannot both see room for one work
     manifest.  That lock is what keeps [used_work_manifests] authoritative now
     that [compute_node_work_wm_state_idx] is gone.  The database no longer
     refuses a second row in the state [created] for one node, so the count in
     [can_run] is the only bound. *)
  let node_that_can_take_it
      ~merge_steps
      ~max_work_manifests_per_node
      s
      compute_node
      work_manifest
      db =
    let module C = Tjc.Compute_node in
    let open Irm in
    match compute_node with
    | Some { C.id = compute_node_id; _ } -> (
        S.Job_context.Compute_node.query ~request_id:(Builder.log_id s) ~compute_node_id db
        >>= function
        | Some compute_node
          when can_run ~merge_steps ~max_work_manifests_per_node compute_node work_manifest ->
            Abbs_fc.return_ok (Some compute_node)
        | Some _ | None -> Abbs_fc.return_ok None)
    | None -> Abbs_fc.return_ok None

  (* Give the new work manifests of this evaluation their compute nodes.

     The work of one call is spread evenly over as few nodes as the cap requires,
     and each group fills one node.  The node of this evaluation fills the first
     group, so a call that makes one node's worth of work keeps it on the node that
     is already going.  Every later group fills a node that this call makes.

     A group spills onto a second node when the node it fills has no room left, or
     when [merge_steps] does not let one of its work manifests join that node.
     [can_run] decides both, under the row lock of the node. *)
  let make_compute_nodes ~compute_node ~merge_steps ~max_work_manifests_per_node s wms db =
    let open Irm in
    let fill compute_node group =
      Abbs_fc.List_result.fold_left
        ~f:(fun compute_node wm ->
          node_that_can_take_it ~merge_steps ~max_work_manifests_per_node s compute_node wm db
          >>= function
          | Some compute_node ->
              attach_to_compute_node s compute_node wm db >>| fun () -> Some compute_node
          | None -> create_compute_node s wm db >>| fun compute_node -> Some compute_node)
        ~init:compute_node
        group
      >>| fun _ -> ()
    in
    match Compute_node.spread_over_nodes ~max_per_node:max_work_manifests_per_node wms with
    | [] -> Abbs_fc.return_ok ()
    | first :: rest ->
        fill compute_node first
        >>= fun () -> Abbs_fc.List_result.iter ~f:(fun group -> fill None group) rest

  let update_state_completed s name work_manifest_id db =
    let open Abbs_fc.Infix_result_monad in
    time_it
      s
      (fun m log_id time ->
        m
          "%s : WM : UPDATE_STATE : COMPLETED : wm=%a : time=%f"
          log_id
          Uuidm.pp
          work_manifest_id
          time)
      (fun () ->
        update_wm_state ~request_id:(Builder.log_id s) ~name work_manifest_id Wm.State.Completed db)
    >>= fun () ->
    Abbs_fc.to_result
      (Tasks_base.release_stategraph_reservation ~request_id:(Builder.log_id s) work_manifest_id)

  let query_work_manifests s job_id db =
    time_it
      s
      (fun m log_id time ->
        m "%s : JOB : QUERY_WORK_MANIFESTS : job_id=%a : time=%f" log_id Uuidm.pp job_id time)
      (fun () ->
        S.Job_context.Job.query_work_manifests ~request_id:(Builder.log_id s) db ~job_id ())

  let add_work_manifests s job_id wms db =
    time_it
      s
      (fun m log_id time ->
        m "%s : JOB : ADD_WORK_MANIFESTS : job_id=%a : time=%f" log_id Uuidm.pp job_id time)
      (fun () ->
        Abbs_fc.List_result.iter
          ~f:(fun { Wm.id = work_manifest_id; _ } ->
            S.Job_context.Job.add_work_manifest
              ~request_id:(Builder.log_id s)
              db
              ~job_id
              ~work_manifest_id
              ())
          wms)

  let num_aborts wms =
    CCList.length
    @@ CCList.filter
         (fun { Terrat_work_manifest3.state; _ } -> state = Terrat_work_manifest3.State.Aborted)
         wms

  let too_many_aborts wms = unreasonable_number_of_aborts < num_aborts wms

  let all_wms_completed =
    CCList.for_all (function
      | { Wm.state = Wm.State.Completed; _ } -> true
      | _ -> false)

  let rem_aborted =
    CCList.filter (function
      | { Wm.state = Wm.State.Aborted; _ } -> false
      | _ -> true)

  let publish_fail _s { Builder.Bs.Fetcher.fetch } = function
    | (`Failed_to_start_with_msg_err _ | `Failed_to_start | `Missing_workflow) as err ->
        let open Irm in
        fetch Keys.publish_comment
        >>= fun publish_comment ->
        publish_comment' publish_comment (Terrat_vcs_provider2.Msg.Run_work_manifest_err err)
    | `Job_failed run_id ->
        let open Irm in
        fetch Keys.publish_comment
        >>= fun publish_comment ->
        publish_comment'
          publish_comment
          (Terrat_vcs_provider2.Msg.Work_manifest_run_failed { run_id })
    | `Result_handling_err ->
        (* The evaluation that failed has already published its own message. *)
        Abbs_fc.return_ok ()
    | `Error ->
        (* Dispatching the work manifest failed, so nothing has run and nothing
           else has spoken to the user. *)
        let open Irm in
        fetch Keys.publish_comment
        >>= fun publish_comment ->
        publish_comment'
          publish_comment
          Terrat_vcs_provider2.Msg.(Operation_failed `Work_manifest_start_err)

  type start =
    | Run of {
        head : S.Api.Ref.t option;
        dest_head : S.Api.Ref.t option;
      }
    | Restart

  type membership =
    | Refs of {
        steps : Wm.Step.t list;
        eq : existing_wm -> bool;
        stored :
          Builder.B.State.t -> Builder.Bs.Fetcher.t -> (bool, Builder.err) result Abb.Future.t;
      }
    | Steps of {
        steps : Wm.Step.t list;
        start :
          sha:S.Api.Ref.t ->
          existing_wm ->
          Builder.B.State.t ->
          Builder.Bs.Fetcher.t ->
          (start, Builder.err) result Abb.Future.t;
        superseded :
          existing_wm list ->
          Builder.B.State.t ->
          Builder.Bs.Fetcher.t ->
          (bool, Builder.err) result Abb.Future.t;
      }

  let is_aborted wm =
    match wm.Wm.state with
    | Wm.State.Aborted -> true
    | Wm.State.(Queued | Running | Completed) -> false

  let run
      ~name
      ~membership
      ~dest_branch_ref
      ~branch_ref
      ~branch
      ~create
      ~initiate
      ~fail
      ~result
      s
      ({ Builder.Bs.Fetcher.fetch } as fetcher) =
    let open Irm in
    let module E = Keys.Work_manifest_event in
    Logs.info (fun m -> m "%s : WM : RUN : name=%s" (Builder.log_id s) name);
    (* A slot made the work manifests it holds.  A plan or an apply slot knows them by their steps:
       one job has one such slot, and its refs can move while a run operates.  A setup slot knows
       them by their refs, because what it makes is for one commit and two setup slots of a job can
       share their steps. *)
    let in_slot =
      match membership with
      | Refs { eq; steps = _; stored = _ } -> eq
      | Steps { steps; start = _; superseded = _ } ->
          fun wm -> CCList.equal Wm.Step.equal wm.Wm.steps steps
    in
    (* A setup work manifest of this slot whose refs moved after it ran.  Its result is for a commit
       that this evaluation no longer asks about, and the result handler stores what it made under
       the refs of this evaluation, thus the result is not handled: the work manifest is completed
       so that it holds nothing, and the next operation computes the data again.

       Two setup slots of a job share their steps: one works on the destination branch, with the
       same ref twice, and one on the working branch.  A work manifest of the other slot is not
       stale, it is not ours, thus both sides of the question must be about the same branch. *)
    let stale_setup wm =
      match membership with
      | Refs { eq; steps; stored = _ } ->
          let slot_on_dest = S.Api.Ref.equal dest_branch_ref branch_ref in
          let wm_on_dest = CCString.equal wm.Wm.base_ref wm.Wm.branch_ref in
          (not (eq wm))
          && CCList.equal Wm.Step.equal wm.Wm.steps steps
          && CCBool.equal slot_on_dest wm_on_dest
      | Steps _ -> false
    in
    (* Work made in an evaluation with pinned refs would run at the commit of an older run, thus it
       waits: an evaluation which reads the refs live makes it.  A setup slot whose data is stored
       has no work to make, thus it does not wait: the start of a run needs that data, and a start
       that waits is never answered. *)
    let create_wms () =
      fetch Keys.refs
      >>= function
      | Keys.Refs.Pinned_run -> (
          (match membership with
            | Refs { stored; eq = _; steps = _ } -> stored s fetcher
            | Steps _ -> Abbs_fc.return_ok false)
          >>= function
          | true ->
              Logs.info (fun m ->
                  m "%s : WM : CREATE : PINNED_STORED : name=%s" (Builder.log_id s) name);
              Abbs_fc.return_ok []
          | false ->
              Logs.info (fun m ->
                  m "%s : WM : CREATE : PINNED_NO_CREATE : name=%s" (Builder.log_id s) name);
              Abbs_fc.return_err (`Suspend_eval name))
      | Keys.Refs.Live -> (
          Logs.info (fun m -> m "%s : WM : CREATE : name=%s" (Builder.log_id s) name);
          create ~dest_branch_ref ~branch_ref ~branch s fetcher
          >>= function
          | [] ->
              Logs.info (fun m ->
                  m "%s : WM : CREATE : name=%s : NO_WORK_MANIFESTS" (Builder.log_id s) name);
              Abbs_fc.return_ok []
          | wms ->
              CCList.iter
                (fun {
                       Terrat_work_manifest3.id;
                       base_ref;
                       branch_ref;
                       environment;
                       runs_on;
                       steps;
                       _;
                     }
                   ->
                  Logs.info (fun m ->
                      m
                        "%s : CREATED_WORK_MANIFEST : id=%a : base_ref=%s : branch_ref=%s : \
                         run_type=%s : env=%s : runs_on=%s"
                        (Builder.log_id s)
                        Uuidm.pp
                        id
                        base_ref
                        branch_ref
                        (CCOption.map_or ~default:"" Wm.Step.to_string @@ CCList.head_opt steps)
                        (CCOption.get_or ~default:"" environment)
                        (CCOption.map_or ~default:"" Yojson.Safe.to_string runs_on)))
                wms;
              fetch Keys.job
              >>= fun job ->
              Builder.run_db s ~f:(fun db -> add_work_manifests s job.Tjc.Job.id wms db)
              >>= fun () ->
              (* Read [Keys.compute_node], and not [Keys.compute_node_id].
             The server makes these work manifests while it reads the
             results of a run, and the results entry point adds the
             node to the store, not its id.

             Never read the work manifest event here.  The chain of
             layers evaluates the next layer with no event, and the
             node of that evaluation must still be able to take it. *)
              fetch Keys.compute_node
              >>= fun compute_node ->
              (* Read the configuration that the repository holds, and
             not the one that the config builder makes.  A step that
             prepares a job runs before a built configuration
             exists. *)
              fetch Keys.repo_config_raw'
              >>= fun (_, repo_config_raw) ->
              let merge_steps = merge_steps_of repo_config_raw in
              let max_work_manifests_per_node = max_work_manifests_per_node_of repo_config_raw in
              Builder.run_db s ~f:(fun db ->
                  make_compute_nodes
                    ~compute_node
                    ~merge_steps
                    ~max_work_manifests_per_node
                    s
                    wms
                    db)
              >>? fun () -> Error (`Suspend_eval name))
    in
    (* Decide what the slot does now from the work manifests of the job.

       An aborted work manifest leaves work undone.  When no live work manifest of the slot covers
       its dirspaces, the slot makes the work again, now, at the refs of this evaluation: a start
       that the commits moved under was aborted so that this happens.  The one exception is a plan
       that newer plans of the pull request superseded: they plan each of its dirspaces, thus this
       job has nothing left to do. *)
    let settle job_wms =
      if too_many_aborts job_wms then (
        Logs.info (fun m -> m "%s : WM : TOO_MANY_ABORTS" (Builder.log_id s));
        Abbs_fc.return_err (`Compute_aborted_err (num_aborts job_wms)))
      else
        let slot_wms = CCList.filter in_slot job_wms in
        let live = rem_aborted slot_wms in
        let aborted = CCList.filter is_aborted slot_wms in
        let uncovered =
          Terrat_vcs_event_evaluator2_staleness.Start.uncovered_dirspaces ~live aborted
        in
        match live with
        | [] when aborted <> [] -> (
            (match membership with
              | Steps { superseded; start = _; steps = _ } -> superseded aborted s fetcher
              | Refs _ -> Abbs_fc.return_ok false)
            >>= function
            | true ->
                Logs.info (fun m -> m "%s : WM : SUPERSEDED : name=%s" (Builder.log_id s) name);
                Abbs_fc.return_err `Noop
            | false -> create_wms ())
        | [] -> create_wms ()
        | live when not (all_wms_completed live) ->
            Logs.info (fun m ->
                m "%s : WM : SETTLE : name=%s : not_all_wms_completed" (Builder.log_id s) name);
            Abbs_fc.return_err (`Suspend_eval name)
        | live when Terrat_data.Dirspace_set.is_empty uncovered ->
            Logs.info (fun m ->
                m "%s : WM : SETTLE : name=%s : all_wms_completed" (Builder.log_id s) name);
            Abbs_fc.return_ok live
        | _ ->
            Logs.info (fun m ->
                m
                  "%s : WM : SETTLE : name=%s : uncovered_aborted_dirspaces=%d"
                  (Builder.log_id s)
                  name
                  (Terrat_data.Dirspace_set.cardinal uncovered));
            create_wms ()
    in
    (* After a result or a failure the slot is over when all its work manifests are completed, and
       waits otherwise.  It never makes work here: a failure that makes its work again would retry
       without end, for example a start that the forge refuses.  An aborted work manifest also means
       "wait": the evaluation of the job without an event, or a restart, is what makes the work
       again. *)
    let finish_event job_wms =
      match CCList.filter in_slot job_wms with
      | slot_wms when all_wms_completed slot_wms ->
          Logs.info (fun m ->
              m "%s : WM : EVENT : name=%s : all_wms_completed" (Builder.log_id s) name);
          Abbs_fc.return_ok slot_wms
      | _ ->
          Logs.info (fun m ->
              m "%s : WM : EVENT : name=%s : not_all_wms_completed" (Builder.log_id s) name);
          Abbs_fc.return_err (`Suspend_eval name)
    in
    (* Explicitly query the work manifests for this job because we might have already created work
       manifests in parallel operations so we don't need to do it again. *)
    let job_wms () =
      fetch Keys.job
      >>= fun job -> Builder.run_db s ~f:(fun db -> query_work_manifests s job.Tjc.Job.id db)
    in
    fetch Keys.work_manifest_event
    >>= function
    | Some
        (E.Initiate
           {
             work_manifest = { Wm.id; state = Wm.State.(Queued | Running); _ } as work_manifest;
             run_id;
             sha;
           })
      when in_slot work_manifest -> (
        Logs.info (fun m -> m "%s : WM : INITIATE : name=%s" (Builder.log_id s) name);
        (match membership with
          | Steps { start; steps = _; superseded = _ } ->
              start ~sha:(S.Api.Ref.of_string sha) work_manifest s fetcher
          | Refs _ -> Abbs_fc.return_ok (Run { head = None; dest_head = None }))
        >>= function
        | Restart ->
            (* The commits moved before the run began and they changed its files.  Nothing ran,
               thus abort the work manifest and answer nothing.  The poll evaluates the job again
               outside of this start, which makes the work at the head now. *)
            Logs.info (fun m -> m "%s : WM : INITIATE : RESTART : name=%s" (Builder.log_id s) name);
            Builder.run_db s ~f:(fun db -> Tasks_base.abort_work_manifest s db id run_id)
            >>= fun () -> Abbs_fc.return_err (`Suspend_eval name)
        | Run { head; dest_head } ->
            Builder.run_db s ~f:(fun db -> update_run_id s name id run_id db)
            >>= fun () ->
            (if CCOption.is_some head || CCOption.is_some dest_head then
               Builder.run_db s ~f:(fun db ->
                   S.Work_manifest.update_start_refs
                     ~request_id:(Builder.log_id s)
                     db
                     id
                     ~start_sha:head
                     ~start_dest_sha:dest_head)
             else Abbs_fc.return_ok ())
            >>= fun () ->
            initiate work_manifest s fetcher
            >>= fun response ->
            fetch Keys.compute_node_id
            >>= fun compute_node_id ->
            (* An initiate event comes from a poll only, and a poll always knows its
               compute node.  Fail loudly if that stops being true. *)
            CCOption.map_or
              ~default:(Abbs_fc.return_err (`Missing_dep_err "compute_node_id"))
              (fun compute_node_id ->
                Builder.run_db s ~f:(fun db -> set_work s compute_node_id id response db))
              compute_node_id
            >>? fun () -> Error (`Suspend_eval name))
    | Some (E.Fail { work_manifest; error }) when in_slot work_manifest ->
        Logs.info (fun m -> m "%s : WM : FAIL : name=%s" (Builder.log_id s) name);
        fail work_manifest s fetcher
        >>= fun () -> publish_fail s fetcher error >>= fun () -> job_wms () >>= finish_event
    | Some (E.Result { work_manifest; result = wm_result }) when in_slot work_manifest ->
        Logs.info (fun m -> m "%s : WM : RESULT : name=%s" (Builder.log_id s) name);
        result work_manifest wm_result s fetcher
        >>= fun () ->
        (* A late result of an aborted work manifest is stored, and the work manifest stays
           aborted: the work was given to another work manifest. *)
        (if is_aborted work_manifest then Abbs_fc.return_ok ()
         else Builder.run_db s ~f:(fun db -> update_state_completed s name work_manifest.Wm.id db))
        >>= fun () -> job_wms () >>= finish_event
    | Some
        (E.Result
           {
             work_manifest =
               {
                 Wm.id;
                 state = Wm.State.(Queued | Running);
                 account = _;
                 base_ref = _;
                 branch = _;
                 branch_ref = _;
                 changes = _;
                 completed_at = _;
                 created_at = _;
                 denied_dirspaces = _;
                 environment = _;
                 initiator = _;
                 run_id = _;
                 runs_on = _;
                 steps = _;
                 tag_query = _;
                 target = _;
               } as work_manifest;
             result = _;
           })
      when stale_setup work_manifest ->
        Logs.info (fun m -> m "%s : WM : RESULT : STALE_SETUP : name=%s" (Builder.log_id s) name);
        Builder.run_db s ~f:(fun db -> update_state_completed s name id db)
        >>= fun () -> job_wms () >>= settle
    | Some _ | None -> job_wms () >>= settle
end
