module Batch : module type of Terrat_vcs_event_evaluator2_batch
module Comment_resolve : module type of Terrat_vcs_event_evaluator2_comment_resolve
module Compute_node : module type of Terrat_vcs_event_evaluator2_compute_node
module Work_set : module type of Terrat_vcs_event_evaluator2_work_set
module Staleness : module type of Terrat_vcs_event_evaluator2_staleness
module Force_fail : module type of Terrat_vcs_event_evaluator2_force_fail
module Ee2_fc : module type of Terrat_vcs_event_evaluator2_fc
module Merge_steps : module type of Terrat_vcs_event_evaluator2_merge_steps
module Status_checks : module type of Terrat_vcs_event_evaluator2_status_checks
module Exec : module type of Abb_bounded_suspendable_executor.Make (Abb) (CCString)

val create_exec : slots:int -> unit -> Exec.t Abb.Future.t

(** [wake_pending_compute ~drain body] runs [body] and forks [drain ()] when [body] is done. A
    settled work manifest frees a slot of its job, and nothing else starts the next work manifest of
    that job, so the arm that settles it must drain the queue. The drain is forked and ignored: the
    result of the arm must not wait for the drain and must not carry its error. *)
val wake_pending_compute :
  drain:(unit -> 'a Abb.Future.t) -> (unit -> 'b Abb.Future.t) -> 'b Abb.Future.t

module Make (S : Terrat_vcs_provider2.S) : sig
  type err = Terrat_vcs_event_evaluator2_builder.Make(S).err

  module Pull_request_event : sig
    type t =
      | Open
      | Close
      | Sync
      | Ready_for_review
      | Comment of {
          comment_id : int;
          comment : Terrat_comment.t;
        }
  end

  val pull_request_event :
    request_id:string ->
    config:S.Api.Config.t ->
    storage:Terrat_storage.t ->
    exec:Exec.t ->
    account:S.Api.Account.t ->
    repo:S.Api.Repo.t ->
    pull_request_id:S.Api.Pull_request.Id.t ->
    user:S.Api.User.t ->
    Pull_request_event.t ->
    (unit, [> `Error ]) result Abb.Future.t

  val work_manifest_job_failed :
    request_id:string ->
    config:S.Api.Config.t ->
    storage:Terrat_storage.t ->
    exec:Exec.t ->
    account:S.Api.Account.t ->
    repo:S.Api.Repo.t ->
    run_id:string ->
    unit ->
    (unit, [> `Error ]) result Abb.Future.t

  val compute_node_poll :
    request_id:string ->
    config:S.Api.Config.t ->
    storage:Terrat_storage.t ->
    exec:Exec.t ->
    compute_node_id:Uuidm.t ->
    Terrat_api_components.Work_manifest_initiate.t ->
    (Terrat_api_components.Work_manifest.t, [> `Error ]) result Abb.Future.t

  val work_manifest_result :
    request_id:string ->
    config:S.Api.Config.t ->
    storage:Terrat_storage.t ->
    exec:Exec.t ->
    work_manifest_id:Uuidm.t ->
    Terrat_api_components.Work_manifest_result.t ->
    (unit, [> `Error ]) result Abb.Future.t

  val push :
    request_id:string ->
    config:S.Api.Config.t ->
    storage:Terrat_storage.t ->
    exec:Exec.t ->
    account:S.Api.Account.t ->
    repo:S.Api.Repo.t ->
    branch:S.Api.Ref.t ->
    user:S.Api.User.t ->
    unit ->
    (unit, [> `Error ]) result Abb.Future.t

  val run_missing_drift_schedules :
    ?request_id:string ->
    config:S.Api.Config.t ->
    storage:Terrat_storage.t ->
    exec:Exec.t ->
    unit ->
    unit Abb.Future.t

  (** The hourly maintenance entries. They open one connection and run the per-provider cleanup SQL.
      A pool error is logged and coerced to [`Error] so no [`Pgsql_pool_error] can reach a caller
      that assumes [`Error]-shaped errors. *)

  val run_plan_cleanup :
    request_id:string -> storage:Terrat_storage.t -> unit -> (unit, [> `Error ]) result Abb.Future.t

  val run_repo_tree_cleanup :
    request_id:string -> storage:Terrat_storage.t -> unit -> (unit, [> `Error ]) result Abb.Future.t

  val run_flow_state_cleanup :
    request_id:string -> storage:Terrat_storage.t -> unit -> (unit, [> `Error ]) result Abb.Future.t

  val run_repo_config_cleanup :
    request_id:string -> storage:Terrat_storage.t -> unit -> (unit, [> `Error ]) result Abb.Future.t

  (** [run_stale_work_manifest_cleanup] is the hourly sweep that aborts the runs that are still
      running past their repository [stale_timeout_sec]. The threshold comes from the stored config.
      This entry takes the configuration and the executor only because it forks the dispatcher when
      it is done, and the dispatcher needs both: the sweep frees a slot of a job at its limit and
      nothing else starts the next work manifest of that job (RFD 2903). *)
  val run_stale_work_manifest_cleanup :
    request_id:string ->
    config:S.Api.Config.t ->
    storage:Terrat_storage.t ->
    exec:Exec.t ->
    unit ->
    (unit, [> `Error ]) result Abb.Future.t
end
