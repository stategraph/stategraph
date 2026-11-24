module Type_ = struct
  type t =
    | User
    | Api
    | System
  [@@deriving show]

  let to_string = function
    | User -> "user"
    | Api -> "api"
    | System -> "system"

  let of_string = function
    | "user" -> Some User
    | "api" -> Some Api
    | "system" -> Some System
    | _ -> None

  let to_api = function
    | User -> `User
    | Api -> `Api
    | System -> `System

  let of_api = function
    | `User -> User
    | `Api -> Api
    | `System -> System
end

type enrich_err =
  [ `User_not_found_err of Uuidm.t
  | Pgsql_io.err
  ]
[@@deriving show]

type store_err = Pgsql_io.err [@@deriving show]
type store_access_token_err = Pgsql_io.err [@@deriving show]
type minted = unit [@@deriving show]

type stored = {
  name : string;
  email : string option;
  type_ : Type_.t;
  avatar_url : string option;
  auth_origin : string option;
  capabilities : Sg_caps.t;
}
[@@deriving show]

type 'a t = {
  id : Uuidm.t;
  v : 'a;
}
[@@deriving show]

let caps_ret =
  Pgsql_io.Typed_sql.Ret.(
    u jsonb (fun json ->
        match Sg_caps_wire_capabilities.of_yojson json with
        | Error _ -> None
        | Ok wire -> CCResult.to_opt (Sg_caps_json.of_wire wire)))

module Sql = struct
  let insert_user_sql = Mql_sql.read [%blob "./sql/insert_user.sql"]

  let insert_user () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* id *)
      Ret.uuid
      /^ insert_user_sql
      /% Var.(option (text "email"))
      /% Var.(text "name")
      /% Var.(ud (text "type") Type_.to_string)
      /% Var.(option (text "password_hash"))
      /% Var.json "capability_trie")

  let select_default_user_caps_sql = Mql_sql.read [%blob "./sql/select_default_user_caps.sql"]

  let select_default_user_caps () =
    Pgsql_io.Typed_sql.(sql // Ret.jsonb /^ select_default_user_caps_sql)

  let upsert_default_user_caps_sql = Mql_sql.read [%blob "./sql/upsert_default_user_caps.sql"]

  let upsert_default_user_caps () =
    Pgsql_io.Typed_sql.(sql /^ upsert_default_user_caps_sql /% Var.json "value")

  let select_user_by_user_id_sql = Mql_sql.read [%blob "./sql/select_user_by_user_id.sql"]

  let select_user_by_user_id () =
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
      Ret.(u text Type_.of_string)
      //
      (* avatar_url *)
      Ret.(option text)
      //
      (* auth_origin *)
      Ret.(option text)
      //
      (* capability_trie *)
      caps_ret
      /^ select_user_by_user_id_sql
      /% Var.uuid "user_id")

  let select_user_capabilities_for_update_sql =
    Mql_sql.read [%blob "./sql/select_user_capabilities_for_update.sql"]

  let select_user_capabilities_for_update () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* capability_trie *)
      caps_ret
      //
      (* base_capability_trie *)
      caps_ret
      /^ select_user_capabilities_for_update_sql
      /% Var.uuid "user_id")

  let fetch_select_user_capabilities_for_update db user =
    Pgsql_io.Prepared_stmt.fetch
      db
      (select_user_capabilities_for_update ())
      ~f:(fun capabilities base_capabilities -> (capabilities, base_capabilities))
      user

  let update_user_capabilities_sql = Mql_sql.read [%blob "./sql/update_user_capabilities.sql"]

  let update_user_capabilities () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* id *)
      Ret.uuid
      /^ update_user_capabilities_sql
      /% Var.json "capability_trie"
      /% Var.json "base_capability_trie"
      /% Var.uuid "user_id")

  let fetch_update_user_capabilities ~effective ~base db user =
    Pgsql_io.Prepared_stmt.fetch
      db
      (update_user_capabilities ())
      ~f:CCFun.id
      (Sg_caps_json.to_json effective)
      (Sg_caps_json.to_json base)
      user

  let delete_user_login_sessions_sql = Mql_sql.read [%blob "./sql/delete_user_login_sessions.sql"]

  let delete_user_login_sessions () =
    Pgsql_io.Typed_sql.(
      sql /^ delete_user_login_sessions_sql /% Var.uuid "user_id" /% Var.(option (uuid "except")))

  let select_base_capabilities_sql = Mql_sql.read [%blob "./sql/select_base_capabilities.sql"]

  let select_base_capabilities () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* base_capability_trie *)
      caps_ret
      /^ select_base_capabilities_sql
      /% Var.uuid "user_id")

  let set_capabilities_sql = Mql_sql.read [%blob "./sql/set_capabilities.sql"]

  let set_capabilities () =
    Pgsql_io.Typed_sql.(
      sql /^ set_capabilities_sql /% Var.json "capability_trie" /% Var.uuid "user_id")

  let select_user_capabilities_sql = Mql_sql.read [%blob "./sql/select_user_capabilities.sql"]

  (* One query, two questions: with no [user_id] it hands back every active human user's
     capabilities, with one it hands back that user's.  A row that does not decode into a
     capabilities object fails the query rather than being skipped -- same choice as
     select_tenant_users.sql, since a capability nobody can read is not a capability nobody has. *)
  let select_user_capabilities () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* capability_trie *)
      caps_ret
      /^ select_user_capabilities_sql
      /% Var.(option (uuid "user_id")))

  let lock_instance_admins_sql = Mql_sql.read [%blob "./sql/lock_instance_admins.sql"]

  (* Answers one boolean row that means nothing; see ./sql/lock_instance_admins.sql. *)
  let lock_instance_admins () = Pgsql_io.Typed_sql.(sql // Ret.boolean /^ lock_instance_admins_sql)
  let select_has_human_users_sql = Mql_sql.read [%blob "./sql/select_has_human_users.sql"]

  let select_has_human_users () =
    Pgsql_io.Typed_sql.(sql // Ret.boolean /^ select_has_human_users_sql)
end

let make ~id () = { id; v = () }
let to_minted t = { id = t.id; v = () }
let id t = t.id
let name t = t.v.name
let email t = t.v.email
let type_ t = t.v.type_
let avatar_url t = t.v.avatar_url
let auth_origin t = t.v.auth_origin
let capabilities t = t.v.capabilities

let default_capabilities =
  {
    Sg_caps.empty with
    Sg_caps.access_token_create = true;
    access_token_refresh = true;
    commit = { Sg_caps.modified = Sg_caps_reach.everything; pulled_in = Sg_caps_reach.everything };
    preview = { Sg_caps.modified = Sg_caps_reach.everything; pulled_in = Sg_caps_reach.everything };
  }

let default_user_caps db =
  let open Abbs_fc.Infix_result_monad in
  Pgsql_io.Prepared_stmt.fetch db (Sql.select_default_user_caps ()) ~f:CCFun.id
  >>| function
  | json :: _ -> CCResult.get_or ~default:default_capabilities (Sg_caps_json.of_json json)
  | [] -> default_capabilities

let set_default_user_caps caps db =
  Pgsql_io.Prepared_stmt.execute db (Sql.upsert_default_user_caps ()) (Sg_caps_json.to_json caps)

(* Which of the two tenant-scoped grants an edit is about. *)
type tenant_grant =
  [ `Admin
  | `Users_manage
  ]
[@@deriving show]

type instance_admin =
  [ `Instance_admin
  | `No_admin
  ]
[@@deriving show]

type admin_scope =
  [ `No
  | `Instance
  | `Tenants of string list
  ]

