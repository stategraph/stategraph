-- The same transition as
-- code/src/terrat_vcs_service_gitlab/sql/update_installation_uninstalled.sql.
-- A change goes in both.
-- An installation that is already uninstalled keeps the time and the user of
-- its uninstall.
update terrateam_admin.gitlab_installations as gi
set state = 'uninstalled',
    uninstalled_at = case when gi.state = 'uninstalled' then gi.uninstalled_at else now() end,
    uninstalled_by = case when gi.state = 'uninstalled' then gi.uninstalled_by else $uninstalled_by end
where gi.id = $group_id
returning gi.name, gi.state
