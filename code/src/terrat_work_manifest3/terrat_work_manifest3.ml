module State = struct
  type t =
    | Queued
    | Running
    | Completed
    | Aborted
  [@@deriving show]

  let to_string = function
    | Queued -> "queued"
    | Running -> "running"
    | Completed -> "completed"
    | Aborted -> "aborted"

  let of_string = function
    | "queued" -> Some Queued
    | "running" -> Some Running
    | "completed" -> Some Completed
    | "aborted" -> Some Aborted
    | _ -> None
end

module Step = struct
  type t =
    | Apply
    | Build_config
    | Build_tree
    | Index
    | Plan
    | Unsafe_apply
  [@@deriving eq, show]

  let to_string = function
    | Apply -> "apply"
    | Build_config -> "build-config"
    | Build_tree -> "build-tree"
    | Index -> "index"
    | Plan -> "plan"
    | Unsafe_apply -> "unsafe-apply"

  let of_string = function
    | "apply" -> Some Apply
    | "build-config" -> Some Build_config
    | "build-tree" -> Some Build_tree
    | "index" -> Some Index
    | "plan" -> Some Plan
    | "unsafe-apply" -> Some Unsafe_apply
    (* Legacy conversions *)
    | "autoplan" -> Some Plan
    | "autoapply" -> Some Apply
    | _ -> None
end

module Deny = struct
  type t = {
    dirspace : Terrat_change.Dirspace.t;
    policy : Terrat_base_repo_config_v1.Access_control.Match_list.t option;
  }
  [@@deriving show]
end

module Initiator = struct
  type t =
    | User of string
    | System
  [@@deriving show]
end

type ('account, 'id, 'created_at, 'run_id, 'state, 'changes, 'denied_dirspaces, 'target) t = {
  account : 'account;
  base_ref : string;
  branch : string option;
  branch_ref : string;
  changes : 'changes;
  completed_at : string option;
  created_at : 'created_at;
  denied_dirspaces : 'denied_dirspaces;
  environment : string option;
  id : 'id;
  initiator : Initiator.t;
      (** The parameters the run sets, as parameter name to value, read from the job of the run
          under [params->'run_params']. The empty map is a run that sets no parameter, and it is the
          value of a work manifest whose job carries none. *)
  params : string Sln_map.String.t;
  run_id : 'run_id;
  runs_on : Yojson.Safe.t option;
  state : 'state;
  steps : Step.t list;
  tag_query : Terrat_tag_query.t;
  target : 'target;
}
[@@deriving show]

module New = struct
  type ('account, 'id, 'created_at, 'run_id, 'state, 'changes, 'denied_dirspaces, 'target) t' =
    ('account, 'id, 'created_at, 'run_id, 'state, 'changes, 'denied_dirspaces, 'target) t
  [@@deriving show]

  (** A new work manifest has no id, create time, run id, or state *)
  type ('account, 'target) t =
    ( 'account,
      unit,
      unit,
      unit,
      unit,
      int option Terrat_change.Dirspaceflow.t list,
      Deny.t list,
      'target )
    t'
  [@@deriving show]
end

module Existing = struct
  type ('account, 'id, 'created_at, 'run_id, 'state, 'changes, 'denied_dirspaces, 'target) t' =
    ('account, 'id, 'created_at, 'run_id, 'state, 'changes, 'denied_dirspaces, 'target) t
  [@@deriving show]

  (** An existing work manifest has all of the fillings *)
  type ('account, 'target) t =
    ( 'account,
      Uuidm.t,
      string,
      string option,
      State.t,
      int option Terrat_change.Dirspaceflow.t list,
      Deny.t list,
      'target )
    t'
  [@@deriving show]
end
