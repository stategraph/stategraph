type err = Pgsql_io.err [@@deriving show]

type enforce_user_err =
  [ `User_not_in_tenant_err of Uuidm.t * Uuidm.t
  | Pgsql_io.err
  ]
[@@deriving show]

type create_err =
  [ `Name_conflict_err
  | `Name_invalid_err
  | Pgsql_io.err
  ]
[@@deriving show]

type rename_err =
  [ `Name_conflict_err
  | `Name_invalid_err
  | `Tenant_not_found_err of Uuidm.t
  | Pgsql_io.err
  ]
[@@deriving show]

type minted = unit
type stored = { name : string }

type 'a t = {
  id : Uuidm.t;
  v : 'a;
}

module Member = struct
  type t = {
    id : Uuidm.t;
    name : string;
    email : string option;
    type_ : Sgs_user.Type_.t;
    avatar_url : string option;
    joined_at : string;
    admin : Sg_caps_ops.Tenant_scope.coverage;
    users_manage : Sg_caps_ops.Tenant_scope.coverage;
  }
  [@@deriving show]
end

(* A tenant name is the display label for a whole workspace and is resolved by [find_or_create], so a
   blank one would be both meaningless and ambiguous.  Bounded because the column is unconstrained
   [text] and an endpoint should not let a caller store an arbitrarily large one. *)
let max_name_length = 255

let valid_name name =
  let name = CCString.trim name in
  (not (CCString.is_empty name)) && CCString.length name <= max_name_length

