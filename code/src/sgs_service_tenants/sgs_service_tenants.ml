module Rt = struct
  let api_v1 () = Brtl_rtng.Route.(rel / "api" / "v1")
  let user_tenants () = Brtl_rtng.Route.(api_v1 () / "user" / "tenants")

  let tenants_create () =
    Brtl_rtng.Route.(
      api_v1 ()
      / "tenants"
      /* Body.decode ~json:Sgs_api_components_tenant_create_request.of_yojson ())

  let tenant () =
    Brtl_rtng.Route.(
      api_v1 ()
      / "tenants"
      /% Path.ud CCFun.(Uuidm.of_string %> CCOption.map (fun id -> Sgs_tenant.make ~id ())))

  let tenant_update () =
    Brtl_rtng.Route.(
      tenant () /* Body.decode ~json:Sgs_api_components_tenant_update_request.of_yojson ())

  let tenant_members () =
    Brtl_rtng.Route.(
      tenant ()
      / "members"
      /? Query.(option (string "cursor"))
      /? Query.(option_default 25 (int "limit")))

  (* The target user is a query parameter rather than a path segment, matching the existing
     /users/update?user_id= convention. *)
  let tenant_members_remove () = Brtl_rtng.Route.(tenant () / "members" /? Query.string "user_id")

  let tenant_members_add () =
    Brtl_rtng.Route.(
      tenant ()
      / "members"
      /* Body.decode ~json:Sgs_api_components_tenant_member_add_request.of_yojson ())

  let tenant_members_set_role () =
    Brtl_rtng.Route.(
      tenant ()
      / "members"
      / "set-role"
      /? Query.string "user_id"
      /* Body.decode ~json:Sgs_api_components_tenant_member_set_role_request.of_yojson ())

  let tenant_invitations () =
    Brtl_rtng.Route.(
      tenant ()
      / "invitations"
      /? Query.(option (string "cursor"))
      /? Query.(option_default 25 (int "limit")))

  let tenant_invitation_create () =
    Brtl_rtng.Route.(
      tenant ()
      / "invitations"
      /* Body.decode ~json:Sgs_api_components_invitation_create_request.of_yojson ())

  (* Re-issue and revoke take the invitation id as a query parameter, matching the
     /users/update?user_id= convention for a mutation's target. *)
  let tenant_invitation_reissue () =
    Brtl_rtng.Route.(tenant () / "invitations" / "reissue" /? Query.string "id")

  let tenant_invitation_revoke () =
    Brtl_rtng.Route.(tenant () / "invitations" / "revoke" /? Query.string "id")

  (* Unauthenticated: the invitation token is the credential, so this sits outside the tenant path. *)
  let invitation_preview () =
    Brtl_rtng.Route.(api_v1 () / "invitations" / "preview" /? Query.string "token")

  let invitation_accept () =
    Brtl_rtng.Route.(
      api_v1 ()
      / "invitations"
      / "accept"
      /* Body.decode ~json:Sgs_api_components_invitation_accept_request.of_yojson ())
end

module Make (Cloud : Sgs_cloud.S) = struct
  module Ep_invitation_create = Sgs_service_tenants_ep_invitation_create.Make (Cloud)
  module Ep_invitation_reissue = Sgs_service_tenants_ep_invitation_reissue.Make (Cloud)

  type t = {
    config : Sgs_config.t;
    storage : Sgs_storage.t;
  }

  type 'a Sgs_service.ty += Ty : t Sgs_service.ty

  let ty = Ty

  let matches (type a) (q : a Sgs_service.ty) : (t, a) Sgs_service.eq option =
    match q with
    | Ty -> Some Sgs_service.Refl
    | _ -> None

  let name = "tenants"

  type opt = Sgs_svc_mngr.t

  (* The routes need the config and the storage, so start loads them like any other dependency. *)
  let start mgr =
    let open Abbs_fc.Infix_result_monad in
    Abbs_fc.Result.all2
      (Sgs_svc_mngr.load ~name:Sgs_service_config.name Sgs_service_config.Ty mgr)
      (Sgs_svc_mngr.load ~name:Sgs_service_storage.name Sgs_service_storage.Ty mgr)
    >>| fun (config, storage) -> { config; storage }

  let routes { config; storage } =
    Brtl_rtng.Route.
      [
        (`GET, Rt.user_tenants () --> Sgs_service_tenants_ep_user_tenants.run config storage);
        (* Members before the bare tenant route: /members and /members/set-role are more specific
         than the tenant path they hang off, and the router matches in order. *)
        (`POST, Rt.tenants_create () --> Sgs_service_tenants_ep_create.run config storage);
        (`GET, Rt.tenant_members () --> Sgs_service_tenants_ep_members_list.run config storage);
        (`POST, Rt.tenant_members_add () --> Sgs_service_tenants_ep_members_add.run config storage);
        ( `POST,
          Rt.tenant_members_set_role ()
          --> Sgs_service_tenants_ep_members_set_role.run config storage );
        ( `DELETE,
          Rt.tenant_members_remove () --> Sgs_service_tenants_ep_members_remove.run config storage
        );
        (`PUT, Rt.tenant_update () --> Sgs_service_tenants_ep_update.run config storage);
        (* Invitations.  The two-segment routes come before the one-segment /invitations pair. *)
        (`POST, Rt.tenant_invitation_reissue () --> Ep_invitation_reissue.run config storage);
        ( `POST,
          Rt.tenant_invitation_revoke ()
          --> Sgs_service_tenants_ep_invitation_revoke.run config storage );
        ( `GET,
          Rt.tenant_invitations () --> Sgs_service_tenants_ep_invitation_list.run config storage );
        (`POST, Rt.tenant_invitation_create () --> Ep_invitation_create.run config storage);
        ( `GET,
          Rt.invitation_preview () --> Sgs_service_tenants_ep_invitation_preview.run config storage
        );
        ( `POST,
          Rt.invitation_accept () --> Sgs_service_tenants_ep_invitation_accept.run config storage );
      ]

  let stop _ = Abb.Future.return ()
end
