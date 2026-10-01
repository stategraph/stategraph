(** Install the [pg_temp.*] sensitive-value masking functions defined in
    [sql/create_mql_mask_fns.sql] onto [db]'s session. Defined in [pg_temp], so they live for the
    pooled connection's lifetime and PostgreSQL drops them on close.

    A session that already carries this exact script is left alone: the install records itself with
    a marker function named after the script's digest, so an edit to the SQL installs the new bodies
    on the next call.

    The marker lives in the database rather than in this process because the install is
    transactional: a caller whose transaction rolls back takes the functions down with it, and the
    marker goes with them. *)
val install : Pgsql_io.t -> (unit, [> Pgsql_io.err ]) result Abb.Future.t
