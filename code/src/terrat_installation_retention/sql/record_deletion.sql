update installation_deletions
set deleted_at = now(), deleted_rows = $deleted_rows
where provider = $provider and installation_id = $installation_id
