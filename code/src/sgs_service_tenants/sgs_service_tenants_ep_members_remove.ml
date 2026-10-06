let src = Logs.Src.create "ep_members_remove"

module Logs = (val Logs.src_log src : Logs.LOG)
module Common = Sgs_service_tenants_members_common

let run' storage tenant user target_id =
  let open Abbs_fc.Infix_result_monad in
  Pgsql_pool.with_conn storage ~f:(fun db ->
      (* One transaction around the membership read, the capability write and the row delete.  A
         partial application is the one dangerous outcome: the membership row gone while the
         capability still names the tenant leaves the user able to mint an access token for it, and
         still reporting as its admin. *)
      Pgsql_io.tx db ~f:(fun () ->
          Sgs_tenant.enforce_user user tenant db
          >>= fun () ->
          Sgs_tenant.find_member tenant target_id db
          >>= function
          | None -> Abbs_fc.return_err `Member_not_found
          | Some member -> (
              let is_admin =
                Sg_caps_ops.Tenant_scope.(
                  match member.Sgs_tenant.Member.admin with
                  | Not_covered -> false
                  | Exact | Wider -> true)
              in
              (* Removing the only administrator would leave the tenant with nobody able to invite a
                 replacement, so it is refused even for a caller who holds installation-wide admin --
                 they can promote someone first. *)
              (if is_admin then Sgs_tenant.count_admins tenant db else Abbs_fc.return_ok 2)
              >>= fun admin_count ->
              if is_admin && admin_count <= 1 then Abbs_fc.return_err `Last_tenant_admin
              else
                match Common.wider_grant member with
                (* A grant covering more than this tenant is not this endpoint's to narrow: taking
                   this tenant out of it would rewrite authority the caller does not own, and would
                   demote an installation administrator without the guard that keeps the last one. *)
                | Some grant -> Abbs_fc.return_err (`Wider_grant grant)
                | None ->
                    let target = Sgs_user.make ~id:target_id () in
                    (* Capability first, then the row.  Order is presentational (we're within a transaction),
                       but it puts the refusable step first, so the common failure aborts before anything is written. *)
                    Sgs_user.revoke_tenant
                      ~grants:[ `Admin; `Users_manage ]
                      ~tenant_id:(Sgs_tenant.id tenant)
                      target
                      db
                    >>= fun _ -> Sgs_tenant.remove_user tenant target db >>| fun () -> ())))

let run _config storage tenant user_id =
  Sgs_user_session.with_user
    ~caps:(Sgs_user_session.Caps.manages_tenant_members (Uuidm.to_string (Sgs_tenant.id tenant)))
    ~f:(fun user ->
      Brtl_ep.run_json ~f:(fun ctx ->
          let open Abb.Future.Infix_monad in
          match Uuidm.of_string user_id with
          | None -> Abb.Future.return (Common.respond_invalid_user_id ctx)
          (* Refused outright rather than allowed-when-others-remain: leaving your own tenant is a
             different intent from administering its membership, and conflating them makes
             "accidentally removed myself" reachable from a members table. *)
          | Some target_id when Uuidm.equal target_id (Sgs_user.id user) ->
              Abb.Future.return
                (Common.respond_error
                   ctx
                   (`Cannot_act_on_self "You cannot remove yourself from a tenant"))
          | Some target_id -> (
              run' storage tenant user target_id
              >>= function
              | Ok () ->
                  Logs.info (fun m ->
                      m
                        "%s : TENANT_MEMBER_REMOVED : tenant=%a user=%a by=%a"
                        (Brtl_ctx.token ctx)
                        Uuidm.pp
                        (Sgs_tenant.id tenant)
                        Uuidm.pp
                        target_id
                        Uuidm.pp
                        (Sgs_user.id user));
                  let body =
                    Yojson.Safe.to_string
                    @@ Sgs_api_components_tenant_member_remove_response.to_yojson
                         {
                           Sgs_api_components_tenant_member_remove_response.user_id =
                             Uuidm.to_string target_id;
                           removed = true;
                         }
                  in
                  Abb.Future.return (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`OK body) ctx)
              | Error (#Common.err as err) -> Abb.Future.return (Common.respond_error ctx err)
              | Error (`User_not_found_err user_id) ->
                  Common.log_tenant_grant_err ctx (`User_not_found_err user_id);
                  Abb.Future.return (Sgs_eplib.respond_internal_error ctx)
              | Error (#Sgs_eplib.tenant_access_err as err) ->
                  Abb.Future.return (Sgs_eplib.respond_tenant_access_err ctx err))))
