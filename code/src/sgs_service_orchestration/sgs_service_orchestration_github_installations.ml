type installation = {
  installation_core_id : Uuidm.t;
  github_id : int;
  login : string;
  target_type : string;
  state : string;
  created_at : string;
}

module Sql = struct
  let read s = Pgsql_io.clean_string s

  let select_unclaimed () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* core_id *)
      Ret.uuid
      //
      (* github id *)
      Ret.bigint
      //
      (* login *)
      Ret.text
      //
      (* target_type *)
      Ret.text
      //
      (* state *)
      Ret.text
      //
      (* created_at *)
      Ret.text
      /^ read [%blob "sql/select_unclaimed_github_installations.sql"]
      /% Var.(option (timestamptz "cursor"))
      /% Var.(option (uuid "cursor_id"))
      /% Var.smallint "limit")

  let select_claimable () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* core_id *)
      Ret.uuid
      //
      (* github id *)
      Ret.bigint
      //
      (* login *)
      Ret.text
      //
      (* target_type *)
      Ret.text
      //
      (* state *)
      Ret.text
      //
      (* created_at *)
      Ret.text
      /^ read [%blob "sql/select_claimable_github_installations.sql"]
      /% Var.(str_array (bigint "github_installation_ids")))

  let select_claimable_by_core_id () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* core_id *)
      Ret.uuid
      //
      (* github id *)
      Ret.bigint
      //
      (* login *)
      Ret.text
      //
      (* target_type *)
      Ret.text
      //
      (* state *)
      Ret.text
      //
      (* created_at *)
      Ret.text
      /^ read [%blob "sql/select_claimable_github_installations_by_core_id.sql"]
      /% Var.(str_array (uuid "installation_core_ids")))
end

let row installation_core_id github_id login target_type state created_at =
  {
    installation_core_id;
    github_id = Int64.to_int github_id;
    login;
    target_type;
    state;
    created_at;
  }

let list_unclaimed ~cursor ~limit db =
  let cursor_created_at, cursor_id =
    match cursor with
    | Some (created_at, id) -> (Some created_at, Some id)
    | None -> (None, None)
  in
  Pgsql_io.Prepared_stmt.fetch db (Sql.select_unclaimed ()) ~f:row cursor_created_at cursor_id limit

let list_claimable_by_core_ids ~installation_core_ids db =
  Pgsql_io.Prepared_stmt.fetch db (Sql.select_claimable_by_core_id ()) ~f:row installation_core_ids

let list_claimable ~github_installation_ids db =
  Pgsql_io.Prepared_stmt.fetch
    db
    (Sql.select_claimable ())
    ~f:row
    (CCList.map Int64.of_int github_installation_ids)

let to_api t =
  {
    Sgs_api_components.Github_unclaimed_installation.installation_core_id =
      Uuidm.to_string t.installation_core_id;
    github_id = t.github_id;
    login = t.login;
    target_type = t.target_type;
    state = t.state;
    created_at = t.created_at;
  }
