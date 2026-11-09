module Dirspace_map = Terrat_data.Dirspace_map
module Dirspace_set = Terrat_data.Dirspace_set

module Run = struct
  type t = {
    sha : string;
    created_at : string;
    during : (string * string) list;
  }
  [@@deriving eq, ord, show]
end

module Kind = struct
  type t =
    | Plan
    | Apply
  [@@deriving eq, show]
end

module Plan = struct
  type t = {
    run : Run.t;
    has_changes : bool;
  }
  [@@deriving eq, show]
end

module Dirspace_state = struct
  type t = {
    dirspace : Terrat_dirspace.t;
    last_plan : Plan.t option;
    last_apply : Run.t option;
  }
  [@@deriving eq, show]
end

module Selection = struct
  type t = {
    to_run : Terrat_dirspace.t list;
    out_of_order : Terrat_dirspace.t list;
    applied : Terrat_dirspace.t list;
  }
  [@@deriving eq, show]
end

let later a b = if CCString.compare a b >= 0 then a else b

(* Each time this dirspace has a run recorded for, whether that run is still good or not.  The
   order of the runs is about when a run happened, thus a run which the files made out of date
   still counts here. *)
let times_of_state { Dirspace_state.dirspace = _; last_plan; last_apply } =
  CCList.filter_map
    CCFun.id
    [
      CCOption.map
        (fun { Plan.run = { Run.sha = _; created_at; during = _ }; has_changes = _ } -> created_at)
        last_plan;
      CCOption.map (fun { Run.sha = _; created_at; during = _ } -> created_at) last_apply;
    ]

(* The most recent run of each dirspace. *)
let times_of_states states =
  CCList.fold_left
    (fun acc ({ Dirspace_state.dirspace; last_plan = _; last_apply = _ } as state) ->
      CCList.fold_left
        (fun acc created_at ->
          Dirspace_map.update
            dirspace
            (fun current -> Some (CCOption.map_or ~default:created_at (later created_at) current))
            acc)
        acc
        (times_of_state state))
    Dirspace_map.empty
    states

(* The most recent run of any dirspace that [dirspace] waits for. *)
let time_of_dependencies ~depends_on ~times dirspace =
  Dirspace_set.fold
    (fun dependency acc ->
      CCOption.map_or
        ~default:acc
        (fun created_at -> Some (CCOption.map_or ~default:created_at (later created_at) acc))
        (Dirspace_map.find_opt dependency times))
    (depends_on dirspace)
    None

let dirspaces_of states =
  states
  |> CCList.map (fun { Dirspace_state.dirspace; last_plan = _; last_apply = _ } -> dirspace)
  |> CCList.sort_uniq ~cmp:Terrat_dirspace.compare

