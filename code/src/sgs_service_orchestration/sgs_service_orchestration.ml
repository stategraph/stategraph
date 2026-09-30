module Rt = struct
  let api_v1 () = Brtl_rtng.Route.(rel / "api" / "v1")

  let tenant () =
    Brtl_rtng.Route.(
      api_v1 ()
      / "tenants"
      /% Path.ud CCFun.(Uuidm.of_string %> CCOption.map (fun id -> Sgs_tenant.make ~id ())))

  let tenant_vcs_installations () = Brtl_rtng.Route.(tenant () / "vcs-installations")

  let tenant_gitlab_provision () =
    Brtl_rtng.Route.(
      tenant ()
      / "vcs-installations"
      / "gitlab"
      /* Body.decode ~json:Sgs_api_tenants.Provision_gitlab_installation.Request_body.of_yojson ())

  let tenant_gitlab_rotate () =
    Brtl_rtng.Route.(
      tenant ()
      / "vcs-installations"
      / "gitlab"
      /% Path.int
      /* Body.decode ~json:Sgs_api_tenants.Rotate_gitlab_installation.Request_body.of_yojson ())

  let vcs_installations_github_unclaimed () =
    Brtl_rtng.Route.(
      api_v1 ()
      / "vcs-installations"
      / "github"
      / "unclaimed"
      /? Query.(option (string "cursor"))
      /? Query.(option_default 100 (int "limit")))

  (* GitHub identity claim (#1795): start the handshake, take GitHub's answer,
     list what was proven, spend the proof. The callback is not tenant-scoped
     because GitHub redirects to a fixed URL; the tenant rides in the signed
     state. *)
  let tenant_github_claim_start () =
    Brtl_rtng.Route.(
      tenant () / "vcs-installations" / "github" / "claim" / "start" /? Query.(option (string "rd")))

  (* Both optional: GitHub also lands the user here after an app installation,
     with installation_id and setup_action but no state to complete. Requiring
     them would answer that navigation with a 404. *)
  let vcs_installations_github_claim_callback () =
    Brtl_rtng.Route.(
      api_v1 ()
      / "vcs-installations"
      / "github"
      / "claim"
      / "callback"
      /? Query.(option (string "code"))
      /? Query.(option (string "state")))

  let tenant_github_claimable () =
    Brtl_rtng.Route.(tenant () / "vcs-installations" / "github" / "claimable")

  let tenant_github_claim () =
    Brtl_rtng.Route.(
      tenant ()
      / "vcs-installations"
      / "github"
      / "claim"
      /* Body.decode ~json:Sgs_api_components_github_claim_request.of_yojson ())

  let tenant_vcs_installation () =
    Brtl_rtng.Route.(tenant () / "vcs-installations" /% Path.string /% Path.uuid)

  (* GitHub App creation: the manifest form, and GitHub's return with the code
     of the created App. Both optional on the callback, so a mangled return is
     redirected rather than answered with a 404. *)
  let setup_github_app_manifest () =
    Brtl_rtng.Route.(
      api_v1 ()
      / "setup"
      / "github-app"
      / "manifest"
      /* Body.decode ~json:Sgs_api_components_github_app_manifest_request.of_yojson ())

  let setup_github_app () = Brtl_rtng.Route.(api_v1 () / "setup" / "github-app")

  let setup_github_app_delete () =
    Brtl_rtng.Route.(
      setup_github_app ()
      /* Body.decode ~json:Sgs_api_components_github_app_delete_request.of_yojson ())

  let setup_github_app_credentials () =
    Brtl_rtng.Route.(
      setup_github_app ()
      / "credentials"
      /* Body.decode ~json:Sgs_api_components_github_app_credentials_request.of_yojson ())

  let setup_github_app_callback () =
    Brtl_rtng.Route.(
      api_v1 ()
      / "setup"
      / "github-app"
      / "callback"
      /? Query.(option (string "code"))
      /? Query.(option (string "state")))
end

type t = unit

let name = "orchestration"
let start _ _ = Abbs_fc.return_ok ()

let routes () config storage =
  Brtl_rtng.Route.
    [
      ( `GET,
        Rt.vcs_installations_github_unclaimed ()
        --> fun cursor limit ->
        Sgs_service_orchestration_ep_vcs_installation_unclaimed_github.run
          ~cursor
          ~limit
          config
          storage );
      ( `GET,
        Rt.tenant_vcs_installations ()
        --> Sgs_service_orchestration_ep_vcs_installation_list.run config storage );
      ( `POST,
        Rt.tenant_gitlab_provision ()
        --> Sgs_service_orchestration_ep_gitlab_provision.run config storage );
      ( `PUT,
        Rt.tenant_gitlab_rotate () --> Sgs_service_orchestration_ep_gitlab_rotate.run config storage
      );
      ( `PUT,
        Rt.tenant_vcs_installation ()
        --> Sgs_service_orchestration_ep_vcs_installation_put.run config storage );
      ( `GET,
        Rt.tenant_github_claim_start ()
        --> Sgs_service_orchestration_ep_github_claim_start.run config storage );
      ( `GET,
        Rt.vcs_installations_github_claim_callback ()
        --> Sgs_service_orchestration_ep_github_claim_callback.run config storage );
      ( `GET,
        Rt.tenant_github_claimable ()
        --> Sgs_service_orchestration_ep_github_claimable_list.run config storage );
      ( `POST,
        Rt.tenant_github_claim () --> Sgs_service_orchestration_ep_github_claim.run config storage
      );
      ( `DELETE,
        Rt.tenant_vcs_installation ()
        --> Sgs_service_orchestration_ep_vcs_installation_delete.run config storage );
      ( `POST,
        Rt.setup_github_app_manifest ()
        --> Sgs_service_orchestration_ep_github_app_manifest.run config storage );
      ( `GET,
        Rt.setup_github_app_callback ()
        --> Sgs_service_orchestration_ep_github_app_callback.run config storage );
      ( `GET,
        Rt.setup_github_app () --> Sgs_service_orchestration_ep_github_app_get.run config storage );
      ( `DELETE,
        Rt.setup_github_app_delete ()
        --> Sgs_service_orchestration_ep_github_app_delete.run config storage );
      ( `PUT,
        Rt.setup_github_app_credentials ()
        --> Sgs_service_orchestration_ep_github_app_credentials_put.run config storage );
    ]

let stop () = Abb.Future.return ()
