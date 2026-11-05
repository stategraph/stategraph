(** GitHub implementation of the unified pull request summary comment.

    The flow has two halves. While a work manifest result is being processed (inside its
    transaction), {!mark_dirty} bumps the dirty counter of the pull request's tracking row so the
    refresh is committed atomically with the results. After the transaction commits, {!drain} runs
    on a fresh connection: it takes an advisory lock so only one publisher runs per pull request,
    recomputes the state of every dirspace, renders it, updates the tracked comment in place
    (posting a new one if it disappeared), and clears the dirty counter it observed. If new results
    arrived while publishing, the counter no longer matches and it retries. *)

(** The state of one dirspace in the comment. [active] is a run of the dirspace in flight on the
    head, [aborted] an aborted run of it on the head without results, and [summary_state] the state
    stored for the head. A run in flight decides the state over any aborted run. *)
val status_of_row :
  plan_success:bool option ->
  apply_success:bool option ->
  active:bool ->
  active_apply:bool ->
  aborted:bool ->
  summary_state:string option ->
  Terrat_vcs_comment_unified.Status.t

val mark_dirty :
  request_id:string ->
  output_details:bool ->
  Pgsql_io.t ->
  Uuidm.t ->
  (unit, [> `Error ]) result Abb.Future.t

(** Like {!mark_dirty} but never creates the tracking row, so pull requests that do not publish a
    unified comment are unaffected. Used by failure paths, which cannot cheaply consult the repo
    config. *)
val mark_dirty_if_tracked :
  request_id:string -> Pgsql_io.t -> Uuidm.t -> (unit, [> `Error ]) result Abb.Future.t

(** Publish the unified summary comment as a run starts, before any result comment posts: the
    comment is created with every dirspace of the run showing as [Plan_running], or as
    [Apply_running] when the run that starts is an apply. Runs in the caller's open transaction; a
    blocking advisory lock serializes concurrent starts of the same pull request. Best effort:
    errors are logged and returned for the caller to ignore. *)
val publish_at_start :
  request_id:string ->
  fetch_brand:
    (Terrat_vcs_api_github.Client.t ->
    Terrat_vcs_api_github.Repo.t ->
    (Terrat_brand.t, Terrat_vcs_api.call_err) result Abb.Future.t) ->
  config:Terrat_vcs_api_github.Config.t ->
  output_details:bool ->
  Pgsql_io.t ->
  Uuidm.t ->
  (unit, [> `Error ]) result Abb.Future.t

val drain :
  request_id:string ->
  fetch_brand:
    (Terrat_vcs_api_github.Client.t ->
    Terrat_vcs_api_github.Repo.t ->
    (Terrat_brand.t, Terrat_vcs_api.call_err) result Abb.Future.t) ->
  Terrat_vcs_api_github.Config.t ->
  Pgsql_pool.t ->
  Uuidm.t ->
  unit Abb.Future.t

(** As {!drain}, for the pull request [pull_number] of [repository]. An evaluation of a pull request
    event can change the states of its dirspaces without a work manifest (RFD 2356), for example a
    push that keeps the runs of a dirspace. Nothing happens when the pull request tracks no unified
    comment. *)
val drain_pull_request :
  request_id:string ->
  fetch_brand:
    (Terrat_vcs_api_github.Client.t ->
    Terrat_vcs_api_github.Repo.t ->
    (Terrat_brand.t, Terrat_vcs_api.call_err) result Abb.Future.t) ->
  Terrat_vcs_api_github.Config.t ->
  Pgsql_pool.t ->
  repository:int ->
  pull_number:int ->
  unit Abb.Future.t
