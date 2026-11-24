-- Puts each closed tenant that is not on the schedule on it.  The deletion is due [days] after the
-- tenant was closed, and never sooner than [notice_days] after it went on the schedule.
insert into tenant_deletions (tenant_id, ended_at, delete_after)
select
    t.id,
    t.ended_at,
    greatest(t.ended_at + $days * interval '1 day', now() + $notice_days * interval '1 day')
from tenants as t
where t.ended_at is not null
on conflict (tenant_id) do nothing
returning tenant_id
