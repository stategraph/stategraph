-- RFD 1008 Phase 2: a module body is stored one time, in [tf_module_hcl], and
-- the calls of the module use that one body.
--
-- The transaction log gets two object types.  [tf_module_hcl] is a block of a
-- module body, keyed by its revision key (the module, then the id of the block
-- relative to the module), because two modules can hold one relative id.
-- [module] is a row of [tf_modules].  A file read is a fact of a call and not of
-- a body: the reads of a path travel in the [file_set] of the path, and the apply
-- writes each read into [filepath_refs].
--
-- A [module] block that calls a local module names the module it reaches in
-- [child_source] and [child_version], in [hcl] for a call of the root and in
-- [tf_module_hcl] for a call inside a body.  [module_input_edges] holds the reads
-- of each argument of the call, with the label of a child call split out, and
-- [module_input_files] the call key of each file read inside an argument; the
-- subgraph walk joins on both.
--
-- An edge that reads an output of a child call names the label of that call in
-- [to_call].  [ref] keeps the address as the block writes it, thus the unique
-- index of [hcl_refs] and every reader of [ref] stay as they are.
--
-- [tf_module_hcl_hints] holds the local form of the hints of a body block, one
-- row for each block: the naming channels the client sends, which are node-local
-- and relative to the body.  Every other form of a hint of a body block depends on
-- the call, so the subgraph walk makes it at the call and nothing stores it.
--
-- [filepath_refs] names the block that reads a file by its call path and its id,
-- in two columns.  For a block of a body, [id] is relative to the module, and the
-- module is in [body_source] and [body_version].  The foreign key to [hcl] holds
-- for a block of the root only, through [root_id]; the foreign key to
-- [tf_module_hcl] holds for a block of a body.  Each row holds its read: the
-- call key and the collector fields of [Sg_tf_eval_files.File_ref.wire].  The
-- unique key gets the call path, the module and the call key, because one block
-- reads one path at each call with each of its call sites, and a call whose
-- source moves reads through a block of another module while the apply removes
-- the row of the old one.
--
-- [files] holds a row for each path that a read names, also when no file is at
-- the path: an absent file, or a folder.  Such a row has [present] false and
-- empty [content].
--
-- Backwards compatible.  Each column is new and nullable or has a default, the
-- unique index of [hcl_refs] does not change, and a row that a server before this
-- phase writes into [filepath_refs] is a row of the root, which satisfies both
-- foreign keys and the new unique key.

insert into transaction_log_actions (id)
values ('module_set'), ('module_delete');

insert into transaction_log_object_types (id)
values ('tf_module_hcl'), ('module');

create unique index transaction_logs_tf_module_hcl_unique_idx
    on transaction_logs (tx_id, state_id, (data->>'node_id'))
    where object_type = 'tf_module_hcl';

create unique index transaction_logs_module_unique_idx
    on transaction_logs (tx_id, state_id, (data->>'node_id'))
    where object_type = 'module';

alter table hcl
    add column child_source text,
    add column child_version text,
    add column module_input_edges jsonb,
    add column module_input_files jsonb;

alter table tf_module_hcl
    add column child_source text,
    add column child_version text,
    add column module_input_edges jsonb,
    add column module_input_files jsonb;

alter table hcl_refs add column to_call text;

alter table tf_module_hcl_refs add column to_call text;

create table tf_module_hcl_hints (
    state_id uuid not null,
    source text not null,
    version text not null,
    id text not null,
    local jsonb not null,
    primary key (state_id, source, version, id),
    foreign key (state_id, source, version, id)
        references tf_module_hcl (state_id, source, version, id) on delete cascade
);

alter table filepath_refs
    add column call_path text[] not null default '{}',
    add column body_source text,
    add column body_version text,
    add column call_key text,
    add column file_function text,
    add column refs jsonb,
    add column template_vars jsonb,
    add column fileset_rel text,
    add column inlined_file_expr text;

alter table files add column present boolean not null default true;

alter table filepath_refs
    add column root_id text generated always as
        (case when body_source is null then id end) stored;

alter table filepath_refs drop constraint filepath_refs_state_id_id_fkey;

alter table filepath_refs
    add constraint filepath_refs_root_fkey
        foreign key (state_id, root_id) references hcl (state_id, id);

alter table filepath_refs
    add constraint filepath_refs_body_fkey
        foreign key (state_id, body_source, body_version, id)
        references tf_module_hcl (state_id, source, version, id) on delete cascade;

drop index filepath_refs_unique_idx;

create unique index filepath_refs_unique_idx
    on filepath_refs (
        state_id, call_path, body_source, body_version, id, filepath, coalesce(template_var, ''),
        coalesce(call_key, '')
    ) nulls not distinct;

create index filepath_refs_body_idx
    on filepath_refs (state_id, body_source, body_version, id)
    where body_source is not null;
