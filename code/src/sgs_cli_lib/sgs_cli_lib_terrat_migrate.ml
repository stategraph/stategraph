let src = Logs.Src.create "terrat_migrate"

module Logs = (val Logs.src_log src : Logs.LOG)

type err =
  [ `Config_err of
    (Terrat_config.err
    [@printer fun fmt err -> Format.pp_print_string fmt (Terrat_config.show_err err)])
  | `Connect_timeout_err of string
  | `Create_database_err of string * Pgsql_io.err
  | `Create_role_err of string * Pgsql_io.err
  | `Migration_err of [ Pgsql_io.err | Pgsql_pool.err | `Mql_err of Mql.Ast.err ]
  | `Consistency_err of Data_mig.Error.Consistency.t
  | Pgsql_io.create_err
  | Pgsql_io.err
  ]
[@@deriving show]

let maintenance_db = "postgres"
let fdw_role = "stategraph_mql"
let provisioner_role = "stategraph_provisioner"
let fdw_grants_sql = [%blob "../sgs_terrateam_catalog/fdw_grants.sql"]

let fdw_grants =
  Sgs_cli_lib_fdw_reconcile.statements fdw_grants_sql
  (* #2469: The tenant scope of the MQL page reads work_manifests, which is not in the catalog. This
     is necessary only because the foreign data wrapper abstraction is leaky. *)
  @ [ "grant select (id, repo) on work_manifests to " ^ fdw_role ]

(* INSERT writes a GitLab group's installation and SELECT reads back its generated columns. The
   AFTER INSERT trigger on gitlab_installations is SECURITY INVOKER, so its insert into
   gitlab_installations_map runs as this role. INSERT and DELETE on github_app replace the App, the
   column UPDATE rotates its credentials, and the column SELECT never includes the PEM or the
   webhook secret. *)
let provisioner_grants =
  CCList.map
    (fun grant -> grant ^ " to " ^ provisioner_role)
    [
      "grant insert, select, update on gitlab_installations";
      "grant insert, select on gitlab_installations_map";
      "grant insert, delete on github_app";
      "grant update (pem, client_secret, webhook_secret, loaded_at) on github_app";
      "grant select (id, slug, client_id, client_secret, html_url, created_at, loaded_at) on \
       github_app";
    ]

module Sql = struct
  let select_database () =
    Pgsql_io.Typed_sql.(
      sql // Ret.integer /^ "select 1 from pg_database where datname = $name" /% Var.text "name")

  let select_role () =
    Pgsql_io.Typed_sql.(
      sql // Ret.integer /^ "select 1 from pg_roles where rolname = $name" /% Var.text "name")

  let execute db stmt =
    Pgsql_io.Prepared_stmt.execute db Pgsql_io.Typed_sql.(sql /^ Pgsql_io.clean_string stmt)

  (* The privileges lock, held until the end of the transaction; to support concurrent migrations *)
  let lock_privileges () =
    Pgsql_io.Typed_sql.(sql // Ret.boolean /^ "select pg_advisory_xact_lock(2721) is null")
end

(* A double-quoted identifier. *)
let sql_ident name = "\"" ^ CCString.replace ~which:`All ~sub:"\"" ~by:"\"\"" name ^ "\""

