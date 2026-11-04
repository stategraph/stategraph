(* The implementation reads the store of an evaluation through [Keys], but
   nothing in this signature names it, so the parameter is anonymous here. *)
module Make
    (S : Terrat_vcs_provider2.S)
    (_ : module type of Terrat_vcs_event_evaluator2_targets.Make (S)) : sig
  module Builder : module type of Terrat_vcs_event_evaluator2_builder.Make (S)

  type existing_wm =
    ( S.Api.Account.t,
      (unit S.Api.Pull_request.t, S.Api.Repo.t) Terrat_vcs_provider2.Target.t )
    Terrat_work_manifest3.Existing.t

  val create_token :
    S.Api.Account.Id.t ->
    Uuidm.t ->
    S.Db.t ->
    (string, [> Terrat_user.Token.to_token_err ]) result Abb.Future.t

  (** Same as [create_token] but logs the error and turns it into an internal failure. *)
  val create_token' :
    log_id:string ->
    S.Api.Account.Id.t ->
    Uuidm.t ->
    S.Db.t ->
    (string, [> `Msg_err of string ]) result Abb.Future.t

  val match_tag_queries :
    accessor:('a -> Terrat_tag_query.t) ->
    changes:Terrat_change_match3.Dirspace_config.t list ->
    'a list ->
    (Terrat_change_match3.Dirspace_config.t * (int * 'a) option) list

  val dirspaceflows_of_changes :
    'a Terrat_base_repo_config_v1.t ->
    Terrat_change_match3.Dirspace_config.t list ->
    ( Terrat_change.Dirspaceflow.Workflow.t option Terrat_change.Dirspaceflow.t list,
      [> Str_template.err ] )
    result

  (** What a start of a plan or an apply decides when its runner asks for work. [Run] carries the
      heads that the run starts on, recorded so that the result can be compared with the heads at
      that time: [head] is the commit that the runner checked out, and [dest_head] is the head of
      the destination branch of an open pull request, which the runner merges. [Restart] aborts the
      work manifest, because the commits moved before the run began and its files changed, or can
      have changed (RFD 2356). *)
  type start =
    | Run of {
        head : S.Api.Ref.t option;
        dest_head : S.Api.Ref.t option;
      }
    | Restart

  (** How a slot knows the work manifests it made among those of its job.

      A setup slot (a tree build, a config build, an index) knows them by their refs: its work is
      for one commit, and two setup slots of one job can share their steps. A result of a setup work
      manifest of its steps whose refs moved is not handled; the work manifest is completed, and the
      next operation computes the data again. [stored] says whether the data that the slot makes is
      stored already, thus the slot has no work to make: an evaluation pinned to the commit of a run
      makes no work, and it uses [stored] to go on without the work instead of waiting for it.

      A plan or an apply slot knows them by their steps. A job has one such slot, and its refs can
      move while a run operates: a merge to the destination branch moves the ref of a merged pull
      request. A work manifest that is not found by its refs is never completed and blocks its
      dirspaces for ever. [start ~sha] decides a start, where [sha] is the commit that the runner
      checked out, and [superseded] says whether a newer plan of the pull request replaced the given
      aborted work manifests of this job, in which case the slot does not make that work again. *)
  type membership =
    | Refs of {
        steps : Terrat_work_manifest3.Step.t list;
        eq : existing_wm -> bool;
        stored :
          Builder.B.State.t -> Builder.Bs.Fetcher.t -> (bool, Builder.err) result Abb.Future.t;
      }
    | Steps of {
        steps : Terrat_work_manifest3.Step.t list;
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

  (** Drive one slot of a job through the events of its work manifests.

      A result or a failure never makes work: the slot is over when all its work manifests are
      completed, and waits otherwise. An evaluation without an event makes again the work of an
      aborted work manifest whose dirspaces no live work manifest of the slot covers, at the refs of
      this evaluation. A late result of an aborted work manifest is stored and the work manifest
      stays aborted. *)
  val run :
    name:string ->
    membership:membership ->
    dest_branch_ref:S.Api.Ref.t ->
    branch_ref:S.Api.Ref.t ->
    branch:S.Api.Ref.t ->
    create:
      (dest_branch_ref:S.Api.Ref.t ->
      branch_ref:S.Api.Ref.t ->
      branch:S.Api.Ref.t ->
      Builder.B.State.t ->
      Builder.Bs.Fetcher.t ->
      (existing_wm list, Builder.err) result Abb.Future.t) ->
    initiate:
      (existing_wm ->
      Builder.B.State.t ->
      Builder.Bs.Fetcher.t ->
      (Terrat_api_components.Work_manifest.t, Builder.err) result Abb.Future.t) ->
    fail:
      (existing_wm ->
      Builder.B.State.t ->
      Builder.Bs.Fetcher.t ->
      (unit, Builder.err) result Abb.Future.t) ->
    result:
      (existing_wm ->
      Terrat_api_components.Work_manifest_result.t ->
      Builder.B.State.t ->
      Builder.Bs.Fetcher.t ->
      (unit, Builder.err) result Abb.Future.t) ->
    Builder.B.State.t ->
    Builder.Bs.Fetcher.t ->
    (existing_wm list, Builder.err) result Abb.Future.t
end
