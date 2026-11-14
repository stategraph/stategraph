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
      type t =
        | Drift of {
            reconcile : bool;
            restart_on_change : bool;
          }
      [@@deriving show, eq]
    end

    (* The parameters of the run, resolved to their values.  The map rides on
       the job so that every task of the evaluation, and every job a run
       continues, reads the same values.  A run that a comment starts is a
       [Plan] or an [Apply], and so is every later layer of it, because a
       continuation carries the map forward.  [Autoapply] and [Autoplan] carry
       no map: the system starts them, and no comment chose their parameters. *)
    module Params = struct
      type t = string Sln_map.String.t [@@deriving yojson, show, eq]
    end

    type t =
      | Apply of {
          tag_query : Terrat_tag_query.t;
          kind : Kind.t option;
          force : bool;
          parameters : Params.t;
        }
      | Autoapply
      | Autoplan
      | Gate_approval of { tokens : string list }
      | Help
      | Index
      | Plan of {
          tag_query : Terrat_tag_query.t;
          kind : Kind.t option;
          parameters : Params.t;
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

  (* What the action run of a node was started with.  A work manifest can join a
     node only when the node can run it, and this is what the server asks.

     [environment] and [runs_on] are inputs of the workflow dispatch, and the VCS
     reads them when it schedules the job, so they hold for the life of the run.
     A work manifest that joins a run takes the values of that run, not its own.

     [used_work_manifests] is how many work manifests the node has been given.
     It is charged when the work manifest joins the node, and not when the run
     serves it, so it never goes down: a work manifest that a later poll moves to
     a node of its own, and one that finishes, both stay counted.  The count is
     therefore an upper bound on how many the node performs, and that upper bound
     is what the action needs.  The action stops after a fixed number of turns of
     its loop, and one turn serves one work manifest, so a node given more work
     than that would leave a work manifest on a run that has gone.
     [batch_runs.max_work_manifests_per_node] gives the limit.

     [merge_phase] is the phase of the work the node was made for, and it never
     changes after that.  [batch_runs.merge_steps] of [by_phase] holds a wall
     between the setup phase and the layer phase, and this is the side of the
     wall the node is on.  [None] is a node that has no phase: a node a version
     before this field made, or a node made for a work manifest of no step or of
     several.  No work manifest joins such a node under [by_phase].

     Every field but [sha] carries a default.  The column is jsonb, so a row
     written before these fields existed must still decode.  [to_capabilities] in
     each provider turns a decode error into [None], and [Ret.u] turns that into
     [`Bad_result], which fails the whole query.  Every read of the node then
     fails, and the work manifest of that node waits for ever.

     The deriving is lenient for that reason: a row that carries a field this
     record no longer has must still decode.  [max_workspaces] and
     [used_workspaces] were such fields, and every row written before they went
     carries both. *)
  module Capabilities = struct
    module Flags = struct
      type t = One_shot [@@deriving yojson, show, eq]
    end

    module Merge_phase = struct
      type t =
        | Layer
        | Setup
      [@@deriving yojson, show, eq]
    end

    type t = {
      flags : Flags.t list; [@default [ Flags.One_shot ]]
      sha : string;
      environment : string option; [@default None]
      runs_on : Yojson.Safe.t option; [@default None]
      used_work_manifests : int; [@default 0]
      merge_phase : Merge_phase.t option; [@default None]
    }
    [@@deriving yojson { strict = false }, show, eq]
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
