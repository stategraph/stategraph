let src = Logs.Src.create "ep_invitation_reissue"

module Logs = (val Logs.src_log src : Logs.LOG)
module Common = Sgs_service_tenants_invitation_common
module Members = Sgs_service_tenants_members_common
module Invitation = Sgs_service_tenants_invitation

module Make (Cloud : Sgs_cloud.S) = struct
  module Sender = Common.Make_sender (Cloud)

  (* The reissue proper: rotate the invitation under a fresh token, then best-effort deliver the new link. *)
  let run' config storage tenant user ~authorize_role ~admin_denial ctx id =
    let open Abb.Future.Infix_monad in
    Pgsql_pool.with_conn storage ~f:(fun db ->
        Pgsql_io.tx db ~f:(fun () ->
            let open Abbs_fc.Infix_result_monad in
            Sgs_tenant.enforce_user user tenant db
            >>= fun () ->
            (* Re-minting an [Admin] invitation hands its bearer token to the caller, so it confers the
             grant just as creating one does and answers to the same rule.  The role is only known
             once the row is read, so the check rides into [rotate] rather than sitting in [~caps]. *)
            Invitation.rotate
              ~ttl_hours:(Sgs_config.invitation_ttl_hours config)
              ~authorize_role
              ~id
              ~tenant_id:(Sgs_tenant.id tenant)
              db))
    >>= function
    | Ok rotated -> (
        let {
          Invitation.rotated_token;
          rotated_created_at;
          rotated_expires_at;
          rotated_email;
          rotated_role;
          rotated_tenant_name;
        } =
          rotated
        in
        let accept_url =
          Common.accept_url ~console_base:(Sgs_config.ui_base config) ~token:rotated_token
        in
        Logs.info (fun m ->
            m
              "%s : INVITATION_REISSUED : invitation=%a by=%a"
              (Brtl_ctx.token ctx)
              Uuidm.pp
              id
              Uuidm.pp
              (Sgs_user.id user));
        (* Best-effort delivery, deliberately NOT wrapped in a transaction: [deliver] makes an external
         control-plane send and then a single [record_send] write.  One bookkeeping statement needs no
         atomicity, and a transaction would stay open across the network send.  A failure here is
         tolerated -- the rotated invitation is already committed and its link is in the response. *)
        Pgsql_pool.with_conn storage ~f:(fun db ->
            Sender.deliver
              ~config
              ~request_token:(Brtl_ctx.token ctx)
              ~inviter:user
              ~invitation_id:id
              ~email:rotated_email
              ~tenant_name:rotated_tenant_name
              ~accept_url
              ~expires_at:rotated_expires_at
              db)
        >>= function
        | Ok delivery ->
            let body =
              Yojson.Safe.to_string
              @@ Sgs_api_components_invitation_create_response.to_yojson
                   {
                     Sgs_api_components_invitation_create_response.invitation =
                       {
                         Sgs_api_components_tenant_invitation.id = Uuidm.to_string id;
                         email = rotated_email;
                         role = Common.api_role rotated_role;
                         status = `Pending;
                         created_at = rotated_created_at;
                         expires_at = rotated_expires_at;
                         delivered = Common.Delivery.delivered delivery;
                         send_count = 1;
                         invited_by_name = Sgs_user.name user;
                       };
                     invite_url = accept_url;
                     delivery = Common.Delivery.to_api delivery;
                   }
            in
            Abb.Future.return (Common.respond_json ~status:`OK body ctx)
        | Error (#Pgsql_pool.err as err) ->
            Logs.err (fun m ->
                m "%s : DB_POOL_ERROR : %a" (Brtl_ctx.token ctx) Pgsql_pool.pp_err err);
            Abb.Future.return (Sgs_eplib.respond_internal_error ctx)
        | Error (#Pgsql_io.err as err) ->
            (* Recording the send attempt failed.  The invitation itself is committed, so this is a
             bookkeeping fault -- the link in the response is live regardless. *)
            Logs.err (fun m -> m "%s : DB_ERROR : %a" (Brtl_ctx.token ctx) Pgsql_io.pp_err err);
            Abb.Future.return (Sgs_eplib.respond_internal_error ctx))
    | Error `Not_authorized ->
        Abb.Future.return
          (Brtl_ctx.set_response
             (Brtl_rspnc.create
                ~status:`Forbidden
                (Sgs_user_session.Caps.denied_body (CCOption.get_or ~default:[] admin_denial)))
             ctx)
    | Error `Not_found -> Abb.Future.return (Common.respond_act_err ctx `Not_found)
    | Error `Not_pending -> Abb.Future.return (Common.respond_act_err ctx `Not_pending)
    | Error `Cooldown -> Abb.Future.return (Common.respond_act_err ctx `Cooldown)
    | Error `Send_limit -> Abb.Future.return (Common.respond_act_err ctx `Send_limit)
    | Error (#Sgs_eplib.tenant_access_err as err) ->
        Abb.Future.return (Sgs_eplib.respond_tenant_access_err ctx err)

  let run config storage tenant id_str =
    Sgs_user_session.with_session
      ~caps:(Sgs_user_session.Caps.manages_tenant_members (Uuidm.to_string (Sgs_tenant.id tenant)))
      ~f:(fun session ->
        let user = Sgs_user_session.Session.user session in
        (* Whether this caller may confer admin does not depend on which invitation is being reissued,
         so it is settled once, here; only the role it applies to comes from the row.  Keeping the
         reasons is what lets the refusal be the same body {!Sgs_user_session.with_session} produces --
         which is exactly what {!Sgs_user_session.Caps.denied_body} is exposed for. *)
        let admin_denial =
          match
            Members.grant_to_caps tenant `Admin (Sgs_user_session.Session.capabilities session) user
          with
          | Sgs_user_session.Caps.Allowed -> None
          | Sgs_user_session.Caps.Denied reasons -> Some reasons
        in
        let authorize_role = function
          | Invitation.Role.Member -> true
          | Invitation.Role.Admin -> CCOption.is_none admin_denial
        in
        Brtl_ep.run_json ~f:(fun ctx ->
            match Uuidm.of_string id_str with
            | None ->
                Abb.Future.return
                  (Sgs_eplib.respond_error
                     ~status:`Bad_request
                     ~id:"INVALID_REQUEST"
                     ~data:"id is not a uuid"
                     ctx)
            | Some id -> run' config storage tenant user ~authorize_role ~admin_denial ctx id))
end
