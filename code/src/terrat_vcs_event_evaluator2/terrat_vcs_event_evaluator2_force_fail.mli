(** Whether a configuration set forces the run to count as failed whatever its actual result.

    A run that sets a parameter whose [fail_if_set] is true does all of its work and then counts as
    failed: its commit checks fail with the names of those parameters, the comment shows the failure
    heading, the directories count as needing a plan, and the layers after it do not run. The rule
    is pure, so the result path, the completion path and the result comment read one implementation.
*)

(** [fail_if_set section parameters] is the names of [parameters] that [section] declares with
    [fail_if_set = true], in the order of [parameters].

    A name that [section] does not declare is not one of them: the comment step rejects such a name
    before any run exists. So an empty answer is the only answer a valid run can give when the
    configuration declares no such parameter. *)
val fail_if_set :
  Terrat_base_repo_config_v1.Parameters.t -> Terrat_job_context.Job.Type_.Params.t -> string list

(** [force_fail section parameters] is true when {!fail_if_set} names at least one parameter: a
    configuration set forces the run to count as failed whatever its actual result. *)
val force_fail :
  Terrat_base_repo_config_v1.Parameters.t -> Terrat_job_context.Job.Type_.Params.t -> bool

(** [force_fail_result result] is [result] with every dirspace failed and the run failed: the shape
    the commit checks, the dirspace summaries and the comment read for a run that failed. The stored
    rows carry the same verdict, because the result path passes [~force_fail] to the store. *)
val force_fail_result :
  Terrat_vcs_provider2.Work_manifest_result.t -> Terrat_vcs_provider2.Work_manifest_result.t
