module Dc = Terrat_change_match3.Dirspace_config
module Dirspace_set = Terrat_data.Dirspace_set

module Op = struct
  type t =
    | Apply
    | Drift_plan
    | Explicit_plan
    | Layer_plan
end

type t = {
  working_set_matches : Dc.t list;
  all_unapplied_matches : Dc.t list list;
  working_layer : Dc.t list;
  pruned : Dirspace_set.t;
}

let dirspaces_of =
  CCList.map
    (fun
      {
        Dc.dirspace;
        file_pattern_matcher = _;
        lock_branch_target = _;
        stack_config = _;
        stack_name = _;
        stack_paths = _;
        tags = _;
        when_modified = _;
      }
    -> dirspace)

let head_set layers =
  Dirspace_set.of_list @@ dirspaces_of @@ CCOption.get_or ~default:[] (CCList.head_opt layers)

(* A dirspace may not apply while an unapplied dirspace of a stack it lists in
   [apply_after] is still in the run.  The test is against the whole run and not
   against the layer, because the stack it waits for can be anywhere in the
   run. *)
let apply_after_is_satisfied
    ~remaining
    {
      Dc.stack_config;
      dirspace = _;
      file_pattern_matcher = _;
      lock_branch_target = _;
      stack_name = _;
      stack_paths = _;
      tags = _;
      when_modified = _;
    } =
  let module S = Terrat_base_repo_config_v1.Stacks.Stack in
  let module Rules = Terrat_base_repo_config_v1.Stacks.Rules in
  let {
    S.rules = { Rules.apply_after; auto_apply = _; modified_by = _; plan_after = _ };
    type_ = _;
    variables = _;
  } =
    stack_config
  in
  not
    (CCList.exists
       (fun {
              Dc.stack_name;
              dirspace = _;
              file_pattern_matcher = _;
              lock_branch_target = _;
              stack_config = _;
              stack_paths = _;
              tags = _;
              when_modified = _;
            }
          -> CCList.mem ~eq:CCString.equal stack_name apply_after)
       remaining)

let dirspace_uses_outputs
    {
      Dc.when_modified =
        {
          Terrat_base_repo_config_v1.When_modified.autoapply = _;
          autoplan = _;
          autoplan_draft_pr = _;
          depends_on;
          file_patterns = _;
          prechecks = _;
        };
      dirspace = _;
      file_pattern_matcher = _;
      lock_branch_target = _;
      stack_config = _;
      stack_name = _;
      stack_paths = _;
      tags = _;
    } =
  CCOption.map_or
    ~default:false
    (fun { Terrat_base_repo_config_v1.Depends_on.tag_query; prune_on_no_change = _ } ->
      Terrat_tag_query.uses_outputs tag_query)
    depends_on

let uses_outputs all_matches = CCList.exists dirspace_uses_outputs (CCList.flatten all_matches)

