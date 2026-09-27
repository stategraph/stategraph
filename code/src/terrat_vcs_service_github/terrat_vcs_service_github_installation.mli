module Id : sig
  type t = int

  val make : int -> t
end

type refresh_repos_err =
  [ Terrat_vcs_api.call_err
  | Terrat_github.get_installation_repos_err
  | Pgsql_pool.err
  | Pgsql_io.err
  ]
[@@deriving show]

type refresh_repos_err' =
  [ Pgsql_pool.err
  | Pgsql_io.err
  ]
[@@deriving show]

val refresh_repos :
  request_id:string ->
  config:Terrat_vcs_service_github_provider.Api.Config.t ->
  storage:Terrat_storage.t ->
  Id.t ->
  (unit, [> refresh_repos_err ]) result Abb.Future.t

val refresh_repos' :
  request_id:string ->
  config:Terrat_vcs_service_github_provider.Api.Config.t ->
  storage:Terrat_storage.t ->
  ?user_id:Uuidm.t ->
  Id.t ->
  (Terrat_task.stored Terrat_task.t, [> refresh_repos_err' ]) result Abb.Future.t
