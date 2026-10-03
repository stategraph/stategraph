module Rt = struct
  let api_v1 () = Brtl_rtng.Route.(rel / "api" / "v1")
  let caps_default () = Brtl_rtng.Route.(api_v1 () / "caps" / "default")

  let tenant () =
    Brtl_rtng.Route.(
      api_v1 ()
      / "tenants"
      /% Path.ud CCFun.(Uuidm.of_string %> CCOption.map (fun id -> Sgs_tenant.make ~id ())))

  let tenant_caps_group_rules () = Brtl_rtng.Route.(tenant () / "caps" / "group-rules")
  let tenant_caps_group_rule () = Brtl_rtng.Route.(tenant () / "caps" / "group-rules" /% Path.uuid)
end

type t = unit

let name = "caps"
let start _ _ = Abbs_fc.return_ok ()

let routes () config storage =
  Brtl_rtng.Route.
    [
      (`GET, Rt.caps_default () --> Sgs_service_caps_ep_default_get.run config storage);
      (`PUT, Rt.caps_default () --> Sgs_service_caps_ep_default_set.run config storage);
      ( `GET,
        Rt.tenant_caps_group_rules () --> Sgs_service_caps_ep_group_rules_list.run config storage );
      ( `POST,
        Rt.tenant_caps_group_rules () --> Sgs_service_caps_ep_group_rule_create.run config storage
      );
      (`GET, Rt.tenant_caps_group_rule () --> Sgs_service_caps_ep_group_rule_get.run config storage);
      ( `DELETE,
        Rt.tenant_caps_group_rule () --> Sgs_service_caps_ep_group_rule_delete.run config storage );
    ]

let stop () = Abb.Future.return ()
