(** The decision a staleness comparison takes about one commit whose stored tree it needs (RFD
    2356).

    The comparison reads stored trees and nothing else, so a tree that is not stored is either read
    from the forge and stored, or the comparison gives up. Giving up is always safe: it answers
    [None], and every caller turns [None] into a stale verdict. *)
type t =
  | Use  (** The tree the comparison may read is stored. *)
  | Fetch  (** The tree is not stored and the caller must read it from the forge and store it. *)
  | Give_up  (** The tree is not stored and this call must answer now. *)
[@@deriving eq, show]

(** [decide ~missing_tree ~tree_builder ~built] is the decision for one commit.

    [built] is [true] when the tree the comparison may read is stored. [missing_tree] is the
    caller's policy for a tree that is not stored: [`Fetch] allows a read from the forge, and
    [`Unknown] does not. [tree_builder] is the tree builder setting of the repository: with the tree
    builder on, the trees the comparison reads are the ones the script made, thus a tree read from
    the forge does not answer, and no tree is read. *)
val decide : missing_tree:[ `Fetch | `Unknown ] -> tree_builder:bool -> built:bool -> t