module Sql = struct
  let insert_tenant_sql = Mql_sql.read [%blob "./sql/insert_tenant.sql"]

  let insert_tenant () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* id *)
      Ret.uuid
      /^ insert_tenant_sql
      /% Var.text "name")

  let insert_tenant_if_name_free_sql = Mql_sql.read [%blob "./sql/insert_tenant_if_name_free.sql"]

  let insert_tenant_if_name_free () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* id *)
      Ret.uuid
      /^ insert_tenant_if_name_free_sql
      /% Var.text "name")

  let add_user_sql = Mql_sql.read [%blob "./sql/insert_tenant_user.sql"]

  let add_user () =
    Pgsql_io.Typed_sql.(sql /^ add_user_sql /% Var.uuid "tenant_id" /% Var.uuid "user_id")

  let select_by_user_id_sql = Mql_sql.read [%blob "./sql/select_tenants_by_user_id.sql"]

  let select_by_user_id () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* id *)
      Ret.uuid
      //
      (* name *)
      Ret.text
      /^ select_by_user_id_sql
      /% Var.uuid "user_id")

  let select_user_id_by_tenant_id_sql = Mql_sql.read [%blob "./sql/select_user_id_by_tenant_id.sql"]

  let select_user_id_by_tenant_id () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* user_id *)
      Ret.uuid
      /^ select_user_id_by_tenant_id_sql
      /% Var.uuid "user_id"
      /% Var.uuid "tenant_id")

  let select_by_name_sql = Mql_sql.read [%blob "./sql/select_tenant_by_name.sql"]

  let select_by_name () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* id *)
      Ret.uuid
      //
      (* name *)
      Ret.text
      /^ select_by_name_sql
      /% Var.text "name")

  let add_user_idempotent_sql = Mql_sql.read [%blob "./sql/insert_tenant_user_idempotent.sql"]

  let add_user_idempotent () =
    Pgsql_io.Typed_sql.(
      sql /^ add_user_idempotent_sql /% Var.uuid "tenant_id" /% Var.uuid "user_id")

  let delete_tenant_user_sql = Mql_sql.read [%blob "./sql/delete_tenant_user.sql"]

  let delete_tenant_user () =
    Pgsql_io.Typed_sql.(sql /^ delete_tenant_user_sql /% Var.uuid "tenant_id" /% Var.uuid "user_id")

  let select_tenant_sql = Mql_sql.read [%blob "./sql/select_tenant.sql"]

  let select_tenant () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* id *)
      Ret.uuid
      //
      (* name *)
      Ret.text
      /^ select_tenant_sql
      /% Var.uuid "tenant_id")

  let select_tenant_for_update_sql = Mql_sql.read [%blob "./sql/select_tenant_for_update.sql"]

  let select_tenant_for_update () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* id *)
      Ret.uuid
      //
      (* name *)
      Ret.text
      /^ select_tenant_for_update_sql
      /% Var.uuid "tenant_id")

  let update_tenant_name_sql = Mql_sql.read [%blob "./sql/update_tenant_name.sql"]

  let update_tenant_name () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* id *)
      Ret.uuid
      //
      (* name *)
      Ret.text
      /^ update_tenant_name_sql
      /% Var.text "name"
      /% Var.uuid "tenant_id")

  let select_tenant_member_capabilities_sql =
    Mql_sql.read [%blob "./sql/select_tenant_member_capabilities.sql"]

  let select_tenant_member_capabilities () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* capability_trie *)
      Sgs_user.caps_ret
      /^ select_tenant_member_capabilities_sql
      /% Var.uuid "tenant_id")

  let select_tenant_users_sql = Mql_sql.read [%blob "./sql/select_tenant_users.sql"]

  let select_tenant_users () =
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
      (* capability_trie *)
      Sgs_user.caps_ret
      //
      (* joined_at *)
      Ret.text
      //
      (* total_count *)
      Ret.bigint
      /^ select_tenant_users_sql
      /% Var.uuid "tenant_id"
      /% Var.(option (text "cursor"))
      /% Var.(option (uuid "cursor_id"))
      /% Var.smallint "limit")

  let select_tenant_member_sql = Mql_sql.read [%blob "./sql/select_tenant_member.sql"]

  let select_tenant_member () =
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
      (* capability_trie *)
      Sgs_user.caps_ret
      //
      (* joined_at *)
      Ret.text
      /^ select_tenant_member_sql
      /% Var.uuid "tenant_id"
      /% Var.uuid "user_id")

  let close_tenant_sql = Mql_sql.read [%blob "./sql/close_tenant.sql"]

  let close_tenant () =
    Pgsql_io.Typed_sql.(sql // Ret.uuid /^ close_tenant_sql /% Var.uuid "tenant_id")

  let reopen_tenant_sql = Mql_sql.read [%blob "./sql/reopen_tenant.sql"]

  let reopen_tenant () =
    Pgsql_io.Typed_sql.(sql // Ret.uuid /^ reopen_tenant_sql /% Var.uuid "tenant_id")

  let delete_tenant_deletion_schedule_sql =
    Mql_sql.read [%blob "./sql/delete_tenant_deletion_schedule.sql"]

  let delete_tenant_deletion_schedule () =
    Pgsql_io.Typed_sql.(sql /^ delete_tenant_deletion_schedule_sql /% Var.uuid "tenant_id")

  let select_member_of_any_tenant_sql = Mql_sql.read [%blob "./sql/select_member_of_any_tenant.sql"]

  let select_member_of_any_tenant () =
    Pgsql_io.Typed_sql.(
      sql
      // Ret.uuid
      /^ select_member_of_any_tenant_sql
      /% Var.uuid "user_id"
      /% Var.uuid "tenant_id")

  let select_closed_by_user_id_sql =
    Mql_sql.read [%blob "./sql/select_closed_tenants_by_user_id.sql"]

  let select_closed_by_user_id () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* id *)
      Ret.uuid
      //
      (* name *)
      Ret.text
      //
      (* ended_at *)
      Ret.text
      /^ select_closed_by_user_id_sql
      /% Var.uuid "user_id")
end

let make ~id () = { id; v = () }
let id t = t.id
let name t = t.v.name
let to_api t = { Sgs_api_components.Tenant.id = Uuidm.to_string t.id; name = t.v.name }

let store name db =
  let open Abbs_fc.Infix_result_monad in
  Pgsql_io.Prepared_stmt.fetch db (Sql.insert_tenant ()) ~f:CCFun.id name
  >>= function
  | id :: _ -> Abbs_fc.return_ok { id; v = { name } }
  | [] -> assert false

