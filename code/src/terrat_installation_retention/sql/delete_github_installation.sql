-- Deletes every row of one GitHub installation and answers the number of rows
-- it deleted from each table.  The caller holds the lock of lock_due_github.sql,
-- which is what decides that the installation may go.
--
-- One statement deletes all of them, so the foreign keys, which are checked at
-- the end of the statement, never see a child row without its parent.
--
-- A repository row moves to a new installation when that installation claims
-- the repository (upsert_installation_repos.sql), and its data moves with it.
-- The repositories of this installation are read once, when the statement
-- starts, and deleted by id: a repository that a new installation claims while
-- the statement runs is deleted with this installation.  Accepted: the window
-- is one statement, at least 30 days after the uninstall.  Users
-- are kept: a user can belong to other installations, so only the links of the
-- users to this installation go.  The org goes when no other installation names
-- it.
--
-- kv_store holds two kinds of rows of an installation.  A row of a
-- `cache<version>.<name>` namespace has a key that starts with the installation
-- id and a value that is the content hash of a row of the `<namespace>.data`
-- namespace.  A content row is shared by every installation whose rows name its
-- hash, so it goes only when no row of another installation names it.  A row of
-- the `github:<installation id>` namespace is the installation's own.
with
installation as (
    select gim.core_id
    from github_installations_map as gim
    where gim.installation_id = $installation_id
),
repositories as (
    select gir.id
    from github_installation_repositories as gir
    where gir.installation_id = $installation_id
),
repos as (
    select grm.core_id
    from github_repositories_map as grm
    inner join repositories as r on r.id = grm.repository_id
),
pull_requests as (
    select gprm.core_id
    from github_pull_requests_map as gprm
    inner join repositories as r on r.id = gprm.repository_id
),
work_manifest_ids as (
    select wm.id
    from work_manifests as wm
    inner join repos as r on r.core_id = wm.repo
),
delete_work_manifest_comments as (
    delete from github_work_manifest_comments as t
    using repositories as r
    where t.repository = r.id
    returning 1
),
delete_unified_comments as (
    delete from github_unified_comments as t
    using repositories as r
    where t.repository = r.id
    returning 1
),
delete_dirspace_summaries as (
    delete from github_pull_request_dirspace_summaries as t
    using repositories as r
    where t.repository = r.id
    returning 1
),
delete_plans as (
    delete from plans as t
    using work_manifest_ids as w
    where t.work_manifest = w.id
    returning 1
),
delete_workflow_step_outputs as (
    delete from workflow_step_outputs as t
    using work_manifest_ids as w
    where t.work_manifest = w.id
    returning 1
),
delete_work_manifest_results as (
    delete from work_manifest_results as t
    using work_manifest_ids as w
    where t.work_manifest = w.id
    returning 1
),
delete_work_manifest_dirspaceflows as (
    delete from work_manifest_dirspaceflows as t
    using work_manifest_ids as w
    where t.work_manifest = w.id
    returning 1
),
delete_work_manifest_access_control as (
    delete from work_manifest_access_control_denied_dirspaces as t
    using work_manifest_ids as w
    where t.work_manifest = w.id
    returning 1
),
delete_work_manifest_steps as (
    delete from work_manifest_steps as t
    using work_manifest_ids as w
    where t.work_manifest_id = w.id
    returning 1
),
delete_flow_states as (
    delete from flow_states as t
    using work_manifest_ids as w
    where t.id = w.id
    returning 1
),
delete_job_work_manifests as (
    delete from job_work_manifests as t
    using work_manifest_ids as w
    where t.work_manifest = w.id
    returning 1
),
delete_drift_work_manifests as (
    delete from drift_work_manifests as t
    using work_manifest_ids as w
    where t.work_manifest = w.id
    returning 1
),
delete_index_work_manifests as (
    delete from index_work_manifests as t
    using work_manifest_ids as w
    where t.work_manifest = w.id
    returning 1
),
delete_compute_node_work as (
    delete from compute_node_work as t
    using work_manifest_ids as w
    where t.work_manifest = w.id
    returning 1
),
delete_work_manifests as (
    delete from work_manifests as t
    using work_manifest_ids as w
    where t.id = w.id
    returning 1
),
delete_pull_request_stacks as (
    delete from pull_request_stacks as t
    using pull_requests as p
    where t.pull_request = p.core_id
    returning 1
),
delete_gates as (
    delete from gates as t
    using pull_requests as p
    where t.pull_request = p.core_id
    returning 1
),
delete_gate_approvals as (
    delete from gate_approvals as t
    using pull_requests as p
    where t.pull_request = p.core_id
    returning 1
),
delete_dirspace_pull_request_locks as (
    delete from dirspace_pull_request_locks as t
    using pull_requests as p
    where t.pull_request = p.core_id
    returning 1
),
delete_pruned_dirspaces as (
    delete from pruned_dirspaces as t
    using pull_requests as p
    where t.pull_request = p.core_id
    returning 1
),
delete_pull_request_unlocks as (
    delete from pull_request_unlocks as t
    using pull_requests as p
    where t.pull_request = p.core_id
    returning 1
),
delete_jobs as (
    delete from jobs as t
    using job_contexts as jc, repos as r
    where t.context_id = jc.id and jc.repo = r.core_id
    returning 1
),
delete_job_contexts as (
    delete from job_contexts as t
    using repos as r
    where t.repo = r.core_id
    returning 1
),
delete_branch_commit_hashes as (
    delete from branch_commit_hashes as t
    using repos as r
    where t.repo = r.core_id
    returning 1
),
delete_change_dirspaces as (
    delete from change_dirspaces as t
    using repos as r
    where t.repo = r.core_id
    returning 1
),
delete_drift_schedules as (
    delete from drift_schedules as t
    using repos as r
    where t.repo = r.core_id
    returning 1
),
delete_drift_unlocks as (
    delete from drift_unlocks as t
    using repos as r
    where t.repo = r.core_id
    returning 1
),
delete_repo_configs as (
    delete from repo_configs as t
    where t.installation in (select i.core_id from installation as i)
        or t.repo in (select r.core_id from repos as r)
    returning 1
),
delete_code_indexes as (
    delete from code_indexes as t
    using installation as i
    where t.installation = i.core_id
    returning 1
),
delete_repo_trees as (
    delete from repo_trees as t
    using installation as i
    where t.installation = i.core_id
    returning 1
),
delete_repo_tree_builds as (
    delete from repo_tree_builds as t
    using installation as i
    where t.installation = i.core_id
    returning 1
),
delete_pull_requests_map as (
    delete from github_pull_requests_map as t
    using repositories as r
    where t.repository_id = r.id
    returning 1
),
delete_pull_requests as (
    delete from github_pull_requests as t
    using repositories as r
    where t.repository = r.id
    returning 1
),
delete_repositories_map as (
    delete from github_repositories_map as t
    using repositories as r
    where t.repository_id = r.id
    returning 1
),
delete_installation_repositories as (
    delete from github_installation_repositories as t
    using repositories as r
    where t.id = r.id
    returning 1
),
delete_kv_cache_keys as (
    delete from kv_store as t
    where left(t.namespace, 5) = 'cache'
        and right(t.namespace, 5) <> '.data'
        and left(t.key, length($installation_id::text) + 1) = $installation_id::text || '.'
    returning t.namespace, t.data
),
delete_kv_cache_data as (
    delete from kv_store as t
    using delete_kv_cache_keys as k
    where t.namespace = k.namespace || '.data'
        and to_jsonb(t.key) = k.data
        and not exists (
            select 1
            from kv_store as other
            where other.namespace = k.namespace
                and other.data = k.data
                and left(other.key, length($installation_id::text) + 1)
                    <> $installation_id::text || '.'
        )
    returning 1
),
delete_kv_installation as (
    delete from kv_store as t
    where t.namespace = 'github:' || $installation_id::text
    returning 1
),
delete_user_installations2 as (
    delete from github_user_installations2 as t
    where t.installation_id = $installation_id
    returning 1
),
delete_user_installations as (
    delete from github_user_installations as t
    where t.installation_id = $installation_id
    returning 1
),
delete_installations_map as (
    delete from github_installations_map as t
    where t.installation_id = $installation_id
    returning 1
),
delete_installation as (
    delete from github_installations as t
    where t.id = $installation_id
    returning t.org
),
delete_org as (
    delete from orgs as t
    using delete_installation as d
    where t.id = d.org
        and not exists (
            select 1
            from github_installations as other
            where other.org = t.id and other.id <> $installation_id
        )
    returning 1
)
select jsonb_build_object(
    'github_work_manifest_comments', (select count(*) from delete_work_manifest_comments),
    'github_unified_comments', (select count(*) from delete_unified_comments),
    'github_pull_request_dirspace_summaries', (select count(*) from delete_dirspace_summaries),
    'plans', (select count(*) from delete_plans),
    'workflow_step_outputs', (select count(*) from delete_workflow_step_outputs),
    'work_manifest_results', (select count(*) from delete_work_manifest_results),
    'work_manifest_dirspaceflows', (select count(*) from delete_work_manifest_dirspaceflows),
    'work_manifest_access_control_denied_dirspaces',
        (select count(*) from delete_work_manifest_access_control),
    'work_manifest_steps', (select count(*) from delete_work_manifest_steps),
    'flow_states', (select count(*) from delete_flow_states),
    'job_work_manifests', (select count(*) from delete_job_work_manifests),
    'drift_work_manifests', (select count(*) from delete_drift_work_manifests),
    'index_work_manifests', (select count(*) from delete_index_work_manifests),
    'compute_node_work', (select count(*) from delete_compute_node_work),
    'work_manifests', (select count(*) from delete_work_manifests),
    'pull_request_stacks', (select count(*) from delete_pull_request_stacks),
    'gates', (select count(*) from delete_gates),
    'gate_approvals', (select count(*) from delete_gate_approvals),
    'dirspace_pull_request_locks', (select count(*) from delete_dirspace_pull_request_locks),
    'pruned_dirspaces', (select count(*) from delete_pruned_dirspaces),
    'pull_request_unlocks', (select count(*) from delete_pull_request_unlocks),
    'jobs', (select count(*) from delete_jobs),
    'job_contexts', (select count(*) from delete_job_contexts),
    'branch_commit_hashes', (select count(*) from delete_branch_commit_hashes),
    'change_dirspaces', (select count(*) from delete_change_dirspaces),
    'drift_schedules', (select count(*) from delete_drift_schedules),
    'drift_unlocks', (select count(*) from delete_drift_unlocks),
    'repo_configs', (select count(*) from delete_repo_configs),
    'code_indexes', (select count(*) from delete_code_indexes),
    'repo_trees', (select count(*) from delete_repo_trees),
    'repo_tree_builds', (select count(*) from delete_repo_tree_builds),
    'github_pull_requests_map', (select count(*) from delete_pull_requests_map),
    'github_pull_requests', (select count(*) from delete_pull_requests),
    'github_repositories_map', (select count(*) from delete_repositories_map),
    'github_installation_repositories', (select count(*) from delete_installation_repositories),
    'kv_store',
        (select count(*) from delete_kv_cache_keys)
        + (select count(*) from delete_kv_cache_data)
        + (select count(*) from delete_kv_installation),
    'github_user_installations2', (select count(*) from delete_user_installations2),
    'github_user_installations', (select count(*) from delete_user_installations),
    'github_installations_map', (select count(*) from delete_installations_map),
    'github_installations', (select count(*) from delete_installation),
    'orgs', (select count(*) from delete_org)
)
