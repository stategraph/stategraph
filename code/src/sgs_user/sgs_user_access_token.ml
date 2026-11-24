type delete_err =
  [ `Access_token_not_found_err of Uuidm.t
  | Pgsql_io.err
  ]
[@@deriving show]

type list_err = Pgsql_io.err [@@deriving show]
type store_err = Pgsql_io.err [@@deriving show]

type query_err =
  [ `Expired_err of string
  | `Access_token_not_found_err of Uuidm.t
  | Pgsql_io.err
  ]
[@@deriving show]

type t = {
  capabilities : Sg_caps.t;
  expiration : string option;
  id : Uuidm.t;
  name : string;
  user_id : Uuidm.t;
}
[@@deriving show]

module Sql = struct
  let insert_access_token_sql = Mql_sql.read [%blob "./sql/insert_access_token.sql"]

  let insert_access_token () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* id *)
      Ret.uuid
      /^ insert_access_token_sql
      /% Var.json "capability_trie"
      /% Var.(option (timestamptz "expiration"))
      /% Var.text "kind"
      /% Var.text "name"
      /% Var.uuid "user_id")

  let delete_expired_login_sessions_sql =
    Mql_sql.read [%blob "./sql/delete_expired_login_sessions.sql"]

  let delete_expired_login_sessions () =
    Pgsql_io.Typed_sql.(sql // Ret.bigint /^ delete_expired_login_sessions_sql)

  let select_access_token_sql = Mql_sql.read [%blob "./sql/select_access_token.sql"]

  let select_access_token () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* expiration *)
      Ret.(option text)
      //
      (* name *)
      Ret.text
      //
      (* user_id *)
      Ret.uuid
      //
      (* expired *)
      Ret.boolean
      //
      (* capability_trie *)
      Sgs_user.caps_ret
      /^ select_access_token_sql
      /% Var.uuid "access_token_id")

  let select_access_tokens_by_user_sql =
    Mql_sql.read [%blob "./sql/select_access_tokens_by_user.sql"]

  let select_access_tokens_by_user () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* id *)
      Ret.uuid
      //
      (* name *)
      Ret.text
      //
      (* created_at *)
      Ret.text
      //
      (* expiration *)
      Ret.(option text)
      //
      (* owner_id *)
      Ret.uuid
      //
      (* owner_name *)
      Ret.text
      //
      (* owner_type *)
      Ret.(u text Sgs_user.Type_.of_string)
      /^ select_access_tokens_by_user_sql
      /% Var.uuid "user_id")

  let delete_access_token_sql = Mql_sql.read [%blob "./sql/delete_access_token.sql"]

  let delete_access_token () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* id *)
      Ret.uuid
      /^ delete_access_token_sql
      /% Var.uuid "token_id"
      /% Var.uuid "user_id")

  let select_access_tokens_all_sql = Mql_sql.read [%blob "./sql/select_access_tokens_all.sql"]

  let select_access_tokens_all () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* id *)
      Ret.uuid
      //
      (* name *)
      Ret.text
      //
      (* created_at *)
      Ret.text
      //
      (* expiration *)
      Ret.(option text)
      //
      (* owner_id *)
      Ret.uuid
      //
      (* owner_name *)
      Ret.text
      //
      (* owner_type *)
      Ret.(u text Sgs_user.Type_.of_string)
      /^ select_access_tokens_all_sql)

  let delete_access_token_admin_sql = Mql_sql.read [%blob "./sql/delete_access_token_admin.sql"]

  let delete_access_token_admin () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* id *)
      Ret.uuid
      /^ delete_access_token_admin_sql
      /% Var.uuid "token_id")
end

let id t = t.id
let user_id t = t.user_id
let expiration t = t.expiration
let capabilities t = t.capabilities

let kind_to_string = function
  | `Api -> "api"
  | `Login -> "login"

let store ?(kind = `Api) ?expiration ~name ~capabilities user db =
  let open Abb.Future.Infix_monad in
  Abb.Sys.time ()
  >>= fun now ->
  let expiration =
    CCOption.map
      (fun d ->
        ISO8601.Permissive.string_of_datetime (now +. (CCFloat.of_int @@ Duration.to_sec d)))
      expiration
  in
  let open Abbs_fc.Infix_result_monad in
  Pgsql_io.Prepared_stmt.fetch
    db
    (Sql.insert_access_token ())
    ~f:CCFun.id
    (Sg_caps_json.to_json capabilities)
    expiration
    (kind_to_string kind)
    name
    (Sgs_user.id user)
  >>= function
  | id :: _ -> Abbs_fc.return_ok { capabilities; expiration; id; name; user_id = Sgs_user.id user }
  | [] -> assert false

let query id db =
  let open Abbs_fc.Infix_result_monad in
  Pgsql_io.Prepared_stmt.fetch
    db
    (Sql.select_access_token ())
    ~f:(fun expiration name user_id expired capabilities ->
      (expiration, name, user_id, expired, capabilities))
    id
  >>= function
  | (None, _name, _user_id, true, _capabilities) :: _ -> assert false
  | (Some expiration, _name, _user_id, true, _capabilities) :: _ ->
      Abbs_fc.return_err (`Expired_err expiration)
  | (expiration, name, user_id, _, capabilities) :: _ ->
      Abbs_fc.return_ok { capabilities; expiration; id; name; user_id }
  | [] -> Abbs_fc.return_err (`Access_token_not_found_err id)

let list_by_user user db =
  Pgsql_io.Prepared_stmt.fetch
    db
    (Sql.select_access_tokens_by_user ())
    ~f:(fun id name created_at expiration owner_id owner_name owner_type ->
      {
        Sgs_api_components_access_token_summary.id = Uuidm.to_string id;
        name;
        created_at;
        expiration;
        owner_id = Uuidm.to_string owner_id;
        owner_name;
        owner_type = Sgs_user.Type_.to_api owner_type;
      })
    (Sgs_user.id user)

let delete ~token_id user db =
  let open Abbs_fc.Infix_result_monad in
  Pgsql_io.Prepared_stmt.fetch
    db
    (Sql.delete_access_token ())
    ~f:CCFun.id
    token_id
    (Sgs_user.id user)
  >>? function
  | _ :: _ -> Ok ()
  | [] -> Error (`Access_token_not_found_err token_id)

let list_all db =
  Pgsql_io.Prepared_stmt.fetch
    db
    (Sql.select_access_tokens_all ())
    ~f:(fun id name created_at expiration owner_id owner_name owner_type ->
      {
        Sgs_api_components_access_token_summary.id = Uuidm.to_string id;
        name;
        created_at;
        expiration;
        owner_id = Uuidm.to_string owner_id;
        owner_name;
        owner_type = Sgs_user.Type_.to_api owner_type;
      })

let delete_any ~token_id db =
  let open Abbs_fc.Infix_result_monad in
  Pgsql_io.Prepared_stmt.fetch db (Sql.delete_access_token_admin ()) ~f:CCFun.id token_id
  >>? function
  | _ :: _ -> Ok ()
  | [] -> Error (`Access_token_not_found_err token_id)

let gc_expired_login_sessions db =
  let open Abbs_fc.Infix_result_monad in
  Pgsql_io.Prepared_stmt.fetch db (Sql.delete_expired_login_sessions ()) ~f:Int64.to_int
  >>| fun count -> count |> CCList.head_opt |> CCOption.get_or ~default:0