(* The create counterpart of [rename]: same name rules, same refusal of a name already in use. *)
let create name db =
  let open Abbs_fc.Infix_result_monad in
  if not (valid_name name) then Abbs_fc.return_err `Name_invalid_err
  else
    let name = CCString.trim name in
    Pgsql_io.Prepared_stmt.fetch db (Sql.insert_tenant_if_name_free ()) ~f:CCFun.id name
    >>? function
    | id :: _ -> Ok { id; v = { name } }
    (* The insert is guarded only by the name clause, so nothing else can match zero rows. *)
    | [] -> Error `Name_conflict_err

let find_or_create name db =
  let open Abbs_fc.Infix_result_monad in
  Pgsql_io.Prepared_stmt.fetch
    db
    (Sql.select_by_name ())
    ~f:(fun id name -> { id; v = { name } })
    name
  >>= function
  | tenant :: _ -> Abbs_fc.return_ok tenant
  | [] -> store name db

let add_user t user db = Pgsql_io.Prepared_stmt.execute db (Sql.add_user ()) t.id (Sgs_user.id user)

let list_by_user user db =
  Pgsql_io.Prepared_stmt.fetch
    db
    (Sql.select_by_user_id ())
    ~f:(fun id name -> { id; v = { name } })
    (Sgs_user.id user)

let enforce_user user tenant db =
  let open Abbs_fc.Infix_result_monad in
  Pgsql_io.Prepared_stmt.fetch
    db
    (Sql.select_user_id_by_tenant_id ())
    ~f:CCFun.id
    (Sgs_user.id user)
    (id tenant)
  >>? function
  | [] -> Error (`User_not_in_tenant_err (id tenant, Sgs_user.id user))
  | _ :: _ -> Ok ()

let enforce_member user tenant db =
  let open Abbs_fc.Infix_result_monad in
  Pgsql_io.Prepared_stmt.fetch
    db
    (Sql.select_member_of_any_tenant ())
    ~f:CCFun.id
    (Sgs_user.id user)
    (id tenant)
  >>? function
  | [] -> Error (`User_not_in_tenant_err (id tenant, Sgs_user.id user))
  | _ :: _ -> Ok ()

let close tenant db =
  let open Abbs_fc.Infix_result_monad in
  Pgsql_io.Prepared_stmt.fetch db (Sql.close_tenant ()) ~f:CCFun.id (id tenant)
  >>| function
  | [] -> `Already_closed
  | _ :: _ -> `Closed

let reopen tenant db =
  let open Abbs_fc.Infix_result_monad in
  Pgsql_io.Prepared_stmt.fetch db (Sql.reopen_tenant ()) ~f:CCFun.id (id tenant)
  >>= function
  | [] -> Abbs_fc.return_ok `Not_closed
  | _ :: _ ->
      Pgsql_io.Prepared_stmt.execute db (Sql.delete_tenant_deletion_schedule ()) (id tenant)
      >>| fun () -> `Reopened

let list_closed_by_user user db =
  Pgsql_io.Prepared_stmt.fetch
    db
    (Sql.select_closed_by_user_id ())
    ~f:(fun id name ended_at -> (id, name, ended_at))
    (Sgs_user.id user)

let add_user_idempotent t user db =
  Pgsql_io.Prepared_stmt.execute db (Sql.add_user_idempotent ()) t.id (Sgs_user.id user)

let remove_user t user db =
  Pgsql_io.Prepared_stmt.execute db (Sql.delete_tenant_user ()) t.id (Sgs_user.id user)

(* The coverage of one grant over this tenant, from the member's stored capabilities.  Shared by
   [list_users] and [find_member] so both report the same classification. *)
let member_of_row t id name email type_ avatar_url capabilities joined_at =
  let tenant_id = Uuidm.to_string t.id in
  {
    Member.id;
    name;
    email;
    type_;
    avatar_url;
    joined_at;
    admin = Sg_caps_ops.tenant_coverage capabilities `Admin ~tenant:tenant_id;
    users_manage = Sg_caps_ops.tenant_coverage capabilities `Users_manage ~tenant:tenant_id;
  }

