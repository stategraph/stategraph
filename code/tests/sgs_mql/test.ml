(* Cross-tenant data leak via coupling between the two MQL allow-lists.

   The MQL core enforces table access against [Sgs_mql_paged.schema], while
   tenant scoping is enforced by the per-table CTEs in
   [src/sgs_mql/sql/select_mql_page.sql]. These are two hand-maintained lists. If a
   table is added to the schema without a matching scoped CTE, that table name
   resolves -- inside the user-query CTE [q] -- to the REAL, unscoped table,
   leaking data across tenants.

   This test fails closed: every table in the schema must have a top-level CTE
   in [select_mql_page.sql]. (The reverse is allowed: helper CTEs such as
   [tenant_users] and [q] need not appear in the schema.) *)

let terrateam_ctes_sql = [%blob "select_mql_page_terrateam_ctes.sql"]

let is_ident c =
  Char.equal c '_' || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')

(* Top-level CTE names: lines of the form "<name> as (" or, when the planner
   hint is present, "<name> as not materialized (". *)
let cte_names sql =
  sql
  |> CCString.split_on_char '\n'
  |> CCList.filter_map (fun line ->
      let line = CCString.trim line in
      CCOption.flat_map
        (fun name ->
          (* A real CTE name is a bare identifier (no embedded whitespace). *)
          if CCString.exists Sln_string.is_whitespace name then None else Some name)
        (CCOption.or_lazy
           ~else_:(fun () -> CCString.chop_suffix ~suf:" as (" line)
           (CCString.chop_suffix ~suf:" as not materialized (" line)))

(* (name, body) pairs for the top-level CTEs of the terrateam fragment: a CTE
   header sits at column 0 ("<name> as (" or "<name> as not materialized (");
   its body is everything until the next header. *)
let cte_bodies sql =
  let header line =
    if CCString.prefix ~pre:" " line || CCString.prefix ~pre:"--" line then None
    else
      CCOption.or_lazy
        ~else_:(fun () -> CCString.chop_suffix ~suf:" as (" line)
        (CCString.chop_suffix ~suf:" as not materialized (" line)
  in
  let flush name buf acc =
    CCOption.map_or ~default:acc (fun n -> (n, CCString.concat "\n" (CCList.rev buf)) :: acc) name
  in
  let name, buf, acc =
    CCList.fold_left
      (fun (name, buf, acc) line ->
        match header line with
        | Some n -> (Some n, [], flush name buf acc)
        | None -> (name, line :: buf, acc))
      (None, [], [])
      (CCString.split_on_char '\n' sql)
  in
  CCList.rev (flush name buf acc)

(* Column names of one table in an MQL schema, via its JSON projection. *)
let columns_of_schema_table schema table =
  match Mql_to_pgsql.Schema.to_yojson schema with
  | `Assoc fields -> (
      match List.assoc_opt "tables" fields with
      | Some (`Assoc tables) -> (
          match List.assoc_opt table tables with
          | Some (`Assoc t) -> (
              match List.assoc_opt "columns" t with
              | Some (`Assoc columns) -> CCList.map fst columns
              | _ -> Oth.Assert.false_ ("no columns for table " ^ table))
          | _ -> Oth.Assert.false_ ("table missing from schema: " ^ table))
      | _ -> Oth.Assert.false_ "unexpected MQL schema json shape")
  | _ -> Oth.Assert.false_ "unexpected MQL schema json shape"

(* Table names from an MQL schema, read via its JSON projection. *)
let schema_tables schema =
  match Mql_to_pgsql.Schema.to_yojson schema with
  | `Assoc fields -> (
      match List.assoc_opt "tables" fields with
      | Some (`Assoc tables) -> CCList.map fst tables
      | _ -> Oth.Assert.false_ "unexpected MQL schema json shape")
  | _ -> Oth.Assert.false_ "unexpected MQL schema json shape"

(* The catalog-generated tables: what the orchestration variant adds. *)
let terrateam_tables =
  let base = schema_tables Sgs_mql_paged.schema in
  CCList.filter
    (fun t -> not (CCList.mem ~eq:CCString.equal t base))
    (schema_tables Sgs_mql_paged.schema_orchestration)

(* Table names of the [tables] object of a schema-endpoint body. *)
let advertised_tables body =
  let { Sgs_api_components.Mql_schema_response.tables; default_limit = _; max_limit = _ } =
    Sgs_api_components.Mql_schema_response.of_yojson body |> Oth.Assert.ok
  in
  Sgs_api_components.Mql_schema_response.Tables.additional tables

