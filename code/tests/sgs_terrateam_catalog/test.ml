(* Secret-safety as a guarantee, not a habit (#1442 Phase 2).

   The demo-day FDW bridge declared credential columns in the foreign tables
   and stripped them one layer up, by hand, in the MQL projections. The
   catalog inverts that: a column that is not in
   api_schemas/stategraph/terrateam_tables.json exists in NO artifact -- not
   in the foreign-table DDL, not in the column-level grants, not in the MQL
   schema fragment. These tests hold that line four ways:

   - set equality: the (table, column) sets parsed from the generated DDL,
     the generated grants, and the compiled MQL schema fragment must each
     equal the catalog's -- so a generator bug, a parser blind spot, or a
     stray artifact edit fails loudly rather than silently shrinking
     coverage;
   - a deny-pattern over every table and column name, so a secret-shaped name
     cannot be added to the catalog without tripping CI;
   - a (table, column)-scoped exception list for names that match a pattern
     but are not secrets, with every entry required to be present in the
     catalog and load-bearing -- so the list can neither go stale nor grow
     silently;
   - sentinel (table, column) pairs that exist in the terrateam schema and
     must stay unexported, with their tables required present -- so the deny
     test cannot be satisfied by dropping the tables, and exclusions whose
     names match no pattern (plans.data) are still pinned.

   Deliberately exported despite carrying run output or a secret-shaped name:
   workflow_step_outputs.payload (raw plan/apply text + step argv),
   repo_configs.data (customer-authored config), pull_request_stacks.stacks
   (stack names, hierarchy paths, dirs, workspaces and states), and
   gates.token / gate_approvals.token (see [deny_exceptions]). They are the
   Run Detail / config parity / Stacks / gate surface the console needs, and
   they are tenant-scoped like every other MQL read.

   The first two are also already shown to the same users by the VCS comments
   the engine posts. The stacks blob is NOT -- the only stack templates are
   synthesize_config_err_* error paths, none of which renders the hierarchy --
   but it still carries nothing the tenant cannot already read: its names and
   hierarchy paths come from repo_configs.data, and its dirs and workspaces
   from Terrat_change_match3's dirspace_configs, whose expansion over the repo
   tree is exported as {github,gitlab}_change_dirspaces.path/workspace. So it
   is narrower than the union of those two surfaces, not narrower than
   repo_configs.data alone: the synthesized config can name directories the
   authored one never mentions.

   plans.data stays excluded: an opaque binary plan blob, deleted after apply,
   useless to the UI.

   One vocabulary note: these tests say "tables" throughout, but
   {github,gitlab}_pull_request_latest_unlocks are the catalog's first remote
   VIEWS (a max(unlocked_at) group-by, per the 2025-05-25 and 2025-06-16
   terrat migrations). Nothing downstream cares -- create foreign table works
   over a remote view, the schema-wide revoke and the column-level grants both
   cover views, and the unified-image drift gate reads
   information_schema.columns, which lists them -- so they need no exception
   anywhere. They are called out only so a reader does not take "table" as a
   guarantee that every catalog entry is a base relation. *)

let catalog_json = [%blob "terrateam_tables.json"]
let fdw_tables_sql = [%blob "fdw_tables.sql"]
let fdw_grants_sql = [%blob "fdw_grants.sql"]

(* Case-insensitive substrings no exported table or column name may contain. *)
let deny_patterns =
  [
    "token";
    "secret";
    "password";
    (* Bare "key", not just "private_key": kv_store.key and friends must trip
       this the day someone tries to catalog them. *)
    "key";
    "pem";
    "credential";
    "cert";
    "signature";
    "encrypt";
    "salt";
    "webhook";
    "session";
  ]

(* (table, column) pairs that exist in the terrateam schema and must never be
   exported. Sourced from the live schema (see the terrat migrations).
   plans.data is here because its name matches no deny pattern: only this pin
   keeps it out.

   The exhaustive, self-maintaining form of this check is the unified-image CI
   gate "Check catalog matches live terrat schema", which classifies every live
   column of a cataloged table against the real terrat schema, so a newly-added
   terrat column trips CI automatically; these sentinels are a fast, DB-less
   spot-check of the known cases. *)
let sentinels =
  [
    ("gitlab_installations", "webhook_secret");
    ("gitlab_installations", "access_token");
    ("gitlab_installations", "access_token_updated_by");
    ("gitlab_installations", "access_token_updated_at");
    ("plans", "data");
  ]

(* Deny-pattern EXCEPTIONS: exported columns whose names match a pattern but
   are not secrets. Gate tokens are correlation ids, not credentials: the
   blocking PR comment already renders them verbatim in its gate table and
   tells users to comment [stategraph gate approve <token1> ... <tokenN>]
   (terrat_vcs_github_comment_templates/tmpl/gate_check_failure.tmpl), so a
   token is published to everyone who can see the PR before it is ever
   queryable over MQL. The exceptions test below fails when an entry here
   stops matching the catalog, so this list cannot silently accumulate. *)
let deny_exceptions = [ ("gates", "token"); ("gate_approvals", "token") ]

let match_deny_pattern name =
  let lower = CCString.lowercase_ascii name in
  CCList.find_opt (fun p -> CCString.mem ~sub:p lower) deny_patterns

(* Table names have no exception mechanism: [deny_exceptions] is column-scoped. *)
let denied_table = match_deny_pattern

let denied_column ~table column =
  if CCList.mem ~eq:(CCPair.equal CCString.equal CCString.equal) (table, column) deny_exceptions
  then None
  else match_deny_pattern column

let sort_pairs =
  CCList.sort_uniq ~cmp:(fun (t1, c1) (t2, c2) ->
      match CCString.compare t1 t2 with
      | 0 -> CCString.compare c1 c2
      | n -> n)

(* (table, columns) pairs from the catalog JSON. *)
let catalog_tables () =
  let member_string k assoc =
    match Sln_list.String.assoc_opt k assoc with
    | Some (`String s) -> s
    | _ -> Oth.Assert.false_ (Printf.sprintf "catalog: field %S must be a string" k)
  in
  match Yojson.Safe.from_string catalog_json with
  | `Assoc assoc -> (
      match Sln_list.String.assoc_opt "tables" assoc with
      | Some (`List tables) ->
          CCList.map
            (function
              | `Assoc t -> (
                  let name = member_string "name" t in
                  match Sln_list.String.assoc_opt "columns" t with
                  | Some (`List columns) ->
                      ( name,
                        CCList.map
                          (function
                            | `Assoc c -> member_string "name" c
                            | _ -> Oth.Assert.false_ "catalog: column must be an object")
                          columns )
                  | _ -> Oth.Assert.false_ "catalog: columns must be a list")
              | _ -> Oth.Assert.false_ "catalog: table must be an object")
            tables
      | _ -> Oth.Assert.false_ "catalog: no tables list")
  | _ -> Oth.Assert.false_ "catalog: not an object"

let catalog_pairs () =
  sort_pairs
    (CCList.flat_map (fun (t, columns) -> CCList.map (fun c -> (t, c)) columns) (catalog_tables ()))

(* (table, column) pairs from the generated DDL: each
   `create foreign table terrateam.<t> (` block's "  <name> <type>[,]" lines
   up to the closing `)`. *)
let ddl_pairs () =
  let lines = CCString.split_on_char '\n' fdw_tables_sql in
  let _, pairs =
    CCList.fold_left
      (fun (current, acc) line ->
        match CCString.chop_prefix ~pre:"create foreign table terrateam." line with
        | Some rest -> (
            match CCString.split_on_char ' ' rest with
            | table :: _ -> (Some table, acc)
            | [] -> (current, acc))
        | None -> (
            match current with
            | Some table -> (
                match CCString.chop_prefix ~pre:"  " line with
                | Some col_line -> (
                    match CCString.split_on_char ' ' col_line with
                    | name :: _ :: _ when not (CCString.is_empty name) ->
                        (current, (table, name) :: acc)
                    | _ -> (current, acc))
                | None -> if CCString.prefix ~pre:")" line then (None, acc) else (current, acc))
            | None -> (current, acc)))
      (None, [])
      lines
  in
  sort_pairs pairs

(* (table, column) pairs from the generated column-level grants:
   `grant select (<c>, <c>, ...) on <t> to stategraph_mql;` lines. *)
let grants_pairs () =
  fdw_grants_sql
  |> CCString.split_on_char '\n'
  |> CCList.flat_map (fun line ->
      match CCString.chop_prefix ~pre:"grant select (" line with
      | Some rest -> (
          match CCString.Split.left ~by:") on " rest with
          | Some (columns, tail) -> (
              match CCString.Split.left ~by:" to stategraph_mql;" tail with
              | Some (table, _) ->
                  columns
                  |> CCString.split_on_char ','
                  |> CCList.map (fun c -> (table, CCString.trim c))
              | None -> Oth.Assert.false_ (Printf.sprintf "unparseable grant line: %s" line))
          | None -> Oth.Assert.false_ (Printf.sprintf "unparseable grant line: %s" line))
      | None -> [])
  |> sort_pairs

(* (table, column) pairs from the compiled MQL schema fragment, via the
   schema's own JSON projection -- proves the artifact the MQL endpoint will
   actually consume, not just its textual source. *)
let fragment_pairs () =
  match Mql_to_pgsql.Schema.to_yojson (Mql_to_pgsql.Schema.make Sgs_terrateam_catalog.tables) with
  | `Assoc fields -> (
      match Sln_list.String.assoc_opt "tables" fields with
      | Some (`Assoc tables) ->
          sort_pairs
            (CCList.flat_map
               (fun (table, json) ->
                 match json with
                 | `Assoc t -> (
                     match Sln_list.String.assoc_opt "columns" t with
                     | Some (`Assoc columns) -> CCList.map (fun (c, _) -> (table, c)) columns
                     | _ -> Oth.Assert.false_ "schema fragment: no columns")
                 | _ -> Oth.Assert.false_ "schema fragment: table not an object")
               tables)
      | _ -> Oth.Assert.false_ "schema fragment: no tables")
  | _ -> Oth.Assert.false_ "schema fragment: unexpected json shape"

