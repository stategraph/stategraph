-- The in-horizon days that hold rows in [repo_trees_default]: the days the drain re-houses.
-- Days older than the cutoff day are not candidates -- the expired-rows statement deletes
-- them; they are retention-expired data that missed their partition, not data to re-house.
select distinct
  cache_day::text,
  (cache_day + 1)::text,
  to_char(cache_day, 'YYYY"d"DDD')
from repo_trees_default
where cache_day >= current_date - $days
