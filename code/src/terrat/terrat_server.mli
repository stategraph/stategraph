(** The routes of terrat's API that neither a VCS nor terrat's console needs: the admin drifts (when
    the admin token is set), [/health], [/metrics], tenv, the access-token refresh and infracost.
    [infracost] is [None] when cost estimation is off. *)
val api_routes :
  infracost:Terrat_ep_infracost.backend option ->
  Terrat_config.t ->
  Terrat_storage.t ->
  (Brtl_rtng.Method.t * Brtl_rtng.Handler.t Brtl_rtng.Route.Route.t) list

(** Send the telemetry start event and start the telemetry ping loop, which runs until the process
    ends. Nothing happens when telemetry is disabled. *)
val start_telemetry : Terrat_config.t -> unit Abb.Future.t

(** Serve terrat's API until the listener stops. It fails before listening when the session
    middleware cannot be created. *)
val run :
  infracost:Terrat_ep_infracost.backend option ->
  Terrat_config.t ->
  Terrat_storage.t ->
  Terrat_vcs_service.service list ->
  (unit, [> Terrat_session.err ]) result Abb.Future.t
