(** The names the repository configuration file can have.

    This is the file that holds the [when_modified], [dirs] and [workflows] of a repository, not the
    configuration of the server. A VCS service reads [.stategraph/config] first and falls back to
    [.terrateam/config], and it probes both extensions, thus a change to any of the four names is a
    change to the configuration. *)

val paths : string list

(** [true] if [path] is one of {!paths}. *)
val mem : string -> bool

(** [true] if the diff touches the configuration file.

    A rename counts on both of its names: a diff that moves the configuration away is as much a
    change to it as one that writes it. *)
val is_changed : Terrat_change.Diff.t list -> bool
