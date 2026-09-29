(** Checks and answers shared by the orchestration endpoints. *)

(** Answer, and log, [503] [ORCHESTRATION_UNAVAILABLE]: with [STATEGRAPH_ORCHESTRATION_ENABLED] off,
    an orchestration endpoint fails this way instead of erroring on the missing terrateam schema.
    [src] is the log source, and it defaults to this module's [src]; prefer passing the endpoint's
    own. *)
val respond_orchestration_unavailable :
  ?src:Logs.src -> ('a, 'b) Brtl_ctx.t -> ('a, Brtl_rspnc.t) Brtl_ctx.t

(** Log the [ORCHESTRATION_UNAVAILABLE] line {!respond_orchestration_unavailable} writes, without
    answering: for an endpoint that answers some other way, such as a redirect. *)
val log_orchestration_unavailable : ?src:Logs.src -> ('a, 'b) Brtl_ctx.t -> unit

(** Whether VCS installation provisioning can run on this server. Provisioning writes through the
    admin FDW channel, and the FDW reconcile builds that channel only when orchestration is enabled
    and [STATEGRAPH_FDW_PROVISIONER_PASSWORD] is set. Without it, a write fails on the missing
    [terrateam_admin] schema. *)
val provisioning_availability :
  Sgs_config.t -> [ `Orchestration_disabled | `Provisioner_not_configured | `Available ]

(** Answer, and log, [503] for a server where provisioning cannot run: [ORCHESTRATION_UNAVAILABLE]
    as {!respond_orchestration_unavailable} does, or [PROVISIONING_UNAVAILABLE]. [src] defaults to
    this module's; prefer passing the endpoint's own. *)
val respond_provisioning_unavailable :
  ?src:Logs.src ->
  ('a, 'b) Brtl_ctx.t ->
  [< `Orchestration_disabled | `Provisioner_not_configured ] ->
  ('a, Brtl_rspnc.t) Brtl_ctx.t

(** [Ok ()] for a VCS provider the orchestration engine knows ([github] or [gitlab]). *)
val check_provider : string -> (unit, [> `Invalid_provider_err ]) result

(** Answer, and log, [400] [VCS_INSTALLATION_INVALID_PROVIDER] for a [provider] that
    {!check_provider} refuses. [src] defaults to this module's; prefer passing the endpoint's own.
*)
val respond_invalid_provider :
  ?src:Logs.src -> provider:string -> ('a, 'b) Brtl_ctx.t -> ('a, Brtl_rspnc.t) Brtl_ctx.t

(** Answer [200] with the [vcs-installation] body of [installation]. *)
val respond_installation :
  ('a, 'b) Brtl_ctx.t ->
  Sgs_service_orchestration_tenant_vcs_installations.t ->
  ('a, Brtl_rspnc.t) Brtl_ctx.t

(** Answer [302] with an empty body and [Location: location]. [headers] carries the other response
    headers, such as a [Set-Cookie]. *)
val respond_found :
  ?headers:Cohttp.Header.t ->
  location:string ->
  ('a, 'b) Brtl_ctx.t ->
  ('a, Brtl_rspnc.t) Brtl_ctx.t
