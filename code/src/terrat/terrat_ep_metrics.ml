let src = Logs.Src.create "ep_metrics"

module Logs = (val Logs.src_log src : Logs.LOG)

module Metrics = struct
  (* The repo tree partition gauges are process-wide maintenance metrics, not endpoint metrics:
     they carry the namespace only, like the shared families of [terrat_metrics.ml], not the
     endpoint subsystem of [terrat_ep_health_check.ml].  The registry memoises the children and
     fails a second registration, so the families are built once here and never per scrape. *)
  let partitions =
    let help = "Number of partitions of the repo tree tables" in
    Prmths.Gauge.v_label ~label_name:"table" ~help ~namespace:"terrat" "repo_tree_partitions"

  let partitions_bytes =
    let help = "Total disk size in bytes of the repo tree table partitions" in
    Prmths.Gauge.v_label ~label_name:"table" ~help ~namespace:"terrat" "repo_tree_partitions_bytes"

  (* The default partition of each repo tree table, as its own gauge: the count and the total
     above are flat in a stalled retention walk, and the [_default] size is what grows while the
     walk is stalled.  The [_default] names are static, so the label set never grows. *)
  let default_partitions_bytes =
    let help = "Total disk size in bytes of the default partition of each repo tree table" in
    Prmths.Gauge.v_label
      ~label_name:"table"
      ~help
      ~namespace:"terrat"
      "repo_tree_default_partitions_bytes"

  (* The catalog scan's failures, beside the gauges: a scan that answers an error or outlives its
     budget leaves the gauges at their previous values, and the counter is what tells the two
     apart from a fresh scan. *)
  let pgsql_errors_total = Terrat_metrics.errors_total ~m:"ep_metrics" ~t:"pgsql"
  let timeout_errors_total = Terrat_metrics.errors_total ~m:"ep_metrics" ~t:"timeout"
end

module Sql = struct
  let select_partition_metrics_sql = Mql_sql.read [%blob "sql/select_partition_metrics.sql"]

  let select_partition_metrics () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* table_name *)
      Ret.text
      //
      (* partitions *)
      Ret.bigint
      //
      (* total_size *)
      Ret.bigint
      //
      (* default_size *)
      Ret.bigint
      /^ select_partition_metrics_sql)
end

let known_tables = [ "repo_trees"; "repo_tree_builds" ]
let known_default_tables = CCList.map (fun table -> table ^ "_default") known_tables

(* The refresh shares the pool with every endpoint, and a pool with no idle connection answers a
   new request only when another request returns one -- unbounded.  A scrape that waits that long
   outlives the scraper's own timeout, which marks the target down and hides the gauges exactly
   when the catalog is the problem.  Five seconds, the health check's ping budget: a scan that
   cannot finish in one is a degraded catalog, and the previous gauge values are the honest
   answer. *)
let refresh_timeout = Duration.to_f (Duration.of_sec 5)

(* Zero every known table so every gauge has a child from the first scrape, even when the
   catalog scan returns no row for it. *)
let zero () =
  CCList.iter
    (fun table ->
      Prmths.Gauge.set (Metrics.partitions table) 0.0;
      Prmths.Gauge.set (Metrics.partitions_bytes table) 0.0)
    known_tables;
  CCList.iter
    (fun table -> Prmths.Gauge.set (Metrics.default_partitions_bytes table) 0.0)
    known_default_tables

(* The refresh of the gauges, as a seam the partition-metrics suite can drive directly. *)
let refresh db =
  let open Abb.Future.Infix_monad in
  Pgsql_io.Prepared_stmt.fetch
    db
    (Sql.select_partition_metrics ())
    ~f:(fun table partitions total_size default_size ->
      (table, partitions, total_size, default_size))
  >>= function
  | Ok rows ->
      (* Zeroed only after a successful scan: on error the gauges keep their previous values. *)
      zero ();
      CCList.iter
        (fun (table, partitions, total_size, default_size) ->
          Prmths.Gauge.set (Metrics.partitions table) (Int64.to_float partitions);
          Prmths.Gauge.set (Metrics.partitions_bytes table) (Int64.to_float total_size);
          Prmths.Gauge.set
            (Metrics.default_partitions_bytes (table ^ "_default"))
            (Int64.to_float default_size))
        rows;
      Abb.Future.return (Ok ())
  | Error (#Pgsql_io.err as err) ->
      Prmths.Counter.inc_one Metrics.pgsql_errors_total;
      Logs.err (fun m -> m "METRICS : %a" Pgsql_io.pp_err err);
      Abb.Future.return (Error err)

let get storage =
  Brtl_ep.run ~content_type:"text/plain" ~f:(fun ctx ->
      let open Abb.Future.Infix_monad in
      Abbs_fc.timeout
        ~timeout:(Abb.Sys.sleep refresh_timeout)
        (Pgsql_pool.with_conn storage ~f:refresh)
      >>= (function
      | `Ok (Ok ()) -> Abb.Future.return ()
      | `Ok (Error `Pgsql_pool_error) ->
          (* [refresh] counts its own [Pgsql_io.err]; a pool refusal never reaches it, so this is
             the one failure the counter would otherwise miss. *)
          Prmths.Counter.inc_one Metrics.pgsql_errors_total;
          Abb.Future.return ()
      | `Ok (Error _) -> Abb.Future.return ()
      | `Timeout ->
          Prmths.Counter.inc_one Metrics.timeout_errors_total;
          Abb.Future.return ())
      >>= fun () ->
      (* The refresh degrades, never serves a 500: a failed, slow, or queued-out scan keeps the
         previous gauge values and the rest of the registry stays visible. *)
      let data = Prmths.CollectorRegistry.(collect default) in
      let body = Fmt.to_to_string Prmths.TextFormat_0_0_4.output data in
      Abb.Future.return (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`OK body) ctx))
