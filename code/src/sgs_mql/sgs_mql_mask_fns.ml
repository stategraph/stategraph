let create_mql_mask_fns_sql = [%blob "./sql/create_mql_mask_fns.sql"]

(* A marker to every doing idempotent writes after the first one.  The marker's
   name carries the script's digest, thus an edit to the SQL leaves the old
   marker unmatched and the next call installs the new bodies. *)
let marker_fn =
  Printf.sprintf "sgs_mql_mask_fns_%s" (Digest.to_hex (Digest.string create_mql_mask_fns_sql))

module Sql = struct
  (* [to_regprocedure] answers NULL for a name it cannot resolve, including one qualified by a
     [pg_temp] the session has not created yet, so this is safe on a connection with no temp schema
     at all. *)
  let installed () =
    Pgsql_io.Typed_sql.(
      sql
      // Ret.boolean
      /^ "select to_regprocedure('pg_temp.' || $marker || '()') is not null"
      /% Var.text "marker")

  let create_marker () =
    Pgsql_io.Typed_sql.(
      sql
      /^ Printf.sprintf
           "create or replace function pg_temp.%s() returns boolean language sql immutable as $$ \
            select true $$"
           marker_fn)
end

let install db =
  let open Abbs_fc.Infix_result_monad in
  Pgsql_io.Prepared_stmt.fetch db (Sql.installed ()) ~f:CCFun.id marker_fn
  >>= function
  | true :: _ -> Abbs_fc.return_ok ()
  | false :: _ | [] ->
      Pgsql_io.execute_script db create_mql_mask_fns_sql
      >>= fun () -> Pgsql_io.Prepared_stmt.execute db (Sql.create_marker ())
