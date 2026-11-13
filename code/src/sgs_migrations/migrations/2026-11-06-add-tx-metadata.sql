-- The metadata of a transaction (#3179): what the server records about it for the layer that
-- drives it, as a JSON object. The server alone writes it, never the API, unlike tags, which the
-- client sets: the conflict checks trust it. Backwards compatible: older code neither reads nor
-- writes it, and the constant default adds the column without rewriting the table. Its JSON field:
--
-- - hold: the key of the transaction's hold, an opaque string the holder chooses, given with the
--   reservation (update_tx_reserve.sql), removed if the reservation is released before the commit
--   (update_tx_release_reserved.sql), kept by the commit. A committed transaction with a hold
--   stands against every overlapping transaction but one reserved under the same key
--   (select_tx_conflicts.sql), until the holder releases the key (update_tx_release_held.sql). The
--   server knows nothing of what the key names: the orchestration keys the hold by the pull request
--   of the apply and releases it when that pull request merges, is closed or is unlocked, so that a
--   plan of another branch, which lacks the change, does not revert it; a transaction committed
--   outside the orchestration holds nothing. A failed commit holds nothing either, by its state:
--   the repair of what it left must not be refused.
alter table transactions add column metadata jsonb not null default '{}';

-- Every key and value of the metadata is indexed, for containment (@>) and key existence (?): a
-- field added later, by the orchestration or by a user building on the column, is looked up without
-- a migration.  The holds of a key, released together (update_tx_release_held.sql), are one
-- containment probe.
create index transactions_metadata_idx on transactions using gin (metadata);

-- The tags, the object the client sets, are indexed the same way: a lookup by tag, through MQL or a
-- layer of the user's, is a containment probe.
create index transactions_tags_idx on transactions using gin (tags);

-- A held commit is matched by fq_address, the HCL-shape address, whatever the kind of node
-- (select_tx_conflicts.sql). State nodes carried their instance address alone until now; the
-- reifier writes their fq_address from here on (insert_reifier_state_subgraph.sql), and the rows
-- already written take it from the resource or output they name.  A state node whose resource was
-- destroyed since keeps its item as it was: the hold is new, so no held commit predates this, and
-- such a row only meets the item equality of the existing conflict arm against a transaction in
-- flight across this migration.
update transaction_subgraphs as ts
set item = ts.item || jsonb_build_object('fq_address', r.fq_address)
from resources as r
where ts.node_type = 'state'
  and not (ts.item ? 'fq_address')
  and ts.item->>'kind' = 'resource'
  and r.state_id = ts.state_id
  and r.address = ts.item->>'address';

update transaction_subgraphs
set item = item || jsonb_build_object('fq_address', item->>'address')
where node_type = 'state'
  and not (item ? 'fq_address')
  and item->>'kind' = 'output';
