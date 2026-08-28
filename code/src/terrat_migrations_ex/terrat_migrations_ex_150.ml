module Sql = struct
  let change_dirspaces_update_sql =
    {|
     with limited as (
       select * from change_dirspaces where repo is null limit 10000
     )
     update change_dirspaces as cd
     set repo = grm.core_id
     from limited
     inner join github_repositories_map as grm
         on grm.repository_id = limited.repository
     where (cd.repository, cd.base_sha, cd.sha, cd.path, cd.workspace) = (limited.repository, limited.base_sha, limited.sha, limited.path, limited.workspace)
           and grm.repository_id = cd.repository
     |}

  let change_dirspaces_update = Pgsql_io.Typed_sql.(sql /^ change_dirspaces_update_sql)

  let change_dirspaces_while_ =
    Pgsql_io.Typed_sql.(
      sql // Ret.(option uuid) /^ "select repo from change_dirspaces where repo is null limit 1")

  let code_indexes_update_sql =
    {|
     with limited as (
       select * from code_indexes where installation is null limit 10000
     )
     update code_indexes as ci
     set installation = gim.core_id
     from limited
     inner join github_installations_map as gim
       on gim.installation_id = limited.installation_id
     where (ci.installation_id, ci.sha) = (limited.installation_id, limited.sha)
           and gim.installation_id = ci.installation_id
     |}

  let code_indexes_update = Pgsql_io.Typed_sql.(sql /^ code_indexes_update_sql)

  let code_indexes_while_ =
    Pgsql_io.Typed_sql.(
      sql
      // Ret.(option uuid)
      /^ "select installation from code_indexes where installation is null limit 1")

  let drift_schedules_update_sql =
    {|
     with limited as (
       select * from drift_schedules where repo is null limit 10000
     )
     update drift_schedules as ds
     set repo = grm.core_id
     from limited
     inner join github_repositories_map as grm
       on grm.repository_id = limited.repository
     where (ds.repository, ds.name) = (limited.repository, limited.name)
           and grm.repository_id = ds.repository
     |}

  let drift_schedules_update = Pgsql_io.Typed_sql.(sql /^ drift_schedules_update_sql)

  let drift_schedules_while_ =
    Pgsql_io.Typed_sql.(
      sql // Ret.(option uuid) /^ "select repo from drift_schedules where repo is null limit 1")

  let drift_unlocks_update_sql =
    {|
     with limited as (
       select * from drift_unlocks where repo is null limit 10000
     )
     update drift_unlocks as du
     set repo = grm.core_id
     from limited
     inner join github_repositories_map as grm
       on grm.repository_id = limited.repository
     where (du.repository, du.unlocked_at) = (limited.repository, limited.unlocked_at)
           and grm.repository_id = du.repository
     |}

  let drift_unlocks_update = Pgsql_io.Typed_sql.(sql /^ drift_unlocks_update_sql)

  let drift_unlocks_while_ =
    Pgsql_io.Typed_sql.(
      sql // Ret.(option uuid) /^ "select repo from drift_unlocks where repo is null limit 1")

  let gate_approvals_update_sql =
    {|
     with limited as (
       select * from gate_approvals where pull_request is null limit 10000
     )
     update gate_approvals as ga
     set pull_request = gprm.core_id
     from limited
     inner join github_pull_requests_map as gprm
       on gprm.repository_id = limited.repository and gprm.pull_number = limited.pull_number
     where (ga.repository, ga.pull_number, ga.sha, ga.token, ga.approver) = (limited.repository, limited.pull_number, limited.sha, limited.token, limited.approver)
           and gprm.repository_id = ga.repository and gprm.pull_number = ga.pull_number
     |}

  let gate_approvals_update = Pgsql_io.Typed_sql.(sql /^ gate_approvals_update_sql)

  let gate_approvals_while_ =
    Pgsql_io.Typed_sql.(
      sql
      // Ret.(option uuid)
      /^ "select pull_request from gate_approvals where pull_request is null limit 1")

  let gates_update_sql =
    {|
     with limited as (
       select * from gates where pull_request is null limit 10000
     )
     update gates as g
     set pull_request = gprm.core_id
     from limited
     inner join github_pull_requests_map as gprm
       on gprm.repository_id = limited.repository and gprm.pull_number = limited.pull_number
     where (g.repository, g.pull_number, g.sha, g.dir, g.workspace, g.token) = (limited.repository, limited.pull_number, limited.sha, limited.dir, limited.workspace, limited.token)
           and gprm.repository_id = g.repository and gprm.pull_number = g.pull_number
     |}

  let gates_update = Pgsql_io.Typed_sql.(sql /^ gates_update_sql)

  let gates_while_ =
    Pgsql_io.Typed_sql.(
      sql
      // Ret.(option uuid)
      /^ "select pull_request from gates where pull_request is null limit 1")

  let pull_request_unlocks_update_sql =
    {|
     with limited as (
       select * from pull_request_unlocks where pull_request is null limit 10000
     )
     update pull_request_unlocks as gpru
     set pull_request = gprm.core_id
     from limited
     inner join github_pull_requests_map as gprm
       on gprm.repository_id = limited.repository and gprm.pull_number = limited.pull_number
     where (gpru.repository, gpru.pull_number, gpru.unlocked_at) = (limited.repository, limited.pull_number, limited.unlocked_at)
           and gprm.repository_id = gpru.repository and gprm.pull_number = gpru.pull_number
     |}

  let pull_request_unlocks_update = Pgsql_io.Typed_sql.(sql /^ pull_request_unlocks_update_sql)

  let pull_request_unlocks_while_ =
    Pgsql_io.Typed_sql.(
      sql
      // Ret.(option uuid)
      /^ "select pull_request from pull_request_unlocks where pull_request is null limit 1")

  let repo_configs_update_sql =
    {|
     with limited as (
       select * from repo_configs where installation is null limit 10000
     )
     update repo_configs as rc
     set installation = gim.core_id
     from limited
     inner join github_installations_map as gim
       on gim.installation_id = limited.installation_id
     where (rc.installation_id, rc.sha) = (limited.installation_id, limited.sha)
           and gim.installation_id = rc.installation_id
     |}

  let repo_configs_update = Pgsql_io.Typed_sql.(sql /^ repo_configs_update_sql)

  let repo_configs_while_ =
    Pgsql_io.Typed_sql.(
      sql
      // Ret.(option uuid)
      /^ "select installation from repo_configs where installation is null limit 1")

  let repo_trees_update_sql =
    {|
     with limited as (
       select * from repo_trees where installation is null limit 10000
     )
     update repo_trees as rc
     set installation = gim.core_id
     from limited
     inner join github_installations_map as gim
       on gim.installation_id = limited.installation_id
     where (rc.installation_id, rc.sha) = (limited.installation_id, limited.sha)
           and gim.installation_id = rc.installation_id
     |}

  let repo_trees_update = Pgsql_io.Typed_sql.(sql /^ repo_trees_update_sql)

  let repo_trees_while_ =
    Pgsql_io.Typed_sql.(
      sql
      // Ret.(option uuid)
      /^ "select installation from repo_trees where installation is null limit 1")

  let work_manifests_repos_update_sql =
    {|
     with limited as (
       select * from work_manifests where repo is null and pull_number is null limit 10000
     )
     update work_manifests as wm
     set repo = grm.core_id
     from limited
     inner join github_repositories_map as grm
       on grm.repository_id = limited.repository
     where wm.id = limited.id and grm.repository_id = wm.repository
     |}

  let work_manifests_repos_update = Pgsql_io.Typed_sql.(sql /^ work_manifests_repos_update_sql)

  let work_manifests_repos_while_ =
    Pgsql_io.Typed_sql.(
      sql
      // Ret.(option uuid)
      /^ "select repo from work_manifests where repo is null and pull_number is null limit 1")

  let work_manifests_pull_requests_update_sql =
    {|
     with limited as (
     select * from work_manifests where pull_request is null and pull_number is not null limit 10000
     )
     update work_manifests as wm
     set repo = grm.core_id, pull_request = gprm.core_id
     from limited
     inner join github_repositories_map as grm
       on grm.repository_id = limited.repository
     inner join github_pull_requests_map as gprm
       on gprm.repository_id = limited.repository and gprm.pull_number = limited.pull_number
     where wm.id = limited.id
           and grm.repository_id = wm.repository
           and gprm.repository_id = wm.repository and gprm.pull_number = wm.pull_number
     |}

  let work_manifests_pull_requests_update =
    Pgsql_io.Typed_sql.(sql /^ work_manifests_pull_requests_update_sql)

  let work_manifests_pull_requets_while_sql =
    {|
     select pull_request from work_manifests as wm
     inner join github_repositories_map as grm
       on grm.repository_id = wm.repository
     inner join github_pull_requests_map as gprm
       on gprm.repository_id = wm.repository and gprm.pull_number = wm.pull_number
     where wm.pull_request is null and wm.pull_number is not null
     limit 1
     |}

  let work_manifests_pull_requests_while_ =
    Pgsql_io.Typed_sql.(sql // Ret.(option uuid) /^ work_manifests_pull_requets_while_sql)
end

let rec fill_in storage update while_ =
  let open Abbs_future_combinators.Infix_result_monad in
  Pgsql_pool.with_conn storage ~f:(fun db ->
      Pgsql_io.tx db ~f:(fun () ->
          while_ db
          >>= function
          | `Cont -> update db >>| fun () -> `Cont
          | `Done -> Abbs_future_combinators.return_ok `Done))
  >>= function
  | `Cont -> fill_in storage update while_
  | `Done -> Abbs_future_combinators.return_ok ()

let update' sql db = Pgsql_io.Prepared_stmt.execute db sql

let while' sql db =
  let open Abbs_future_combinators.Infix_result_monad in
  Pgsql_io.Prepared_stmt.fetch db sql ~f:CCFun.id
  >>| function
  | [] -> `Done
  | _ :: _ -> `Cont

let fill_in_change_dirspace (_config, storage) =
  fill_in storage (update' Sql.change_dirspaces_update) (while' Sql.change_dirspaces_while_)

let fill_in_code_indexes (_config, storage) =
  fill_in storage (update' Sql.code_indexes_update) (while' Sql.code_indexes_while_)

let fill_in_drift_schedules (_config, storage) =
  fill_in storage (update' Sql.drift_schedules_update) (while' Sql.drift_schedules_while_)

let fill_in_drift_unlocks (_config, storage) =
  fill_in storage (update' Sql.drift_unlocks_update) (while' Sql.drift_unlocks_while_)

let fill_in_gate_approvals (_config, storage) =
  fill_in storage (update' Sql.gate_approvals_update) (while' Sql.gate_approvals_while_)

let fill_in_gates (_config, storage) =
  fill_in storage (update' Sql.gates_update) (while' Sql.gates_while_)

let fill_in_pull_request_unlocks (_config, storage) =
  fill_in storage (update' Sql.pull_request_unlocks_update) (while' Sql.pull_request_unlocks_while_)

let fill_in_repo_configs (_config, storage) =
  fill_in storage (update' Sql.repo_configs_update) (while' Sql.repo_configs_while_)

let fill_in_repo_trees (_config, storage) =
  fill_in storage (update' Sql.repo_trees_update) (while' Sql.repo_trees_while_)

let fill_in_work_manifests_repos (_config, storage) =
  fill_in storage (update' Sql.work_manifests_repos_update) (while' Sql.work_manifests_repos_while_)

let fill_in_work_manifests_pull_requests (_config, storage) =
  fill_in
    storage
    (update' Sql.work_manifests_pull_requests_update)
    (while' Sql.work_manifests_pull_requests_while_)

let fill_in_all ctx =
  let open Abbs_future_combinators.Infix_result_monad in
  fill_in_change_dirspace ctx
  >>= fun () ->
  fill_in_code_indexes ctx
  >>= fun () ->
  fill_in_drift_schedules ctx
  >>= fun () ->
  fill_in_drift_unlocks ctx
  >>= fun () ->
  fill_in_gate_approvals ctx
  >>= fun () ->
  fill_in_gates ctx
  >>= fun () ->
  fill_in_pull_request_unlocks ctx
  >>= fun () ->
  fill_in_repo_configs ctx
  >>= fun () ->
  fill_in_repo_trees ctx
  >>= fun () ->
  fill_in_work_manifests_repos ctx >>= fun () -> fill_in_work_manifests_pull_requests ctx
