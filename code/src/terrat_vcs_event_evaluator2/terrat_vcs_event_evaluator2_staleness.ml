type t =
  | Not_impacted
  | Impacted of Terrat_dirspace.t list
  | Unknown
[@@deriving eq, show]

let decide ~changed dirspaces =
  CCOption.map_or
    ~default:Unknown
    (fun changed ->
      match
        dirspaces
        |> CCList.filter (CCFun.flip Terrat_data.Dirspace_set.mem changed)
        |> CCList.sort_uniq ~cmp:Terrat_dirspace.compare
      with
      | [] -> Not_impacted
      | impacted -> Impacted impacted)
    changed

let union a b =
  match (a, b) with
  | Unknown, (Not_impacted | Impacted _ | Unknown) | (Not_impacted | Impacted _), Unknown -> Unknown
  | Impacted a, Impacted b -> Impacted (CCList.sort_uniq ~cmp:Terrat_dirspace.compare (a @ b))
  | Impacted impacted, Not_impacted | Not_impacted, Impacted impacted -> Impacted impacted
  | Not_impacted, Not_impacted -> Not_impacted

module Start = struct
  type decision =
    | Run
    | Restart
  [@@deriving eq, show]

  let decide = function
    | Impacted _ | Unknown -> Restart
    | Not_impacted -> Run

  (* [created_at] has a fixed width, thus the order of two strings is the order of two times.  The work
     manifests of one creation have the same time, thus only the dirspaces can cover an abort among
     them. *)
  let uncovered_dirspaces ~live aborted =
    let dirspaces wms =
      wms
      |> CCList.flat_map (fun wm ->
          CCList.map
            (fun change -> change.Terrat_change.Dirspaceflow.dirspace)
            wm.Terrat_work_manifest3.changes)
      |> Terrat_data.Dirspace_set.of_list
    in
    let newer_live wm =
      CCList.exists
        (fun live_wm ->
          CCString.compare
            live_wm.Terrat_work_manifest3.created_at
            wm.Terrat_work_manifest3.created_at
          > 0)
        live
    in
    Terrat_data.Dirspace_set.diff
      (dirspaces (CCList.filter (fun wm -> not (newer_live wm)) aborted))
      (dirspaces live)
end

module Pr_result = struct
  type decision =
    | Fresh
    | Stale_files_changed of Terrat_dirspace.t list
    | Stale_files_unknown
  [@@deriving eq, show]

  let decide = function
    | Not_impacted -> Fresh
    | Impacted dirspaces -> Stale_files_changed dirspaces
    | Unknown -> Stale_files_unknown

  let stale_dirspaces decision dirspaces =
    match decision with
    | Fresh -> Terrat_data.Dirspace_set.empty
    | Stale_files_changed changed -> Terrat_data.Dirspace_set.of_list changed
    | Stale_files_unknown -> Terrat_data.Dirspace_set.of_list dirspaces
end

module Drift_result = struct
  type decision =
    | Resolved
    | Reconcile_again
  [@@deriving eq, show]

  let decide = function
    | Impacted _ | Unknown -> Reconcile_again
    | Not_impacted -> Resolved

  type restart =
    | Restart
    | Limit_reached
    | Disabled
  [@@deriving eq, show]

  let restart_limit = 10

  let restart ~restart_on_change ~restarts =
    if not restart_on_change then Disabled
    else if restarts < restart_limit then Restart
    else Limit_reached
end

module Summary = struct
  module Ds = Terrat_vcs_provider2.Dirspace_summary

  let decide ~applied ~planned ~failed dirspace =
    let mem = Terrat_data.Dirspace_set.mem dirspace in
    if mem failed then Some Ds.Failed
    else if mem applied then Some Ds.Applied
    else if mem planned then Some Ds.Planned
    else None

  let of_result ~run ~stale ~no_changes dirspace success =
    match (success, Terrat_data.Dirspace_set.mem dirspace stale, run) with
    | false, _, _ -> Ds.Failed
    | true, true, _ -> Ds.Stale
    | true, false, `Apply -> Ds.Applied
    | true, false, `Plan ->
        if Terrat_data.Dirspace_set.mem dirspace no_changes then Ds.Applied else Ds.Planned
end
