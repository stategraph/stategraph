let src = Logs.Src.create "ep_list"

module Logs = (val Logs.src_log src : Logs.LOG)
module Fc = Abbs_fc
module Common = Sgs_service_users_common
module L = Sgs_api_components_users_list_response
module Scope = Sg_caps_trie_scope

(* Bounded so a caller cannot ask for the whole table in one page. *)
let max_page_size = 100

module Sql = struct
  let select_users_list_sql = Mql_sql.read [%blob "./sql/select_users_list.sql"]

  let select_users_list () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* id *)
      Ret.uuid
      //
      (* name *)
      Ret.text
      //
      (* email *)
      Ret.(option text)
      //
      (* type *)
      Ret.(u text Sgs_user.Type_.of_string)
      //
      (* avatar_url *)
      Ret.(option text)
      //
      (* auth_origin *)
      Ret.(option text)
      //
      (* capability_trie *)
      Sgs_user.caps_ret
      //
      (* created_at *)
      Ret.text
      //
      (* total_count *)
      Ret.bigint
      /^ select_users_list_sql
      /% Var.boolean "whole_installation"
      /% Var.(array (boolean "rule_neg"))
      /% Var.(array (boolean "rule_prefix"))
      /% Var.(str_array (text "rule_pat"))
      /% Var.(option (ud (text "type") Sgs_user.Type_.to_string))
      /% Var.(option (text "search"))
      /% Var.(option (timestamptz "cursor"))
      /% Var.(option (uuid "cursor_id"))
      /% Var.smallint "limit")
end

(* The users a caller may list are those of the tenants its grant reaches. The query decides that
   reach, over every open tenant, from the rules of [Sg_caps_ops.Db_checks.scope_rules], so this
   list is not served through [Sgs_mql_paged], whose catalog scopes every table by the caller's
   memberships. *)
let reach caps =
  let users_reach = Sg_caps_ops.users_reach caps in
  match Scope.is_full users_reach with
  | true -> `Whole_installation
  | false -> `Tenants (Sg_caps_ops.Db_checks.scope_rules users_reach)

(* One row more than [limit] is fetched: when it comes back, another page follows. *)
let run' ~caps ~type_ ~search ~cursor ~limit db =
  let open Fc.Infix_result_monad in
  let module R = Sg_caps_ops.Db_checks in
  let whole_installation, rules =
    match reach caps with
    | `Whole_installation -> (true, [])
    | `Tenants rules -> (false, rules)
  in
  let cursor_created_at, cursor_id =
    match cursor with
    | Some (created_at, id) -> (Some created_at, Some id)
    | None -> (None, None)
  in
  Pgsql_io.Prepared_stmt.fetch
    db
    (Sql.select_users_list ())
    ~f:(fun id name email type_ avatar_url auth_origin capabilities created_at total_count ->
      (id, name, email, type_, avatar_url, auth_origin, capabilities, created_at, total_count))
    whole_installation
    (CCList.map (fun rule -> rule.R.Scope_rule.neg) rules)
    (CCList.map (fun rule -> rule.R.Scope_rule.prefix) rules)
    (CCList.map (fun rule -> rule.R.Scope_rule.pat) rules)
    type_
    search
    cursor_created_at
    cursor_id
    (limit + 1)
  >>| fun rows ->
  let page = CCList.take limit rows in
  let total_count =
    match rows with
    | [] -> 0
    | (_, _, _, _, _, _, _, _, count) :: _ -> Int64.to_int count
  in
  let users =
    CCList.map
      (fun (id, name, email, type_, avatar_url, auth_origin, capabilities, created_at, _) ->
        {
          L.Users.Items.id = Uuidm.to_string id;
          name;
          email;
          type_ = Sgs_user.Type_.to_api type_;
          avatar_url;
          auth_origin;
          admin_rights = Common.admin_rights capabilities;
          created_at;
        })
      page
  in
  let next_cursor =
    match (CCList.drop limit rows, CCList.last_opt page) with
    | _ :: _, Some (id, _, _, _, _, _, _, created_at, _) ->
        Some (Sgs_eplib.Cursor.encode ~timestamp:created_at ~id)
    | [], _ | _ :: _, None -> None
  in
  { L.users; total_count; limit; has_more = CCOption.is_some next_cursor; next_cursor }

let run _config storage type_ search cursor limit =
  let type_ = CCOption.map Sgs_user.Type_.of_api type_ in
  Sgs_user_session.with_session ~caps:Sgs_user_session.Caps.users_manage_some ~f:(fun session ->
      let caps = Sgs_user_session.Session.capabilities session in
      Brtl_ep.run_json ~f:(fun ctx ->
          let open Abb.Future.Infix_monad in
          let limit = CCInt.max 1 (CCInt.min max_page_size limit) in
          let cursor = CCOption.flat_map Sgs_eplib.Cursor.decode cursor in
          Pgsql_pool.with_conn storage ~f:(run' ~caps ~type_ ~search ~cursor ~limit)
          >>= function
          | Ok response ->
              Logs.info (fun m ->
                  m
                    "%s : USERS_LISTED : Listed %d users"
                    (Brtl_ctx.token ctx)
                    (CCList.length response.L.users));
              let headers =
                CCOption.map
                  (fun cursor ->
                    Sgs_eplib.pagination_links ~param:"cursor" ~next:(Some cursor) ~prev:None ctx)
                  response.L.next_cursor
              in
              let body = Yojson.Safe.to_string (L.to_yojson response) in
              Abb.Future.return
                (Brtl_ctx.set_response (Brtl_rspnc.create ?headers ~status:`OK body) ctx)
          | Error ((#Pgsql_pool.err | #Pgsql_io.err) as err) ->
              Abb.Future.return
                (Sgs_eplib.respond_db_err
                   ~src
                   ~body:
                     (Sgs_eplib.error_response_body
                        ~id:"INTERNAL_SERVER_ERROR"
                        ~data:"Failed to list users")
                   ctx
                   err)))

module Tests = struct
  let page = run'
end
