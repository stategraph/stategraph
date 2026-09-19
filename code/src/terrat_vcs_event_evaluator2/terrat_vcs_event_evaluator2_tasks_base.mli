module Make
    (S : Terrat_vcs_provider2.S)
    (Keys : module type of Terrat_vcs_event_evaluator2_targets.Make (S)) : sig
  module Builder : module type of Terrat_vcs_event_evaluator2_builder.Make (S)

  val run :
    name:string ->
    (Builder.Bs.state -> Builder.Bs.Fetcher.t -> ('v, Builder.err) result Abb.Future.t) ->
    Builder.Bs.key_repr list ->
    Builder.Bs.state ->
    Builder.Bs.Fetcher.t ->
    ('v, Builder.err) result Abb.Future.t

  (** Publish a comment, turning a publish failure into [`Silent_failure] so that error handlers do
      not answer a failed publish by publishing again. *)
  val publish_comment' :
    ('msg -> (unit, [ `Error ]) result Abb.Future.t) ->
    'msg ->
    (unit, [> `Silent_failure ]) result Abb.Future.t

  (** Create commit checks, skipping the call entirely when there is nothing to create so that the
      commit checks are not dirtied. *)
  val create_commit_checks' :
    (S.Api.Ref.t ->
    Terrat_commit_check.t list ->
    (unit, Terrat_vcs_api.call_err) result Abb.Future.t) ->
    S.Api.Ref.t ->
    Terrat_commit_check.t list ->
    ( unit,
      [> `Vcs_api_err of string
      | `Vcs_api_rate_limit_err of string
      | `Vcs_api_timeout_err of string
      ] )
    result
    Abb.Future.t

  (** Create the completed [terrateam apply] commit check at the head of the pull request.

      A pull request that reached a noop still has to be mergeable, thus an operator who needs that
      check green to merge gets it even though no work was done. The caller decides that no work is
      left; this reads no matches of its own, so a caller that must not start a setup job can use
      it. *)
  val create_completed_apply_check :
    Builder.Bs.state -> Builder.Bs.Fetcher.t -> (unit, Builder.err) result Abb.Future.t

  (** The comment, if any, to publish for an evaluation error. [None] means publish nothing: either
      nothing went wrong or the user has already been told. *)
  val msg_of_err : Builder.err -> Keys.msg option

  (** Forward a standard keys that we want to pass between evals, because in an eval the store gets
      reset *)
  val forward_std_keys : Builder.State.t -> Builder.Hmap.t -> Builder.Hmap.t
end
