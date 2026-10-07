(** The Stategraph state schema version this build understands.

    This versions the shape of the data Stategraph derives from a config and stores against a state
    — it is neither the Terraform provider schema version ([instances.schema_version]) nor the TF
    state file format version ([states_metadata.version]).

    Bump this whenever a representation change cannot be expressed as a DB migration because the new
    data is computed from the original config rather than from rows the server already holds
    ([hcl.file_refs], [hcl.path_attrs], [hcl.hints] and [files.mode] are all of that kind). A state
    whose [states.schema_version] is below this value is behind and must be re-imported before it is
    operated on.

    Version 2 adds [files.mode], the permission bits a collected file had in the checkout: the
    migration can only default it, and the real value lives on the client's disk.

    Version 3 adds the module-output reference hints a comprehension over a module collection
    contributes ([{for k, sa in module.X : ... sa.attr ...}]). They are derived by the client's
    ref-hints visitor from the whole configuration — it takes both the module's iterated-ness and
    its declared outputs to know what such a read names — so no migration over stored rows can
    produce them. Without the re-import, a state keeps the incomplete edges written before the fix:
    the consuming node is admitted to a plan subgraph while the outputs it reads are not, and the
    reified bundle drops those outputs and no longer parses.

    Version 4: [hcl_refs]' key gained [ref_state_id]. Before that, a node reading two remote states
    that export the same output name persisted only one of the two reads. A node only heals when a
    later transaction rewrites it ([insert_remote_refs] replaces a touched node's remote refs
    wholesale), so untouched nodes would stay wrong indefinitely; re-encoding the config rewrites
    every node of the state and writes both reads.

    Version 5: per-attribute subgraph generation. A node now carries [realized_object] and
    [object_attr_refs] hints (see {!Sgs_tx_log.stored_hints_of_wire}), which the client computes
    from the config and the server cannot derive from the rows it already holds. A state ingested
    before this has none, and a missing [object_attr_refs] is read as "no narrowing known" rather
    than as a narrower truth, so such a state silently loses the per-attribute narrowing until it is
    re-encoded.

    A cross-state entry additionally carries the data source it was read through, and the state that
    resolves to. Same story, one level down: without them a consumer reading same-named outputs from
    two producers cannot say which entry belongs to which, and every entry is consulted on every
    producer's edge. No separate version for it — nothing here has shipped, so the re-encode 5
    already forces is the one that writes these too.

    Version 6: instance-granular [for_each] pruning (RFD 1562). A node now also carries [for_each],
    [for_each_refs] and [for_each_body_refs] — the block's collection as an object canon plus which
    instances a consumer demands — and, like the 1162 hints above, they are canonicalized from the
    config by the client rather than recoverable from stored rows. A state ingested before this
    declares no collection, so the diff that decides which instances changed has nothing to compare
    against until it is re-encoded.

    Version 7: hints on data sources (RFD 584). The per-attribute and [for_each] hints of 5 and 6
    were suppressed whenever the value they describe depends on a data source, because a data source
    cannot be evaluated at encode time. Data source refresh gives that value a home in the database,
    so the hints become usable and are emitted — which also makes a [data] block a fourth node kind
    that holds a value the rest of the config reads through, alongside [locals], [variable] and
    [output]. Computed from the config by the client, so not back-fillable.

    A state ingested before this carries no hint on any data source, and the refresh step's fail
    safe reads a missing hint as "no narrowing known" and admits every consumer of that data source.
    So a stale state stays correct and merely over-reifies — but it gets none of the feature until
    it is re-encoded, which is what this bump forces.

    Version 8: the output path of a file-producing data source
    ({!Sg_resource_path_attrs.write_path_attrs_of_data_source_type} — [archive_file]'s
    [output_path]). The client now records it as an [attached_path_file] write ref, exactly as it
    already did for a managed write-file resource's [filename], and the server turns that ref into
    the capture target the actuator reads the produced archive back from.

    Not back-fillable, for the usual reason: the ref carries the path resolved against the block's
    own [path.*] anchor plus the canon that anchor reduced to, both of which come from evaluating
    the config. The server holds neither — [archive_file.output_path] was classified as a write path
    and deliberately never collected, so there is no row to derive it from.

    A state ingested before this names no capture target for its archives, so nothing carries the
    zip out of the plan sandbox and the apply opens a path nothing created. Unlike 7, a stale state
    here is not merely under-featured: it is the field failure this bump exists to close.

    Version 9: the all-outputs edge of a read that names a module but no output — [module.X] whole,
    or a dynamically indexed [module.X[expr]]. Such a read depends on every output the module
    declares, and the only edge it used to earn pointed at the call block, which a walk refuses as a
    reference-edge origin (a block is admitted by containment, so originating from it would drag in
    every consumer of every output and defeat RFD 1162's narrowing at every module boundary). The
    consumer was therefore never admitted when the module it reads changed, and its resources went
    missing from the plan.

    The client now emits a second edge to that block carrying
    {!Sg_tf_references.module_all_outputs_attr}, which the walk matches against any output node of
    the module. Derived from the reference shape at encode time, so no migration over stored rows
    can produce it: a state ingested before this holds only the bare block edge and keeps losing
    those consumers until it is re-encoded.

    Version 10: narrowing a read that goes through a bare module alias — [locals { loc = module.X }]
    and then [local.loc.attr] somewhere else.

    This version carried two hints, and the tree holds neither of them. Each one was read by the
    walk that the expand/mark/sweep algorithm replaced, and that walk is deleted. The number stays
    in the sequence, because a state in the field carries it, but the bump buys nothing now: a state
    at 9 and a state at 10 send the same hints.

    The first hint was a [realized_object] hint on a scalar output of an aliased module. The shape
    gate suppresses a scalar, because a scalar has no per-attribute comparison to make on itself.
    The client lifted that gate for this one shape, because as a member of an output set the value
    is per-attribute data. The lift is gone: [bare_aliased_modules], the [~aliased_modules]
    parameter and the [?allow_scalar] gate went with the walk. What consumed the hint was the
    deleted walk's module-alias realization, thus the hint had no reader left. It bought precision
    and not correctness. Without it the alias object does not realize, and each consumer that reads
    through the alias takes the whole-value path, which over-reifies and is the safe direction.

    The second hint was [module_alias], which named the call block such a node aliases. It was read
    by one arm of the same walk. The new one answers the same question structurally, by asking the
    edge relation rather than a hint — see [whole_read_is_narrowed] in {!Sgs_reifier_subgraph2_mark}
    — and the client resolves a bare alias to a concrete output address before the walk ever runs.
    So this channel had no reader left either.

    Nothing back-fills either hint on an old row, and nothing needs to. A state that is behind is
    not incorrect here. It over-reifies, which is the safe direction.

    Version 11: the selector a read carries, for the expand/mark/sweep algorithm (see
    [stategraph/rfds/2172 - Expand Mark Sweep]). A read can name one member of what it reads without
    any evaluation, and {!Sg_tf_references.references} drops that member; see
    {!Sg_tf_references.selectors} for the shapes it recovers and why the two are separate.
    {!Sgs_tx_log_edges.edges_of_references} now records what it finds on [hcl_refs.index_kind] and
    [hcl_refs.index_val].

    It cannot be back-filled. The selector lives in the expression the stored references were
    derived from, and that expression is gone by the time any migration runs --
    [Sgs_migrations_ex_685], which rebuilds edges from stored refs, writes none for exactly that
    reason.

    A state that is behind is not incorrect. Every guard that would consult a selector answers
    [unknown] without one, and an unknown guard is followed, so such a state over-reifies -- the
    safe direction -- and gets none of the narrowing until it is re-encoded.

    Version 12: the scope of a file read (see [stategraph/rfds/2172 - Expand Mark Sweep], the
    ingestion contract, item 7). A block with a top-level [for_each] now carries the
    [for_each_file_calls] hint, which says which of its file calls feed the collection and which
    feed the body. The walk reads it to give a [reads_file] edge its scope: a changed file that only
    the collection reads moves only the keys of the collection.

    The server derives the hint at ingest from the AST of the block, and the client sends nothing
    for it. Unlike the hints above, the input is on the row: [hcl.data] holds the block, and an
    OCaml migration in the shape of [Sgs_migrations_ex_685] could compute the hint from it. No such
    migration exists. The bump makes the next ingest write the hint, and that ingest re-encodes the
    config of the state.

    A state that is behind is not incorrect. Without the hint the walk gives each file read of the
    block the scope body, which admits every instance. Such a state over-reifies -- the safe
    direction -- and gets none of the narrowing until it is re-encoded. *)
val version : int
