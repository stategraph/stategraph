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
   guessed.  [imported] counts resources the plan imports, whatever their
   action, so an import that also updates counts in [imported] and [updated]. *)
module Resource_summary = struct
  type t = {
    created : int option;
    deleted : int option;
    imported : int option;
    replaced : int option;
    updated : int option;
  }
  [@@deriving eq, show]

  (* Nothing reported, which every count renders as "-". *)
  let none = { created = None; deleted = None; imported = None; replaced = None; updated = None }

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
        imported : int option; [@default None]
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
            | Ok { P.resource_summary = Some { Rs.created; deleted; imported; replaced; updated } }
              when CCList.exists CCOption.is_some [ created; deleted; imported; replaced; updated ]
              -> Some { created; deleted; imported; replaced; updated }
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
        imported : int;
        replaced : int;
        updated : int;
        reported : bool;
      }
    end in
    let add acc n = acc + CCOption.get_or ~default:0 n in
    let { Acc.created; deleted; imported; replaced; updated; reported } =
      CCList.fold_left
        (fun { Acc.created; deleted; imported; replaced; updated; reported } s ->
          {
            Acc.created = add created s.created;
            deleted = add deleted s.deleted;
            imported = add imported s.imported;
            replaced = add replaced s.replaced;
            updated = add updated s.updated;
            reported =
              reported
              || CCList.exists
                   CCOption.is_some
                   [ s.created; s.deleted; s.imported; s.replaced; s.updated ];
          })
        { Acc.created = 0; deleted = 0; imported = 0; replaced = 0; updated = 0; reported = false }
        summaries
    in
    if reported then
      {
        created = Some created;
        deleted = Some deleted;
        imported = Some imported;
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
      "Completed · 2 create, 1 update, 0 replace, 0 delete".  The import count
      leads only when it is above zero, e.g.
      "Completed · 1 import, 2 create, 1 update, 0 replace, 0 delete".  The
      count words are present tense, like the comment table headers.  Without a
      summary the description is returned unchanged; clipped defensively at
      {!description_limit}. *)
  let describe ?resource_summary ~description () =
    match resource_summary with
    | None -> description
    | Some { created; deleted; imported; replaced; updated } ->
        let imports =
          match imported with
          | Some n when n > 0 -> Printf.sprintf "%d import, " n
          | Some _ | None -> ""
        in
        let text =
          Printf.sprintf
            "%s · %s%s create, %s update, %s replace, %s delete"
            description
            imports
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

(** The Stategraph transaction a stored plan names. A plan of the Stategraph engine is the file
    [stategraph tf plan --out] writes ({!Sg_plan_file}), whose transaction is the one the plan
    opened and an apply commits; the runner stores it as it is, base64 in the [data] of the
    [terrateam] storage method, and the orchestration reads the transaction back out of its own
    copy. *)
module Stategraph_plan = struct
  (* The envelope the runner stores a plan in. It has no type of its own anywhere else: the runner
     writes it, the server keeps it opaque, and the cleanup of old plans reads it in SQL. *)
  module Envelope = struct
    type t = {
      data : string;
      method_ : string; [@key "method"]
    }
    [@@deriving of_yojson { strict = false }]
  end

  let json_of_string s = try Some (Yojson.Safe.from_string s) with Yojson.Json_error _ -> None

  (* Postgres wraps the base64 it encodes at 76 columns, and the decoder rejects a line break. *)
  let decode s =
    CCResult.to_opt (Base64.decode (CCString.filter (fun c -> c <> '\n' && c <> '\r') s))

  (* [data] is the stored plan as the provider serves it, base64. A plan stored any other way, or
     a file of another engine, names no transaction. *)
  let tx_id data =
    let open CCOption.Infix in
    decode data
    >>= json_of_string
    >>= CCFun.(Envelope.of_yojson %> CCResult.to_opt)
    >>= function
    | { Envelope.method_ = "terrateam"; data } ->
        decode data
        >>= json_of_string
        >>= CCFun.(Sg_plan_file.of_yojson %> CCResult.to_opt)
        >>= Sg_plan_file.tx_id
    | _ -> None
end

