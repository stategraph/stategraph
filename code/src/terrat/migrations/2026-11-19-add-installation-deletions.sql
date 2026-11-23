-- The schedule of the deletions of the data of uninstalled installations, and
-- the record of each deletion.
--
-- A row is made when the daily retention task first sees an installation
-- uninstalled.  [ended_at] is when it was uninstalled, or when the task first
-- saw it when the installation carries no uninstall time.  [delete_after] is the
-- earliest time of its deletion.  An installation with a [hold] is not deleted.
-- After the deletion, [deleted_at] and the number of deleted rows of each table
-- stay as the record of the deletion; the row names no customer data.
--
-- Backwards compatible: it adds a table that nothing else reads.
create table installation_deletions (
    provider text not null,
    installation_id bigint not null,
    ended_at timestamp with time zone not null,
    scheduled_at timestamp with time zone not null default (now()),
    delete_after timestamp with time zone not null,
    hold text,
    deleted_at timestamp with time zone,
    deleted_rows jsonb,
    primary key (provider, installation_id)
);

create index installation_deletions_due_idx on installation_deletions (delete_after)
    where deleted_at is null;

create index installation_deletions_deleted_at_idx on installation_deletions (deleted_at)
    where deleted_at is not null;
