type t = {
  group_id : int;
  name : string;
  state : string;
  webhook_secret : string option;
}

module Sql = struct
  let read s = Pgsql_io.clean_string s

  let select_tenant_installation () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* one *)
      Ret.integer
      /^ read [%blob "sql/select_tenant_gitlab_installation.sql"]
      /% Var.uuid "tenant_id"
      /% Var.bigint "group_id")

  let update_token () =
    Pgsql_io.Typed_sql.(
      sql
      /^ read [%blob "sql/update_gitlab_installation_token.sql"]
      /% Var.text "access_token"
      /% Var.bigint "group_id")

  let update_secret () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* webhook_secret *)
      Ret.text
      /^ read [%blob "sql/update_gitlab_installation_secret.sql"]
      /% Var.bigint "group_id")

  let select_rotated () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* name *)
      Ret.text
      //
      (* state *)
      Ret.text
      /^ read [%blob "sql/select_gitlab_installation_rotated.sql"]
      /% Var.bigint "group_id")
end

type rotate_err =
  [ Pgsql_io.err
  | `Not_found_err
  | `Rotated_row_missing_err
  ]

let rotate ~tenant_id ~group_id ~access_token ~webhook_secret db =
  Pgsql_io.tx db ~f:(fun () ->
      let open Abbs_fc.Infix_result_monad in
      Pgsql_io.Prepared_stmt.fetch
        db
        (Sql.select_tenant_installation ())
        ~f:CCFun.id
        tenant_id
        (Int64.of_int group_id)
      >>= function
      | [] -> Abb.Future.return (Error `Not_found_err)
      | _ :: _ -> (
          (match access_token with
            | Some token ->
                Pgsql_io.Prepared_stmt.execute
                  db
                  (Sql.update_token ())
                  token
                  (Int64.of_int group_id)
            | None -> Abb.Future.return (Ok ()))
          >>= fun () ->
          (* The secret is read back from the update that regenerated it
             only, so a token-only rotation never pulls the live secret. *)
          (match webhook_secret with
            | `Regenerate -> (
                Pgsql_io.Prepared_stmt.fetch
                  db
                  (Sql.update_secret ())
                  ~f:CCFun.id
                  (Int64.of_int group_id)
                >>= function
                | [] -> Abbs_fc.return_err `Rotated_row_missing_err
                | secret :: _ -> Abbs_fc.return_ok (Some secret))
            | `Keep -> Abbs_fc.return_ok None)
          >>= fun webhook_secret ->
          Pgsql_io.Prepared_stmt.fetch
            db
            (Sql.select_rotated ())
            ~f:(fun name state -> (name, state))
            (Int64.of_int group_id)
          >>= function
          | [] ->
              (* The map row existed above in the same remote transaction,
                 so this shouldn't happen. *)
              Abb.Future.return (Error `Rotated_row_missing_err)
          | (name, state) :: _ -> Abb.Future.return (Ok { group_id; name; state; webhook_secret })))

let to_api t =
  {
    Sgs_api_components.Gitlab_rotate_response.group_id = t.group_id;
    name = t.name;
    state = t.state;
    webhook_secret = t.webhook_secret;
  }