(** The moments the orchestration read from Stategraph, where it reaches it, for the two rules that
    order a plan against another pull request's apply on a dirspace that applies in parallel: when
    the transaction of our latest plan of a dirspace opened, and when the transaction an apply
    commits completed, by the apply's work manifest. The rules bound a moment the orchestration did
    not read by the run itself: a plan completes after its transaction opened, and an apply is
    dispatched before it commits. *)
module Stategraph_moments = struct
  type t = {
    planned_at : (Terrat_change.Dirspace.t * string) list;
    committed_at : (Uuidm.t * string) list;
  }

  let empty = { planned_at = []; committed_at = [] }
end

(** The Stategraph transaction of our latest plan of a dirspace that applies in parallel, beside the
    transaction of an apply of another pull request on it, when there is one: the transactions the
    stored plans name ({!Stategraph_plan}). *)
module Parallel_apply_tx = struct
  module Other = struct
    (** Where the other apply stands. A failed apply is not an [Other]: it stands against nothing.
    *)
    module State = struct
      type t =
        | Applied  (** Completed and succeeded: its transaction is committed. *)
        | Applying  (** Queued or running: its transaction is not committed yet. *)
      [@@deriving show, eq]

      (** The state of several applies of one pull request on a dirspace: [Applied] once one of them
          is, as its commit is what stands in the state. *)
      let merge a b =
        match (a, b) with
        | Applied, _ | _, Applied -> Applied
        | Applying, Applying -> Applying
    end

    type t = {
      pull_number : int;
      work_manifest : Uuidm.t;  (** The apply. *)
      tx : Uuidm.t;  (** The transaction of the other pull request's apply. *)
      state : State.t;
    }
    [@@deriving show]
  end

  type t = {
    dirspace : Terrat_change.Dirspace.t;
    installation : Uuidm.t;  (** The core id of the installation the repository belongs to. *)
    tx : Uuidm.t;  (** The transaction of our plan. *)
    other : Other.t option;
  }
  [@@deriving show]
end

(** An apply of another pull request that Stategraph refuses our plan of a dirspace for: the two
    transactions share the nodes at [addresses] and the other one is applying, or committed after
    our plan opened. *)
module Stategraph_overlap = struct
  type t = {
    dirspace : Terrat_change.Dirspace.t;
    pull_number : int;
    state : Parallel_apply_tx.Other.State.t;
    addresses : string list;
  }
  [@@deriving show]
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

(* The token a target renders in an unlock command, and whether it names a
   pull request.  All drift targets share the one [drift] token. *)
let target_unlock_id ~pull_request_id target =
  match target with
  | Target.Pr pr -> (CCInt.to_string (pull_request_id pr), true)
  | Target.Drift _ -> ("drift", false)

(* Returns the unlock command arguments for the list of work manifests.  The
   result has one token per pull request, and one [drift] token for all drift
   targets.  Comment templates print one token per element, so the list has no
   duplicates.  [Sln_list] sorts the strings, so [drift] is last. *)
let work_manifest_unlock_ids ~pull_request_id wms =
  wms
  |> CCList.map (fun { Terrat_work_manifest3.target; _ } ->
      fst (target_unlock_id ~pull_request_id target))
  |> Sln_list.String.sort_uniq

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
    | Stale
      (* The commits of the plan moved while it ran and changed its files, or the files changed
           since, thus the plan is not valid (RFD 2356). *)
    | Out_of_dependency_order
      (* A dirspace that this one depends on ran after the plan, thus the plan does not follow the
           order of the layers.  The files of the plan did not change. *)
  [@@deriving show]

  type t = {
    dirspace : Terrat_change.Dirspace.t;
    reason : reason;
  }
  [@@deriving show]
end

(* The runs of a dirspace of a pull request.  [state] holds the most recent successful runs, which
   the intra-PR hash rules read.  A push makes a new head with no checks, and the check of a failed
   run is written again on the new head (RFD 2356), thus [plan_failed] and [apply_failed] say
   whether the most recent plan and the most recent apply failed. *)
module Dirspace_runs = struct
  type t = {
    state : Terrat_intra_pr_hash.Dirspace_state.t;
    plan_failed : bool;
    apply_failed : bool;
  }
end

(* The state of a dirspace of a pull request at its head, as the intra-PR hash rules decide it
   (RFD 2356).  A run on an older commit can still count for the head, thus the unified summary
   comment shows this state and not only the runs on the head. *)
module Dirspace_summary = struct
  type t =
    | Applied
    | Planned
    | Failed
    | Stale
  [@@deriving show, eq]

  let to_string = function
    | Applied -> "applied"
    | Planned -> "planned"
    | Failed -> "failed"
    | Stale -> "stale"

  let of_string = function
    | "applied" -> Some Applied
    | "planned" -> Some Planned
    | "failed" -> Some Failed
    | "stale" -> Some Stale
    | _ -> None
end

(* The content of the message a plan or an apply gets when the commits it used moved while it
   operated and the files of its dirspaces changed.  It is the data of a template, thus a record
   that derives its JSON. *)
module Work_manifest_stale = struct
  module Dirspace = struct
    type t = {
      dir : string;
      workspace : string;
    }
    [@@deriving yojson, show, eq]
  end

  (** A branch that moved while a run operated. *)
  module Move = struct
    type t = {
      from_sha : string;  (** The head when the run started. *)
      to_sha : string;  (** The head when the result arrived. *)
    }
    [@@deriving yojson, show, eq]
  end

  type t = {
    is_plan : bool;
    files_unknown : bool;  (** The tree of a commit is not stored, thus nothing was compared. *)
    run_sha : string;  (** The commit the run started on. *)
    branch_move : Move.t option;
        (** The branch of the run, if it moved: the pull request branch, or the destination branch
            of a merged pull request. *)
    dest_branch_move : Move.t option;
        (** The destination branch of an open pull request, if it moved. The runner merges it, thus
            its files are files of the run too. *)
    dirspaces : Dirspace.t list;  (** The impacted dirspaces, empty when [files_unknown]. *)
    is_layered_run : bool;
    replan_dirs : string list;  (** The directories to plan again to go back to this layer. *)
  }
  [@@deriving yojson, show, eq]
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
    | Stategraph_overlapping_applies of Stategraph_overlap.t list
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
        stale : Work_manifest_stale.t option;
            (* The commits of the run moved and its files changed.  The output shows it as a
               warning.  When no output comment is posted, the warning is posted alone. *)
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
    | Work_manifest_stale of Work_manifest_stale.t

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
          let open Abbs_fc.Infix_result_monad in
          Api.fetch_remote_repo ~request_id client repo
          >>= fun remote_repo ->
          let default_branch = Api.Remote_repo.default_branch remote_repo in
          fetch_branch_sha client (Api.Remote_repo.to_repo remote_repo) default_branch
          >>= fun default_branch_sha ->
          let default_branch_ref = CCOption.get_or ~default:default_branch default_branch_sha in
          Abbs_fc.Result.all2
            (config_brand client repo default_branch_ref)
            (centralized client repo)
          >>| fun (repo_config, (forced_config, centralized)) ->
          Terrat_brand.resolve
            ~forced_config
            ~repo_config
            ~centralized
            ~fallback:(Terrat_brand.fallback ()))
      >>| CCResult.map_err (fun (#Terrat_vcs_api.call_err as err) -> err)

    let no_centralized _ _ = Abbs_fc.return_ok (None, None)
  end
end

(** What the editions of a provider share. *)
module type Shared = sig
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

    (** Store the tree of a commit. [built_by_script] says the tree builder script made it; a tree
        read from the forge did not, and the ids of the two do not compare. *)
    val store_repo_tree :
      request_id:string ->
      built_by_script:bool ->
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

    (** Store the drift schedules of [repo] for [branch]. Never upsert the [Api.Ref.of_string ""]
        sentinel; pass the real branch name, the default branch included. The sentinel is only a
        legacy delete key. *)
    val store_drift_schedule :
      request_id:string ->
      t ->
      Api.Repo.t ->
      branch:Api.Ref.t ->
      Terrat_base_repo_config_v1.Drift.t ->
      (unit, [> `Error ]) result Abb.Future.t

    (** Migrate the legacy [(repo, '', name)] row to [(repo, branch, name)] and delete the sentinel.
        Idempotent: an existing target row is left untouched. *)
    val migrate_default_branch_drift_schedule :
      request_id:string ->
      t ->
      Api.Repo.t ->
      branch:Api.Ref.t ->
      name:string ->
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
        from a tree which was never built, which the rows alone cannot. With [script_only], only a
        tree the tree builder script made answers. *)
    val query_repo_tree_built :
      request_id:string ->
      script_only:bool ->
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

    (** The runs of each given dirspace of the context: the most recent successful plan and the most
        recent successful apply, each with the sha it ran at and the time of its work manifest, and
        whether the most recent plan and the most recent apply failed.

        This does not test the sha against the sha of the branch, which
        {!query_applied_dirspaces_for_context} does. Whether a run still counts is a question about
        the hashes of the files of that dirspace, thus the caller decides it. *)
    val query_dirspace_runs_for_context :
      request_id:string ->
      t ->
      (Api.Pull_request.Id.t, Api.Ref.t) Terrat_job_context.Context.t ->
      Terrat_change.Dirspace.t list ->
      (Dirspace_runs.t list, [> `Error ]) result Abb.Future.t

    (** Store the states of the given dirspaces of the pull request of the context at its head
        [sha], and refresh the unified summary comment when a state changed. The summary shows these
        states, because a run on an older commit can still count for the head (RFD 2356).

        [work_manifest] is the run whose result decided the states, or [None] when an evaluation
        decided them. A run on the head that completes after a state decides the dirspace instead,
        except the run that decided the state: it completes after its result stores the state. *)
    val store_dirspace_summaries :
      request_id:string ->
      t ->
      (Api.Pull_request.Id.t, Api.Ref.t) Terrat_job_context.Context.t ->
      sha:Api.Ref.t ->
      work_manifest:Uuidm.t option ->
      (Terrat_change.Dirspace.t * Dirspace_summary.t) list ->
      (unit, [> `Error ]) result Abb.Future.t

    (* The next work manifest to start an action run for, with the compute node
       it belongs to and the id of its job, if it has one.  The statement holds
       the row of the work manifest it answers, so the answer is a work
       manifest no other dispatcher owns, and the hold lasts until the
       transaction of the caller ends.  A work manifest whose node already runs
       is not returned, because that node picks it up on its next poll.  The
       node and the job are [None] for a work manifest made before the server
       made a node with each one, and attached each work manifest to its job.

       [exclude_jobs] removes the candidates of those jobs from the answer
       only.  It is a choice of candidate for one drain of the dispatcher, and
       never a rule: the rules must see the whole queue.  The dispatcher adds
       the job of a candidate whose claim answered nothing, which means another
       transaction holds the row of that job. *)
    val query_next_pending_work_manifest :
      ?new_age:bool ->
      exclude_jobs:Uuidm.t list ->
      request_id:string ->
      stategraph_parallel_applies:bool ->
      t ->
      ( (( Api.Account.t,
           (unit Api.Pull_request.t, Api.Repo.t) Target.t )
         Terrat_work_manifest3.Existing.t
        * Uuidm.t option
        * Uuidm.t option)
        option,
        [> `Error ] )
      result
      Abb.Future.t

    (* Hold the row of a job without waiting for it.  [false] is a job row
       another transaction holds: the caller ends its transaction, excludes the
       job from its drain, and asks for the next candidate.  [true] holds the
       row until the transaction of the caller ends, which makes the count of
       the running work manifests of the job true for the dispatch that
       follows, and keeps two dispatchers from passing one free slot of the
       job's concurrent_runs limit.  The caller must ask inside a transaction,
       or the hold ends before the caller acts on the answer. *)
    val claim_work_manifest_job :
      request_id:string -> job_id:Uuidm.t -> t -> (bool, [> `Error ]) result Abb.Future.t

    (* Whether a work manifest may run now, by the rules the dispatcher applies:
       a plan waits for an apply that runs on its dirspaces, and two applies
       never run on one dirspace at once.  A compute node asks this before it
       takes work, because work that a node performs never reaches the
       dispatcher.

       The answer is three-valued.  [`No] is a rule of the query that declined
       the work manifest.  [`Busy] is another transaction already dispatching
       it: the hold of the row of the work manifest answered nothing.

       The question holds the row of the job of the work manifest, then the row
       of the work manifest itself, until the transaction of the caller ends.
       The hold of the work manifest row is the reservation: the dispatcher asks
       the same question after its own holds, so the two paths of the limit
       share one rule and one mutex, and a 'yes' names no work manifest another
       dispatcher can start.  The caller must ask inside a transaction, or the
       holds end before the caller acts on the answer. *)
    val work_manifest_can_run :
      request_id:string ->
      work_manifest_id:Uuidm.t ->
      stategraph_parallel_applies:bool ->
      t ->
      ([ `Busy | `No | `Yes ], [> `Error ]) result Abb.Future.t

    (** Record that [job_id] restarts [restart_of]. A drift whose files changed while its reconcile
        ran is reconciled again by a new job, and the chain of these jobs limits how many times (RFD
        2356). *)
    val set_job_restart_of :
      request_id:string ->
      job_id:Uuidm.t ->
      restart_of:Uuidm.t ->
      t ->
      (unit, [> `Error ]) result Abb.Future.t

    (** Record that the job [job_id] continues the job [from_job_id]: it gets the same link to the
        job that the chain restarts. The reconcile apply job of a drift continues its plan job, thus
        the restarts of every reconcile of a chain count toward its limit (RFD 2356). *)
    val inherit_job_restart_of :
      request_id:string ->
      job_id:Uuidm.t ->
      from_job_id:Uuidm.t ->
      t ->
      (unit, [> `Error ]) result Abb.Future.t

    (** The newest plan job that restarts [job_id], if any. *)
    val query_job_restart :
      request_id:string -> job_id:Uuidm.t -> t -> (Uuidm.t option, [> `Error ]) result Abb.Future.t

    (** How many restarts lead to [job_id]: 0 for a job that restarts nothing. *)
    val query_job_restart_depth :
      request_id:string -> job_id:Uuidm.t -> t -> (int, [> `Error ]) result Abb.Future.t

    (** Whether newer plans of the same pull request replace the plan of [job_id] for the work
        manifest [work_manifest_id]. Two pushes close together can make two plan jobs; the older
        plan is aborted at its start, or its late result is stored and not posted (RFD 2356). The
        plan is replaced only when each of its dirspaces is in a plan work manifest, not aborted, of
        a newer plan job. Then the newer result is the most recent plan of each dirspace, thus the
        older plan, which the user did not see, is never applied. *)
    val query_plan_superseded :
      request_id:string ->
      job_id:Uuidm.t ->
      work_manifest_id:Uuidm.t ->
      t ->
      (bool, [> `Error ]) result Abb.Future.t

    val query_flow_state :
      request_id:string -> t -> Uuidm.t -> (string option, [> `Error ]) result Abb.Future.t

    val delete_flow_state :
      request_id:string -> t -> Uuidm.t -> (unit, [> `Error ]) result Abb.Future.t

    val query_pull_request_out_of_change_applies :
      request_id:string ->
      t ->
      'diff Api.Pull_request.t ->
      (Terrat_change.Dirspace.t list, [> `Error ]) result Abb.Future.t

    (** Record [dirspaces] as the dirspaces that output pruning removed from the run of the pull
        request, and forget the dirspaces it removed before. A pruned dirspace needs no apply, thus
        a merged pull request keeps no lock for it. The caller must already hold a transaction:
        implementations run on the connection they are given and must not open a nested
        [Pgsql_io.tx] — that raises [Pgsql_io.Nested_tx_not_supported]. *)
    val store_pruned_dirspaces_in_tx :
      request_id:string ->
      t ->
      'diff Api.Pull_request.t ->
      Terrat_dirspace.t list ->
      (unit, [> `Error ]) result Abb.Future.t

    (** The baseline and the current outputs of each of [dirspaces] that the pull request has
        applied. A dirspace that the pull request has not applied is not in the result. *)
    val query_dirspace_outputs :
      request_id:string ->
      t ->
      'diff Api.Pull_request.t ->
      Terrat_dirspace.t list ->
      ((Terrat_dirspace.t * Terrat_output_diff.t) list, [> `Error ]) result Abb.Future.t

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
      stategraph_parallel_apply_dirspaces:Terrat_change.Dirspace.t list ->
      stategraph_moments:Stategraph_moments.t ->
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

    (* [job_id] is the job asking the question.  Work manifests belonging to it
       are never aborted, and a plan of any job created after it is never
       aborted.  [changed_dirspaces] is the dirspaces that the pull request
       changes at its head now.  A plan of an older job is aborted when the new
       plan covers each of its dirspaces that is still in [changed_dirspaces]: a
       dirspace that the pull request no longer changes needs no plan (RFD 2356).

       [start_timeout] is how long a dispatched work manifest has to call
       home before it counts as stale.  A stale work manifest is aborted,
       because it holds the locks of its dirspaces and the queue waits behind it
       with no end (RFD 2826). *)
    val query_conflicting_work_manifests_in_repo_for_context :
      request_id:string ->
      job_id:Uuidm.t ->
      start_timeout:Duration.t ->
      changed_dirspaces:Terrat_change.Dirspace.t list ->
      stategraph_parallel_apply_dirspaces:Terrat_change.Dirspace.t list ->
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
       own work manifests are never reported.  On a dirspace of
       [stategraph_parallel_apply_dirspaces], the eligible plans and applies of
       other pull requests do not hold the apply back. *)
    val query_blocking_work_manifests_in_repo_for_context :
      request_id:string ->
      job_id:Uuidm.t ->
      t ->
      (Api.Pull_request.Id.t, Api.Ref.t) Terrat_job_context.Context.t ->
      Terrat_change.Dirspace.t list ->
      stategraph_parallel_apply_dirspaces:Terrat_change.Dirspace.t list ->
      ( ( Api.Account.t,
          (unit Api.Pull_request.t, Api.Repo.t) Target.t )
        Terrat_work_manifest3.Existing.t
        list,
        [> `Error ] )
      result
      Abb.Future.t

    (** The dirspaces of the pull request that other pull requests block, each with the blocking
        pull request. Those in [stategraph_parallel_apply_dirspaces] are blocked not by a lock but
        by another pull request's apply that committed its Stategraph transaction before the
        transaction of the pull request's latest plan of the dirspace opened. *)
    val query_dirspaces_owned_by_other_pull_requests :
      request_id:string ->
      t ->
      'diff Api.Pull_request.t ->
      Terrat_change.Dirspace.t list ->
      stategraph_parallel_apply_dirspaces:Terrat_change.Dirspace.t list ->
      stategraph_moments:Stategraph_moments.t ->
      ((Terrat_change.Dirspace.t * unit Api.Pull_request.t) list, [> `Error ]) result Abb.Future.t

    (** For each of [dirspaces], which apply in parallel, the transaction of the pull request's
        latest completed plan beside the transaction of each apply of another pull request that
        Stategraph may refuse that plan for, see {!Parallel_apply_tx}: one row per such apply, or
        one row without when there is none. A dirspace whose plan has no reported transaction gives
        no row, and an apply without one is left out: Stategraph then decides at commit. *)
    val query_parallel_apply_transactions :
      request_id:string ->
      t ->
      'diff Api.Pull_request.t ->
      Terrat_change.Dirspace.t list ->
      (Parallel_apply_tx.t list, [> `Error ]) result Abb.Future.t

    val query_missing_drift_scheduled_runs :
      request_id:string ->
      t ->
      ( (string
        * Api.Account.t
        * Api.Repo.t
        * bool
        * bool
        * Terrat_tag_query.t
        * (string * string) option
        * string option)
        list,
        [> `Error ] )
      result
      Abb.Future.t

    val cleanup_repo_configs : request_id:string -> t -> (unit, [> `Error ]) result Abb.Future.t
    val cleanup_flow_states : request_id:string -> t -> (unit, [> `Error ]) result Abb.Future.t
    val cleanup_plans : request_id:string -> t -> (unit, [> `Error ]) result Abb.Future.t
    val cleanup_repo_trees : request_id:string -> t -> (unit, [> `Error ]) result Abb.Future.t

    val cleanup_stale_work_manifests :
      request_id:string -> t -> (unit, [> `Error ]) result Abb.Future.t

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

    (** As {!drain_unified_comment}, for a pull request. An evaluation of a pull request event can
        change the states of its dirspaces without a work manifest (RFD 2356). *)
    val drain_unified_comment_for_pull_request :
      request_id:string ->
      fetch_brand:
        (Api.Client.t ->
        Api.Repo.t ->
        (Terrat_brand.t, Terrat_vcs_api.call_err) result Abb.Future.t) ->
      Api.Config.t ->
      Pgsql_pool.t ->
      Api.Repo.t ->
      Api.Pull_request.Id.t ->
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

    (** Record the commits that a run starts on, when the runner takes the work manifest.
        [start_sha] is the commit that the runner checked out. [start_dest_sha] is the head of the
        destination branch of an open pull request, which the runner merges when the operation
        starts, thus a move of the destination during the run can make it stale too. A result
        compares these commits with the heads at that time to decide whether the run is stale (RFD
        2356). *)
    val update_start_refs :
      request_id:string ->
      Db.t ->
      Uuidm.t ->
      start_sha:Api.Ref.t option ->
      start_dest_sha:Api.Ref.t option ->
      (unit, [> `Error ]) result Abb.Future.t

    (** The commits recorded by {!update_start_refs}, as [(start_sha, start_dest_sha)]. A commit is
        [None] for a work manifest that has not started, or that started before the server recorded
        it. *)
    val query_start_refs :
      request_id:string ->
      Db.t ->
      Uuidm.t ->
      (Api.Ref.t option * Api.Ref.t option, [> `Error ]) result Abb.Future.t

    (** Record the heads that the result of a run was compared with: the head of the branch of the
        run and, for an open pull request, the head of the destination branch. A later evaluation of
        the pull request compares the same pairs of commits, thus it decides the staleness of the
        run as the result did, or better once the missing trees exist (RFD 2356). *)
    val update_result_refs :
      request_id:string ->
      Db.t ->
      Uuidm.t ->
      result_sha:Api.Ref.t option ->
      result_dest_sha:Api.Ref.t option ->
      (unit, [> `Error ]) result Abb.Future.t

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
      brand:Terrat_brand.t ->
      Api.Config.t ->
      Api.Account.t ->
      (Api.Repo.t * int) option ->
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
      (** [continuation_of] is the job that the new job continues: the job whose completion made it,
          when the new job runs a later layer of the same run. *)
      val create :
        request_id:string ->
        ?continuation_of:Uuidm.t ->
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

      (** The job that started the run that [job_id] is a layer of: the job at the head of its chain
          of continuations. A job that continues nothing is its own origin. [None] when no job has
          the id. *)
      val query_origin :
        request_id:string ->
        Db.t ->
        job_id:Uuidm.t ->
        unit ->
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

      (* The rows the node still owes, in the order the job made them.  A node is
         one action run and it may hold more than one work manifest, so the poll
         asks for all of them and serves the first that may run. *)
      val query_work :
        request_id:string ->
        compute_node_id:Uuidm.t ->
        Db.t ->
        (Terrat_job_context.Compute_node_work.t list, [> `Error ]) result Abb.Future.t

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

(** What an edition decides. *)
module type Edition = sig
  (** Whether a dirspace that runs the Stategraph engine, whatever its lock policy, applies in
      parallel with the same dirspace of other pull requests, rather than behind their locks:
      Stategraph locks the resources, and the orchestration asks it about them where it can. True in
      the enterprise editions only. *)
  val stategraph_parallel_applies : bool
end

(** A provider as the evaluator runs on it: what the editions share, what the edition decides, and
    Stategraph as the orchestration reaches it ({!Terrat_stategraph}). The VCS service is given the
    last two when it is instantiated: the edition's answers, and the Stategraph of its process in
    the unified server or {!Terrat_stategraph.Standalone} in the orchestration on its own. *)
module type S = sig
  include Shared
  include Edition
  module Stategraph : Terrat_stategraph.S
end
