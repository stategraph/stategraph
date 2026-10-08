let default_limit = 20
let max_limit = 1000

module Sql = struct
  (* The terrateam CTE block only exists when orchestration is enabled: the
     foreign tables it selects from are created by the boot-time FDW
     reconcile, and a CTE over an absent relation would fail EVERY query at
     parse time, not just terrateam ones. *)
  let terrateam_ctes = ",\n" ^ [%blob "./sql/select_mql_page_terrateam_ctes.sql"]

  (* The page query per variant, exactly as sent modulo [{{q}}]. *)
  let select_page_sql ~orchestration =
    CCString.replace
      ~sub:"{{terrateam_ctes}}"
      ~by:(if orchestration then terrateam_ctes else "")
      [%blob "./sql/select_mql_page.sql"]

  let select_page ~orchestration q =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* row *)
      Ret.jsonb
      /^ CCString.replace ~sub:"{{q}}" ~by:q (select_page_sql ~orchestration)
      /% Var.(ud (uuid "user_id") Sgs_user.id)
      /% Var.(str_array (text "texts"))
      /% Var.(str_array (json "json"))
      /% Var.(array (smallint "smallints"))
      /% Var.(array (integer "integers"))
      /% Var.(array (bigint "bigints"))
      /% Var.(array (double "floats"))
      /% Var.(array (timestamptz "timestamptzs")))

  let set_timeout timeout =
    Pgsql_io.Typed_sql.(sql /^ Printf.sprintf "set local statement_timeout = '%s'" timeout)

  let set_timezone () = Pgsql_io.Typed_sql.(sql /^ "set local timezone = $tz" /% Var.text "tz")

  (* #2469: The row estimates for foreign tables are bad. Then the planner
     selects nested loops that send one remote query for each outer row. This
     is necessary only because the foreign data wrapper abstraction is leaky. *)
  let disable_nestloop () = Pgsql_io.Typed_sql.(sql /^ "set local enable_nestloop = off")
end

(* The MQL table allow-list.

   SECURITY -- two coupled lists: every table named here MUST also have a
   matching tenant-scoped CTE in [sql/select_mql_page.sql]. A query may only
   name tables that appear here; inside [select_mql_page.sql] each such name
   resolves to a CTE that is filtered to the caller's tenants. If a table is
   added here without a corresponding CTE, the name resolves to the REAL,
   UNSCOPED table -> cross-tenant data exposure. The test in
   [code/tests/sgs_mql] asserts this list stays a subset of the CTE names
   defined in [select_mql_page.sql] -- keep it green.

   SECURITY (secret masking) -- [instances.attributes], [instances.private],
   [outputs.value] and [transaction_logs.data] carry raw Terraform state, which
   can contain secrets. Before these columns leave the database the wrapper in
   [select_mql_page.sql] masks every value the state marks sensitive (replacing
   it with the sentinel ["__SENSITIVE__"]), using the [pg_temp.*] helpers
   installed by [Sgs_mql_mask_fns.install]. [instances.sensitive_attributes] is
   left intact: it is metadata naming which paths were masked, not a secret. *)
