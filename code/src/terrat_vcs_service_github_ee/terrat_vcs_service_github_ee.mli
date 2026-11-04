(** The enterprise edition's Github service, given Stategraph as the orchestration reaches it: the
    one of its process in the unified server, {!Terrat_stategraph.Standalone} on its own. *)
module Make (_ : Terrat_stategraph.S) :
  Terrat_vcs_service.S with type Service.vcs_config = Terrat_config.Github.t
