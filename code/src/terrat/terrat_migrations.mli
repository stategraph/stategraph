val run :
  Terrat_config.t ->
  Terrat_storage.t ->
  ( unit,
    [> `Migration_err of [ Pgsql_io.err | Pgsql_pool.err ]
    | `Consistency_err of Data_mig.Error.Consistency.t
    ] )
  result
  Abb.Future.t
