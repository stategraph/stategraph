let src = Logs.Src.create "ep_list"

module Fc = Abbs_fc
module Common = Sgs_service_users_common

(* Bounded so a caller cannot ask for the whole table in one page. *)
let max_page_size = 100

module Sql = struct
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
      Ret.text
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
      /^ [%blob "./sql/select_users_list.sql"]
      /% Var.(option (text "type"))
      /% Var.(option (text "search"))
      /% Var.(option (timestamptz "cursor"))
      /% Var.(option (uuid "cursor_id"))
      /% Var.smallint "limit")
end

let run _config storage type_ search cursor limit =
  Sgs_user_session.with_user ~caps:Sgs_user_session.Caps.users_manage_instance ~f:(fun _user ->
      Brtl_ep.run_json ~f:(fun ctx ->
          let open Abb.Future.Infix_monad in
          let limit = CCInt.max 1 (CCInt.min max_page_size limit) in
          let cursor_created_at, cursor_id =
            match CCOption.flat_map Sgs_eplib.Cursor.decode cursor with
            | Some (created_at, id) -> (Some created_at, Some id)
            | None -> (None, None)
          in
          Pgsql_pool.with_conn storage ~f:(fun db ->
              let open Fc.Infix_result_monad in
              Pgsql_io.Prepared_stmt.fetch
                db
                (Sql.select_users_list ())
                ~f:(fun
                    id
                    name
                    email
                    type_
                    avatar_url
                    auth_origin
                    capabilities
                    created_at
                    total_count
                  ->
                  ( id,
                    name,
                    email,
                    type_,
                    avatar_url,
                    auth_origin,
                    capabilities,
                    created_at,
                    total_count ))
                type_
                search
                cursor_created_at
                cursor_id
                limit
              >>| fun rows ->
              let total_count =
                match rows with
                | [] -> 0
                | (_, _, _, _, _, _, _, _, count) :: _ -> Int64.to_int count
              in
              let users =
                CCList.map
                  (fun (id, name, email, type_, avatar_url, auth_origin, capabilities, created_at, _)
                     ->
                    {
                      Sgs_api_components_users_list_response.Users.Items.id = Uuidm.to_string id;
                      name;
                      email;
                      type_;
                      avatar_url;
                      auth_origin;
                      admin_rights = Common.admin_rights capabilities;
                      created_at;
                    })
                  rows
              in
              let has_more = CCList.length rows = limit in
              let next_cursor =
                if has_more then
                  match CCList.last_opt rows with
                  | Some (id, _, _, _, _, _, _, created_at, _) ->
                      Some (Sgs_eplib.Cursor.encode ~timestamp:created_at ~id)
                  | None -> None
                else None
              in
              let response =
                {
                  Sgs_api_components_users_list_response.users;
                  total_count;
                  limit;
                  has_more;
                  next_cursor;
                }
              in
              let body =
                Yojson.Safe.to_string @@ Sgs_api_components_users_list_response.to_yojson response
              in
              body)
          >>= function
          | Ok body ->
              Abb.Future.return (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`OK body) ctx)
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
