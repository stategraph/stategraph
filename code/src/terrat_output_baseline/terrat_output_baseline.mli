(** Finds the outputs that an [outputs:] term of a [depends_on] compares against.

    The baseline of a dirspace is the outputs of its most recent successful apply in another pull
    request of the same repository. That apply is what represents the infrastructure now, so a
    dependent only needs to run if the current apply changed an output relative to it. The applies
    of the pull request under evaluation are excluded, so a second apply in the same pull request is
    still compared against the other pull request. *)

type err = Pgsql_io.err [@@deriving show]

(** The apply step that recorded the outputs, and the outputs. [step] tells the layout of [outputs],
    for example [tf/apply] or [custom/apply]. [outputs] is [None] when the step recorded no
    [outputs] key. *)
type row = {
  step : string;
  outputs : Yojson.Safe.t option;
}
[@@deriving show, eq]

(** The baseline of [dirspace] for [pull_request] in [repo], or [None] if no other pull request has
    applied [dirspace] successfully. [repo] and [pull_request] are the ids of the VCS-neutral
    tables.

    When [pull_request] has applied [dirspace], the baseline is older than its most recent apply.
    Thus an apply in another pull request after that apply does not change the baseline, and the
    dependents that were pruned stay pruned. *)
val query :
  Pgsql_io.t ->
  repo:Uuidm.t ->
  pull_request:Uuidm.t ->
  dirspace:Terrat_dirspace.t ->
  (row option, [> err ]) result Abb.Future.t

(** The outputs of the most recent successful apply of [dirspace] in [pull_request], or [None] if
    [pull_request] has not applied [dirspace]. This is the side that {!query} is compared to. *)
val current :
  Pgsql_io.t ->
  repo:Uuidm.t ->
  pull_request:Uuidm.t ->
  dirspace:Terrat_dirspace.t ->
  (row option, [> err ]) result Abb.Future.t

(** The baseline and the current outputs of [dirspace] in [pull_request], ready to compare, or
    [None] if [pull_request] has not applied [dirspace]. A dirspace can count as applied without an
    apply, when its plan had no changes; it gets [None] as well. The caller reads [None] for an
    applied dirspace as no output changed, so its dependents are pruned.

    The step name sets the shape: [tf/apply] is [Tf_wrapped] and every other step is [Raw]. A
    baseline with a shape different from the current one counts as no baseline. *)
val outputs :
  Pgsql_io.t ->
  repo:Uuidm.t ->
  pull_request:Uuidm.t ->
  dirspace:Terrat_dirspace.t ->
  (Terrat_output_diff.t option, [> err ]) result Abb.Future.t
