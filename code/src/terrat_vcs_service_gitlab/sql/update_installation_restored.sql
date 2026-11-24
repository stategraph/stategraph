-- The same transition as
-- code/src/sgs_service_orchestration/sql/update_gitlab_installation_restored.sql.
-- A change goes in both.
-- An uninstalled installation goes back to pending, so its next webhook
-- verifies it again.  An installation in any other state is unchanged.
update gitlab_installations as gi
set state = case when gi.state = 'uninstalled' then 'pending' else gi.state end,
    uninstalled_at = case when gi.state = 'uninstalled' then null else gi.uninstalled_at end,
    uninstalled_by = case when gi.state = 'uninstalled' then null else gi.uninstalled_by end
where gi.id = $installation_id
returning gi.state
