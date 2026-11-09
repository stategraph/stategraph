(** The decision whether the commits that moved during a run make the work of that run stale.

    A run uses the files of one commit. Another push or merge can move the branch while the run
    operates. A move is not enough to make the run stale: only a change to a file that one of its
    dirspaces uses does (RFD 2356). The caller compares the stored trees of the two commits and
    gives the dirspaces that changed; this module holds the rules that turn that answer into a
    decision, so that they can be read and tested without a database or a VCS. *)

(** What the comparison of two commits says about the dirspaces of a run. *)
type t =
  | Not_impacted  (** No file of a dirspace of the run changed. *)
  | Impacted of Terrat_dirspace.t list
      (** These dirspaces of the run have a changed file. The list is sorted and holds no duplicate.
      *)
  | Unknown  (** The tree of one of the two commits is not stored, thus nothing was compared. *)
[@@deriving eq, show]

(** [decide ~changed dirspaces] is the impact on the dirspaces of a run. [changed] is the set of
    dirspaces with a changed file between the two commits, or [None] when a tree is not stored. *)
val decide : changed:Terrat_data.Dirspace_set.t option -> Terrat_dirspace.t list -> t

(** [union a b] is the impact of two comparisons of one run together. The run of an open pull
    request uses the head of its branch and the head of the destination branch, and a move of either
    can make it stale. An unknown comparison makes the whole impact unknown, because the rules fail
    safe; otherwise the impacted dirspaces of both are impacted. *)
val union : t -> t -> t

(** What to do when a run starts and the commits moved. An unknown impact restarts, as a proven
    impact does, because the rules fail safe (RFD 2356, Fail safe): a run must not change
    infrastructure from a plan that can be stale. The evaluation after the restart builds the tree
    and the config of the head, thus the next start at that head can decide. The limit on the aborts
    of a job stops a branch that keeps moving. *)
module Start : sig
  type decision =
    | Run
    | Restart
  [@@deriving eq, show]

  val decide : t -> decision

  (** [uncovered_dirspaces ~live aborted] is the dirspaces of the [aborted] work manifests of a slot
      that no work covers yet, thus the slot makes work again. A live work manifest covers an
      aborted one when it has its dirspaces, or when it was made after the aborted one. The work
      that an abort asks for is made at the commits of that later evaluation, thus its dirspaces can
      be different when the commits moved (RFD 2356). Without the second rule, the slot makes work
      again after each result, without end. *)
  val uncovered_dirspaces :
    live:
      ('a, 'b, string, 'c, 'd, 'e Terrat_change.Dirspaceflow.t list, 'f, 'g) Terrat_work_manifest3.t
      list ->
    ('a, 'b, string, 'c, 'd, 'e Terrat_change.Dirspaceflow.t list, 'f, 'g) Terrat_work_manifest3.t
    list ->
    Terrat_data.Dirspace_set.t
end

(** What to report when the result of a pull request run arrives and the commits moved. The output
    is always posted; this says whether a stale message goes with it. An unknown impact is reported
    as stale, because the result is the last check and it must never hide a real change. *)
module Pr_result : sig
  type decision =
    | Fresh
    | Stale_files_changed of Terrat_dirspace.t list
    | Stale_files_unknown
  [@@deriving eq, show]

  val decide : t -> decision

  (** [stale_dirspaces decision dirspaces] is the set of the [dirspaces] of a run whose result is
      stale: none when it is fresh, the changed ones, or all of them when the impact is unknown. The
      checks and the stale message of a result use the same set. *)
  val stale_dirspaces : decision -> Terrat_dirspace.t list -> Terrat_data.Dirspace_set.t
end

(** What to do when the result of a drift reconcile arrives and the commits moved. An unknown impact
    reconciles again, as a proven impact does, because the rules fail safe (RFD 2356, Fail safe).
    The limit on the chain of restarts stops a branch that keeps moving. *)
module Drift_result : sig
  type decision =
    | Resolved
    | Reconcile_again
  [@@deriving eq, show]

  val decide : t -> decision

  (** Whether a drift that must reconcile again gets a new job. [Limit_reached] stops a branch that
      keeps moving, because each move can make the reconcile stale again. [Disabled] is a drift
      whose schedule sets [restart_on_change: false]. *)
  type restart =
    | Restart
    | Limit_reached
    | Disabled
  [@@deriving eq, show]

  (** [restart ~restart_on_change ~restarts] is the restart decision for a drift that already
      reconciled again [restarts] times. A drift reconciles again at most 10 times:
      [restart ~restart_on_change:true ~restarts:9] is [Restart], and
      [restart ~restart_on_change:true ~restarts:10] is [Limit_reached]. With
      [~restart_on_change:false] it is always [Disabled]. *)
  val restart : restart_on_change:bool -> restarts:int -> restart
end

(** The state of a dirspace of a pull request at its head, which the unified summary comment shows.
    A run on an older commit can still count for the head (RFD 2356), thus the state comes from the
    same rules as the checks, and not only from the runs on the head. *)
module Summary : sig
  (** [decide ~applied ~planned ~failed dirspace] is the state of [dirspace] from the sets of
      dirspaces whose runs count for the head. A newest run that failed decides the state, as it
      decides the check. An applied dirspace has a good plan too, thus [Applied] comes before
      [Planned]. A dirspace with no run that counts has no state: the summary does not show a
      dirspace that never ran, for example a dirspace that access control denied. *)
  val decide :
    applied:Terrat_data.Dirspace_set.t ->
    planned:Terrat_data.Dirspace_set.t ->
    failed:Terrat_data.Dirspace_set.t ->
    Terrat_dirspace.t ->
    Terrat_vcs_provider2.Dirspace_summary.t option

  (** [of_result ~run ~stale ~no_changes dirspace success] is the state of [dirspace] after a result
      of the given [run]. A stale result is not valid (RFD 2356, Stale results considered invalid):
      a dirspace in [stale] must be planned again. A failed dirspace is failed, stale or not. A good
      plan of a dirspace in [no_changes] found nothing to apply, thus the dirspace is applied, as
      the selection of the dirspaces to run counts it (RFD 2108). *)
  val of_result :
    run:[ `Plan | `Apply ] ->
    stale:Terrat_data.Dirspace_set.t ->
    no_changes:Terrat_data.Dirspace_set.t ->
    Terrat_dirspace.t ->
    bool ->
    Terrat_vcs_provider2.Dirspace_summary.t
end
