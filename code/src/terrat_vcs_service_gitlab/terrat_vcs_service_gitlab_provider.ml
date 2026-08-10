let src = Logs.Src.create "vcs_service_gitlab_provider"

module Api = Terrat_vcs_api_gitlab
module By_scope = Terrat_scope.By_scope
module Logs = (val Logs.src_log src : Logs.LOG)
module Scope = Terrat_scope.Scope
module Tmpl = Terrat_vcs_gitlab_comment_templates.Tmpl
module Ui = Terrat_vcs_gitlab_comment_ui.Ui

let not_a_bad_chunk_size = 500
let replace_nul_byte = CCString.replace ~which:`All ~sub:"\x00" ~by:"\\0"

let rec replace_nul_byte_json = function
  | `Tuple l -> `Tuple (CCList.map replace_nul_byte_json l)
  | `Variant (k, None) -> `Variant (replace_nul_byte k, None)
  | `Variant (k, Some v) -> `Variant (replace_nul_byte k, Some (replace_nul_byte_json v))
  | `List l -> `List (CCList.map replace_nul_byte_json l)
  | `Assoc assoc ->
      `Assoc (CCList.map (fun (k, v) -> (replace_nul_byte k, replace_nul_byte_json v)) assoc)
  | `String s -> `String (replace_nul_byte s)
  | (`Bool _ | `Intlit _ | `Null | `Float _ | `Int _) as t -> t

module Metrics = struct
  module Psql_query_time = Prmths.Histogram (struct
    let spec = Prmths.Histogram_spec.of_linear ~start:0.0 ~interval:0.1 ~count:15
  end)

  module Time_histogram = Prmths.DefaultHistogram

  let namespace = "terrat"
  let subsystem = "vcs_service_gitlab_provider"
  let pgsql_errors_total = Terrat_metrics.errors_total ~m:subsystem ~t:"pgsql"

  let psql_query_time =
    let help = "Time for PostgreSQL query" in
    Psql_query_time.v_label ~help ~label_name:"q" ~namespace ~subsystem "psql_query_time"

  let run_overall_result_count =
    let help = "Count of the results of overall runs" in
    Prmths.Counter.v_label
      ~label_name:"success"
      ~help
      ~namespace
      ~subsystem
      "run_overall_result_count"
end

module Sql = struct
  let read s = Pgsql_io.clean_string s

  let select_user_installation () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* installation_id *)
      Ret.bigint
      /^ read [%blob "sql/select_user_installation.sql"]
      /% Var.uuid "user_id"
      /% Var.bigint "installation_id")
end

(* Do not change this willy-nilly, values in the database probablye depend on it. *)
let name = "gitlab"

let enforce_installation_access ~request_id user account_id db =
  if
    Terrat_user.has_capability
      (Terrat_user.Capability.Installation_id (CCInt.to_string account_id))
      user
  then Abb.Future.return (Ok ())
  else
    let open Abb.Future.Infix_monad in
    Pgsql_io.Prepared_stmt.fetch
      db
      (Sql.select_user_installation ())
      ~f:CCFun.id
      (Terrat_user.id user)
      (CCInt64.of_int account_id)
    >>= function
    | Ok [] -> Abb.Future.return (Error `Forbidden)
    | Ok (_ :: _) -> Abb.Future.return (Ok ())
    | Error (#Pgsql_io.err as err) ->
        Logs.err (fun m -> m "%s : ENFORCE_INSTALLATION_ACCESS : %a" request_id Pgsql_io.pp_err err);
        Abb.Future.return (Error `Forbidden)

module Unlock_id = struct
  type t =
    | Pull_request of int
    | Drift

  let of_pull_request id = Pull_request id
  let drift () = Drift

  let to_string = function
    | Pull_request id -> CCInt.to_string id
    | Drift -> "drift"
end