let connect config database =
  let open Abb.Future.Infix_monad in
  Abbs_fc.timeout
    ~timeout:(Abb.Sys.sleep (Terrat_config.db_connect_timeout config))
    (Pgsql_io.create
       ~tls_config:(`Prefer (Terrat_storage.tls_config ()))
       ~passwd:(Terrat_config.db_password config)
       ~port:(Terrat_config.db_port config)
       ~host:(Terrat_config.db_host config)
       ~user:(Terrat_config.db_user config)
       database)
  >>| function
  | `Ok conn -> conn
  | `Timeout -> Error (`Connect_timeout_err database)

let with_conn ~f db = Abbs_fc.with_finally (fun () -> f db) ~finally:(fun () -> Pgsql_io.destroy db)

let exists db stmt name =
  let open Abbs_fc.Infix_result_monad in
  Pgsql_io.Prepared_stmt.fetch db (stmt ()) ~f:CCFun.id name
  >>| function
  | [] -> `Absent
  | _ :: _ -> `Present

(* [create] lost a race when another process created the object in the meantime, which is a
   success. *)
let create_unless_present ~what ~create ~on_err db stmt name =
  let open Abbs_fc.Infix_result_monad in
  exists db stmt name
  >>= function
  | `Present -> Abbs_fc.return_ok ()
  | `Absent -> (
      let open Abb.Future.Infix_monad in
      Sql.execute db create
      >>= function
      | Ok () ->
          Logs.info (fun m -> m "Created the %s %s" what name);
          Abbs_fc.return_ok ()
      | Error (#Pgsql_io.err as err) -> (
          exists db stmt name
          >>= function
          | Ok `Present ->
              Logs.info (fun m -> m "The %s %s was created concurrently" what name);
              Abbs_fc.return_ok ()
          | Ok `Absent | Error _ -> Abbs_fc.return_err (on_err err)))

let ensure_database config =
  let open Abb.Future.Infix_monad in
  let database = Terrat_config.db config in
  let owner = Terrat_config.db_user config in
  connect config maintenance_db
  >>= function
  | Ok db ->
      with_conn db ~f:(fun db ->
          create_unless_present
            db
            Sql.select_database
            database
            ~what:"database"
            ~create:
              (Printf.sprintf "create database %s owner %s" (sql_ident database) (sql_ident owner))
            ~on_err:(fun err ->
              Logs.err (fun m ->
                  m
                    "Could not create the database %s. The role %s probably does not have the \
                     CREATEDB privilege, which is frequent on managed Postgres. Create the \
                     database manually, then restart: CREATE DATABASE %s OWNER %s;"
                    database
                    owner
                    (sql_ident database)
                    (sql_ident owner));
              `Create_database_err (database, err)))
  | Error err ->
      Logs.warn (fun m ->
          m
            "The maintenance database %s does not accept a connection (%a): no check that %s \
             exists. If it does not exist, create it, then restart: CREATE DATABASE %s OWNER %s;"
            maintenance_db
            pp_err
            err
            database
            (sql_ident database)
            (sql_ident owner));
      Abbs_fc.return_ok ()

let migrate config =
  let open Abbs_fc.Infix_result_monad in
  Abbs_fc.Result.map_err ~f:(fun err -> `Migration_err err) (Terrat_storage.try_create config)
  >>= fun storage ->
  Abbs_fc.with_finally
    (fun () -> Terrat_migrations.run config storage)
    ~finally:(fun () -> Pgsql_pool.destroy storage)

let reconcile_role ~role db grants =
  let open Abbs_fc.Infix_result_monad in
  create_unless_present
    db
    Sql.select_role
    role
    ~what:"role"
    ~create:(Printf.sprintf "create role %s nologin" role)
    ~on_err:(fun err ->
      Logs.err (fun m ->
          m
            "Could not create the role %s. The connecting role probably does not have the \
             CREATEROLE privilege, which is frequent on managed Postgres. Create the role \
             manually, then restart: CREATE ROLE %s NOLOGIN;"
            role
            role);
      `Create_role_err (role, err))
  >>= fun () ->
  Pgsql_io.tx db ~f:(fun () ->
      Pgsql_io.Prepared_stmt.fetch db (Sql.lock_privileges ()) ~f:CCFun.id
      >>= fun _ ->
      Abbs_fc.List_result.iter
        ~f:(Sql.execute db)
        ([
           "revoke all privileges on all tables in schema public from " ^ role;
           "grant usage on schema public to " ^ role;
         ]
        @ grants))
  >>| fun () -> Logs.info (fun m -> m "Reconciled the privileges of %s" role)

let run' () =
  let open Abbs_fc.Infix_result_monad in
  Abb.Future.return (CCResult.map_err (fun err -> `Config_err err) (Sgs_terrat_config.create ()))
  >>= fun terrat_config ->
  ensure_database terrat_config
  >>= fun () ->
  connect terrat_config (Terrat_config.db terrat_config)
  >>= fun db ->
  with_conn db ~f:(fun db ->
      migrate terrat_config
      >>= fun () ->
      Logs.info (fun m -> m "Migrated %s" (Terrat_config.db terrat_config));
      reconcile_role ~role:fdw_role db fdw_grants
      >>= fun () -> reconcile_role ~role:provisioner_role db provisioner_grants)

let run config =
  match Sgs_config.orchestration_enabled config with
  | true -> run' ()
  | false ->
      Logs.debug (fun m -> m "Orchestration disabled; skipping the terrateam database");
      Abbs_fc.return_ok ()
