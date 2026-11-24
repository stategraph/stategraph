-- The same transition as
-- code/src/sgs_service_orchestration/sql/update_gitlab_installation_uninstalled.sql.
-- A change goes in both.
-- An installation that is already uninstalled keeps the time and the user of
-- its uninstall.
update gitlab_installations as gi
set state = 'uninstalled',
    uninstalled_at = case when gi.state = 'uninstalled' then gi.uninstalled_at else now() end,
    uninstalled_by = case
        when gi.state = 'uninstalled' then gi.uninstalled_by
        else (select 'gitlab:' || gu.username from gitlab_users2 as gu where gu.user_id = $user_id)
    end
where gi.id = $installation_id
returning gi.state