module Db = struct
  module Sql = struct
    let read s = Pgsql_io.clean_string s

    let policy =
      let module P = struct
        type t = Terrat_base_repo_config_v1.Access_control.Match_list.t [@@deriving yojson]
      end in
      CCFun.(P.of_yojson %> CCResult.to_opt)

    let lock_policy =
      let open Terrat_base_repo_config_v1.Workflows.Entry.Lock_policy in
      function
      | Apply -> "apply"
      | Merge -> "merge"
      | None -> "none"
      | Strict -> "strict"

    let branch_target =
      let open Terrat_base_repo_config_v1.Dirs.Dir.Branch_target in
      function
      | All -> "all"
      | Dest_branch -> "dest_branch"

    let select_work_manifests_batch_query = read [%blob "sql/select_work_manifests_batch.sql"]

    let select_work_manifests_batch () =
      Pgsql_io.Typed_sql.(
        sql
        //
        (* id *)
        Ret.uuid
        //
        (* base_sha *)
        Ret.text
        //
        (* completed_at *)
        Ret.(option text)
        //
        (* created_at *)
        Ret.text
        //
        (* pull_number *)
        Ret.(option bigint)
        //
        (* repository *)
        Ret.bigint
        //
        (* run_id *)
        Ret.(option text)
        //
        (* run_type *)
        Ret.(u text Terrat_work_manifest3.Step.of_string)
        //
        (* sha *)
        Ret.text
        //
        (* state *)
        Ret.(u text Terrat_work_manifest3.State.of_string)
        //
        (* tag_query *)
        Ret.(u text CCFun.(Terrat_tag_query.of_string %> CCResult.to_opt))
        //
        (* username *)
        Ret.(option text)
        //
        (* run_kind *)
        Ret.text
        //
        (* installation_id *)
        Ret.bigint
        //
        (* repo_owner *)
        Ret.text
        //
        (* repo_name *)
        Ret.text
        //
        (* environment *)
        Ret.(option text)
        //
        (* runs_on *)
        Ret.(option json)
        //
        (* branch *)
        Ret.(option text)
        /^ select_work_manifests_batch_query
        /% Var.(str_array (uuid "ids")))

    let select_work_manifest_dirspaceflows_batch =
      Pgsql_io.Typed_sql.(
        sql
        //
        (* work_manifest *)
        Ret.uuid
        //
        (* path *)
        Ret.text
        //
        (* workflow_idx *)
        Ret.(option smallint)
        //
        (* workspace *)
        Ret.text
        /^ read [%blob "sql/select_work_manifest_dirspaceflows_batch.sql"]
        /% Var.(str_array (uuid "ids")))

    let select_work_manifest_access_control_denied_dirspaces_batch =
      Pgsql_io.Typed_sql.(
        sql
        //
        (* work_manifest *)
        Ret.uuid
        //
        (* path *)
        Ret.text
        //
        (* workspace *)
        Ret.text
        //
        (* policy *)
        Ret.(option (u json policy))
        /^ read [%blob "sql/select_work_manifest_access_control_denied_dirspaces_batch.sql"]
        /% Var.(str_array (uuid "ids")))

    let select_work_manifest_pull_requests_batch_query =
      read [%blob "sql/select_work_manifest_pull_requests_batch.sql"]

    let select_work_manifest_pull_requests_batch () =
      Pgsql_io.Typed_sql.(
        sql
        //
        (* id *)
        Ret.uuid
        //
        (* base_branch_name *)
        Ret.text
        //
        (* base_ref *)
        Ret.text
        //
        (* branch_name *)
        Ret.text
        //
        (* branch_ref *)
        Ret.text
        //
        (* pull_number *)
        Ret.bigint
        //
        (* state *)
        Ret.text
        //
        (* merged_sha *)
        Ret.(option text)
        //
        (* merged_at *)
        Ret.(option text)
        //
        (* title *)
        Ret.(option text)
        //
        (* username *)
        Ret.(option text)
        /^ select_work_manifest_pull_requests_batch_query
        /% Var.(str_array (uuid "ids")))

    let select_drift_work_manifests_batch_query =
      read [%blob "sql/select_drift_work_manifests_batch.sql"]

    let select_drift_work_manifests_batch () =
      Pgsql_io.Typed_sql.(
        sql
        //
        (* work_manifest *)
        Ret.uuid
        //
        (* branch *)
        Ret.text
        //
        (* reconcile *)
        Ret.boolean
        /^ select_drift_work_manifests_batch_query
        /% Var.(str_array (uuid "ids")))

    let insert_gitlab_installation_repository =
      Pgsql_io.Typed_sql.(
        sql
        /^ read [%blob "sql/insert_installation_repository.sql"]
        /% Var.bigint "id"
        /% Var.bigint "installation_id"
        /% Var.text "owner"
        /% Var.text "name")

    let select_repository_for_update =
      Pgsql_io.Typed_sql.(
        sql
        //
        (* id *)
        Ret.bigint
        /^ read [%blob "sql/select_repository_for_update.sql"]
        /% Var.bigint "id")

    let insert_pull_request =
      Pgsql_io.Typed_sql.(
        sql
        /^ read [%blob "sql/insert_pull_request.sql"]
        /% Var.text "base_branch"
        /% Var.text "base_sha"
        /% Var.text "branch"
        /% Var.bigint "pull_number"
        /% Var.bigint "repository"
        /% Var.text "sha"
        /% Var.(option (text "merged_sha"))
        /% Var.(option (timestamptz "merged_at"))
        /% Var.text "state"
        /% Var.(option (text "title"))
        /% Var.(option (text "username")))

    let insert_index_query = read [%blob "sql/insert_code_index.sql"]

    let insert_index () =
      Pgsql_io.Typed_sql.(sql /^ insert_index_query /% Var.uuid "work_manifest" /% Var.json "index")

    let insert_gitlab_work_manifest_result =
      Pgsql_io.Typed_sql.(
        sql
        /^ read [%blob "sql/insert_work_manifest_result.sql"]
        /% Var.(str_array (uuid "work_manifest"))
        /% Var.(str_array (text "path"))
        /% Var.(str_array (text "workspace"))
        /% Var.(array (boolean "success")))

    let insert_repo_config =
      Pgsql_io.Typed_sql.(
        sql
        /^ read [%blob "sql/insert_repo_config.sql"]
        /% Var.bigint "installation_id"
        /% Var.text "sha"
        /% Var.json "data")

    let insert_repo_config_history =
      Pgsql_io.Typed_sql.(
        sql
        /^ read [%blob "sql/insert_repo_config_history.sql"]
        /% Var.text "branch"
        /% Var.text "sha"
        /% Var.json "data"
        /% Var.bigint "repository_id"
        /% Var.bigint "installation_id")

    let insert_repo_tree =
      Pgsql_io.Typed_sql.(
        sql
        /^ read [%blob "sql/insert_repo_tree.sql"]
        /% Var.(array (bigint "installation_ids"))
        /% Var.(str_array (text "shas"))
        /% Var.(str_array (text "paths"))
        /% Var.(array (option (boolean "changed")))
        /% Var.(str_array (option (text "id"))))

    let insert_repo_tree_build =
      Pgsql_io.Typed_sql.(
        sql
        /^ read [%blob "sql/insert_repo_tree_build.sql"]
        /% Var.bigint "installation_id"
        /% Var.text "sha")

    let upsert_flow_state_query = read [%blob "sql/update_flow_state.sql"]

    let upsert_flow_state () =
      Pgsql_io.Typed_sql.(sql /^ upsert_flow_state_query /% Var.uuid "id" /% Var.text "data")

    let insert_dirspace =
      Pgsql_io.Typed_sql.(
        sql
        /^ read [%blob "sql/insert_dirspaces.sql"]
        /% Var.(str_array (text "base_sha"))
        /% Var.(str_array (text "path"))
        /% Var.(array (bigint "repository"))
        /% Var.(str_array (text "sha"))
        /% Var.(str_array (text "workspace"))
        /% Var.(str_array (ud (text "lock_policy") lock_policy))
        /% Var.(str_array (ud (text "branch_target") branch_target)))

    let insert_workflow_step_output =
      let query = read [%blob "sql/insert_workflow_step_output.sql"] in
      Pgsql_io.Typed_sql.(
        sql
        /^ query
        /% Var.(array (smallint "idx"))
        /% Var.(array (boolean "ignore_errors"))
        /% Var.(str_array (json "payload"))
        /% Var.(str_array (json "scope"))
        /% Var.(str_array (text "step"))
        /% Var.(array (boolean "success"))
        /% Var.(str_array (uuid "work_manifest")))

    let upsert_drift_schedule =
      Pgsql_io.Typed_sql.(
        sql
        /^ read [%blob "sql/upsert_drift_schedule.sql"]
        /% Var.bigint "repo"
        /% Var.(ud (text "schedule") Terrat_base_repo_config_v1.Drift.Schedule.Sched.to_string)
        /% Var.boolean "reconcile"
        /% Var.(option (ud (text "tag_query") Terrat_tag_query.to_string))
        /% Var.text "name"
        /% Var.(option (timetz "window_start"))
        /% Var.(option (timetz "window_end")))

    let delete_drift_schedules =
      Pgsql_io.Typed_sql.(
        sql
        /^ read [%blob "sql/delete_drift_schedules.sql"]
        /% Var.bigint "repo_id"
        /% Var.(str_array (text "names")))

    let select_installation_account_status_query = read [%blob "sql/select_account_status.sql"]

    let select_installation_account_status () =
      Pgsql_io.Typed_sql.(
        sql
        //
        (* account_status *)
        Ret.text
        //
        (* trial_end_days *)
        Ret.(option integer)
        /^ select_installation_account_status_query
        /% Var.bigint "installation_id")

    let select_index =
      let index = CCFun.(Terrat_code_idx.of_yojson %> CCResult.to_opt) in
      Pgsql_io.Typed_sql.(
        sql
        //
        (* Index *)
        Ret.(u json index)
        /^ read [%blob "sql/select_index.sql"]
        /% Var.bigint "installation_id"
        /% Var.text "sha")

    let select_repo_config =
      Pgsql_io.Typed_sql.(
        sql
        //
        (* repo_config *)
        Ret.json
        /^ read [%blob "sql/select_repo_config.sql"]
        /% Var.bigint "installation_id"
        /% Var.text "sha")

    let select_repo_tree =
      Pgsql_io.Typed_sql.(
        sql
        //
        (* path *)
        Ret.text
        //
        (* changed *)
        Ret.(option boolean)
        /^ read [%blob "sql/select_repo_tree.sql"]
        /% Var.bigint "installation_id"
        /% Var.text "sha"
        /% Var.(option (text "base_sha")))

    let select_repo_tree_build =
      Pgsql_io.Typed_sql.(
        sql
        //
        (* sha *)
        Ret.text
        /^ read [%blob "sql/select_repo_tree_build.sql"]
        /% Var.bigint "installation_id"
        /% Var.text "sha")

    let select_next_work_manifest =
      Pgsql_io.Typed_sql.(
        sql
        //
        (* id *)
        Ret.uuid
        /^ read [%blob "sql/select_next_work_manifest.sql"])

    let select_flow_state_query = read [%blob "sql/select_flow_data.sql"]

    let select_flow_state () =
      Pgsql_io.Typed_sql.(
        sql
        //
        (* data *)
        Ret.text
        /^ select_flow_state_query
        /% Var.uuid "id")

    let delete_flow_state_query = read [%blob "sql/delete_flow_state.sql"]
    let delete_flow_state () = Pgsql_io.Typed_sql.(sql /^ delete_flow_state_query /% Var.uuid "id")

    let select_out_of_diff_applies =
      Pgsql_io.Typed_sql.(
        sql
        //
        (* path *)
        Ret.text
        //
        (* workspace *)
        Ret.text
        /^ read [%blob "sql/select_out_of_diff_applies.sql"]
        /% Var.bigint "repository"
        /% Var.bigint "pull_number")

    let select_dirspace_applies_for_pull_request =
      Pgsql_io.Typed_sql.(
        sql
        //
        (* path *)
        Ret.text
        //
        (* workspace *)
        Ret.text
        /^ read [%blob "sql/select_dirspace_applies_for_pull_request.sql"]
        /% Var.bigint "repo_id"
        /% Var.bigint "pull_number")

    let select_dirspace_applies_for_context =
      Pgsql_io.Typed_sql.(
        sql
        //
        (* path *)
        Ret.text
        //
        (* workspace *)
        Ret.text
        /^ read [%blob "sql/select_dirspace_applies_for_context.sql"]
        /% Var.(ud (uuid "context_id") (fun c -> c.Terrat_job_context.Context.id)))

    let select_dirspaces_without_valid_plans =
      Pgsql_io.Typed_sql.(
        sql
        //
        (* dir *)
        Ret.text
        //
        (* workspace *)
        Ret.text
        /^ read [%blob "sql/select_dirspaces_without_valid_plans.sql"]
        /% Var.bigint "repository"
        /% Var.bigint "pull_number"
        /% Var.(str_array (text "dirs"))
        /% Var.(str_array (text "workspaces"))
        /% Var.(ud (text "base_ref") Api.Ref.to_string)
        /% Var.(ud (text "branch_ref") Api.Ref.to_string))

    let update_abort_duplicate_work_manifests_query =
      read [%blob "sql/abort_duplicate_work_manifests.sql"]

    let update_abort_duplicate_work_manifests () =
      Pgsql_io.Typed_sql.(
        sql
        //
        (* work manifest id *)
        Ret.uuid
        /^ update_abort_duplicate_work_manifests_query
        /% Var.bigint "repository"
        /% Var.bigint "pull_number"
        /% Var.(ud (text "run_type") Terrat_work_manifest3.Step.to_string)
        /% Var.(str_array (text "dirs"))
        /% Var.(str_array (text "workspaces")))

    let update_abort_duplicate_work_manifests_for_context_query =
      read [%blob "sql/abort_duplicate_work_manifests_for_context.sql"]

    let update_abort_duplicate_work_manifests_for_context () =
      Pgsql_io.Typed_sql.(
        sql
        //
        (* work manifest id *)
        Ret.uuid
        /^ update_abort_duplicate_work_manifests_for_context_query
        /% Var.(ud (uuid "context_id") (fun c -> c.Terrat_job_context.Context.id))
        /% Var.(ud (text "run_type") Terrat_work_manifest3.Step.to_string)
        /% Var.(str_array (text "dirs"))
        /% Var.(str_array (text "workspaces")))

    let select_conflicting_work_manifests_in_repo_query =
      read [%blob "sql/select_conflicting_work_manifests_in_repo2.sql"]

    let select_conflicting_work_manifests_in_repo () =
      Pgsql_io.Typed_sql.(
        sql
        //
        (* id *)
        Ret.uuid
        //
        (* maybe_stale *)
        Ret.boolean
        /^ select_conflicting_work_manifests_in_repo_query
        /% Var.bigint "repository"
        /% Var.bigint "pull_number"
        /% Var.(ud (text "run_type") Terrat_work_manifest3.Step.to_string)
        /% Var.(str_array (text "dirs"))
        /% Var.(str_array (text "workspaces")))

    let select_conflicting_work_manifests_in_repo_for_context_query =
      read [%blob "sql/select_conflicting_work_manifests_in_repo_for_context.sql"]

    let select_conflicting_work_manifests_in_repo_for_context () =
      Pgsql_io.Typed_sql.(
        sql
        //
        (* id *)
        Ret.uuid
        //
        (* maybe_stale *)
        Ret.boolean
        /^ select_conflicting_work_manifests_in_repo_for_context_query
        /% Var.(ud (uuid "context_id") (fun c -> c.Terrat_job_context.Context.id))
        /% Var.(ud (text "run_type") Terrat_work_manifest3.Step.to_string)
        /% Var.(str_array (text "dirs"))
        /% Var.(str_array (text "workspaces")))

    let select_dirspaces_owned_by_other_pull_requests_query =
      read [%blob "sql/select_dirspaces_owned_by_other_pull_requests.sql"]

    let select_dirspaces_owned_by_other_pull_requests () =
      Pgsql_io.Typed_sql.(
        sql
        //
        (* dir *)
        Ret.text
        //
        (* workspace *)
        Ret.text
        //
        (* base_branch *)
        Ret.text
        //
        (* branch *)
        Ret.text
        //
        (* base_hash *)
        Ret.text
        //
        (* hash *)
        Ret.text
        //
        (* merged_hash *)
        Ret.(option text)
        //
        (* merged_at *)
        Ret.(option text)
        //
        (* pull_number *)
        Ret.bigint
        //
        (* state *)
        Ret.text
        //
        (* title *)
        Ret.(option text)
        //
        (* username *)
        Ret.(option text)
        /^ select_dirspaces_owned_by_other_pull_requests_query
        /% Var.bigint "repository"
        /% Var.bigint "pull_number"
        /% Var.(str_array (text "dirs"))
        /% Var.(str_array (text "workspaces")))

    let select_missing_drift_scheduled_runs_query =
      read [%blob "sql/select_missing_drift_scheduled_runs.sql"]

    let select_missing_drift_scheduled_runs () =
      Pgsql_io.Typed_sql.(
        sql
        //
        (* drift name *)
        Ret.text
        //
        (* installation_id *)
        Ret.bigint
        //
        (* repository *)
        Ret.bigint
        //
        (* owner *)
        Ret.text
        //
        (* name *)
        Ret.text
        //
        (* reconcile *)
        Ret.boolean
        //
        (* tag_query *)
        Ret.(option (u text CCFun.(Terrat_tag_query.of_string %> CCResult.to_opt)))
        //
        (* window_start *)
        Ret.(option text)
        //
        (* window_end *)
        Ret.(option text)
        /^ select_missing_drift_scheduled_runs_query)

    let cleanup_repo_configs =
      Pgsql_io.Typed_sql.(sql /^ read [%blob "sql/cleanup_repo_configs.sql"])

    let delete_stale_flow_states_query = read [%blob "sql/delete_stale_flow_states.sql"]
    let delete_stale_flow_states () = Pgsql_io.Typed_sql.(sql /^ delete_stale_flow_states_query)

    let delete_old_plans =
      Pgsql_io.Typed_sql.(
        sql
        //
        (* count *)
        Ret.integer
        /^ read [%blob "sql/delete_old_terraform_plans.sql"])

    let insert_pull_request_unlock_query = read [%blob "sql/insert_pull_request_unlock.sql"]

    let insert_pull_request_unlock () =
      Pgsql_io.Typed_sql.(
        sql
        /^ insert_pull_request_unlock_query
        /% Var.bigint "repository"
        /% Var.bigint "pull_number")

    let insert_drift_unlock_query = read [%blob "sql/insert_drift_unlock.sql"]

    let insert_drift_unlock () =
      Pgsql_io.Typed_sql.(sql /^ insert_drift_unlock_query /% Var.bigint "repository")

    let select_recent_plan =
      Pgsql_io.Typed_sql.(
        sql
        //
        (* data *)
        Ret.text
        /^ read [%blob "sql/select_recent_plan.sql"]
        /% Var.uuid "id"
        /% Var.text "dir"
        /% Var.text "workspace")

    let delete_plan_query = read [%blob "sql/delete_terraform_plan.sql"]

    let delete_plan () =
      Pgsql_io.Typed_sql.(
        sql /^ delete_plan_query /% Var.uuid "id" /% Var.text "dir" /% Var.text "workspace")

    let upsert_plan =
      Pgsql_io.Typed_sql.(
        sql
        /^ read [%blob "sql/upsert_terraform_plan.sql"]
        /% Var.uuid "work_manifest"
        /% Var.text "path"
        /% Var.text "workspace"
        /% Var.(ud (text "data") Base64.encode_string)
        /% Var.boolean "has_changes")

    let insert_gate =
      Pgsql_io.Typed_sql.(
        sql
        /^ read [%blob "sql/insert_gate.sql"]
        /% Var.(option (text "name"))
        /% Var.(option (text "token"))
        /% Var.json "gate"
        /% Var.bigint "repository"
        /% Var.bigint "pull_number"
        /% Var.text "sha"
        /% Var.text "dir"
        /% Var.text "workspace")

    let upsert_branch_hash =
      Pgsql_io.Typed_sql.(
        sql
        /^ read [%blob "sql/upsert_branch_hash.sql"]
        /% Var.(ud (bigint "repo_id") CCFun.(Api.Repo.id %> CCInt64.of_int))
        /% Var.(ud (text "branch") Api.Ref.to_string)
        /% Var.(ud (text "hash") Api.Ref.to_string))

    let select_repo_by_id () =
      Pgsql_io.Typed_sql.(
        sql
        // Ret.bigint
        // Ret.text
        // Ret.text
        /^ read [%blob "sql/select_repo_by_id.sql"]
        /% Var.bigint "repo_id"
        /% Var.bigint "installation_id")

    let delete_repo () =
      Pgsql_io.Typed_sql.(
        sql
        /^ read [%blob "sql/delete_repo.sql"]
        /% Var.(ud (bigint "repo_id") CCInt64.of_int)
        /% Var.(ud (bigint "installation_id") CCInt64.of_int))
  end

  type t = Pgsql_io.t

  let load_work_manifests ~request_id db ids =
    let module Wm = Terrat_work_manifest3 in
    let module Dsf = Terrat_change.Dirspaceflow in
    let module Ds = Terrat_change.Dirspace in
    let ids = CCList.sort_uniq ~cmp:Uuidm.compare ids in
    match ids with
    | [] -> Abb.Future.return (Ok [])
    | _ -> (
        let group_rows_by_id rows =
          let tbl = Hashtbl.create (CCList.length rows) in
          CCList.iter
            (fun (id, v) ->
              let prev = CCOption.get_or ~default:[] (Hashtbl.find_opt tbl id) in
              Hashtbl.replace tbl id (v :: prev))
            rows;
          tbl
        in
        let index_rows_by_id rows =
          let tbl = Hashtbl.create (CCList.length rows) in
          CCList.iter (fun (id, v) -> Hashtbl.replace tbl id v) rows;
          tbl
        in
        let fetch_dirspaceflows () =
          Metrics.Psql_query_time.time
            (Metrics.psql_query_time "select_work_manifest_dirspaceflows_batch")
            (fun () ->
              Pgsql_io.Prepared_stmt.fetch
                db
                Sql.select_work_manifest_dirspaceflows_batch
                ~f:(fun wm_id dir idx workspace ->
                  (wm_id, { Dsf.dirspace = { Ds.dir; workspace }; workflow = idx; variables = None }))
                ids)
        in
        let fetch_denied_dirspaces () =
          Metrics.Psql_query_time.time
            (Metrics.psql_query_time "select_work_manifest_access_control_denied_dirspaces_batch")
            (fun () ->
              Pgsql_io.Prepared_stmt.fetch
                db
                Sql.select_work_manifest_access_control_denied_dirspaces_batch
                ~f:(fun wm_id dir workspace policy ->
                  (wm_id, { Wm.Deny.dirspace = { Terrat_change.Dirspace.dir; workspace }; policy }))
                ids)
        in
        let fetch_manifests dsf_tbl denied_tbl =
          Metrics.Psql_query_time.time
            (Metrics.psql_query_time "select_work_manifests_batch")
            (fun () ->
              Pgsql_io.Prepared_stmt.fetch
                db
                (Sql.select_work_manifests_batch ())
                ~f:(fun
                    id
                    base_ref
                    completed_at
                    created_at
                    pull_request_id
                    repo_id
                    run_id
                    run_type
                    branch_ref
                    state
                    tag_query
                    user
                    _run_kind
                    installation_id
                    owner
                    name
                    environment
                    runs_on
                    branch
                  ->
                  let changes =
                    CCOption.get_or ~default:[] (Hashtbl.find_opt dsf_tbl id) |> CCList.rev
                  in
                  let denied_dirspaces =
                    CCOption.get_or ~default:[] (Hashtbl.find_opt denied_tbl id) |> CCList.rev
                  in
                  {
                    Wm.account = Api.Account.make (CCInt64.to_int installation_id);
                    base_ref;
                    branch;
                    branch_ref;
                    changes;
                    completed_at;
                    created_at;
                    denied_dirspaces;
                    environment;
                    id;
                    initiator =
                      (match user with
                      | Some user -> Wm.Initiator.User user
                      | None -> Wm.Initiator.System);
                    run_id;
                    runs_on;
                    steps = [ run_type ];
                    state;
                    tag_query;
                    target =
                      ( CCOption.map CCInt64.to_int pull_request_id,
                        Api.Repo.make ~id:(CCInt64.to_int repo_id) ~owner ~name () );
                  })
                ids)
        in
        let fetch_pull_request_details pr_ids =
          match pr_ids with
          | [] -> Abb.Future.return (Ok (Hashtbl.create 0))
          | _ ->
              let open Abbs_future_combinators.Infix_result_monad in
              Metrics.Psql_query_time.time
                (Metrics.psql_query_time "select_work_manifest_pull_requests_batch")
                (fun () ->
                  Pgsql_io.Prepared_stmt.fetch
                    db
                    (Sql.select_work_manifest_pull_requests_batch ())
                    ~f:(fun
                        id
                        base_branch_name
                        base_ref
                        branch_name
                        branch_ref
                        pull_number
                        state
                        merged_sha
                        merged_at
                        title
                        user
                      ->
                      ( id,
                        ( base_branch_name,
                          base_ref,
                          branch_name,
                          branch_ref,
                          pull_number,
                          state,
                          merged_sha,
                          merged_at,
                          title,
                          user ) ))
                    pr_ids)
              >>= fun rows -> Abb.Future.return (Ok (index_rows_by_id rows))
        in
        let fetch_drift_details drift_ids =
          match drift_ids with
          | [] -> Abb.Future.return (Ok (Hashtbl.create 0))
          | _ ->
              let open Abbs_future_combinators.Infix_result_monad in
              Metrics.Psql_query_time.time
                (Metrics.psql_query_time "select_drift_work_manifests_batch")
                (fun () ->
                  Pgsql_io.Prepared_stmt.fetch
                    db
                    (Sql.select_drift_work_manifests_batch ())
                    ~f:(fun id branch _reconcile -> (id, branch))
                    drift_ids)
              >>= fun rows -> Abb.Future.return (Ok (index_rows_by_id rows))
        in
        let resolve_targets pr_tbl drift_tbl wms =
          CCList.filter_map
            (fun wm ->
              match wm.Wm.target with
              | Some _pull_request_id, repo -> (
                  match Hashtbl.find_opt pr_tbl wm.Wm.id with
                  | Some
                      ( base_branch_name,
                        base_ref,
                        branch_name,
                        branch_ref,
                        pull_number,
                        state,
                        merged_sha,
                        merged_at,
                        title,
                        user ) ->
                      let pr =
                        Api.Pull_request.make
                          ~base_branch_name:(Api.Ref.of_string base_branch_name)
                          ~base_ref:(Api.Ref.of_string base_ref)
                          ~branch_name:(Api.Ref.of_string branch_name)
                          ~branch_ref:(Api.Ref.of_string branch_ref)
                          ~checks:()
                          ~diff:()
                          ~draft:false
                          ~id:(CCInt64.to_int pull_number)
                          ~mergeable:None
                          ~provisional_merge_ref:None
                          ~repo
                          ~state:
                            (match (state, merged_sha, merged_at) with
                            | "open", _, _ -> Terrat_pull_request.State.(Open Open_status.Mergeable)
                            | "closed", _, _ -> Terrat_pull_request.State.Closed
                            | "merged", Some merged_hash, Some merged_at ->
                                Terrat_pull_request.State.(Merged Merged.{ merged_hash; merged_at })
                            | _ -> assert false)
                          ~title
                          ~user
                          ()
                      in
                      Some { wm with Wm.target = Terrat_vcs_provider2.Target.Pr pr }
                  | None -> None)
              | None, repo -> (
                  match Hashtbl.find_opt drift_tbl wm.Wm.id with
                  | Some branch ->
                      Some
                        { wm with Wm.target = Terrat_vcs_provider2.Target.Drift { repo; branch } }
                  | None -> None))
            wms
        in
        let run =
          let open Abbs_future_combinators.Infix_result_monad in
          fetch_dirspaceflows ()
          >>= fun dsf_rows ->
          fetch_denied_dirspaces ()
          >>= fun denied_rows ->
          let dsf_tbl = group_rows_by_id dsf_rows in
          let denied_tbl = group_rows_by_id denied_rows in
          fetch_manifests dsf_tbl denied_tbl
          >>= fun wms ->
          let pr_wms, drift_wms =
            CCList.partition
              (fun wm ->
                match wm.Wm.target with
                | Some _, _ -> true
                | None, _ -> false)
              wms
          in
          fetch_pull_request_details (CCList.map (fun wm -> wm.Wm.id) pr_wms)
          >>= fun pr_tbl ->
          fetch_drift_details (CCList.map (fun wm -> wm.Wm.id) drift_wms)
          >>= fun drift_tbl ->
          let results = resolve_targets pr_tbl drift_tbl wms in
          if CCList.length results <> CCList.length wms then (
            Logs.info (fun m ->
                m
                  "%s : QUERY_WORK_MANIFESTS_BATCH : MISSING_TARGET_DETAILS : expected=%d got=%d"
                  request_id
                  (CCList.length wms)
                  (CCList.length results));
            Abb.Future.return (Error `Error))
          else Abb.Future.return (Ok results)
        in
        let open Abb.Future.Infix_monad in
        run
        >>= function
        | Ok _ as ret -> Abb.Future.return ret
        | Error (#Pgsql_io.err as err) ->
            Prmths.Counter.inc_one Metrics.pgsql_errors_total;
            Logs.err (fun m -> m "%s : ERROR : %a" request_id Pgsql_io.pp_err err);
            Abb.Future.return (Error `Error)
        | Error `Error -> Abb.Future.return (Error `Error))

  let query_work_manifests ~request_id db ids =
    let ids = CCList.sort_uniq ~cmp:Uuidm.compare ids in
    let open Abb.Future.Infix_monad in
    load_work_manifests ~request_id db ids
    >>= function
    | Ok results when CCList.length results <> CCList.length ids ->
        Logs.info (fun m ->
            m
              "%s : QUERY_WORK_MANIFESTS : MISSING_MANIFESTS : expected=%d got=%d"
              request_id
              (CCList.length ids)
              (CCList.length results));
        Abb.Future.return (Error `Error)
    | Ok _ as ret -> Abb.Future.return ret
    | Error `Error -> Abb.Future.return (Error `Error)

  let query_work_manifest ~request_id db work_manifest_id =
    let open Abb.Future.Infix_monad in
    load_work_manifests ~request_id db [ work_manifest_id ]
    >>= function
    | Ok [] -> Abb.Future.return (Ok None)
    | Ok (wm :: _) -> Abb.Future.return (Ok (Some wm))
    | Error `Error -> Abb.Future.return (Error `Error)

  let store_account_repository ~request_id db account repo =
    let open Abb.Future.Infix_monad in
    Metrics.Psql_query_time.time
      (Metrics.psql_query_time "insert_gitlab_installation_repository")
      (fun () ->
        Pgsql_io.Prepared_stmt.execute
          db
          Sql.insert_gitlab_installation_repository
          (CCInt64.of_int (Api.Repo.id repo))
          (CCInt64.of_int (Api.Account.id account))
          (Api.Repo.owner repo)
          (Api.Repo.name repo))
    >>= function
    | Ok () -> Abb.Future.return (Ok ())
    | Error (#Pgsql_io.err as err) ->
        Prmths.Counter.inc_one Metrics.pgsql_errors_total;
        Logs.err (fun m -> m "%s : ERROR : %a" request_id Pgsql_io.pp_err err);
        Abb.Future.return (Error `Error)

  let lock_repository ~request_id db _account repo =
    let open Abb.Future.Infix_monad in
    Metrics.Psql_query_time.time (Metrics.psql_query_time "select_repository_for_update") (fun () ->
        Pgsql_io.Prepared_stmt.fetch
          db
          Sql.select_repository_for_update
          ~f:CCFun.id
          (CCInt64.of_int (Api.Repo.id repo)))
    >>= function
    | Ok _ -> Abb.Future.return (Ok ())
    | Error (#Pgsql_io.err as err) ->
        Prmths.Counter.inc_one Metrics.pgsql_errors_total;
        Logs.err (fun m -> m "%s : ERROR : %a" request_id Pgsql_io.pp_err err);
        Abb.Future.return (Error `Error)

  let store_pull_request ~request_id db pull_request =
    let open Abb.Future.Infix_monad in
    let module Pr = Api.Pull_request in
    let module State = Terrat_pull_request.State in
    let merged_sha, merged_at, state =
      match Pr.state pull_request with
      | State.Open _ -> (None, None, "open")
      | State.Closed -> (None, None, "closed")
      | State.(Merged { Merged.merged_hash; merged_at }) ->
          (Some merged_hash, Some merged_at, "merged")
    in
    Metrics.Psql_query_time.time (Metrics.psql_query_time "insert_pull_request") (fun () ->
        Pgsql_io.Prepared_stmt.execute
          db
          Sql.insert_pull_request
          (Api.Ref.to_string @@ Pr.base_branch_name pull_request)
          (Api.Ref.to_string @@ Pr.base_ref pull_request)
          (Api.Ref.to_string @@ Pr.branch_name pull_request)
          (CCInt64.of_int @@ Pr.id pull_request)
          (CCInt64.of_int @@ Api.Repo.id @@ Pr.repo pull_request)
          (Api.Ref.to_string @@ Pr.branch_ref pull_request)
          merged_sha
          merged_at
          state
          (Pr.title pull_request)
          (Pr.user pull_request))
    >>= function
    | Ok () -> Abb.Future.return (Ok ())
    | Error (#Pgsql_io.err as err) ->
        Prmths.Counter.inc_one Metrics.pgsql_errors_total;
        Logs.err (fun m -> m "%s : ERROR : %a" request_id Pgsql_io.pp_err err);
        Abb.Future.return (Error `Error)

  let index_of_index idx =
    let module Idx = Terrat_code_idx in
    let module Paths = Terrat_api_components.Work_manifest_index_paths in
    let module Symlinks = Terrat_api_components.Work_manifest_index_symlinks in
    let success = idx.Idx.success in
    let paths = Sln_map.String.to_list (Paths.additional idx.Idx.paths) in
    let symlinks =
      CCOption.map_or
        ~default:[]
        (fun idx -> Sln_map.String.to_list (Symlinks.additional idx))
        idx.Idx.symlinks
    in
    let failures =
      CCList.flat_map
        (fun (_path, { Paths.Additional.failures; _ }) ->
          let failures = Sln_map.String.to_list (Paths.Additional.Failures.additional failures) in
          CCList.map
            (fun (path, { Paths.Additional.Failures.Additional.lnum; msg }) ->
              { Terrat_vcs_provider2.Index.Failure.file = path; line_num = lnum; error = msg })
            failures)
        paths
    in
    let index =
      Terrat_base_repo_config_v1.Index.make
        ~symlinks
        (CCList.map
           (fun (path, { Paths.Additional.modules; _ }) ->
             (path, CCList.map (fun m -> Terrat_base_repo_config_v1.Index.Dep.Module m) modules))
           paths)
    in
    { Terrat_vcs_provider2.Index.success; failures; index }

  let store_index ~request_id db work_manifest_id index =
    let module R = Terrat_api_components.Work_manifest_index_result in
    let open Abb.Future.Infix_monad in
    Metrics.Psql_query_time.time (Metrics.psql_query_time "insert_index") (fun () ->
        Pgsql_io.Prepared_stmt.execute db (Sql.insert_index ()) work_manifest_id (R.to_yojson index))
    >>= function
    | Ok () -> Abb.Future.return (Ok (index_of_index index))
    | Error (#Pgsql_io.err as err) ->
        Prmths.Counter.inc_one Metrics.pgsql_errors_total;
        Logs.err (fun m -> m "%s : ERROR : %a" request_id Pgsql_io.pp_err err);
        Abb.Future.return (Error `Error)

  let store_index_result ~request_id db work_manifest_id index =
    let module Wm = Terrat_work_manifest3 in
    let module Idx = Terrat_code_idx in
    let run =
      let open Abbs_future_combinators.Infix_result_monad in
      let success = index.Idx.success in
      query_work_manifest ~request_id db work_manifest_id
      >>= function
      | Some { Wm.changes; _ } ->
          Abbs_future_combinators.List_result.iter
            ~f:(fun chunk ->
              let module Ds = Terrat_change.Dirspace in
              let work_manifest_id = CCList.replicate (CCList.length chunk) work_manifest_id in
              let success = CCList.replicate (CCList.length chunk) success in
              let dir =
                CCList.map
                  (fun dsf ->
                    let { Ds.dir; _ } = Terrat_change.Dirspaceflow.to_dirspace dsf in
                    dir)
                  chunk
              in
              let workspace =
                CCList.map
                  (fun dsf ->
                    let { Ds.workspace; _ } = Terrat_change.Dirspaceflow.to_dirspace dsf in
                    workspace)
                  chunk
              in
              Metrics.Psql_query_time.time
                (Metrics.psql_query_time "insert_gitlab_work_manifest_result")
                (fun () ->
                  Pgsql_io.Prepared_stmt.execute
                    db
                    Sql.insert_gitlab_work_manifest_result
                    work_manifest_id
                    dir
                    workspace
                    success))
            (CCList.chunks not_a_bad_chunk_size changes)
      | None -> assert false
    in
    let open Abb.Future.Infix_monad in
    run
    >>= function
    | Ok () -> Abb.Future.return (Ok ())
    | Error (#Pgsql_io.err as err) ->
        Prmths.Counter.inc_one Metrics.pgsql_errors_total;
        Logs.err (fun m -> m "%s : ERROR : %a" request_id Pgsql_io.pp_err err);
        Abb.Future.return (Error `Error)
    | Error `Error -> Abb.Future.return (Error `Error)

  let store_repo_config_json ~request_id db account ref_ json =
    let open Abb.Future.Infix_monad in
    Metrics.Psql_query_time.time (Metrics.psql_query_time "insert_repo_config") (fun () ->
        Pgsql_io.Prepared_stmt.execute
          db
          Sql.insert_repo_config
          (CCInt64.of_int @@ Api.Account.id account)
          (Api.Ref.to_string ref_)
          json)
    >>= function
    | Ok () -> Abb.Future.return (Ok ())
    | Error (#Pgsql_io.err as err) ->
        Prmths.Counter.inc_one Metrics.pgsql_errors_total;
        Logs.err (fun m -> m "%s : ERROR : %a" request_id Pgsql_io.pp_err err);
        Abb.Future.return (Error `Error)

  let store_repo_config_history ~request_id db account repo ~branch ~sha json =
    let open Abb.Future.Infix_monad in
    Metrics.Psql_query_time.time (Metrics.psql_query_time "insert_repo_config_history") (fun () ->
        Pgsql_io.Prepared_stmt.execute
          db
          Sql.insert_repo_config_history
          (Api.Ref.to_string branch)
          (Api.Ref.to_string sha)
          json
          (CCInt64.of_int @@ Api.Repo.id repo)
          (CCInt64.of_int @@ Api.Account.id account))
    >>= function
    | Ok () -> Abb.Future.return (Ok ())
    | Error (#Pgsql_io.err as err) ->
        Prmths.Counter.inc_one Metrics.pgsql_errors_total;
        Logs.err (fun m -> m "%s : ERROR : %a" request_id Pgsql_io.pp_err err);
        Abb.Future.return (Error `Error)

  let store_repo_tree ~request_id db account ref_ files =
    let module I = Terrat_api_components.Work_manifest_build_tree_result.Files.Items in
    let open Abb.Future.Infix_monad in
    Abbs_future_combinators.List_result.iter
      ~f:(fun chunk ->
        Metrics.Psql_query_time.time (Metrics.psql_query_time "insert_repo_tree") (fun () ->
            Pgsql_io.Prepared_stmt.execute
              db
              Sql.insert_repo_tree
              (CCList.replicate (CCList.length chunk) (Int64.of_int @@ Api.Account.id account))
              (CCList.replicate (CCList.length chunk) (Api.Ref.to_string ref_))
              (CCList.map (fun { I.path; _ } -> path) chunk)
              (CCList.map (fun { I.changed; _ } -> changed) chunk)
              (CCList.map (fun { I.id; _ } -> id) chunk)))
      (CCList.chunks not_a_bad_chunk_size files)
    >>= function
    | Ok () -> (
        (* Record the build itself.  An empty tree stores no rows, so this is
           the only way to tell a built-but-empty tree apart from one that was
           never built. *)
        Metrics.Psql_query_time.time (Metrics.psql_query_time "insert_repo_tree_build") (fun () ->
            Pgsql_io.Prepared_stmt.execute
              db
              Sql.insert_repo_tree_build
              (CCInt64.of_int @@ Api.Account.id account)
              (Api.Ref.to_string ref_))
        >>= function
        | Ok () -> Abb.Future.return (Ok ())
        | Error (#Pgsql_io.err as err) ->
            Prmths.Counter.inc_one Metrics.pgsql_errors_total;
            Logs.err (fun m -> m "%s : ERROR : %a" request_id Pgsql_io.pp_err err);
            Abb.Future.return (Error `Error))
    | Error (#Pgsql_io.err as err) ->
        Prmths.Counter.inc_one Metrics.pgsql_errors_total;
        Logs.err (fun m -> m "%s : ERROR : %a" request_id Pgsql_io.pp_err err);
        Abb.Future.return (Error `Error)

  let store_flow_state ~request_id db work_manifest_id data =
    let open Abb.Future.Infix_monad in
    Metrics.Psql_query_time.time (Metrics.psql_query_time "upsert_flow_state") (fun () ->
        Pgsql_io.Prepared_stmt.execute db (Sql.upsert_flow_state ()) work_manifest_id data)
    >>= function
    | Ok () -> Abb.Future.return (Ok ())
    | Error (#Pgsql_io.err as err) ->
        Logs.err (fun m -> m "%s: ERROR : %a" request_id Pgsql_io.pp_err err);
        Abb.Future.return (Error `Error)

  let store_dirspaceflows ~request_id ~base_ref ~branch_ref db repo dirspaceflows =
    let id = CCInt64.of_int (Api.Repo.id repo) in
    let run =
      Abbs_future_combinators.List_result.iter
        ~f:(fun dirspaceflows ->
          Metrics.Psql_query_time.time (Metrics.psql_query_time "insert_dirspace") (fun () ->
              Pgsql_io.Prepared_stmt.execute
                db
                Sql.insert_dirspace
                (CCList.replicate (CCList.length dirspaceflows) (Api.Ref.to_string base_ref))
                (CCList.map
                   (fun Terrat_change.{ Dirspaceflow.dirspace = { Dirspace.dir; _ }; _ } -> dir)
                   dirspaceflows)
                (CCList.replicate (CCList.length dirspaceflows) id)
                (CCList.replicate (CCList.length dirspaceflows) (Api.Ref.to_string branch_ref))
                (CCList.map
                   (fun Terrat_change.{ Dirspaceflow.dirspace = { Dirspace.workspace; _ }; _ } ->
                     workspace)
                   dirspaceflows)
                (CCList.map
                   (fun Terrat_change.{ Dirspaceflow.workflow = _, workflow; _ } ->
                     let module Dfwf = Terrat_change.Dirspaceflow.Workflow in
                     let module Wf = Terrat_base_repo_config_v1.Workflows.Entry in
                     CCOption.map_or
                       ~default:Terrat_base_repo_config_v1.Workflows.Entry.Lock_policy.Strict
                       (fun { Dfwf.workflow = { Wf.lock_policy; _ }; _ } -> lock_policy)
                       workflow)
                   dirspaceflows)
                (CCList.map
                   (fun Terrat_change.{ Dirspaceflow.workflow = lock_branch_target, _; _ } ->
                     lock_branch_target)
                   dirspaceflows)))
        (CCList.chunks not_a_bad_chunk_size dirspaceflows)
    in
    let open Abb.Future.Infix_monad in
    run
    >>= function
    | Ok () -> Abb.Future.return (Ok ())
    | Error (#Pgsql_io.err as err) ->
        Prmths.Counter.inc_one Metrics.pgsql_errors_total;
        Logs.err (fun m -> m "%s : ERROR : %a" request_id Pgsql_io.pp_err err);
        Abb.Future.return (Error `Error)

  let maybe_store_gates ~request_id db work_manifest_id = function
    | Some [] | None -> Abb.Future.return (Ok ())
    | Some gates -> (
        let open Abbs_future_combinators.Infix_result_monad in
        let module G = Terrat_api_components.Gate in
        let module Wm = Terrat_work_manifest3 in
        query_work_manifest ~request_id db work_manifest_id
        >>= function
        | Some { Wm.target = Terrat_vcs_provider2.Target.Pr pr; _ } ->
            let repo = CCInt64.of_int @@ Api.Repo.id @@ Terrat_pull_request.repo pr in
            let pull_number = CCInt64.of_int @@ Terrat_pull_request.id pr in
            let sha = Api.Ref.to_string @@ Terrat_pull_request.branch_ref pr in
            Abbs_future_combinators.List_result.iter
              ~f:(fun { G.all_of; any_of; any_of_count; dir; workspace; token; name } ->
                Abb.Future.return
                @@ CCResult.map_l Terrat_gate.Match.make
                @@ CCOption.get_or ~default:[] all_of
                >>= fun all_of ->
                Abb.Future.return
                @@ CCResult.map_l Terrat_gate.Match.make
                @@ CCOption.get_or ~default:[] any_of
                >>= fun any_of ->
                let gate =
                  {
                    Terrat_gate.all_of;
                    any_of;
                    any_of_count = CCOption.get_or ~default:0 any_of_count;
                  }
                in
                Pgsql_io.Prepared_stmt.execute
                  db
                  Sql.insert_gate
                  name
                  token
                  (Terrat_gate.to_yojson gate)
                  repo
                  pull_number
                  sha
                  (CCOption.get_or ~default:"" dir)
                  (CCOption.get_or ~default:"" workspace))
              gates
        | Some _ | None -> Abb.Future.return (Ok ()))

  let store_tf_operation_result ~request_id:_ _db _work_manifest_id _result =
    raise (Failure "NOT SUPPORTED")

  let store_tf_operation_result2 ~request_id db work_manifest_id result =
    let module R2 = Terrat_api_components_work_manifest_tf_operation_result2 in
    let open Abb.Future.Infix_monad in
    let steps_success steps =
      let module O = Terrat_api_components.Workflow_step_output in
      CCList.for_all (fun { O.success; ignore_errors; _ } -> success || ignore_errors) steps
    in
    let by_scope = By_scope.group result.R2.steps in
    let overall_success = CCList.for_all (fun (_, steps) -> steps_success steps) by_scope in
    let dirspaces =
      CCList.filter_map
        (function
          | Scope.Dirspace dirspace, steps -> Some (dirspace, steps)
          | _ -> None)
        by_scope
    in
    Prmths.Counter.inc_one (Metrics.run_overall_result_count (Bool.to_string overall_success));
    Abbs_time_it.run
      (fun time -> Logs.info (fun m -> m "%s : DIRSPACE_RESULT_STORE : time=%f" request_id time))
      (fun () ->
        let module O = Terrat_api_components.Workflow_step_output in
        let module Scope = Terrat_api_components.Workflow_step_output_scope in
        let open Abbs_future_combinators.Infix_result_monad in
        let steps = CCList.mapi (fun idx step -> (idx, step)) result.R2.steps in
        let gates = result.R2.gates in
        maybe_store_gates ~request_id db work_manifest_id gates
        >>= fun () ->
        let run =
          Abbs_future_combinators.List_result.iter
            ~f:(fun chunk ->
              let idx = CCList.map (fun (idx, _) -> idx) chunk in
              let ignore_errors =
                CCList.map (fun (_, { O.ignore_errors; _ }) -> ignore_errors) chunk
              in
              let payload =
                CCList.map
                  (fun (_, { O.payload; _ }) -> replace_nul_byte_json (O.Payload.to_yojson payload))
                  chunk
              in
              let scope =
                CCList.map
                  (fun (_, { O.scope; _ }) -> replace_nul_byte_json (Scope.to_yojson scope))
                  chunk
              in
              let step = CCList.map (fun (_, { O.step; _ }) -> replace_nul_byte step) chunk in
              let success = CCList.map (fun (_, { O.success; _ }) -> success) chunk in
              let work_manifest_id = CCList.replicate (CCList.length chunk) work_manifest_id in
              Metrics.Psql_query_time.time
                (Metrics.psql_query_time "insert_workflow_step_output")
                (fun () ->
                  Pgsql_io.Prepared_stmt.execute
                    db
                    Sql.insert_workflow_step_output
                    idx
                    ignore_errors
                    payload
                    scope
                    step
                    success
                    work_manifest_id))
            (CCList.chunks not_a_bad_chunk_size steps)
          >>= fun () ->
          let dirspaces =
            CCList.map (fun (dirspace, steps) -> (dirspace, steps_success steps)) dirspaces
          in
          CCList.iter
            (fun ({ Terrat_dirspace.dir; workspace }, success) ->
              Logs.info (fun m ->
                  m
                    "%s : RESULT_STORE : id=%a : dir=%s : workspace=%s : result=%s"
                    request_id
                    Uuidm.pp
                    work_manifest_id
                    dir
                    workspace
                    (if success then "SUCCESS" else "FAILURE")))
            dirspaces;
          Abbs_future_combinators.List_result.iter
            ~f:(fun chunk ->
              let work_manifest_id = CCList.replicate (CCList.length chunk) work_manifest_id in
              let dir = CCList.map (fun ({ Terrat_dirspace.dir; _ }, _) -> dir) chunk in
              let workspace =
                CCList.map (fun ({ Terrat_dirspace.workspace; _ }, _) -> workspace) chunk
              in
              let success = CCList.map (fun (_, success) -> success) chunk in
              Metrics.Psql_query_time.time
                (Metrics.psql_query_time "insert_gitlab_work_manifest_result")
                (fun () ->
                  Pgsql_io.Prepared_stmt.execute
                    db
                    Sql.insert_gitlab_work_manifest_result
                    work_manifest_id
                    dir
                    workspace
                    success))
            (CCList.chunks not_a_bad_chunk_size dirspaces)
        in
        let open Abb.Future.Infix_monad in
        (* Not sure why, but the type system was upset at me about something and this resolved it. *)
        run
        >>= function
        | Ok _ as res -> Abb.Future.return res
        | Error (#Pgsql_io.err as err) -> Abb.Future.return (Error err)
        | Error `Error -> Abb.Future.return (Error `Error))
    >>= function
    | Ok () -> Abb.Future.return (Ok ())
    | Error (`Match_parse_err err) ->
        Logs.info (fun m -> m "%s : MATCH_PARSE_ERR : %s" request_id err);
        Abb.Future.return (Error `Error)
    | Error (#Pgsql_io.err as err) ->
        Prmths.Counter.inc_one Metrics.pgsql_errors_total;
        Logs.err (fun m -> m "%s : %a" request_id Pgsql_io.pp_err err);
        Abb.Future.return (Error `Error)
    | Error `Error -> Abb.Future.return (Error `Error)

  let store_drift_schedule ~request_id db repo drift =
    let module D = Terrat_base_repo_config_v1.Drift in
    let { D.enabled; schedules; _ } = drift in
    let open Abb.Future.Infix_monad in
    (if enabled then
       Metrics.Psql_query_time.time (Metrics.psql_query_time "upsert_drift_schedule") (fun () ->
           let open Abbs_future_combinators.Infix_result_monad in
           let names = Iter.to_list @@ Sln_map.String.keys schedules in
           Pgsql_io.Prepared_stmt.execute
             db
             Sql.delete_drift_schedules
             (CCInt64.of_int @@ Api.Repo.id repo)
             names
           >>= fun () ->
           Abbs_future_combinators.List_result.iter
             ~f:(fun (name, { D.Schedule.reconcile; schedule; tag_query; window }) ->
               let window_start, window_end =
                 CCOption.map_or
                   ~default:(None, None)
                   (fun { D.Window.start; end_ } -> (Some start, Some end_))
                   window
               in
               Pgsql_io.Prepared_stmt.execute
                 db
                 Sql.upsert_drift_schedule
                 (CCInt64.of_int @@ Api.Repo.id repo)
                 schedule
                 reconcile
                 (Some tag_query)
                 name
                 window_start
                 window_end)
             (Sln_map.String.to_list schedules))
     else
       Pgsql_io.Prepared_stmt.execute
         db
         Sql.delete_drift_schedules
         (CCInt64.of_int @@ Api.Repo.id repo)
         [])
    >>= function
    | Ok () -> Abb.Future.return (Ok ())
    | Error (#Pgsql_io.err as err) ->
        Prmths.Counter.inc_one Metrics.pgsql_errors_total;
        Logs.err (fun m -> m "%s : ERROR : %a" request_id Pgsql_io.pp_err err);
        Abb.Future.return (Error `Error)

  let query_account_status ~request_id db account =
    let open Abb.Future.Infix_monad in
    Metrics.Psql_query_time.time
      (Metrics.psql_query_time "select_installation_account_status")
      (fun () ->
        Pgsql_io.Prepared_stmt.fetch
          db
          (Sql.select_installation_account_status ())
          ~f:(fun account_status trial_end_days -> (account_status, trial_end_days))
          (CCInt64.of_int @@ Api.Account.id account))
    >>= function
    | Ok (("expired", _) :: _) -> Abb.Future.return (Ok `Expired)
    | Ok (("disabled", _) :: _) -> Abb.Future.return (Ok `Disabled)
    | Ok (("trial_ending", Some trial_end_days) :: _) ->
        (* Ensure that trial end always is now or in the future *)
        Abb.Future.return
          (Ok (`Trial_ending (Duration.of_day (CCInt.max 0 (CCInt32.to_int trial_end_days)))))
    | Ok (("trial_ending", None) :: _) -> Abb.Future.return (Ok (`Trial_ending (Duration.of_day 0)))
    | Ok _ -> Abb.Future.return (Ok `Active)
    | Error (#Pgsql_io.err as err) ->
        Prmths.Counter.inc_one Metrics.pgsql_errors_total;
        Logs.err (fun m -> m "%s : ERROR : %a" request_id Pgsql_io.pp_err err);
        Abb.Future.return (Error `Error)

  let query_index ~request_id db account ref_ =
    let open Abb.Future.Infix_monad in
    Metrics.Psql_query_time.time (Metrics.psql_query_time "select_index") (fun () ->
        Pgsql_io.Prepared_stmt.fetch
          db
          Sql.select_index
          ~f:CCFun.id
          (CCInt64.of_int @@ Api.Account.id account)
          (Api.Ref.to_string ref_))
    >>= function
    | Ok (idx :: _) -> Abb.Future.return (Ok (Some (index_of_index idx)))
    | Ok [] -> Abb.Future.return (Ok None)
    | Error (#Pgsql_io.err as err) ->
        Prmths.Counter.inc_one Metrics.pgsql_errors_total;
        Logs.err (fun m -> m "%s : ERROR : %a" request_id Pgsql_io.pp_err err);
        Abb.Future.return (Error `Error)

  let query_repo_config_json ~request_id db account ref_ =
    let open Abb.Future.Infix_monad in
    Metrics.Psql_query_time.time (Metrics.psql_query_time "select_repo_config") (fun () ->
        Pgsql_io.Prepared_stmt.fetch
          db
          Sql.select_repo_config
          ~f:CCFun.id
          (CCInt64.of_int @@ Api.Account.id account)
          (Api.Ref.to_string ref_))
    >>= function
    | Ok (repo_config :: _) -> Abb.Future.return (Ok (Some repo_config))
    | Ok [] -> Abb.Future.return (Ok None)
    | Error (#Pgsql_io.err as err) ->
        Prmths.Counter.inc_one Metrics.pgsql_errors_total;
        Logs.err (fun m -> m "%s : ERROR : %a" request_id Pgsql_io.pp_err err);
        Abb.Future.return (Error `Error)

  let query_repo_tree ?base_ref ~request_id db account ref_ =
    let module I = Terrat_api_components.Work_manifest_build_tree_result.Files.Items in
    let open Abb.Future.Infix_monad in
    Metrics.Psql_query_time.time (Metrics.psql_query_time "select_repo_tree") (fun () ->
        Pgsql_io.Prepared_stmt.fetch
          db
          Sql.select_repo_tree
          ~f:(fun path changed ->
            (* We are being a bit lazy here and re-using the tree result object
               for the response from the database.  We are setting [id] to
               [None] because the query directly tells us if [changed] is true
               or false. *)
            { I.changed; path; id = None })
          (CCInt64.of_int @@ Api.Account.id account)
          (Api.Ref.to_string ref_)
          (CCOption.map Api.Ref.to_string base_ref))
    >>= function
    | Ok [] -> (
        (* No rows is ambiguous: either the tree was built and is empty, or it
           was never built.  [repo_tree_builds] tells the two apart. *)
        Metrics.Psql_query_time.time (Metrics.psql_query_time "select_repo_tree_build") (fun () ->
            Pgsql_io.Prepared_stmt.fetch
              db
              Sql.select_repo_tree_build
              ~f:CCFun.id
              (CCInt64.of_int @@ Api.Account.id account)
              (Api.Ref.to_string ref_))
        >>= function
        | Ok (_ :: _) -> Abb.Future.return (Ok (Some []))
        | Ok [] -> Abb.Future.return (Ok None)
        | Error (#Pgsql_io.err as err) ->
            Prmths.Counter.inc_one Metrics.pgsql_errors_total;
            Logs.err (fun m -> m "%s : ERROR : %a" request_id Pgsql_io.pp_err err);
            Abb.Future.return (Error `Error))
    | Ok files -> Abb.Future.return (Ok (Some files))
    | Error (#Pgsql_io.err as err) ->
        Prmths.Counter.inc_one Metrics.pgsql_errors_total;
        Logs.err (fun m -> m "%s : ERROR : %a" request_id Pgsql_io.pp_err err);
        Abb.Future.return (Error `Error)

  let query_next_pending_work_manifest ?new_age:(_ = false) ~request_id db =
    let run =
      let open Abbs_future_combinators.Infix_result_monad in
      Metrics.Psql_query_time.time (Metrics.psql_query_time "select_next_work_manifest") (fun () ->
          Pgsql_io.Prepared_stmt.fetch db ~f:CCFun.id Sql.select_next_work_manifest)
      >>= function
      | [] -> Abb.Future.return (Ok None)
      | [ id ] ->
          Abbs_time_it.run
            (fun time ->
              Logs.info (fun m ->
                  m "%s : QUERY_WORK_MANIFEST : id=%a : time=%f" request_id Uuidm.pp id time))
            (fun () ->
              query_work_manifest ~request_id db id
              >>= function
              | Some wm ->
                  let module Wm = Terrat_work_manifest3 in
                  assert (wm.Wm.state = Wm.State.Queued);
                  Abb.Future.return (Ok (Some wm))
              | None -> Abb.Future.return (Ok None))
      | _ :: _ -> assert false
    in
    let open Abb.Future.Infix_monad in
    run
    >>= function
    | Ok _ as ret -> Abb.Future.return ret
    | Error (#Pgsql_io.err as err) ->
        Logs.err (fun m -> m "%s: ERROR : %a" request_id Pgsql_io.pp_err err);
        Abb.Future.return (Error `Error)
    | Error (#Pgsql_pool.err as err) ->
        Logs.err (fun m -> m "%s: ERROR : %a" request_id Pgsql_pool.pp_err err);
        Abb.Future.return (Error `Error)
    | Error `Error -> Abb.Future.return (Error `Error)

  let query_flow_state ~request_id db work_manifest_id =
    let open Abb.Future.Infix_monad in
    Metrics.Psql_query_time.time (Metrics.psql_query_time "select_flow_state") (fun () ->
        Pgsql_io.Prepared_stmt.fetch db (Sql.select_flow_state ()) ~f:CCFun.id work_manifest_id)
    >>= function
    | Ok (data :: _) -> Abb.Future.return (Ok (Some data))
    | Ok [] -> Abb.Future.return (Ok None)
    | Error (#Pgsql_io.err as err) ->
        Logs.err (fun m -> m "%s: ERROR : %a" request_id Pgsql_io.pp_err err);
        Abb.Future.return (Error `Error)

  let delete_flow_state ~request_id db work_manifest_id =
    let open Abb.Future.Infix_monad in
    Metrics.Psql_query_time.time (Metrics.psql_query_time "delete_flow_state") (fun () ->
        Pgsql_io.Prepared_stmt.execute db (Sql.delete_flow_state ()) work_manifest_id)
    >>= function
    | Ok () -> Abb.Future.return (Ok ())
    | Error (#Pgsql_io.err as err) ->
        Logs.err (fun m -> m "%s: ERROR : %a" request_id Pgsql_io.pp_err err);
        Abb.Future.return (Error `Error)

  let query_pull_request_out_of_change_applies ~request_id db pull_request =
    let run =
      Metrics.Psql_query_time.time (Metrics.psql_query_time "select_out_of_diff_applies") (fun () ->
          Pgsql_io.Prepared_stmt.fetch
            db
            Sql.select_out_of_diff_applies
            ~f:(fun dir workspace -> Terrat_change.Dirspace.{ dir; workspace })
            (CCInt64.of_int @@ Api.Repo.id @@ Api.Pull_request.repo pull_request)
            (CCInt64.of_int @@ Api.Pull_request.id pull_request))
    in
    let open Abb.Future.Infix_monad in
    run
    >>= function
    | Ok dirspaces -> Abb.Future.return (Ok dirspaces)
    | Error (#Pgsql_io.err as err) ->
        Prmths.Counter.inc_one Metrics.pgsql_errors_total;
        Logs.err (fun m -> m "%s : ERROR : %a" request_id Pgsql_io.pp_err err);
        Abb.Future.return (Error `Error)

  let query_applied_dirspaces ~request_id db pull_request =
    let open Abb.Future.Infix_monad in
    Metrics.Psql_query_time.time
      (Metrics.psql_query_time "select_dirspace_applies_for_pull_request")
      (fun () ->
        Pgsql_io.Prepared_stmt.fetch
          db
          Sql.select_dirspace_applies_for_pull_request
          ~f:(fun dir workspace -> { Terrat_dirspace.dir; workspace })
          (CCInt64.of_int @@ Api.Repo.id @@ Api.Pull_request.repo pull_request)
          (CCInt64.of_int @@ Api.Pull_request.id pull_request))
    >>= function
    | Ok dirspaces -> Abb.Future.return (Ok dirspaces)
    | Error (#Pgsql_io.err as err) ->
        Prmths.Counter.inc_one Metrics.pgsql_errors_total;
        Logs.err (fun m -> m "%s : ERROR : %a" request_id Pgsql_io.pp_err err);
        Abb.Future.return (Error `Error)

  let query_applied_dirspaces_for_context ~request_id db context =
    let open Abb.Future.Infix_monad in
    Metrics.Psql_query_time.time
      (Metrics.psql_query_time "select_dirspace_applies_for_context")
      (fun () ->
        Pgsql_io.Prepared_stmt.fetch
          db
          Sql.select_dirspace_applies_for_context
          ~f:(fun dir workspace -> { Terrat_dirspace.dir; workspace })
          context)
    >>= function
    | Ok dirspaces -> Abb.Future.return (Ok dirspaces)
    | Error (#Pgsql_io.err as err) ->
        Prmths.Counter.inc_one Metrics.pgsql_errors_total;
        Logs.err (fun m -> m "%s : %a" request_id Pgsql_io.pp_err err);
        Abb.Future.return (Error `Error)

  let query_dirspaces_without_valid_plans
      ~request_id
      ~base_ref
      ~branch_ref
      db
      pull_request
      dirspaces =
    let open Abb.Future.Infix_monad in
    Metrics.Psql_query_time.time
      (Metrics.psql_query_time "select_dirspaces_without_valid_plans")
      (fun () ->
        Pgsql_io.Prepared_stmt.fetch
          db
          ~f:(fun dir workspace -> Terrat_change.Dirspace.{ dir; workspace })
          Sql.select_dirspaces_without_valid_plans
          (CCInt64.of_int @@ Api.Repo.id @@ Api.Pull_request.repo pull_request)
          (CCInt64.of_int @@ Api.Pull_request.id pull_request)
          (CCList.map (fun { Terrat_change.Dirspace.dir; _ } -> dir) dirspaces)
          (CCList.map (fun { Terrat_change.Dirspace.workspace; _ } -> workspace) dirspaces)
          base_ref
          branch_ref)
    >>= function
    | Ok _ as ret -> Abb.Future.return ret
    | Error (#Pgsql_io.err as err) ->
        Prmths.Counter.inc_one Metrics.pgsql_errors_total;
        Logs.err (fun m -> m "%s : ERROR : %a" request_id Pgsql_io.pp_err err);
        Abb.Future.return (Error `Error)

  let query_conflicting_work_manifests_in_repo ~request_id db pull_request dirspaces op =
    let run_type =
      match op with
      | `Plan -> Terrat_work_manifest3.Step.Plan
      | `Apply -> Terrat_work_manifest3.Step.Apply
    in
    let dirs = CCList.map (fun Terrat_change.Dirspace.{ dir; _ } -> dir) dirspaces in
    let workspaces =
      CCList.map (fun Terrat_change.Dirspace.{ workspace; _ } -> workspace) dirspaces
    in
    let run =
      let open Abbs_future_combinators.Infix_result_monad in
      Metrics.Psql_query_time.time
        (Metrics.psql_query_time "update_abort_duplicate_work_manifests")
        (fun () ->
          Pgsql_io.Prepared_stmt.fetch
            db
            (Sql.update_abort_duplicate_work_manifests ())
            ~f:CCFun.id
            (CCInt64.of_int @@ Api.Repo.id @@ Api.Pull_request.repo pull_request)
            (CCInt64.of_int @@ Api.Pull_request.id pull_request)
            run_type
            dirs
            workspaces)
      >>= fun ids ->
      CCList.iter
        (fun id -> Logs.info (fun m -> m "%s : ABORTED_WORK_MANIFEST : %a" request_id Uuidm.pp id))
        ids;
      Metrics.Psql_query_time.time
        (Metrics.psql_query_time "select_conflicting_work_manifests_in_repo")
        (fun () ->
          Pgsql_io.Prepared_stmt.fetch
            db
            (Sql.select_conflicting_work_manifests_in_repo ())
            ~f:(fun id maybe_stale -> (id, maybe_stale))
            (CCInt64.of_int @@ Api.Repo.id @@ Api.Pull_request.repo pull_request)
            (CCInt64.of_int @@ Api.Pull_request.id pull_request)
            run_type
            dirs
            workspaces)
      >>= fun ids ->
      match
        CCList.partition_filter_map
          (function
            | id, true -> `Right id
            | id, false -> `Left id)
          ids
      with
      | (_ :: _ as conflicting), _ ->
          Abbs_future_combinators.List_result.map
            ~f:(query_work_manifest ~request_id db)
            conflicting
          >>= fun wms ->
          Abb.Future.return
            (Ok
               (Some
                  (Terrat_vcs_provider2.Conflicting_work_manifests.Conflicting
                     (CCList.filter_map CCFun.id wms))))
      | _, (_ :: _ as maybe_stale) ->
          Abbs_future_combinators.List_result.map
            ~f:(query_work_manifest ~request_id db)
            maybe_stale
          >>= fun wms ->
          Abb.Future.return
            (Ok
               (Some
                  (Terrat_vcs_provider2.Conflicting_work_manifests.Maybe_stale
                     (CCList.filter_map CCFun.id wms))))
      | _, _ -> Abb.Future.return (Ok None)
    in
    let open Abb.Future.Infix_monad in
    run
    >>= function
    | Ok wms -> Abb.Future.return (Ok wms)
    | Error `Error -> Abb.Future.return (Error `Error)
    | Error (#Pgsql_io.err as err) ->
        Prmths.Counter.inc_one Metrics.pgsql_errors_total;
        Logs.err (fun m -> m "%s : ERROR : %a" request_id Pgsql_io.pp_err err);
        Abb.Future.return (Error `Error)

  let query_conflicting_work_manifests_in_repo_for_context ~request_id db context dirspaces op =
    let run_type =
      match op with
      | `Plan -> Terrat_work_manifest3.Step.Plan
      | `Apply -> Terrat_work_manifest3.Step.Apply
    in
    let dirs = CCList.map (fun Terrat_change.Dirspace.{ dir; _ } -> dir) dirspaces in
    let workspaces =
      CCList.map (fun Terrat_change.Dirspace.{ workspace; _ } -> workspace) dirspaces
    in
    let run =
      let open Abbs_future_combinators.Infix_result_monad in
      Metrics.Psql_query_time.time
        (Metrics.psql_query_time "update_abort_duplicate_work_manifests_for_context")
        (fun () ->
          Pgsql_io.Prepared_stmt.fetch
            db
            (Sql.update_abort_duplicate_work_manifests_for_context ())
            ~f:CCFun.id
            context
            run_type
            dirs
            workspaces)
      >>= fun ids ->
      CCList.iter
        (fun id -> Logs.info (fun m -> m "%s : ABORTED_WORK_MANIFEST : %a" request_id Uuidm.pp id))
        ids;
      Metrics.Psql_query_time.time
        (Metrics.psql_query_time "select_conflicting_work_manifests_in_repo_for_context")
        (fun () ->
          Pgsql_io.Prepared_stmt.fetch
            db
            (Sql.select_conflicting_work_manifests_in_repo_for_context ())
            ~f:(fun id maybe_stale -> (id, maybe_stale))
            context
            run_type
            dirs
            workspaces)
      >>= fun ids ->
      match
        CCList.partition_filter_map
          (function
            | id, true -> `Right id
            | id, false -> `Left id)
          ids
      with
      | (_ :: _ as conflicting), _ ->
          Abbs_future_combinators.List_result.map
            ~f:(query_work_manifest ~request_id db)
            conflicting
          >>= fun wms ->
          Abb.Future.return
            (Ok
               (Some
                  (Terrat_vcs_provider2.Conflicting_work_manifests.Conflicting
                     (CCList.filter_map CCFun.id wms))))
      | _, (_ :: _ as maybe_stale) ->
          Abbs_future_combinators.List_result.map
            ~f:(query_work_manifest ~request_id db)
            maybe_stale
          >>= fun wms ->
          Abb.Future.return
            (Ok
               (Some
                  (Terrat_vcs_provider2.Conflicting_work_manifests.Maybe_stale
                     (CCList.filter_map CCFun.id wms))))
      | _, _ -> Abb.Future.return (Ok None)
    in
    let open Abb.Future.Infix_monad in
    run
    >>= function
    | Ok wms -> Abb.Future.return (Ok wms)
    | Error `Error -> Abb.Future.return (Error `Error)
    | Error (#Pgsql_io.err as err) ->
        Prmths.Counter.inc_one Metrics.pgsql_errors_total;
        Logs.err (fun m -> m "%s : ERROR : %a" request_id Pgsql_io.pp_err err);
        Abb.Future.return (Error `Error)

  let query_dirspaces_owned_by_other_pull_requests ~request_id db pull_request dirspaces =
    let open Abb.Future.Infix_monad in
    Metrics.Psql_query_time.time
      (Metrics.psql_query_time "select_dirspaces_owned_by_other_pull_requests")
      (fun () ->
        Pgsql_io.Prepared_stmt.fetch
          db
          (Sql.select_dirspaces_owned_by_other_pull_requests ())
          ~f:(fun
              dir
              workspace
              base_branch
              branch
              base_hash
              hash
              merged_hash
              merged_at
              pull_number
              state
              title
              user
            ->
            ( Terrat_change.Dirspace.{ dir; workspace },
              Api.Pull_request.make
                ~base_branch_name:(Api.Ref.of_string base_branch)
                ~base_ref:(Api.Ref.of_string base_hash)
                ~branch_name:(Api.Ref.of_string branch)
                ~branch_ref:(Api.Ref.of_string hash)
                ~checks:()
                ~diff:()
                ~draft:false
                ~id:(CCInt64.to_int pull_number)
                ~mergeable:None
                ~provisional_merge_ref:None
                ~repo:(Api.Pull_request.repo pull_request)
                ~state:
                  (match (state, merged_hash, merged_at) with
                  | "open", _, _ -> Terrat_pull_request.State.(Open Open_status.Mergeable)
                  | "closed", _, _ -> Terrat_pull_request.State.Closed
                  | "merged", Some merged_hash, Some merged_at ->
                      Terrat_pull_request.State.(Merged Merged.{ merged_hash; merged_at })
                  | _ -> assert false)
                ~title
                ~user
                () ))
          (CCInt64.of_int @@ Api.Repo.id @@ Api.Pull_request.repo pull_request)
          (CCInt64.of_int @@ Api.Pull_request.id pull_request)
          (CCList.map (fun { Terrat_change.Dirspace.dir; _ } -> dir) dirspaces)
          (CCList.map (fun { Terrat_change.Dirspace.workspace; _ } -> workspace) dirspaces))
    >>= function
    | Ok _ as res -> Abb.Future.return res
    | Error (#Pgsql_io.err as err) ->
        Prmths.Counter.inc_one Metrics.pgsql_errors_total;
        Logs.err (fun m -> m "%s : ERROR : %a" request_id Pgsql_io.pp_err err);
        Abb.Future.return (Error `Error)

  let query_missing_drift_scheduled_runs ~request_id db =
    let open Abb.Future.Infix_monad in
    Metrics.Psql_query_time.time
      (Metrics.psql_query_time "select_missing_drift_scheduled_runs")
      (fun () ->
        Pgsql_io.Prepared_stmt.fetch
          db
          (Sql.select_missing_drift_scheduled_runs ())
          ~f:(fun
              drift_name
              installation_id
              repository_id
              owner
              name
              reconcile
              tag_query
              window_start
              window_end
            ->
            ( drift_name,
              Api.Account.make @@ CCInt64.to_int installation_id,
              Api.Repo.make ~id:(CCInt64.to_int repository_id) ~owner ~name (),
              reconcile,
              CCOption.get_or ~default:Terrat_tag_query.any tag_query,
              CCOption.map2
                (fun window_start window_end -> (window_start, window_end))
                window_start
                window_end )))
    >>= function
    | Ok _ as ret -> Abb.Future.return ret
    | Error (#Pgsql_io.err as err) ->
        Logs.err (fun m -> m "%s : DRIFT : %a" request_id Pgsql_io.pp_err err);
        Abb.Future.return (Error `Error)

  let cleanup_repo_configs ~request_id db =
    let open Abb.Future.Infix_monad in
    Metrics.Psql_query_time.time (Metrics.psql_query_time "cleanup_repo_configs") (fun () ->
        Pgsql_io.Prepared_stmt.execute db Sql.cleanup_repo_configs)
    >>= function
    | Ok () -> Abb.Future.return (Ok ())
    | Error (#Pgsql_io.err as err) ->
        Prmths.Counter.inc_one Metrics.pgsql_errors_total;
        Logs.err (fun m -> m "%s : ERROR : %a" request_id Pgsql_io.pp_err err);
        Abb.Future.return (Error `Error)

  let cleanup_flow_states ~request_id db =
    let open Abb.Future.Infix_monad in
    Metrics.Psql_query_time.time (Metrics.psql_query_time "delete_stale_flow_states") (fun () ->
        Pgsql_io.Prepared_stmt.execute db (Sql.delete_stale_flow_states ()))
    >>= function
    | Ok () -> Abb.Future.return (Ok ())
    | Error (#Pgsql_io.err as err) ->
        Logs.err (fun m -> m "%s: ERROR : %a" request_id Pgsql_io.pp_err err);
        Abb.Future.return (Error `Error)

  let cleanup_plans ~request_id db =
    let open Abb.Future.Infix_monad in
    Metrics.Psql_query_time.time (Metrics.psql_query_time "delete_old_plans") (fun () ->
        Pgsql_io.Prepared_stmt.fetch db Sql.delete_old_plans ~f:CCFun.id)
    >>= function
    | Ok [] -> assert false
    | Ok (count :: _) ->
        Logs.info (fun m -> m "%s : PLAN_CLEANUP : %d" request_id (Int32.to_int count));
        Abb.Future.return (Ok ())
    | Error (#Pgsql_io.err as err) ->
        Logs.err (fun m -> m "%s : %a" request_id Pgsql_io.pp_err err);
        Abb.Future.return (Error `Error)

  let unlock' db repo = function
    | Unlock_id.Pull_request pull_request_id ->
        Metrics.Psql_query_time.time
          (Metrics.psql_query_time "insert_pull_request_unlock")
          (fun () ->
            Pgsql_io.Prepared_stmt.execute
              db
              (Sql.insert_pull_request_unlock ())
              (CCInt64.of_int @@ Api.Repo.id repo)
              (CCInt64.of_int pull_request_id))
    | Unlock_id.Drift ->
        Metrics.Psql_query_time.time (Metrics.psql_query_time "insert_drift_unlock") (fun () ->
            Pgsql_io.Prepared_stmt.execute
              db
              (Sql.insert_drift_unlock ())
              (CCInt64.of_int @@ Api.Repo.id repo))

  let unlock ~request_id db repo unlock_id =
    let open Abb.Future.Infix_monad in
    unlock' db repo unlock_id
    >>= function
    | Ok _ as ret -> Abb.Future.return ret
    | Error (#Pgsql_io.err as err) ->
        Logs.err (fun m -> m "%s: ERROR : %a" request_id Pgsql_io.pp_err err);
        Abb.Future.return (Error `Error)
    | Error (#Pgsql_pool.err as err) ->
        Logs.err (fun m -> m "%s: ERROR : %a" request_id Pgsql_pool.pp_err err);
        Abb.Future.return (Error `Error)

  let query_plan ~request_id db work_manifest_id dirspace =
    let run =
      let open Abbs_future_combinators.Infix_result_monad in
      Metrics.Psql_query_time.time (Metrics.psql_query_time "select_recent_plan") (fun () ->
          Pgsql_io.Prepared_stmt.fetch
            db
            Sql.select_recent_plan
            ~f:CCFun.id
            work_manifest_id
            dirspace.Terrat_dirspace.dir
            dirspace.Terrat_dirspace.workspace)
      >>= function
      | [] -> Abb.Future.return (Ok None)
      | data :: _ ->
          Metrics.Psql_query_time.time (Metrics.psql_query_time "delete_plan") (fun () ->
              Pgsql_io.Prepared_stmt.execute
                db
                (Sql.delete_plan ())
                work_manifest_id
                dirspace.Terrat_dirspace.dir
                dirspace.Terrat_dirspace.workspace)
          >>= fun () -> Abb.Future.return (Ok (Some data))
    in
    let open Abb.Future.Infix_monad in
    run
    >>= function
    | Ok _ as ret -> Abb.Future.return ret
    | Error (#Pgsql_io.err as err) ->
        Prmths.Counter.inc_one Metrics.pgsql_errors_total;
        Logs.err (fun m -> m "%s : ERROR : %a" request_id Pgsql_io.pp_err err);
        Abb.Future.return (Error `Error)

  let store_plan ~request_id db work_manifest_id dirspace data has_changes =
    let open Abb.Future.Infix_monad in
    Metrics.Psql_query_time.time (Metrics.psql_query_time "upsert_plan") (fun () ->
        Pgsql_io.Prepared_stmt.execute
          db
          Sql.upsert_plan
          work_manifest_id
          dirspace.Terrat_dirspace.dir
          dirspace.Terrat_dirspace.workspace
          data
          has_changes)
    >>= function
    | Ok () -> Abb.Future.return (Ok ())
    | Error (#Pgsql_io.err as err) ->
        Prmths.Counter.inc_one Metrics.pgsql_errors_total;
        Logs.err (fun m -> m "%s : ERROR : %a" request_id Pgsql_io.pp_err err);
        Abb.Future.return (Error `Error)

  let store_branch_hash ~request_id ~branch_name ~branch_ref repo db =
    let open Abb.Future.Infix_monad in
    Metrics.Psql_query_time.time (Metrics.psql_query_time "store_branch_hash") (fun () ->
        Pgsql_io.Prepared_stmt.execute db Sql.upsert_branch_hash repo branch_name branch_ref)
    >>= function
    | Ok () -> Abb.Future.return (Ok ())
    | Error (#Pgsql_io.err as err) ->
        Prmths.Counter.inc_one Metrics.pgsql_errors_total;
        Logs.err (fun m -> m "%s : %a" request_id Pgsql_io.pp_err err);
        Abb.Future.return (Error `Error)

  let query_repo_by_id ~request_id db installation_id repo_id =
    let open Abb.Future.Infix_monad in
    Metrics.Psql_query_time.time (Metrics.psql_query_time "select_repo_by_id") (fun () ->
        Pgsql_io.Prepared_stmt.fetch
          db
          (Sql.select_repo_by_id ())
          ~f:(fun id owner name -> Api.Repo.make ~id:(Int64.to_int id) ~owner ~name ())
          (CCInt64.of_int repo_id)
          (CCInt64.of_int installation_id))
    >>= function
    | Ok (repo :: _) -> Abb.Future.return (Ok (Some repo))
    | Ok [] -> Abb.Future.return (Ok None)
    | Error (#Pgsql_io.err as err) ->
        Prmths.Counter.inc_one Metrics.pgsql_errors_total;
        Logs.err (fun m -> m "%s : ERROR : %a" request_id Pgsql_io.pp_err err);
        Abb.Future.return (Error `Error)

  let delete_repo ~request_id db installation_id repo_id =
    let open Abb.Future.Infix_monad in
    Metrics.Psql_query_time.time (Metrics.psql_query_time "delete_repo") (fun () ->
        Pgsql_io.Prepared_stmt.execute db (Sql.delete_repo ()) repo_id installation_id)
    >>= function
    | Ok () -> Abb.Future.return (Ok ())
    | Error (#Pgsql_io.err as err) ->
        Prmths.Counter.inc_one Metrics.pgsql_errors_total;
        Logs.err (fun m -> m "%s : ERROR : %a" request_id Pgsql_io.pp_err err);
        Abb.Future.return (Error `Error)
end

module Apply_requirements = struct
  module Result = struct
    type result = {
      apply_after_merge : bool option;
      approved : bool option;
      approved_reviews : Terrat_pull_request_review.t list;
      missing_reviews : Terrat_base_repo_config_v1.Access_control.Match.t list;
      missing_any_of_count : int;
      any_of_count : int;
      any_of : Terrat_base_repo_config_v1.Access_control.Match.t list;
      match_ : Terrat_change_match3.Dirspace_config.t;
      merge_conflicts : bool option;
      passed : bool option;
      ready_for_review : bool option;
      status_checks : bool option;
      status_checks_failed : Terrat_commit_check.t list;
    }

    type t = result list

    let passed t = CCList.for_all (fun { passed; _ } -> CCOption.get_or ~default:false passed) t

    let approved_reviews t =
      CCList.flatten (CCList.map (fun { approved_reviews; _ } -> approved_reviews) t)
  end

  (* Order matters here.  Roles closer to the beginning of the search are more
         powerful than those closer to the end *)
  let repo_permission_levels =
    [
      ("admin", "admin");
      ("maintain", "maintain");
      ("write", "write");
      ("triage", "triage");
      ("read", "read");
    ]

  let match_query ~request_id client repo user =
    let module M = Terrat_base_repo_config_v1.Access_control.Match in
    function
    | M.User value -> Abb.Future.return (Ok (CCString.equal value @@ Api.User.to_string user))
    | M.Team value -> (
        let open Abb.Future.Infix_monad in
        Api.is_member_of_team ~request_id ~team:value ~user repo client
        >>= function
        | Ok res -> Abb.Future.return (Ok res)
        | Error _ -> Abb.Future.return (Error `Error))
    | M.Role value -> (
        let open Abb.Future.Infix_monad in
        match CCList.find_idx CCFun.(fst %> CCString.equal value) repo_permission_levels with
        | Some (idx, _) -> (
            Api.get_repo_role ~request_id repo user client
            >>= function
            | Ok (Some role) -> (
                match CCList.find_idx CCFun.(snd %> CCString.equal role) repo_permission_levels with
                | Some (idx_role, _) ->
                    (* Test if their actual role has an index less than or
                           equal to the index of the role in the query. *)
                    Abb.Future.return (Ok (idx_role <= idx))
                | None -> Abb.Future.return (Ok false))
            | Ok None -> Abb.Future.return (Ok false)
            | Error _ -> Abb.Future.return (Error `Error))
        | None -> raise (Failure "nyi")
        (* Abb.Future.return (Error (`Invalid_query query)) *))
    | M.Any -> Abb.Future.return (Ok true)

  let compute_approved ~request_id client repo approved approved_reviews requested_reviews =
    let module Match_set = CCSet.Make (Terrat_base_repo_config_v1.Access_control.Match) in
    let module Match_map = CCMap.Make (Terrat_base_repo_config_v1.Access_control.Match) in
    let open Abbs_future_combinators.Infix_result_monad in
    let module Tprr = Terrat_pull_request_review in
    let module Ac = Terrat_base_repo_config_v1.Apply_requirements.Approved in
    let { Ac.all_of; any_of; any_of_count; enabled = _; require_completed_reviews } = approved in
    let combined_queries = Match_set.(to_list (of_list (all_of @ any_of))) in
    Abbs_future_combinators.List_result.fold_left
      ~init:Match_map.empty
      ~f:(fun acc query ->
        Abbs_future_combinators.List_result.filter_map
          ~f:(function
            | { Tprr.user = Some user; _ } -> (
                let user = Api.User.make user in
                match_query ~request_id client repo user query
                >>= function
                | true -> Abb.Future.return (Ok (Some user))
                | false -> Abb.Future.return (Ok None))
            | _ -> Abb.Future.return (Ok None))
          approved_reviews
        >>= fun matching_reviews ->
        (* [query] is something like "user:foo" or "team:bar" and
           [approved_reviews] are the list of reviews for this PR.
           [matching_reviews] are the users that match this query. *)
        Abb.Future.return
          (Ok
             (CCList.fold_left
                (fun acc user -> Match_map.add_to_list query user acc)
                acc
                matching_reviews)))
      combined_queries
    >>= fun matching_reviews ->
    (* [matching_reviews] is a map from a query to those users that approved and
       match that query. *)
    let all_of_results, all_of_missing =
      CCList.partition (CCFun.flip Match_map.mem matching_reviews) all_of
    in
    let any_of_results =
      CCList.flatten (CCList.filter_map (CCFun.flip Match_map.find_opt matching_reviews) any_of)
    in
    let all_of_passed = CCList.length all_of_results = CCList.length all_of in
    let missing_any_of =
      CCInt.max
        0
        (if CCList.is_empty any_of then any_of_count - CCList.length approved_reviews
         else any_of_count - CCList.length any_of_results)
    in
    let any_of_passed = missing_any_of = 0 in
    let required_reviews_passed =
      (not require_completed_reviews) || CCList.is_empty requested_reviews
    in
    let missing_reviews =
      all_of_missing @ if require_completed_reviews then requested_reviews else []
    in
    Logs.info (fun m ->
        m
          "%s : COMPUTE_APPROVED : all_of_passed=%s : any_of_passed=%s"
          request_id
          (Bool.to_string all_of_passed)
          (Bool.to_string any_of_passed));
    (* Considered approved if all "all_of" passes and any "any_of" passes OR
         "all of" and "any of" are empty and the approvals is more than count *)
    Abb.Future.return
      (Ok
         ( all_of_passed && any_of_passed && required_reviews_passed,
           missing_reviews,
           missing_any_of,
           any_of_count ))

  let eval ~request_id _config _user client repo_config pull_request dirspace_configs =
    let max_parallel = 20 in
    let module R = Terrat_base_repo_config_v1 in
    let module Ar = R.Apply_requirements in
    let module Abc = Ar.Check in
    let module Afm = Ar.Apply_after_merge in
    let module Mc = Ar.Merge_conflicts in
    let module Sc = Ar.Status_checks in
    let open Abbs_future_combinators.Infix_result_monad in
    let log_time ?m request_id name t =
      Logs.info (fun m -> m "%s : %s : %f" request_id name t);
      match m with
      | Some m -> Metrics.Time_histogram.observe m t
      | None -> ()
    in
    let filter_relevant_commit_checks ignore_matching_pats ignore_matching commit_checks =
      CCList.filter
        (fun Terrat_commit_check.{ title; _ } ->
          not
            (CCString.equal "terrateam_job" title
            || CCString.equal "terrateam apply" title
            || CCList.exists CCFun.(Lua_pattern.find title %> CCOption.is_some) ignore_matching_pats
            || CCList.exists (CCString.equal title) ignore_matching))
        commit_checks
    in
    let { Ar.checks; _ } = R.apply_requirements repo_config in
    Abbs_future_combinators.Infix_result_app.(
      (fun reviews commit_checks requested_reviews -> (reviews, commit_checks, requested_reviews))
      <$> Abbs_time_it.run (log_time request_id "FETCH_APPROVED_TIME") (fun () ->
          Api.fetch_pull_request_reviews
            ~request_id
            (Api.Pull_request.repo pull_request)
            (Api.Pull_request.id pull_request)
            client)
      <*> Abbs_time_it.run (log_time request_id "FETCH_COMMIT_CHECKS_TIME") (fun () ->
          Api.fetch_commit_checks
            ~request_id
            client
            (Api.Pull_request.repo pull_request)
            (Api.Pull_request.branch_ref pull_request))
      <*> Abbs_time_it.run (log_time request_id "FETCH_REQUESTED_REVIEWS") (fun () ->
          Api.fetch_pull_request_requested_reviews
            ~request_id
            (Api.Pull_request.repo pull_request)
            (Api.Pull_request.id pull_request)
            client))
    >>= fun (reviews, commit_checks, requested_reviews) ->
    let approved_reviews =
      CCList.filter
        (function
          | Terrat_pull_request_review.{ status = Status.Approved; _ } -> true
          | _ -> false)
        reviews
    in
    let merge_result = CCOption.get_or ~default:false @@ Api.Pull_request.mergeable pull_request in
    if CCOption.is_none @@ Api.Pull_request.mergeable pull_request then
      Logs.info (fun m -> m "%s : MERGEABLE_NONE" request_id);
    let open Abb.Future.Infix_monad in
    Abbs_future_combinators.List_result.map
      ~f:(fun chunk ->
        Abbs_future_combinators.List_result.map
          ~f:(fun ({ Terrat_change_match3.Dirspace_config.tags; dirspace; _ } as match_) ->
            let open Abbs_future_combinators.Infix_result_monad in
            Logs.info (fun m ->
                m
                  "%s : CHECK_APPLY_REQUIREMENTS : dir=%s : workspace=%s"
                  request_id
                  dirspace.Terrat_dirspace.dir
                  dirspace.Terrat_dirspace.workspace);
            match
              CCList.find_opt
                (fun { Abc.tag_query; _ } ->
                  let ctx = Terrat_tag_query.Ctx.make ~dirspace () in
                  Terrat_tag_query.match_ ~ctx ~tag_set:tags tag_query)
                checks
            with
            | Some
                {
                  Abc.tag_query;
                  apply_after_merge;
                  merge_conflicts;
                  status_checks;
                  approved;
                  require_ready_for_review_pr;
                } ->
                compute_approved
                  ~request_id
                  client
                  (Api.Pull_request.repo pull_request)
                  approved
                  approved_reviews
                  requested_reviews
                >>= fun (approved_result, missing_reviews, missing_any_of_count, any_of_count) ->
                let module Ac = Terrat_base_repo_config_v1.Apply_requirements.Approved in
                let { Ac.any_of; _ } = approved in
                let ignore_matching = status_checks.Sc.ignore_matching in
                (* Convert all patterns and ignore those that don't compile.  This eats
                     errors.

                     TODO: Improve handling errors here *)
                let ignore_matching_pats =
                  CCList.filter_map Lua_pattern.of_string ignore_matching
                in
                (* Relevant checks exclude our terrateam checks, and also exclude any
                     ignored patterns.  We check both if a pattern matches OR if there is an
                     exact match with the string.  This is because someone might put in an
                     invalid pattern (because secretly we are using Lua patterns underneath
                     which have a slightly different syntax) *)
                let relevant_commit_checks =
                  filter_relevant_commit_checks ignore_matching_pats ignore_matching commit_checks
                in
                let failed_commit_checks =
                  CCList.filter
                    (function
                      | Terrat_commit_check.{ status = Status.Completed; _ } -> false
                      | _ -> true)
                    relevant_commit_checks
                in
                CCList.iter
                  (fun { Terrat_commit_check.title; status; _ } ->
                    Logs.debug (fun m ->
                        m
                          "%s : COMMIT_CHECK : %s : %a"
                          request_id
                          title
                          Terrat_commit_check.Status.pp
                          status))
                  relevant_commit_checks;
                let all_commit_check_success = CCList.is_empty failed_commit_checks in
                let merged =
                  let module St = Terrat_pull_request.State in
                  match Api.Pull_request.state pull_request with
                  | St.Merged _ -> true
                  | St.Open _ | St.Closed -> false
                in
                let ready_for_review =
                  (not require_ready_for_review_pr)
                  || not (Api.Pull_request.is_draft_pr pull_request)
                in
                let passed =
                  merged
                  || ((not approved.Ac.enabled) || approved_result)
                     && ((not merge_conflicts.Mc.enabled) || merge_result)
                     && ((not status_checks.Sc.enabled) || all_commit_check_success)
                     && (not apply_after_merge.Afm.enabled)
                     && ready_for_review
                in
                let apply_requirements =
                  {
                    Result.passed = Some passed;
                    match_;
                    apply_after_merge =
                      (if apply_after_merge.Afm.enabled then Some merged else None);
                    approved = (if approved.Ac.enabled then Some approved_result else None);
                    merge_conflicts =
                      (if merge_conflicts.Mc.enabled then Some merge_result else None);
                    ready_for_review =
                      (if require_ready_for_review_pr then Some ready_for_review else None);
                    status_checks =
                      (if status_checks.Sc.enabled then Some all_commit_check_success else None);
                    status_checks_failed = failed_commit_checks;
                    approved_reviews;
                    missing_reviews;
                    missing_any_of_count;
                    any_of_count;
                    any_of;
                  }
                in
                Logs.info (fun m ->
                    m
                      "%s : APPLY_REQUIREMENTS_CHECKS : tag_query=%s approved=%s \
                       merge_conflicts=%s status_checks=%s require_ready_for_review=%s"
                      request_id
                      (Terrat_tag_query.to_string tag_query)
                      (Bool.to_string approved.Ac.enabled)
                      (Bool.to_string merge_conflicts.Mc.enabled)
                      (Bool.to_string status_checks.Sc.enabled)
                      (Bool.to_string require_ready_for_review_pr));
                Logs.info (fun m ->
                    m
                      "%s : APPLY_REQUIREMENTS_RESULT : tag_query=%s approved=%s merge_check=%s \
                       commit_check=%s merged=%s ready_for_review=%s passed=%s"
                      request_id
                      (Terrat_tag_query.to_string tag_query)
                      (Bool.to_string approved_result)
                      (Bool.to_string merge_result)
                      (Bool.to_string all_commit_check_success)
                      (Bool.to_string merged)
                      (Bool.to_string ready_for_review)
                      (Bool.to_string passed));
                Abb.Future.return (Ok apply_requirements)
            | None ->
                Logs.info (fun m -> m "%s : NO_APPLY_REQUIREMENTS_MATCHED" request_id);
                Abb.Future.return
                  (Ok
                     {
                       Result.passed = None;
                       match_;
                       apply_after_merge = None;
                       approved = None;
                       merge_conflicts = None;
                       ready_for_review = None;
                       status_checks = None;
                       status_checks_failed = [];
                       approved_reviews = [];
                       missing_reviews = [];
                       missing_any_of_count = 0;
                       any_of_count = 0;
                       any_of = [];
                     }))
          chunk)
      (CCList.chunks (CCInt.max 1 (CCList.length dirspace_configs / max_parallel)) dirspace_configs)
    >>= function
    | Ok ret -> Abb.Future.return (Ok (CCList.flatten ret))
    | Error (`Error as ret) -> Abb.Future.return (Error ret)
end

module Tier = struct
  module Sql = struct
    let read s =
      s
      |> CCString.split_on_char '\n'
      |> CCList.filter CCFun.(CCString.prefix ~pre:"--" %> not)
      |> CCString.concat "\n"

    let tier = CCFun.(Terrat_tier.of_yojson %> CCResult.to_opt)

    let select_tier =
      Pgsql_io.Typed_sql.(
        sql
        //
        (* id *)
        Ret.text
        //
        (* name *)
        Ret.text
        //
        (* tier *)
        Ret.(u json tier)
        /^ read [%blob "sql/select_tier.sql"]
        /% Var.bigint "installation_id")

    let select_users_this_month =
      Pgsql_io.Typed_sql.(
        sql
        //
        (* user *)
        Ret.text
        //
        (* created_at *)
        Ret.text
        /^ read [%blob "sql/select_users_this_month.sql"]
        /% Var.bigint "installation_id")

    let select_runs_this_month =
      Pgsql_io.Typed_sql.(
        sql
        //
        (* count *)
        Ret.bigint
        /^ read [%blob "sql/select_runs_this_month.sql"]
        /% Var.bigint "installation_id")
  end

  let check_users_per_month ~request_id user account limit db =
    let open Abbs_future_combinators.Infix_result_monad in
    Pgsql_io.Prepared_stmt.fetch
      db
      Sql.select_users_this_month
      ~f:(fun user created_at -> (user, created_at))
      (CCInt64.of_int @@ Api.Account.id account)
    >>= function
    | [] -> Abb.Future.return (Ok None)
    | users -> (
        let user = Api.User.to_string user in
        let all_users = Sln_set.String.dedup_list (user :: CCList.map fst users) in
        (* Allow users that have used the product with-in the existing tier to use it. *)
        let allowed_users = Sln_set.String.of_list @@ CCList.take limit @@ CCList.map fst users in
        Logs.info (fun m ->
            m
              "%s : TIER_CHECK : NUM_USERS_PER_MONTH : all_users=%d : limit=%d"
              request_id
              (CCList.length all_users)
              limit);
        match CCList.length all_users with
        | n when n > limit && not (Sln_set.String.mem user allowed_users) ->
            CCList.iter
              (fun (user, first_run) ->
                Logs.info (fun m ->
                    m "%s : TIER_CHECK : user=%s : first_run=%s" request_id user first_run))
              users;
            Abb.Future.return (Ok (Some { Terrat_tier.Check.users = all_users; limit }))
        | _ -> Abb.Future.return (Ok None))

  let runs_usage' ~request_id account limit db =
    if limit = CCInt.max_int then Abb.Future.return (Ok None)
    else
      let open Abbs_future_combinators.Infix_result_monad in
      Pgsql_io.Prepared_stmt.fetch
        db
        Sql.select_runs_this_month
        ~f:CCFun.id
        (CCInt64.of_int @@ Api.Account.id account)
      >>= function
      | [] -> assert false
      | used :: _ ->
          let used = CCInt64.to_int used in
          Logs.info (fun m ->
              m "%s : TIER_CHECK : RUNS_PER_MONTH : used=%d : limit=%d" request_id used limit);
          Abb.Future.return (Ok (Some { Terrat_tier.Check.used; limit }))

  let check_runs_per_month ~request_id account limit db =
    let open Abbs_future_combinators.Infix_result_monad in
    runs_usage' ~request_id account limit db
    >>= function
    | Some { Terrat_tier.Check.used; limit } when used >= limit ->
        Abb.Future.return (Ok (Some { Terrat_tier.Check.used; limit }))
    | Some _ | None -> Abb.Future.return (Ok None)

  let runs_usage ~request_id account db =
    let run =
      let open Abbs_future_combinators.Infix_result_monad in
      Pgsql_io.Prepared_stmt.fetch
        db
        Sql.select_tier
        ~f:(fun id name tier -> (id, name, tier))
        (CCInt64.of_int @@ Api.Account.id account)
      >>= function
      | [] -> assert false
      | (_, _, tier) :: _ ->
          let { Terrat_tier.runs_per_month; _ } = tier in
          runs_usage' ~request_id account runs_per_month db
    in
    let open Abb.Future.Infix_monad in
    run
    >>= function
    | Ok _ as res -> Abb.Future.return res
    | Error (#Pgsql_io.err as err) ->
        Logs.err (fun m -> m "%s : %a" request_id Pgsql_io.pp_err err);
        Abb.Future.return (Error `Error)

  let check ~request_id user account db =
    let run =
      let open Abbs_future_combinators.Infix_result_monad in
      Pgsql_io.Prepared_stmt.fetch
        db
        Sql.select_tier
        ~f:(fun id name tier -> (id, name, tier))
        (CCInt64.of_int @@ Api.Account.id account)
      >>= function
      | [] -> assert false
      | (tier_id, tier_name, tier) :: _ -> (
          let { Terrat_tier.num_users_per_month; runs_per_month; _ } = tier in
          Logs.info (fun m -> m "%s : TIER : id=%s : name=%s" request_id tier_id tier_name);
          check_users_per_month ~request_id user account num_users_per_month db
          >>= fun users_check ->
          check_runs_per_month ~request_id account runs_per_month db
          >>= fun runs_check ->
          match (users_check, runs_check) with
          | None, None -> Abb.Future.return (Ok None)
          | users_per_month, runs_per_month ->
              Abb.Future.return
                (Ok (Some { Terrat_tier.Check.tier_name; users_per_month; runs_per_month })))
    in
    let open Abb.Future.Infix_monad in
    run
    >>= function
    | Ok _ as res -> Abb.Future.return res
    | Error (#Pgsql_io.err as err) ->
        Logs.err (fun m -> m "%s : %a" request_id Pgsql_io.pp_err err);
        Abb.Future.return (Error `Error)
end

module Gate = struct
  let add_approval ~request_id:_ ~token:_ ~approver:_ _pull_request _db =
    Abb.Future.return (Error (`Premium_feature_err `Gatekeeping))

  let eval ~request_id:_ _ _ _ _ = Abb.Future.return (Ok [])
end

module Comment = struct
  module Result = struct
    module Publisher3 = struct
      module Gcm = Terrat_vcs_comment.Make (Terrat_vcs_gitlab_comment.S)

      let post_comment
          request_id
          account_status
          config
          client
          db
          is_layered_run
          remaining_layers
          repo_config
          result
          pull_request
          synthesized_config
          work_manifest =
        let module Tcm = Terrat_vcs_gitlab_comment in
        let module R2 = Terrat_api_components.Work_manifest_tf_operation_result2 in
        let open Abb.Future.Infix_monad in
        (* The comment is best effort: if we cannot load the tier's runs usage,
           still publish it, just without the usage warning. *)
        Tier.runs_usage ~request_id work_manifest.Terrat_work_manifest3.account db
        >>= fun tier_runs ->
        let tier_runs = CCResult.get_or ~default:None tier_runs in
        let pull_request =
          Api.Pull_request.set_diff () pull_request |> Api.Pull_request.set_checks ()
        in
        let work_manifest = { work_manifest with Terrat_work_manifest3.target = () } in
        let by_scope = By_scope.group result.R2.steps in
        let hooks =
          CCList.filter_map
            (function
              | (Scope.Run _, _) as run -> Some run
              | _ -> None)
            by_scope
        in
        let t =
          {
            Tcm.S.request_id;
            account_status;
            tier_runs;
            config;
            client;
            db;
            hooks;
            is_layered_run;
            pull_request;
            remaining_layers;
            repo_config;
            result;
            synthesized_config;
            work_manifest;
          }
        in
        let els =
          CCList.filter_map
            (function
              | Scope.Dirspace dirspace, steps -> Tcm.S.create_el t dirspace steps
              | Scope.Run _, _ -> None)
            by_scope
        in
        Gcm.run t els
    end
  end

  let repo_config_failure ~request_id ~client ~pull_request ~title err =
    (* A bit of a cheap trick here to make it look like a code section in this
         context *)
    let module Comment_api = Terrat_vcs_gitlab_comment_publishers.Comment_api in
    let err = "```\n" ^ err ^ "\n```" in
    let kv = Snabela.Kv.(Map.of_list [ ("title", string title); ("msg", string err) ]) in
    Comment_api.apply_template_and_publish
      ~request_id
      client
      pull_request
      "REPO_CONFIG_GENERIC_FAILURE"
      Tmpl.repo_config_generic_failure
      kv

  let repo_config_err ~request_id ~client ~pull_request ~title:_ err =
    let module Gcm_api = Terrat_vcs_gitlab_comment_publishers.Comment_api in
    match err with
    | `Access_control_ci_config_update_match_parse_err m ->
        let kv = Snabela.Kv.(Map.of_list [ ("match", string m) ]) in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "ACCESS_CONTROL_CI_CONFIG_UPDATE_MATCH_PARSE_ERR"
          Tmpl.repo_config_err_access_control_ci_config_update_match_parse_err
          kv
    | `Access_control_file_match_parse_err (path, m) ->
        let kv = Snabela.Kv.(Map.of_list [ ("path", string path); ("match", string m) ]) in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "ACCESS_CONTROL_FILE_MATCH_PARSE_ERR"
          Tmpl.repo_config_err_access_control_file_match_parse_err
          kv
    | `Access_control_policy_apply_autoapprove_match_parse_err m ->
        let kv = Snabela.Kv.(Map.of_list [ ("match", string m) ]) in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "ACCESS_CONTROL_POLICY_APPLY_AUTOAPPROVE_MATCH_PARSE_ERR"
          Tmpl.repo_config_err_access_control_policy_apply_autoapprove_match_parse_err
          kv
    | `Access_control_policy_apply_force_match_parse_err m ->
        let kv = Snabela.Kv.(Map.of_list [ ("match", string m) ]) in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "ACCESS_CONTROL_POLICY_APPLY_FORCE_MATCH_PARSE_ERR"
          Tmpl.repo_config_err_access_control_policy_apply_force_match_parse_err
          kv
    | `Access_control_policy_apply_match_parse_err m ->
        let kv = Snabela.Kv.(Map.of_list [ ("match", string m) ]) in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "ACCESS_CONTROL_POLICY_APPLY_MATCH_PARSE_ERR"
          Tmpl.repo_config_err_access_control_policy_apply_match_parse_err
          kv
    | `Access_control_policy_apply_with_superapproval_match_parse_err m ->
        let kv = Snabela.Kv.(Map.of_list [ ("match", string m) ]) in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "ACCESS_CONTROL_POLICY_APPLY_WITH_SUPERAPPROVAL_MATCH_PARSE_ERR"
          Tmpl.repo_config_err_access_control_policy_apply_with_superapproval_match_parse_err
          kv
    | `Access_control_policy_plan_match_parse_err m ->
        let kv = Snabela.Kv.(Map.of_list [ ("match", string m) ]) in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "ACCESS_CONTROL_POLICY_PLAN_MATCH_PARSE_ERR"
          Tmpl.repo_config_err_access_control_policy_plan_match_parse_err
          kv
    | `Access_control_policy_superapproval_match_parse_err m ->
        let kv = Snabela.Kv.(Map.of_list [ ("match", string m) ]) in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "ACCESS_CONTROL_POLICY_SUPERAPPROVAL_MATCH_PARSE_ERR"
          Tmpl.repo_config_err_access_control_policy_superapproval_match_parse_err
          kv
    | `Access_control_policy_tag_query_err (q, err) ->
        let kv = Snabela.Kv.(Map.of_list [ ("query", string q); ("error", string err) ]) in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "ACCESS_CONTROL_POLICY_TAG_QUERY_ERR"
          Tmpl.repo_config_err_access_control_policy_tag_query_err
          kv
    | `Access_control_terrateam_config_update_match_parse_err m ->
        let kv = Snabela.Kv.(Map.of_list [ ("match", string m) ]) in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "ACCESS_CONTROL_TERRATEAM_CONFIG_UPDATE_MATCH_PARSE_ERR"
          Tmpl.repo_config_err_access_control_terrateam_config_update_match_parse_err
          kv
    | `Access_control_unlock_match_parse_err m ->
        let kv = Snabela.Kv.(Map.of_list [ ("match", string m) ]) in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "ACCESS_CONTROL_UNLOCK_MATCH_PARSE_ERR"
          Tmpl.repo_config_err_access_control_unlock_match_parse_err
          kv
    | `Apply_requirements_approved_all_of_match_parse_err m ->
        let kv = Snabela.Kv.(Map.of_list [ ("match", string m) ]) in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "APPLY_REQUIREMENTS_APPROVED_ALL_OF_MATCH_PARSE_ERR"
          Tmpl.repo_config_err_apply_requirements_approved_all_of_match_parse_err
          kv
    | `Apply_requirements_approved_any_of_match_parse_err m ->
        let kv = Snabela.Kv.(Map.of_list [ ("match", string m) ]) in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "APPLY_REQUIREMENTS_APPROVED_ANY_OF_MATCH_PARSE_ERR"
          Tmpl.repo_config_err_apply_requirements_approved_any_of_match_parse_err
          kv
    | `Apply_requirements_check_tag_query_err (q, err) ->
        let kv = Snabela.Kv.(Map.of_list [ ("query", string q); ("error", string err) ]) in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "APPLY_REQUIREMENTS_CHECK_TAG_QUERY_ERR"
          Tmpl.repo_config_err_apply_requirements_check_tag_query_err
          kv
    | `Depends_on_err (q, err) ->
        let kv = Snabela.Kv.(Map.of_list [ ("query", string q); ("error", string err) ]) in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "DRIFT_TAG_QUERY_ERR"
          Tmpl.repo_config_err_depends_on_err
          kv
    | `Drift_tag_query_err (q, err) ->
        let kv = Snabela.Kv.(Map.of_list [ ("query", string q); ("error", string err) ]) in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "DRIFT_TAG_QUERY_ERR"
          Tmpl.repo_config_err_drift_tag_query_err
          kv
    | `Glob_parse_err (s, err) ->
        let kv = Snabela.Kv.(Map.of_list [ ("glob", string s); ("error", string err) ]) in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "GLOB_PARSE_ERR"
          Tmpl.repo_config_err_glob_parse_err
          kv
    | `Pattern_parse_err s ->
        let kv = Snabela.Kv.(Map.of_list [ ("pattern", string s) ]) in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "PATTERN_PARSE_ERR"
          Tmpl.repo_config_err_pattern_parse_err
          kv
    | `Window_parse_timezone_err tz ->
        let kv = Snabela.Kv.(Map.of_list [ ("tz", string tz) ]) in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "WINDOW_PARSE_TIMEZONE_ERR"
          Tmpl.repo_config_err_window_parse_timezone_err
          kv
    | `Workflows_tag_query_parse_err (q, err) ->
        let kv = Snabela.Kv.(Map.of_list [ ("query", string q); ("error", string err) ]) in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "WORKFLOWS_TAG_QUERY_PARSE_ERR"
          Tmpl.repo_config_err_workflows_tag_query_parse_err
          kv
    | `Repo_config_schema_err errs ->
        let errors =
          CCList.map
            (fun { Jsonschema_check.Validation_err.msg; path } ->
              Snabela.Kv.(Map.of_list [ ("msg", string msg); ("path", string path) ]))
            errs
        in
        let kv =
          Snabela.Kv.(Map.of_list [ ("fname", string "repo_config"); ("errors", list errors) ])
        in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "REPO_CONFIG_SCHEMA_ERR"
          Tmpl.repo_config_schema_err
          kv
    | `Notification_policy_tag_query_err (query, err) ->
        let kv = `Assoc [ ("query", `String query); ("error", `String err) ] in
        Abbs_future_combinators.Result.ignore
        @@ Gcm_api.apply_template_and_publish_jinja
             ~request_id
             client
             pull_request
             "NOTIFICATION_POLICY_TAG_QUERY_ERR"
             Tmpl.notification_policy_tag_query_err
             kv
    | `Stack_config_tag_query_err _err -> raise (Failure "nyi")

  let publish_comment ~request_id client user pull_request =
    let module Gcm_api = Terrat_vcs_gitlab_comment_publishers.Comment_api in
    let module Msg = Terrat_vcs_provider2.Msg in
    function
    | Msg.Access_control_denied (default_branch, `All_dirspaces denies) ->
        let kv =
          Snabela.Kv.(
            Map.of_list
              [
                ("user", string user);
                ("default_branch", string default_branch);
                ( "denies",
                  list
                    (CCList.map
                       (fun {
                              Terrat_access_control2.R.Deny.change_match =
                                {
                                  Terrat_change_match3.Dirspace_config.dirspace =
                                    { Terrat_dirspace.dir; workspace };
                                  _;
                                };
                              policy;
                            }
                          ->
                         Map.of_list
                           (CCList.flatten
                              [
                                [ ("dir", string dir); ("workspace", string workspace) ];
                                CCOption.map_or
                                  ~default:[]
                                  (fun policy ->
                                    [
                                      ( "match_list",
                                        list
                                          (CCList.map
                                             (fun s ->
                                               Map.of_list
                                                 [
                                                   ( "item",
                                                     string
                                                       (Terrat_base_repo_config_v1.Access_control
                                                        .Match
                                                        .to_string
                                                          s) );
                                                 ])
                                             policy) );
                                    ])
                                  policy;
                              ]))
                       denies) );
              ])
        in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "ACCESS_CONTROL_ALL_DIRSPACES_DENIED"
          Tmpl.access_control_all_dirspaces_denied
          kv
    | Msg.Access_control_denied (default_branch, `Ci_config_update match_list) ->
        let kv =
          Snabela.Kv.(
            Map.of_list
              [
                ("user", string user);
                ("default_branch", string default_branch);
                ( "match_list",
                  list
                    (CCList.map
                       (fun s ->
                         Map.of_list
                           [
                             ( "item",
                               string (Terrat_base_repo_config_v1.Access_control.Match.to_string s)
                             );
                           ])
                       match_list) );
              ])
        in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "ACCESS_CONTROL_CI_CONFIG_UPDATE_DENIED"
          Tmpl.access_control_ci_config_update_denied
          kv
    | Msg.Access_control_denied (default_branch, `Dirspaces denies) ->
        let kv =
          Snabela.Kv.(
            Map.of_list
              [
                ("user", string user);
                ("default_branch", string default_branch);
                ( "denies",
                  list
                    (CCList.map
                       (fun {
                              Terrat_access_control2.R.Deny.change_match =
                                {
                                  Terrat_change_match3.Dirspace_config.dirspace =
                                    { Terrat_dirspace.dir; workspace };
                                  _;
                                };
                              policy;
                            }
                          ->
                         Map.of_list
                           (CCList.flatten
                              [
                                [ ("dir", string dir); ("workspace", string workspace) ];
                                CCOption.map_or
                                  ~default:[]
                                  (fun policy ->
                                    [
                                      ( "match_list",
                                        list
                                          (CCList.map
                                             (fun s ->
                                               Map.of_list
                                                 [
                                                   ( "item",
                                                     string
                                                       (Terrat_base_repo_config_v1.Access_control
                                                        .Match
                                                        .to_string
                                                          s) );
                                                 ])
                                             policy) );
                                    ])
                                  policy;
                              ]))
                       denies) );
              ])
        in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "ACCESS_CONTROL_DIRSPACES_DENIED"
          Tmpl.access_control_dirspaces_denied
          kv
    | Msg.Access_control_denied (default_branch, `Files (fname, match_list)) ->
        let kv =
          Snabela.Kv.(
            Map.of_list
              [
                ("user", string user);
                ("default_branch", string default_branch);
                ("filename", string fname);
                ( "match_list",
                  list
                    (CCList.map
                       (fun s ->
                         Map.of_list
                           [
                             ( "item",
                               string (Terrat_base_repo_config_v1.Access_control.Match.to_string s)
                             );
                           ])
                       match_list) );
              ])
        in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "ACCESS_CONTROL_FILES"
          Tmpl.access_control_files_denied
          kv
    | Msg.Access_control_denied (default_branch, `Terrateam_config_update match_list) ->
        let kv =
          Snabela.Kv.(
            Map.of_list
              [
                ("user", string user);
                ("default_branch", string default_branch);
                ( "match_list",
                  list
                    (CCList.map
                       (fun s ->
                         Map.of_list
                           [
                             ( "item",
                               string (Terrat_base_repo_config_v1.Access_control.Match.to_string s)
                             );
                           ])
                       match_list) );
              ])
        in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "ACCESS_CONTROL_TERRATEAM_CONFIG_UPDATE_DENIED"
          Tmpl.access_control_terrateam_config_update_denied
          kv
    | Msg.Access_control_denied (default_branch, `Lookup_err) ->
        let kv =
          Snabela.Kv.(
            Map.of_list [ ("user", string user); ("default_branch", string default_branch) ])
        in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "ACCESS_CONTROL_LOOKUP_ERR"
          Tmpl.access_control_lookup_err
          kv
    | Msg.Access_control_denied (default_branch, `Unlock match_list) ->
        let kv =
          Snabela.Kv.(
            Map.of_list
              [
                ("user", string user);
                ("default_branch", string default_branch);
                ( "match_list",
                  list
                    (CCList.map
                       (fun s ->
                         Map.of_list
                           [
                             ( "item",
                               string (Terrat_base_repo_config_v1.Access_control.Match.to_string s)
                             );
                           ])
                       match_list) );
              ])
        in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "ACCESS_CONTROL_UNLOCK_DENIED"
          Tmpl.access_control_unlock_denied
          kv
    | Msg.Account_expired ->
        let kv = Snabela.Kv.(Map.of_list []) in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "ACCOUNT_EXPIRED"
          Tmpl.account_expired_err
          kv
    | Msg.Apply_no_matching_dirspaces ->
        let kv = Snabela.Kv.(Map.of_list []) in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "APPLY_NO_MATCHING_DIRSPACES"
          Tmpl.apply_no_matching_dirspaces
          kv
    | Msg.Apply_requirements_config_err (`Tag_query_error (query, err)) ->
        let kv = Snabela.Kv.(Map.of_list [ ("query", string query); ("error", string err) ]) in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "APPLY_REQUIREMENTS_CONFIG_ERR_TAG_QUERY"
          Tmpl.apply_requirements_config_err_tag_query
          kv
    | Msg.Apply_requirements_config_err (`Invalid_query query) ->
        let kv = Snabela.Kv.(Map.of_list [ ("query", string query) ]) in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "APPLY_REQUIREMENTS_CONFIG_ERR_INVALID_QUERY"
          Tmpl.apply_requirements_config_err_invalid_query
          kv
    | Msg.Apply_requirements_validation_err ->
        let kv = Snabela.Kv.(Map.of_list []) in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "APPLY_REQUIREMENTS_VALIDATION_ERR"
          Tmpl.apply_requirements_validation_err
          kv
    | Msg.Autoapply_running ->
        let kv = Snabela.Kv.(Map.of_list []) in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "AUTO_APPLY_RUNNING"
          Tmpl.auto_apply_running
          kv
    | Msg.Automerge_failure (_pr, msg) ->
        let kv = Snabela.Kv.(Map.of_list [ ("msg", string msg) ]) in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "AUTOMERGE_FAILURE"
          Tmpl.automerge_failure
          kv
    | Msg.Bad_custom_branch_tag_pattern (tag, pat) ->
        let kv = Snabela.Kv.(Map.of_list [ ("tag", string tag); ("pattern", string pat) ]) in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "BAD_CUSTOM_BRANCH_TAG_PATTERN"
          Tmpl.bad_custom_branch_tag_pattern
          kv
    | Msg.Bad_glob s ->
        let kv = Snabela.Kv.(Map.of_list [ ("glob", string s) ]) in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "BAD_GLOB"
          Tmpl.bad_glob
          kv
    | Msg.Build_config_err err -> repo_config_err ~request_id ~client ~pull_request ~title:"" err
    | Msg.Build_config_failure err ->
        repo_config_failure ~request_id ~client ~pull_request ~title:"built" err
    | Msg.Build_tree_failure msg ->
        let kv = Snabela.Kv.(Map.of_list [ ("msg", string msg) ]) in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "BUILD_TREE_FAILURE"
          Tmpl.build_tree_failure
          kv
    | Msg.Conflicting_work_manifests wms ->
        let module Wm = Terrat_work_manifest3 in
        let wms =
          let module Key = struct
            type t = string * bool [@@deriving ord]
          end in
          CCList.map
            (fun ({ Wm.target; _ } as wm) ->
              let id, is_pr =
                match target with
                | Terrat_vcs_provider2.Target.Pr pr ->
                    (CCInt.to_string (Api.Pull_request.id pr), true)
                | Terrat_vcs_provider2.Target.Drift _ -> ("drift", false)
              in
              ((id, is_pr), wm))
            wms
          |> CCList.sort_uniq ~cmp:(fun (a, _) (b, _) -> Key.compare a b)
          |> CCList.map snd
        in
        let kv =
          Snabela.Kv.(
            Map.of_list
              [
                ( "work_manifests",
                  list
                    (CCList.map
                       (fun { Wm.created_at; steps; state; target; _ } ->
                         let id, is_pr =
                           match target with
                           | Terrat_vcs_provider2.Target.Pr pr ->
                               (CCInt.to_string (Api.Pull_request.id pr), true)
                           | Terrat_vcs_provider2.Target.Drift _ -> ("drift", false)
                         in
                         Map.of_list
                           [
                             ("id", string id);
                             ("is_pr", bool is_pr);
                             ( "run_type",
                               string
                                 (CCString.capitalize_ascii
                                    (Wm.Step.to_string
                                       (CCOption.get_exn_or
                                          "Conflicting_work_manifests"
                                          (CCList.last_opt steps)))) );
                             ("state", string (CCString.capitalize_ascii (Wm.State.to_string state)));
                             ( "created_at",
                               string
                                 (let Unix.{ tm_year; tm_mon; tm_mday; tm_hour; tm_min; _ } =
                                    Unix.gmtime (ISO8601.Permissive.datetime created_at)
                                  in
                                  Printf.sprintf
                                    "%d-%d-%d %d:%d"
                                    (1900 + tm_year)
                                    (tm_mon + 1)
                                    tm_mday
                                    tm_hour
                                    tm_min) );
                           ])
                       wms) );
              ])
        in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "CONFLICTING_WORK_MANIFESTS"
          Tmpl.conflicting_work_manifests
          kv
    | Msg.Synthesize_config_err (`Stack_cycle_err cycle) ->
        let kv = `Assoc [ ("cycle", `List (CCList.map (fun stack -> `String stack) cycle)) ] in
        Abbs_future_combinators.Result.ignore
        @@ Gcm_api.apply_template_and_publish_jinja
             ~request_id
             client
             pull_request
             "STACK_CYCLE"
             Tmpl.synthesize_config_err_stack_cycle
             kv
    | Msg.Synthesize_config_err (`Depends_on_cycle_err cycle) ->
        let kv =
          `Assoc
            [
              ( "cycle",
                `List
                  (CCList.map
                     (fun { Terrat_dirspace.dir; workspace } ->
                       `Assoc [ ("dir", `String dir); ("workspace", `String workspace) ])
                     cycle) );
            ]
        in
        Abbs_future_combinators.Result.ignore
        @@ Gcm_api.apply_template_and_publish_jinja
             ~request_id
             client
             pull_request
             "DEPENDS_ON_CYCLE"
             Tmpl.synthesize_config_err_cycle
             kv
    | Msg.Synthesize_config_err
        (`Workspace_in_multiple_stacks_err { Terrat_dirspace.dir; workspace }) ->
        let kv = `Assoc [ ("dir", `String dir); ("workspace", `String workspace) ] in
        Abbs_future_combinators.Result.ignore
        @@ Gcm_api.apply_template_and_publish_jinja
             ~request_id
             client
             pull_request
             "WORKSPACE_IN_MULTIPLE_STACKS"
             Tmpl.synthesize_config_err_workspace_in_multiple_stacks
             kv
    | Msg.Synthesize_config_err
        (`Workspace_matches_no_stacks_err { Terrat_dirspace.dir; workspace }) ->
        let kv = `Assoc [ ("dir", `String dir); ("workspace", `String workspace) ] in
        Abbs_future_combinators.Result.ignore
        @@ Gcm_api.apply_template_and_publish_jinja
             ~request_id
             client
             pull_request
             "WORKSPACE_MATCHES_NO_STACKS"
             Tmpl.synthesize_config_err_workspace_matches_no_stacks
             kv
    | Msg.Synthesize_config_err (`Stack_not_found_err stack) ->
        let kv = `Assoc [ ("stack", `String stack) ] in
        Abbs_future_combinators.Result.ignore
        @@ Gcm_api.apply_template_and_publish_jinja
             ~request_id
             client
             pull_request
             "STACK_NOT_FOUND"
             Tmpl.synthesize_config_err_stack_not_found
             kv
    | Msg.Str_template_err (`Missing_var_err name) ->
        let kv = `Assoc [ ("var_name", `String name) ] in
        Abbs_future_combinators.Result.ignore
        @@ Gcm_api.apply_template_and_publish_jinja
             ~request_id
             client
             pull_request
             "STR_TEMPLATE"
             Tmpl.str_template_err_missing_var
             kv
    | Msg.Dest_branch_no_match pull_request ->
        let kv =
          Snabela.Kv.(
            Map.of_list
              [
                ( "source_branch",
                  string
                    (CCString.lowercase_ascii
                    @@ Api.Ref.to_string
                    @@ Api.Pull_request.branch_name pull_request) );
                ( "dest_branch",
                  string
                    (CCString.lowercase_ascii
                    @@ Api.Ref.to_string
                    @@ Api.Pull_request.base_branch_name pull_request) );
              ])
        in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "DEST_BRANCH_NO_MATCH"
          Tmpl.base_branch_not_default_branch
          kv
    | Msg.Dirspaces_owned_by_other_pull_request prs ->
        let unique_pull_request_ids =
          prs
          |> CCList.map (fun (_, pr) -> Api.Pull_request.id pr)
          |> CCList.sort_uniq ~cmp:CCInt.compare
        in
        let kv =
          Snabela.Kv.(
            Map.of_list
              [
                ( "dirspaces",
                  list
                    (CCList.map
                       (fun ({ Terrat_change.Dirspace.dir; workspace }, pr) ->
                         let id = Api.Pull_request.id pr in
                         Map.of_list
                           [
                             ("dir", string dir);
                             ("workspace", string workspace);
                             ("pull_request_id", int id);
                           ])
                       prs) );
                ( "unique_pull_request_ids",
                  list
                    (CCList.map (fun id -> Map.of_list [ ("id", int id) ]) unique_pull_request_ids)
                );
              ])
        in
        CCList.iter
          (fun (Terrat_change.Dirspace.{ dir; workspace }, pr) ->
            let id = Api.Pull_request.id pr in
            Logs.info (fun m ->
                m
                  "%s : DIRSPACES_OWNED_BY_OTHER_PR : dir=%s : workspace=%s : pull_number=%d"
                  request_id
                  dir
                  workspace
                  id))
          prs;
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "DIRSPACES_OWNED_BY_OTHER_PRS"
          Tmpl.dirspaces_owned_by_other_pull_requests
          kv
    | Msg.Gate_check_failure denied ->
        let module G = Terrat_vcs_provider2.Gate_eval in
        let kv =
          `Assoc
            [
              ( "denied",
                `List
                  (CCList.map (fun { G.dirspace; token; name; result } ->
                       let { Terrat_gate.all_of; any_of; any_of_count } = result in
                       let { Terrat_dirspace.dir; workspace } =
                         CCOption.get_or
                           ~default:{ Terrat_dirspace.dir = ""; workspace = "" }
                           dirspace
                       in
                       `Assoc
                         [
                           ( "token",
                             CCOption.map_or ~default:`Null (fun token -> `String token) token );
                           ("name", CCOption.map_or ~default:`Null (fun name -> `String name) name);
                           ("dir", `String dir);
                           ("workspace", `String workspace);
                           ( "all_of",
                             `List
                               (CCList.map
                                  (fun q -> `String (Terrat_gate.Match.to_string q))
                                  all_of) );
                           ( "any_of",
                             `List
                               (CCList.map
                                  (fun q -> `String (Terrat_gate.Match.to_string q))
                                  (if any_of_count = 0 then [] else any_of)) );
                           ("any_of_count", `Int any_of_count);
                         ])
                  @@ CCList.sort
                       (fun { G.token = t1; name = n1; _ } { G.token = t2; name = n2; _ } ->
                         let module Cmp = struct
                           type t = string option * string option [@@deriving ord]
                         end in
                         Cmp.compare (t1, n1) (t2, n2))
                       denied) );
            ]
        in
        Abbs_future_combinators.Result.ignore
        @@ Gcm_api.apply_template_and_publish_jinja
             ~request_id
             client
             pull_request
             "GATE_CHECK_FAILURE"
             Tmpl.gate_check_failure
             kv
    | Msg.Help ->
        let kv = Snabela.Kv.(Map.of_list []) in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "HELP"
          Tmpl.terrateam_comment_help
          kv
    | Msg.Index_complete (success, failures) ->
        let kv =
          Snabela.Kv.(
            Map.of_list
              [
                ("success", bool success);
                ( "failures",
                  list
                    (CCList.map
                       (fun (path, lnum, msg) ->
                         Map.of_list
                           (CCList.flatten
                              [
                                [ ("path", string path); ("failure", string msg) ];
                                CCOption.map_or
                                  ~default:[]
                                  (fun lnum -> [ ("line", int lnum) ])
                                  lnum;
                              ]))
                       failures) );
              ])
        in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "INDEX_COMPLETE"
          Tmpl.index_complete
          kv
    | Msg.Invalid_unlock_id unlock_id ->
        let kv = Snabela.Kv.(Map.of_list [ ("unlock_id", string unlock_id) ]) in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "INVALID_UNLOCK_ID"
          Tmpl.invalid_lock_id
          kv
    | Msg.Maybe_stale_work_manifests wms ->
        let module Wm = Terrat_work_manifest3 in
        let kv =
          Snabela.Kv.(
            Map.of_list
              [
                ( "work_manifests",
                  list
                    (CCList.map
                       (fun Wm.{ created_at; steps; state; target; _ } ->
                         let id, is_pr =
                           match target with
                           | Terrat_vcs_provider2.Target.Pr pr ->
                               (CCInt.to_string (Api.Pull_request.id pr), true)
                           | Terrat_vcs_provider2.Target.Drift _ -> ("drift", false)
                         in
                         Map.of_list
                           [
                             ("id", string id);
                             ("is_pr", bool is_pr);
                             ( "run_type",
                               string
                                 (CCString.capitalize_ascii
                                    (Wm.Step.to_string
                                       (CCOption.get_exn_or
                                          "Maybe_stale_work_manifests"
                                          (CCList.last_opt steps)))) );
                             ("state", string (CCString.capitalize_ascii (Wm.State.to_string state)));
                             ( "created_at",
                               string
                                 (let Unix.{ tm_year; tm_mon; tm_mday; tm_hour; tm_min; _ } =
                                    Unix.gmtime (ISO8601.Permissive.datetime created_at)
                                  in
                                  Printf.sprintf
                                    "%d-%d-%d %d:%d"
                                    (1900 + tm_year)
                                    (tm_mon + 1)
                                    tm_mday
                                    tm_hour
                                    tm_min) );
                           ])
                       wms) );
              ])
        in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "MAYBE_STALE_WORK_MANIFESTS"
          Tmpl.maybe_stale_work_manifests
          kv
    | Msg.Mismatched_refs ->
        let kv = Snabela.Kv.(Map.of_list []) in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "MISMATCHED_REFS"
          Tmpl.mismatched_refs
          kv
    | Msg.Missing_plans dirspaces ->
        let kv =
          Snabela.Kv.(
            Map.of_list
              [
                ( "dirspaces",
                  list
                    (CCList.map
                       (fun Terrat_change.Dirspace.{ dir; workspace } ->
                         Map.of_list [ ("dir", string dir); ("workspace", string workspace) ])
                       dirspaces) );
              ])
        in
        CCList.iter
          (fun Terrat_change.Dirspace.{ dir; workspace } ->
            Logs.info (fun m -> m "%s : MISSING_PLANS : %s : %s" request_id dir workspace))
          dirspaces;
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "MISSING_PLANS"
          Tmpl.missing_plans
          kv
    | Msg.Plan_all_changes_applied ->
        let kv = Snabela.Kv.(Map.of_list []) in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "PLAN_ALL_CHANGES_APPLIED"
          Tmpl.plan_all_changes_applied
          kv
    | Msg.Plan_no_matching_dirspaces ->
        let kv = Snabela.Kv.(Map.of_list []) in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "PLAN_NO_MATCHING_DIRSPACES"
          Tmpl.plan_no_matching_dirspaces
          kv
    | Msg.Premium_feature_err `Access_control ->
        let kv = Snabela.Kv.(Map.of_list []) in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "PREMIUM_FEATURE_ACCESS_CONTROL"
          Tmpl.premium_feature_err_access_control
          kv
    | Msg.Premium_feature_err `Multiple_drift_schedules ->
        let kv = Snabela.Kv.(Map.of_list []) in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "PREMIUM_FEATURE_MULTIPLE_DRIFT_SCHEDULES"
          Tmpl.premium_feature_err_multiple_drift_schedules
          kv
    | Msg.Premium_feature_err `Gatekeeping ->
        let kv = Snabela.Kv.(Map.of_list []) in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "PREMIUM_FEATURE_GATEKEEPING"
          Tmpl.premium_feature_err_gatekeeping
          kv
    | Msg.Premium_feature_err `Require_completed_reviews ->
        let kv = Snabela.Kv.(Map.of_list []) in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "PREMIUM_FEATURE_REQUIRE_COMPLETED_REVIEWS"
          Tmpl.premium_feature_err_require_completed_reviews
          kv
    | Msg.Premium_feature_err `Notifications_summary ->
        let kv = Snabela.Kv.(Map.of_list []) in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "PREMIUM_FEATURE_NOTIFICATIONS_SUMMARY"
          Tmpl.premium_feature_err_notifications_summary
          kv
    | Msg.Pull_request_not_appliable (_, apply_requirements) ->
        let module Dc = Terrat_change_match3.Dirspace_config in
        let module Ds = Terrat_dirspace in
        let module Ar = Apply_requirements.Result in
        let kv =
          `Assoc
            [
              ( "checks",
                `List
                  (CCList.map (fun ar ->
                       `Assoc
                         [
                           ("dir", `String ar.Ar.match_.Dc.dirspace.Ds.dir);
                           ("workspace", `String ar.Ar.match_.Dc.dirspace.Ds.workspace);
                           ("matched_apply_requirement", `Bool (CCOption.is_some ar.Ar.passed));
                           ("passed", `Bool (CCOption.get_or ~default:false ar.Ar.passed));
                           ( "apply_after_merge_enabled",
                             `Bool (CCOption.is_some ar.Ar.apply_after_merge) );
                           ( "apply_after_merge_check",
                             `Bool (CCOption.get_or ~default:false ar.Ar.apply_after_merge) );
                           ("approved_enabled", `Bool (CCOption.is_some ar.Ar.approved));
                           ("approved_check", `Bool (CCOption.get_or ~default:false ar.Ar.approved));
                           ( "missing_reviews",
                             `List
                               (CCList.map
                                  (fun m ->
                                    `String
                                      (Terrat_base_repo_config_v1.Access_control.Match.to_string m))
                                  ar.Ar.missing_reviews) );
                           ("missing_any_of_count", `Int ar.Ar.missing_any_of_count);
                           ("any_of_count", `Int ar.Ar.any_of_count);
                           ( "any_of",
                             `List
                               (CCList.map
                                  (fun m ->
                                    `String
                                      (Terrat_base_repo_config_v1.Access_control.Match.to_string m))
                                  ar.Ar.any_of) );
                           ( "merge_conflicts_enabled",
                             `Bool (CCOption.is_some ar.Ar.merge_conflicts) );
                           ( "merge_conflicts_check",
                             `Bool (CCOption.get_or ~default:false ar.Ar.merge_conflicts) );
                           ( "ready_for_review_enabled",
                             `Bool (CCOption.is_some ar.Ar.ready_for_review) );
                           ( "ready_for_review_check",
                             `Bool (CCOption.get_or ~default:false ar.Ar.ready_for_review) );
                           ("status_checks_enabled", `Bool (CCOption.is_some ar.Ar.status_checks));
                           ( "status_checks_check",
                             `Bool (CCOption.get_or ~default:false ar.Ar.status_checks) );
                           ( "status_checks_failed",
                             `List
                               (CCList.map
                                  (fun Terrat_commit_check.{ title; _ } ->
                                    `Assoc [ ("title", `String title) ])
                                  ar.Ar.status_checks_failed) );
                         ])
                  @@ CCList.sort
                       (fun { Ar.passed = passed1; _ } { Ar.passed = passed2; _ } ->
                         Bool.compare
                           (CCOption.get_or ~default:false passed1)
                           (CCOption.get_or ~default:false passed2))
                       apply_requirements) );
            ]
        in
        Abbs_future_combinators.Result.ignore
        @@ Gcm_api.apply_template_and_publish_jinja
             ~request_id
             client
             pull_request
             "PULL_REQUEST_NOT_APPLIABLE"
             Tmpl.pull_request_not_appliable
             kv
    | Msg.Pull_request_not_mergeable ->
        let kv = Snabela.Kv.(Map.of_list []) in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "PULL_REQUEST_NOT_MERGEABLE"
          Tmpl.pull_request_not_mergeable
          kv
    | Msg.Repo_config (provenance, repo_config) ->
        let repo_config_json =
          Terrat_repo_config.Version_1.to_yojson
            (Terrat_base_repo_config_v1.to_version_1 repo_config)
        in
        let repo_config_yaml = Jsonu.to_yaml_string repo_config_json in
        let kv =
          Snabela.Kv.(
            Map.of_list
              [
                ("repo_config", string repo_config_yaml);
                ( "provenance",
                  list (CCList.map (fun src -> Map.of_list [ ("src", string src) ]) provenance) );
              ])
        in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "REPO_CONFIG"
          Tmpl.repo_config
          kv
    | Msg.Repo_config_err err -> repo_config_err ~request_id ~client ~pull_request ~title:"" err
    | Msg.Repo_config_failure err ->
        repo_config_failure ~request_id ~client ~pull_request ~title:"Terrateam repository" err
    | Msg.Repo_config_merge_err ((base, src), (key, base_value, src_value)) ->
        let base_value = Jsonu.to_yaml_string base_value in
        let src_value = Jsonu.to_yaml_string src_value in
        let bases = CCList.filter (( <> ) "") @@ CCString.split ~by:"," base in
        let kv =
          Snabela.Kv.(
            Map.of_list
              [
                ("base", list (CCList.map (fun name -> Map.of_list [ ("name", string name) ]) bases));
                ("src", string src);
                ("key", string (CCOption.get_or ~default:"<unknown>" key));
                ("base_value", string base_value);
                ("src_value", string src_value);
              ])
        in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "REPO_CONFIG_MERGE_ERR"
          Tmpl.repo_config_merge_err
          kv
    | Msg.Repo_config_parse_failure (fname, err) ->
        let kv = Snabela.Kv.(Map.of_list [ ("fname", string fname); ("msg", string err) ]) in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "REPO_CONFIG_PARSE_FAILURE"
          Tmpl.repo_config_parse_failure
          kv
    | Msg.Repo_config_schema_err (fname, errs) ->
        let errors =
          CCList.map
            (fun { Jsonschema_check.Validation_err.msg; path } ->
              Snabela.Kv.(Map.of_list [ ("msg", string msg); ("path", string path) ]))
            errs
        in
        let kv = Snabela.Kv.(Map.of_list [ ("fname", string fname); ("errors", list errors) ]) in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "REPO_CONFIG_SCHEMA_ERR"
          Tmpl.repo_config_schema_err
          kv
    | Msg.Run_work_manifest_err (`Failed_to_start_with_msg_err "IDENTITY_VERIFICATION_ERR") ->
        let kv = Snabela.Kv.(Map.of_list []) in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "RUN_WORK_MANIFEST_ERR_FAILED_TO_START_IDENTITY_VERIFICATION"
          Tmpl.failed_to_start_identity_verification_workflow
          kv
    | Msg.Run_work_manifest_err (`Failed_to_start_with_msg_err "GITLAB_INPUTS_MISSING_DEFAULTS") ->
        let kv = Snabela.Kv.(Map.of_list []) in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "RUN_WORK_MANIFEST_ERR_FAILED_TO_START_MISSING_INPUTS"
          Tmpl.failed_to_start_missing_inputs
          kv
    | Msg.Run_work_manifest_err (`Failed_to_start | `Failed_to_start_with_msg_err _) ->
        let kv = Snabela.Kv.(Map.of_list []) in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "RUN_WORK_MANIFEST_ERR_FAILED_TO_START"
          Tmpl.failed_to_start_workflow
          kv
    | Msg.Run_work_manifest_err `Missing_workflow ->
        let kv = Snabela.Kv.(Map.of_list []) in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "RUN_WORK_MANIFEST_ERR_MISSING_WORKFLOW"
          Tmpl.failed_to_find_workflow
          kv
    | Msg.Tag_query_err (`Tag_query_error (s, err)) ->
        let kv = Snabela.Kv.(Map.of_list [ ("query", string s); ("err", string err) ]) in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "TAG_QUERY_ERR"
          Tmpl.tag_query_error
          kv
    | Msg.Tf_op_result2
        {
          account_status;
          config;
          db;
          is_layered_run;
          remaining_layers;
          repo_config;
          result;
          synthesized_config;
          work_manifest;
        } -> (
        let open Abb.Future.Infix_monad in
        Result.Publisher3.post_comment
          request_id
          account_status
          config
          client
          db
          is_layered_run
          remaining_layers
          repo_config
          result
          pull_request
          synthesized_config
          work_manifest
        >>= function
        | Ok comment_id -> Abb.Future.return (Ok comment_id)
        | Error _ -> Abb.Future.return (Error `Error))
    | Msg.Tier_check checks ->
        let module C = Terrat_tier.Check in
        let { C.tier_name; users_per_month; runs_per_month } = checks in
        let kv =
          Snabela.Kv.(
            Map.of_list
              [
                ("tier_name", string tier_name);
                ( "num_users_per_month",
                  list
                    (CCOption.map_or
                       ~default:[]
                       (fun { C.users; limit } ->
                         [
                           Map.of_list
                             [
                               ( "all_users",
                                 list
                                 @@ CCList.map
                                      (fun user -> Map.of_list [ ("name", string user) ])
                                      users );
                               ("limit", int limit);
                               ("num_users", int @@ CCList.length users);
                             ];
                         ])
                       users_per_month) );
                ( "runs_per_month",
                  list
                    (CCOption.map_or
                       ~default:[]
                       (fun { C.used; limit } ->
                         [ Map.of_list [ ("used", int used); ("limit", int limit) ] ])
                       runs_per_month) );
              ])
        in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "TIER_CHECK"
          Tmpl.tier_check
          kv
    | Msg.Unexpected_temporary_err ->
        let kv = Snabela.Kv.(Map.of_list []) in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "UNEXPECTED_TEMPORARY_ERR"
          Tmpl.unexpected_temporary_err
          kv
    | Msg.Unlock_success ->
        let kv = Snabela.Kv.(Map.of_list []) in
        Gcm_api.apply_template_and_publish
          ~request_id
          client
          pull_request
          "UNLOCK_SUCCESS"
          Tmpl.unlock_success
          kv
    | Msg.Work_manifest_run_failed { run_id } ->
        let kv = `Assoc [ ("run_id", `String run_id) ] in
        Abbs_future_combinators.Result.ignore
        @@ Gcm_api.apply_template_and_publish_jinja
             ~request_id
             client
             pull_request
             "WORK_MANIFEST_RUN_FAILED"
             Tmpl.work_manifest_run_failed
             kv
end

module Repo_config = struct
  let fetch_repo_config_file request_id client repo ref_ basename =
    let open Abbs_future_combinators.Infix_result_monad in
    Abbs_future_combinators.Infix_result_app.(
      (fun yml yaml ->
        match (yml, yaml) with
        | Some yml, _ ->
            Some
              (Api.Repo.to_string repo ^ ":" ^ Api.Ref.to_string ref_ ^ ":" ^ basename ^ ".yml", yml)
        | _, Some yaml ->
            Some
              ( Api.Repo.to_string repo ^ ":" ^ Api.Ref.to_string ref_ ^ ":" ^ basename ^ ".yaml",
                yaml )
        | _, _ -> None)
      <$> Api.fetch_file ~request_id client repo ref_ (basename ^ ".yml")
      <*> Api.fetch_file ~request_id client repo ref_ (basename ^ ".yaml"))
    >>= function
    | None -> Abb.Future.return (Ok None)
    | Some (_, content) when CCString.is_empty (CCString.trim content) ->
        Abb.Future.return (Ok None)
    | Some (fname, content) ->
        Abb.Future.return
        @@ CCResult.map_err
             (fun (`Yaml_decode_err err) -> `Yaml_decode_err (fname, err))
             (Jsonu.of_yaml_string content)
        >>= fun json -> Abb.Future.return (Ok (Some (fname, json)))

  let repo_config_system_defaults system_defaults =
    (* Access control should be disabled for OSS *)
    let module V1 = Terrat_base_repo_config_v1 in
    let system_defaults = CCOption.get_or ~default:V1.default system_defaults in
    V1.of_view
      {
        (V1.to_view system_defaults) with
        V1.View.access_control = V1.Access_control.make ~enabled:false ();
      }

  let fetch_with_provenance ?system_defaults ?built_config request_id client repo ref_ =
    let module V1 = Terrat_base_repo_config_v1 in
    let open Abbs_future_combinators.Infix_result_monad in
    let system_defaults = repo_config_system_defaults system_defaults in
    Api.fetch_remote_repo ~request_id client repo
    >>= fun remote_repo ->
    Api.fetch_branch_sha
      ~request_id
      client
      (Api.Remote_repo.to_repo remote_repo)
      (Api.Remote_repo.default_branch remote_repo)
    >>= fun default_branch_sha ->
    let default_branch_ref =
      CCOption.get_or ~default:(Api.Remote_repo.default_branch remote_repo) default_branch_sha
    in
    Abbs_future_combinators.Infix_result_app.(
      (fun default_repo_config repo_config -> (default_repo_config, repo_config))
      <$> fetch_repo_config_file request_id client repo default_branch_ref ".terrateam/config"
      <*> fetch_repo_config_file request_id client repo ref_ ".terrateam/config")
    >>= fun (default_repo_config, repo_config) ->
    let wrap_err fname =
      Abbs_future_combinators.Result.map_err ~f:(function
        | `Repo_config_schema_err err -> `Repo_config_schema_err (fname, err)
        | #Terrat_base_repo_config_v1.of_version_1_err as err -> err)
    in
    let validate_configs =
      Abbs_future_combinators.List_result.iter ~f:(function
        | Some (fname, json) ->
            wrap_err fname (Abb.Future.return (V1.of_version_1_json json))
            >>= fun _ -> Abb.Future.return (Ok ())
        | None -> Abb.Future.return (Ok ()))
    in
    let get_json = function
      | None -> `Assoc []
      | Some (_, json) -> json
    in
    let get_fname = CCOption.map (fun (fname, _) -> fname) in
    let collect_provenance =
      CCList.filter_map (function
        | Some (fname, _) -> Some fname
        | None -> None)
    in
    let merge ~base v =
      CCResult.map_err
        (fun (`Type_mismatch_err err) ->
          `Config_merge_err
            ( ( CCOption.get_or ~default:"" (get_fname base),
                CCOption.get_or ~default:"" (get_fname v) ),
              err ))
        (CCResult.map
           (fun r ->
             Some
               ( Printf.sprintf
                   "%s,%s"
                   (CCOption.get_or ~default:"" (get_fname base))
                   (CCOption.get_or ~default:"" (get_fname v)),
                 r ))
           (Jsonu.merge ~base:(get_json base) (get_json v)))
    in
    let system_defaults =
      Some
        ( "system_defaults",
          Terrat_repo_config.Version_1.to_yojson
            (Terrat_base_repo_config_v1.to_version_1 system_defaults) )
    in
    let built_config = CCOption.map (fun config -> ("config_builder", config)) built_config in
    let provenance =
      collect_provenance [ system_defaults; default_repo_config; built_config; repo_config ]
    in
    validate_configs [ system_defaults; default_repo_config; built_config; repo_config ]
    >>= fun () ->
    Abb.Future.return (merge ~base:system_defaults default_repo_config)
    >>= fun default_repo_config ->
    Abb.Future.return (merge ~base:system_defaults built_config)
    >>= fun base_repo_config ->
    Abb.Future.return (merge ~base:base_repo_config repo_config)
    >>= fun repo_config ->
    Abbs_future_combinators.Infix_result_app.(
      (fun default_repo_config repo_config -> (default_repo_config, repo_config))
      <$> wrap_err
            "default"
            (Abb.Future.return (V1.of_version_1_json (get_json default_repo_config)))
      <*> wrap_err "repo" (Abb.Future.return (V1.of_version_1_json (get_json repo_config))))
    >>= fun (default_repo_config, repo_config) ->
    let final_repo_config =
      Terrat_base_repo_config_v1.merge_with_default_branch_config
        ~default:default_repo_config
        repo_config
    in
    (* Warn OSS users about enabled functionality that only is part of the
           EE edition.  This is to make sure someone doesn't enable
           functionality and is surprised when it doesn't work. *)
    match V1.to_view final_repo_config with
    | { V1.View.access_control = { V1.Access_control.enabled = true; _ }; _ } ->
        Abb.Future.return (Error (`Premium_feature_err `Access_control))
    | { V1.View.drift = { V1.Drift.enabled = true; schedules }; _ }
      when Sln_map.String.cardinal schedules > 1 ->
        Abb.Future.return (Error (`Premium_feature_err `Multiple_drift_schedules))
    | { V1.View.apply_requirements = { V1.Apply_requirements.checks; _ }; _ }
      when CCList.exists
             (fun {
                    V1.Apply_requirements.Check.approved =
                      { V1.Apply_requirements.Approved.require_completed_reviews; _ };
                    _;
                  }
                -> require_completed_reviews)
             checks -> Abb.Future.return (Error (`Premium_feature_err `Require_completed_reviews))
    | {
     V1.View.notifications =
       { V1.Notifications.summary = { V1.Notifications.Summary.enabled = true }; _ };
     _;
    } -> Abb.Future.return (Error (`Premium_feature_err `Notifications_summary))
    | _ -> Abb.Future.return (Ok (provenance, final_repo_config))
end

module Access_control = struct
  (* Access control is an enterprise feature, so always return success on
       any requests. *)

  let query ~request_id:_ _ _ _ _ = Abb.Future.return (Ok true)
  let is_ci_changed ~request_id:_ _ _ _ = Abb.Future.return (Ok false)
end

module Commit_check = struct
  let make_dirspace_title ~run_type { Terrat_dirspace.dir; workspace } =
    Printf.sprintf "terrateam %s: %s %s" run_type dir workspace

  let make ?work_manifest:_ ~config:_ ~description ~title ~status ~repo:_ ~account:_ () =
    Terrat_commit_check.make ~details_url:"" ~description ~title ~status

  let make_str ?work_manifest ~config ~description ~status ~repo ~account s =
    make ?work_manifest ~config ~description ~title:s ~status ~repo ~account ()

  let make_dirspace
      ?work_manifest
      ~config
      ~description
      ~run_type
      ~dirspace
      ~status
      ~repo
      ~account
      () =
    make_str
      ?work_manifest
      ~config
      ~description
      ~status
      ~repo
      ~account
      (make_dirspace_title ~run_type dirspace)
end

module Work_manifest = struct
  module Sql = struct
    let read s =
      s
      |> CCString.split_on_char '\n'
      |> CCList.filter CCFun.(CCString.prefix ~pre:"--" %> not)
      |> CCString.concat "\n"

    let insert_work_manifest_query = read [%blob "sql/insert_work_manifest.sql"]

    let insert_work_manifest () =
      Pgsql_io.Typed_sql.(
        sql
        //
        (* id *)
        Ret.uuid
        //
        (* state *)
        Ret.u Ret.text Terrat_work_manifest3.State.of_string
        //
        (* created_at *)
        Ret.text
        /^ insert_work_manifest_query
        /% Var.text "base_sha"
        /% Var.(option (bigint "pull_number"))
        /% Var.bigint "repository"
        /% Var.text "run_type"
        /% Var.text "sha"
        /% Var.text "tag_query"
        /% Var.(option (text "username"))
        /% Var.json "dirspaces"
        /% Var.text "run_kind"
        /% Var.(option (text "environment"))
        /% Var.(option (json "runs_on")))

    let insert_work_manifest_access_control_denied_dirspace =
      Pgsql_io.Typed_sql.(
        sql
        /^ read [%blob "sql/insert_work_manifest_access_control_denied_dirspace.sql"]
        /% Var.(str_array (text "path"))
        /% Var.(str_array (text "workspace"))
        /% Var.(str_array (option (json "policy")))
        /% Var.(str_array (uuid "work_manifest")))

    let insert_work_manifest_dirspaceflow_query =
      read [%blob "sql/insert_work_manifest_dirspaceflow.sql"]

    let insert_work_manifest_dirspaceflow () =
      Pgsql_io.Typed_sql.(
        sql
        /^ insert_work_manifest_dirspaceflow_query
        /% Var.(str_array (uuid "work_manifest"))
        /% Var.(str_array (text "path"))
        /% Var.(str_array (text "workspace"))
        /% Var.(array (option (smallint "workflow_idx"))))

    let insert_drift_work_manifest_query = read [%blob "sql/insert_drift_work_manifest.sql"]

    let insert_drift_work_manifest () =
      Pgsql_io.Typed_sql.(
        sql /^ insert_drift_work_manifest_query /% Var.uuid "work_manifest" /% Var.text "branch")

    let update_work_manifest_state_running_query =
      read [%blob "sql/update_work_manifest_state_running.sql"]

    let update_work_manifest_state_running () =
      Pgsql_io.Typed_sql.(sql /^ update_work_manifest_state_running_query /% Var.uuid "id")

    let update_work_manifest_state_completed_query =
      read [%blob "sql/update_work_manifest_state_completed.sql"]

    let update_work_manifest_state_completed () =
      Pgsql_io.Typed_sql.(sql /^ update_work_manifest_state_completed_query /% Var.uuid "id")

    let update_work_manifest_state_aborted_query =
      read [%blob "sql/update_work_manifest_state_aborted.sql"]

    let update_work_manifest_state_aborted () =
      Pgsql_io.Typed_sql.(sql /^ update_work_manifest_state_aborted_query /% Var.uuid "id")

    let update_work_manifest_run_id_query = read [%blob "sql/update_work_manifest_run_id.sql"]

    let update_work_manifest_run_id () =
      Pgsql_io.Typed_sql.(
        sql /^ update_work_manifest_run_id_query /% Var.uuid "id" /% Var.(option (text "run_id")))

    let update_run_type =
      Pgsql_io.Typed_sql.(
        sql /^ read [%blob "sql/update_run_type.sql"] /% Var.uuid "id" /% Var.text "run_type")

    let select_work_manifest_by_run_id () =
      Pgsql_io.Typed_sql.(
        sql
        //
        (* id *)
        Ret.uuid
        /^ "select id from work_manifests where run_id = $run_id"
        /% Var.text "run_id")
  end

  let run ~request_id config client work_manifest =
    let module Pipeline_api = Gitlabc_projects_pipeline.PostApiV4ProjectsIdPipeline in
    let module Wm = Terrat_work_manifest3 in
    let get_repo = function
      | { Wm.target = Terrat_vcs_provider2.Target.Pr pr; _ } -> Api.Pull_request.repo pr
      | { Wm.target = Terrat_vcs_provider2.Target.Drift { repo; _ }; _ } -> repo
    in
    let get_branch = function
      | { Wm.target = Terrat_vcs_provider2.Target.Pr pr; _ } -> (
          match Api.Pull_request.state pr with
          | Terrat_pull_request.State.(Open _ | Closed) ->
              Api.Ref.to_string @@ Terrat_pull_request.branch_name pr
          | Terrat_pull_request.State.Merged _ ->
              Api.Ref.to_string @@ Terrat_pull_request.base_branch_name pr)
      | { Wm.target = Terrat_vcs_provider2.Target.Drift { branch; _ }; _ } -> branch
    in
    let build_pipeline_inputs ~work_manifest ~config () =
      let base_inputs =
        [
          ("TERRATEAM_TRIGGER", `String "true");
          ("WORK_TOKEN", `String (Ouuid.to_string work_manifest.Wm.id));
          ("API_BASE_URL", `String (Terrat_config.api_base (Api.Config.config config) ^ "/gitlab"));
        ]
      in
      let runs_on_inputs =
        match work_manifest.Wm.runs_on with
        | Some runs_on -> [ ("RUNS_ON", runs_on) ]
        | None -> []
      in
      Sln_map.String.of_list (base_inputs @ runs_on_inputs)
    in
    let run =
      let open Abbs_future_combinators.Infix_result_monad in
      let module Pipeline = Gitlabc_components.PostApiV4ProjectsIdPipeline in
      let repo = get_repo work_manifest in
      let body =
        {
          Pipeline.ref_ = get_branch work_manifest;
          inputs =
            Some
              Pipeline.Inputs.
                {
                  primary = Json_schema.Empty_obj.t;
                  additional = build_pipeline_inputs ~work_manifest ~config ();
                };
          variables = None;
        }
      in
      Openapic_abb.call
        (Api.Client.to_native client)
        Pipeline_api.(make ~body (Parameters.make ~id:(CCInt.to_string @@ Api.Repo.id repo)))
      >>= fun resp ->
      match Openapi.Response.value resp with
      | `Created _ -> Abb.Future.return (Ok ())
      | `Bad_request json
        when CCString.find ~sub:"Identity verification is required in order to run CI jobs"
             @@ Yojson.Safe.to_string json
             <> -1 ->
          (* The above is cheap trick to determine if our specific error message
             we care about is somewhere in the JSON error rather than decoding
             it. *)
          Abb.Future.return (Error (`Failed_to_start_with_msg_err "IDENTITY_VERIFICATION_ERR"))
      | `Bad_request json
        when CCString.find
               ~sub:"Given inputs not defined in the `spec` section"
               (Yojson.Safe.to_string json)
             <> -1 ->
          let err_msg = "Given inputs not defined in the `spec` section" in
          Logs.err (fun m -> m "%s : %s : %s" request_id err_msg (Yojson.Safe.to_string json));
          Abb.Future.return (Error (`Failed_to_start_with_msg_err "GITLAB_INPUTS_MISSING_DEFAULTS"))
      | (`Bad_request _ | `Unauthorized _ | `Forbidden _ | `Not_found _) as err ->
          Abb.Future.return (Error err)
    in
    let open Abb.Future.Infix_monad in
    run
    >>= function
    | Ok _ -> Abb.Future.return (Ok ())
    | Error (`Failed_to_start_with_msg_err _) as err -> Abb.Future.return err
    | Error (#Pipeline_api.Responses.t as err) ->
        Logs.err (fun m -> m "%s : %a" request_id Pipeline_api.Responses.pp err);
        Abb.Future.return (Error `Error)
    | Error (#Openapic_abb.call_err as err) ->
        Logs.err (fun m -> m "%s : %a" request_id Openapic_abb.pp_call_err err);
        Abb.Future.return (Error `Error)

  let update_work_manifest_changes ~request_id db work_manifest_id changes =
    let module Tc = Terrat_change in
    let module Dsf = Tc.Dirspaceflow in
    let module Ds = Tc.Dirspace in
    let open Abb.Future.Infix_monad in
    Abbs_future_combinators.List_result.iter
      ~f:(fun changes ->
        Metrics.Psql_query_time.time
          (Metrics.psql_query_time "insert_work_manifest_dirspaceflow")
          (fun () ->
            Pgsql_io.Prepared_stmt.execute
              db
              (Sql.insert_work_manifest_dirspaceflow ())
              (CCList.replicate (CCList.length changes) work_manifest_id)
              (CCList.map (fun { Dsf.dirspace = { Ds.dir; _ }; _ } -> dir) changes)
              (CCList.map (fun { Dsf.dirspace = { Ds.workspace; _ }; _ } -> workspace) changes)
              (CCList.map (fun { Dsf.workflow; _ } -> workflow) changes)))
      (CCList.chunks not_a_bad_chunk_size changes)
    >>= function
    | Ok () -> Abb.Future.return (Ok ())
    | Error (#Pgsql_io.err as err) ->
        Prmths.Counter.inc_one Metrics.pgsql_errors_total;
        Logs.err (fun m -> m "%s : ERROR : %a" request_id Pgsql_io.pp_err err);
        Abb.Future.return (Error `Error)

  let update_work_manifest_denied_dirspaces ~request_id db work_manifest_id denied_dirspaces =
    let module Ch = Terrat_change in
    let module Wm = Terrat_work_manifest3 in
    let open Abb.Future.Infix_monad in
    let module Policy = struct
      type t = Terrat_base_repo_config_v1.Access_control.Match_list.t [@@deriving yojson]
    end in
    Abbs_future_combinators.List_result.iter
      ~f:(fun denied_dirspaces ->
        Metrics.Psql_query_time.time
          (Metrics.psql_query_time "insert_work_manifest_access_control_denied_dirspace")
          (fun () ->
            Pgsql_io.Prepared_stmt.execute
              db
              Sql.insert_work_manifest_access_control_denied_dirspace
              (CCList.map
                 (fun { Wm.Deny.dirspace = { Ch.Dirspace.dir; _ }; _ } -> dir)
                 denied_dirspaces)
              (CCList.map
                 (fun { Wm.Deny.dirspace = { Ch.Dirspace.workspace; _ }; _ } -> workspace)
                 denied_dirspaces)
              (CCList.map
                 (fun { Wm.Deny.policy; _ } ->
                   (* This has a very awkward JSON conversion because we are
                    performing this insert by passing in a bunch of arrays
                    of values.  However policy is already an array and SQL
                    does not support multidimensional arrays where the
                    inner arrays can have different dimensions.  So we need
                    to convert the policy to a string so that we can pass
                    in an array of strings, and it needs to be in a format
                    postgresql can turn back into an array.  So we use JSON
                    as the intermediate representation. *)
                   CCOption.map (fun policy -> Policy.to_yojson policy) policy)
                 denied_dirspaces)
              (CCList.replicate (CCList.length denied_dirspaces) work_manifest_id)))
      (CCList.chunks not_a_bad_chunk_size denied_dirspaces)
    >>= function
    | Ok () -> Abb.Future.return (Ok ())
    | Error (#Pgsql_io.err as err) ->
        Prmths.Counter.inc_one Metrics.pgsql_errors_total;
        Logs.err (fun m -> m "%s : ERROR : %a" request_id Pgsql_io.pp_err err);
        Abb.Future.return (Error `Error)

  let create ~request_id db work_manifest =
    let run =
      let module Wm = Terrat_work_manifest3 in
      let module Tc = Terrat_change in
      let module Dsf = Tc.Dirspaceflow in
      let module Ds = Tc.Dirspace in
      let open Abbs_future_combinators.Infix_result_monad in
      let dirspaces_json =
        `List
          (CCList.map
             (fun dsf ->
               let ds = Dsf.to_dirspace dsf in
               `Assoc [ ("dir", `String ds.Ds.dir); ("workspace", `String ds.Ds.workspace) ])
             work_manifest.Wm.changes)
      in
      let dirspaces = dirspaces_json in
      let pull_number_opt =
        match work_manifest.Wm.target with
        | Terrat_vcs_provider2.Target.Pr pr -> Some (Api.Pull_request.id pr)
        | Terrat_vcs_provider2.Target.Drift _ -> None
      in
      let repo_id =
        match work_manifest.Wm.target with
        | Terrat_vcs_provider2.Target.Pr pr -> Api.Repo.id @@ Api.Pull_request.repo pr
        | Terrat_vcs_provider2.Target.Drift { repo; _ } -> Api.Repo.id repo
      in
      let run_kind =
        match work_manifest.Wm.target with
        | Terrat_vcs_provider2.Target.Pr _ -> "pr"
        | Terrat_vcs_provider2.Target.Drift _ -> "drift"
      in
      let run_type =
        CCOption.map_or
          ~default:""
          Terrat_work_manifest3.Step.to_string
          (CCList.last_opt work_manifest.Wm.steps)
      in
      let user =
        match work_manifest.Wm.initiator with
        | Wm.Initiator.User user -> Some user
        | Wm.Initiator.System -> None
      in
      Metrics.Psql_query_time.time (Metrics.psql_query_time "insert_work_manifest") (fun () ->
          Pgsql_io.Prepared_stmt.fetch
            db
            (Sql.insert_work_manifest ())
            ~f:(fun id state created_at -> (id, state, created_at))
            work_manifest.Wm.base_ref
            (CCOption.map CCInt64.of_int pull_number_opt)
            (CCInt64.of_int repo_id)
            run_type
            work_manifest.Wm.branch_ref
            (Terrat_tag_query.to_string work_manifest.Wm.tag_query)
            user
            dirspaces
            run_kind
            work_manifest.Wm.environment
            work_manifest.Wm.runs_on)
      >>= function
      | [] -> assert false
      | (id, state, created_at) :: _ -> (
          update_work_manifest_changes ~request_id db id work_manifest.Wm.changes
          >>= fun () ->
          update_work_manifest_denied_dirspaces ~request_id db id work_manifest.Wm.denied_dirspaces
          >>= fun () ->
          let work_manifest = { work_manifest with Wm.id; state; created_at; run_id = None } in
          match work_manifest.Wm.target with
          | Terrat_vcs_provider2.Target.Pr pr ->
              Abb.Future.return
                (Ok
                   {
                     work_manifest with
                     Wm.target =
                       Terrat_vcs_provider2.Target.Pr
                         (Terrat_pull_request.set_diff () @@ Terrat_pull_request.set_checks () pr);
                   })
          | Terrat_vcs_provider2.Target.Drift { repo = _; branch } ->
              Pgsql_io.Prepared_stmt.execute db (Sql.insert_drift_work_manifest ()) id branch
              >>= fun () -> Abb.Future.return (Ok work_manifest))
    in
    let open Abb.Future.Infix_monad in
    run
    >>= function
    | Ok _ as ret -> Abb.Future.return ret
    | Error (#Pgsql_io.err as err) ->
        Prmths.Counter.inc_one Metrics.pgsql_errors_total;
        Logs.err (fun m -> m "%s : ERROR : %a" request_id Pgsql_io.pp_err err);
        Abb.Future.return (Error `Error)
    | Error `Error -> Abb.Future.return (Error `Error)

  let query' = Db.query_work_manifests
  let query = Db.query_work_manifest

  let query_by_run_id ~request_id db run_id =
    let run =
      let open Abbs_future_combinators.Infix_result_monad in
      Pgsql_io.Prepared_stmt.fetch db (Sql.select_work_manifest_by_run_id ()) ~f:CCFun.id run_id
      >>= function
      | [] -> Abb.Future.return (Ok None)
      | id :: _ -> query ~request_id db id
    in
    let open Abb.Future.Infix_monad in
    run
    >>= function
    | Ok _ as r -> Abb.Future.return r
    | Error (#Pgsql_io.err as err) ->
        Logs.err (fun m -> m "%s : %a" request_id Pgsql_io.pp_err err);
        Abb.Future.return (Error `Error)
    | Error `Error -> Abb.Future.return (Error `Error)

  let update_state ~request_id db work_manifest_id state =
    let module Wm = Terrat_work_manifest3 in
    let sql =
      match state with
      | Wm.State.Running -> Sql.update_work_manifest_state_running
      | Wm.State.Completed -> Sql.update_work_manifest_state_completed
      | Wm.State.Aborted -> Sql.update_work_manifest_state_aborted
      | Wm.State.Queued -> assert false
    in
    let open Abb.Future.Infix_monad in
    Metrics.Psql_query_time.time (Metrics.psql_query_time "update_work_manifest_state") (fun () ->
        Pgsql_io.Prepared_stmt.execute db (sql ()) work_manifest_id)
    >>= function
    | Ok () -> Abb.Future.return (Ok ())
    | Error (#Pgsql_io.err as err) ->
        Prmths.Counter.inc_one Metrics.pgsql_errors_total;
        Logs.err (fun m -> m "%s : ERROR : %a" request_id Pgsql_io.pp_err err);
        Abb.Future.return (Error `Error)

  let update_run_id ~request_id db work_manifest_id run_id =
    let open Abb.Future.Infix_monad in
    Metrics.Psql_query_time.time (Metrics.psql_query_time "update_work_manifest_run_id") (fun () ->
        Pgsql_io.Prepared_stmt.execute
          db
          (Sql.update_work_manifest_run_id ())
          work_manifest_id
          (Some run_id))
    >>= function
    | Ok () -> Abb.Future.return (Ok ())
    | Error (#Pgsql_io.err as err) ->
        Prmths.Counter.inc_one Metrics.pgsql_errors_total;
        Logs.err (fun m -> m "%s : ERROR : %a" request_id Pgsql_io.pp_err err);
        Abb.Future.return (Error `Error)

  let update_changes ~request_id db work_manifest_id dirspaceflows =
    let module Tc = Terrat_change in
    let module Dsf = Tc.Dirspaceflow in
    let module Ds = Tc.Dirspace in
    let open Abb.Future.Infix_monad in
    Abbs_future_combinators.List_result.iter
      ~f:(fun changes ->
        Metrics.Psql_query_time.time
          (Metrics.psql_query_time "insert_work_manifest_dirspaceflow")
          (fun () ->
            Pgsql_io.Prepared_stmt.execute
              db
              (Sql.insert_work_manifest_dirspaceflow ())
              (CCList.replicate (CCList.length changes) work_manifest_id)
              (CCList.map (fun { Dsf.dirspace = { Ds.dir; _ }; _ } -> dir) changes)
              (CCList.map (fun { Dsf.dirspace = { Ds.workspace; _ }; _ } -> workspace) changes)
              (CCList.map (fun { Dsf.workflow; _ } -> workflow) changes)))
      (CCList.chunks not_a_bad_chunk_size dirspaceflows)
    >>= function
    | Ok () -> Abb.Future.return (Ok ())
    | Error (#Pgsql_io.err as err) ->
        Prmths.Counter.inc_one Metrics.pgsql_errors_total;
        Logs.err (fun m -> m "%s : ERROR : %a" request_id Pgsql_io.pp_err err);
        Abb.Future.return (Error `Error)

  let update_denied_dirspaces ~request_id db work_manifest_id denied_dirspaces =
    let module Ch = Terrat_change in
    let module Wm = Terrat_work_manifest3 in
    let open Abb.Future.Infix_monad in
    let module Policy = struct
      type t = Terrat_base_repo_config_v1.Access_control.Match_list.t [@@deriving yojson]
    end in
    Abbs_future_combinators.List_result.iter
      ~f:(fun denied_dirspaces ->
        Metrics.Psql_query_time.time
          (Metrics.psql_query_time "insert_work_manifest_access_control_denied_dirspace")
          (fun () ->
            Pgsql_io.Prepared_stmt.execute
              db
              Sql.insert_work_manifest_access_control_denied_dirspace
              (CCList.map
                 (fun { Wm.Deny.dirspace = { Ch.Dirspace.dir; _ }; _ } -> dir)
                 denied_dirspaces)
              (CCList.map
                 (fun { Wm.Deny.dirspace = { Ch.Dirspace.workspace; _ }; _ } -> workspace)
                 denied_dirspaces)
              (CCList.map
                 (fun { Wm.Deny.policy; _ } ->
                   (* This has a very awkward JSON conversion because we are
                    performing this insert by passing in a bunch of arrays
                    of values.  However policy is already an array and SQL
                    does not support multidimensional arrays where the
                    inner arrays can have different dimensions.  So we need
                    to convert the policy to a string so that we can pass
                    in an array of strings, and it needs to be in a format
                    postgresql can turn back into an array.  So we use JSON
                    as the intermediate representation. *)
                   CCOption.map (fun policy -> Policy.to_yojson policy) policy)
                 denied_dirspaces)
              (CCList.replicate (CCList.length denied_dirspaces) work_manifest_id)))
      (CCList.chunks not_a_bad_chunk_size denied_dirspaces)
    >>= function
    | Ok () -> Abb.Future.return (Ok ())
    | Error (#Pgsql_io.err as err) ->
        Prmths.Counter.inc_one Metrics.pgsql_errors_total;
        Logs.err (fun m -> m "%s : ERROR : %a" request_id Pgsql_io.pp_err err);
        Abb.Future.return (Error `Error)

  let update_steps ~request_id db work_manifest_id steps =
    let open Abb.Future.Infix_monad in
    let run_type =
      CCOption.map_or ~default:"" Terrat_work_manifest3.Step.to_string (CCList.last_opt steps)
    in
    Metrics.Psql_query_time.time
      (Metrics.psql_query_time "update_run_type work_manifest_id")
      (fun () -> Pgsql_io.Prepared_stmt.execute db Sql.update_run_type work_manifest_id run_type)
    >>= function
    | Ok () -> Abb.Future.return (Ok ())
    | Error (#Pgsql_io.err as err) ->
        Prmths.Counter.inc_one Metrics.pgsql_errors_total;
        Logs.err (fun m -> m "%s : ERROR : %a" request_id Pgsql_io.pp_err err);
        Abb.Future.return (Error `Error)

  let result _rest = raise (Failure "NOT SUPPORTED")

  let result2 result =
    let module R2 = Terrat_api_components.Work_manifest_tf_operation_result2 in
    let by_scope = By_scope.group result.R2.steps in
    let steps_success steps =
      let module O = Terrat_api_components.Workflow_step_output in
      CCList.for_all (fun { O.success; ignore_errors; _ } -> success || ignore_errors) steps
    in

    let hooks_pre =
      CCList.Assoc.get ~eq:Scope.equal (Scope.Run { flow = "hooks"; subflow = "pre" }) by_scope
    in
    let hooks_post =
      CCList.Assoc.get ~eq:Scope.equal (Scope.Run { flow = "hooks"; subflow = "post" }) by_scope
    in
    let dirspaces =
      CCList.filter_map
        (function
          | Scope.Dirspace dirspace, steps -> Some (dirspace, steps)
          | _ -> None)
        by_scope
    in
    let pre_hooks_success = steps_success (CCOption.get_or ~default:[] hooks_pre) in
    let post_hooks_success = steps_success (CCOption.get_or ~default:[] hooks_post) in
    let dirspaces_success =
      CCList.map (fun (dirspace, steps) -> (dirspace, steps_success steps)) dirspaces
    in
    let overall_success = CCList.for_all (fun (_, steps) -> steps_success steps) by_scope in
    {
      Terrat_vcs_provider2.Work_manifest_result.overall_success;
      pre_hooks_success;
      post_hooks_success;
      dirspaces_success;
    }
end

module Stacks = struct
  include Terrat_vcs_stacks.Make (struct
    module Installation_id = Api.Account.Id
    module Repo_id = Api.Repo.Id
    module Pull_request_id = Api.Pull_request.Id
    module Config = Api.Config

    type db = Db.t

    let vcs = name
    let route_root () = Brtl_rtng.Route.(rel / "api" / "v1")

    module Sql = struct
      let read s = Pgsql_io.clean_string s

      let select_stacks () =
        Pgsql_io.Typed_sql.(
          sql
          //
          (* stacks *)
          Ret.u Ret.json CCFun.(Terrat_api_components.Stacks.of_yojson %> CCOption.of_result)
          /^ read [%blob "sql/select_stacks.sql"]
          /% Var.bigint "repo_id"
          /% Var.bigint "pull_number")

      let upsert_stacks () =
        Pgsql_io.Typed_sql.(
          sql
          /^ read [%blob "sql/upsert_stacks.sql"]
          /% Var.bigint "repo_id"
          /% Var.bigint "pull_number"
          /% Var.json "stacks")

      let select_dirspace_states () =
        Pgsql_io.Typed_sql.(
          sql
          //
          (* dir *)
          Ret.text
          //
          (* workspace *)
          Ret.text
          //
          (* state *)
          Ret.text
          /^ read [%blob "sql/select_dirspace_stack_states.sql"]
          /% Var.bigint "repo_id"
          /% Var.bigint "pull_number")
    end

    let store_stacks ~request_id ~installation_id:_ ~repo_id ~pull_request_id stacks db =
      let open Abb.Future.Infix_monad in
      Pgsql_io.Prepared_stmt.execute
        db
        (Sql.upsert_stacks ())
        (CCInt64.of_int repo_id)
        (CCInt64.of_int pull_request_id)
        (Terrat_api_components.Stacks.to_yojson stacks)
      >>= function
      | Ok _ as r -> Abb.Future.return r
      | Error (#Pgsql_io.err as err) ->
          Logs.err (fun m -> m "%s : %a" request_id Pgsql_io.pp_err err);
          Abb.Future.return (Error `Error)

    let query_stacks ~request_id ~installation_id:_ ~repo_id ~pull_request_id db =
      let open Abb.Future.Infix_monad in
      Pgsql_io.Prepared_stmt.fetch
        db
        (Sql.select_stacks ())
        ~f:CCFun.id
        (CCInt64.of_int repo_id)
        (CCInt64.of_int pull_request_id)
      >>= function
      | Ok r -> Abb.Future.return (Ok (CCOption.of_list r))
      | Error (#Pgsql_io.err as err) ->
          Logs.err (fun m -> m "%s : %a" request_id Pgsql_io.pp_err err);
          Abb.Future.return (Error `Error)

    let query_dirspace_states ~request_id ~installation_id:_ ~repo_id ~pull_request_id db =
      let open Abb.Future.Infix_monad in
      Pgsql_io.Prepared_stmt.fetch
        db
        (Sql.select_dirspace_states ())
        ~f:(fun dir workspace state ->
          let state =
            CCResult.get_or_failwith @@ Terrat_api_components_stack_state.of_yojson (`String state)
          in
          { Terrat_vcs_stacks.Dirspace_state.dirspace = { Terrat_dirspace.dir; workspace }; state })
        (CCInt64.of_int repo_id)
        (CCInt64.of_int pull_request_id)
      >>= function
      | Ok _ as r -> Abb.Future.return r
      | Error (#Pgsql_io.err as err) ->
          Logs.err (fun m -> m "%s : %a" request_id Pgsql_io.pp_err err);
          Abb.Future.return (Error `Error)

    let enforce_installation_access = enforce_installation_access
  end)
end

module Job_context = struct
  module Tjc = Terrat_job_context

  module Sql = struct
    let read s = Pgsql_io.clean_string s

    let select_or_insert_pull_request_context =
      Pgsql_io.Typed_sql.(
        sql
        //
        (* id *)
        Ret.uuid
        //
        (* created_at *)
        Ret.text
        //
        (* updated_at *)
        Ret.text
        /^ read [%blob "sql/select_or_insert_pull_request_context.sql"]
        /% Var.bigint "repo_id"
        /% Var.bigint "pull_number")

    let select_or_insert_branch_context =
      Pgsql_io.Typed_sql.(
        sql
        //
        (* id *)
        Ret.uuid
        //
        (* created_at *)
        Ret.text
        //
        (* updated_at *)
        Ret.text
        /^ read [%blob "sql/select_or_insert_branch_context.sql"]
        /% Var.bigint "repo_id"
        /% Var.text "branch")

    let scope_of_json =
      let module C = Terrat_job_context_param_context in
      let module P = Terrat_job_context_param_pull_request in
      let module B = Terrat_job_context_param_branch in
      let module Bb = Terrat_job_context_param_branch_dest_branch in
      let module S = Terrat_job_context.Context.Scope in
      CCFun.(
        C.of_yojson
        %> CCResult.to_opt
        %> CCOption.map (function
          | C.Pull_request { P.pull_request } -> S.Pull_request pull_request
          | C.Branch { B.branch } -> S.Branch (Api.Ref.of_string branch, None)
          | C.Branch_dest_branch { Bb.branch; dest_branch } ->
              S.Branch (Api.Ref.of_string branch, Some (Api.Ref.of_string dest_branch))))

    let select_context_by_id =
      Pgsql_io.Typed_sql.(
        sql
        //
        (* created_at *)
        Ret.text
        //
        (* scope *)
        Ret.(u json scope_of_json)
        //
        (* updated_at *)
        Ret.text
        /^ read [%blob "sql/select_context_by_id.sql"]
        /% Var.uuid "id")

    let string_of_state = function
      | Tjc.Job.State.Running -> "running"
      | Tjc.Job.State.Completed -> "completed"
      | Tjc.Job.State.Failed -> "failed"

    let state_of_string = function
      | "running" -> Some Tjc.Job.State.Running
      | "completed" -> Some Tjc.Job.State.Completed
      | "failed" -> Some Tjc.Job.State.Failed
      | _ -> None

    module Type_ = struct
      let kind_to_json =
        let module K = Terrat_job_context.Job.Type_.Kind in
        let module O = Terrat_job_type_kind in
        let module Kd = Terrat_job_type_kind_drift in
        CCOption.map (function K.Drift { reconcile } ->
            O.Kind_drift { Kd.reconcile; type_ = `Drift })

      let json_to_kind =
        let module K = Terrat_job_context.Job.Type_.Kind in
        let module O = Terrat_job_type_kind in
        let module Kd = Terrat_job_type_kind_drift in
        CCOption.map (function O.Kind_drift { Kd.reconcile; type_ = _ } -> K.Drift { reconcile })

      let to_json =
        let module T = Terrat_job_context.Job.Type_ in
        let module Jt = Terrat_job_type in
        CCFun.(
          (function
          | T.Apply { tag_query; kind; force } ->
              Jt.Type.Apply
                {
                  Jt.Apply.type_ = `Apply;
                  tag_query = Some (Terrat_tag_query.to_string tag_query);
                  kind = kind_to_json kind;
                  force;
                }
          | T.Autoapply ->
              Jt.Type.Apply
                { Jt.Apply.type_ = `Apply; tag_query = None; kind = None; force = false }
          | T.Autoplan -> Jt.Type.Plan { Jt.Plan.type_ = `Plan; tag_query = None; kind = None }
          | T.Plan { tag_query; kind } ->
              Jt.Type.Plan
                {
                  Jt.Plan.type_ = `Plan;
                  tag_query = Some (Terrat_tag_query.to_string tag_query);
                  kind = kind_to_json kind;
                }
          | T.Gate_approval { tokens } ->
              Jt.Type.Gate_approval { Jt.Gate_approval.type_ = `Gate_approval; tokens }
          | T.Help -> Jt.Type.Help { Jt.Help.type_ = `Help }
          | T.Index -> Jt.Type.Index { Jt.Index.type_ = `Index }
          | T.Repo_config -> Jt.Type.Repo_config { Jt.Repo_config.type_ = `Repo_config }
          | T.Unlock unlocks -> Jt.Type.Unlock { Jt.Unlock.type_ = `Unlock; ids = unlocks }
          | T.Push -> Jt.Type.Push { Jt.Push.type_ = `Push })
          %> Jt.Type.to_yojson)

      let of_json =
        let module T = Terrat_job_context.Job.Type_ in
        let module Jt = Terrat_job_type in
        CCFun.(
          Jt.Type.of_yojson
          %> CCResult.to_opt
          %> CCOption.flat_map (function
            | Jt.Type.Apply { Jt.Apply.type_ = _; tag_query = Some tag_query; kind; force } ->
                Some
                  (T.Apply
                     {
                       tag_query = CCResult.get_exn @@ Terrat_tag_query.of_string tag_query;
                       kind = json_to_kind kind;
                       force;
                     })
            | Jt.Type.Apply { Jt.Apply.type_ = _; tag_query = None; kind = _; force = _ } ->
                Some T.Autoapply
            | Jt.Type.Plan { Jt.Plan.type_ = _; tag_query = Some tag_query; kind } ->
                Some
                  (T.Plan
                     {
                       tag_query = CCResult.get_exn @@ Terrat_tag_query.of_string tag_query;
                       kind = json_to_kind kind;
                     })
            | Jt.Type.Plan { Jt.Plan.type_ = _; tag_query = None; kind = _ } -> Some T.Autoplan
            | Jt.Type.Repo_config { Jt.Repo_config.type_ = _ } -> Some T.Repo_config
            | Jt.Type.Unlock { Jt.Unlock.type_ = _; ids } -> Some (T.Unlock ids)
            | Jt.Type.Gate_approval { Jt.Gate_approval.type_ = _; tokens } ->
                Some (T.Gate_approval { tokens })
            | Jt.Type.Help { Jt.Help.type_ = _ } -> Some T.Help
            | Jt.Type.Index { Jt.Index.type_ = _ } -> Some T.Index
            | Jt.Type.Push { Jt.Push.type_ = _ } -> Some T.Push))
    end

    let string_of_initiator = Api.User.to_string
    let initiator_of_string = CCFun.(Api.User.make %> CCOption.return)

    let insert_job =
      Pgsql_io.Typed_sql.(
        sql
        //
        (* id *)
        Ret.uuid
        //
        (* created_at *)
        Ret.text
        //
        (* updated_at *)
        Ret.text
        /^ read [%blob "sql/insert_job.sql"]
        /% Var.uuid "context_id"
        /% Var.ud (Var.text "state") string_of_state
        /% Var.ud (Var.json "parameters") Type_.to_json
        /% Var.ud (Var.option (Var.text "initiator")) (CCOption.map string_of_initiator))

    let select_job_by_id =
      Pgsql_io.Typed_sql.(
        sql
        //
        (* id *)
        Ret.uuid
        //
        (* context_id *)
        Ret.uuid
        //
        (* type *)
        Ret.(u json Type_.of_json)
        //
        (* state *)
        Ret.(u text state_of_string)
        //
        (* initiator *)
        Ret.(option (u text initiator_of_string))
        //
        (* created_at *)
        Ret.text
        //
        (* updated_at *)
        Ret.text
        //
        (* completed_at *)
        Ret.(option text)
        /^ read [%blob "sql/select_job_by_id.sql"]
        /% Var.uuid "id")

    let select_job_by_work_manifest_id =
      Pgsql_io.Typed_sql.(
        sql
        //
        (* id *)
        Ret.uuid
        //
        (* context_id *)
        Ret.uuid
        //
        (* type *)
        Ret.(u json Type_.of_json)
        //
        (* state *)
        Ret.(u text state_of_string)
        //
        (* initiator *)
        Ret.(option (u text initiator_of_string))
        //
        (* created_at *)
        Ret.text
        //
        (* updated_at *)
        Ret.text
        //
        (* completed_at *)
        Ret.(option text)
        /^ read [%blob "sql/select_job_by_work_manifest_id.sql"]
        /% Var.uuid "work_manifest")

    let update_job_state =
      Pgsql_io.Typed_sql.(
        sql
        /^ read [%blob "sql/update_job_state.sql"]
        /% Var.uuid "job"
        /% Var.ud (Var.text "state") string_of_state)

    let upsert_job_work_manifest =
      Pgsql_io.Typed_sql.(
        sql
        /^ read [%blob "sql/upsert_job_work_manifest.sql"]
        /% Var.uuid "job"
        /% Var.uuid "work_manifest")

    let select_job_work_manifests =
      Pgsql_io.Typed_sql.(
        sql
        //
        (* work_manifest_id *)
        Ret.uuid
        /^ read [%blob "sql/select_job_work_manifests.sql"]
        /% Var.uuid "job")

    let to_compute_node_state =
      Tjc.Compute_node.State.(
        function
        | "starting" -> Some Starting
        | "running" -> Some Running
        | "terminated" -> Some Terminated
        | _ -> None)

    let to_capabilities = CCFun.(Tjc.Compute_node.Capabilities.of_yojson %> CCOption.of_result)

    let insert_compute_node () =
      Pgsql_io.Typed_sql.(
        sql
        (* state *)
        // Ret.u Ret.text to_compute_node_state
        (* created_at *)
        // Ret.text
        (* updated_at *)
        // Ret.text
        /^ read [%blob "sql/insert_compute_node.sql"]
        /% Var.uuid "id"
        /% Var.(ud (json "capabilities") Tjc.Compute_node.Capabilities.to_yojson))

    let select_compute_node () =
      Pgsql_io.Typed_sql.(
        sql
        //
        (* id *)
        Ret.uuid
        //
        (* state *)
        Ret.u Ret.text to_compute_node_state
        //
        (* capabilities *)
        Ret.u Ret.json to_capabilities
        //
        (* created_at *)
        Ret.text
        //
        (* updated_at *)
        Ret.text
        /^ read [%blob "sql/select_compute_node.sql"]
        /% Var.uuid "id")

    let state_of_string =
      let module S = Tjc.Compute_node_work.State in
      function
      | "created" -> Some S.Created
      | "completed" -> Some S.Completed
      | "aborted" -> Some S.Aborted
      | _ -> None

    let work_of_json = CCFun.(Terrat_api_components.Work_manifest.of_yojson %> CCResult.to_opt)

    let select_compute_node_work =
      Pgsql_io.Typed_sql.(
        sql
        //
        (* created_at *)
        Ret.text
        //
        (* state *)
        Ret.(u text state_of_string)
        //
        (* work *)
        Ret.(u json work_of_json)
        //
        (* work_manifest *)
        Ret.uuid
        /^ read [%blob "sql/select_compute_node_work.sql"]
        /% Var.uuid "compute_node_id")

    let string_of_state =
      let module S = Tjc.Compute_node.State in
      function
      | S.Starting -> "starting"
      | S.Running -> "running"
      | S.Terminated -> "terminated"

    let update_compute_node_state =
      Pgsql_io.Typed_sql.(
        sql
        /^ read [%blob "sql/update_compute_node_state.sql"]
        /% Var.uuid "compute_node_id"
        /% Var.(ud (text "state") string_of_state))

    let upsert_compute_node_work =
      Pgsql_io.Typed_sql.(
        sql
        /^ read [%blob "sql/upsert_compute_node_work.sql"]
        /% Var.uuid "compute_node_id"
        /% Var.uuid "work_manifest"
        /% Var.ud (Var.json "work") Terrat_api_components.Work_manifest.to_yojson)
  end

  let create_or_get_for_pull_request ~request_id db _account repo pull_request_id =
    let run =
      let open Abbs_future_combinators.Infix_result_monad in
      Pgsql_io.Prepared_stmt.fetch
        db
        Sql.select_or_insert_pull_request_context
        ~f:(fun id created_at updated_at -> (id, created_at, updated_at))
        (CCInt64.of_int @@ Api.Repo.id repo)
        (CCInt64.of_int @@ pull_request_id)
      >>= function
      | [] -> assert false
      | (id, created_at, updated_at) :: _ ->
          Abb.Future.return
            (Ok
               {
                 Tjc.Context.created_at;
                 id;
                 scope = Tjc.Context.Scope.Pull_request pull_request_id;
                 updated_at;
               })
    in
    let open Abb.Future.Infix_monad in
    run
    >>= function
    | Ok _ as ret -> Abb.Future.return ret
    | Error (#Pgsql_io.err as err) ->
        Logs.err (fun m ->
            m
              "%s : JOB_CONTEXT : CREATE_OR_GET_FOR_PULL_REQUEST : %a"
              request_id
              Pgsql_io.pp_err
              err);
        Abb.Future.return (Error `Error)

  let create_or_get_for_branch ~request_id db _account repo branch =
    let run =
      let open Abbs_future_combinators.Infix_result_monad in
      Pgsql_io.Prepared_stmt.fetch
        db
        Sql.select_or_insert_branch_context
        ~f:(fun id created_at updated_at -> (id, created_at, updated_at))
        (CCInt64.of_int @@ Api.Repo.id repo)
        (Api.Ref.to_string branch)
      >>= function
      | [] -> assert false
      | (id, created_at, updated_at) :: _ ->
          Abb.Future.return
            (Ok
               {
                 Tjc.Context.created_at;
                 id;
                 scope = Tjc.Context.Scope.Branch (branch, None);
                 updated_at;
               })
    in
    let open Abb.Future.Infix_monad in
    run
    >>= function
    | Ok _ as ret -> Abb.Future.return ret
    | Error (#Pgsql_io.err as err) ->
        Logs.err (fun m ->
            m "%s : JOB_CONTEXT : CREATE_OR_GET_FOR_BRANCH : %a" request_id Pgsql_io.pp_err err);
        Abb.Future.return (Error `Error)

  let query ~request_id db id =
    let open Abb.Future.Infix_monad in
    Pgsql_io.Prepared_stmt.fetch
      db
      Sql.select_context_by_id
      ~f:(fun created_at scope updated_at ->
        { Terrat_job_context.Context.created_at; id; scope; updated_at })
      id
    >>= function
    | Ok r -> Abb.Future.return (Ok (CCOption.of_list r))
    | Error (#Pgsql_io.err as err) ->
        Logs.err (fun m -> m "%s : CONTEXT : QUERY : %a" request_id Pgsql_io.pp_err err);
        Abb.Future.return (Error `Error)

  module Job = struct
    let query_context = query

    let create ~request_id db type_ context initiator =
      let run =
        let open Abbs_future_combinators.Infix_result_monad in
        Pgsql_io.Prepared_stmt.fetch
          db
          Sql.insert_job
          ~f:(fun id created_at updated_at -> (id, created_at, updated_at))
          context.Tjc.Context.id
          Tjc.Job.State.Running
          type_
          initiator
        >>= function
        | [] -> assert false
        | (id, created_at, _updated_at) :: _ ->
            Abb.Future.return
              (Ok
                 {
                   Tjc.Job.completed_at = None;
                   context;
                   created_at;
                   id;
                   initiator;
                   state = Tjc.Job.State.Running;
                   type_;
                   updated_at = created_at;
                 })
      in
      let open Abb.Future.Infix_monad in
      run
      >>= function
      | Ok _ as r -> Abb.Future.return r
      | Error (#Pgsql_io.err as err) ->
          Logs.err (fun m -> m "%s : JOB : CREATE : %a" request_id Pgsql_io.pp_err err);
          Abb.Future.return (Error `Error)

    let query ~request_id db ~job_id =
      let run =
        let open Abbs_future_combinators.Infix_result_monad in
        Pgsql_io.Prepared_stmt.fetch
          db
          Sql.select_job_by_id
          ~f:(fun id context_id type_ state initiator created_at updated_at completed_at ->
            (id, context_id, type_, state, initiator, created_at, updated_at, completed_at))
          job_id
        >>= function
        | [] -> Abb.Future.return (Ok None)
        | (id, context_id, type_, state, initiator, created_at, updated_at, completed_at) :: _ -> (
            query_context ~request_id db context_id
            >>= function
            | None -> assert false
            | Some context ->
                let module J = Terrat_job_context.Job in
                Abb.Future.return
                  (Ok
                     (Some
                        {
                          J.completed_at;
                          context;
                          created_at;
                          id;
                          initiator;
                          state;
                          type_;
                          updated_at;
                        })))
      in
      let open Abb.Future.Infix_monad in
      run
      >>= function
      | Ok _ as r -> Abb.Future.return r
      | Error `Error -> Abb.Future.return (Error `Error)
      | Error (#Pgsql_io.err as err) ->
          Logs.err (fun m -> m "%s : JOB : QUERY : %a" request_id Pgsql_io.pp_err err);
          Abb.Future.return (Error `Error)

    let query_all_by_context_id ~request_id:_ _db ~context_id:_ () = raise (Failure "nyi")
    let query_pending_by_context_id ~request_id:_ _db ~context_id:_ () = raise (Failure "nyi")

    let query_by_work_manifest_id ~request_id db ~work_manifest_id () =
      let run =
        let open Abbs_future_combinators.Infix_result_monad in
        Pgsql_io.Prepared_stmt.fetch
          db
          Sql.select_job_by_work_manifest_id
          ~f:(fun id context_id type_ state initiator created_at updated_at completed_at ->
            (id, context_id, type_, state, initiator, created_at, updated_at, completed_at))
          work_manifest_id
        >>= function
        | [] -> Abb.Future.return (Ok None)
        | (id, context_id, type_, state, initiator, created_at, updated_at, completed_at) :: _ -> (
            query_context ~request_id db context_id
            >>= function
            | None -> assert false
            | Some context ->
                let module J = Terrat_job_context.Job in
                Abb.Future.return
                  (Ok
                     (Some
                        {
                          J.completed_at;
                          context;
                          created_at;
                          id;
                          initiator;
                          state;
                          type_;
                          updated_at;
                        })))
      in
      let open Abb.Future.Infix_monad in
      run
      >>= function
      | Ok _ as r -> Abb.Future.return r
      | Error `Error -> Abb.Future.return (Error `Error)
      | Error (#Pgsql_io.err as err) ->
          Logs.err (fun m -> m "%s : JOB : QUERY : %a" request_id Pgsql_io.pp_err err);
          Abb.Future.return (Error `Error)

    let update_state ~request_id db ~job_id state =
      let open Abb.Future.Infix_monad in
      Pgsql_io.Prepared_stmt.execute db Sql.update_job_state job_id state
      >>= function
      | Ok () -> Abb.Future.return (Ok ())
      | Error (#Pgsql_io.err as err) ->
          Logs.err (fun m -> m "%s : JOB : UPDATE_STATE : %a" request_id Pgsql_io.pp_err err);
          Abb.Future.return (Error `Error)

    let add_work_manifest ~request_id db ~job_id ~work_manifest_id () =
      let open Abb.Future.Infix_monad in
      Pgsql_io.Prepared_stmt.execute db Sql.upsert_job_work_manifest job_id work_manifest_id
      >>= function
      | Ok () -> Abb.Future.return (Ok ())
      | Error (#Pgsql_io.err as err) ->
          Logs.err (fun m -> m "%s : JOB : ADD_WORK_MANIFEST : %a" request_id Pgsql_io.pp_err err);
          Abb.Future.return (Error `Error)

    let query_work_manifests ~request_id db ~job_id () =
      let run =
        let open Abbs_future_combinators.Infix_result_monad in
        Pgsql_io.Prepared_stmt.fetch db Sql.select_job_work_manifests ~f:CCFun.id job_id
        >>= fun work_manifests -> Work_manifest.query' ~request_id db work_manifests
      in
      let open Abb.Future.Infix_monad in
      run
      >>= function
      | Ok _ as r -> Abb.Future.return r
      | Error `Error -> Abb.Future.return (Error `Error)
      | Error (#Pgsql_io.err as err) ->
          Logs.err (fun m ->
              m "%s : JOB : QUERY_WORK_MANIFESTS : %a" request_id Pgsql_io.pp_err err);
          Abb.Future.return (Error `Error)
  end

  module Compute_node = struct
    let create ~request_id ~id ~capabilities db =
      let open Abb.Future.Infix_monad in
      Pgsql_io.Prepared_stmt.fetch
        db
        (Sql.insert_compute_node ())
        ~f:(fun state created_at updated_at -> (state, created_at, updated_at))
        id
        capabilities
      >>= function
      | Ok [] -> assert false
      | Ok ((state, created_at, updated_at) :: _) ->
          Abb.Future.return
            (Ok { Tjc.Compute_node.id; state; capabilities; created_at; updated_at })
      | Error (#Pgsql_io.err as err) ->
          Logs.err (fun m -> m "%s : COMPUTE_NODE : CREATE : %a" request_id Pgsql_io.pp_err err);
          Abb.Future.return (Error `Error)

    let query ~request_id ~compute_node_id db =
      let open Abb.Future.Infix_monad in
      Pgsql_io.Prepared_stmt.fetch
        db
        (Sql.select_compute_node ())
        ~f:(fun id state capabilities created_at updated_at ->
          { Tjc.Compute_node.id; state; capabilities; created_at; updated_at })
        compute_node_id
      >>= function
      | Ok [] -> Abb.Future.return (Ok None)
      | Ok (compute_node :: _) -> Abb.Future.return (Ok (Some compute_node))
      | Error (#Pgsql_io.err as err) ->
          Logs.err (fun m -> m "%s : COMPUTE_NODE : CREATE : %a" request_id Pgsql_io.pp_err err);
          Abb.Future.return (Error `Error)

    let query_work ~request_id ~compute_node_id db =
      let open Abb.Future.Infix_monad in
      Pgsql_io.Prepared_stmt.fetch
        db
        Sql.select_compute_node_work
        ~f:(fun created_at state work work_manifest ->
          { Tjc.Compute_node_work.compute_node_id; created_at; state; work; work_manifest })
        compute_node_id
      >>= function
      | Ok r -> Abb.Future.return (Ok (CCOption.of_list r))
      | Error (#Pgsql_io.err as err) ->
          Logs.err (fun m -> m "%s : COMPUTE_NODE : QUERY_WORK : %a" request_id Pgsql_io.pp_err err);
          Abb.Future.return (Error `Error)

    let update_state ~request_id ~compute_node_id db state =
      let open Abb.Future.Infix_monad in
      Pgsql_io.Prepared_stmt.execute db Sql.update_compute_node_state compute_node_id state
      >>= function
      | Ok () -> Abb.Future.return (Ok ())
      | Error (#Pgsql_io.err as err) ->
          Logs.err (fun m ->
              m "%s : COMPUTE_NODE : UPDATE_STATE : %a" request_id Pgsql_io.pp_err err);
          Abb.Future.return (Error `Error)

    let set_work ~request_id ~compute_node_id ~work_manifest db work =
      let open Abb.Future.Infix_monad in
      Pgsql_io.Prepared_stmt.execute
        db
        Sql.upsert_compute_node_work
        compute_node_id
        work_manifest
        work
      >>= function
      | Ok () -> Abb.Future.return (Ok ())
      | Error (#Pgsql_io.err as err) ->
          Logs.err (fun m ->
              m "%s : COMPUTE_NODE : UPDATE_STATE : %a" request_id Pgsql_io.pp_err err);
          Abb.Future.return (Error `Error)
  end
end
