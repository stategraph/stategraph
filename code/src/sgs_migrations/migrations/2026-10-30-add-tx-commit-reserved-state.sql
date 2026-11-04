-- The 'commit-reserved' transaction state: a previewed transaction that an orchestrated apply is
-- about to commit.  The orchestration reserves the transaction when it creates the apply's work
-- manifest and releases it when that work manifest ends; the commit moves it on to 'committing' as
-- it moves a previewed one.  While reserved, and for an hour at most (select_tx_conflicts.sql), the
-- transaction stands against overlapping commits as a committing one does, which closes the window
-- between the orchestration's check of the apply and the commit itself.  In flight, so completed_at
-- stays null.  reserved_by is the holder the orchestration names, the id of its work manifest;
-- reserved_at bounds a reservation nobody released.  Backwards compatible: older code never writes
-- the new value.
insert into transaction_states (id) values ('commit-reserved');

alter table transactions add column reserved_at timestamp with time zone;

alter table transactions add column reserved_by text;

alter table transactions drop constraint transactions_check;

alter table transactions add constraint transactions_check
  check (
    (state in ('open', 'previewing', 'previewed', 'commit-reserved', 'committing') and completed_at is null)
    or (state in ('aborted', 'failed', 'failed-committed', 'committed') and completed_at is not null)
  );

alter table transactions add constraint transactions_reserved_check
  check (state <> 'commit-reserved' or (reserved_at is not null and reserved_by is not null));

create index transactions_reserved_by_idx on transactions (reserved_by) where reserved_by is not null
