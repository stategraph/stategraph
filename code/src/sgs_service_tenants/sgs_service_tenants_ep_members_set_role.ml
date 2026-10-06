let src = Logs.Src.create "ep_members_set_role"

module Logs = (val Logs.src_log src : Logs.LOG)
module Common = Sgs_service_tenants_members_common
module Scope = Sg_caps_ops.Tenant_scope
module Request = Sgs_api_components_tenant_member_set_role_request

(* The part of [body] corresponding to [tenant_grant]. The type annotation is intentional: better
   error message if we later add a new kind of grant. Leave it. The record is destructured rather
   than projected for the mirror-image reason: naming every field means adding one to the request
   breaks the build right here, in the function that has to decide which grant it maps to. *)
let want_of_grant (tenant_grant : Sg_caps_ops.tenant_grant) body =
  let grant_or_revoke_opt =
    let { Request.tenant_admin; can_manage_users } = body in
    match tenant_grant with
    | `Admin -> tenant_admin
    | `Users_manage -> can_manage_users
  in
  match grant_or_revoke_opt with
  | None -> `Noop
  | Some true -> `Grant
  | Some false -> `Revoke

(* Apply one requested grant change, or nothing when the field was omitted. [`Admin] and
   [`Users_manage] are independent: demoting someone from tenant admin does not strip a
   separately-granted right to manage members, and vice versa. *)
let apply_grant ?except_login_session ~body ~grant tenant target db =
  let open Abbs_fc.Infix_result_monad in
  let tenant_id = Sgs_tenant.id tenant in
  let grants = [ grant ] in
  match want_of_grant grant body with
  | `Noop -> Abbs_fc.return_ok ()
  | `Grant ->
      (* Widening, so the caller's own session may be kept: its snapshot is merely
         under-privileged until the next sign-in. *)
      Sgs_user.grant_tenant ?except_login_session ~grants ~tenant_id target db >>| fun _ -> ()
  | `Revoke ->
      (* Narrowing, so there is no exemption to offer: the caller's session dies with every other
         one and the revoked grant stops authorizing now. *)
      Sgs_user.revoke_tenant ~grants ~tenant_id target db >>| fun _ -> ()

(* [except_login_session] is the caller's own login session, and [run] passes it
   only when the caller is the target. *)
let run' ~except_login_session storage tenant user target_id body =
  let open Abbs_fc.Infix_result_monad in
  Pgsql_pool.with_conn storage ~f:(fun db ->
      Pgsql_io.tx db ~f:(fun () ->
          Sgs_tenant.enforce_user user tenant db
          >>= fun () ->
          Sgs_tenant.find_member tenant target_id db
          >>= function
          | None -> Abbs_fc.return_err `Member_not_found
          | Some member ->
              let is_admin =
                Scope.(
                  match member.Sgs_tenant.Member.admin with
                  | Not_covered -> false
                  | Exact -> true
                  | Wider -> true)
              in
              let demoting =
                if is_admin then
                  (* You're an admin, will this change demote you? *)
                  match want_of_grant `Admin body with
                  | `Noop | `Grant -> false
                  | `Revoke -> true
                else (* You're not an admin, you can't get demoted *) false
              in
              (* Both guards are kept even though self-demotion nearly implies the second: the caller
                 may hold only [users-manage] for this tenant and no admin grant at all, in which case
                 demoting the single administrator would strand the tenant. *)
              (if demoting then Sgs_tenant.count_admins tenant db else Abbs_fc.return_ok 2)
              >>= fun admin_count ->
              (* A grant this change would revoke, that covers more than this tenant: not this
                 endpoint's to narrow, for the same reason removing such a member is refused. *)
              let narrowing =
                CCList.find_opt
                  (fun grant ->
                    match want_of_grant grant body with
                    | `Revoke -> (
                        let coverage =
                          match grant with
                          | `Admin -> member.Sgs_tenant.Member.admin
                          | `Users_manage -> member.Sgs_tenant.Member.users_manage
                        in
                        match coverage with
                        | Scope.Wider -> true
                        | Scope.Exact | Scope.Not_covered -> false)
                    | `Noop | `Grant -> false)
                  [ `Admin; `Users_manage ]
              in
              if demoting && admin_count <= 1 then Abbs_fc.return_err `Last_tenant_admin
              else if CCOption.is_some narrowing then
                Abbs_fc.return_err
                  (`Wider_grant (CCOption.get_exn_or "checked just above" narrowing))
              else
                let target = Sgs_user.make ~id:target_id () in
                apply_grant ?except_login_session ~body ~grant:`Admin tenant target db
                >>= fun () ->
                apply_grant ?except_login_session ~body ~grant:`Users_manage tenant target db
                >>= fun () ->
                (* Re-read so the response reports the coverage actually stored, rather than what the
                   request asked for -- they differ for a member whose grant was already wider. *)
                Sgs_tenant.find_member tenant target_id db
                >>? fun member_opt -> CCOption.to_result `Member_not_found member_opt))

let run _config storage tenant user_id body =
  let admin_operation = want_of_grant `Admin body in
  (* Granting admin requires holding it; granting [users-manage] does not need singling out, because
     the gate below already demands that right (or admin, which subsumes it).
     Revoking is deliberately left on the base gate: taking
     a right away is a separate question from being able to confer it, and the last-administrator
     guard in [run'] is what protects the tenant there. *)
  let caps =
    match admin_operation with
    | `Grant -> Common.grant_to_caps tenant `Admin
    | `Noop | `Revoke ->
        Sgs_user_session.Caps.manages_tenant_members (Uuidm.to_string (Sgs_tenant.id tenant))
  in
  Sgs_user_session.with_session ~caps ~f:(fun session ->
      let user = Sgs_user_session.Session.user session in
      let is_self target_id = Uuidm.equal target_id (Sgs_user.id user) in
      (* The row id of the caller's own login session. A duration-bounded session has no row. *)
      let own_login_session =
        match Sgs_user_session.Session.expiration session with
        | Sgs_user_session.Session.Expiration.Access_token id -> Some id
        | Sgs_user_session.Session.Expiration.Duration _ -> None
      in
      Brtl_ep.run_json ~f:(fun ctx ->
          let open Abb.Future.Infix_monad in
          match (Uuidm.of_string user_id, admin_operation) with
          | None, _ -> Abb.Future.return (Common.respond_invalid_user_id ctx)
          (* Demoting yourself is refused rather than allowed-if-others-remain: it locks you out of
             the screen you would need to undo it. Stepping down is "leave tenant", a separate
             action with its own confirmation. *)
          | Some target_id, `Revoke when is_self target_id ->
              Abb.Future.return
                (Common.respond_error
                   ctx
                   (`Cannot_act_on_self "You cannot remove your own admin access to a tenant"))
          | Some target_id, (`Noop | `Grant | `Revoke) -> (
              (* Offered only for a self-directed change (mirrors Sgs_service_tenants_ep_invitation_accept): it is
                 the caller's own login row, so against any other target it could only ever match
                 nothing. *)
              let except_login_session = if is_self target_id then own_login_session else None in
              run' ~except_login_session storage tenant user target_id body
              >>= function
              | Ok member ->
                  Logs.info (fun m ->
                      m
                        "%s : TENANT_MEMBER_ROLE_CHANGED : tenant=%a user=%a admin=%s \
                         users_manage=%s by=%a"
                        (Brtl_ctx.token ctx)
                        Uuidm.pp
                        (Sgs_tenant.id tenant)
                        Uuidm.pp
                        target_id
                        (Scope.show_coverage member.Sgs_tenant.Member.admin)
                        (Scope.show_coverage member.Sgs_tenant.Member.users_manage)
                        Uuidm.pp
                        (Sgs_user.id user));
                  Abb.Future.return (Common.respond_member ~status:`OK ctx member)
              | Error (#Common.err as err) -> Abb.Future.return (Common.respond_error ctx err)
              | Error (`User_not_found_err user_id) ->
                  Common.log_tenant_grant_err ctx (`User_not_found_err user_id);
                  Abb.Future.return (Sgs_eplib.respond_internal_error ctx)
              | Error (#Sgs_eplib.tenant_access_err as err) ->
                  Abb.Future.return (Sgs_eplib.respond_tenant_access_err ctx err))))

module Tests = struct
  type run_prime_err =
    [ Pgsql_io.err
    | Pgsql_pool.err
    | Sgs_tenant.enforce_user_err
    | `Last_tenant_admin
    | `Member_not_found
    | `Wider_grant of Sg_caps_ops.tenant_grant
    | `User_not_found_err of Uuidm.t
    ]

  let run' = run'
end
