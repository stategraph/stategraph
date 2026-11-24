-- Takes the installations that are no longer uninstalled off the schedule.  A
-- deleted installation keeps its row as the record of the deletion.
delete from installation_deletions as d
where d.provider = 'gitlab'
    and d.deleted_at is null
    and not exists (
        select 1
        from gitlab_installations as gi
        where gi.id = d.installation_id and gi.state = 'uninstalled'
    )
returning d.installation_id
