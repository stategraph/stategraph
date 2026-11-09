(** The rules which decide, on a push to a pull request, which dirspaces must run again and which
    dirspaces keep the result of an earlier run.

    Orchestration connects a run to the head commit sha of a branch. Thus a push makes every
    dirspace of the pull request unapplied and unplanned, although the push can touch one dirspace
    only. These rules replace that sha test with a file test: a dirspace keeps the result of its
    last run while the files which that dirspace uses keep the same hashes.

    The rules are pure. They speak only of dirspaces, runs and the dirspaces a dirspace waits for,
    thus they need no database and no VCS. *)

(** One run of one dirspace, as the database recorded it. *)
module Run : sig
  type t = {
    sha : string;  (** The head commit sha which the run used. *)
    created_at : string;
        (** The time of the work manifest, as [YYYY-MM-DDTHH:MM:SSZ]. The format has a constant
            width, thus a comparison of two of these strings is a comparison of two times. *)
    during : (string * string) list;
        (** The pairs of commits [(from, to)] that moved while the run operated: the heads at the
            start and at the result of the run (RFD 2356). A change to a file of the dirspace
            between the two commits of a pair makes the run stale. Empty for a run that ran before
            the heads were recorded, or when nothing moved. *)
  }
  [@@deriving eq, ord, show]
end

(** Whether a run is a plan or an apply. The two kinds compare with different heads: the apply of a
    merged pull request changed the infrastructure at its commit, and a later change to the
    destination does not undo it. *)
module Kind : sig
  type t =
    | Plan
    | Apply
  [@@deriving eq, show]
end

(** One plan of one dirspace. A plan which found no changes makes the dirspace applied, because
    there is nothing to apply. *)
module Plan : sig
  type t = {
    run : Run.t;
    has_changes : bool;
  }
  [@@deriving eq, show]
end

(** What the database knows about one dirspace of the pull request. *)
module Dirspace_state : sig
  type t = {
    dirspace : Terrat_dirspace.t;
    last_plan : Plan.t option;  (** The most recent plan which was a success. *)
    last_apply : Run.t option;  (** The most recent apply which was a success. *)
  }
  [@@deriving eq, show]
end

module Selection : sig
  (** The lists are in the order of {!Terrat_dirspace.compare} and hold no duplicate, thus the
      result does not change with the order of the input. No dirspace is in both [to_run] and
      [applied], thus the caller does not have to know which of them wins. *)
  type t = {
    to_run : Terrat_dirspace.t list;
        (** The dirspaces which must run. A dirspace is here when it has no plan which is still
            good, when its newest run failed, or when the user forced it. A dirspace which counts as
            applied is never here. *)
    out_of_order : Terrat_dirspace.t list;
        (** The dirspaces of [to_run] whose plan is good for their own files, but older than a run
            of a dirspace they wait for. No file and no commit made that plan bad, thus a caller
            that tells the user why a dirspace needs a plan gives these a reason of their own. *)
    applied : Terrat_dirspace.t list;
        (** The dirspaces which count as applied. The caller removes these from the work which is
            left, thus the evaluation stays where it reached in the tree. *)
  }
  [@@deriving eq, show]
end

