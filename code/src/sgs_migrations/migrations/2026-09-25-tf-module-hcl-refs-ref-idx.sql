-- RFD 1008 Phase 2: the committed blocks of a body that name one address.  A plan
-- and an apply ask it for each block the transaction deletes, to find the
-- instances whose hints the delete can change ([sql/subgraph2/committed_readers.sql]).
-- [hcl_refs] has the same index for the root, [hcl_refs_state_ref_idx].
--
-- Backwards compatible: an index only.
create index if not exists tf_module_hcl_refs_state_body_ref_idx
    on tf_module_hcl_refs (state_id, source, version, ref);
