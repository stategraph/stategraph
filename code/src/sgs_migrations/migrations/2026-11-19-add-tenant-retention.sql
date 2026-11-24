-- [tenants.ended_at] is the time a tenant admin closed the tenant; a closed tenant refuses every
-- request but its reopen, which clears it.
--
-- [tenant_deletions] is the schedule of the deletions of the data of closed tenants and the record
-- of each deletion.  The daily tenant retention task makes a row when it first sees a tenant
-- closed: [delete_after] is the earliest time of its deletion, and a tenant with a [hold] is not
-- deleted.  After the deletion, [deleted_at] and the number of deleted rows of each table stay as
-- the record of the deletion; the row names no customer data, and no foreign key ties it to the
-- deleted tenant.
--
-- Backwards compatible: a nullable column that no older reader selects, and a new table.
alter table tenants add column ended_at timestamp with time zone;

create table tenant_deletions (
    tenant_id uuid primary key,
    ended_at timestamp with time zone not null,
    scheduled_at timestamp with time zone not null default now(),
    delete_after timestamp with time zone not null,
    hold text,
    deleted_at timestamp with time zone,
    deleted_rows jsonb
);

create index tenant_deletions_due_idx on tenant_deletions (delete_after) where deleted_at is null;

create index tenant_deletions_deleted_at_idx on tenant_deletions (deleted_at)
    where deleted_at is not null;
