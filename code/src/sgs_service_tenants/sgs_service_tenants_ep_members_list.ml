module Common = Sgs_service_tenants_members_common

(* Bounded so a caller cannot ask for the whole table in one page. *)
let max_page_size = 100

(* The pair select_tenant_users.sql orders and pages by: the membership's join time and the member's
   id.  See {!Sgs_eplib.Cursor}. *)
let encode_cursor tenant_member =
  Sgs_eplib.Cursor.encode
    ~timestamp:tenant_member.Sgs_tenant.Member.joined_at
    ~id:tenant_member.Sgs_tenant.Member.id

let run _config storage tenant cursor limit =
  Sgs_user_session.with_user
    ~caps:(Sgs_user_session.Caps.manages_tenant_members (Uuidm.to_string (Sgs_tenant.id tenant)))
    ~f:(fun user ->
      Brtl_ep.run_json ~f:(fun ctx ->
          let open Abb.Future.Infix_monad in
          let limit = CCInt.max 1 (CCInt.min max_page_size limit) in
          let cursor = CCOption.flat_map Sgs_eplib.Cursor.decode cursor in
          Pgsql_pool.with_conn storage ~f:(fun db ->
              let open Abbs_fc.Infix_result_monad in
              Sgs_tenant.enforce_user user tenant db
              >>= fun () -> Sgs_tenant.list_users ?cursor ~limit tenant db)
          >>= function
          | Ok (members, total_count) ->
              (* A full page means there may be more; the next cursor is the last row's (join time,
                 id), the key select_tenant_users.sql orders and pages by. *)
              let has_more = CCList.length members = limit in
              let next_cursor =
                if has_more then CCOption.map encode_cursor (CCList.last_opt members) else None
              in
              let body =
                Yojson.Safe.to_string
                @@ Sgs_api_components_tenant_members_response.to_yojson
                     {
                       Sgs_api_components_tenant_members_response.members =
                         CCList.map Common.member_to_api members;
                       total_count;
                       limit;
                       has_more;
                       next_cursor;
                     }
              in
              Abb.Future.return (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`OK body) ctx)
          | Error (#Sgs_eplib.tenant_access_err as err) ->
              Abb.Future.return (Sgs_eplib.respond_tenant_access_err ctx err)))
