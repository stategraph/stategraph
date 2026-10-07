(** Boot-time reconcile of the postgres_fdw bridge to the terrateam database.

    When orchestration is enabled, [run] (re)creates the whole bridge inside one transaction on the
    stategraph database: the postgres_fdw extension, the [terrateam_fdw] server pointing at the
    STATEGRAPH_FDW_* location, a user mapping for the connecting role, the [terrateam] schema, and
    the catalog-generated foreign tables (code/src/sgs_terrateam_catalog/fdw_tables.sql). The server
    is dropped with CASCADE first, so every boot converges on exactly the config + catalog state —
    env changes take effect on restart, and there is no CREATE-vs-ALTER dance. Foreign tables bind
    lazily, so none of this requires the terrateam database to be reachable.

    This is deliberately NOT part of the migration stream: migrations are static, prefix-checked SQL
    (see data_mig), while the bridge is a function of env; a conditional or env-substituted
    migration would break the consistency model. Called from the [migrate] CLI path after
    {!Sgs_migrations.run}.

    When orchestration is disabled, [run] is a no-op and leaves any existing FDW objects in place.
*)

type err =
  [ Pgsql_pool.err
  | Pgsql_io.err
  ]
[@@deriving show]

val run : Sgs_config.t -> Pgsql_pool.t -> (unit, [> err ]) result Abb.Future.t
