val run :
  Sgs_config.t ->
  Pgsql_pool.t ->
  ( unit,
    [> `Migration_err of [ Pgsql_io.err | Pgsql_pool.err | `Mql_err of Mql.Ast.err ]
    | `Consistency_err of Data_mig.Error.Consistency.t
    ] )
  result
  Abb.Future.t

module Tests : sig
  (** Run the statements of the migration [restore-masked-sensitive-values] on [db]. *)
  val restore_masked_sensitive_values :
    Sgs_config.t ->
    Pgsql_pool.t ->
    Pgsql_io.t ->
    (unit, [> `Mql_err of Mql.Ast.err | Pgsql_io.err | Pgsql_pool.err ]) result Abb.Future.t
end
