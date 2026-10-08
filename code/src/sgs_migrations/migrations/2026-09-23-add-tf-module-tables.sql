-- RFD 1008 Phase 1: the Terraform module tables.
--
-- Stategraph has no table that connects a module call site to the module body it
-- reaches.  These three tables are that place.  [tf_modules] holds one row for
-- each module a state imports, [tf_module_hcl] holds the blocks of its body, and
-- [tf_module_hcl_refs] holds the edges inside that body.
--
-- The key is (state_id, source, version).  [source] is the identity of the
-- module: for a remote module the text of the call's [source] argument, and for a
-- local module its path after resolution, so two calls of [./child] from two
-- directories give two keys.  [version] is the call's [version] argument, or ''
-- when the HCL gives none.  Each state has its own set of modules.  [created_at]
-- records when the module was imported.
--
-- A body carries no call site.  The two body tables mirror [hcl] and [hcl_refs]
-- less the columns that belong to a call: [module_address] and [module_source]
-- name it; [file_refs] is a path resolved for it, and RFD 1008 Phase 2 keeps a
-- file read in [files] and [filepath_refs]; [remote_tf_state_refs] and
-- [remote_state_id] are a remote state resolved for it, and two calls with two
-- arguments can resolve two states.  One body row then serves every call of the
-- module.
--
-- Backwards compatible.  This migration only creates tables.  No code reads or
-- writes them yet; Phase 2 moves module bodies into them and Phase 3 imports
-- remote modules into them.

create table tf_modules (
  state_id uuid not null references states (id),
  source text not null,
  version text not null,
  created_at timestamptz not null default now(),
  primary key (state_id, source, version)
);

create table tf_module_hcl (
  state_id uuid not null,
  source text not null,
  version text not null,
  id text not null,
  fq_address text not null,
  data jsonb not null,
  refs text[] not null,
  depends_on_addresses text[] not null default '{}',
  module_inputs jsonb,
  module_input_refs jsonb,
  path_attrs jsonb,
  source_file text,
  source_start_line int,
  source_end_line int,
  unconditional_seed boolean,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (state_id, source, version, id),
  foreign key (state_id, source, version)
    references tf_modules (state_id, source, version) on delete cascade
);

create table tf_module_hcl_refs (
  state_id uuid not null,
  source text not null,
  version text not null,
  id text not null,
  ref text not null,
  attr_path text[] not null default '{}',
  index_kind text,
  index_val jsonb,
  is_bare bool not null default true,
  resolvable bool not null default true,
  from_depends_on bool not null default false,
  ref_state_id uuid,
  foreign key (state_id, source, version, id)
    references tf_module_hcl (state_id, source, version, id) on delete cascade
);

-- The identity of an edge, the same as [hcl_refs_uniq_with_ref_state_idx] with
-- the module key in front.  The table is new and empty, so the index does not
-- need [concurrently].
create unique index tf_module_hcl_refs_uniq_idx
  on tf_module_hcl_refs (
    state_id, source, version, id, ref, attr_path, from_depends_on, ref_state_id
  ) nulls not distinct
