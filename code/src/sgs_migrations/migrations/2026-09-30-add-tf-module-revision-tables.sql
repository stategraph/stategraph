-- RFD 1008 Phase 3, "Scopes".  A scope is the root module, or one module.  Each
-- scope has one scope hash and one set of node hashes.  The root scope stays in
-- [revision_hashes] and [revision_tx_hashes]: the root blocks, the tfvars and
-- the path rows.  A module has one row of [tf_module_revision_hashes], with its
-- kind and its scope hash, and one row of [tf_module_revision_node_hashes] for
-- each node of its body.  A local module inside a remote package has the kind
-- [remote].
--
-- [key] is the revision key of the node, the same text as the [node_id] of its
-- log row.  A query finds the rows of a module by [source] and [version], and
-- not with the text of [key].
--
-- Each committed table has a foreign key to [tf_modules], thus the rows of a
-- module go with it.  The transaction twins have no foreign key to
-- [tf_modules], because the apply of the same transaction writes the module.
--
-- Backwards compatible: new tables only.
create table tf_module_revision_hashes (
    state_id uuid not null,
    source text not null,
    version text not null,
    kind text not null check (kind in ('local', 'remote')),
    hash text not null,
    primary key (state_id, source, version),
    foreign key (state_id, source, version)
        references tf_modules (state_id, source, version) on delete cascade
);

create table tf_module_revision_node_hashes (
    state_id uuid not null,
    source text not null,
    version text not null,
    key text not null,
    hash text not null,
    primary key (state_id, source, version, key),
    foreign key (state_id, source, version)
        references tf_modules (state_id, source, version) on delete cascade
);

create table tf_module_revision_tx_hashes (
    tx_id uuid not null references transactions (id),
    state_id uuid not null references states (id),
    source text not null,
    version text not null,
    kind text not null check (kind in ('local', 'remote')),
    hash text not null,
    primary key (tx_id, state_id, source, version)
);

create table tf_module_revision_tx_node_hashes (
    tx_id uuid not null references transactions (id),
    state_id uuid not null references states (id),
    source text not null,
    version text not null,
    key text not null,
    hash text not null,
    primary key (tx_id, state_id, source, version, key)
);
