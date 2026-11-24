-- Puts each uninstalled installation that is not on the schedule on it.  An
-- installation without an uninstall time ended when the task first saw it.
-- The deletion is due [days] after the end, and never sooner than
-- [notice_days] after the installation went on the schedule.
insert into installation_deletions (provider, installation_id, ended_at, delete_after)
select
    'github',
    gi.id,
    coalesce(gi.uninstalled_at, now()),
    greatest(
        coalesce(gi.uninstalled_at, now()) + $days * interval '1 day',
        now() + $notice_days * interval '1 day'
    )
from github_installations as gi
where gi.state = 'uninstalled'
on conflict (provider, installation_id) do nothing
returning installation_id
