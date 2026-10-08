-- MQL query wrapper.
--
-- SECURITY: each CTE below shadows a real table with a copy filtered to the
-- caller's tenants (the user MQL query is substituted into the `q` CTE, where
-- every table name resolves to one of these scoped CTEs). Every table in the
-- MQL allow-list (`schema` in sgs_mql_paged.ml) MUST have a tenant-scoped CTE
-- here; otherwise that name resolves to the real, unscoped table. The test in
-- code/tests/sgs_mql asserts the allow-list stays a subset of these CTEs.
--
-- PERFORMANCE (issue #1070): an analytical MQL query references a scoped table
-- many times. A plain CTE referenced more than once is materialised by PG
-- (12+) into an index-less copy, which (a) drops the (state_id, ...) indexes
-- and (b) forces the secret-masking projection to run over every row even when
-- no masked column is selected -- the dominant cost on real estates. So the
-- data-bearing CTEs are marked `AS NOT MATERIALIZED`: the planner inlines them,
-- pushing the tenant predicate down to the indexes and pruning the unused
-- (masked) columns.
--
-- The exception is the *anchor* CTEs that other CTEs join through to reach the
-- tenant scope -- `tenants`, `tenant_users`, `states`, `transactions`,
-- `cost_snapshots`, `security_scans`. These are LEFT as plain (materialised)
-- CTEs on purpose: materialising the small scope set once gives the planner a
-- concrete row count, so the inlined data CTEs that join to it estimate
-- correctly. Inlining the anchors too collapses every join estimate to one row
-- and the planner picks nested loops that re-run the whole scope chain per
-- reference -- ~35x SLOWER on the home dashboard. Every leaf CTE only ever
-- joins through a materialised anchor, so inlining never cascades. Do not flip
-- an anchor to NOT MATERIALIZED, or a leaf to plain, without re-benchmarking.
with
tenants as (
  select
    t.id as id,
    t.name as name,
    t.created_at as created_at
  from tenants as t
  inner join tenant_users as tu
    on tu.tenant_id = t.id
  where tu.user_id = $user_id
),
tenant_users as (
  select
    tu.tenant_id as tenant_id,
    tu.user_id as user_id
  from tenant_users as tu
  inner join tenants as t
    on t.id = tu.tenant_id
),
users as not materialized (
  select
    u.id as id,
    u.name as name,
    u.type as type,
    u.created_at as created_at
  from users as u
  inner join tenant_users as tu
    on tu.user_id = u.id
  where u.id = $user_id
),
states as (
  select
    s.id as id,
    s.group_id as group_id,
    s.workspace as workspace,
    s.name as name,
    s.tenant_id as tenant_id,
    s.created_at as created_at,
    s.updated_at as updated_at,
    s.deleted_at as deleted_at,
    s.deleted_by as deleted_by,
    s.schema_version as schema_version
  from states as s
  inner join tenants as t
    on t.id = s.tenant_id
),
providers as not materialized (
  select
    p.name as name,
    p.state_id as state_id
  from providers as p
  inner join states as s
    on p.state_id = s.id
  inner join tenants as t
    on t.id = s.tenant_id
),
resources as not materialized (
  select
    r.address as address,
    r.fq_address as fq_address,
    r.mode as mode,
    r.module_ as module,
    r.name as name,
    r.provider as provider,
    r.state_id as state_id,
    r.type as type
  from resources as r
  inner join states as s
    on r.state_id = s.id
  inner join tenants as t
    on t.id = s.tenant_id
),
instances as not materialized (
  -- SECURITY (secret masking): attributes and private carry raw Terraform
  -- instance state, which can contain secrets. Before they leave the database
  -- every value the state marks sensitive is masked: attribute values declared
  -- in sensitive_attributes are replaced with '__SENSITIVE__' by
  -- pg_temp.mask_sensitive_attributes, and the opaque private blob is replaced
  -- wholesale. sensitive_attributes itself is metadata (which paths were
  -- masked), not a secret, so it is left intact. See sgs_mql_paged.ml.
  select
    i.address as address,
    -- PERFORMANCE (issue #1071): mask_sensitive_attributes is plpgsql and copies
    -- the (detoasted) attributes blob into a local on every call -- paid per row
    -- even when nothing is masked. Skip the call for the common rows that mark
    -- nothing sensitive (sql null / json null / empty array): those are exactly
    -- the cases where the helper is a no-op, so this is output-identical while
    -- avoiding the plpgsql call. Only genuinely-sensitive rows pay the rewrite.
    -- The guards are total jsonb equalities -- no jsonb_array_length on a
    -- possibly-non-array value, whose evaluation Postgres may reorder ahead of a
    -- type check and throw.
    case
      when i.sensitive_attributes is null
           or i.sensitive_attributes = '[]'::jsonb
           or i.sensitive_attributes = 'null'::jsonb
      then i.attributes
      else pg_temp.mask_sensitive_attributes(i.attributes, i.sensitive_attributes)
    end as attributes,
    i.create_before_destroy as create_before_destroy,
    coalesce(i.dependencies, '{}'::text[]) as dependencies,
    i.deposed as deposed,
    i.fq_address as fq_address,
    coalesce(i.identity, '{}'::jsonb) as identity,
    i.identity_schema_version as identity_schema_version,
    i.index_key as index_key,
    case when i.private is null then null else '__SENSITIVE__' end as private,
    i.resource_address as resource_address,
    i.schema_version as schema_version,
    coalesce(i.sensitive_attributes, '{}'::jsonb) as sensitive_attributes,
    i.state_id as state_id,
    i.status as status
  from instances as i
  inner join states as s
    on i.state_id = s.id
  inner join tenants as t
    on t.id = s.tenant_id
),
outputs as not materialized (
  -- SECURITY (secret masking): value carries raw Terraform output values. When
  -- the output is marked sensitive its value is replaced with '__SENSITIVE__'
  -- before it leaves the database. See sgs_mql_paged.ml.
  select
    o.address as address,
    o.name as name,
    coalesce(o.sensitive, false) as sensitive,
    o.state_id as state_id,
    o.type as type,
    case when coalesce(o.sensitive, false) then to_jsonb('__SENSITIVE__'::text) else o.value end as value
  from outputs as o
  inner join states as s
    on o.state_id = s.id
  inner join tenants as t
    on t.id = s.tenant_id
),
check_results as not materialized (
  select
    c.config_addr as config_addr,
    c.object_kind as object_kind,
    c.state_id as state_id,
    c.status as status
  from check_results as c
  inner join states as s
    on s.id = c.state_id
),
check_entries as not materialized (
  select
    c.config_addr as config_addr,
    c.failure_messages as failure_messages,
    c.object_addr as object_addr,
    c.state_id as state_id,
    c.status as status
  from check_entries as c
  inner join states as s
    on s.id = c.state_id
),
transactions as (
  select
    tx.completed_at as completed_at,
    tx.created_at as created_at,
    tx.id as id,
    tx.state as state,
    tx.tags as tags,
    tx.params as params,
    tx.tenant_id as tenant_id,
    tx.created_by as created_by,
    tx.completed_by as completed_by,
    -- Projected for the transaction_output_chunks CTE below, which resolves a
    -- tx's apply output through it; not in the catalog (sgs_mql_paged.ml), so
    -- not selectable by name from a user query.
    tx.apply_task_id as apply_task_id
  from transactions as tx
  inner join tenants as t
    on t.id = tx.tenant_id
),
transaction_logs as not materialized (
  -- SECURITY (secret masking): data carries raw transaction-log payloads, which
  -- for instance/output rows embed the same secret-bearing state. pg_temp.mask_tx_log_data
  -- masks those values (instance attributes via sensitive_attributes, sensitive
  -- output values) before they leave the database. See sgs_mql_paged.ml.
  --
  -- SECURITY (RFD 1377): an ephemeral tfvar generally carries a secret, and its
  -- transaction log entry is the ONLY surviving copy of the value -- it is never
  -- committed to the [tfvars] table -- so this is the one place a reader can
  -- reach it. Masked by ACTION, not object_type: an ephemeral tfvar is stored
  -- as object_type 'tfvar' exactly like an ordinary one, whose value must
  -- remain visible.
  select
    txl.action as action,
    txl.created_at as created_at,
    -- PERFORMANCE (issue #1071): mask_tx_log_data only rewrites 'instance' and
    -- 'output' rows; every other object_type returns data unchanged. Gate the
    -- plpgsql call on those two types so the common log rows skip it entirely.
    case
      when txl.object_type in ('instance', 'output')
      then pg_temp.mask_tx_log_data(txl.object_type, txl.data)
      when txl.action = 'tfvar_ephemeral'
      then pg_temp.mask_tfvar_ephemeral_data(txl.data)
      else txl.data
    end as data,
    txl.id as id,
    txl.object_type as object_type,
    txl.state_id as state_id,
    txl.tx_id as tx_id,
    txl.user_id as user_id
  from transaction_logs as txl
  inner join transactions as tx
    on tx.id = txl.tx_id
),
hcl as not materialized (
  select
    h.fq_address as fq_address,
    h.created_at as created_at,
    h.data as data,
    h.file_refs as file_refs,
    hh.expanded as hints,
    h.id as id,
    h.module_address as module_address,
    h.module_source as module_source,
    h.path_attrs as path_attrs,
    h.refs as refs,
    h.state_id as state_id,
    h.updated_at as updated_at
  from hcl as h
  inner join states as s
    on s.id = h.state_id
  left join hcl_hints as hh
    on hh.state_id = h.state_id
   and hh.id = h.id
),
hcl_refs as not materialized (
  select
    hr.state_id as state_id,
    hr.id as id,
    hr.ref as ref,
    coalesce(hr.attr_path, '{}'::text[]) as attr_path,
    hr.index_kind as index_kind,
    coalesce(hr.index_val, 'null'::jsonb) as index_val,
    hr.is_bare as is_bare,
    hr.resolvable as resolvable,
    hr.from_depends_on as from_depends_on
  from hcl_refs as hr
  inner join states as s
    on s.id = hr.state_id
),
-- RFD 1008 Phase 1.  The module tables join the [states] anchor directly, the
-- same as [hcl] and [hcl_refs], and not through the [tf_modules] CTE: a leaf
-- joins only a materialised anchor.
tf_modules as not materialized (
  select
    tm.state_id as state_id,
    tm.source as source,
    tm.version as version,
    tm.created_at as created_at
  from tf_modules as tm
  inner join states as s
    on s.id = tm.state_id
),
tf_module_hcl as not materialized (
  select
    tmh.state_id as state_id,
    tmh.source as source,
    tmh.version as version,
    tmh.id as id,
    tmh.fq_address as fq_address,
    tmh.data as data,
    tmh.refs as refs,
    tmh.path_attrs as path_attrs,
    tmh.created_at as created_at,
    tmh.updated_at as updated_at
  from tf_module_hcl as tmh
  inner join states as s
    on s.id = tmh.state_id
),
tf_module_hcl_refs as not materialized (
  select
    tmr.state_id as state_id,
    tmr.source as source,
    tmr.version as version,
    tmr.id as id,
    tmr.ref as ref,
    coalesce(tmr.attr_path, '{}'::text[]) as attr_path,
    tmr.index_kind as index_kind,
    coalesce(tmr.index_val, 'null'::jsonb) as index_val,
    tmr.is_bare as is_bare,
    tmr.resolvable as resolvable,
    tmr.from_depends_on as from_depends_on
  from tf_module_hcl_refs as tmr
  inner join states as s
    on s.id = tmr.state_id
),
files as not materialized (
  select
    f.state_id as state_id,
    f.filepath as filepath,
    f.content_hash as content_hash,
    f.mode as mode,
    coalesce(f.template_vars, '{}'::text[]) as template_vars,
    f.module_address as module_address,
    f.id as id
  from files as f
  inner join states as s
    on s.id = f.state_id
),
tfvars as not materialized (
  select
    tv.state_id as state_id,
    tv.id as id,
    tv.var_address as var_address,
    tv.file as file,
    tv.data as data
  from tfvars as tv
  inner join states as s
    on s.id = tv.state_id
),
transaction_subgraphs as not materialized (
  select
    ts.tx_id as tx_id,
    ts.state_id as state_id,
    ts.node_type as node_type,
    ts.direction as direction,
    ts.depth as depth,
    ts.item as item
  from transaction_subgraphs as ts
  inner join transactions as tx
    on tx.id = ts.tx_id
),
transaction_output_chunks as not materialized (
  -- The captured output of a transaction's apply, as the stored chunk rows of
  -- the task that ran it (transactions.apply_task_id). A task's rows hold the
  -- base64 of a JSON payload, cut across idx in order. Reassembly (concatenate,
  -- base64-decode, parse) is the reader's job. payload names what the rows
  -- reassemble to, from the task's state: a completed apply stored its stdout
  -- (a JSON string), a failed one its run-failure record.
  --
  -- SECURITY (no masking, by design -- #2122): unlike instances, outputs
  -- and transaction_logs above, run output is served as stored. The
  -- payload is base64 cut across rows, so a row cannot be masked on its own
  -- anyway, and the text is what tofu already rendered with its
  -- "(sensitive value)" redaction. Tenant membership is the whole of the
  -- control, here and on the endpoint alike.
  select
    tx.id as tx_id,
    tr.idx as idx,
    tr.data as data,
    case when tk.state = 'completed' then 'apply_stdout' else 'run_failure' end as payload
  from task_results as tr
  inner join tasks as tk
    on tk.id = tr.task_id
  inner join transactions as tx
    on tx.apply_task_id = tr.task_id
),
transaction_plan_operations as not materialized (
  -- Per-resource plan operations persisted at preview-finalize. One row per changed resource
  -- instance. Scoped through the transactions anchor. Serves
  -- GET /api/v1/tx/{tx_id}/plan-operations.
  select
    po.tx_id as tx_id,
    po.address as address,
    po.operation as operation
  from transaction_plan_operations as po
  inner join transactions as tx
    on tx.id = po.tx_id
),
revision_hashes as not materialized (
  select
    r.created_at as created_at,
    r.hash as hash,
    r.key as key,
    r.state_id as state_id,
    r.tx_id as tx_id,
    r.user_id as user_id
  from revision_hashes as r
  inner join states as s
    on s.id = r.state_id
),
revision_tx_hashes as not materialized (
  select
    r.created_at as created_at,
    r.hash as hash,
    r.key as key,
    r.state_id as state_id,
    r.tx_id as tx_id,
    r.user_id as user_id
  from revision_tx_hashes as r
  inner join states as s
    on s.id = r.state_id
),
cost_snapshots as (
  -- tenant_id is denormalised at write time, so scoping is a direct join on
  -- the tenant-membership CTE (no traversal through states needed). Money
  -- columns are cast to text on the way out so the JSON wire preserves
  -- precision; this matches the cost read API.
  select
    cs.id as id,
    cs.state_id as state_id,
    cs.tenant_id as tenant_id,
    cs.tx_id as tx_id,
    cs.calculated_at as calculated_at,
    cs.kind as kind,
    cs.source as source,
    cs.triggered_by as triggered_by,
    cs.currency as currency,
    cs.monthly_cost::text as monthly_cost,
    cs.hourly_cost::text as hourly_cost,
    cs.resource_count as resource_count,
    cs.supported_count as supported_count,
    cs.priced_count as priced_count,
    cs.pricing_service_version as pricing_service_version
  from cost_snapshots as cs
  inner join tenants as t
    on t.id = cs.tenant_id
),
cost_snapshot_resources as not materialized (
  -- No tenant_id column; scope is inherited from the (already tenant-scoped)
  -- cost_snapshots CTE above by joining on snapshot_id.
  select
    csr.snapshot_id as snapshot_id,
    csr.address as address,
    csr.type as type,
    csr.provider as provider,
    csr.region as region,
    csr.supported as supported,
    csr.no_price as no_price,
    csr.monthly_cost::text as monthly_cost,
    csr.hourly_cost::text as hourly_cost,
    csr.components as components,
    csr.tags as tags,
    csr.cloud_resource_id as cloud_resource_id
  from cost_snapshot_resources as csr
  inner join cost_snapshots as cs
    on cs.id = csr.snapshot_id
),
security_scans as (
  -- Scoped via the (tenant_id-bearing) row's own tenant_id, joined to the
  -- caller-visible tenants CTE.
  select
    ss.id as id,
    ss.state_id as state_id,
    ss.tenant_id as tenant_id,
    ss.tx_id as tx_id,
    ss.scanned_at as scanned_at,
    ss.kind as kind,
    ss.triggered_by as triggered_by,
    ss.scanner as scanner,
    ss.scanner_version as scanner_version,
    ss.status as status,
    ss.finding_count as finding_count,
    ss.severity_breakdown as severity_breakdown,
    ss.error_message as error_message
  from security_scans as ss
  inner join tenants as t
    on t.id = ss.tenant_id
),
security_scan_findings as not materialized (
  -- No tenant_id column; scope is inherited from the (already tenant-scoped)
  -- security_scans CTE above by joining on scan_id.
  select
    sf.scan_id as scan_id,
    sf.fingerprint as fingerprint,
    sf.check_id as check_id,
    sf.resource_fq_address as resource_fq_address,
    sf.state_id as state_id,
    sf.source_file as source_file,
    sf.source_start_line as source_start_line,
    sf.source_end_line as source_end_line,
    sf.severity_base as severity_base,
    sf.severity_effective as severity_effective,
    sf.severity_reason as severity_reason,
    sf.blast_radius_resource_count as blast_radius_resource_count,
    coalesce(sf.blast_radius_modules, '{}'::text[]) as blast_radius_modules,
    sf.is_internet_reachable as is_internet_reachable,
    sf.internet_reachability_evidence as internet_reachability_evidence,
    coalesce(sf.cross_state_refs, '{}'::uuid[]) as cross_state_refs,
    s.workspace as workspace,
    sf.first_seen_scan_id as first_seen_scan_id,
    sf.resolved_scan_id as resolved_scan_id
  from security_scan_findings as sf
  inner join security_scans as ss
    on ss.id = sf.scan_id
  inner join states as s
    on s.id = sf.state_id
),
focus_billing_sources as not materialized (
  -- tenant_id is denormalised on the row, so scoping is a direct join on the
  -- tenant-membership CTE (like cost_snapshots). This table holds no secret or
  -- credential columns (credentials resolve ambiently via DuckDB's
  -- credential_chain), so every column is projected as-is with no masking.
  select
    fbs.id as id,
    fbs.tenant_id as tenant_id,
    fbs.provider as provider,
    fbs.source_uri as source_uri,
    fbs.region as region,
    fbs.window_months as window_months,
    fbs.enabled as enabled,
    fbs.last_status as last_status,
    fbs.last_error as last_error,
    fbs.last_synced_at as last_synced_at,
    fbs.last_row_count as last_row_count,
    fbs.created_at as created_at,
    fbs.updated_at as updated_at
  from focus_billing_sources as fbs
  inner join tenants as t
    on t.id = fbs.tenant_id
){{terrateam_ctes}},
q as (
{{q}}
)
select to_json(q) from q
