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

let name = "orchestration"

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
  Brtl_rtng.Route.
    [
      ( `GET,
        Sgs_api_vcs_installations.List_unclaimed_github.route ()
        --> fun cursor limit ->
        Sgs_service_orchestration_ep_vcs_installation_unclaimed_github.run
          ~cursor
          ~limit
          config
          storage );
      ( `GET,
        Sgs_api_tenants.List_vcs_installations.route ()
        --> with_tenant Sgs_service_orchestration_ep_vcs_installation_list.run );
      ( `POST,
        Sgs_api_tenants.Provision_gitlab_installation.route ()
        /* Body.decode ~json:Sgs_api_tenants.Provision_gitlab_installation.Request_body.of_yojson ()
        --> with_tenant Sgs_service_orchestration_ep_gitlab_provision.run );
      ( `PUT,
        Sgs_api_tenants.Rotate_gitlab_installation.route ()
        /* Body.decode ~json:Sgs_api_tenants.Rotate_gitlab_installation.Request_body.of_yojson ()
        --> with_tenant Sgs_service_orchestration_ep_gitlab_rotate.run );
      ( `POST,
        Sgs_api_tenants.Uninstall_gitlab_installation.route ()
        --> with_tenant Sgs_service_orchestration_ep_gitlab_installation_state.uninstall );
      ( `POST,
        Sgs_api_tenants.Restore_gitlab_installation.route ()
        --> with_tenant Sgs_service_orchestration_ep_gitlab_installation_state.restore );
      ( `PUT,
        Sgs_api_tenants.Link_vcs_installation.route ()
        --> with_tenant Sgs_service_orchestration_ep_vcs_installation_put.run );
      (* GitHub identity claim (#1795): start the handshake, take GitHub's answer,
         list what was proven, spend the proof. The callback is not tenant-scoped
         because GitHub redirects to a fixed URL; the tenant rides in the signed
         state. *)
      ( `GET,
        Sgs_api_tenants.Start_github_claim.route ()
        --> with_tenant Sgs_service_orchestration_ep_github_claim_start.run );
      ( `GET,
        Sgs_api_vcs_installations.Github_claim_callback.route ()
        --> Sgs_service_orchestration_ep_github_claim_callback.run config storage );
      ( `GET,
        Sgs_api_tenants.List_claimable_github_installations.route ()
        --> with_tenant Sgs_service_orchestration_ep_github_claimable_list.run );
      ( `POST,
        Sgs_api_tenants.Claim_github_installation.route ()
        /* Body.decode ~json:Sgs_api_components_github_claim_request.of_yojson ()
        --> with_tenant Sgs_service_orchestration_ep_github_claim.run );
      ( `DELETE,
        Sgs_api_tenants.Unlink_vcs_installation.route ()
        --> with_tenant Sgs_service_orchestration_ep_vcs_installation_delete.run );
      (* GitHub App creation: the manifest form, and GitHub's return with the code
         of the created App. Both optional on the callback, so a mangled return is
         redirected rather than answered with a 404. *)
      ( `POST,
        Sgs_api_setup.Github_app_manifest.route ()
        /* Body.decode ~json:Sgs_api_components_github_app_manifest_request.of_yojson ()
        --> Sgs_service_orchestration_ep_github_app_manifest.run config storage );
      ( `GET,
        Sgs_api_setup.Github_app_callback.route ()
        --> Sgs_service_orchestration_ep_github_app_callback.run config storage );
      ( `GET,
        Sgs_api_setup.Github_app_get.route ()
        --> Sgs_service_orchestration_ep_github_app_get.run config storage );
      ( `DELETE,
        Sgs_api_setup.Github_app_delete.route ()
        /* Body.decode ~json:Sgs_api_components_github_app_delete_request.of_yojson ()
        --> Sgs_service_orchestration_ep_github_app_delete.run config storage );
      ( `PUT,
        Sgs_api_setup.Github_app_set_credentials.route ()
        /* Body.decode ~json:Sgs_api_components_github_app_credentials_request.of_yojson ()
        --> Sgs_service_orchestration_ep_github_app_credentials_put.run config storage );
    ]

let wrap _ = CCFun.id
let stop _ = Abb.Future.return ()
