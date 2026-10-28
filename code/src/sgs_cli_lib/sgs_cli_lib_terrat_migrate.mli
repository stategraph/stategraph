(** Boot-time setup of the terrateam database, when orchestration is enabled. [run] reads the
    Terrateam configuration from the Stategraph environment ({!Sgs_terrat_config}), then:

    + creates the terrateam database when it does not exist. It does this check only when the
      maintenance database [postgres] accepts a connection, because hardened setups revoke it.
    + runs the Terrateam migrations on it.
    + converges two roles on their privileges on the [public] schema. A role that does not exist is
      created NOLOGIN; its LOGIN attribute and its password stay with the deployment. Each role
      loses all of its privileges and gets them again in one transaction, so a reader never sees the
      role without privileges. Concurrent runs take these transactions one at a time:

    - [stategraph_mql], the role of the read-only foreign data wrapper: the column-level SELECT of
      the catalog (code/src/sgs_terrateam_catalog/fdw_grants.sql), and SELECT (id, repo) on
      [work_manifests].
    - [stategraph_provisioner], the role of the console's provisioning writes: the GitLab
      installation tables and the GitHub App row.

    Each step converges, so a second [run], also a concurrent one, changes nothing. When
    orchestration is disabled, [run] does nothing. *)

type err =
  [ `Config_err of Terrat_config.err
  | `Connect_timeout_err of string
  | `Create_database_err of string * Pgsql_io.err
  | `Create_role_err of string * Pgsql_io.err
  | `Migration_err of [ Pgsql_io.err | Pgsql_pool.err | `Mql_err of Mql.Ast.err ]
  | `Consistency_err of Data_mig.Error.Consistency.t
  | Pgsql_io.create_err
  | Pgsql_io.err
  ]
[@@deriving show]

val run : Sgs_config.t -> (unit, [> err ]) result Abb.Future.t
