-- RFD 1008 Phase 0: hints move off the [hcl] row into tables of their own.
--
-- Why a table and not the column it replaces.  Phase 0 makes a hint node-local
-- and body-relative, and the server derives and expands it instead of the
-- client.  That expansion writes a row for every node in the affected set, which
-- is the nodes of the transaction plus every node that transitively references
-- one of them -- and the consumers are, by construction, outside the
-- transaction.  Today no runtime code writes an [hcl] row outside the
-- transaction: [insert into hcl] is bounded by [tx_rows]
-- (update_state_apply_tx.sql).  Writing expansions into [hcl.hints] would break
-- that property, which several statements depend on.  A separate table keeps it.
--
-- Two forms, two columns.  [local] is the source of truth: the node's own hint,
-- in the coordinates of the body that wrote it, naming its neighbours instead of
-- holding copies of them.  [expanded] is a cache of what that becomes once the
-- instance is supplied and every named neighbour is substituted -- byte for byte
-- what the client used to upload.  A cache, so it is nullable: a row whose
-- [expanded] is null has not been expanded since its [local] last moved, and the
-- expansion fills it.
--
-- The key is (state_id, id) and not an instance path.  Phase 0 does not collapse
-- the rows.  A node keeps its own [hcl] row, and [id], [fq_address] and
-- [module_address] still carry the call site, so [id] is still unique for each
-- call and the instance an expansion needs is the row's own [module_address]
-- column.  The later phases move the body into [tf_module_hcl] and change one
-- thing: where that instance comes from.  The hint form does not change again.
--
-- Backwards compatible.  This migration only adds.  [hcl.hints] and
-- [transaction_subgraph_nodes.hints] stay exactly as they are and keep being
-- written and read, so a server running the previous code against a migrated
-- database is unaffected.  Dropping the column belongs to a later migration,
-- after every reader has moved.

create table hcl_hints (
  state_id uuid not null references states (id),
  id text not null,
  local jsonb not null,
  expanded jsonb,
  primary key (state_id, id)
);

-- The transaction side of the same pair.  It is a real table and not a TEMP
-- [on commit drop] one for the reason setup.sql states: build-scoped working
-- state is TEMP, and anything that must outlive the build that produced it is a
-- real table.  The expansion runs at the preview, and the commit reads what it
-- wrote.
--
-- Its lifetime is the transaction's, exactly as transaction_subgraph_nodes': it
-- is deleted when the tx reaches a terminal state (commit finalize, runtime
-- failure, timeout) and cascaded on state hard-delete.
create table transaction_hints (
  tx_id uuid not null references transactions (id),
  state_id uuid not null references states (id),
  id text not null,
  local jsonb not null,
  expanded jsonb,
  primary key (tx_id, state_id, id)
);

-- Cascade target for hard_delete_state.sql, which deletes by state_id.
create index transaction_hints_state_id_idx on transaction_hints (state_id);

-- High-churn, for the same reason transaction_subgraph_nodes is: every
-- transaction bulk-inserts its whole affected set and later bulk-deletes it on
-- the tx's terminal state.  Default autovacuum (scale_factor 0.2) would let dead
-- tuples accumulate to a large fraction of a moving target before reclaiming.
-- Pin the scale factors to 0 and trigger on absolute row counts, so vacuum
-- reclaims promptly and independently of table size.
alter table transaction_hints set (
  autovacuum_vacuum_scale_factor = 0.0,
  autovacuum_vacuum_threshold = 20000,
  autovacuum_vacuum_insert_scale_factor = 0.0,
  autovacuum_vacuum_insert_threshold = 20000,
  autovacuum_analyze_scale_factor = 0.0,
  autovacuum_analyze_threshold = 20000
);
