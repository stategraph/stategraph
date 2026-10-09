-- RFD 1008 Phase 3, "The fileset hint".  A new member of a folder has no path
-- row, thus no content node and no presence node shows it.  The fileset hint of
-- an instance shows it: a list of entries, one for each [fileset(dir, pattern)]
-- call with concrete values.
--
-- The entry travels on the read of each member of the folder.  [filepath_refs]
-- keeps it on each read, in [fileset_dir] and [fileset_pattern].  The commit
-- then writes the entries of each instance into [hcl_hints.filesets], from the
-- reads that stay: an entry stays while one or more of its members stay.
--
-- Backwards compatible: new nullable columns only.
alter table filepath_refs
    add column fileset_dir text,
    add column fileset_pattern text;

alter table hcl_hints add column filesets jsonb;

-- The commit reads the folder reads of a state, and the instances whose stored
-- hint holds entries: a few rows of a large state.
create index filepath_refs_fileset_idx
    on filepath_refs (state_id)
    where fileset_dir is not null;

create index hcl_hints_filesets_idx
    on hcl_hints (state_id)
    where filesets is not null;
