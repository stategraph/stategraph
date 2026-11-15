-- The rows of [repo_trees_default] older than the cutoff day: no partition of their day will
-- exist again, so re-housing them is not on offer.
delete from repo_trees_default
where cache_day < current_date - $days
