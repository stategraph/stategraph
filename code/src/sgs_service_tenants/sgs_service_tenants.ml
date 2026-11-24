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
    let with_tenant run tenant_id = run config storage (Sgs_tenant.make ~id:tenant_id ()) in
    let retention_routes =
      match Cloud.new_user_tenant () with
      | `Personal_tenant ->
          Brtl_rtng.Route.
            [
              ( `POST,
                Sgs_api_tenants.Close.route () --> with_tenant Sgs_service_tenants_ep_close.run );
              ( `POST,
                Sgs_api_tenants.Reopen.route () --> with_tenant Sgs_service_tenants_ep_reopen.run );
              ( `GET,
                Sgs_api_user.Closed_tenants.route ()
                --> Sgs_service_tenants_ep_closed_tenants.run config storage );
            ]
      | `Default_tenant -> []
    in
    retention_routes
    @ Brtl_rtng.Route.
        [
          ( `GET,
            Sgs_api_user.Tenants.route () --> Sgs_service_tenants_ep_user_tenants.run config storage
          );
          (* Members before the bare tenant route: /members and /members/set-role are more specific
         than the tenant path they hang off, and the router matches in order. *)
          ( `POST,
            Sgs_api_tenants.Create.route ()
            /* Body.decode ~json:Sgs_api_components_tenant_create_request.of_yojson ()
            --> Sgs_service_tenants_ep_create.run config storage );
          ( `GET,
            Sgs_api_tenants.List_members.route ()
            --> with_tenant Sgs_service_tenants_ep_members_list.run );
          ( `POST,
            Sgs_api_tenants.Add_member.route ()
            /* Body.decode ~json:Sgs_api_components_tenant_member_add_request.of_yojson ()
            --> with_tenant Sgs_service_tenants_ep_members_add.run );
          (* The target user is a query parameter rather than a path segment, matching the existing
             /users/update?user_id= convention. *)
          ( `POST,
            Sgs_api_tenants.Set_member_role.route ()
            /* Body.decode ~json:Sgs_api_components_tenant_member_set_role_request.of_yojson ()
            --> with_tenant Sgs_service_tenants_ep_members_set_role.run );
          ( `DELETE,
            Sgs_api_tenants.Remove_member.route ()
            --> with_tenant Sgs_service_tenants_ep_members_remove.run );
          ( `PUT,
            Sgs_api_tenants.Update.route ()
            /* Body.decode ~json:Sgs_api_components_tenant_update_request.of_yojson ()
            --> with_tenant Sgs_service_tenants_ep_update.run );
          (* Invitations.  The two-segment routes come before the one-segment /invitations pair.
             Re-issue and revoke take the invitation id as a query parameter, matching the
             /users/update?user_id= convention for a mutation's target. *)
          ( `POST,
            Sgs_api_tenants.Reissue_invitation.route () --> with_tenant Ep_invitation_reissue.run );
          ( `POST,
            Sgs_api_tenants.Revoke_invitation.route ()
            --> with_tenant Sgs_service_tenants_ep_invitation_revoke.run );
          ( `GET,
            Sgs_api_tenants.List_invitations.route ()
            --> with_tenant Sgs_service_tenants_ep_invitation_list.run );
          ( `POST,
            Sgs_api_tenants.Create_invitation.route ()
            /* Body.decode ~json:Sgs_api_components_invitation_create_request.of_yojson ()
            --> with_tenant Ep_invitation_create.run );
          (* Unauthenticated: the invitation token is the credential, so this sits outside the tenant
           path. *)
          ( `GET,
            Sgs_api_invitations.Preview.route ()
            --> Sgs_service_tenants_ep_invitation_preview.run config storage );
          ( `POST,
            Sgs_api_invitations.Accept.route ()
            /* Body.decode ~json:Sgs_api_components_invitation_accept_request.of_yojson ()
            --> Sgs_service_tenants_ep_invitation_accept.run config storage );
        ]

  let wrap _ = CCFun.id
  let stop _ = Abb.Future.return ()
end
