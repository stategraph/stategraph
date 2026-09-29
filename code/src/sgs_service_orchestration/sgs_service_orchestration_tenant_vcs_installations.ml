type t = {
  tenant_id : Uuidm.t;
  provider : string;
  installation_core_id : Uuidm.t;
  created_at : string;
  updated_at : string;
}

let valid_vcs_provider = function
  | "github" | "gitlab" -> true
  | _ -> false

module Sql = struct
  let read s = Pgsql_io.clean_string s

  let select_by_tenant () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* tenant_id *)
      Ret.uuid
      //
      (* provider *)
      Ret.text
      //
      (* installation_core_id *)
      Ret.uuid
      //
      (* created_at *)
      Ret.text
      //
      (* updated_at *)
      Ret.text
      /^ read [%blob "sql/select_tenant_vcs_installations.sql"]
      /% Var.uuid "tenant_id")

  let upsert () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* tenant_id *)
      Ret.uuid
      //
      (* provider *)
      Ret.text
      //
      (* installation_core_id *)
      Ret.uuid
      //
      (* created_at *)
      Ret.text
      //
      (* updated_at *)
      Ret.text
      //
      (* previous tenant_id *)
      Ret.(option uuid)
      /^ read [%blob "sql/upsert_tenant_vcs_installation.sql"]
      /% Var.uuid "tenant_id"
      /% Var.text "provider"
      /% Var.uuid "installation_core_id")

  let link_if_unlinked () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* tenant_id *)
      Ret.uuid
      //
      (* provider *)
      Ret.text
      //
      (* installation_core_id *)
      Ret.uuid
      //
      (* created_at *)
      Ret.text
      //
      (* updated_at *)
      Ret.text
      /^ read [%blob "sql/link_tenant_vcs_installation_if_unlinked.sql"]
      /% Var.uuid "tenant_id"
      /% Var.text "provider"
      /% Var.uuid "installation_core_id")

  let select_by_installation () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* tenant_id *)
      Ret.uuid
      //
      (* provider *)
      Ret.text
      //
      (* installation_core_id *)
      Ret.uuid
      //
      (* created_at *)
      Ret.text
      //
      (* updated_at *)
      Ret.text
      /^ read [%blob "sql/select_tenant_vcs_installation.sql"]
      /% Var.text "provider"
      /% Var.uuid "installation_core_id")

  let delete () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* provider, one row per deleted mapping *)
      Ret.text
      /^ read [%blob "sql/delete_tenant_vcs_installation.sql"]
      /% Var.uuid "tenant_id"
      /% Var.text "provider"
      /% Var.uuid "installation_core_id")
end

let row tenant_id provider installation_core_id created_at updated_at =
  { tenant_id; provider; installation_core_id; created_at; updated_at }

let list_by_tenant ~tenant_id db =
  Pgsql_io.Prepared_stmt.fetch db (Sql.select_by_tenant ()) ~f:row tenant_id

let link_if_unlinked ~tenant_id ~provider ~installation_core_id db =
  let open Abbs_fc.Infix_result_monad in
  Pgsql_io.Prepared_stmt.fetch
    db
    (Sql.link_if_unlinked ())
    ~f:row
    tenant_id
    provider
    installation_core_id
  >>= function
  | t :: _ -> Abbs_fc.return_ok (`Linked t)
  | [] -> (
      (* The insert linked nothing, so some tenant holds the installation. The
         one that does is retrying its own claim, and gets its link back
         rather than a conflict. *)
      Pgsql_io.Prepared_stmt.fetch
        db
        (Sql.select_by_installation ())
        ~f:row
        provider
        installation_core_id
      >>| function
      | t :: _ when Uuidm.equal t.tenant_id tenant_id -> `Already_linked_here t
      | _ :: _ | [] -> `Linked_elsewhere)

let upsert ~tenant_id ~provider ~installation_core_id db =
  let open Abb.Future.Infix_monad in
  Pgsql_io.Prepared_stmt.fetch
    db
    (Sql.upsert ())
    ~f:(fun tenant_id provider installation_core_id created_at updated_at prev ->
      (row tenant_id provider installation_core_id created_at updated_at, prev))
    tenant_id
    provider
    installation_core_id
  >>= function
  | Ok [ (t, prev) ] -> Abbs_fc.return_ok (`Linked (t, prev))
  | Ok [] ->
      (* The insert is driven off a [tenants] lookup, so a missing tenant
         yields zero rows rather than a foreign-key violation, which is
         easier for error handling. *)
      Abbs_fc.return_ok `Tenant_not_found
  | Ok (_ :: _ :: _) ->
      (* The upsert targets a single primary key. *)
      assert false
  | Error (#Pgsql_io.err as err) -> Abbs_fc.return_err err

let delete ~tenant_id ~provider ~installation_core_id db =
  let open Abbs_fc.Infix_result_monad in
  Pgsql_io.Prepared_stmt.fetch
    db
    (Sql.delete ())
    ~f:CCFun.id
    tenant_id
    provider
    installation_core_id
  >>| function
  | _ :: _ -> `Deleted
  | [] -> `Not_found

let to_api t =
  {
    Sgs_api_components.Vcs_installation.tenant_id = Uuidm.to_string t.tenant_id;
    provider = t.provider;
    installation_core_id = Uuidm.to_string t.installation_core_id;
    created_at = t.created_at;
    updated_at = t.updated_at;
  }

let to_body t = Yojson.Safe.to_string (Sgs_api_components.Vcs_installation.to_yojson (to_api t))
