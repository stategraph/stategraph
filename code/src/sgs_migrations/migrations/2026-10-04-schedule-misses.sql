-- How many times a scheduled task has triggered with nobody registered to run it. The dispatcher
-- records a miss on every trigger, re-runs the task on its next schedule, and deletes the row when
-- the count reaches three.

alter table schedules add column misses integer not null default 0;
