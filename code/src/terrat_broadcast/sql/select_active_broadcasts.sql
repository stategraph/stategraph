select level, message from broadcasts
where now() < ends_at and (vcs is null or vcs = $vcs)
order by created_at, id