let stategraph_tables =
  Mql_to_pgsql.Schema.
    [
      Table.make
        ~name:"tenants"
        Column.
          [
            make ~name:"id" ~type_:Type_.Uuid ();
            make ~name:"name" ~type_:Type_.Text ();
            make ~name:"created_at" ~type_:Type_.Timestamptz ();
          ];
      Table.make
        ~name:"users"
        Column.
          [
            make ~name:"id" ~type_:Type_.Uuid ();
            make ~name:"name" ~type_:Type_.Text ();
            make ~name:"type" ~type_:Type_.Text ();
            make ~name:"created_at" ~type_:Type_.Timestamptz ();
          ];
      Table.make
        ~name:"states"
        Column.
          [
            make ~name:"id" ~type_:Type_.Uuid ();
            make ~name:"group_id" ~type_:Type_.Uuid ();
            make ~name:"workspace" ~type_:Type_.Text ();
            make ~name:"name" ~type_:Type_.Text ();
            make ~name:"tenant_id" ~type_:Type_.Uuid ();
            make ~name:"created_at" ~type_:Type_.Timestamptz ();
            make ~name:"updated_at" ~type_:Type_.Timestamptz ();
            make ~name:"deleted_at" ~type_:Type_.Timestamptz ();
            make ~name:"deleted_by" ~type_:Type_.Uuid ();
            make ~name:"schema_version" ~type_:Type_.Integer ();
          ];
      Table.make
        ~name:"providers"
        Column.
          [ make ~name:"name" ~type_:Type_.Text (); make ~name:"state_id" ~type_:Type_.Uuid () ];
      Table.make
        ~name:"resources"
        Column.
          [
            make ~name:"address" ~type_:Type_.Text ();
            make ~name:"fq_address" ~type_:Type_.Text ();
            make ~name:"mode" ~type_:Type_.Text ();
            make ~name:"module" ~type_:Type_.Text ();
            make ~name:"name" ~type_:Type_.Text ();
            make ~name:"provider" ~type_:Type_.Text ();
            make ~name:"state_id" ~type_:Type_.Uuid ();
            make ~name:"type" ~type_:Type_.Text ();
          ];
      Table.make
        ~name:"instances"
        Column.
          [
            make ~name:"address" ~type_:Type_.Text ();
            make ~name:"attributes" ~type_:Type_.Jsonb ();
            make ~name:"create_before_destroy" ~type_:Type_.Bool ();
            make ~name:"dependencies" ~type_:(Type_.Complex "text[]") ();
            make ~name:"deposed" ~type_:Type_.Text ();
            make ~name:"fq_address" ~type_:Type_.Text ();
            make ~name:"fq_resource_address" ~type_:Type_.Text ();
            make ~name:"identity" ~type_:Type_.Jsonb ();
            make ~name:"identity_schema_version" ~type_:Type_.Integer ();
            make ~name:"index_key" ~type_:Type_.Jsonb ();
            make ~name:"private" ~type_:Type_.Text ();
            make ~name:"resource_address" ~type_:Type_.Text ();
            make ~name:"schema_version" ~type_:Type_.Integer ();
            make ~name:"sensitive_attributes" ~type_:Type_.Jsonb ();
            make ~name:"state_id" ~type_:Type_.Uuid ();
            make ~name:"status" ~type_:Type_.Text ();
          ];
      Table.make
        ~name:"outputs"
        Column.
          [
            make ~name:"address" ~type_:Type_.Text ();
            make ~name:"name" ~type_:Type_.Text ();
            make ~name:"sensitive" ~type_:Type_.Bool ();
            make ~name:"state_id" ~type_:Type_.Uuid ();
            make ~name:"type" ~type_:Type_.Jsonb ();
            make ~name:"value" ~type_:Type_.Jsonb ();
          ];
      Table.make
        ~name:"check_results"
        Column.
          [
            make ~name:"config_addr" ~type_:Type_.Text ();
            make ~name:"object_kind" ~type_:Type_.Text ();
            make ~name:"state_id" ~type_:Type_.Uuid ();
            make ~name:"status" ~type_:Type_.Text ();
          ];
      Table.make
        ~name:"check_entries"
        Column.
          [
            make ~name:"config_addr" ~type_:Type_.Text ();
            make ~name:"failure_messages" ~type_:(Type_.Complex "text[]") ();
            make ~name:"object_addr" ~type_:Type_.Text ();
            make ~name:"state_id" ~type_:Type_.Uuid ();
            make ~name:"status" ~type_:Type_.Text ();
          ];
      Table.make
        ~name:"transactions"
        Column.
          [
            make ~name:"completed_at" ~type_:Type_.Timestamptz ();
            make ~name:"completed_by" ~type_:Type_.Uuid ();
            make ~name:"created_at" ~type_:Type_.Timestamptz ();
            make ~name:"created_by" ~type_:Type_.Uuid ();
            make ~name:"id" ~type_:Type_.Uuid ();
            make ~name:"state" ~type_:Type_.Text ();
            make ~name:"tags" ~type_:Type_.Jsonb ();
            make ~name:"params" ~type_:Type_.Jsonb ();
            make ~name:"tenant_id" ~type_:Type_.Uuid ();
          ];
      Table.make
        ~name:"transaction_logs"
        Column.
          [
            make ~name:"action" ~type_:Type_.Text ();
            make ~name:"created_at" ~type_:Type_.Timestamptz ();
            make ~name:"data" ~type_:Type_.Jsonb ();
            make ~name:"id" ~type_:Type_.Uuid ();
            make ~name:"object_type" ~type_:Type_.Text ();
            make ~name:"state_id" ~type_:Type_.Uuid ();
            make ~name:"tx_id" ~type_:Type_.Uuid ();
            make ~name:"user_id" ~type_:Type_.Uuid ();
          ];
      Table.make
        ~name:"hcl"
        Column.
          [
            make ~name:"fq_address" ~type_:Type_.Text ();
            make ~name:"created_at" ~type_:Type_.Timestamptz ();
            make ~name:"data" ~type_:Type_.Jsonb ();
            make ~name:"file_refs" ~type_:Type_.Jsonb ();
            make ~name:"hints" ~type_:Type_.Jsonb ();
            make ~name:"id" ~type_:Type_.Text ();
            make ~name:"module_address" ~type_:Type_.Text ();
            make ~name:"module_source" ~type_:Type_.Text ();
            make ~name:"path_attrs" ~type_:Type_.Jsonb ();
            make ~name:"refs" ~type_:(Type_.Complex "text[]") ();
            make ~name:"state_id" ~type_:Type_.Uuid ();
            make ~name:"updated_at" ~type_:Type_.Timestamptz ();
          ];
      Table.make
        ~name:"hcl_refs"
        Column.
          [
            make ~name:"state_id" ~type_:Type_.Uuid ();
            make ~name:"id" ~type_:Type_.Text ();
            make ~name:"ref" ~type_:Type_.Text ();
            make ~name:"attr_path" ~type_:(Type_.Complex "text[]") ();
            make ~name:"index_kind" ~type_:Type_.Text ();
            make ~name:"index_val" ~type_:Type_.Jsonb ();
            make ~name:"is_bare" ~type_:Type_.Bool ();
            make ~name:"resolvable" ~type_:Type_.Bool ();
            make ~name:"from_depends_on" ~type_:Type_.Bool ();
          ];
      Table.make
        ~name:"tf_modules"
        Column.
          [
            make ~name:"state_id" ~type_:Type_.Uuid ();
            make ~name:"source" ~type_:Type_.Text ();
            make ~name:"version" ~type_:Type_.Text ();
            make ~name:"created_at" ~type_:Type_.Timestamptz ();
          ];
      Table.make
        ~name:"tf_module_hcl"
        Column.
          [
            make ~name:"state_id" ~type_:Type_.Uuid ();
            make ~name:"source" ~type_:Type_.Text ();
            make ~name:"version" ~type_:Type_.Text ();
            make ~name:"id" ~type_:Type_.Text ();
            make ~name:"fq_address" ~type_:Type_.Text ();
            make ~name:"data" ~type_:Type_.Jsonb ();
            make ~name:"refs" ~type_:(Type_.Complex "text[]") ();
            make ~name:"path_attrs" ~type_:Type_.Jsonb ();
            make ~name:"created_at" ~type_:Type_.Timestamptz ();
            make ~name:"updated_at" ~type_:Type_.Timestamptz ();
          ];
      Table.make
        ~name:"tf_module_hcl_refs"
        Column.
          [
            make ~name:"state_id" ~type_:Type_.Uuid ();
            make ~name:"source" ~type_:Type_.Text ();
            make ~name:"version" ~type_:Type_.Text ();
            make ~name:"id" ~type_:Type_.Text ();
            make ~name:"ref" ~type_:Type_.Text ();
            make ~name:"attr_path" ~type_:(Type_.Complex "text[]") ();
            make ~name:"index_kind" ~type_:Type_.Text ();
            make ~name:"index_val" ~type_:Type_.Jsonb ();
            make ~name:"is_bare" ~type_:Type_.Bool ();
            make ~name:"resolvable" ~type_:Type_.Bool ();
            make ~name:"from_depends_on" ~type_:Type_.Bool ();
          ];
      Table.make
        ~name:"files"
        Column.
          [
            make ~name:"state_id" ~type_:Type_.Uuid ();
            make ~name:"filepath" ~type_:Type_.Text ();
            make ~name:"content_hash" ~type_:Type_.Text ();
            make ~name:"mode" ~type_:Type_.Integer ();
            make ~name:"template_vars" ~type_:(Type_.Complex "text[]") ();
            make ~name:"module_address" ~type_:Type_.Text ();
            make ~name:"id" ~type_:Type_.Text ();
          ];
      Table.make
        ~name:"tfvars"
        Column.
          [
            make ~name:"state_id" ~type_:Type_.Uuid ();
            make ~name:"id" ~type_:Type_.Text ();
            make ~name:"var_address" ~type_:Type_.Text ();
            make ~name:"file" ~type_:Type_.Text ();
            make ~name:"data" ~type_:Type_.Jsonb ();
          ];
      Table.make
        ~name:"transaction_subgraphs"
        Column.
          [
            make ~name:"tx_id" ~type_:Type_.Uuid ();
            make ~name:"state_id" ~type_:Type_.Uuid ();
            make ~name:"node_type" ~type_:Type_.Text ();
            make ~name:"direction" ~type_:Type_.Text ();
            make ~name:"depth" ~type_:Type_.Integer ();
            make ~name:"item" ~type_:Type_.Jsonb ();
          ];
      (* The stored chunk rows of a transaction's apply output. *)
      Table.make
        ~name:"transaction_output_chunks"
        Column.
          [
            make ~name:"tx_id" ~type_:Type_.Uuid ();
            make ~name:"idx" ~type_:Type_.Integer ();
            make ~name:"data" ~type_:Type_.Jsonb ();
            make ~name:"payload" ~type_:Type_.Text ();
          ];
      (* Per-resource plan operations of a transaction. *)
      Table.make
        ~name:"transaction_plan_operations"
        Column.
          [
            make ~name:"tx_id" ~type_:Type_.Uuid ();
            make ~name:"address" ~type_:Type_.Text ();
            make ~name:"operation" ~type_:Type_.Text ();
          ];
      Table.make
        ~name:"revision_hashes"
        Column.
          [
            make ~name:"created_at" ~type_:Type_.Timestamptz ();
            make ~name:"hash" ~type_:Type_.Text ();
            make ~name:"key" ~type_:Type_.Text ();
            make ~name:"state_id" ~type_:Type_.Uuid ();
            make ~name:"tx_id" ~type_:Type_.Uuid ();
            make ~name:"user_id" ~type_:Type_.Uuid ();
          ];
      Table.make
        ~name:"revision_tx_hashes"
        Column.
          [
            make ~name:"created_at" ~type_:Type_.Timestamptz ();
            make ~name:"hash" ~type_:Type_.Text ();
            make ~name:"key" ~type_:Type_.Text ();
            make ~name:"state_id" ~type_:Type_.Uuid ();
            make ~name:"tx_id" ~type_:Type_.Uuid ();
            make ~name:"user_id" ~type_:Type_.Uuid ();
          ];
      Table.make
        ~name:"cost_snapshots"
        Column.
          [
            make ~name:"id" ~type_:Type_.Uuid ();
            make ~name:"state_id" ~type_:Type_.Uuid ();
            make ~name:"tenant_id" ~type_:Type_.Uuid ();
            make ~name:"tx_id" ~type_:Type_.Uuid ();
            make ~name:"calculated_at" ~type_:Type_.Timestamptz ();
            make ~name:"kind" ~type_:Type_.Text ();
            make ~name:"source" ~type_:Type_.Text ();
            make ~name:"triggered_by" ~type_:Type_.Text ();
            make ~name:"currency" ~type_:Type_.Text ();
            (* Money columns are projected as text so precision survives the
                 JSON wire (numeric -> JSON number loses precision in clients
                 that coerce to float). Matches the cost read API. *)
            make ~name:"monthly_cost" ~type_:Type_.Text ();
            make ~name:"hourly_cost" ~type_:Type_.Text ();
            make ~name:"resource_count" ~type_:Type_.Integer ();
            make ~name:"supported_count" ~type_:Type_.Integer ();
            make ~name:"priced_count" ~type_:Type_.Integer ();
            make ~name:"pricing_service_version" ~type_:Type_.Text ();
          ];
      Table.make
        ~name:"cost_snapshot_resources"
        Column.
          [
            make ~name:"snapshot_id" ~type_:Type_.Uuid ();
            make ~name:"address" ~type_:Type_.Text ();
            make ~name:"type" ~type_:Type_.Text ();
            make ~name:"provider" ~type_:Type_.Text ();
            make ~name:"region" ~type_:Type_.Text ();
            make ~name:"supported" ~type_:Type_.Bool ();
            make ~name:"no_price" ~type_:Type_.Bool ();
            make ~name:"monthly_cost" ~type_:Type_.Text ();
            make ~name:"hourly_cost" ~type_:Type_.Text ();
            make ~name:"components" ~type_:Type_.Jsonb ();
            make ~name:"tags" ~type_:Type_.Jsonb ();
            make ~name:"cloud_resource_id" ~type_:Type_.Text ();
          ];
      Table.make
        ~name:"security_scans"
        Column.
          [
            make ~name:"id" ~type_:Type_.Uuid ();
            make ~name:"state_id" ~type_:Type_.Uuid ();
            make ~name:"tenant_id" ~type_:Type_.Uuid ();
            make ~name:"tx_id" ~type_:Type_.Uuid ();
            make ~name:"scanned_at" ~type_:Type_.Timestamptz ();
            make ~name:"kind" ~type_:Type_.Text ();
            make ~name:"triggered_by" ~type_:Type_.Text ();
            make ~name:"scanner" ~type_:Type_.Text ();
            make ~name:"scanner_version" ~type_:Type_.Text ();
            make ~name:"status" ~type_:Type_.Text ();
            make ~name:"finding_count" ~type_:Type_.Integer ();
            make ~name:"severity_breakdown" ~type_:Type_.Jsonb ();
            make ~name:"error_message" ~type_:Type_.Text ();
          ];
      Table.make
        ~name:"security_scan_findings"
        Column.
          [
            make ~name:"scan_id" ~type_:Type_.Uuid ();
            make ~name:"fingerprint" ~type_:Type_.Text ();
            make ~name:"check_id" ~type_:Type_.Text ();
            make ~name:"resource_fq_address" ~type_:Type_.Text ();
            make ~name:"state_id" ~type_:Type_.Uuid ();
            make ~name:"source_file" ~type_:Type_.Text ();
            make ~name:"source_start_line" ~type_:Type_.Integer ();
            make ~name:"source_end_line" ~type_:Type_.Integer ();
            make ~name:"severity_base" ~type_:Type_.Text ();
            make ~name:"severity_effective" ~type_:Type_.Text ();
            make ~name:"severity_reason" ~type_:Type_.Text ();
            make ~name:"blast_radius_resource_count" ~type_:Type_.Integer ();
            make ~name:"blast_radius_modules" ~type_:(Type_.Complex "text[]") ();
            make ~name:"is_internet_reachable" ~type_:Type_.Bool ();
            make ~name:"internet_reachability_evidence" ~type_:Type_.Jsonb ();
            make ~name:"cross_state_refs" ~type_:(Type_.Complex "uuid[]") ();
            make ~name:"workspace" ~type_:Type_.Text ();
            make ~name:"first_seen_scan_id" ~type_:Type_.Uuid ();
            make ~name:"resolved_scan_id" ~type_:Type_.Uuid ();
          ];
      (* Per-tenant FOCUS billing sources (config rows). No secret/credential
           columns exist on this table — credentials resolve ambiently via
           DuckDB's credential_chain — so every column is exposed unmasked. The
           matching tenant-scoped CTE lives in select_mql_page.sql. *)
      Table.make
        ~name:"focus_billing_sources"
        Column.
          [
            make ~name:"id" ~type_:Type_.Uuid ();
            make ~name:"tenant_id" ~type_:Type_.Uuid ();
            make ~name:"provider" ~type_:Type_.Text ();
            make ~name:"source_uri" ~type_:Type_.Text ();
            make ~name:"region" ~type_:Type_.Text ();
            make ~name:"window_months" ~type_:Type_.Integer ();
            make ~name:"enabled" ~type_:Type_.Bool ();
            make ~name:"last_status" ~type_:Type_.Text ();
            make ~name:"last_error" ~type_:Type_.Text ();
            make ~name:"last_synced_at" ~type_:Type_.Timestamptz ();
            make ~name:"last_row_count" ~type_:Type_.Integer ();
            make ~name:"created_at" ~type_:Type_.Timestamptz ();
            make ~name:"updated_at" ~type_:Type_.Timestamptz ();
          ];
    ]

let schema = Mql_to_pgsql.Schema.make stategraph_tables

let schema_orchestration =
  Mql_to_pgsql.Schema.make (stategraph_tables @ Sgs_terrateam_catalog.tables)

let schema_for config =
  if Sgs_config.orchestration_enabled config then schema_orchestration else schema

let terrateam_table_names = CCList.map Mql_to_pgsql.Schema.Table.name Sgs_terrateam_catalog.tables

(* #2469: A query reads a foreign table only through a terrateam CTE. Only
   such a query gets [Sql.disable_nestloop]. This is necessary only because the
   foreign data wrapper abstraction is leaky. *)
let reads_foreign_tables config query =
  Sgs_config.orchestration_enabled config
  && CCList.exists
       (fun t -> CCList.mem ~eq:CCString.equal t terrateam_table_names)
       (Mql_to_pgsql.tables query)

let encode_link rel uri = Printf.sprintf "<%s>; rel=\"%s\"" (Uri.to_string uri) rel

let update_page_param uri cursor =
  uri
  |> CCFun.flip Uri.remove_query_param "page"
  |> fun uri -> Uri.add_query_param' uri ("page", cursor)

let mk_pagination_headers ~prev ~next ctx =
  let merged_uri_base = Brtl_uri.merge_base ~base:(Brtl_ctx.uri_base ctx) (Brtl_ctx.uri ctx) in
  let next_uri = CCOption.map (update_page_param merged_uri_base) next in
  let prev_uri = CCOption.map (update_page_param merged_uri_base) prev in
  let link =
    CCString.concat
      ", "
      (CCOption.to_list (CCOption.map (encode_link "next") next_uri)
      @ CCOption.to_list (CCOption.map (encode_link "prev") prev_uri))
  in
  let headers = Cohttp.Header.of_list [ ("link", link) ] in
  headers

(* Apply the requested page (if any) to an MQL AST and compile to pgsql.
   Returns the compiled query plus the effective row limit.

   One row more than [limit] is fetched so the extra ("sentinel") row reveals a
   further page. With a cursor the keyset predicate re-selects the cursor row
   itself (its last ORDER BY column is inclusive, see [Mql_to_pgsql.lex_keyset])
   for [trim_rows] to drop, so one more row again is fetched to keep room for the
   sentinel. *)
let build_query_ast config ast page =
  let open Abbs_fc.Infix_result_monad in
  Abb.Future.return
  @@ CCOption.map_or ~default:(Ok ast) (fun page -> Mql_to_pgsql.apply_page page ast) page
  >>= fun ast ->
  (* A query that names no LIMIT of its own falls back to [default_limit]; record
     that so callers can tell a server-default cap from the caller's own LIMIT. *)
  let limit_defaulted = CCOption.is_none (Mql.Ast.limit ast) in
  let limit = CCInt.min max_limit @@ CCOption.get_or ~default:default_limit @@ Mql.Ast.limit ast in
  let fetch_limit = limit + 1 + if CCOption.is_some page then 1 else 0 in
  Abb.Future.return
  @@ Mql_to_pgsql.of_mql ~max_limit:fetch_limit ~schema:(schema_for config)
  @@ Mql.Ast.set_limit fetch_limit ast
  >>| fun query -> (query, limit, limit_defaulted)

(* Execute the compiled query inside a transaction, applying the configured
   statement timeout and, when provided, the caller's timezone. Returns the
   raw rows fetched from the database. *)
let execute_query config storage user tz query =
  let open Abbs_fc.Infix_result_monad in
  Pgsql_pool.with_conn storage ~f:(fun db ->
      Pgsql_io.tx db ~f:(fun () ->
          Pgsql_io.Prepared_stmt.execute db (Sql.set_timeout (Sgs_config.statement_timeout config))
          >>= fun () ->
          Abbs_fc.List_result.iter
            ~f:(fun tz -> Pgsql_io.Prepared_stmt.execute db (Sql.set_timezone ()) tz)
            (CCOption.to_list tz)
          >>= fun () ->
          (if reads_foreign_tables config query then
             Pgsql_io.Prepared_stmt.execute db (Sql.disable_nestloop ())
           else Abb.Future.return (Ok ()))
          >>= fun () ->
          (* The scoped CTEs in [select_mql_page.sql] call [pg_temp.*] helpers to
             mask sensitive values; install them on this connection first. *)
          Sgs_mql_mask_fns.install db
          >>= fun () ->
          Pgsql_io.Prepared_stmt.fetch
            db
            (Sql.select_page
               ~orchestration:(Sgs_config.orchestration_enabled config)
               (Mql.Ast.to_string @@ Mql_to_pgsql.query query))
            ~f:CCFun.id
            user
            (CCVector.to_list @@ Mql_to_pgsql.texts query)
            (List.map Yojson.Safe.from_string (CCVector.to_list @@ Mql_to_pgsql.json query))
            (CCVector.to_list @@ Mql_to_pgsql.smallints query)
            (CCVector.to_list @@ Mql_to_pgsql.integers query)
            (CCVector.to_list @@ Mql_to_pgsql.bigints query)
            (CCVector.to_list @@ Mql_to_pgsql.floats query)
            (CCVector.to_list @@ Mql_to_pgsql.timestamptzs query)))

(* The rows come back with the cursor row first when a page was applied (the
   keyset re-selects it) and, when a further page exists, the sentinel row last
   (see [build_query_ast]). Drop the cursor row, decide on what is left whether
   there is a further page in the direction of travel ([excessive_rows]), drop
   the sentinel, and restore natural order when paging backwards. *)
let trim_rows ~limit ~page rows =
  let rows = if CCOption.is_some page then CCList.drop 1 rows else rows in
  let excessive_rows = CCList.length rows > limit in
  let rows = CCList.take limit rows in
  let rows =
    match page with
    | Some { Mql_to_pgsql.Page.dir = Mql_to_pgsql.Page.Negate; cursor = _ } -> CCList.rev rows
    | Some { Mql_to_pgsql.Page.dir = Mql_to_pgsql.Page.Affirm; cursor = _ } | None -> rows
  in
  (rows, excessive_rows)

(* Work out which pagination links, if any, accompany the trimmed [rows].
   [excessive_rows] means the query saw the sentinel extra row, i.e. there is a
   further page in the direction of travel. *)
let decide_pagination ~excessive_rows ~page rows query =
  let module Ps = Mql_to_pgsql.Pages in
  let module P = Mql_to_pgsql.Page in
  let cursor p = Some (Yojson.Safe.to_string @@ P.to_yojson p) in
  match Mql_to_pgsql.pages rows query with
  | Ok (Some { Ps.prev; next }) -> (
      match (excessive_rows, page) with
      | true, Some { P.dir = P.Affirm; _ } | true, Some { P.dir = P.Negate; _ } ->
          (* Extra rows: regardless of direction, both links exist. *)
          `Paginate (cursor prev, cursor next)
      | true, None ->
          (* Extra rows but no page given: we are at the beginning, so only the
             next link exists. *)
          `Paginate (None, cursor next)
      | false, None ->
          (* No extra rows and no page: all rows fit in a single page. *)
          `No_paginate
      | false, Some { P.dir = P.Affirm; _ } ->
          (* No extra rows going forward: we are on the last page. *)
          `Paginate (cursor prev, None)
      | false, Some { P.dir = P.Negate; _ } ->
          (* No extra rows going backward: we are on the first page. *)
          `Paginate (None, cursor next))
  | Ok None -> if excessive_rows then `Missing_order_by else `No_paginate
  | Error err -> (
      if not excessive_rows then
        (* The query cannot be paginated, but it all fits in one page anyway. *)
        `No_paginate
      else
        match err with
        | `Column_not_in_row_err col -> `Paginate_err ("COLUMN_NOT_IN_ROW " ^ col)
        | `Order_by_col_not_identifier_err e ->
            `Paginate_err ("ORDER_BY_COL_NOT_IDENTIFIER " ^ Mql.Ast.expr_to_string e))

type pagination_decision =
  [ `Paginate of string option * string option
  | `Paginate_err of string
  | `Missing_order_by
  | `No_paginate
  ]
[@@deriving show]

type page = {
  pagination : pagination_decision;
  rows : Yojson.Safe.t list;
  limit : int;
  default_limit_applied : bool;
}
[@@deriving show]

type query_err =
  [ Mql_to_pgsql.apply_page_err
  | Mql_to_pgsql.of_mql_err
  | Pgsql_io.err
  | Pgsql_pool.err
  ]
[@@deriving show]

(* Run an MQL query end to end: build the query, execute it, trim the result
   set, and decide its pagination links. Also returns the effective [limit] so
   callers can surface it on their typed response shape. *)
let query ?tz ?page config storage user ast =
  let open Abbs_fc.Infix_result_monad in
  build_query_ast config ast page
  >>= fun (query, limit, limit_defaulted) ->
  execute_query config storage user tz query
  >>| fun rows ->
  let rows, excessive_rows = trim_rows ~limit ~page rows in
  (* The result was capped by the server default (not the caller's LIMIT) iff the
     query carried no LIMIT and more rows than the default existed. *)
  let default_limit_applied = limit_defaulted && excessive_rows in
  {
    pagination = decide_pagination ~excessive_rows ~page rows query;
    rows;
    limit;
    default_limit_applied;
  }

let parse_page_param raw =
  match raw with
  | None -> None
  | Some s -> (
      match Yojson.Safe.from_string s with
      | exception Yojson.Json_error _ -> None
      | json -> (
          match Mql_to_pgsql.Page.of_yojson json with
          | Ok p -> Some p
          | Error _ -> None))

let with_limit ?default limit ast =
  match (limit, default) with
  | Some n, _ when n > 0 -> Mql.Ast.set_limit n ast
  | (Some _ | None), Some default -> Mql.Ast.set_limit default ast
  | (Some _ | None), None -> ast

let bad_request ~id ~data ctx =
  let module Br = Sgs_api_components.Bad_request_err in
  Brtl_ctx.set_response
    (Brtl_rspnc.create ~status:`Bad_request (Yojson.Safe.to_string (Br.to_yojson { Br.id; data })))
    ctx

(* Decode every row, short-circuiting on the first failure so the offending row
   travels with the [of_yojson] message: a decode failure means the AST's column
   list has drifted from the API schema -- a server-side bug -- so the whole
   request fails rather than returning partial / empty-shelled data. *)
let decode_all decode rows =
  CCResult.map_l (fun row -> CCResult.map_err (fun msg -> (msg, row)) (decode row)) rows

let respond ~src ~tag ~decode_row ~body ~page config storage user ast ctx =
  let token = Brtl_ctx.token ctx in
  let label suffix = tag ^ "_" ^ suffix in
  let respond_500 suffix pp err =
    Logs.err ~src (fun m -> m "%s : %s : %a" token (label suffix) pp err);
    Sgs_eplib.respond_internal_error ctx
  in
  let open Abb.Future.Infix_monad in
  query ?page:(parse_page_param page) config storage user ast
  >>| function
  | Ok { pagination; rows; limit; default_limit_applied = _ } -> (
      match decode_all decode_row rows with
      | Ok rows ->
          let headers =
            match pagination with
            | `Paginate (prev, next) -> Some (mk_pagination_headers ~prev ~next ctx)
            | `No_paginate -> None
            | (`Paginate_err _ | `Missing_order_by) as decision ->
                (* The AST is ours, so a page that cannot be chained is a defect
                   -- and one whose symptom is a page cut at [limit] that looks
                   complete. Say so, rather than serving it silently. *)
                Logs.err ~src (fun m ->
                    m "%s : %s : %a" token (label "PAGINATION_ERR") pp_pagination_decision decision);
                None
          in
          Brtl_ctx.set_response
            (Brtl_rspnc.create ?headers ~status:`OK (Yojson.Safe.to_string (body ~rows ~limit)))
            ctx
      | Error (msg, bad_row) ->
          Logs.err ~src (fun m ->
              m
                "%s : %s : row=%s : %s"
                token
                (label "DECODE_ERR")
                (Yojson.Safe.to_string bad_row)
                msg);
          Sgs_eplib.respond_internal_error ctx)
  | Error (#Mql_to_pgsql.apply_page_err as err) ->
      Logs.warn ~src (fun m ->
          m "%s : %s : %a" token (label "APPLY_PAGE_ERR") Mql_to_pgsql.pp_apply_page_err err);
      bad_request ~id:"APPLY_PAGE_ERR" ~data:(Some (Mql_to_pgsql.show_apply_page_err err)) ctx
  | Error (#Mql_to_pgsql.of_mql_err as err) ->
      respond_500 "OF_MQL_ERR" Mql_to_pgsql.pp_of_mql_err err
  | Error `Statement_timeout ->
      Logs.warn ~src (fun m -> m "%s : %s" token (label "TIMEOUT"));
      bad_request ~id:"TIMEOUT_ERR" ~data:None ctx
  | Error (#Pgsql_io.err as err) -> respond_500 "DB_ERR" Pgsql_io.pp_err err
  | Error (#Pgsql_pool.err as err) -> respond_500 "POOL_ERR" Pgsql_pool.pp_err err

module Tests = struct
  let select_page_sql = Sql.select_page_sql
end
