-- The rows [repo_tree_builds_default] holds in [[$from, $to)]: zero makes the day a plain empty
-- partition, non-zero makes it the drain sequence.
select count(*)
from repo_tree_builds_default
where cache_day >= $from::date and cache_day < $to::date
