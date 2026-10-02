let src = Logs.Src.create "ep_group_rule_create"

module Logs = (val Logs.src_log src : Logs.LOG)
module Common = Sgs_caps_group_rule_common

module Sql = struct
  (* Of the given state ids, the ones this tenant owns -- one query for the whole grant.  An id the
     tenant does not own (another tenant's state, or a nonexistent one) simply does not come back,
     so the caller flags any input id missing from the result. *)
  let states_owned_by_tenant () =
    Pgsql_io.Typed_sql.(
      sql
      // Ret.uuid
      /^ [%blob "./sql/select_states_owned_by_tenant.sql"]
      /% Var.(str_array (uuid "state_ids"))
      /% Var.uuid "tenant_id")
end

(* Confirm every state a [commit]/[preview] grant names belongs to [tenant_id]. One query
   for the whole grant: fetch the subset the tenant owns, then flag every input id missing from it *)
let check_states ~tenant_id db state_ids =
  match Sln_list.String.uniq state_ids with
  | [] -> Abbs_fc.return_ok ()
  | ids -> (
      let open Abbs_fc.Infix_result_monad in
      (* An id that is not a uuid cannot be one of this tenant's states. *)
      let not_uuids = CCList.filter (fun s -> CCOption.is_none (Uuidm.of_string s)) ids in
      let uuids = CCList.filter_map Uuidm.of_string ids in
      Pgsql_io.Prepared_stmt.fetch db (Sql.states_owned_by_tenant ()) ~f:CCFun.id uuids tenant_id
      >>? fun owned ->
      let not_owned =
        CCList.filter (fun u -> not (Sln_list.Uuidm.mem u owned)) uuids
        |> CCList.map Uuidm.to_string
      in
      match not_uuids @ not_owned with
      | [] -> Ok ()
      | foreign -> Error (`Foreign_states foreign))

(* Verify the grant's states, then persist the rule and respond with its id. *)
let run'' ~tenant_id ~created_by ~description ~condition ~grant ~state_ids storage ctx =
  let open Abb.Future.Infix_monad in
  Pgsql_pool.with_conn storage ~f:(fun db ->
      let open Abbs_fc.Infix_result_monad in
      check_states ~tenant_id db state_ids
      >>= fun () -> Sgs_caps_rules.add ~tenant_id ~created_by ~description ~condition ~grant db)
  >>= function
  | Ok id ->
      Logs.info (fun m -> m "%s : GROUP_RULE_CREATED : %a" (Brtl_ctx.token ctx) Uuidm.pp id);
      let body =
        Yojson.Safe.to_string
        @@ Sgs_api_components_caps_group_rule_create_response.to_yojson
             { Sgs_api_components_caps_group_rule_create_response.id = Uuidm.to_string id }
      in
      Abb.Future.return (Common.respond_json ~status:`OK body ctx)
  | Error (`Foreign_states state_ids) ->
      let joined = CCString.concat ", " state_ids in
      Logs.warn (fun m -> m "%s : STATE_NOT_IN_TENANT : %s" (Brtl_ctx.token ctx) joined);
      Abb.Future.return
        (Common.unprocessable
           "GRANT_BEYOND_TENANT"
           (Printf.sprintf
              {|these states do not belong to this tenant, so a rule may not grant rights on them (a rule may only grant rights on this tenant's own states): %s|}
              joined)
           ctx)
  | Error ((#Pgsql_pool.err | #Pgsql_io.err) as err) ->
      Abb.Future.return (Sgs_eplib.respond_db_err ~src ctx err)

(* Validate the condition and the grant, confirm the grant is confined to this tenant, then persist
   it (via {!run''}).  A malformed condition or invalid grant is a 400 ([reject]); a well-formed
   grant that reaches beyond this tenant is a 422 (semantically invalid for the resource, not
   malformed). *)
let run' ~tenant_id ~created_by ~description ~condition ~grant ~reject storage ctx =
  match (Sgs_caps_rules.validate_cond condition, Sg_caps_json.of_wire grant) with
  | Error err, _ -> reject err
  | _, Error (#Sg_caps_json.read_err as err) -> reject (Sg_caps_json.read_err_to_string err)
  | Ok (), Ok grant -> (
      (* The grant must be confined to this tenant: a tenant admin cannot mint a rule that grants
         rights beyond it. *)
      match Sg_caps_ops.scoped_to_tenant ~tenant:(Uuidm.to_string tenant_id) grant with
      | Ok state_ids ->
          run'' ~tenant_id ~created_by ~description ~condition ~grant ~state_ids storage ctx
      | Error scope_err ->
          let msg = Sg_caps_ops.tenant_scope_err_to_string scope_err in
          Logs.warn (fun m -> m "%s : GRANT_BEYOND_TENANT : %s" (Brtl_ctx.token ctx) msg);
          Abb.Future.return (Common.unprocessable "GRANT_BEYOND_TENANT" msg ctx))

let run _config storage tenant =
  let tenant_id = Sgs_tenant.id tenant in
  Sgs_user_session.with_user ~caps:(Common.manage_caps tenant) ~f:(fun user ->
      Brtl_ep.run_json ~f:(fun ctx ->
          let created_by = Sgs_user.id user in
          let reject msg =
            Logs.warn (fun m -> m "%s : VALIDATION_FAILED %s" (Brtl_ctx.token ctx) msg);
            Abb.Future.return (Common.bad_request "INVALID_REQUEST_BODY" msg ctx)
          in
          match
            Sgs_api_components_caps_group_rule_create_request.of_yojson
              (Yojson.Safe.from_string (Brtl_ctx.body ctx))
          with
          | Error err -> Abb.Future.return (Common.bad_request "INVALID_REQUEST_BODY" err ctx)
          | Ok { Sgs_api_components_caps_group_rule_create_request.condition; description; grant }
            -> (
              match
                Sgs_caps_rules.cond_of_yojson
                  (Sgs_api_components_caps_group_rule_create_request.Condition.to_yojson condition)
              with
              | Error err -> reject err
              | Ok condition ->
                  run' ~tenant_id ~created_by ~description ~condition ~grant ~reject storage ctx)))
