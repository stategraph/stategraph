-- The result of a queued or running work manifest is evaluated with the refs of its run pinned, and
-- a pinned evaluation cannot build a config again, thus the built configs of the commit and of the
-- base commit of such a work manifest stay.  The key of a built config is the commit followed by
-- [:] and the hash of the raw config.
with
in_flight as (
    select sha from work_manifests where state in ('queued', 'running')
    union
    select base_sha from work_manifests where state in ('queued', 'running')
)
delete from repo_configs
where (kind = 'built'
       and (now() - created_at) > interval '14 days'
       and split_part(repo_configs.sha, ':', 1) not in (select sha from in_flight))
   or (kind = 'derived' and (now() - created_at) > interval '90 days')
