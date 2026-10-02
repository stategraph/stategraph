(* An admin of [tenant] may manage its group rules; an installation-wide admin qualifies for any
   tenant, and a wider multi-tenant admin covering [tenant] qualifies too. Mirrors
   [Sgs_tenant_members_common.manage_members_caps]. *)
let manage_caps tenant = Sgs_user_session.Caps.admin_tenant (Uuidm.to_string (Sgs_tenant.id tenant))
let respond_json ~status body ctx = Brtl_ctx.set_response (Brtl_rspnc.create ~status body) ctx

(* 400 with a machine-readable [id] and a human-readable [data] detail. *)
let bad_request id data ctx = Sgs_eplib.respond_error ~status:`Bad_request ~id ~data ctx

(* 422 with a machine-readable [id] and a human-readable [data] detail: the request is well-formed
   but semantically invalid for the resource -- a tenant rule whose grant reaches beyond its tenant.
   Distinct from the 400 the malformed-condition / invalid-glob cases return. *)
let unprocessable id data ctx = Sgs_eplib.respond_error ~status:`Unprocessable_entity ~id ~data ctx

(* [Condition.of_yojson] is total on our own [cond_to_yojson] output, so the default is unreachable. *)
let api_condition c =
  Sgs_api_components_caps_group_rule.Condition.of_yojson (Sgs_caps_rules.cond_to_yojson c)
  |> CCResult.get_or
       ~default:(Sgs_api_components_caps_group_rule.Condition.make Json_schema.Empty_obj.t)

(* Project a stored rule onto the API type. The owning [tenant_id] is intentionally not surfaced:
   the caller already scopes the request to one tenant. *)
let to_api
    { Sgs_caps_rules.id; created_at; created_by; description; condition; grant; tenant_id = _ } =
  let id = Uuidm.to_string id in
  let created_by = Uuidm.to_string created_by in
  let condition = api_condition condition in
  {
    Sgs_api_components_caps_group_rule.id;
    created_at;
    created_by;
    description;
    condition;
    grant = Sg_caps_json.to_wire grant;
  }