(* The tenants a list of ids names, as a scope. A tenant id holds no pattern character, so this
   cannot fail; an id that somehow did would name no tenant rather than more than it should. *)
let tenants_scope tenants =
  CCResult.get_or ~default:Sg_caps_trie_scope.empty (Sg_caps_trie_scope.of_strings tenants)

let caps_for ~admin db =
  let open Abbs_fc.Infix_result_monad in
  default_user_caps db
  >>| fun caps ->
  let admin =
    match admin with
    (* [`No] does not revoke: whatever the default-caps setting grants is left alone. *)
    | `No -> caps.Sg_caps.admin
    | `Instance -> Sg_caps_trie_scope.full
    | `Tenants tenants -> tenants_scope tenants
  in
  { caps with Sg_caps.admin }

let caps_or_default ?capabilities ~admin db =
  match capabilities with
  | Some c -> Abbs_fc.return_ok c
  | None -> caps_for ~admin db

let store ?email ?(admin = `No) ?capabilities ?password_hash ~name ~type_ db =
  let open Abbs_fc.Infix_result_monad in
  caps_or_default ?capabilities ~admin db
  >>= fun capabilities ->
  Pgsql_io.Prepared_stmt.fetch
    db
    (Sql.insert_user ())
    ~f:CCFun.id
    email
    name
    type_
    password_hash
    (Sg_caps_json.to_json capabilities)
  >>= function
  | id :: _ ->
      Abbs_fc.return_ok
        { id; v = { name; email; type_; avatar_url = None; auth_origin = None; capabilities } }
  | [] -> assert false

let enrich t db =
  let open Abbs_fc.Infix_result_monad in
  Pgsql_io.Prepared_stmt.fetch
    db
    (Sql.select_user_by_user_id ())
    ~f:(fun id name email type_ avatar_url auth_origin capabilities ->
      { id; v = { name; email; type_; avatar_url; auth_origin; capabilities } })
    t.id
  >>? function
  | user :: _ -> Ok user
  | [] -> Error (`User_not_found_err t.id)

type tenant_grant_err =
  [ `User_not_found_err of Uuidm.t
  | Pgsql_io.err
  ]
[@@deriving show]

(* A login session is a DB row snapshotting the capabilities at sign-in (see
   [Sgs_user_session.Session.create_login]); once the capabilities change, the snapshot is stale in
   either direction, so the rows are deleted and the user signs in again.  API tokens are
   deliberately left alone: capabilities limit what tokens a user can create, not what an
   already-minted token can do. *)
let revoke_login_sessions ?except user db =
  Pgsql_io.Prepared_stmt.execute db (Sql.delete_user_login_sessions ()) user.id except

(* The read-modify-write shared by {!grant_tenant} and {!revoke_tenant}. [f] is the pure edit.
   The updated effective capabilities (the one unioned with groups rules) is returned. *)
let edit_tenant_capabilities ?except_login_session ~f ~tenant_id user db =
  let open Abbs_fc.Infix_result_monad in
  Sql.fetch_select_user_capabilities_for_update db user.id
  >>= function
  | [] -> Abbs_fc.return_err (`User_not_found_err user.id)
  | (capabilities, base_capabilities) :: _ -> (
      let f = f ~tenant:(Uuidm.to_string tenant_id) in
      let f_capabilities = f capabilities in
      Sql.fetch_update_user_capabilities
        ~effective:f_capabilities
        ~base:(f base_capabilities)
        db
        user.id
      >>= function
      | _ :: _ ->
          revoke_login_sessions ?except:except_login_session user db >>| fun () -> f_capabilities
      | [] -> Abbs_fc.return_err (`User_not_found_err user.id))

let edit_grants ~grants ~edit ~tenant caps =
  let tenant = tenants_scope [ tenant ] in
  CCList.fold_left
    (fun caps -> function
      | `Admin -> { caps with Sg_caps.admin = edit caps.Sg_caps.admin tenant }
      | `Users_manage -> { caps with Sg_caps.users_manage = edit caps.Sg_caps.users_manage tenant })
    caps
    grants

let grant_tenant ?except_login_session ~grants ~tenant_id user db =
  edit_tenant_capabilities
    ?except_login_session
    ~f:(edit_grants ~grants ~edit:Sg_caps_trie_scope.union)
    ~tenant_id
    user
    db

let revoke_tenant ~grants ~tenant_id user db =
  edit_tenant_capabilities ~f:(edit_grants ~grants ~edit:Sg_caps_trie_scope.diff) ~tenant_id user db

let recompute_login_capabilities ~group_caps db id =
  let open Abbs_fc.Infix_result_monad in
  Pgsql_io.Prepared_stmt.fetch db (Sql.select_base_capabilities ()) ~f:CCFun.id id
  >>= function
  | [] -> Abbs_fc.return_err (`User_not_found_err id)
  | base :: _ ->
      let effective = Sg_caps.union base group_caps in
      Pgsql_io.Prepared_stmt.execute
        db
        (Sql.set_capabilities ())
        (Sg_caps_json.to_json effective)
        id
      >>| fun () -> effective

type instance_admin_status =
  | Instance_admin
  | Not_instance_admin
  | No_active_user

let capabilities_of db user_id =
  let open Abbs_fc.Infix_result_monad in
  Pgsql_io.Prepared_stmt.fetch db (Sql.select_user_capabilities ()) ~f:CCFun.id (Some user_id)
  >>| CCList.head_opt

let instance_admin_status db user_id =
  let open Abbs_fc.Infix_result_monad in
  capabilities_of db user_id
  >>| function
  | Some caps when Sg_caps_trie_scope.is_full caps.Sg_caps.admin -> Instance_admin
  | Some _ -> Not_instance_admin
  | None -> No_active_user

let count_instance_admins db =
  let open Abbs_fc.Infix_result_monad in
  Pgsql_io.Prepared_stmt.fetch db (Sql.select_user_capabilities ()) ~f:CCFun.id None
  >>| CCList.count (fun caps -> Sg_caps_trie_scope.is_full caps.Sg_caps.admin)

let has_human_users db =
  let open Abbs_fc.Infix_result_monad in
  Pgsql_io.Prepared_stmt.fetch db (Sql.select_has_human_users ()) ~f:CCFun.id
  >>| CCList.exists CCFun.id

let lock_instance_admins db =
  let open Abbs_fc.Infix_result_monad in
  Pgsql_io.Prepared_stmt.fetch db (Sql.lock_instance_admins ()) ~f:CCFun.id >>| fun _ -> ()

let guard_last_instance_admin ~f db target_user_id =
  let open Abbs_fc.Infix_result_monad in
  Pgsql_io.tx db ~f:(fun () ->
      lock_instance_admins db
      >>= fun () ->
      instance_admin_status db target_user_id
      >>= function
      | No_active_user -> Abbs_fc.return_err `Not_found_user_err
      | Not_instance_admin -> f ()
      | Instance_admin -> (
          count_instance_admins db
          >>= function
          | admin_count when admin_count <= 1 ->
              Abbs_fc.return_err `Would_remove_last_instance_admin_err
          | _ -> f ()))

(* The read-modify-write behind [set_instance_admin].  Everything the user holds besides [admin] is
   carried over, which is why the current value is read rather than overwritten blind; why both
   columns are written is in ./sql/update_user_capabilities.sql.  The read is also what tells a
   write that changes a column from one that does not, and only the first is worth a logout: a
   login session snapshots the capabilities, and a snapshot of what did not change is not stale.

   TODO Tamiya: should we avoid logging out the user when widening its capability? *)
let write_instance_admin admin db target_user_id =
  let open Abbs_fc.Infix_result_monad in
  Sql.fetch_select_user_capabilities_for_update db target_user_id
  >>= function
  | [] -> Abbs_fc.return_err `Not_found_user_err
  | (capabilities, base_capabilities) :: _ -> (
      let set_admin_field caps =
        let with_admin scope = `Change { caps with Sg_caps.admin = scope } in
        match (admin, Sg_caps_trie_scope.is_full caps.Sg_caps.admin) with
        | `Instance_admin, true | `No_admin, false -> `No_change
        | `Instance_admin, false -> with_admin Sg_caps_trie_scope.full
        | `No_admin, true -> with_admin Sg_caps_trie_scope.empty
      in
      let or_current current = function
        | `Change caps -> caps
        | `No_change -> current
      in
      match (set_admin_field capabilities, set_admin_field base_capabilities) with
      | `No_change, `No_change -> Abbs_fc.return_ok ()
      | ((`Change _ | `No_change) as capabilities'), ((`Change _ | `No_change) as base') ->
          Sql.fetch_update_user_capabilities
            ~effective:(or_current capabilities capabilities')
            ~base:(or_current base_capabilities base')
            db
            target_user_id
          (* The returned id says the row was still there, which the lock above already
             guarantees. *)
          >>= fun _ -> revoke_login_sessions (make ~id:target_user_id ()) db)

let set_instance_admin admin ~f db target_user_id =
  let open Abbs_fc.Infix_result_monad in
  let write () = write_instance_admin admin db target_user_id >>= f in
  match admin with
  | `Instance_admin -> Pgsql_io.tx db ~f:write
  | `No_admin -> guard_last_instance_admin ~f:write db target_user_id