let test =
  Oth.parallel
    [
      Oth.test ~name:"MQL schema tables all have a tenant-scoped CTE (base variant)" (fun _ ->
          let ctes = cte_names (Sgs_mql_paged.Tests.select_page_sql ~orchestration:false) in
          let missing =
            CCList.filter
              (fun t -> not (CCList.mem ~eq:CCString.equal t ctes))
              (schema_tables Sgs_mql_paged.schema)
          in
          Oth.Assert.List.empty missing);
      Oth.test
        ~name:"MQL schema tables all have a tenant-scoped CTE (orchestration variant)"
        (fun _ ->
          let ctes = cte_names (Sgs_mql_paged.Tests.select_page_sql ~orchestration:true) in
          let missing =
            CCList.filter
              (fun t -> not (CCList.mem ~eq:CCString.equal t ctes))
              (schema_tables Sgs_mql_paged.schema_orchestration)
          in
          Oth.Assert.List.empty missing);
      (* Every terrateam (table, column) the orchestration schema advertises
         must be projected by its CTE: the foreign tables carry exactly the
         catalog columns, but a fragment that fell behind the catalog would
         500 at query time with no earlier signal. *)
      Oth.test ~name:"terrateam CTE projections cover the orchestration schema" (fun _ ->
          let bodies = cte_bodies terrateam_ctes_sql in
          let missing =
            CCList.flat_map
              (fun table ->
                match Sln_list.String.assoc_opt table bodies with
                | None -> [ table ^ ".<no CTE>" ]
                | Some body ->
                    columns_of_schema_table Sgs_mql_paged.schema_orchestration table
                    |> CCList.filter_map (fun col ->
                        let projected = " as " ^ col in
                        if CCString.mem ~sub:projected body then None else Some (table ^ "." ^ col)))
              terrateam_tables
          in
          Oth.Assert.List.empty missing);
      (* The reverse direction. The fragment is spliced into EVERY
         orchestration query and Postgres resolves each CTE's relations at
         parse time whether or not the user query touches them, so a single
         [terrateam.<x>] reference to a table the catalog no longer carries
         (its foreign table is dropped by the boot reconcile) fails all MQL at
         once. Pin the foreign-table references to exactly the catalog: one CTE
         per table, reading its own foreign table. The only other reference is
         work_manifests, the tenant scope of the work-manifest tables, from
         fdw_scope_tables.sql. #2469: This reference is necessary only
         because the foreign data wrapper abstraction is leaky. *)
      Oth.test ~name:"terrateam fragment reads exactly the catalog's foreign tables" (fun _ ->
          let referenced =
            CCString.split ~by:"terrateam." terrateam_ctes_sql
            |> CCList.drop 1
            |> CCList.map (CCString.take_while is_ident)
            |> Sln_list.String.sort_uniq
          in
          Oth.Assert.Eq.string_list
            ~expected:(CCList.sort CCString.compare ("work_manifests" :: terrateam_tables))
            ~actual:referenced);
      (* #1061: the schema endpoint body must conform to [mql-schema-response] and
         publish the endpoint's row-limit policy, so clients can discover the
         defaulting behaviour (and the [mql-default-limit-applied] header) rather
         than hard-coding the magic 20/1000. A successful [of_yojson] also proves
         the endpoint's [Tables.of_yojson] round-trip took the Ok path, not the
         legacy tables-only fallback that would silently drop the limits. *)
      Oth.test ~name:"MQL schema endpoint body advertises default_limit and max_limit" (fun _ ->
          let { Sgs_api_components.Mql_schema_response.default_limit; max_limit; tables } =
            Sgs_api_components.Mql_schema_response.of_yojson Sgs_mql_ep.Tests.response_json
            |> Oth.Assert.ok
          in
          Oth.Assert.Eq.int ~expected:20 ~actual:default_limit;
          Oth.Assert.Eq.int ~expected:1000 ~actual:max_limit;
          (* the table set survived the round-trip intact *)
          Oth.Assert.Eq.bool
            ~expected:true
            ~actual:
              (Sln_map.String.mem
                 "instances"
                 (Sgs_api_components.Mql_schema_response.Tables.additional tables)));
      (* [mql-schema-response] is additionalProperties:false, so pin the exact top
         level keys -- an accidental extra field would put the wire body out of
         contract with its own schema. *)
      Oth.test ~name:"MQL schema endpoint body has exactly the contract keys" (fun _ ->
          let keys =
            match Sgs_mql_ep.Tests.response_json with
            | `Assoc fields -> CCList.sort CCString.compare (CCList.map fst fields)
            | _ -> Oth.Assert.false_ "schema body is not a JSON object"
          in
          Oth.Assert.Eq.string_list
            ~expected:[ "default_limit"; "max_limit"; "tables" ]
            ~actual:keys);
      (* [Schema.run] picks the body per config flag: the orchestration body
         must advertise every terrateam table (the ON contract, so clients can
         discover them), the base body none of them (the OFF contract, since a
         query naming one is refused there). *)
      Oth.test
        ~name:"MQL schema endpoint bodies advertise terrateam tables iff orchestration"
        (fun _ ->
          let on = advertised_tables Sgs_mql_ep.Tests.response_json_orchestration in
          let off = advertised_tables Sgs_mql_ep.Tests.response_json in
          Oth.Assert.List.empty
            (CCList.filter (fun t -> not (Sln_map.String.mem t on)) terrateam_tables);
          Oth.Assert.List.empty (CCList.filter (fun t -> Sln_map.String.mem t off) terrateam_tables));
      (* #1442 PR 21: the narrow provisioning write channel lives in a separate
         FDW schema, [terrateam_admin], holding the full gitlab_installations
         (webhook_secret, access_token). That schema must NEVER be reachable
         through MQL. The read surface is schema-qualified to [terrateam.*], so
         [terrateam_admin] can only leak if a CTE or the assembled query names
         it -- assert it appears nowhere in either. *)
      Oth.test ~name:"MQL surface never references the terrateam_admin schema" (fun _ ->
          Oth.Assert.str_doesnt_contain ~haystack:terrateam_ctes_sql ~needle:"terrateam_admin";
          Oth.Assert.str_doesnt_contain
            ~haystack:(Sgs_mql_paged.Tests.select_page_sql ~orchestration:true)
            ~needle:"terrateam_admin";
          Oth.Assert.str_doesnt_contain
            ~haystack:(Sgs_mql_paged.Tests.select_page_sql ~orchestration:false)
            ~needle:"terrateam_admin");
    ]

let () =
  Random.self_init ();
  Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)
