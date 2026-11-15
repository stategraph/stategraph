-- The current day and the next: the horizon the migration seeds and the daily retention task
-- re-creates when missing, so days roll forward without an operator.  The bounds are days, not
-- instants, and the label is the zero-padded day of the year --
-- [DDD], not [DD], which is the day of the month and would collide twelve times a year -- and
-- [YYYY], not [IYYY], whose ISO year boundary would give 2025-12-31 and 2026-12-31 one label.
-- The migration and the task must share this one expression: a second expression of the label
-- rule in OCaml would be a second statement of the naming rule, which the database conventions
-- make a mandatory differential test.
select date_trunc('day', now())::date::text,
       (date_trunc('day', now()) + interval '1 day')::date::text,
       to_char(date_trunc('day', now()), 'YYYY"d"DDD')
union all
select (date_trunc('day', now()) + interval '1 day')::date::text,
       (date_trunc('day', now()) + interval '2 days')::date::text,
       to_char(date_trunc('day', now()) + interval '1 day', 'YYYY"d"DDD')
