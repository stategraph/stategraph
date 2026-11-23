-- Deletes every row of one GitLab installation and answers the number of rows
-- it deleted from each table.  The caller holds the lock of lock_due_gitlab.sql,
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
-- is one statement, at least 30 days after the uninstall.  Users are kept: a
-- user can belong to other installations, so only the links of the users to
-- this installation go.
--
-- kv_store holds two kinds of rows of an installation.  A row of a
-- `cache<version>.<name>` namespace has a key that starts with the installation
-- id and a value that is the content hash of a row of the `<namespace>.data`
-- namespace.  A content row is shared by every installation whose rows name its
-- hash, so it goes only when no row of another installation names it.  A row of
-- the `gitlab:<installation id>` namespace is the installation's own.
with
installation as (
    select gim.core_id
    from gitlab_installations_map as gim
    where gim.installation_id = $installation_id
),
repositories as (
    select gir.id
    from gitlab_installation_repositories as gir
    where gir.installation_id = $installation_id
),
repos as (
    select grm.core_id
    from gitlab_repositories_map as grm
    inner join repositories as r on r.id = grm.repository_id
),
pull_requests as (
    select gprm.core_id
    from gitlab_pull_requests_map as gprm
    inner join repositories as r on r.id = gprm.repository_id
),
work_manifest_ids as (
    select wm.id
    from work_manifests as wm
    inner join repos as r on r.core_id = wm.repo
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
    delete from gitlab_pull_requests_map as t
    using repositories as r
    where t.repository_id = r.id
    returning 1
),
delete_pull_requests as (
    delete from gitlab_pull_requests as t
    using repositories as r
    where t.repository = r.id
    returning 1
),
delete_repositories_map as (
    delete from gitlab_repositories_map as t
    using repositories as r
    where t.repository_id = r.id
    returning 1
),
delete_installation_repositories as (
    delete from gitlab_installation_repositories as t
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
    where t.namespace = 'gitlab:' || $installation_id::text
    returning 1
),
delete_user_installations2 as (
    delete from gitlab_user_installations2 as t
    where t.installation_id = $installation_id
    returning 1
),
delete_installations_map as (
    delete from gitlab_installations_map as t
    where t.installation_id = $installation_id
    returning 1
),
delete_installation as (
    delete from gitlab_installations as t
    where t.id = $installation_id
    returning 1
)
select jsonb_build_object(
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
    'gitlab_pull_requests_map', (select count(*) from delete_pull_requests_map),
    'gitlab_pull_requests', (select count(*) from delete_pull_requests),
    'gitlab_repositories_map', (select count(*) from delete_repositories_map),
    'gitlab_installation_repositories', (select count(*) from delete_installation_repositories),
    'kv_store',
        (select count(*) from delete_kv_cache_keys)
        + (select count(*) from delete_kv_cache_data)
        + (select count(*) from delete_kv_installation),
    'gitlab_user_installations2', (select count(*) from delete_user_installations2),
    'gitlab_installations_map', (select count(*) from delete_installations_map),
    'gitlab_installations', (select count(*) from delete_installation)
)
