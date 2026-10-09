-- RFD 1008 Phase 2: a taint is per call site.  A block of a module body is one row
-- of [tf_module_hcl] whatever calls it, and an apply that fails leaves the
-- infrastructure of one call inconsistent, not of each call.  Thus [hcl_tainted]
-- names the tainted block by its call path and its body id, with the same foreign
-- keys as [filepath_refs]: to [hcl] for a block of the root, through [root_id], and
-- to [tf_module_hcl] for a block of a body.
--
-- [id] stays the key.  It is the id of the INSTANCE, which the walk builds from the
-- call path and the body id, and it is the id of the block for a block of the root.
-- [revision_key] is the key of the block in [revision_hashes], which the next plan
-- compares: the id of the block for the root, and the key of the body block for a
-- body.  The server computes both in OCaml.
--
-- Backwards compatible.  Each column is new and nullable or has a default, the
-- primary key does not change, and a row that a server before this phase writes is
-- a row of the root, which satisfies both foreign keys.
alter table hcl_tainted
    add column call_path text[] not null default '{}',
    add column body_source text,
    add column body_version text,
    add column body_id text,
    add column revision_key text,
    add column root_id text generated always as (
        case when body_source is null then id end
    ) stored;

alter table hcl_tainted drop constraint hcl_tainted_state_id_id_fkey;

alter table hcl_tainted
    add constraint hcl_tainted_root_fkey
        foreign key (state_id, root_id) references hcl (state_id, id) on delete cascade;

alter table hcl_tainted
    add constraint hcl_tainted_body_fkey
        foreign key (state_id, body_source, body_version, body_id)
        references tf_module_hcl (state_id, source, version, id) on delete cascade;

create index hcl_tainted_body_idx
    on hcl_tainted (state_id, body_source, body_version, body_id)
    where body_source is not null;
