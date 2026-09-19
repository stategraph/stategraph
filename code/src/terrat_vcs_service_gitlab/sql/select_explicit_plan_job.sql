select
    id
from jobs
where jobs.context_id = $context_id
      and jobs.params->>'type' = 'plan'
      and jobs.params->>'tag_query' is not null
limit 1
