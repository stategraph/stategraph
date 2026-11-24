type t = {
  group_id : int;
  name : string;
  state : string;
}

module Sql = struct
  let select_tenant_installation_sql =
    Mql_sql.read [%blob "sql/select_tenant_gitlab_installation.sql"]

  let select_tenant_installation () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* one *)
      Ret.integer
      /^ select_tenant_installation_sql
      /% Var.uuid "tenant_id"
      /% Var.bigint "group_id")

  let update_uninstalled_sql = Mql_sql.read [%blob "sql/update_gitlab_installation_uninstalled.sql"]

  let update_uninstalled () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* name *)
      Ret.text
      //
      (* state *)
      Ret.text
      /^ update_uninstalled_sql
      /% Var.text "uninstalled_by"
      /% Var.bigint "group_id")

  let update_restored_sql = Mql_sql.read [%blob "sql/update_gitlab_installation_restored.sql"]

  let update_restored () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* name *)
      Ret.text
      //
      (* state *)
      Ret.text
      /^ update_restored_sql
      /% Var.bigint "group_id")
end

type state_err =
  [ Pgsql_io.err
  | `Not_found_err
  | `Updated_row_missing_err
  ]

let change ~tenant_id ~group_id ~update db =
  Pgsql_io.tx db ~f:(fun () ->
      let open Abbs_fc.Infix_result_monad in
      Pgsql_io.Prepared_stmt.fetch
        db
        (Sql.select_tenant_installation ())
        ~f:CCFun.id
        tenant_id
        (Int64.of_int group_id)
      >>= function
      | [] -> Abbs_fc.return_err `Not_found_err
      | _ :: _ -> (
          update ()
          >>= function
          | [] -> Abbs_fc.return_err `Updated_row_missing_err
          | (name, state) :: _ -> Abbs_fc.return_ok { group_id; name; state }))

let uninstall ~tenant_id ~group_id ~user_id db =
  change ~tenant_id ~group_id db ~update:(fun () ->
      Pgsql_io.Prepared_stmt.fetch
        db
        (Sql.update_uninstalled ())
        ~f:(fun name state -> (name, state))
        ("stategraph:" ^ Uuidm.to_string user_id)
        (Int64.of_int group_id))

let restore ~tenant_id ~group_id db =
  change ~tenant_id ~group_id db ~update:(fun () ->
      Pgsql_io.Prepared_stmt.fetch
        db
        (Sql.update_restored ())
        ~f:(fun name state -> (name, state))
        (Int64.of_int group_id))

let to_api t =
  {
    Sgs_api_components.Gitlab_installation_state.group_id = t.group_id;
    name = t.name;
    state = t.state;
  }
