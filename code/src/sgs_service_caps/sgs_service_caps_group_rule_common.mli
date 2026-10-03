(** Shared pieces of the capability group-rule endpoints (create / list / get / delete) *)

(** An admin of [tenant] may manage its group rules; an installation-wide admin qualifies for any
    tenant, and a wider multi-tenant admin covering it qualifies too. *)
val manage_caps : 'a Sgs_tenant.t -> Sgs_user_session.Caps.t

val respond_json :
  status:Cohttp.Code.status_code -> string -> ('a, 'b) Brtl_ctx.t -> ('a, Brtl_rspnc.t) Brtl_ctx.t

(** Answer [400] with [id] and a human-readable [data] detail. *)
val bad_request : string -> string -> ('a, 'b) Brtl_ctx.t -> ('a, Brtl_rspnc.t) Brtl_ctx.t

(** Answer [422] with [id] and a human-readable [data] detail -- a well-formed request that is
    semantically invalid for the resource (a tenant rule whose grant reaches beyond its tenant). *)
val unprocessable : string -> string -> ('a, 'b) Brtl_ctx.t -> ('a, Brtl_rspnc.t) Brtl_ctx.t

(** Project a stored rule onto the API type. *)
val to_api : Sgs_caps_rules.rule -> Sgs_api_components_caps_group_rule.t