(** [select ~changed_since ~changed_between ~force ~superseded ~last_run_failed ~depends_on states]
    is the dirspaces to run and the dirspaces which count as applied.

    [changed_since kind run] is the set of dirspaces which have at least one file with a different
    hash at the commit of [run] than at the head that a run of [kind] is compared with now. The
    caller makes this set from a comparison of the two stored trees, thus the cost is a function of
    the number of files which changed and not of the number of files in the repository.

    [changed_between from to] is the set of dirspaces with a file that changed between the two
    commits of a pair of {!Run.during}. A commit whose tree is not stored gives every dirspace: the
    rules fail safe. Once the tree is stored, the same pair can give a smaller set, and a run which
    was stale becomes good again (RFD 2356, Retroactive freshness).

    [force] is the set of dirspaces which a tag query of an explicit [terrateam plan] comment
    matched. A dirspace of [force] which is not in [states] does nothing: force planning reaches
    only the dirspaces which the pull request changes.

    [superseded] is the set of dirspaces which another pull request applied or merged after every
    run this pull request has for them. No file of this branch records that, thus the file test
    alone cannot find it: the tree of this branch is the same before and after the other pull
    request lands. Such a dirspace has no good run at all, thus it plans again and it counts as
    unapplied.

    [last_run_failed] is the set of dirspaces whose newest run of this pull request was not
    successful. [states] cannot hold that run, because [states] carries the successful runs only,
    thus the newest run [states] knows is the one before the failure. Such a dirspace runs again,
    because the apply gate refuses it for this same reason and there must be one answer. It does not
    touch the applied test: a plan which failed takes nothing away from an apply which succeeded.

    [depends_on dirspace] is the dirspaces that [dirspace] waits for, transitively. A layered run is
    a tree: a dirspace waits for the dirspaces it depends on and for nothing else, so two branches
    of the tree are walked in any order. A dirspace that waits for nothing has an empty set.

    A run of a dirspace is good when that dirspace is not in [superseded], not in [changed_since] of
    that run, and not in [changed_between] of a pair of {!Run.during} of that run. From this:

    - A dirspace runs when [force] holds it, when [last_run_failed] holds it, or when it has no good
      plan.
    - A plan is not good when an apply which is not older than the plan is not good. That apply used
      the plan, and a stale apply is not valid (RFD 2356, Stale results considered invalid): the
      dirspace must be planned again.
    - A dirspace which counts as applied never runs. It has nothing left to do, and this is what
      keeps the two lists apart.
    - A dirspace counts as applied when it has a good apply, or a good plan which found no changes.
    - A good apply counts only when it is not older than the good plan of the same dirspace. A plan
      which is newer than the apply is work which nobody applied yet. Thus the rewind which a force
      starts outlives the evaluation which carries the tag query: [force] is empty again when the
      user applies, but the plan which the force made is still there.
    - A plan and an apply count only when they are not older than each run of each dirspace the
      dirspace waits for. A run of another branch of the tree says nothing about this dirspace.
    - A dirspace counts as applied only when [force] holds neither it nor a dirspace it waits for.
      This makes the tree rewind at the moment of the force, before the forced run exists. *)
val select :
  changed_since:(Kind.t -> Run.t -> Terrat_data.Dirspace_set.t) ->
  changed_between:(string -> string -> Terrat_data.Dirspace_set.t) ->
  force:Terrat_data.Dirspace_set.t ->
  superseded:Terrat_data.Dirspace_set.t ->
  last_run_failed:Terrat_data.Dirspace_set.t ->
  depends_on:(Terrat_dirspace.t -> Terrat_data.Dirspace_set.t) ->
  Dirspace_state.t list ->
  Selection.t

(** [without_in_progress ~in_progress ~force selection] is the dirspaces to plan of a second
    [terrateam plan] on [selection]: the dirspaces of [to_run] that no plan of the pull request is
    planning now. A second [terrateam plan] is a noop for such a dirspace: the plan that is running
    answers for it.

    [in_progress] pairs each such dirspace with the set of dirspaces whose files changed since its
    plan started. A dirspace in that set is not removed: a push made the running plan stale, and the
    dirspace is planned again. A dirspace of [force] is not removed either: a tag query which names
    it is a request to run it now, which is what [Terrat_tag_query.selects_dirspaces_only] answers
    for and what the comment which offers that command promises. Only the dirspaces to plan are
    filtered: the caller reads the other fields of [selection] from [selection] itself, whose
    [to_run] stays as the rules computed it. *)
val without_in_progress :
  in_progress:(Terrat_dirspace.t * Terrat_data.Dirspace_set.t) list ->
  force:Terrat_data.Dirspace_set.t ->
  Selection.t ->
  Terrat_data.Dirspace_set.t
