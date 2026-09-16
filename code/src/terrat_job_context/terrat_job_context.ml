module Context = struct
  module Scope = struct
    type ('pr, 'branch) t =
      | Pull_request of 'pr
      | Branch of ('branch * 'branch option)
    [@@deriving show, eq]
  end

  type ('pr, 'branch) t = {
    created_at : string;
    id : Uuidm.t;
    scope : ('pr, 'branch) Scope.t;
    updated_at : string;
  }
  [@@deriving show, eq]
end

module Job = struct
  module Type_ = struct
    module Kind = struct
      type t = Drift of { reconcile : bool } [@@deriving show, eq]
    end

    type t =
      | Apply of {
          tag_query : Terrat_tag_query.t;
          kind : Kind.t option;
          force : bool;
        }
      | Autoapply
      | Autoplan
      | Gate_approval of { tokens : string list }
      | Help
      | Index
      | Plan of {
          tag_query : Terrat_tag_query.t;
          kind : Kind.t option;
        }
      | Push
      | Repo_config
      | Unlock of string list
    [@@deriving show, eq]
  end

  module State = struct
    type t =
      | Running
      | Completed
      | Failed
    [@@deriving show, eq]
  end

  type ('pr, 'branch, 'user) t = {
    completed_at : string option;
    context : ('pr, 'branch) Context.t;
    created_at : string;
    id : Uuidm.t;
    initiator : 'user;
    state : State.t;
    type_ : Type_.t;
    updated_at : string;
  }
  [@@deriving show, eq]
end

module Compute_node = struct
  module State = struct
    type t =
      | Queued
      | Starting
      | Running
      | Terminated
  end

  module Capabilities = struct
    module Flags = struct
      type t = One_shot [@@deriving yojson, show, eq]
    end

    type t = {
      flags : Flags.t list; [@default [ Flags.One_shot ]]
      sha : string;
    }
    [@@deriving yojson, show, eq]
  end

  type t = {
    id : Uuidm.t;
    state : State.t;
    capabilities : Capabilities.t;
    created_at : string;
    updated_at : string;
  }
end

module Compute_node_work = struct
  module State = struct
    type t =
      | Created
      | Completed
      | Aborted
  end

  type t = {
    compute_node_id : Uuidm.t;
    created_at : string;
    state : State.t;
    (* An empty [work] shows that the node has the work manifest, but that the
       server has not made the response for the action yet. *)
    work : Terrat_api_components.Work_manifest.t option;
    work_manifest : Uuidm.t;
  }
end