let fetch t db =
  let open Abbs_fc.Infix_result_monad in
  Pgsql_io.Prepared_stmt.fetch
    db
    (Sql.select_tenant ())
    ~f:(fun id name -> { id; v = { name } })
    t.id
  >>| fun rows -> CCList.head_opt rows

let find_member t user_id db =
  let open Abbs_fc.Infix_result_monad in
  Pgsql_io.Prepared_stmt.fetch db (Sql.select_tenant_member ()) ~f:(member_of_row t) t.id user_id
  >>| fun rows -> CCList.head_opt rows

let list_users ?cursor ~limit t db =
  let open Abbs_fc.Infix_result_monad in
  (* The cursor is the (join time, user id) of the last row of the previous page -- the full sort key,
     so members who joined in the same instant are split cleanly across a page boundary. *)
  let cursor_joined_at, cursor_id =
    match cursor with
    | Some (joined_at, id) -> (Some joined_at, Some id)
    | None -> (None, None)
  in
  Pgsql_io.Prepared_stmt.fetch
    db
    (Sql.select_tenant_users ())
    ~f:(fun id name email type_ avatar_url capabilities joined_at total_count ->
      (member_of_row t id name email type_ avatar_url capabilities joined_at, total_count))
    t.id
    cursor_joined_at
    cursor_id
    limit
  >>| fun rows ->
  (* The windowed total repeats on every row, so any row carries it; an empty page means the tenant
     has no members left to show. *)
  let total = CCOption.map_or ~default:0 (fun (_, n) -> Int64.to_int n) (CCList.head_opt rows) in
  (CCList.map fst rows, total)

let count_admins t db =
  let open Abbs_fc.Infix_result_monad in
  (* This call's purpose is to serialize with the other admin-count-reducing mutations on this tenant.
     Both callers -- set_role (demote) and member remove -- guard on this count, so a race is possible.
     Locking the tenant row here (the same row that 'rename' locks) prevents the race.
     This must run in the caller's transaction so the lock is held through the guarded write. *)
  Pgsql_io.Prepared_stmt.fetch db (Sql.select_tenant_for_update ()) ~f:(fun id _name -> id) t.id
  >>= fun _ ->
  (* Who administers the tenant is decided here, by [Sg_caps_ops.grants_tenant], not by the
     query. What that costs is one capability object per active member crossing the wire inside the
     lock taken above, where the SQL this replaced returned a single integer.

     The trade is transfer and decode, not scan: the old query joined the same member rows and ran a
     per-row jsonb match over every one of them. Two things bound it: both callers reach this
     only when the member being removed or demoted actually holds an admin grant, and the lock is
     the tenant's own row, so a slow count delays other mutations of this tenant and nothing else.

     If a large tenant ever makes it matter, the query can be narrowed to rows carrying an [admin]
     key at all: a member without one cannot grant admin, so that drops no candidate, and it filters
     on the shape of the row rather than restating the matching rules. *)
  Pgsql_io.Prepared_stmt.fetch db (Sql.select_tenant_member_capabilities ()) ~f:CCFun.id t.id
  >>| fun member_caps ->
  let tenant_id = Uuidm.to_string t.id in
  CCList.count (fun caps -> Sg_caps_ops.grants_tenant caps `Admin ~tenant:tenant_id) member_caps

let rename ~name t db =
  let open Abbs_fc.Infix_result_monad in
  if not (valid_name name) then Abbs_fc.return_err `Name_invalid_err
  else
    let name = CCString.trim name in
    Pgsql_io.Prepared_stmt.fetch
      db
      (Sql.select_tenant_for_update ())
      ~f:(fun id name -> { id; v = { name } })
      t.id
    >>= function
    | [] -> Abbs_fc.return_err (`Tenant_not_found_err t.id)
    | _ :: _ -> (
        Pgsql_io.Prepared_stmt.fetch
          db
          (Sql.update_tenant_name ())
          ~f:(fun id name -> { id; v = { name } })
          name
          t.id
        >>? function
        | tenant :: _ -> Ok tenant
        (* The row is locked and confirmed present, so the only way the guarded update matches
           nothing is the name-collision clause. *)
        | [] -> Error `Name_conflict_err)
