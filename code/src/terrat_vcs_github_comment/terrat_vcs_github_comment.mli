module Api = Terrat_vcs_api_github
module Scope = Terrat_scope.Scope

module S : sig
  type t = {
    account_status : Terrat_vcs_provider2.Account_status.t;
    tier_runs : Terrat_tier.Check.runs_per_month option;
    client : Api.Client.t;
    config : Api.Config.t;
    db : Pgsql_io.t;
    is_layered_run : bool;
    hooks : (Scope.t * Terrat_api_components_workflow_step_output.t list) list;
    pull_request : unit Api.Pull_request.t;
    request_id : string;
    brand : Terrat_brand.t;
    num_remaining_layers : int;
    result : Terrat_api_components_work_manifest_tf_operation_result2.t;
    repo_config : Terrat_base_repo_config_v1.derived Terrat_base_repo_config_v1.t;
    synthesized_config : Terrat_change_match3.Config.t;
    work_manifest : (Api.Account.t, unit) Terrat_work_manifest3.Existing.t;
  }

  type el = {
    applied : bool;
    compact : bool;
    dirspace : Terrat_dirspace.t;
    steps : Terrat_api_components_workflow_step_output.t list;
    strategy : Terrat_vcs_comment.Strategy.t;
    work_manifest_id : Uuidm.t;
  }
  [@@deriving show]

  type comment_id = Api.Comment.Id.t [@@deriving ord, show]

  module Cmp : sig
    type t = bool * bool * Terrat_dirspace.t [@@deriving ord]
  end

  val create_el :
    t ->
    ?applied:bool ->
    work_manifest_id:Uuidm.t ->
    Terrat_dirspace.t ->
    Terrat_api_components_workflow_step_output.t list ->
    el option

  val query_comment_id : t -> el -> (comment_id option, [> `Error ]) result Abb.Future.t
  val query_els_for_comment_id : t -> comment_id -> (el list, [> `Error ]) result Abb.Future.t
  val upsert_comment_id : t -> el list -> comment_id -> (unit, [> `Error ]) result Abb.Future.t
  val delete_comment : t -> comment_id -> (unit, [> `Error ]) result Abb.Future.t
  val minimize_comment : t -> comment_id -> (unit, [> `Error ]) result Abb.Future.t
  val post_comment : t -> el list -> (comment_id, [> `Error ]) result Abb.Future.t
  val rendered_length : t -> el list -> int
  val dirspace : el -> Terrat_dirspace.t
  val strategy : el -> Terrat_vcs_comment.Strategy.t
  val compact : el -> el
  val compare_el : el -> el -> int
  val max_comment_length : int
end
