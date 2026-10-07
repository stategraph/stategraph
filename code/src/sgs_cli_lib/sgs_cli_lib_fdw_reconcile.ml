let src = Logs.Src.create "fdw_reconcile"

module Logs = (val Logs.src_log src : Logs.LOG)

type err =
  [ Pgsql_pool.err
  | Pgsql_io.err
  ]
[@@deriving show]

let fdw_tables_sql = [%blob "../sgs_terrateam_catalog/fdw_tables.sql"]
let fdw_admin_tables_sql = [%blob "sql/fdw_admin_tables.sql"]
let fdw_scope_tables_sql = [%blob "sql/fdw_scope_tables.sql"]

(* Single-quoted literal for FDW OPTIONS values (host, dbname, user,
   password). Values come from operator env, but quote correctly anyway. *)
let sql_literal v = "'" ^ CCString.replace ~which:`All ~sub:"'" ~by:"''" v ^ "'"

(* The generator emits one statement per [;\n]; comment lines ride along with
   the statement that follows them, which Postgres accepts. This is distinct
   from the migration runner's [;\n\n] convention because the drop+create
   pairs here are separated by single newlines. *)
let statements sql =
  sql
  |> CCString.split ~by:";\n"
  |> CCList.map CCString.trim
  |> CCList.filter (fun s -> not (CCString.is_empty s))

let preamble config =
  let opt = sql_literal in
  [
    "create extension if not exists postgres_fdw";
    (* CASCADE drops the user mapping and every foreign table, so the rebuild
       below converges on exactly config + catalog. All DDL is transactional:
       concurrent readers see the old bridge until commit. *)
    "drop server if exists terrateam_fdw cascade";
    (* use_remote_estimate costs each foreign path with a remote EXPLAIN. Without
       it the planner cannot tell a scoped remote join from a whole-table scan and
       runs the MQL page's scoping joins locally (#2469). fetch_size is the rows
       per remote FETCH. *)
    Printf.sprintf
      "create server terrateam_fdw foreign data wrapper postgres_fdw options (host %s, port %s, \
       dbname %s, use_remote_estimate 'true', fetch_size '1000')"
      (opt (Sgs_config.fdw_host config))
      (opt (CCInt.to_string (Sgs_config.fdw_port config)))
      (opt (Sgs_config.fdw_dbname config));
    Printf.sprintf
      "create user mapping for current_user server terrateam_fdw options (user %s, password %s)"
      (opt (Sgs_config.fdw_user config))
      (opt (CCOption.get_or ~default:"" (Sgs_config.fdw_password config)));
    "create schema if not exists terrateam";
  ]

(* Second, narrow write channel for provisioning. A separate server is required:
   one server carries a single user mapping for current_user, so the read-only
   role and the provisioner role cannot share [terrateam_fdw]. The read-back of
   the trigger-generated core_id must use THIS server (postgres_fdw opens one
   remote session per (server, mapping), so the admin insert and its map read
   share a remote transaction). Built only when the provisioner password is set. *)
let admin_preamble config password =
  let opt = sql_literal in
  [
    Printf.sprintf
      "create server terrateam_admin_fdw foreign data wrapper postgres_fdw options (host %s, port \
       %s, dbname %s)"
      (opt (Sgs_config.fdw_host config))
      (opt (CCInt.to_string (Sgs_config.fdw_port config)))
      (opt (Sgs_config.fdw_dbname config));
    Printf.sprintf
      "create user mapping for current_user server terrateam_admin_fdw options (user %s, password \
       %s)"
      (opt (Sgs_config.fdw_provisioner_user config))
      (opt password);
    "create schema if not exists terrateam_admin";
  ]

let run config storage =
  if not (Sgs_config.orchestration_enabled config) then (
    Logs.debug (fun m -> m "Orchestration disabled; skipping FDW reconcile");
    Abb.Future.return (Ok ()))
  else
    let open Abb.Future.Infix_monad in
    (* Always drop the admin server first so removing the provisioner password
       tears the whole admin bridge (server, mapping holding the old password,
       foreign tables) down — the create/mapping/tables are re-appended only
       when the password is set. *)
    let admin_stmts =
      "drop server if exists terrateam_admin_fdw cascade"
      :: (Sgs_config.fdw_provisioner_password config
         |> CCOption.map_or ~default:[] (fun password ->
             admin_preamble config password @ statements fdw_admin_tables_sql))
    in
    let stmts =
      preamble config
      @ statements fdw_tables_sql
      (* #2469: The tenant scope of the MQL page reads these tables. This is
         necessary only because the foreign data wrapper abstraction is leaky. *)
      @ statements fdw_scope_tables_sql
      @ admin_stmts
    in
    Pgsql_pool.with_conn storage ~f:(fun db ->
        Pgsql_io.tx db ~f:(fun () ->
            Abbs_fc.List_result.iter
              ~f:(fun stmt ->
                let stmt_sql = Pgsql_io.Typed_sql.(sql /^ Pgsql_io.clean_string stmt) in
                Pgsql_io.Prepared_stmt.execute db stmt_sql)
              stmts))
    >>| function
    | Ok () ->
        Logs.info (fun m ->
            m "FDW reconcile applied (%d statements, catalog foreign tables rebuilt)"
            @@ CCList.length stmts);
        Ok ()
    | Error (#err as err) -> Error err
