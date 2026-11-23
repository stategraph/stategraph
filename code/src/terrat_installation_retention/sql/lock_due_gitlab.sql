-- Locks one installation whose deletion is due, and its schedule row, for the
-- transaction of its deletion.  No row: the deletion is no longer due.
select d.installation_id
from installation_deletions as d
inner join gitlab_installations as gi on gi.id = d.installation_id
where d.provider = 'gitlab'
    and d.installation_id = $installation_id
    and d.deleted_at is null
    and d.hold is null
    and d.delete_after <= now()
    and gi.state = 'uninstalled'
for update of d, gi
