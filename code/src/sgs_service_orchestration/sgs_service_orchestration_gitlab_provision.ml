(* The outcome of provisioning a GitLab group installation: the once-returnable
   webhook secret, the installation state, and the tenant<->installation link. *)
type t = {
  group_id : int;
  name : string;
  webhook_secret : string;
  state : string;
  installation_core_id : Uuidm.t;
}

module Sql = struct
  let read s = Pgsql_io.clean_string s

  let insert_installation () =
    Pgsql_io.Typed_sql.(
      sql
      /^ read [%blob "sql/insert_gitlab_installation.sql"]
      /% Var.bigint "group_id"
      /% Var.text "name"
      /% Var.text "access_token")

  let select_provisioned () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* webhook_secret *)
      Ret.text
      //
      (* state *)
      Ret.text
      //
      (* core_id *)
      Ret.uuid
      /^ read [%blob "sql/select_gitlab_installation_provisioned.sql"]
      /% Var.bigint "group_id")
end

type provision_err =
  [ Pgsql_io.err
  | `Already_provisioned_err
  | `Tenant_not_found_err
  | `Provisioned_row_missing_err
  ]

let provision ~tenant_id ~group_id ~name ~access_token db =
  let open Abb.Future.Infix_monad in
  Pgsql_io.tx db ~f:(fun () ->
      let open Abbs_fc.Infix_result_monad in
      Pgsql_io.Prepared_stmt.execute
        db
        (Sql.insert_installation ())
        (Int64.of_int group_id)
        name
        access_token
      >>= fun () ->
      Pgsql_io.Prepared_stmt.fetch
        db
        (Sql.select_provisioned ())
        ~f:(fun webhook_secret state core_id -> (webhook_secret, state, core_id))
        (Int64.of_int group_id)
      >>= fun provisioned ->
      match provisioned with
      | [] ->
          (* The row (and its trigger-written map row) was just inserted in this
             remote transaction, so this shouldn' happen. *)
          Abb.Future.return (Error `Provisioned_row_missing_err)
      | (webhook_secret, state, core_id) :: _ ->
          Sgs_service_orchestration_tenant_vcs_installations.upsert
            ~tenant_id
            ~provider:"gitlab"
            ~installation_core_id:core_id
            db
          >>= fun link ->
          (* Roll the whole provision back if the tenant vanished between the
             capability check and here — never leave an orphaned installation. *)
          Abb.Future.return
            (match link with
            | `Linked _ ->
                Ok { group_id; name; webhook_secret; state; installation_core_id = core_id }
            | `Tenant_not_found -> Error `Tenant_not_found_err))
  >>| function
  | Ok t -> Ok t
  | Error ((`Tenant_not_found_err | `Provisioned_row_missing_err) as err) -> Error err
  | Error (`Unique_violation_err _) -> Error `Already_provisioned_err
  | Error (#Pgsql_io.err as err) -> Error err

let to_api t =
  {
    Sgs_api_components.Gitlab_provision_response.group_id = t.group_id;
    name = t.name;
    webhook_secret = t.webhook_secret;
    state = t.state;
    installation_core_id = Uuidm.to_string t.installation_core_id;
  }
