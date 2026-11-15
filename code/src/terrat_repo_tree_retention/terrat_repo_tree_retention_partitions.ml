(* The statements of the walk, as MQL trees.  The writers render names as identifiers and bounds
   as string literals -- see the .mli header. *)
let cache_day_range ~from_bound ~to_bound =
  Mql.Build.and_
    (Mql.Build.gte (Mql.Build.id "cache_day") (Mql.Build.string from_bound))
    (Mql.Build.lt (Mql.Build.id "cache_day") (Mql.Build.string to_bound))

let day_partition_name ~parent ~label = parent ^ "_d" ^ label
let lock_parent parent = Mql.Build.lock_table ~mode:Mql_ast.Lock_mode_exclusive parent

let stage_default_rows ~parent ~tmp ~from_bound ~to_bound =
  Mql.Build.create_temp_table_as
    ~on_commit_drop:true
    tmp
    (Mql.Build.select
       ~from:[ Mql.Build.table (parent ^ "_default") ]
       ~where:(cache_day_range ~from_bound ~to_bound)
       ~cols:Mql.Build.star
       ())

let delete_default_rows ~parent ~from_bound ~to_bound =
  Mql.Build.delete_where ~where:(cache_day_range ~from_bound ~to_bound) (parent ^ "_default")

let create_day_partition ?(if_not_exists = false) ~parent ~from_bound ~to_bound name =
  Mql.Build.create_table_partition_of
    ~if_not_exists
    ~parent
    ~bound:(Mql.Build.range_bound ~from:from_bound ~to_:to_bound)
    name

let insert_staged ~target ~tmp =
  Mql.Build.insert_select
    ~query:(Mql.Build.select ~from:[ Mql.Build.table tmp ] ~cols:Mql.Build.star ())
    target

let horizon_days_sql = Mql_sql.read [%blob "./sql/retention_horizon_days.sql"]

let horizon_days db =
  Pgsql_io.Prepared_stmt.fetch
    db
    Pgsql_io.Typed_sql.(
      sql
      //
      (* day_start *)
      Ret.text
      //
      (* day_end *)
      Ret.text
      //
      (* label *)
      Ret.text
      /^ horizon_days_sql)
    ~f:(fun day_start day_end label -> (day_start, day_end, label))

let exec db stmt = Pgsql_io.Prepared_stmt.execute db Pgsql_io.Typed_sql.(sql /^ stmt)

(* The [timezone] guard is a load-time value: it names no operator knob, and [Mql_sql.set] raises
   [Sql_err] on an illegal name, so binding it at load time fails the program at startup instead of
   mid-walk.  The [lock_timeout] value is the operator's [DB_LOCK_TIMEOUT], so it binds per call;
   its name is the constant [lock_timeout], the same legal identifier the load-time check would
   validate, and [exec_tree] answers a writer defect as [`Mql_err] rather than a raise. *)
let timezone_utc_sql = Mql_sql.set ~local:true ~name:"timezone" "UTC"

let lock_timeout_tree lock_timeout =
  Mql_ast.Set_stmt
    {
      local = true;
      name = { Mql_ast.qualifier = None; base = { Mql_ast.name = "lock_timeout"; quoted = false } };
      value = Mql_ast.String lock_timeout;
    }

let exec_tree db tree =
  match Mql_sql.write tree with
  | Ok stmt -> exec db stmt
  | Error (#Mql.Ast.err as err) -> Abbs_fc.return_err (`Mql_err err)

let set_transaction_guards db ~lock_timeout =
  let open Abbs_fc.Infix_result_monad in
  exec db timezone_utc_sql >>= fun () -> exec_tree db (lock_timeout_tree lock_timeout)

let ensure_horizon_partitions db ~parent =
  let open Abbs_fc.Infix_result_monad in
  horizon_days db
  >>= fun days ->
  CCList.fold_left
    (fun acc (day_start, day_end, label) ->
      acc
      >>= fun created ->
      exec_tree
        db
        (create_day_partition
           ~if_not_exists:true
           ~parent
           ~from_bound:day_start
           ~to_bound:day_end
           (day_partition_name ~parent ~label))
      >>= fun () -> Abbs_fc.return_ok (created + 1))
    (Abbs_fc.return_ok 0)
    days
