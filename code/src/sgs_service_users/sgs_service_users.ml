module Rt = struct
  let api_v1 () = Brtl_rtng.Route.(rel / "api" / "v1")

  (* Users *)
  let user_access_tokens_create () =
    Brtl_rtng.Route.(
      api_v1 ()
      / "user"
      / "access-tokens"
      /* Body.decode ~json:Sgs_api_components_access_token_create_request.of_yojson ())

  let api_users_create () =
    Brtl_rtng.Route.(
      api_v1 ()
      / "api-users"
      /* Body.decode ~json:Sgs_api_components_api_user_create_request.of_yojson ())
end

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

let name = "users"

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
      ( `GET,
        Sgs_api_user.Access_tokens_list.route ()
        --> Sgs_service_users_ep_access_token_list.run config storage );
      ( `POST,
        Sgs_api_user.Access_tokens_revoke.route ()
        --> Sgs_service_users_ep_access_token_revoke.run config storage );
      ( `POST,
        Rt.user_access_tokens_create ()
        --> Sgs_service_users_ep_access_token_create.run config storage );
      (`POST, Rt.api_users_create () --> Sgs_service_users_ep_api_user_create.run config storage);
      (* User Management *)
      (`GET, Sgs_api_users.List.route () --> Sgs_service_users_ep_list.run config storage);
      (`GET, Sgs_api_users.Detail.route () --> Sgs_service_users_ep_detail.run config storage);
      (`POST, Sgs_api_users.Create.route () --> Sgs_service_users_ep_create.run config storage);
      (`PUT, Sgs_api_users.Update.route () --> Sgs_service_users_ep_update.run config storage);
      (`DELETE, Sgs_api_users.Delete.route () --> Sgs_service_users_ep_delete.run config storage);
      ( `POST,
        Sgs_api_users.Change_password.route ()
        --> Sgs_service_users_ep_change_password.run config storage );
      ( `POST,
        Sgs_api_users.Set_instance_admin.route ()
        --> Sgs_service_users_ep_set_instance_admin.run config storage );
    ]

let wrap _ = CCFun.id
let stop _ = Abb.Future.return ()
