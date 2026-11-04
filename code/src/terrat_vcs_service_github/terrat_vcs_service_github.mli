module type ROUTES = sig
  type config

  val routes :
    config ->
    Terrat_storage.t ->
    (Brtl_rtng.Method.t * Brtl_rtng.Handler.t Brtl_rtng.Route.Route.t) list
end

(** The service of a provider, given what the edition decides and Stategraph as the orchestration
    reaches it: the one of its process in the unified server, {!Terrat_stategraph.Standalone} on its
    own. *)
module Make
    (Shared :
      Terrat_vcs_provider2_github.Shared
        with type Api.Config.t = Terrat_vcs_service_github_provider.Api.Config.t)
    (_ : ROUTES with type config = Shared.Api.Config.t)
    (_ : Terrat_vcs_provider2.Edition)
    (_ : Terrat_stategraph.S) :
  Terrat_vcs_service.S with type Service.vcs_config = Shared.Api.Config.vcs_config
