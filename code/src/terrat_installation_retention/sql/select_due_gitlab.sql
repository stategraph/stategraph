-- The installations whose deletion is due: on the schedule past their
-- [delete_after], without a hold, not deleted, and still uninstalled.
select d.installation_id
from installation_deletions as d
inner join gitlab_installations as gi on gi.id = d.installation_id
where d.provider = 'gitlab'
    and d.deleted_at is null
    and d.hold is null
    and d.delete_after <= now()
    and gi.state = 'uninstalled'
order by d.delete_after, d.installation_id
limit $limit
