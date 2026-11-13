module Make
    (S : Terrat_vcs_provider2.S)
    (Keys : module type of Terrat_vcs_event_evaluator2_targets.Make (S)) : sig
  module Builder : module type of Terrat_vcs_event_evaluator2_builder.Make (S)

  val run :
    name:string ->
    (Builder.Bs.state -> Builder.Bs.Fetcher.t -> ('v, Builder.err) result Abb.Future.t) ->
    Builder.Bs.key_repr list ->
    Builder.Bs.state ->
    Builder.Bs.Fetcher.t ->
    ('v, Builder.err) result Abb.Future.t

  (** Publish a comment, turning a publish failure into [`Silent_failure] so that error handlers do
      not answer a failed publish by publishing again. *)
  val publish_comment' :
    ('msg -> (unit, [ `Error ]) result Abb.Future.t) ->
    'msg ->
    (unit, [> `Silent_failure ]) result Abb.Future.t

  (** Create commit checks, skipping the call entirely when there is nothing to create so that the
      commit checks are not dirtied. *)
  val create_commit_checks' :
    (S.Api.Ref.t ->
    Terrat_commit_check.t list ->
    (unit, Terrat_vcs_api.call_err) result Abb.Future.t) ->
    S.Api.Ref.t ->
    Terrat_commit_check.t list ->
    ( unit,
      [> `Vcs_api_err of string
      | `Vcs_api_rate_limit_err of string
      | `Vcs_api_timeout_err of string
      ] )
    result
    Abb.Future.t

  (** The task that publishes commit checks. The PR flow and the branch flow register the same task:
      the body is identical for the two, and the ref that receives the checks is an argument of the
      returned function. *)
  val create_commit_checks :
    Builder.Bs.key_repr list ->
    Builder.Bs.state ->
    Builder.Bs.Fetcher.t ->
    ( S.Api.Ref.t ->
      Terrat_commit_check.t list ->
      (unit, Terrat_vcs_api.call_err) result Abb.Future.t,
      Builder.err )
    result
    Abb.Future.t

  (** The paths whose contents differ between the stored tree of [base_ref] and the stored tree of
      the given ref, with the time of the query in the log. *)
  val query_repo_tree_changes :
    base_ref:S.Api.Ref.t ->
    Builder.Bs.state ->
    S.Db.t ->
    S.Api.Account.t ->
    S.Api.Ref.t ->
    (string list, [> `Error ]) result Abb.Future.t

  (** [abort_work_manifest s db work_manifest_id run_id] records [run_id] as the run of the work
      manifest and aborts it. A run that took a work manifest and cannot operate on it gives it
      back, thus the job can make its work again. Every abort of a taken work manifest goes through
      here, so that they all write the same state. *)
  val abort_work_manifest :
    Builder.Bs.state -> S.Db.t -> Uuidm.t -> string -> (unit, [> `Error ]) result Abb.Future.t

  (** The dirspaces of [config] that the given paths change. It uses the change match of a pull
      request diff, thus the file patterns and the dependencies of a dirspace count. *)
  val dirspaces_of_paths :
    Terrat_change_match3.Config.t -> string list -> Terrat_data.Dirspace_set.t

  (** Whether a dirspace run by [workflow] applies in parallel with the same dirspace of other pull
      requests, rather than behind their locks: the edition allows it, and the dirspace runs the
      Stategraph engine, whatever its lock policy. That is the engine of [workflow] or, for a
      dirspace that no workflow matches, the engine of [repo_config]. Nothing is recorded: the
      answer is read off the configuration each time it is asked. *)
  val stategraph_parallel_apply :
    'a Terrat_base_repo_config_v1.t -> Terrat_base_repo_config_v1.Workflows.Entry.t option -> bool

  (** The dirspaces of [dirspaceflows] that apply in parallel, by {!stategraph_parallel_apply}. *)
  val stategraph_parallel_apply_dirspaces :
    'a Terrat_base_repo_config_v1.t ->
    Terrat_change.Dirspaceflow.Workflow.t option Terrat_change.Dirspaceflow.t list ->
    Terrat_change.Dirspace.t list

  (** The same for the changes of a work manifest, which name their workflow by its index in the
      workflows of [repo_config]. *)
  val stategraph_parallel_apply_dirspaces_of_work_manifest :
    'a Terrat_base_repo_config_v1.t ->
    int option Terrat_change.Dirspaceflow.t list ->
    Terrat_change.Dirspace.t list

  (** Reserve, for the apply work manifest, the Stategraph transactions of the pull request's plans
      of [dirspaces], through [S.Stategraph]: from now until the apply commits them or the work
      manifest ends, Stategraph refuses an overlapping commit of another transaction. A failure is
      logged and not an error: the commit decides on its own without the reservation. *)
  val reserve_stategraph_plans :
    request_id:string ->
    S.Db.t ->
    'diff S.Api.Pull_request.t ->
    Uuidm.t ->
    Terrat_change.Dirspace.t list ->
    unit Abb.Future.t

  (** The work manifest is over: give back the transactions it reserved and did not commit, the
      counterpart of [reserve_stategraph_plans], and let go of the hold of the commit it made when
      its pull request is merged, closed or unlocked already (the apply a merge starts, or the apply
      a merge or a close raced, commits held with no merge to come). The same silence. *)
  val release_stategraph_reservation : request_id:string -> S.Db.t -> Uuidm.t -> unit Abb.Future.t

  (** Let go of the holds of the pull request's applies, through [S.Stategraph]: the pull request
      merged, was closed or was unlocked, so a plan made after its applies no longer reverts them,
      or no longer counts. A failure is logged and not an error: a hold this misses waits for
      [terrateam unlock]. *)
  val release_stategraph_holds :
    request_id:string -> S.Db.t -> S.Api.Repo.t -> S.Api.Pull_request.Id.t -> unit Abb.Future.t

  (** Unlock one id: the dirspace locks it names ([S.Db.unlock]) and, for a pull request, the holds
      of its applies ({!release_stategraph_holds}), as the runs before an unlock no longer count. *)
  val unlock :
    request_id:string ->
    S.Db.t ->
    S.Api.Repo.t ->
    S.Unlock_id.t ->
    (unit, [> `Error ]) result Abb.Future.t

  (** The hash of a repository config, the part of the key of a built config that follows the config
      the build used. *)
  val repo_config_hash : Terrat_base_repo_config_v1.raw Terrat_base_repo_config_v1.t -> string

  (** The key under which the config builder stores the config it built for [ref_] from
      [repo_config]. A built config belongs to a commit and to the config that the build read. *)
  val build_config_cache_ref :
    S.Api.Ref.t -> Terrat_base_repo_config_v1.raw Terrat_base_repo_config_v1.t -> S.Api.Ref.t

  (** [changed_between ~from_ref ~to_ref] is the set of dirspaces of [config] with a file that
      changed between the two commits, or [None] when the two commits cannot be compared: the tree
      of one commit is not stored, or the config builder is on and the config of [to_ref] is not
      built yet.

      A commit can move while a run operates, and only a change to the files of a dirspace makes the
      run stale (RFD 2356). [missing_tree] says what to do with a tree that is not stored. With
      [`Fetch], and the tree builder off, the tree is read from the forge and stored. With
      [`Unknown], or with the tree builder on, the answer is [None]. The call never waits for a tree
      build or a config build: a caller that must answer now gets [None] instead. *)
  val changed_between :
    Builder.Bs.state ->
    missing_tree:[ `Fetch of S.Api.Client.t * S.Api.Repo.t | `Unknown ] ->
    config:Terrat_change_match3.Config.t ->
    repo_config_raw:Terrat_base_repo_config_v1.raw Terrat_base_repo_config_v1.t ->
    account:S.Api.Account.t ->
    from_ref:S.Api.Ref.t ->
    to_ref:S.Api.Ref.t ->
    (Terrat_data.Dirspace_set.t option, Builder.err) result Abb.Future.t

  (** [pending_apply_check ~config ~account ~repo ~apply_requirements ~commit_checks matches] is the
      waiting [terrateam apply] check, when the repository asks for one and [commit_checks] has no
      [terrateam apply] check yet. The check holds the pull request until it is applied. A run that
      matches no dirspace gets none: it has nothing to wait for, and its apply check is created
      completed when the run finishes. *)
  val pending_apply_check :
    config:S.Api.Config.t ->
    account:S.Api.Account.t ->
    repo:S.Api.Repo.t ->
    apply_requirements:Terrat_base_repo_config_v1.Apply_requirements.t ->
    commit_checks:Terrat_commit_check.t list ->
    'a list ->
    Terrat_commit_check.t list

  (** Create the completed [terrateam apply] commit check at the head of the pull request.

      A pull request that reached a noop still has to be mergeable, thus an operator who needs that
      check green to merge gets it even though no work was done. The caller decides that no work is
      left; this reads no matches of its own, so a caller that must not start a setup job can use
      it.

      [description] is the wording of the check. It is required, thus each caller states why the run
      closed; {!apply_check_description} computes it. *)
  val create_completed_apply_check :
    description:string ->
    Builder.Bs.state ->
    Builder.Bs.Fetcher.t ->
    (unit, Builder.err) result Abb.Future.t

  (** The wording of a completed apply check, from why the run closed. [`Changes]: a plan found
      changes and an apply applied them. [`No_changes]: every plan came back clean, thus nothing was
      applied, and the check says so rather than "Completed". [`Not_run]: no plan of the run is
      known, for instance because a precheck stopped the run; that is not a run without changes,
      thus it reads "Completed". Every writer of an apply check takes its wording from here, so they
      all agree.

      A check belongs to one head commit, thus the wording describes that head only. When an earlier
      head of the pull request was applied and a later push leaves every plan without changes, the
      check on the new head reads "No Changes"; the check on the earlier head keeps "Completed". A
      pull request that only deletes a directory plans and applies nothing, thus it reads "No
      Changes" too. *)
  val apply_check_description : [< `Changes | `No_changes | `Not_run ] -> string

  (** The most recent successful plan and the most recent successful apply of each given dirspace of
      the context, timed and logged. *)
  val query_dirspace_runs_for_context :
    Builder.State.t ->
    S.Stacks.db ->
    (S.Api.Pull_request.Id.t, S.Api.Ref.t) Terrat_job_context.Context.t ->
    Terrat_change.Dirspace.t list ->
    (Terrat_vcs_provider2.Dirspace_runs.t list, [> `Error ]) result Abb.Future.t

  (** The comment, if any, to publish for an evaluation error. [None] means publish nothing: either
      nothing went wrong or the user has already been told. *)
  val msg_of_err : Builder.err -> Keys.msg option

  (** [forward_std_keys s store] adds to [store] the values of the standard keys that the build of
      [s] computed, so that the next eval does not compute them again. An eval starts from the store
      it was made with, thus a value it does not get is computed again.

      A key is standard when it holds the same value for the whole of one event:
      - It is a function of a commit sha or of an account, and not of a branch name. The ref of a
        branch can move while a job operates, thus [branch_ref], [dest_branch_ref] and all that
        comes from them are not standard.
      - The evaluation does not write it. [commit_checks] and [work_manifests_for_job] change when
        the evaluation writes, thus they are not standard.
      - The forge does not change it during the event. The mergeable state of a pull request can
        change, thus it has a key of its own.

      The pull request is standard: an event reads it once. A caller that must know the head of a
      branch at a later time reads the forge again. [client] is not standard, because it is a handle
      and not a value. *)
  val forward_std_keys : Builder.State.t -> Builder.Hmap.t -> Builder.Hmap.t
end