(* [reachable] takes the outputs of one dependency or nothing at all, so [`Unchanged] is written
   as a comparison of two absent sides: no path in it differs, which is what makes an [outputs:]
   term false.  Nothing at all keeps the [dir:] meaning of the term. *)
let outputs_for_walk ~outputs ~applied dirspace =
  if Dirspace_set.mem dirspace applied then
    match outputs dirspace with
    | `Diff diff -> Some diff
    | `Unchanged ->
        Some { Terrat_output_diff.shape = Terrat_output_diff.Raw; baseline = None; current = None }
    | `No_comparison -> None
  else None

(* Walk the run again from its roots, this time with the outputs of the applied dirspaces, and keep
   only what the walk reaches.  The roots are the dirspaces whose own files changed and the revived
   dirspaces of the run.  A revived dirspace outside the run is not a root, or it could bring its
   dependents into the run.  A run with no [outputs:] term skips the walk, because the walk cannot
   remove anything from it. *)
let prune_unchanged_outputs ~outputs ~file_changed ~revived ~config ~applied all_matches =
  match uses_outputs all_matches with
  | false -> (all_matches, Dirspace_set.empty)
  | true ->
      let in_run = Dirspace_set.of_list (dirspaces_of (CCList.flatten all_matches)) in
      let roots =
        CCList.filter_map
          (Terrat_change_match3.of_dirspace config)
          (Dirspace_set.to_list
             (Dirspace_set.union file_changed (Dirspace_set.inter revived in_run)))
      in
      let reached =
        Terrat_change_match3.reachable ~outputs:(outputs_for_walk ~outputs ~applied) config ~roots
      in
      all_matches
      |> CCList.map
           (CCList.filter
              (fun
                {
                  Dc.dirspace;
                  file_pattern_matcher = _;
                  lock_branch_target = _;
                  stack_config = _;
                  stack_name = _;
                  stack_paths = _;
                  tags = _;
                  when_modified = _;
                }
              -> Dirspace_set.mem dirspace reached))
      |> CCList.filter (function
        | [] -> false
        | _ :: _ -> true)
      |> fun pruned_matches ->
      ( pruned_matches,
        Dirspace_set.diff
          in_run
          (Dirspace_set.of_list (dirspaces_of (CCList.flatten pruned_matches))) )

let make ~outputs ~file_changed ~revived ~config ~op ~tag_query ~applied ~dir_exists ~all_matches =
  let all_matches, pruned =
    prune_unchanged_outputs ~outputs ~file_changed ~revived ~config ~applied all_matches
  in
  let matching = CCList.filter (Terrat_change_match3.match_tag_query ~tag_query) in
  (* A directory that is gone cannot run, and it cannot hold anything back
     either, so it leaves by the same door as an applied dirspace. *)
  let present =
    CCList.filter
      (fun {
             Dc.dirspace = { Terrat_dirspace.dir; workspace = _ };
             file_pattern_matcher = _;
             lock_branch_target = _;
             stack_config = _;
             stack_name = _;
             stack_paths = _;
             tags = _;
             when_modified = _;
           }
         -> dir_exists dir)
      (CCList.flatten all_matches)
  in
  let unapplied, already_applied =
    CCList.partition
      (fun {
             Dc.dirspace;
             file_pattern_matcher = _;
             lock_branch_target = _;
             stack_config = _;
             stack_name = _;
             stack_paths = _;
             tags = _;
             when_modified = _;
           }
         -> not (Dirspace_set.mem dirspace applied))
      present
  in
  let all_unapplied_matches = Terrat_change_match3.layers_of config unapplied in
  let working_layer = CCOption.get_or ~default:[] (CCList.head_opt all_unapplied_matches) in
  let working_set_matches =
    match all_unapplied_matches with
    | _ :: _ -> (
        match op with
        | Op.Apply ->
            working_layer
            |> matching
            |> CCList.filter (apply_after_is_satisfied ~remaining:unapplied)
        | Op.Drift_plan -> matching (CCList.flatten all_matches)
        | Op.Explicit_plan ->
            (* An applied dirspace cannot break the order, so the user may name
               one and have it planned again.  Without this a dirspace whose
               last plan found no changes could never be re-planned on its
               own. *)
            matching (working_layer @ already_applied)
        | Op.Layer_plan -> matching working_layer)
    | [] -> (
        (* Nothing is unapplied.  An explicit query is still a request:
           everything it names has been applied or planned clean, so re-planning
           any of it cannot violate the order. *)
        match op with
        | Op.Explicit_plan -> matching (CCList.flatten all_matches)
        | Op.Apply | Op.Drift_plan | Op.Layer_plan -> [])
  in
  { working_set_matches; all_unapplied_matches; working_layer; pruned }

let next_round_ready ~config ~all_unapplied_matches ~just_ran =
  let remaining = CCList.flatten all_unapplied_matches in
  let remaining_set = Dirspace_set.of_list (dirspaces_of remaining) in
  (* The run as it was before this work manifest: what remains, plus whatever it
     covered and took out. *)
  let before =
    remaining
    @ CCList.filter_map
        (fun dirspace ->
          if Dirspace_set.mem dirspace remaining_set then None
          else Terrat_change_match3.of_dirspace config dirspace)
        just_ran
  in
  not
    (Dirspace_set.is_empty
       (Dirspace_set.diff
          (head_set all_unapplied_matches)
          (head_set (Terrat_change_match3.layers_of config before))))
