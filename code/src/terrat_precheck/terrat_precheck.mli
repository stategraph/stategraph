(** The matching rules of [when_modified.prechecks].

    A precheck decides, from the static repository configuration alone, if a pull request is worth
    any work. If a check gives [false], the operation becomes a noop, and the tree builder, the
    config builder and the indexer never start. Each of those three costs an action run on every
    pull request, thus a check that answers first is the point of the feature.

    All of the list rules here obey the same rule for negations, which the entries of the list write
    with a leading [!]:

    - a list that holds negations only gets an implicit ['*'], thus it gives [true] for everything
      that no negation refuses;
    - a mixed list gets no implicit ['*'], thus a positive entry must match;
    - an empty list matches nothing.

    A check that cannot get its data gives [true], not [false]. A precheck stops work, thus missing
    data must let the usual evaluation continue. *)

(** [true] if [user] matches the list.

    The entries are exact names, not globs. An absent user gives [true], because the identity that
    the check reads is not known. *)
val match_user : users:string list -> string option -> bool

(** [true] if any path of [files] matches the list.

    These globs are repository paths and carry no [${DIR}] prefix, thus the caller gives the changed
    files of the pull request as the repository writes them. *)
val match_file_patterns :
  files:string list -> Terrat_base_repo_config_v1.File_pattern_list.t -> bool

(** [true] if [files] holds a path of the Terrateam configuration file.

    A pull request that rewrites the configuration always continues the usual evaluation: the
    configuration of the destination branch cannot describe a configuration that the pull request
    changes. *)
val changes_repo_config : string list -> bool

(** [Some true] if the changed files of [diff] match a dir of the fully-derived configuration
    [repo_config_json], which is the shape {!Terrat_base_repo_config_v1.to_version_1} writes.

    The dirs of that configuration are already expanded over the repository it was derived for, thus
    no tree and no index are needed to match against it.

    [None] when the configuration does not parse. The answer comes from a stored copy, thus a copy
    that cannot be read must not decide anything; the caller says what happens then. *)
val match_derived_config : diff:Terrat_change.Diff.t list -> Yojson.Safe.t -> bool option
