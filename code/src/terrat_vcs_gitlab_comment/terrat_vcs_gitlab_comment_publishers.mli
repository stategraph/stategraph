module Api = Terrat_vcs_api_gitlab
module Scope = Terrat_scope.Scope
module Visible_on = Terrat_base_repo_config_v1.Workflow_step.Visible_on

(** [tail_of ~max_bytes s] keeps the last [max_bytes] of [s], resuming at a line boundary and
    prefixing a marker when anything was dropped. Terraform and provider errors are emitted at the
    END of a step's output, so the tail is the part worth keeping when a comment has to shrink.
    Exposed for testing. *)
val tail_of : max_bytes:int -> string -> string

val dirspace_compare :
  Terrat_dirspace.t * Terrat_api_components.Workflow_step_output.t list ->
  Terrat_dirspace.t * Terrat_api_components.Workflow_step_output.t list ->
  int

(** Publishing a comment. A rate limit refusal is reported as [`Vcs_api_rate_limit_err] rather than
    [`Error]: the caller has to be able to tell a comment that could not land because the VCS is
    throttling us from an operation that actually failed. *)
module Comment_api : sig
  val comment_on_pull_request :
    request_id:string ->
    Api.Client.t ->
    'a Api.Pull_request.t ->
    string ->
    string ->
    (Api.Comment.Id.t, [> `Error | `Vcs_api_rate_limit_err of string ]) Abbs_fc.Infix_result_monad.t

  val apply_template_and_publish :
    request_id:string ->
    Api.Client.t ->
    'a Api.Pull_request.t ->
    string ->
    Snabela.t ->
    Snabela.Kv.t Snabela.Kv.Map.t ->
    (unit, [> `Error | `Vcs_api_rate_limit_err of string ]) result Abb.Future.t

  val apply_template_and_publish_jinja :
    request_id:string ->
    Api.Client.t ->
    'a Api.Pull_request.t ->
    string ->
    string ->
    Yojson.Safe.t ->
    (Api.Comment.Id.t, [> `Error | `Vcs_api_rate_limit_err of string ]) Abbs_fc.Infix_result_monad.t
end

module Publisher_tools : sig
  val create_run_output :
    ?stale:Terrat_vcs_provider2.Work_manifest_stale.t ->
    brand:Terrat_brand.t ->
    view:[> `Compact ] ->
    compacted_dirspaces:Terrat_dirspace.t list ->
    summary:bool ->
    pull_request_ref:(Api.Repo.t * int) option ->
    dirspace_run_urls:(Terrat_dirspace.t * string) list ->
    fail_if_set:string list ->
    string ->
    [< `Active | `Disabled | `Expired | `Trial_ending of int64 > `Trial_ending ] ->
    Terrat_tier.Check.runs_per_month option ->
    Api.Config.t ->
    bool ->
    int ->
    (Scope.t, Terrat_api_components_workflow_step_output.t list) CCList.Assoc.t ->
    Terrat_api_components_gate.t list option ->
    ( Api.Account.t,
      Uuidm.t,
      'b,
      'c,
      'd,
      'e Terrat_change.Dirspaceflow.t list,
      Terrat_work_manifest3.Deny.t list,
      'f )
    Terrat_work_manifest3.t ->
    string
end
