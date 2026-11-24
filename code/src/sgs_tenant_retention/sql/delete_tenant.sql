-- Deletes every row of one tenant and answers the number of rows it deleted from each table.  The
-- caller holds the lock of lock_due.sql, which is what decides that the tenant may go.
--
-- One statement deletes all of them, so the foreign keys, which are checked at the end of the
-- statement, never see a child row without its parent.  The users of the tenant stay: a user can
-- belong to other tenants, and cleanup_users.sql decides about the ones left without one.  A state
-- of another tenant whose HCL names a state of this tenant as a remote state fails the statement,
-- and nothing is deleted.
with
tenant_states as (
    select id from states where tenant_id = $tenant_id
),
tenant_txs as (
    select id, apply_task_id from transactions where tenant_id = $tenant_id
),
delete_check_entries as (
    delete from check_entries where state_id in (select id from tenant_states) returning 1
),
delete_check_results as (
    delete from check_results where state_id in (select id from tenant_states) returning 1
),
delete_instances as (
    delete from instances where state_id in (select id from tenant_states) returning 1
),
delete_resources as (
    delete from resources where state_id in (select id from tenant_states) returning 1
),
delete_providers as (
    delete from providers where state_id in (select id from tenant_states) returning 1
),
delete_outputs as (
    delete from outputs where state_id in (select id from tenant_states) returning 1
),
delete_states_metadata as (
    delete from states_metadata where id in (select id from tenant_states) returning 1
),
delete_transaction_logs as (
    delete from transaction_logs
    where state_id in (select id from tenant_states) or tx_id in (select id from tenant_txs)
    returning 1
),
delete_filepath_refs as (
    delete from filepath_refs where state_id in (select id from tenant_states) returning 1
),
delete_files as (
    delete from files where state_id in (select id from tenant_states) returning 1
),
delete_hcl_refs as (
    delete from hcl_refs where state_id in (select id from tenant_states) returning 1
),
delete_hcl_tainted as (
    delete from hcl_tainted where state_id in (select id from tenant_states) returning 1
),
delete_hcl as (
    delete from hcl where state_id in (select id from tenant_states) returning 1
),
delete_tf_module_hcl_refs as (
    delete from tf_module_hcl_refs where state_id in (select id from tenant_states) returning 1
),
delete_tf_module_hcl as (
    delete from tf_module_hcl where state_id in (select id from tenant_states) returning 1
),
delete_tf_module_revision_node_hashes as (
    delete from tf_module_revision_node_hashes
    where state_id in (select id from tenant_states)
    returning 1
),
delete_tf_module_revision_hashes as (
    delete from tf_module_revision_hashes where state_id in (select id from tenant_states) returning 1
),
delete_tf_module_revision_tx_node_hashes as (
    delete from tf_module_revision_tx_node_hashes
    where state_id in (select id from tenant_states) or tx_id in (select id from tenant_txs)
    returning 1
),
delete_tf_module_revision_tx_hashes as (
    delete from tf_module_revision_tx_hashes
    where state_id in (select id from tenant_states) or tx_id in (select id from tenant_txs)
    returning 1
),
delete_tf_modules as (
    delete from tf_modules where state_id in (select id from tenant_states) returning 1
),
delete_revision_hashes as (
    delete from revision_hashes
    where state_id in (select id from tenant_states) or tx_id in (select id from tenant_txs)
    returning 1
),
delete_revision_tx_hashes as (
    delete from revision_tx_hashes
    where state_id in (select id from tenant_states) or tx_id in (select id from tenant_txs)
    returning 1
),
delete_transaction_subgraphs as (
    delete from transaction_subgraphs
    where state_id in (select id from tenant_states) or tx_id in (select id from tenant_txs)
    returning 1
),
delete_transaction_subgraph_nodes as (
    delete from transaction_subgraph_nodes
    where state_id in (select id from tenant_states) or tx_id in (select id from tenant_txs)
    returning 1
),
delete_transaction_hints as (
    delete from transaction_hints
    where state_id in (select id from tenant_states) or tx_id in (select id from tenant_txs)
    returning 1
),
delete_hcl_hints as (
    delete from hcl_hints where state_id in (select id from tenant_states) returning 1
),
delete_tf_module_hcl_hints as (
    delete from tf_module_hcl_hints where state_id in (select id from tenant_states) returning 1
),
delete_tfvars as (
    delete from tfvars where state_id in (select id from tenant_states) returning 1
),
tenant_cost_snapshots as (
    select id from cost_snapshots
    where tenant_id = $tenant_id or state_id in (select id from tenant_states)
),
delete_cost_snapshot_resources as (
    delete from cost_snapshot_resources
    where snapshot_id in (select id from tenant_cost_snapshots)
    returning 1
),
delete_cost_snapshots as (
    delete from cost_snapshots where id in (select id from tenant_cost_snapshots) returning 1
),
delete_schedules as (
    delete from schedules
    where data ->> 'state_id' in (select id::text from tenant_states)
        or data ->> 'tenant_id' = $tenant_id::text
    returning 1
),
tenant_security_scans as (
    select id from security_scans
    where tenant_id = $tenant_id
        or state_id in (select id from tenant_states)
        or tx_id in (select id from tenant_txs)
),
delete_security_scan_findings as (
    delete from security_scan_findings
    where state_id in (select id from tenant_states)
        or scan_id in (select id from tenant_security_scans)
        or first_seen_scan_id in (select id from tenant_security_scans)
        or resolved_scan_id in (select id from tenant_security_scans)
    returning 1
),
delete_security_scans as (
    delete from security_scans where id in (select id from tenant_security_scans) returning 1
),
delete_resource_cloud_ids as (
    delete from resource_cloud_ids
    where tenant_id = $tenant_id or state_id in (select id from tenant_states)
    returning 1
),
delete_focus_billing_attribution as (
    delete from focus_billing_attribution
    where state_id in (select id from tenant_states)
    returning 1
),
delete_focus_billing as (
    delete from focus_billing where tenant_id = $tenant_id returning 1
),
delete_focus_billing_sources as (
    delete from focus_billing_sources where tenant_id = $tenant_id returning 1
),
delete_gap_analysis_jobs as (
    delete from gap_analysis_jobs where tenant_id = $tenant_id returning 1
),
delete_caps_group_rules as (
    delete from caps_group_rules where tenant_id = $tenant_id returning 1
),
delete_transaction_plan_operations as (
    delete from transaction_plan_operations where tx_id in (select id from tenant_txs) returning 1
),
delete_transaction_previews as (
    delete from transaction_previews where tx_id in (select id from tenant_txs) returning 1
),
delete_task_results as (
    delete from task_results
    where task_id in (select apply_task_id from tenant_txs where apply_task_id is not null)
    returning 1
),
delete_tasks as (
    delete from tasks
    where id in (select apply_task_id from tenant_txs where apply_task_id is not null)
    returning 1
),
delete_transactions as (
    delete from transactions where id in (select id from tenant_txs) returning 1
),
delete_tenant_invitations as (
    delete from tenant_invitations where tenant_id = $tenant_id returning 1
),
delete_tenant_users as (
    delete from tenant_users where tenant_id = $tenant_id returning 1
),
delete_tenant_vcs_installations as (
    delete from tenant_vcs_installations where tenant_id = $tenant_id returning 1
),
delete_states as (
    delete from states where id in (select id from tenant_states) returning 1
),
delete_tenant as (
    delete from tenants where id = $tenant_id returning 1
)
select jsonb_build_object(
    'check_entries', (select count(*) from delete_check_entries),
    'check_results', (select count(*) from delete_check_results),
    'instances', (select count(*) from delete_instances),
    'resources', (select count(*) from delete_resources),
    'providers', (select count(*) from delete_providers),
    'outputs', (select count(*) from delete_outputs),
    'states_metadata', (select count(*) from delete_states_metadata),
    'transaction_logs', (select count(*) from delete_transaction_logs),
    'filepath_refs', (select count(*) from delete_filepath_refs),
    'files', (select count(*) from delete_files),
    'hcl_refs', (select count(*) from delete_hcl_refs),
    'hcl_tainted', (select count(*) from delete_hcl_tainted),
    'hcl', (select count(*) from delete_hcl),
    'tf_module_hcl_refs', (select count(*) from delete_tf_module_hcl_refs),
    'tf_module_hcl', (select count(*) from delete_tf_module_hcl),
    'tf_module_revision_node_hashes', (select count(*) from delete_tf_module_revision_node_hashes),
    'tf_module_revision_hashes', (select count(*) from delete_tf_module_revision_hashes),
    'tf_module_revision_tx_node_hashes',
        (select count(*) from delete_tf_module_revision_tx_node_hashes),
    'tf_module_revision_tx_hashes', (select count(*) from delete_tf_module_revision_tx_hashes),
    'tf_modules', (select count(*) from delete_tf_modules),
    'revision_hashes', (select count(*) from delete_revision_hashes),
    'revision_tx_hashes', (select count(*) from delete_revision_tx_hashes),
    'transaction_subgraphs', (select count(*) from delete_transaction_subgraphs),
    'transaction_subgraph_nodes', (select count(*) from delete_transaction_subgraph_nodes),
    'transaction_hints', (select count(*) from delete_transaction_hints),
    'hcl_hints', (select count(*) from delete_hcl_hints),
    'tf_module_hcl_hints', (select count(*) from delete_tf_module_hcl_hints),
    'tfvars', (select count(*) from delete_tfvars),
    'cost_snapshot_resources', (select count(*) from delete_cost_snapshot_resources),
    'cost_snapshots', (select count(*) from delete_cost_snapshots),
    'schedules', (select count(*) from delete_schedules),
    'security_scan_findings', (select count(*) from delete_security_scan_findings),
    'security_scans', (select count(*) from delete_security_scans),
    'resource_cloud_ids', (select count(*) from delete_resource_cloud_ids),
    'focus_billing_attribution', (select count(*) from delete_focus_billing_attribution),
    'focus_billing', (select count(*) from delete_focus_billing),
    'focus_billing_sources', (select count(*) from delete_focus_billing_sources),
    'gap_analysis_jobs', (select count(*) from delete_gap_analysis_jobs),
    'caps_group_rules', (select count(*) from delete_caps_group_rules),
    'transaction_plan_operations', (select count(*) from delete_transaction_plan_operations),
    'transaction_previews', (select count(*) from delete_transaction_previews),
    'task_results', (select count(*) from delete_task_results),
    'tasks', (select count(*) from delete_tasks),
    'transactions', (select count(*) from delete_transactions),
    'tenant_invitations', (select count(*) from delete_tenant_invitations),
    'tenant_users', (select count(*) from delete_tenant_users),
    'tenant_vcs_installations', (select count(*) from delete_tenant_vcs_installations),
    'states', (select count(*) from delete_states),
    'tenants', (select count(*) from delete_tenant)
)
