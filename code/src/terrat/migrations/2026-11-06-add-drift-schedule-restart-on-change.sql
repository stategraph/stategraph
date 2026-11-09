-- Whether a drift reconcile whose files changed while it ran reconciles again.
alter table drift_schedules add column if not exists restart_on_change boolean not null default true
