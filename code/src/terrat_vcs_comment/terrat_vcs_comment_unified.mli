(** Maintains a single "unified" summary comment for a pull request. Unlike {!Terrat_vcs_comment},
    which tracks and consolidates the comments of individual work manifest results, this module
    recomputes the state of every dirspace of the pull request from persistent storage on each
    refresh and renders it into one comment which is updated in place. *)

module Status : sig
  (** The lifecycle state of a dirspace in the pull request, ordered by urgency: failures sort
      before anything else, then plans awaiting an apply, then dirspaces that have not run yet, then
      successfully applied ones. *)
  type t =
    | Failed
    | Planned
    | Pending
    | Applied
  [@@deriving ord, show]

  val rank : t -> int
end

module Tier : sig
  (** How much of the elements to render, from richest to most compact. [Details n] renders the
      summary table plus inline output details for the first [n] elements in sorted order. [Table]
      renders only the summary table. [Truncated n] renders only the first [n] table rows plus a
      truncation notice. *)
  type t =
    | Details of int
    | Table
    | Truncated of int
  [@@deriving ord, show]
end

module type S = sig
  type t
  type el [@@deriving ord, show]
  type comment_id [@@deriving ord, show]

  (** The tracked unified comment for the pull request, if one was posted. *)
  val query_comment_id : t -> (comment_id option, [> `Error ]) result Abb.Future.t

  (** Recompute the current state of every dirspace of the pull request. An empty result means the
      state could not be established (for example the window between a new push and its run being
      created) and the comment must be left untouched. *)
  val query_els : t -> (el list, [> `Error ]) result Abb.Future.t

  val render : t -> Tier.t -> el list -> string

  (** [`Not_found] means the comment does not exist anymore (for example a user deleted it) and a
      new one should be posted. *)
  val update_comment :
    t -> comment_id -> string -> (unit, [> `Not_found | `Error ]) result Abb.Future.t

  val post_comment : t -> string -> (comment_id, [> `Error ]) result Abb.Future.t
  val upsert_comment_id : t -> comment_id -> (unit, [> `Error ]) result Abb.Future.t

  (** Element accessors used for sorting *)
  val dirspace : el -> Terrat_dirspace.t

  val status : el -> Status.t
  val has_changes : el -> bool

  (** Constraints *)

  (** Upper bound on a rendered comment, measured as {!Stdlib.String.length} of the string {!render}
      returns. The functor measures the raw string, so an adapter whose VCS charges against a
      different unit — GitHub counts the JSON-escaped body — has to absorb the difference into this
      bound itself. *)
  val max_comment_length : int
end

module Make (M : S) : sig
  (** Sort elements by (status rank, has changes, dirspace). Exposed for the renderer so the table
      and the details sections agree on the order. *)
  val sort_els : M.el list -> M.el list

  val run : M.t -> (unit, [> `Error ]) result Abb.Future.t
end
