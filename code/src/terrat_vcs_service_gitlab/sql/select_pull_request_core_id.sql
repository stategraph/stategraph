-- The core id of the pull request: what the orchestration names Stategraph as the pull request of an
-- apply, the key of the hold of its commits (#3179), the same for every provider.
select core_id
from gitlab_pull_requests_map
where repository_id = $repository and pull_number = $pull_number