let select ~changed_since ~changed_between ~force ~superseded ~last_run_failed ~depends_on states =
  let times = times_of_states states in
  (* A run is good when its dirspace is not superseded, did not change since the run, and did not
     change while the run operated. *)
  let is_good kind dirspace ({ Run.sha = _; created_at = _; during } as run) =
    (not (Dirspace_set.mem dirspace superseded))
    && (not (Dirspace_set.mem dirspace (changed_since kind run)))
    && not
         (CCList.exists
            (fun (from_sha, to_sha) -> Dirspace_set.mem dirspace (changed_between from_sha to_sha))
            during)
  in
  (* A run must not be older than a run of a dirspace it waits for, or the order of the tree is
     broken and this dirspace must run again.  Only the dirspaces it waits for count: a dirspace of
     another branch of the tree runs whenever the user asks for it, and that says nothing about
     this one. *)
  let stands_in_dependency_order dirspace { Run.sha = _; created_at; during = _ } =
    CCOption.for_all
      (fun before -> CCString.compare created_at before >= 0)
      (time_of_dependencies ~depends_on ~times dirspace)
  in
  (* An apply which is not older than a plan used that plan.  When the apply is not good, the plan
     is used up with it: the dirspace must be planned again, and not applied again from the same
     plan. *)
  let used_up_by_bad_apply dirspace { Run.sha = _; created_at = planned_at; during = _ } last_apply
      =
    CCOption.exists
      (fun ({ Run.sha = _; created_at = applied_at; during = _ } as apply) ->
        CCString.compare applied_at planned_at >= 0 && not (is_good Kind.Apply dirspace apply))
      last_apply
  in
  let plan_is_good dirspace last_apply run =
    is_good Kind.Plan dirspace run && not (used_up_by_bad_apply dirspace run last_apply)
  in
  (* The plan which is good for the files of its dirspace, whatever the runs of the dirspaces it
     waits for. *)
  let good_own_plan { Dirspace_state.dirspace; last_plan; last_apply } =
    last_plan
    |> CCOption.map (fun { Plan.run; has_changes = _ } -> run)
    |> CCOption.filter (plan_is_good dirspace last_apply)
  in
  (* The plan which still stands, thus the dirspace needs no new one. *)
  let good_plan ({ Dirspace_state.dirspace; last_plan = _; last_apply = _ } as state) =
    CCOption.filter (stands_in_dependency_order dirspace) (good_own_plan state)
  in
  (* The run which makes the dirspace applied.  A plan which found no changes counts, because
     there is nothing to apply. *)
  let applied_run ({ Dirspace_state.dirspace; last_plan; last_apply } as state) =
    (* A plan made after the apply is work which nobody applied yet.  A stale apply falls through
       to the test below, thus a newer plan which found no changes still counts as applied. *)
    let stands_after_plan { Run.sha = _; created_at; during = _ } =
      CCOption.for_all
        (fun { Run.sha = _; created_at = planned_at; during = _ } ->
          CCString.compare created_at planned_at >= 0)
        (good_plan state)
    in
    last_apply
    |> CCOption.filter (fun run -> is_good Kind.Apply dirspace run && stands_after_plan run)
    |> CCOption.or_lazy ~else_:(fun () ->
        last_plan
        |> CCOption.filter (fun { Plan.run; has_changes } ->
            (not has_changes) && plan_is_good dirspace last_apply run)
        |> CCOption.map (fun { Plan.run; has_changes = _ } -> run))
  in
  (* A force on a dirspace takes the applied state from that dirspace and from every dirspace that
     waits for it, because the run they hold is the run the force replaces. *)
  let force_reaches dirspace =
    Dirspace_set.mem dirspace force
    || Dirspace_set.exists (CCFun.flip Dirspace_set.mem force) (depends_on dirspace)
  in
  let is_applied ({ Dirspace_state.dirspace; last_plan = _; last_apply = _ } as state) =
    CCOption.exists
      (fun run -> (not (force_reaches dirspace)) && stands_in_dependency_order dirspace run)
      (applied_run state)
  in
  (* [is_applied] comes first, thus a dirspace of one list is never in the other.  The force is
     already outside this test: [force_reaches] takes the applied state away from the dirspace it
     names and from every dirspace that waits for it. *)
  let must_run ({ Dirspace_state.dirspace; last_plan = _; last_apply = _ } as state) =
    (not (is_applied state))
    && (Dirspace_set.mem dirspace force
       || Dirspace_set.mem dirspace last_run_failed
       || CCOption.is_none (good_plan state))
  in
  (* A dirspace that must run while its own plan is good must run only because a dirspace it waits
     for ran after that plan: [force] and [last_run_failed] are the other two causes. *)
  let out_of_order ({ Dirspace_state.dirspace; last_plan = _; last_apply = _ } as state) =
    must_run state
    && (not (Dirspace_set.mem dirspace force))
    && (not (Dirspace_set.mem dirspace last_run_failed))
    && CCOption.is_some (good_own_plan state)
  in
  {
    Selection.to_run = dirspaces_of (CCList.filter must_run states);
    out_of_order = dirspaces_of (CCList.filter out_of_order states);
    applied = dirspaces_of (CCList.filter is_applied states);
  }

let without_in_progress ~in_progress ~force selection =
  let keep dirspace =
    Dirspace_set.mem dirspace force
    || not
         (CCList.exists
            (fun (in_progress_dirspace, changed) ->
              Terrat_dirspace.equal in_progress_dirspace dirspace
              && not (Dirspace_set.mem dirspace changed))
            in_progress)
  in
  Dirspace_set.of_list (CCList.filter keep selection.Selection.to_run)
