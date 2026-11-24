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

let name = "caps"

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
        Sgs_api_caps.Get_default.route () --> Sgs_service_caps_ep_default_get.run config storage );
      ( `PUT,
        Sgs_api_caps.Set_default.route () --> Sgs_service_caps_ep_default_set.run config storage );
      ( `GET,
        Sgs_api_caps.List_group_rules.route ()
        --> with_tenant Sgs_service_caps_ep_group_rules_list.run );
      ( `POST,
        Sgs_api_caps.Create_group_rule.route ()
        --> with_tenant Sgs_service_caps_ep_group_rule_create.run );
      ( `GET,
        Sgs_api_caps.Get_group_rule.route () --> with_tenant Sgs_service_caps_ep_group_rule_get.run
      );
      ( `DELETE,
        Sgs_api_caps.Delete_group_rule.route ()
        --> with_tenant Sgs_service_caps_ep_group_rule_delete.run );
    ]

let wrap _ = CCFun.id
let stop _ = Abb.Future.return ()
