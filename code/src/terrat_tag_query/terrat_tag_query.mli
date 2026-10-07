module Ctx : sig
  type t

  (** [working_dirspace] is the dirspace that is currently being evaluated. This is necessary to use
      [relative_dir] in the tag query.

      [outputs] is the baseline and current outputs of [dirspace], present once [dirspace] has been
      applied. The [outputs:] and [relative_outputs:] terms use it to decide whether an output
      changed. When it is absent, those terms mean the same as [dir:] and [relative_dir:], so the
      dependency graph can be built before anything has been applied. *)
  val make :
    ?working_dirspace:Terrat_dirspace.t ->
    ?outputs:Terrat_output_diff.t ->
    dirspace:Terrat_dirspace.t ->
    unit ->
    t
end

type t [@@deriving show, eq]

(** A query that parsed but was written in a way worth telling the user about.

    [Implicit_and] means two expressions were separated by whitespace alone, which is an [and].
    [suggestion] is the same query with every operand joined by [or], and is only present when the
    query is made of nothing but directory selectors: [dir:a dir:b] and [dir:a or dir:b dir:c]
    cannot match every directory named, so [or] is certainly what was meant, while
    [dir:a workspace:prod] is a sensible [and] and gets no rewrite. *)
type warning = Implicit_and of { suggestion : string option } [@@deriving show]

val of_string : string -> (t, [> Terrat_tag_query_ast.err ]) result
val to_string : t -> string

(** The warning, if any, the query was parsed with. It stays on the query rather than being returned
    by {!of_string} so that it survives a round trip through storage, and so that only the call
    points that act on a warning have to know it exists. *)
val warning : t -> warning option

(** [dirspace] is used in tests against the [dir] and [workspace] and [in dir] tests. *)
val match_ : ctx:Ctx.t -> tag_set:Terrat_tag_set.t -> t -> bool

(** Whether the query names dirspaces and nothing else, thus every tag in it starts with [dir:] or
    with [workspace:] and the query holds no negation.

    This is the test for the force mode of a [stategraph plan] comment: such a query names the work
    the user wants run, thus that work runs although the file hashes say it needs no new plan. Any
    other query keeps the defaults of the algorithm and plans the work which has no current plan.

    An [in dir <glob>] selector, and the [dir~<glob>] form of it, answer false: they choose
    directories by a glob rather than naming them. An [outputs:] term answers false: it can select
    no dirspace when the outputs did not change. A negation answers false wherever it sits, because
    a negation says what must not run, and a force must say what must run. The empty query, which
    matches everything, answers false. *)
val selects_dirspaces_only : t -> bool

(** Whether the query is the empty query, the match-all a comment carries when it named no tag
    query. A plain [terrateam plan] parses to it, and it is the query for which the reset rule of a
    plain plan fires. *)
val is_empty : t -> bool

(** Whether the query holds an [outputs:] or a [relative_outputs:] term. Only such a query can prune
    a dependent when the outputs of its dependency did not change. *)
val uses_outputs : t -> bool

(** A pre-defined matcher that matches anything, equivalent to [of_string ""] *)
val any : t
