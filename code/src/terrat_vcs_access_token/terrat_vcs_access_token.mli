module type S = sig
  val vcs : string
end

module Make (P : Terrat_vcs_provider2.Shared) (_ : S) : sig
  val routes :
    P.Api.Config.t ->
    Terrat_storage.t ->
    (Brtl_rtng.Method.t * Brtl_rtng.Handler.t Brtl_rtng.Route.Route.t) list
end
