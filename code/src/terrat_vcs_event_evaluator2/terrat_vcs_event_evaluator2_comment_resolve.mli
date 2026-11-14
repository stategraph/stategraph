(** The comment-to-job table of a pull request comment.

    [resolve] owns the whole table that the pull request evaluation used to spell inline: a run
    command becomes the job of its verb with its parameters validated against the repository
    configuration, an alias expands into the verb its [action] names, and every other comment
    becomes the job it always made. The validation answers before a job exists, so a comment the
    configuration rejects starts no run and the reply names the parameter the comment wrote. *)

type reply =
  [ `Not_a_run
    (** The comment names a run the evaluator does not run: [apply-autoapprove], directly or through
        an alias. *)
  | `Parameter_err of Terrat_vcs_provider2.Msg.parameter_err
    (** The parameters of the comment do not decode against the configuration; the payload is what
        the reply to the comment renders. *)
  | `Unknown_command
    (** The comment names no command this system has: a misspelled verb, or an alias the
        configuration does not declare. *)
  ]

(** [needs_config comment] answers whether resolving [comment] reads the repository configuration.
    Only an alias, which the configuration declares, and a run command that carries parameters,
    which the configuration validates, need it; [help] and the other commands answer even when the
    configuration does not decode. *)
val needs_config : Terrat_comment.t -> bool

(** [resolve ~config comment] answers the job the comment asks for, or the reply to publish.
    [config] is the [parameters] section of the repository configuration, or [None] when
    {!needs_config} answered false for the comment; a comment that carries no parameter never reads
    it, so a plain [plan] runs on a repository whose configuration does not decode. *)
val resolve :
  config:Terrat_base_repo_config_v1.Parameters.t option ->
  Terrat_comment.t ->
  (Terrat_job_context.Job.Type_.t, reply) result
