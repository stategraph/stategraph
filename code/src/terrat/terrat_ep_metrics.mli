(** The Prometheus metrics endpoint. Before rendering the registry, it refreshes the repo tree
    partition gauges from the catalog through a pooled connection: a failed refresh is counted and
    logged, and the endpoint still serves, with the previous gauge values. *)
val get : Terrat_storage.t -> Brtl_rtng.Handler.t

(** [refresh db] refreshes the repo tree partition gauges from the catalog scan of
    {i sql/select_partition_metrics.sql}: one row per parent table, with its partition count, the
    total bytes of its partitions, and the bytes of its [_default] partition as its own gauge. On a
    failed scan the gauges keep their previous values, and the error is what the scan answered. *)
val refresh : Pgsql_io.t -> (unit, [> Pgsql_io.err ]) result Abb.Future.t
