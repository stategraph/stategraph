type premium_features =
  [ `Access_control
  | `Multiple_drift_schedules
  | `Gatekeeping
  | `Require_completed_reviews
  | `Notifications_summary
  ]
[@@deriving show]

type premium_feature_err = [ `Premium_feature_err of premium_features ] [@@deriving show]

type fetch_repo_config_with_provenance_err =
  [ Terrat_base_repo_config_v1.of_version_1_err
  | `Repo_config_schema_err of string * Jsonschema_check.Validation_err.t list
  | `Config_merge_err of (string * string) * (string option * Yojson.Safe.t * Yojson.Safe.t)
  | `Json_decode_err of string * string
  | `Unexpected_err of string
  | `Yaml_decode_err of string * string
  | premium_feature_err
  | Terrat_vcs_api.call_err
  ]
[@@deriving show]

type access_control_query_err = [ `Error ] [@@deriving show]
type access_control_err = access_control_query_err [@@deriving show]

type gate_add_approval_err =
  [ `Error
  | `No_matching_token_err of string
  | `Premium_feature_err of premium_features
  ]
[@@deriving show]

type gate_eval_err = [ `Error ] [@@deriving show]
type tier_check_err = [ `Error ] [@@deriving show]

type run_work_manifest_err =
  [ `Failed_to_start_with_msg_err of string
  | `Failed_to_start
  | `Missing_workflow
  | `Job_failed of string
    (* Handling a work manifest result failed.  Whoever produced this has
       already told the user, so do not comment again. *)
  | `Result_handling_err
  | `Error
  ]

module Account_status = struct
  type t =
    [ `Active
    | `Expired
    | `Disabled
    | `Trial_ending of Duration.t
    ]
  [@@deriving show]
end

(* Resource counts reported by the runner in the plan step's [resource_summary]
   payload, computed from `terraform show -json`.  When the runner or engine
   does not emit them the fields are None (rendered as "-") rather than
   guessed. *)
module Resource_summary = struct
  type t = {
    created : int option;
    deleted : int option;
    replaced : int option;
    updated : int option;
  }
  [@@deriving eq, show]

  (* Nothing reported, which every count renders as "-". *)
  let none = { created = None; deleted = None; replaced = None; updated = None }

  (* The plan steps whose payload may carry a [resource_summary]. *)
  let plan_steps = [ "tf/plan"; "pulumi/plan"; "custom/plan"; "fly/plan"; "stategraph/plan" ]

  (* The first plan step in [steps] whose payload carries a resource summary
      with at least one reported count.  [None] when the runner or engine did
      not report one, so callers can fall back to a summary-less rendering
      rather than a table of dashes. *)
  let of_steps steps =
    let module Rs = struct
      type t = {
        created : int option; [@default None]
        deleted : int option; [@default None]
        replaced : int option; [@default None]
        updated : int option; [@default None]
      }
      [@@deriving of_yojson { strict = false }]
    end in
    let module P = struct
      type t = { resource_summary : Rs.t option [@default None] }
      [@@deriving of_yojson { strict = false }]
    end in
    let module O = Terrat_api_components.Workflow_step_output in
    CCList.find_map
      (function
        | { O.step; payload; success = _; ignore_errors = _; scope = _ }
          when CCList.mem ~eq:CCString.equal step plan_steps -> (
            match P.of_yojson (O.Payload.to_yojson payload) with
            | Ok { P.resource_summary = Some { Rs.created; deleted; replaced; updated } }
              when CCList.exists CCOption.is_some [ created; deleted; replaced; updated ] ->
                Some { created; deleted; replaced; updated }
            | _ -> None)
        | _ -> None)
      steps

  (* [of_steps] with the summary-less runs folded into {!none}, for renderers that show "-"
      rather than nothing at all. *)
  let of_steps_or_none steps = CCOption.get_or ~default:none (of_steps steps)

  (* The totals of [summaries].  Every count is [None] when no summary reported anything, so a
      run whose engine emits no counts renders a row of "-" rather than a row of zeroes. *)
  let total summaries =
    let module Acc = struct
      type t = {
        created : int;
        deleted : int;
        replaced : int;
        updated : int;
        reported : bool;
      }
    end in
    let add acc n = acc + CCOption.get_or ~default:0 n in
    let { Acc.created; deleted; replaced; updated; reported } =
      CCList.fold_left
        (fun { Acc.created; deleted; replaced; updated; reported } s ->
          {
            Acc.created = add created s.created;
            deleted = add deleted s.deleted;
            replaced = add replaced s.replaced;
            updated = add updated s.updated;
            reported =
              reported
              || CCList.exists CCOption.is_some [ s.created; s.deleted; s.replaced; s.updated ];
          })
        { Acc.created = 0; deleted = 0; replaced = 0; updated = 0; reported = false }
        summaries
    in
    if reported then
      {
        created = Some created;
        deleted = Some deleted;
        replaced = Some replaced;
        updated = Some updated;
      }
    else none

  (* The GitHub commit status description is truncated in the UI at 140
      characters. *)
  let description_limit = 140

  let count_str = function
    | Some n -> CCInt.to_string n
    | None -> "-"

  (* [description] suffixed with the counts, e.g.
      "Completed · 2 created, 1 updated, 0 replaced, 0 deleted".  Without a
      summary the description is returned unchanged; clipped defensively at
      {!description_limit}. *)
  let describe ?resource_summary ~description () =
    match resource_summary with
    | None -> description
    | Some { created; deleted; replaced; updated } ->
        let text =
          Printf.sprintf
            "%s · %s created, %s updated, %s replaced, %s deleted"
            description
            (count_str created)
            (count_str updated)
            (count_str replaced)
            (count_str deleted)
        in
        if CCString.length text > description_limit then CCString.sub text 0 description_limit
        else text
end

module Work_manifest_result = struct
  type t = {
    dirspaces_success : (Terrat_change.Dirspace.t * bool) list;
    (* Per-dirspace resource counts from the run's plan step.  Legacy results
       and results without a plan step carry an empty list; the commit check
       description then falls back to the bare status word. *)
    dirspaces_resource_summary : (Terrat_change.Dirspace.t * Resource_summary.t) list;
    overall_success : bool;
    post_hooks_success : bool;
    pre_hooks_success : bool;
  }
end

module Conflicting_work_manifests = struct
  type 'a t =
    | Conflicting of 'a list
    | Maybe_stale of 'a list
end

module Target = struct
  type ('pr, 'repo) t =
    | Pr of 'pr
    | Drift of {
        repo : 'repo;
        branch : string;
      }
  [@@deriving show]
end

module Index = struct
  module Failure = struct
    type t = {
      file : string;
      line_num : int option;
      error : string;
    }
  end

  type t = {
    success : bool;
    failures : Failure.t list;
    index : Terrat_base_repo_config_v1.Index.t;
  }
end

module Gate_eval = struct
  type t = {
    dirspace : Terrat_dirspace.t option;
    token : string option;
    name : string option;
    result : Terrat_gate.Result.t;
  }
  [@@deriving show]
end

(* A dirspace with no valid plan, and which of the three things the query
   distinguishes put it there.  Reporting the dirspace alone leaves an operator
   who watched their plan succeed with no way to tell that another pull request
   moved underneath them. *)
module Missing_plan = struct
  type reason =
    | Never_planned
    | Invalidated_by_pull_request of int
    | Last_run_failed
  [@@deriving show]

  type t = {
    dirspace : Terrat_change.Dirspace.t;
    reason : reason;
  }
  [@@deriving show]
end

module Msg = struct
  type access_control_denied =
    [ `All_dirspaces of Terrat_access_control2.R.Deny.t list
    | `Ci_config_update of Terrat_base_repo_config_v1.Access_control.Match_list.t
    | `Dirspaces of Terrat_access_control2.R.Deny.t list
    | `Files of string * Terrat_base_repo_config_v1.Access_control.Match_list.t
    | `Lookup_err
    | `Terrateam_config_update of Terrat_base_repo_config_v1.Access_control.Match_list.t
    | `Unlock of Terrat_base_repo_config_v1.Access_control.Match_list.t
    ]

  (* Why an operation stopped, when the cause is Terrateam or its infrastructure
     rather than something in the user's configuration.  The request id is
     deliberately not carried here: [publish_comment] already takes
     [~request_id] and the templates render it from there. *)
  type operation_failed_reason =
    [ `Branch_not_found_err of string  (** Branch the VCS has no sha for *)
    | `Compute_aborted_err of int  (** How many runs aborted without a result *)
    | `Db_err
    | `Internal_err of string  (** Short tag naming the invariant that broke *)
    | `Vcs_api_err of string  (** Short tag naming the API call that failed *)
    | `Vcs_api_rate_limit_err of string
      (** Short tag naming the API call the VCS refused for a rate limit *)
    | `Vcs_api_timeout_err of string
      (** Short tag naming the API call the VCS did not answer in time *)
    | `Work_manifest_start_err
    ]
  [@@deriving show]

  type ('account, 'db, 'pull_request, 'target, 'apply_requirements, 'config) t =
    | Access_control_denied of (string * access_control_denied)
    | Account_expired
    | Apply_no_matching_dirspaces of Terrat_tag_query.t
    | Apply_requirements_config_err of [ Terrat_tag_query_ast.err | `Invalid_query of string ]
    | Apply_requirements_validation_err
    | Apply_queued_behind_work_manifests of
        ('account, 'target) Terrat_work_manifest3.Existing.t list
    | Autoapply_running
    | Automerge_failure of ('pull_request * string)
    | Bad_custom_branch_tag_pattern of (string * string)
    | Bad_glob of string
    | Build_config_err of Terrat_base_repo_config_v1.of_version_1_json_err
    | Build_config_failure of string
    | Build_tree_failure of string
    | Conflicting_work_manifests of ('account, 'target) Terrat_work_manifest3.Existing.t list
    | Dest_branch_no_match of 'pull_request
    | Dirspaces_owned_by_other_pull_request of (Terrat_change.Dirspace.t * 'pull_request) list
    | Gate_check_failure of Gate_eval.t list
    | Help
    | Index_complete of (bool * (string * int option * string) list)
    | Invalid_unlock_id of string
    | Maybe_stale_work_manifests of ('account, 'target) Terrat_work_manifest3.Existing.t list
    | Matches_in_later_layer of Terrat_change.Dirspace.t list
    | Mismatched_refs
    | Missing_plans of Missing_plan.t list
    | Operation_failed of operation_failed_reason
    | Plan_all_changes_applied
    | Plan_already_planned of Terrat_change.Dirspace.t list
    | Plan_no_matching_dirspaces of Terrat_tag_query.t
    | Premium_feature_err of premium_features
    | Pull_request_not_appliable of ('pull_request * 'apply_requirements)
    | Pull_request_not_mergeable
    | Repo_config of (string list * Terrat_base_repo_config_v1.derived Terrat_base_repo_config_v1.t)
    | Repo_config_err of Terrat_base_repo_config_v1.of_version_1_err
    | Repo_config_failure of string
    | Repo_config_merge_err of ((string * string) * (string option * Yojson.Safe.t * Yojson.Safe.t))
    | Repo_config_parse_failure of string * string
    | Repo_config_schema_err of (string * Jsonschema_check.Validation_err.t list)
    | Run_work_manifest_err of
        [ `Failed_to_start_with_msg_err of string | `Failed_to_start | `Missing_workflow ]
    | Str_template_err of Str_template.err
    | Synthesize_config_err of Terrat_change_match3.synthesize_config_err
    | Tag_query_err of Terrat_tag_query_ast.err
    | Tf_op_result2 of {
        account_status : Account_status.t;
        db : 'db;
        config : 'config;
        is_layered_run : bool;
        num_remaining_layers : int;
            (* How many rounds the run still needs, counted with [apply_after] as an
               edge.  A plan layering would say something smaller, because
               [apply_after] holds an apply back without holding the plan back. *)
        repo_config : Terrat_base_repo_config_v1.derived Terrat_base_repo_config_v1.t;
        result : Terrat_api_components_work_manifest_tf_operation_result2.t;
        synthesized_config : Terrat_change_match3.Config.t;
        work_manifest : ('account, 'target) Terrat_work_manifest3.Existing.t;
      }
    | Tag_query_dropped_dirspaces of {
        (* The bare command, ["apply"] or ["plan"], with no trigger word in
           front of it.  The trigger word is brand-dependent, so it belongs in
           the template, where the brand rewrite reaches it; a value handed to
           the renderer is never rewritten. *)
        command : string;
        suggestion : string;
        dirspaces : Terrat_change.Dirspace.t list;
      }
    | Tier_check of Terrat_tier.Check.t
    | Unlock_success
    | Work_manifest_run_failed of { run_id : string }

  (* Both [no matching dirspaces] messages, in both services, say the same thing
     about the query that matched nothing, so they render from one payload. *)
  let no_matching_dirspaces_kv tag_query =
    let implicit_and, suggestion =
      match Terrat_tag_query.warning tag_query with
      | Some (Terrat_tag_query.Implicit_and { suggestion }) -> (true, suggestion)
      | None -> (false, None)
    in
    `Assoc
      [
        ("tag_query", `String (Terrat_tag_query.to_string tag_query));
        ("implicit_and", `Bool implicit_and);
        ( "suggestion",
          match suggestion with
          | Some suggestion -> `String suggestion
          | None -> `Null );
      ]
end

(* The brand of a repository comes from the configuration on the default branch
   of the repository and from the centralized repository of its owner.  It
   changes only when that configuration moves, thus an answer is kept for a
   minute.  A failed lookup is not kept. *)
module Brand = struct
  let call_count =
    let help = "Count of brand cache calls by provider with hit or miss or evict" in
    let family =
      Prmths.Counter.v_labels
        ~label_names:[ "provider"; "type" ]
        ~help
        ~namespace:"terrat"
        ~subsystem:"vcs_provider"
        "brand_cache_call_count"
    in
    fun ~provider t -> Prmths.Counter.labels family [ provider; t ]

  module Make
      (Api : Terrat_vcs_api.S)
      (M : sig
        val provider : string
      end) =
  struct
    module Cache = Abbs_cache.Expiring.Make (struct
      type k = Api.Repo.t [@@deriving eq]
      type v = Terrat_brand.t
      type err = Terrat_vcs_api.call_err
      type args = unit -> (v, err) result Abb.Future.t

      let fetch f = f ()
      let weight _ = 1
    end)

    let count t () = Prmths.Counter.inc_one (call_count ~provider:M.provider t)

    let cache =
      Cache.create
        {
          Abbs_cache.Expiring.on_hit = count "hit";
          on_miss = count "miss";
          on_evict = count "evict";
          duration = Duration.of_min 1;
          capacity = 10_000;
        }

    (* [centralized] answers the brand of the selected centralized repository,
       and the same brand again when that repository holds a forced config for
       this repository. *)
    let fetch ~request_id ~fetch_branch_sha ~config_brand ~centralized client repo =
      let open Abb.Future.Infix_monad in
      Cache.fetch cache repo (fun () ->
          let open Abbs_future_combinators.Infix_result_monad in
          Api.fetch_remote_repo ~request_id client repo
          >>= fun remote_repo ->
          let default_branch = Api.Remote_repo.default_branch remote_repo in
          fetch_branch_sha client (Api.Remote_repo.to_repo remote_repo) default_branch
          >>= fun default_branch_sha ->
          let default_branch_ref = CCOption.get_or ~default:default_branch default_branch_sha in
          Abbs_future_combinators.Result.all2
            (config_brand client repo default_branch_ref)
            (centralized client repo)
          >>| fun (repo_config, (forced_config, centralized)) ->
          Terrat_brand.resolve
            ~forced_config
            ~repo_config
            ~centralized
            ~fallback:(Terrat_brand.fallback ()))
      >>| CCResult.map_err (fun (#Terrat_vcs_api.call_err as err) -> err)

    let no_centralized _ _ = Abbs_future_combinators.return_ok (None, None)
  end
end

module type S = sig
  val name : string

  module Api : Terrat_vcs_api.S

  val enforce_installation_access :
    request_id:string ->
    Terrat_user.t ->
    Api.Account.Id.t ->
    Pgsql_io.t ->
    (unit, [> `Forbidden ]) result Abb.Future.t

  module Unlock_id : sig
    type t

    val of_pull_request : Api.Pull_request.Id.t -> t
    val drift : unit -> t
    val to_string : t -> string
  end

  module Db : sig
    type t = Pgsql_io.t

    val store_account_repository :
      request_id:string ->
      t ->
      Api.Account.t ->
      Api.Repo.t ->
      (unit, [> `Error ]) result Abb.Future.t

    val lock_repository :
      request_id:string ->
      t ->
      Api.Account.t ->
      Api.Repo.t ->
      (unit, [> `Error ]) result Abb.Future.t

    val store_pull_request :
      request_id:string ->
      t ->
      Terrat_change.Diff.t list Api.Pull_request.t ->
      (unit, [> `Error ]) result Abb.Future.t

    val store_index :
      request_id:string ->
      t ->
      Uuidm.t ->
      Terrat_api_components.Work_manifest_index_result.t ->
      (Index.t, [> `Error ]) result Abb.Future.t

    val store_index_result :
      request_id:string ->
      t ->
      Uuidm.t ->
      Terrat_api_components.Work_manifest_index_result.t ->
      (unit, [> `Error ]) result Abb.Future.t

    val store_repo_config_json :
      request_id:string ->
      t ->
      Api.Account.t ->
      Api.Ref.t ->
      Yojson.Safe.t ->
      (unit, [> `Error ]) result Abb.Future.t

    val store_repo_config_history :
      request_id:string ->
      t ->
      Api.Account.t ->
      Api.Repo.t ->
      branch:Api.Ref.t ->
      sha:Api.Ref.t ->
      Yojson.Safe.t ->
      (unit, [> `Error ]) result Abb.Future.t

    val store_repo_tree :
      request_id:string ->
      t ->
      Api.Account.t ->
      Api.Ref.t ->
      Terrat_api_components.Work_manifest_build_tree_result.Files.t ->
      (unit, [> `Error ]) result Abb.Future.t

    val store_flow_state :
      request_id:string -> t -> Uuidm.t -> string -> (unit, [> `Error ]) result Abb.Future.t

    val store_dirspaceflows :
      request_id:string ->
      base_ref:Api.Ref.t ->
      branch_ref:Api.Ref.t ->
      lock_policy:Terrat_base_repo_config_v1.Workflows.Entry.Lock_policy.t ->
      t ->
      Api.Repo.t ->
      (Terrat_base_repo_config_v1.Dirs.Dir.Branch_target.t
      * Terrat_change.Dirspaceflow.Workflow.t option)
      Terrat_change.Dirspaceflow.t
      list ->
      (unit, [> `Error ]) result Abb.Future.t

    val store_tf_operation_result :
      request_id:string ->
      t ->
      Uuidm.t ->
      Terrat_api_components_work_manifest_tf_operation_result.t ->
      (unit, [> `Error ]) result Abb.Future.t

    val store_tf_operation_result2 :
      request_id:string ->
      t ->
      Uuidm.t ->
      Terrat_api_components_work_manifest_tf_operation_result2.t ->
      (unit, [> `Error ]) result Abb.Future.t

    val store_drift_schedule :
      request_id:string ->
      t ->
      Api.Repo.t ->
      Terrat_base_repo_config_v1.Drift.t ->
      (unit, [> `Error ]) result Abb.Future.t

    val query_account_status :
      request_id:string -> t -> Api.Account.t -> (Account_status.t, [> `Error ]) result Abb.Future.t

    val query_index :
      request_id:string ->
      t ->
      Api.Account.t ->
      Api.Ref.t ->
      (Index.t option, [> `Error ]) result Abb.Future.t

    val query_repo_config_json :
      request_id:string ->
      t ->
      Api.Account.t ->
      Api.Ref.t ->
      (Yojson.Safe.t option, [> `Error ]) result Abb.Future.t

    (** The fully-derived configuration of the commit of [branch] that is nearest to its head, out
        of [shas], if that configuration is younger than [stale_min] minutes. [shas] is the lineage
        of [branch], newest first, as {!Terrat_vcs_api.S.fetch_branch_commits} gives it.

        The lineage is what makes the answer safe. A repository holds a derived configuration for
        many branches, and the newest of them can belong to a branch that changed the dirs
        completely. A configuration that a commit of the lineage produced is a true earlier state of
        [branch] itself.

        Every push to the default branch records one, and so does each evaluation of a pull request
        against it. The answer tells what dirs the destination branch holds without any setup job,
        thus it is cheap enough to read before one starts. [None] when no commit of the lineage
        recorded one or the nearest one is too old. A [stale_min] of [0] makes every row too old. *)
    val query_recent_derived_repo_config :
      request_id:string ->
      t ->
      Api.Account.t ->
      Api.Repo.t ->
      branch:Api.Ref.t ->
      shas:Api.Ref.t list ->
      stale_min:int ->
      (Yojson.Safe.t option, [> `Error ]) result Abb.Future.t

    val query_repo_tree :
      ?base_ref:Api.Ref.t ->
      request_id:string ->
      t ->
      Api.Account.t ->
      Api.Ref.t ->
      (Terrat_api_components.Work_manifest_build_tree_result.Files.t option, [> `Error ]) result
      Abb.Future.t

    (** Whether a tree is stored for this ref. It tells a tree which was built and is empty apart
        from a tree which was never built, which the rows alone cannot. *)
    val query_repo_tree_built :
      request_id:string ->
      t ->
      Api.Account.t ->
      Api.Ref.t ->
      (bool, [> `Error ]) result Abb.Future.t

    (** The paths whose contents are not the same at [base_ref] as they are at the given ref. A path
        which only one of the two trees holds is one of them, and so is a path whose id is not
        known, because a tree which is not there must mean "run it" and never "skip it".

        The cost follows the number of paths which changed, and not the number of files of the
        repository, thus this is what makes the intra-pull-request hash check cheap. *)
    val query_repo_tree_changes :
      request_id:string ->
      base_ref:Api.Ref.t ->
      t ->
      Api.Account.t ->
      Api.Ref.t ->
      (string list, [> `Error ]) result Abb.Future.t

    (** The most recent successful plan and the most recent successful apply of each given dirspace
        of the context, each with the sha it ran at and the time of its work manifest.

        This does not test the sha against the sha of the branch, which
        {!query_applied_dirspaces_for_context} does. Whether a run still counts is a question about
        the hashes of the files of that dirspace, thus the caller decides it. *)
    val query_dirspace_runs_for_context :
      request_id:string ->
      t ->
      (Api.Pull_request.Id.t, Api.Ref.t) Terrat_job_context.Context.t ->
      Terrat_change.Dirspace.t list ->
      (Terrat_intra_pr_hash.Dirspace_state.t list, [> `Error ]) result Abb.Future.t

    (* The next work manifest to start an action run for, with the compute node
       it belongs to.  A work manifest whose node already runs is not returned,
       because that node picks it up on its next poll.  The node is [None] for a
       work manifest made before the server made a node with each one. *)
    val query_next_pending_work_manifest :
      ?new_age:bool ->
      request_id:string ->
      t ->
      ( (( Api.Account.t,
           (unit Api.Pull_request.t, Api.Repo.t) Target.t )
         Terrat_work_manifest3.Existing.t
        * Uuidm.t option)
        option,
        [> `Error ] )
      result
      Abb.Future.t

    (* Whether a work manifest may run now, by the rules the dispatcher applies:
       a plan waits for an apply that runs on its dirspaces, and two applies
       never run on one dirspace at once.  A compute node asks this before it
       takes work, because work that a node performs never reaches the
       dispatcher. *)
    val work_manifest_can_run :
      request_id:string -> work_manifest_id:Uuidm.t -> t -> (bool, [> `Error ]) result Abb.Future.t

    val query_flow_state :
      request_id:string -> t -> Uuidm.t -> (string option, [> `Error ]) result Abb.Future.t

    val delete_flow_state :
      request_id:string -> t -> Uuidm.t -> (unit, [> `Error ]) result Abb.Future.t

    val query_pull_request_out_of_change_applies :
      request_id:string ->
      t ->
      'diff Api.Pull_request.t ->
      (Terrat_change.Dirspace.t list, [> `Error ]) result Abb.Future.t

    val query_applied_dirspaces_for_context :
      request_id:string ->
      t ->
      (Api.Pull_request.Id.t, Api.Ref.t) Terrat_job_context.Context.t ->
      (Terrat_change.Dirspace.t list, [> `Error ]) result Abb.Future.t

    val query_applied_dirspaces :
      request_id:string ->
      t ->
      'diff Api.Pull_request.t ->
      (Terrat_change.Dirspace.t list, [> `Error ]) result Abb.Future.t

    val query_dirspaces_without_valid_plans :
      request_id:string ->
      base_ref:Api.Ref.t ->
      branch_ref:Api.Ref.t ->
      t ->
      'diff Api.Pull_request.t ->
      Terrat_change.Dirspace.t list ->
      (Missing_plan.t list, [> `Error ]) result Abb.Future.t

    val query_conflicting_work_manifests_in_repo :
      request_id:string ->
      t ->
      'diff Api.Pull_request.t ->
      Terrat_change.Dirspace.t list ->
      [< `Plan | `Apply ] ->
      ( ( Api.Account.t,
          (unit Api.Pull_request.t, Api.Repo.t) Target.t )
        Terrat_work_manifest3.Existing.t
        Conflicting_work_manifests.t
        option,
        [> `Error ] )
      result
      Abb.Future.t

    (* [job_id] is the job asking the question.  Work manifests belonging to it,
       or to any job created after it, are never aborted. *)
    val query_conflicting_work_manifests_in_repo_for_context :
      request_id:string ->
      job_id:Uuidm.t ->
      t ->
      (Api.Pull_request.Id.t, Api.Ref.t) Terrat_job_context.Context.t ->
      Terrat_change.Dirspace.t list ->
      [< `Plan | `Apply ] ->
      ( ( Api.Account.t,
          (unit Api.Pull_request.t, Api.Repo.t) Target.t )
        Terrat_work_manifest3.Existing.t
        Conflicting_work_manifests.t
        option,
        [> `Error ] )
      result
      Abb.Future.t

    (* The work manifests that are running against [dirspaces], so an apply
       queued against them cannot start yet.  These are not conflicts: the apply
       is queued and will run once they finish.  [job_id] is the job asking, its
       own work manifests are never reported. *)
    val query_blocking_work_manifests_in_repo_for_context :
      request_id:string ->
      job_id:Uuidm.t ->
      t ->
      (Api.Pull_request.Id.t, Api.Ref.t) Terrat_job_context.Context.t ->
      Terrat_change.Dirspace.t list ->
      ( ( Api.Account.t,
          (unit Api.Pull_request.t, Api.Repo.t) Target.t )
        Terrat_work_manifest3.Existing.t
        list,
        [> `Error ] )
      result
      Abb.Future.t

    val query_dirspaces_owned_by_other_pull_requests :
      request_id:string ->
      t ->
      'diff Api.Pull_request.t ->
      Terrat_change.Dirspace.t list ->
      ((Terrat_change.Dirspace.t * unit Api.Pull_request.t) list, [> `Error ]) result Abb.Future.t

    val query_missing_drift_scheduled_runs :
      request_id:string ->
      t ->
      ( (string * Api.Account.t * Api.Repo.t * bool * Terrat_tag_query.t * (string * string) option)
        list,
        [> `Error ] )
      result
      Abb.Future.t

    val cleanup_repo_configs : request_id:string -> t -> (unit, [> `Error ]) result Abb.Future.t
    val cleanup_flow_states : request_id:string -> t -> (unit, [> `Error ]) result Abb.Future.t
    val cleanup_plans : request_id:string -> t -> (unit, [> `Error ]) result Abb.Future.t
    val cleanup_repo_trees : request_id:string -> t -> (unit, [> `Error ]) result Abb.Future.t

    val unlock :
      request_id:string -> t -> Api.Repo.t -> Unlock_id.t -> (unit, [> `Error ]) result Abb.Future.t

    val query_plan :
      request_id:string ->
      t ->
      Uuidm.t ->
      Terrat_dirspace.t ->
      (string option, [> `Error ]) result Abb.Future.t

    val store_plan :
      request_id:string ->
      t ->
      Uuidm.t ->
      Terrat_dirspace.t ->
      string ->
      bool ->
      (unit, [> `Error ]) result Abb.Future.t

    val store_branch_hash :
      request_id:string ->
      branch_name:Api.Ref.t ->
      branch_ref:Api.Ref.t ->
      Api.Repo.t ->
      t ->
      (unit, [> `Error ]) result Abb.Future.t

    val query_repo_by_id :
      request_id:string ->
      t ->
      Api.Account.Id.t ->
      Api.Repo.Id.t ->
      (Api.Repo.t option, [> `Error ]) result Abb.Future.t

    val delete_repo :
      request_id:string ->
      t ->
      Api.Account.Id.t ->
      Api.Repo.Id.t ->
      (unit, [> `Error ]) result Abb.Future.t
  end

  module Apply_requirements : sig
    module Result : sig
      type t

      val passed : t -> bool
      val approved_reviews : t -> Terrat_pull_request_review.t list
    end

    val eval :
      request_id:string ->
      Api.Config.t ->
      Api.User.t ->
      Api.Client.t ->
      'a Terrat_base_repo_config_v1.t ->
      'diff Api.Pull_request.t ->
      Terrat_change_match3.Dirspace_config.t list ->
      (Result.t, [> Terrat_vcs_api.call_err ]) result Abb.Future.t
  end

  module Gate : sig
    val add_approval :
      request_id:string ->
      token:string ->
      approver:string ->
      'a Api.Pull_request.t ->
      Db.t ->
      (unit, [> gate_add_approval_err ]) result Abb.Future.t

    val eval :
      request_id:string ->
      Api.Client.t ->
      Terrat_dirspace.t list ->
      'a Api.Pull_request.t ->
      Db.t ->
      (Gate_eval.t list, [> gate_eval_err ]) result Abb.Future.t
  end

  module Tier : sig
    val check :
      request_id:string ->
      Api.User.t ->
      Api.Account.t ->
      Db.t ->
      (Terrat_tier.Check.t option, [> tier_check_err ]) result Abb.Future.t
  end

  module Comment : sig
    val publish_comment :
      request_id:string ->
      brand:Terrat_brand.t ->
      Api.Client.t ->
      string ->
      'diff Api.Pull_request.t ->
      ( Api.Account.t,
        Db.t,
        'diff2 Api.Pull_request.t,
        ('diff3 Api.Pull_request.t, Api.Repo.t) Target.t,
        Apply_requirements.Result.t,
        Api.Config.t )
      Msg.t ->
      (unit, [> `Error ]) result Abb.Future.t

    (** Refresh the unified summary comment of the pull request the given work manifest belongs to,
        if it has been marked dirty. Runs on its own connections after the result transaction
        commits and is best effort: it must log and swallow its errors. *)
    val drain_unified_comment :
      request_id:string ->
      fetch_brand:
        (Api.Client.t ->
        Api.Repo.t ->
        (Terrat_brand.t, Terrat_vcs_api.call_err) result Abb.Future.t) ->
      Api.Config.t ->
      Pgsql_pool.t ->
      Uuidm.t ->
      unit Abb.Future.t

    (** Mark the unified summary comment of the work manifest's pull request as needing a refresh,
        but only if the pull request already tracks one. Used by failure paths so aborted runs show
        up in the comment. *)
    val mark_unified_comment_dirty :
      request_id:string -> Db.t -> Uuidm.t -> (unit, [> `Error ]) result Abb.Future.t

    (** Publish the unified summary comment as the given work manifest starts, so it is the first
        comment of the run. Must run in the caller's open transaction and only for repositories
        whose summary is enabled in pull_request mode; any other work manifest is ignored. Best
        effort: errors are logged and swallowed. *)
    val publish_unified_comment_at_start :
      request_id:string ->
      fetch_brand:
        (Api.Client.t ->
        Api.Repo.t ->
        (Terrat_brand.t, Terrat_vcs_api.call_err) result Abb.Future.t) ->
      repo_config:Terrat_base_repo_config_v1.derived Terrat_base_repo_config_v1.t ->
      Api.Config.t ->
      Db.t ->
      Uuidm.t ->
      (unit, [> `Error ]) result Abb.Future.t
  end

  module Repo_config : sig
    (** The brand of a repository, from [Terrat_brand.resolve]. *)
    val fetch_brand :
      request_id:string ->
      Api.Client.t ->
      Api.Repo.t ->
      (Terrat_brand.t, [> Terrat_vcs_api.call_err ]) result Abb.Future.t

    val fetch_with_provenance :
      ?system_defaults:Terrat_base_repo_config_v1.raw Terrat_base_repo_config_v1.t ->
      ?built_config:Yojson.Safe.t ->
      string ->
      Api.Client.t ->
      Api.Repo.t ->
      Api.Ref.t ->
      ( string list * Terrat_base_repo_config_v1.raw Terrat_base_repo_config_v1.t,
        [> fetch_repo_config_with_provenance_err ] )
      result
      Abb.Future.t
  end

  module Access_control : sig
    val query :
      request_id:string ->
      Api.Client.t ->
      Api.Repo.t ->
      string ->
      Terrat_base_repo_config_v1.Access_control.Match.t ->
      (bool, [> access_control_query_err ]) result Abb.Future.t

    val is_ci_changed :
      request_id:string ->
      Api.Client.t ->
      Api.Repo.t ->
      Terrat_change.Diff.t list ->
      (bool, [> access_control_err ]) result Abb.Future.t
  end

  module Commit_check : sig
    val make_dirspace_title : run_type:string -> Terrat_dirspace.t -> string

    val make_dirspace :
      ?work_manifest:('a, 'b) Terrat_work_manifest3.Existing.t ->
      ?resource_summary:Resource_summary.t ->
      config:Api.Config.t ->
      description:string ->
      run_type:string ->
      dirspace:Terrat_dirspace.t ->
      status:Terrat_commit_check.Status.t ->
      repo:Api.Repo.t ->
      account:Api.Account.t ->
      unit ->
      Terrat_commit_check.t

    val make_str :
      ?work_manifest:('a, 'b) Terrat_work_manifest3.Existing.t ->
      config:Api.Config.t ->
      description:string ->
      status:Terrat_commit_check.Status.t ->
      repo:Api.Repo.t ->
      account:Api.Account.t ->
      string ->
      Terrat_commit_check.t
  end

  module Work_manifest : sig
    (* Start the action run of a compute node.  The node is what the run asks for
       work, so [compute_node_id] is the work token the run is given, and not the
       id of the work manifest: a node can perform more than one. *)
    val run :
      request_id:string ->
      compute_node_id:Uuidm.t ->
      Api.Config.t ->
      Api.Client.t ->
      ( Api.Account.t,
        (unit Api.Pull_request.t, Api.Repo.t) Target.t )
      Terrat_work_manifest3.Existing.t ->
      (unit, [> run_work_manifest_err ]) result Abb.Future.t

    val create :
      request_id:string ->
      Db.t ->
      (Api.Account.t, (unit Api.Pull_request.t, Api.Repo.t) Target.t) Terrat_work_manifest3.New.t ->
      ( ( Api.Account.t,
          (unit Api.Pull_request.t, Api.Repo.t) Target.t )
        Terrat_work_manifest3.Existing.t,
        [> `Error ] )
      result
      Abb.Future.t

    val query' :
      request_id:string ->
      Db.t ->
      Uuidm.t list ->
      ( ( Api.Account.t,
          (unit Api.Pull_request.t, Api.Repo.t) Target.t )
        Terrat_work_manifest3.Existing.t
        list,
        [> `Error ] )
      result
      Abb.Future.t

    val query :
      request_id:string ->
      Db.t ->
      Uuidm.t ->
      ( ( Api.Account.t,
          (unit Api.Pull_request.t, Api.Repo.t) Target.t )
        Terrat_work_manifest3.Existing.t
        option,
        [> `Error ] )
      result
      Abb.Future.t

    val query_by_run_id :
      request_id:string ->
      Db.t ->
      string ->
      ( ( Api.Account.t,
          (unit Api.Pull_request.t, Api.Repo.t) Target.t )
        Terrat_work_manifest3.Existing.t
        option,
        [> `Error ] )
      result
      Abb.Future.t

    val update_state :
      request_id:string ->
      Db.t ->
      Uuidm.t ->
      Terrat_work_manifest3.State.t ->
      (unit, [> `Error ]) result Abb.Future.t

    val update_run_id :
      request_id:string -> Db.t -> Uuidm.t -> string -> (unit, [> `Error ]) result Abb.Future.t

    val update_changes :
      request_id:string ->
      Db.t ->
      Uuidm.t ->
      int option Terrat_change.Dirspaceflow.t list ->
      (unit, [> `Error ]) result Abb.Future.t

    val update_denied_dirspaces :
      request_id:string ->
      Db.t ->
      Uuidm.t ->
      Terrat_work_manifest3.Deny.t list ->
      (unit, [> `Error ]) result Abb.Future.t

    val update_steps :
      request_id:string ->
      Db.t ->
      Uuidm.t ->
      Terrat_work_manifest3.Step.t list ->
      (unit, [> `Error ]) result Abb.Future.t

    val result : Terrat_api_components_work_manifest_tf_operation_result.t -> Work_manifest_result.t

    val result2 :
      Terrat_api_components_work_manifest_tf_operation_result2.t -> Work_manifest_result.t
  end

  module Ui : sig
    val work_manifest_url :
      Api.Config.t ->
      Api.Account.t ->
      int option ->
      ('a, 'b) Terrat_work_manifest3.Existing.t ->
      Uri.t option
  end

  module Job_context : sig
    val create_or_get_for_pull_request :
      request_id:string ->
      Db.t ->
      Api.Account.t ->
      Api.Repo.t ->
      Api.Pull_request.Id.t ->
      ((Api.Pull_request.Id.t, Api.Ref.t) Terrat_job_context.Context.t, [> `Error ]) result
      Abb.Future.t

    val create_or_get_for_branch :
      request_id:string ->
      Db.t ->
      Api.Account.t ->
      Api.Repo.t ->
      Api.Ref.t ->
      ((Api.Pull_request.Id.t, Api.Ref.t) Terrat_job_context.Context.t, [> `Error ]) result
      Abb.Future.t

    val query :
      request_id:string ->
      Db.t ->
      Uuidm.t ->
      ((Api.Pull_request.Id.t, Api.Ref.t) Terrat_job_context.Context.t option, [> `Error ]) result
      Abb.Future.t

    module Job : sig
      val create :
        request_id:string ->
        Db.t ->
        Terrat_job_context.Job.Type_.t ->
        (Api.Pull_request.Id.t, Api.Ref.t) Terrat_job_context.Context.t ->
        Api.User.t option ->
        ( (Api.Pull_request.Id.t, Api.Ref.t, Api.User.t option) Terrat_job_context.Job.t,
          [> `Error ] )
        result
        Abb.Future.t

      val query :
        request_id:string ->
        Db.t ->
        job_id:Uuidm.t ->
        ( (Api.Pull_request.Id.t, Api.Ref.t, Api.User.t option) Terrat_job_context.Job.t option,
          [> `Error ] )
        result
        Abb.Future.t

      val query_all_by_context_id :
        request_id:string ->
        Db.t ->
        context_id:Uuidm.t ->
        unit ->
        ( (Api.Pull_request.Id.t, Api.Ref.t, Api.User.t option) Terrat_job_context.Job.t list,
          [> `Error ] )
        result
        Abb.Future.t

      val query_pending_by_context_id :
        request_id:string ->
        Db.t ->
        context_id:Uuidm.t ->
        unit ->
        ( (Api.Pull_request.Id.t, Api.Ref.t, Api.User.t option) Terrat_job_context.Job.t list,
          [> `Error ] )
        result
        Abb.Future.t

      (** [true] if a user has asked for a plan in this context.

          An autoplan and a [terrateam plan] both write a job of type [plan]; only the explicit one
          carries a tag query. Once a user has forced a run in a pull request, the prechecks of RFD
          2111 no longer apply to it. This tells the caller if that has happened. *)
      val query_explicit_plan_exists :
        request_id:string ->
        Db.t ->
        context_id:Uuidm.t ->
        unit ->
        (bool, [> `Error ]) result Abb.Future.t

      val query_by_work_manifest_id :
        request_id:string ->
        Db.t ->
        work_manifest_id:Uuidm.t ->
        unit ->
        ( (Api.Pull_request.Id.t, Api.Ref.t, Api.User.t option) Terrat_job_context.Job.t option,
          [> `Error ] )
        result
        Abb.Future.t

      val update_state :
        request_id:string ->
        Db.t ->
        job_id:Uuidm.t ->
        Terrat_job_context.Job.State.t ->
        (unit, [> `Error ]) result Abb.Future.t

      val add_work_manifest :
        request_id:string ->
        Db.t ->
        job_id:Uuidm.t ->
        work_manifest_id:Uuidm.t ->
        unit ->
        (unit, [> `Error ]) result Abb.Future.t

      val query_work_manifests :
        request_id:string ->
        Db.t ->
        job_id:Uuidm.t ->
        unit ->
        ( ( Api.Account.t,
            (unit Api.Pull_request.t, Api.Repo.t) Target.t )
          Terrat_work_manifest3.Existing.t
          list,
          [> `Error ] )
        result
        Abb.Future.t
    end

    module Compute_node : sig
      (* The database chooses the id, so the caller reads it back off the node
         and then writes the row in compute_node_work with it. *)
      val create :
        request_id:string ->
        capabilities:Terrat_job_context.Compute_node.Capabilities.t ->
        Db.t ->
        (Terrat_job_context.Compute_node.t, [> `Error ]) result Abb.Future.t

      val query :
        request_id:string ->
        compute_node_id:Uuidm.t ->
        Db.t ->
        (Terrat_job_context.Compute_node.t option, [> `Error ]) result Abb.Future.t

      (* The compute node that owns a work manifest.  The database chooses the id
         of a node, so that id says nothing about the work manifests of the node
         and this read must go through [compute_node_work]. *)
      val query_by_work_manifest :
        request_id:string ->
        work_manifest_id:Uuidm.t ->
        Db.t ->
        (Terrat_job_context.Compute_node.t option, [> `Error ]) result Abb.Future.t

      val query_work :
        request_id:string ->
        compute_node_id:Uuidm.t ->
        Db.t ->
        (Terrat_job_context.Compute_node_work.t option, [> `Error ]) result Abb.Future.t

      val update_state :
        request_id:string ->
        compute_node_id:Uuidm.t ->
        Db.t ->
        Terrat_job_context.Compute_node.State.t ->
        (unit, [> `Error ]) result Abb.Future.t

      (* What the run of this node was started with, and what it has spent of its
         budget.  The server writes it when it makes the node, and again when a
         work manifest joins. *)
      val update_capabilities :
        request_id:string ->
        compute_node_id:Uuidm.t ->
        Db.t ->
        Terrat_job_context.Compute_node.Capabilities.t ->
        (unit, [> `Error ]) result Abb.Future.t

      (* Link a work manifest to a compute node before the response for the
         action exists.  The row is written with no work.  [set_work] fills it
         on the first poll. *)
      val add_work :
        request_id:string ->
        compute_node_id:Uuidm.t ->
        work_manifest:Uuidm.t ->
        Db.t ->
        (unit, [> `Error ]) result Abb.Future.t

      (* Move a work manifest to another compute node.  The index on
         [work_manifest] is unique, so a work manifest has one node and one row.
         The row moves; it is never copied. *)
      val move_work :
        request_id:string ->
        compute_node_id:Uuidm.t ->
        work_manifest:Uuidm.t ->
        Db.t ->
        (unit, [> `Error ]) result Abb.Future.t

      val set_work :
        request_id:string ->
        compute_node_id:Uuidm.t ->
        work_manifest:Uuidm.t ->
        Db.t ->
        Terrat_api_components.Work_manifest.t ->
        (unit, [> `Error ]) result Abb.Future.t
    end
  end

  module Stacks :
    Terrat_vcs_stacks.S
      with type Installation_id.t = Api.Account.Id.t
       and type Repo_id.t = Api.Repo.Id.t
       and type Pull_request_id.t = Api.Pull_request.Id.t
       and type Config.t = Api.Config.t
       and type db = Db.t
end
