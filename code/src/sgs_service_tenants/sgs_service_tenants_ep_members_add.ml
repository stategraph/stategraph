let src = Logs.Src.create "ep_members_add"

module Logs = (val Logs.src_log src : Logs.LOG)
module Common = Sgs_service_tenants_members_common
module Fc = Abbs_fc

(* Add an existing user to the tenant as a plain member. Unlike an invitation (which is for someone
   with no account yet), this is the direct verb the Members table needs: it grants no capability,
   only the [tenant_users] row, so the member starts with no tenant-scoped rights. Idempotent, so a
   double-add is not an error. *)
let run' storage tenant user target_id =
  let open Fc.Infix_result_monad in
  Pgsql_pool.with_conn storage ~f:(fun db ->
      Pgsql_io.tx db ~f:(fun () ->
          Sgs_tenant.enforce_user user tenant db
          >>= fun () ->
          (* The user must exist and be active before a membership row can reference it (there is a
             foreign key), and a missing user is a request error, not an internal one. *)
          Sgs_user.enrich (Sgs_user.make ~id:target_id ()) db
          >>= fun target ->
          (* Read before the write, in the same transaction, so the response can say whether the add
             did anything -- [add_user_idempotent] cannot report that on its own. Same shape as
             [Sgs_service_tenants_ep_invitation_accept.accept], which reports it as [already_member]. *)
          Sgs_tenant.find_member tenant target_id db
          >>= function
          | Some member -> Abbs_fc.return_ok (member, `Already_member)
          | None -> (
              Sgs_tenant.add_user_idempotent tenant target db
              >>= fun () ->
              Sgs_tenant.find_member tenant target_id db
              >>? function
              | Some member -> Ok (member, `Added)
              (* Not the caller's 404: [enrich] already established the user is active and
                 [add_user_idempotent] just succeeded, both in this transaction, so no membership row
                 here is a broken invariant rather than a bad request. *)
              | None -> Error (`Member_missing_after_add_err target_id))))

let run _config storage tenant body =
  let { Sgs_api_components_tenant_member_add_request.user_id } = body in
  Sgs_user_session.with_user
    ~caps:(Sgs_user_session.Caps.manages_tenant_members (Uuidm.to_string (Sgs_tenant.id tenant)))
    ~f:(fun user ->
      Brtl_ep.run_json ~f:(fun ctx ->
          let open Abb.Future.Infix_monad in
          match Uuidm.of_string user_id with
          | None -> Abb.Future.return (Common.respond_invalid_user_id ctx)
          | Some target_id -> (
              run' storage tenant user target_id
              >>= function
              | Ok (member, outcome) ->
                  Logs.info (fun m ->
                      m
                        "%s : TENANT_MEMBER_ADDED : tenant=%a user=%a by=%a created=%b"
                        (Brtl_ctx.token ctx)
                        Uuidm.pp
                        (Sgs_tenant.id tenant)
                        Uuidm.pp
                        target_id
                        Uuidm.pp
                        (Sgs_user.id user)
                        (match outcome with
                        | `Added -> true
                        | `Already_member -> false));
                  (* 201 only when this call created the membership; a repeat add is a 200, so the UI
                     can tell "added them" from "they were already here". *)
                  let status =
                    match outcome with
                    | `Added -> `Created
                    | `Already_member -> `OK
                  in
                  Abb.Future.return (Common.respond_member ~status ctx member)
              | Error (`User_not_found_err target) ->
                  Logs.warn (fun m ->
                      m
                        "%s : TENANT_MEMBER_ADD_NO_USER : user=%a"
                        (Brtl_ctx.token ctx)
                        Uuidm.pp
                        target);
                  Abb.Future.return (Common.respond_error ctx `User_not_found)
              | Error (`Member_missing_after_add_err target) ->
                  Logs.err (fun m ->
                      m
                        "%s : TENANT_MEMBER_ADD_NO_ROW : tenant=%a user=%a"
                        (Brtl_ctx.token ctx)
                        Uuidm.pp
                        (Sgs_tenant.id tenant)
                        Uuidm.pp
                        target);
                  Abb.Future.return (Sgs_eplib.respond_internal_error ctx)
              | Error (#Sgs_eplib.tenant_access_err as err) ->
                  Abb.Future.return (Sgs_eplib.respond_tenant_access_err ctx err))))

module Tests = struct
  type run_prime_err =
    [ Pgsql_io.err
    | Pgsql_pool.err
    | Sgs_tenant.enforce_user_err
    | `Member_missing_after_add_err of Uuidm.t
    | `User_not_found_err of Uuidm.t
    ]

  let run' = run'
end