let pp_pairs = CCList.pp (CCPair.pp CCString.pp CCString.pp)
let eq_pairs = CCList.equal (CCPair.equal CCString.equal CCString.equal)

let test =
  Oth.parallel
    [
      Oth.test ~name:"DDL, grants, and schema fragment each equal the catalog" (fun _ ->
          let catalog = catalog_pairs () in
          Oth.Assert.List.non_empty catalog |> ignore;
          Oth.Assert.eq ~pp:pp_pairs ~eq:eq_pairs catalog (ddl_pairs ());
          Oth.Assert.eq ~pp:pp_pairs ~eq:eq_pairs catalog (grants_pairs ());
          Oth.Assert.eq ~pp:pp_pairs ~eq:eq_pairs catalog (fragment_pairs ());
          ());
      Oth.test ~name:"no catalog table or column name matches a deny pattern" (fun _ ->
          CCList.iter
            (fun (table, columns) ->
              (match denied_table table with
              | Some pattern ->
                  Oth.Assert.false_
                    (Printf.sprintf "catalog table %s matches deny pattern %S" table pattern)
              | None -> ());
              CCList.iter
                (fun column ->
                  match denied_column ~table column with
                  | Some pattern ->
                      Oth.Assert.false_
                        (Printf.sprintf
                           "catalog column %s.%s matches deny pattern %S -- secret-shaped columns \
                            must not be exported over the FDW bridge"
                           table
                           column
                           pattern)
                  | None -> ())
                columns)
            (catalog_tables ());
          ());
      (* Exceptions must stay live: each entry must name a column that is in
         the catalog AND would match a deny pattern without the exception --
         otherwise the entry is stale and the allowlist silently grows. *)
      Oth.test ~name:"every deny exception is present and load-bearing" (fun _ ->
          let tables = catalog_tables () in
          CCList.iter
            (fun (table, column) ->
              (match Sln_list.String.assoc_opt table tables with
              | Some columns when Sln_list.String.mem column columns -> ()
              | Some _ | None ->
                  Oth.Assert.false_
                    (Printf.sprintf
                       "deny exception %s.%s is not in the catalog -- remove the stale entry"
                       table
                       column));
              let lower = CCString.lowercase_ascii column in
              Oth.Assert.List.exists
                ~fail_msg:
                  (Printf.sprintf
                     "deny exception %s.%s matches no deny pattern -- remove the pointless entry"
                     table
                     column)
                (fun p -> CCString.mem ~sub:p lower)
                deny_patterns)
            deny_exceptions;
          (* The exception is pair-scoped: the same column name under any
             other table must still trip the deny pattern. *)
          Oth.Assert.true_ (CCOption.is_some (denied_column ~table:"not_a_cataloged_table" "token"));
          ());
      Oth.test ~name:"sentinel tables are present with their secret columns absent" (fun _ ->
          let tables = catalog_tables () in
          CCList.iter
            (fun (table, column) ->
              match Sln_list.String.assoc_opt table tables with
              | None ->
                  Oth.Assert.false_
                    (Printf.sprintf
                       "sentinel table %s missing from the catalog -- the deny test must not be \
                        satisfied by dropping the table"
                       table)
              | Some columns -> Oth.Assert.not_true (Sln_list.String.mem column columns))
            sentinels;
          ());
    ]

let () =
  Random.self_init ();
  Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)
