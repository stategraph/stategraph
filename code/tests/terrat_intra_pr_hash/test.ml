(* Tests for the rules which decide, on a push to a pull request, which dirspaces run again and
   which dirspaces keep the result of an earlier run.

   Every test names its dirspaces by directory only, and every dirspace uses the "default"
   workspace, thus an assertion is a comparison of two lists of directory names. *)

module Ipr = Terrat_intra_pr_hash

(* The head sha of the pull request now.  A run at this sha is always good, because a tree cannot
   differ from itself. *)
let head = "head"
let ds dir = { Terrat_dirspace.dir; workspace = "default" }
let dirs_of = CCList.map (fun { Terrat_dirspace.dir; workspace = _ } -> dir)
let dirspace_set dirs = Terrat_data.Dirspace_set.of_list (CCList.map ds dirs)

(* [~ls] is a chain of layers, as the tests of the layer order were written: each layer waits for
   every layer before it.  [depends_on] takes each dirspace to the dirspaces it waits for, which is
   what the rule asks (RFD 2305: a run is a tree).  [tree_depends_on] builds one branch per list, so
   two branches wait for nothing of each other. *)
let depends_on_of ls dirspace =
  let rec go seen = function
    | [] -> Terrat_data.Dirspace_set.empty
    | layer :: rest ->
        if CCList.mem ~eq:CCString.equal dirspace.Terrat_dirspace.dir layer then
          Terrat_data.Dirspace_set.of_list (CCList.map ds seen)
        else go (seen @ layer) rest
  in
  go [] ls

let tree_depends_on branches dirspace =
  let rec go seen = function
    | [] -> None
    | dir :: rest ->
        if CCString.equal dir dirspace.Terrat_dirspace.dir then
          Some (Terrat_data.Dirspace_set.of_list (CCList.map ds seen))
        else go (seen @ [ dir ]) rest
  in
  branches
  |> CCList.filter_map (go [])
  |> CCList.fold_left Terrat_data.Dirspace_set.union Terrat_data.Dirspace_set.empty

(* [during] is the pairs of commits that moved while the run operated (RFD 2356). *)
let run ?(during = []) ~sha ~created_at () = { Ipr.Run.sha; created_at; during }

let plan ?(has_changes = true) ?during ~sha ~created_at () =
  { Ipr.Plan.run = run ?during ~sha ~created_at (); has_changes }

let state ?last_plan ?last_apply dir =
  { Ipr.Dirspace_state.dirspace = ds dir; last_plan; last_apply }

(* [changes] is a list of (sha, the directories which changed between that sha and the head).  A
   sha which is absent has no change. *)
let changed_dirspaces changes sha =
  changes |> Sln_list.String.assoc_opt sha |> CCOption.get_or ~default:[] |> dirspace_set

(* [between] is a list of ((from, to), the directories which changed between the two commits).  A
   pair which is absent has no change. *)
let changed_between between from_sha to_sha =
  between
  |> CCList.assoc_opt
       ~eq:(fun (a_from, a_to) (b_from, b_to) ->
         CCString.equal a_from b_from && CCString.equal a_to b_to)
       (from_sha, to_sha)
  |> CCOption.get_or ~default:[]
  |> dirspace_set

(* A run of an open pull request is compared with its head whatever its kind.  [~merged] is the
   shape of a merged pull request: its applies at the destination have no comparison since they
   ran. *)
let changed_since ~merged changes kind { Ipr.Run.sha; created_at = _; during = _ } =
  match (kind, merged) with
  | Ipr.Kind.Apply, true -> Terrat_data.Dirspace_set.empty
  | Ipr.Kind.Apply, false | Ipr.Kind.Plan, (true | false) -> changed_dirspaces changes sha

let select
    ?(changes = [])
    ?(between = [])
    ?(merged = false)
    ?(force = [])
    ?(superseded = [])
    ?(last_run_failed = [])
    ?(ls = [])
    states =
  Ipr.select
    ~changed_since:(changed_since ~merged changes)
    ~changed_between:(changed_between between)
    ~force:(dirspace_set force)
    ~superseded:(dirspace_set superseded)
    ~last_run_failed:(dirspace_set last_run_failed)
    ~depends_on:(depends_on_of ls)
    states

let assert_to_run ~expected { Ipr.Selection.to_run; out_of_order = _; applied = _ } =
  Oth.Assert.Eq.string_list ~expected ~actual:(dirs_of to_run)

let assert_out_of_order ~expected { Ipr.Selection.to_run = _; out_of_order; applied = _ } =
  Oth.Assert.Eq.string_list ~expected ~actual:(dirs_of out_of_order)

let assert_applied ~expected { Ipr.Selection.to_run = _; out_of_order = _; applied } =
  Oth.Assert.Eq.string_list ~expected ~actual:(dirs_of applied)

(* The answer of [without_in_progress] is the dirspaces to plan, not a selection. *)
let assert_planned ~expected planned =
  Oth.Assert.Eq.string_list ~expected ~actual:(dirs_of (Terrat_data.Dirspace_set.elements planned))

(* -- Autoplan filtering -- *)

let test_no_plan_runs =
  Oth.test ~name:"autoplan: a dirspace with no plan runs" (fun _ ->
      let selection = select [ state "ds_one" ] in
      assert_to_run ~expected:[ "ds_one" ] selection;
      assert_applied ~expected:[] selection;
      ())

(* A failed plan is not a successful plan, thus [last_plan] holds the run before the failure.  That
   run is at the sha from before the change which the user pushed, thus its files are different now
   and the dirspace runs. *)
let test_failed_plan_runs =
  Oth.test ~name:"autoplan: a dirspace whose last plan failed runs" (fun _ ->
      let selection =
        select
          ~changes:[ ("old", [ "ds_one" ]) ]
          [ state "ds_one" ~last_plan:(plan ~sha:"old" ~created_at:"2026-09-11T10:00:00Z" ()) ]
      in
      assert_to_run ~expected:[ "ds_one" ] selection;
      ())

let test_unchanged_plan_does_not_run =
  Oth.test ~name:"autoplan: a plan with no changed file does not run again" (fun _ ->
      let selection =
        select
          ~changes:[ ("old", [ "ds_two" ]) ]
          [ state "ds_one" ~last_plan:(plan ~sha:"old" ~created_at:"2026-09-11T10:00:00Z" ()) ]
      in
      assert_to_run ~expected:[] selection;
      ())

let test_changed_plan_runs =
  Oth.test ~name:"autoplan: a plan with a changed file runs again" (fun _ ->
      let selection =
        select
          ~changes:[ ("old", [ "ds_one"; "ds_two" ]) ]
          [
            state "ds_one" ~last_plan:(plan ~sha:"old" ~created_at:"2026-09-11T10:00:00Z" ());
            state "ds_two" ~last_plan:(plan ~sha:"old" ~created_at:"2026-09-11T10:00:00Z" ());
            state "ds_three" ~last_plan:(plan ~sha:"old" ~created_at:"2026-09-11T10:00:00Z" ());
          ]
      in
      assert_to_run ~expected:[ "ds_one"; "ds_two" ] selection;
      ())

(* The caller must do nothing with an empty selection, and must not make a work manifest which
   holds no dirspace. *)
let test_everything_filtered_is_empty =
  Oth.test ~name:"autoplan: every dirspace filtered out gives an empty selection" (fun _ ->
      let selection =
        select
          [
            state "ds_one" ~last_plan:(plan ~sha:head ~created_at:"2026-09-11T10:00:00Z" ());
            state "ds_two" ~last_plan:(plan ~sha:head ~created_at:"2026-09-11T10:00:00Z" ());
          ]
      in
      assert_to_run ~expected:[] selection;
      ())

(* -- Applied state -- *)

let test_apply_survives_an_unrelated_push =
  Oth.test ~name:"applied: an apply survives a push which does not touch its files" (fun _ ->
      let selection =
        select
          ~changes:[ ("sha_a", [ "ds_two" ]) ]
          [
            state
              "ds_one"
              ~last_plan:(plan ~sha:"sha_a" ~created_at:"2026-09-11T10:00:00Z" ())
              ~last_apply:(run ~sha:"sha_a" ~created_at:"2026-09-11T10:05:00Z" ());
          ]
      in
      assert_applied ~expected:[ "ds_one" ] selection;
      assert_to_run ~expected:[] selection;
      ())

let test_apply_lost_when_a_file_changed =
  Oth.test ~name:"applied: an apply is lost when one of its files changed" (fun _ ->
      let selection =
        select
          ~changes:[ ("sha_a", [ "ds_one" ]) ]
          [
            state
              "ds_one"
              ~last_plan:(plan ~sha:"sha_a" ~created_at:"2026-09-11T10:00:00Z" ())
              ~last_apply:(run ~sha:"sha_a" ~created_at:"2026-09-11T10:05:00Z" ());
          ]
      in
      assert_applied ~expected:[] selection;
      assert_to_run ~expected:[ "ds_one" ] selection;
      ())

(* A plan which found no changes has nothing to apply, thus it counts as applied.  This is the
   [plans_with_no_changes] union of select_dirspace_applies_for_context.sql. *)
let test_clean_plan_counts_as_applied =
  Oth.test ~name:"applied: a plan with no changes counts as applied and survives a push" (fun _ ->
      let selection =
        select
          ~changes:[ ("sha_a", [ "ds_two" ]) ]
          [
            state
              "ds_one"
              ~last_plan:
                (plan ~has_changes:false ~sha:"sha_a" ~created_at:"2026-09-11T10:00:00Z" ());
          ]
      in
      assert_applied ~expected:[ "ds_one" ] selection;
      assert_to_run ~expected:[] selection;
      ())

(* -- Layers -- *)

let three_layers = [ [ "l_one" ]; [ "l_two" ]; [ "l_three" ] ]

let test_working_layer_stays_at_the_third_layer =
  Oth.test ~name:"layers: two applied layers stay applied when their files did not change" (fun _ ->
      let selection =
        select
          ~ls:three_layers
          [
            state
              "l_one"
              ~last_plan:(plan ~sha:"sha_a" ~created_at:"2026-09-11T10:00:00Z" ())
              ~last_apply:(run ~sha:"sha_a" ~created_at:"2026-09-11T10:01:00Z" ());
            state
              "l_two"
              ~last_plan:(plan ~sha:"sha_a" ~created_at:"2026-09-11T10:02:00Z" ())
              ~last_apply:(run ~sha:"sha_a" ~created_at:"2026-09-11T10:03:00Z" ());
            state "l_three";
          ]
      in
      assert_applied ~expected:[ "l_one"; "l_two" ] selection;
      assert_to_run ~expected:[ "l_three" ] selection;
      ())

let test_force_in_the_first_layer_rewinds =
  Oth.test
    ~name:"layers: a force match in the first layer makes that layer the working layer"
    (fun _ ->
      let selection =
        select
          ~ls:three_layers
          ~force:[ "l_one" ]
          [
            state
              "l_one"
              ~last_plan:(plan ~sha:"sha_a" ~created_at:"2026-09-11T10:00:00Z" ())
              ~last_apply:(run ~sha:"sha_a" ~created_at:"2026-09-11T10:01:00Z" ());
            state
              "l_two"
              ~last_plan:(plan ~sha:"sha_a" ~created_at:"2026-09-11T10:02:00Z" ())
              ~last_apply:(run ~sha:"sha_a" ~created_at:"2026-09-11T10:03:00Z" ());
            state
              "l_three"
              ~last_plan:(plan ~sha:"sha_a" ~created_at:"2026-09-11T10:04:00Z" ())
              ~last_apply:(run ~sha:"sha_a" ~created_at:"2026-09-11T10:05:00Z" ());
          ]
      in
      assert_to_run ~expected:[ "l_one" ] selection;
      assert_applied ~expected:[] selection;
      ())

(* After the forced run of the first layer lands, its work manifest is the most recent one.  The
   applies of the later layers are older than it, thus they no longer count. *)
let test_a_later_first_layer_run_invalidates_the_layers_after_it =
  Oth.test
    ~name:"layers: a run in the first layer after the later layers invalidates them"
    (fun _ ->
      let selection =
        select
          ~ls:three_layers
          [
            state "l_one" ~last_plan:(plan ~sha:head ~created_at:"2026-09-11T11:00:00Z" ());
            state
              "l_two"
              ~last_plan:(plan ~sha:"sha_a" ~created_at:"2026-09-11T10:02:00Z" ())
              ~last_apply:(run ~sha:"sha_a" ~created_at:"2026-09-11T10:03:00Z" ());
            state
              "l_three"
              ~last_plan:(plan ~sha:"sha_a" ~created_at:"2026-09-11T10:04:00Z" ())
              ~last_apply:(run ~sha:"sha_a" ~created_at:"2026-09-11T10:05:00Z" ());
          ]
      in
      assert_applied ~expected:[] selection;
      ())

(* The state of 0008 at the moment the user comments [terrateam apply], after the forced plan of
   [l_one] landed.  The force lives only in the evaluation which carries the tag query, thus
   [force] is empty here and the plan of [l_one] is what must keep the rewind alive.  Without it
   the apply of [l_one] never runs, and the apply reaches [l_two] instead. *)
let test_a_forced_plan_outlives_the_force =
  Oth.test ~name:"layers: a plan made after an apply makes that dirspace unapplied" (fun _ ->
      let selection =
        select
          ~ls:three_layers
          ~changes:[ ("sha_a", [ "l_three" ]) ]
          [
            state
              "l_one"
              ~last_plan:(plan ~sha:head ~created_at:"2026-09-11T11:14:00Z" ())
              ~last_apply:(run ~sha:"sha_a" ~created_at:"2026-09-11T11:10:00Z" ());
            state
              "l_two"
              ~last_plan:(plan ~sha:"sha_a" ~created_at:"2026-09-11T11:10:00Z" ())
              ~last_apply:(run ~sha:"sha_a" ~created_at:"2026-09-11T11:12:00Z" ());
            state "l_three" ~last_plan:(plan ~sha:head ~created_at:"2026-09-11T11:13:00Z" ());
          ]
      in
      (* [l_one] holds a good plan, thus it needs no new one -- it needs to be applied. *)
      assert_applied ~expected:[] selection;
      assert_to_run ~expected:[ "l_three"; "l_two" ] selection;
      ())

(* The step after {!test_a_forced_plan_outlives_the_force}: [l_one] is applied, thus its apply is
   now the most recent run of the first layer and the layers after it must plan again. *)
let test_the_layers_after_a_forced_apply_plan_again =
  Oth.test ~name:"layers: the layers after a forced apply lose their plans" (fun _ ->
      let selection =
        select
          ~ls:three_layers
          ~changes:[ ("sha_a", [ "l_three" ]) ]
          [
            state
              "l_one"
              ~last_plan:(plan ~sha:head ~created_at:"2026-09-11T11:14:00Z" ())
              ~last_apply:(run ~sha:head ~created_at:"2026-09-11T11:16:00Z" ());
            state
              "l_two"
              ~last_plan:(plan ~sha:"sha_a" ~created_at:"2026-09-11T11:10:00Z" ())
              ~last_apply:(run ~sha:"sha_a" ~created_at:"2026-09-11T11:12:00Z" ());
            state "l_three" ~last_plan:(plan ~sha:head ~created_at:"2026-09-11T11:13:00Z" ());
          ]
      in
      assert_applied ~expected:[ "l_one" ] selection;
      assert_to_run ~expected:[ "l_three"; "l_two" ] selection;
      ())

let test_force_in_the_last_layer_keeps_the_earlier_layers =
  Oth.test
    ~name:"layers: a force match in the last layer does not invalidate the earlier layers"
    (fun _ ->
      let selection =
        select
          ~ls:three_layers
          ~force:[ "l_three" ]
          [
            state
              "l_one"
              ~last_plan:(plan ~sha:"sha_a" ~created_at:"2026-09-11T10:00:00Z" ())
              ~last_apply:(run ~sha:"sha_a" ~created_at:"2026-09-11T10:01:00Z" ());
            state
              "l_two"
              ~last_plan:(plan ~sha:"sha_a" ~created_at:"2026-09-11T10:02:00Z" ())
              ~last_apply:(run ~sha:"sha_a" ~created_at:"2026-09-11T10:03:00Z" ());
            state "l_three" ~last_plan:(plan ~sha:"sha_a" ~created_at:"2026-09-11T10:04:00Z" ());
          ]
      in
      assert_applied ~expected:[ "l_one"; "l_two" ] selection;
      assert_to_run ~expected:[ "l_three" ] selection;
      ())

(* A force names one dirspace of a layer.  What waits for that dirspace loses its applied state,
   and a dirspace beside it in the layer does not: nothing waits for a sibling, thus the run it
   holds still stands (RFD 2305). *)
let test_one_dirspace_of_a_layer_is_forced =
  Oth.test
    ~name:"tree: a force takes the applied state from what waits for the forced dirspace"
    (fun _ ->
      let selection =
        select
          ~ls:[ [ "l_one" ]; [ "m_alpha"; "m_beta" ]; [ "l_three" ] ]
          ~force:[ "m_alpha" ]
          [
            state
              "l_one"
              ~last_plan:(plan ~sha:"sha_a" ~created_at:"2026-09-11T10:00:00Z" ())
              ~last_apply:(run ~sha:"sha_a" ~created_at:"2026-09-11T10:01:00Z" ());
            state
              "m_alpha"
              ~last_plan:(plan ~sha:"sha_a" ~created_at:"2026-09-11T10:02:00Z" ())
              ~last_apply:(run ~sha:"sha_a" ~created_at:"2026-09-11T10:03:00Z" ());
            state
              "m_beta"
              ~last_plan:(plan ~sha:"sha_a" ~created_at:"2026-09-11T10:02:00Z" ())
              ~last_apply:(run ~sha:"sha_a" ~created_at:"2026-09-11T10:03:00Z" ());
            state
              "l_three"
              ~last_plan:(plan ~sha:"sha_a" ~created_at:"2026-09-11T10:04:00Z" ())
              ~last_apply:(run ~sha:"sha_a" ~created_at:"2026-09-11T10:05:00Z" ());
          ]
      in
      assert_to_run ~expected:[ "m_alpha" ] selection;
      assert_applied ~expected:[ "l_one"; "m_beta" ] selection;
      ())

(* -- Force path -- *)

let test_force_runs_an_unchanged_dirspace =
  Oth.test ~name:"force: a force match runs a dirspace whose files did not change" (fun _ ->
      let selection =
        select
          ~force:[ "ds_one" ]
          [
            state "ds_one" ~last_plan:(plan ~sha:head ~created_at:"2026-09-11T10:00:00Z" ());
            state "ds_two" ~last_plan:(plan ~sha:head ~created_at:"2026-09-11T10:00:00Z" ());
          ]
      in
      assert_to_run ~expected:[ "ds_one" ] selection;
      ())

(* Force planning reaches only the dirspaces which the pull request changes.  A dirspace which is
   not a candidate is not in [states], thus the force does nothing. *)
let test_force_outside_the_change_set_does_nothing =
  Oth.test ~name:"force: a force match outside the change set does not run" (fun _ ->
      let selection =
        select
          ~force:[ "ds_two" ]
          [ state "ds_one" ~last_plan:(plan ~sha:head ~created_at:"2026-09-11T10:00:00Z" ()) ]
      in
      assert_to_run ~expected:[] selection;
      ())

let test_empty_force_changes_nothing =
  Oth.test ~name:"force: an empty force set leaves the selection unchanged" (fun _ ->
      let states =
        [
          state
            "ds_one"
            ~last_plan:(plan ~sha:"sha_a" ~created_at:"2026-09-11T10:00:00Z" ())
            ~last_apply:(run ~sha:"sha_a" ~created_at:"2026-09-11T10:01:00Z" ());
          state "ds_two";
        ]
      in
      let selection = select ~ls:[ [ "ds_one" ]; [ "ds_two" ] ] states in
      assert_to_run ~expected:[ "ds_two" ] selection;
      assert_applied ~expected:[ "ds_one" ] selection;
      ())

(* -- The tree (RFD 2305) -- *)

(* Two branches of the tree, [dev] and [prod], each networking -> database -> app.  The user walks
   the whole dev branch and applies prod/networking after it.  dev/database waits for dev/networking
   only, thus the later run of prod/networking takes nothing away from it. *)
let test_tree_branches_do_not_order_each_other =
  Oth.test ~name:"tree: a run of another branch does not send this branch back" (fun _ ->
      let applied dir at =
        state
          dir
          ~last_plan:(plan ~sha:head ~created_at:at ())
          ~last_apply:(run ~sha:head ~created_at:at ())
      in
      let states =
        [
          applied "dev/networking" "2026-09-11T10:00:00Z";
          applied "dev/database" "2026-09-11T10:01:00Z";
          applied "dev/app" "2026-09-11T10:02:00Z";
          applied "prod/networking" "2026-09-11T10:03:00Z";
          state "prod/database";
          state "prod/app";
        ]
      in
      let selection =
        Ipr.select
          ~changed_since:(fun _ _ -> Terrat_data.Dirspace_set.empty)
          ~changed_between:(fun _ _ -> Terrat_data.Dirspace_set.empty)
          ~force:(dirspace_set [])
          ~superseded:(dirspace_set [])
          ~last_run_failed:(dirspace_set [])
          ~depends_on:
            (tree_depends_on
               [
                 [ "dev/networking"; "dev/database"; "dev/app" ];
                 [ "prod/networking"; "prod/database"; "prod/app" ];
               ])
          states
      in
      assert_applied
        ~expected:[ "dev/app"; "dev/database"; "dev/networking"; "prod/networking" ]
        selection;
      assert_to_run ~expected:[ "prod/app"; "prod/database" ] selection;
      ())

(* Inside one branch the order still holds: a dirspace whose dependency ran after it must run
   again. *)
let test_tree_branch_keeps_its_order =
  Oth.test ~name:"tree: a dependency that ran later sends its dependent back" (fun _ ->
      let states =
        [
          state
            "dev/networking"
            ~last_plan:(plan ~sha:head ~created_at:"2026-09-11T10:05:00Z" ())
            ~last_apply:(run ~sha:head ~created_at:"2026-09-11T10:05:00Z" ());
          state
            "dev/database"
            ~last_plan:(plan ~sha:head ~created_at:"2026-09-11T10:01:00Z" ())
            ~last_apply:(run ~sha:head ~created_at:"2026-09-11T10:01:00Z" ());
        ]
      in
      let selection =
        Ipr.select
          ~changed_since:(fun _ _ -> Terrat_data.Dirspace_set.empty)
          ~changed_between:(fun _ _ -> Terrat_data.Dirspace_set.empty)
          ~force:(dirspace_set [])
          ~superseded:(dirspace_set [])
          ~last_run_failed:(dirspace_set [])
          ~depends_on:(tree_depends_on [ [ "dev/networking"; "dev/database" ] ])
          states
      in
      assert_applied ~expected:[ "dev/networking" ] selection;
      assert_to_run ~expected:[ "dev/database" ] selection;
      ())

(* -- Ordering -- *)

(* Two runs can carry the same time, because the work manifest time has a resolution of one second
   and because a drift run plans every layer under one work manifest.  The result must not depend
   on the order of the input list. *)
let test_equal_times_are_deterministic =
  Oth.test
    ~name:"ordering: equal created_at values do not make the result depend on list order"
    (fun _ ->
      let states =
        [
          state
            "l_one"
            ~last_plan:(plan ~sha:"sha_a" ~created_at:"2026-09-11T10:00:00Z" ())
            ~last_apply:(run ~sha:"sha_a" ~created_at:"2026-09-11T10:00:00Z" ());
          state
            "l_two"
            ~last_plan:(plan ~sha:"sha_a" ~created_at:"2026-09-11T10:00:00Z" ())
            ~last_apply:(run ~sha:"sha_a" ~created_at:"2026-09-11T10:00:00Z" ());
        ]
      in
      let ls = [ [ "l_one" ]; [ "l_two" ] ] in
      let forward = select ~ls states in
      let backward = select ~ls (CCList.rev states) in
      assert_applied ~expected:[ "l_one"; "l_two" ] forward;
      Oth.Assert.eq ~eq:Ipr.Selection.equal ~pp:Ipr.Selection.pp forward backward;
      ())

(* The shape the apply gate falls back to when the tree of the head is not in the database.  It
   hands [select] change sets which hold every dirspace, because a tree which is not
   there must mean "run it" and never "skip it".  Nothing may survive as applied, or a stale plan
   reaches an apply. *)
let test_everything_changed_runs_everything =
  Oth.test ~name:"guard: every dirspace changed runs everything and applies nothing" (fun _ ->
      let states =
        [
          state
            "l_one"
            ~last_plan:(plan ~sha:"old" ~created_at:"2026-09-11T10:00:00Z" ())
            ~last_apply:(run ~sha:"old" ~created_at:"2026-09-11T10:00:00Z" ());
          state
            "l_two"
            ~last_plan:(plan ~has_changes:false ~sha:"old" ~created_at:"2026-09-11T10:00:00Z" ());
          state "l_three";
        ]
      in
      let selection =
        Ipr.select
          ~changed_since:(fun _ _ -> dirspace_set [ "l_one"; "l_two"; "l_three" ])
          ~changed_between:(fun _ _ -> dirspace_set [ "l_one"; "l_two"; "l_three" ])
          ~force:(dirspace_set [])
          ~superseded:(dirspace_set [])
          ~last_run_failed:(dirspace_set [])
          ~depends_on:(depends_on_of [ [ "l_one" ]; [ "l_two" ]; [ "l_three" ] ])
          states
      in
      assert_to_run ~expected:[ "l_one"; "l_three"; "l_two" ] selection;
      assert_applied ~expected:[] selection;
      ())

(* -- Superseded by another pull request -- *)

(* The files of the dirspace did not move, thus the file test alone keeps the plan.  Another pull
   request applied or merged the dirspace after that plan, thus the state the plan was built on is
   gone and the plan has to be made again. *)
let test_superseded_plan_runs =
  Oth.test ~name:"superseded: a plan which another pull request superseded runs again" (fun _ ->
      let selection =
        select
          ~superseded:[ "ds_one" ]
          [ state "ds_one" ~last_plan:(plan ~sha:"old" ~created_at:"2026-09-11T10:00:00Z" ()) ]
      in
      assert_to_run ~expected:[ "ds_one" ] selection;
      assert_applied ~expected:[] selection;
      ())

(* The apply of this pull request is gone the same way, thus the dirspace is unapplied and the
   evaluation gives it back to the layer which runs next. *)
let test_superseded_apply_is_not_applied =
  Oth.test
    ~name:"superseded: an apply which another pull request superseded does not count as applied"
    (fun _ ->
      let selection =
        select
          ~superseded:[ "ds_one" ]
          [
            state
              "ds_one"
              ~last_plan:(plan ~sha:"old" ~created_at:"2026-09-11T10:00:00Z" ())
              ~last_apply:(run ~sha:"old" ~created_at:"2026-09-11T11:00:00Z" ());
          ]
      in
      assert_to_run ~expected:[ "ds_one" ] selection;
      assert_applied ~expected:[] selection;
      ())

(* A plan which found no changes counts as applied.  That answer is about the state the plan read,
   thus the other pull request takes it away too. *)
let test_superseded_clean_plan_is_not_applied =
  Oth.test
    ~name:"superseded: a plan with no changes which another pull request superseded runs again"
    (fun _ ->
      let selection =
        select
          ~superseded:[ "ds_one" ]
          [
            state
              "ds_one"
              ~last_plan:(plan ~has_changes:false ~sha:"old" ~created_at:"2026-09-11T10:00:00Z" ());
          ]
      in
      assert_to_run ~expected:[ "ds_one" ] selection;
      assert_applied ~expected:[] selection;
      ())

(* The set names the dirspaces it names and no other one. *)
let test_superseded_reaches_only_its_dirspaces =
  Oth.test ~name:"superseded: a dirspace outside the set keeps its plan" (fun _ ->
      let selection =
        select
          ~superseded:[ "ds_one" ]
          [
            state "ds_one" ~last_plan:(plan ~sha:"old" ~created_at:"2026-09-11T10:00:00Z" ());
            state "ds_two" ~last_plan:(plan ~sha:"old" ~created_at:"2026-09-11T10:00:00Z" ());
          ]
      in
      assert_to_run ~expected:[ "ds_one" ] selection;
      ())

(* An empty set is the usual case and must change nothing. *)
let test_empty_superseded_changes_nothing =
  Oth.test ~name:"superseded: an empty set leaves the selection unchanged" (fun _ ->
      let states =
        [
          state
            "ds_one"
            ~last_plan:(plan ~sha:"old" ~created_at:"2026-09-11T10:00:00Z" ())
            ~last_apply:(run ~sha:"old" ~created_at:"2026-09-11T11:00:00Z" ());
        ]
      in
      Oth.Assert.eq
        ~eq:Ipr.Selection.equal
        ~pp:Ipr.Selection.pp
        (select states)
        (select ~superseded:[] states);
      ())

(* -- A run which failed -- *)

(* The files of the dirspace did not move since the plan which succeeded, thus the file test alone
   keeps that plan.  A newer run failed, and no row of [states] carries it, because the caller
   takes the successful runs only. *)
let test_failed_run_with_no_file_change_runs =
  Oth.test ~name:"failed: a newer failed run with no file change runs again" (fun _ ->
      let selection =
        select
          ~last_run_failed:[ "ds_one" ]
          [ state "ds_one" ~last_plan:(plan ~sha:"old" ~created_at:"2026-09-11T10:00:00Z" ()) ]
      in
      assert_to_run ~expected:[ "ds_one" ] selection;
      assert_applied ~expected:[] selection;
      ())

(* A plan which failed says nothing about an apply which succeeded.  Thus the dirspace stays
   applied, and the layers after it keep what they reached. *)
let test_failed_run_keeps_an_apply =
  Oth.test ~name:"failed: a failed run does not take away an apply which succeeded" (fun _ ->
      let selection =
        select
          ~last_run_failed:[ "l_one" ]
          ~ls:[ [ "l_one" ]; [ "l_two" ] ]
          [
            state
              "l_one"
              ~last_plan:(plan ~sha:"old" ~created_at:"2026-09-11T10:00:00Z" ())
              ~last_apply:(run ~sha:"old" ~created_at:"2026-09-11T11:00:00Z" ());
            state
              "l_two"
              ~last_plan:(plan ~sha:"old" ~created_at:"2026-09-11T12:00:00Z" ())
              ~last_apply:(run ~sha:"old" ~created_at:"2026-09-11T13:00:00Z" ());
          ]
      in
      assert_to_run ~expected:[] selection;
      assert_applied ~expected:[ "l_one"; "l_two" ] selection;
      ())

(* A plan which succeeded and which nobody applied is work which is still there.  A failed run
   after it must not turn that work into an applied dirspace. *)
let test_failed_run_does_not_apply_an_unapplied_plan =
  Oth.test
    ~name:"failed: a failed run after an unapplied plan does not make the dirspace applied"
    (fun _ ->
      let selection =
        select
          ~last_run_failed:[ "ds_one" ]
          [
            state
              "ds_one"
              ~last_plan:(plan ~sha:"old" ~created_at:"2026-09-11T12:00:00Z" ())
              ~last_apply:(run ~sha:"old" ~created_at:"2026-09-11T10:00:00Z" ());
          ]
      in
      assert_to_run ~expected:[ "ds_one" ] selection;
      assert_applied ~expected:[] selection;
      ())

(* The set names the dirspaces it names and no other one. *)
let test_empty_last_run_failed_changes_nothing =
  Oth.test ~name:"failed: an empty set leaves the selection unchanged" (fun _ ->
      let states =
        [ state "ds_one" ~last_plan:(plan ~sha:"old" ~created_at:"2026-09-11T10:00:00Z" ()) ]
      in
      Oth.Assert.eq
        ~eq:Ipr.Selection.equal
        ~pp:Ipr.Selection.pp
        (select states)
        (select ~last_run_failed:[] states);
      ())

(* -- The two lists are apart -- *)

(* An apply with no plan, which is what an unsafe-apply records.  The dirspace was applied, thus it
   has nothing left to do and it must not also be in the list of what runs. *)
let test_an_apply_with_no_plan_is_applied_only =
  Oth.test ~name:"lists: an apply with no plan is applied and does not run" (fun _ ->
      let selection =
        select [ state "ds_one" ~last_apply:(run ~sha:"old" ~created_at:"2026-09-11T10:00:00Z" ()) ]
      in
      assert_to_run ~expected:[] selection;
      assert_applied ~expected:[ "ds_one" ] selection;
      ())

(* The same, over every case the other tests of this suite make: whatever the input, one dirspace
   is never in both lists. *)
let test_the_lists_never_overlap =
  Oth.test ~name:"lists: no dirspace is in both lists" (fun _ ->
      let states =
        [
          state "ds_one" ~last_apply:(run ~sha:"old" ~created_at:"2026-09-11T10:00:00Z" ());
          state
            "ds_two"
            ~last_plan:(plan ~has_changes:false ~sha:"old" ~created_at:"2026-09-11T10:00:00Z" ());
          state "ds_three" ~last_plan:(plan ~sha:"old" ~created_at:"2026-09-11T10:00:00Z" ());
          state "ds_four";
        ]
      in
      CCList.iter
        (fun (force, superseded, last_run_failed) ->
          let { Ipr.Selection.to_run; out_of_order = _; applied } =
            select ~force ~superseded ~last_run_failed states
          in
          let to_run = Terrat_data.Dirspace_set.of_list to_run in
          CCList.iter
            (fun dirspace -> Oth.Assert.not_true (Terrat_data.Dirspace_set.mem dirspace to_run))
            applied)
        [
          ([], [], []);
          ([ "ds_one" ], [], []);
          ([], [ "ds_one" ], []);
          ([], [], [ "ds_one" ]);
          ([], [], [ "ds_two" ]);
          ([ "ds_two" ], [ "ds_three" ], [ "ds_one" ]);
        ];
      ())

(* -- Commits that move during a run (RFD 2356) -- *)

(* The heads at the start and at the result of a run.  [moved] is a pair of commits that moved
   while the run operated. *)
let moved = ("start", "result")

let test_a_stale_apply_is_not_applied =
  Oth.test ~name:"moved: an apply whose files changed during the run is not applied" (fun _ ->
      let selection =
        select
          ~between:[ (moved, [ "tf" ]) ]
          [
            state
              "tf"
              ~last_plan:(plan ~sha:head ~created_at:"2026-09-22T10:00:00Z" ())
              ~last_apply:(run ~during:[ moved ] ~sha:head ~created_at:"2026-09-22T10:01:00Z" ());
          ]
      in
      (* The apply used the plan, thus the plan is used up: the dirspace plans again. *)
      assert_to_run ~expected:[ "tf" ] selection;
      assert_applied ~expected:[] selection;
      ())

let test_an_apply_whose_files_did_not_move_is_applied =
  Oth.test ~name:"moved: an apply whose files did not change during the run is applied" (fun _ ->
      let selection =
        select
          ~between:[ (moved, [ "docs" ]) ]
          [
            state
              "tf"
              ~last_plan:(plan ~sha:head ~created_at:"2026-09-22T10:00:00Z" ())
              ~last_apply:(run ~during:[ moved ] ~sha:head ~created_at:"2026-09-22T10:01:00Z" ());
          ]
      in
      assert_to_run ~expected:[] selection;
      assert_applied ~expected:[ "tf" ] selection;
      ())

let test_a_stale_plan_runs =
  Oth.test ~name:"moved: a plan whose files changed during the run plans again" (fun _ ->
      let selection =
        select
          ~between:[ (moved, [ "tf" ]) ]
          [
            state
              "tf"
              ~last_plan:(plan ~during:[ moved ] ~sha:head ~created_at:"2026-09-22T10:00:00Z" ());
          ]
      in
      assert_to_run ~expected:[ "tf" ] selection;
      assert_applied ~expected:[] selection;
      ())

let test_a_plan_after_a_stale_apply_stands =
  Oth.test ~name:"moved: a plan made after a stale apply is not used up" (fun _ ->
      let selection =
        select
          ~between:[ (moved, [ "tf" ]) ]
          [
            state
              "tf"
              ~last_plan:(plan ~sha:head ~created_at:"2026-09-22T10:02:00Z" ())
              ~last_apply:(run ~during:[ moved ] ~sha:head ~created_at:"2026-09-22T10:01:00Z" ());
          ]
      in
      assert_to_run ~expected:[] selection;
      assert_applied ~expected:[] selection;
      ())

(* -- Out of order -- *)

(* A plan whose files did not change is still in [to_run] when a dirspace it waits for ran after
   it.  Nothing moved under it, and the caller tells the user so. *)
let test_a_plan_behind_its_dependency_is_out_of_order =
  Oth.test ~name:"out of order: a plan older than a run of its dependency is out of order" (fun _ ->
      let selection =
        select
          ~ls:[ [ "l_one" ]; [ "l_two" ] ]
          [
            state "l_one" ~last_plan:(plan ~sha:head ~created_at:"2026-09-22T10:05:00Z" ());
            state "l_two" ~last_plan:(plan ~sha:head ~created_at:"2026-09-22T10:01:00Z" ());
          ]
      in
      assert_to_run ~expected:[ "l_two" ] selection;
      assert_out_of_order ~expected:[ "l_two" ] selection;
      ())

(* A stale plan is bad for its own files, thus it is not out of order even when a dependency ran
   after it. *)
let test_a_stale_plan_behind_its_dependency_is_not_out_of_order =
  Oth.test ~name:"out of order: a stale plan is not out of order" (fun _ ->
      let selection =
        select
          ~between:[ (moved, [ "l_two" ]) ]
          ~ls:[ [ "l_one" ]; [ "l_two" ] ]
          [
            state "l_one" ~last_plan:(plan ~sha:head ~created_at:"2026-09-22T10:05:00Z" ());
            state
              "l_two"
              ~last_plan:(plan ~during:[ moved ] ~sha:head ~created_at:"2026-09-22T10:01:00Z" ());
          ]
      in
      assert_to_run ~expected:[ "l_two" ] selection;
      assert_out_of_order ~expected:[] selection;
      ())

(* A forced dirspace and a dirspace whose newest run failed run for that reason, and not for the
   order of the layers. *)
let test_forced_and_failed_are_not_out_of_order =
  Oth.test ~name:"out of order: a forced or failed dirspace is not out of order" (fun _ ->
      let states =
        [
          state "l_one" ~last_plan:(plan ~sha:head ~created_at:"2026-09-22T10:05:00Z" ());
          state "l_two" ~last_plan:(plan ~sha:head ~created_at:"2026-09-22T10:01:00Z" ());
        ]
      in
      let ls = [ [ "l_one" ]; [ "l_two" ] ] in
      let forced = select ~force:[ "l_two" ] ~ls states in
      assert_to_run ~expected:[ "l_two" ] forced;
      assert_out_of_order ~expected:[] forced;
      let failed = select ~last_run_failed:[ "l_two" ] ~ls states in
      assert_to_run ~expected:[ "l_two" ] failed;
      assert_out_of_order ~expected:[] failed;
      ())

let test_an_unknown_pair_is_not_good =
  Oth.test ~name:"moved: a pair that could not be compared fails safe" (fun _ ->
      (* The caller gives every dirspace for a pair whose tree is not stored. *)
      let selection =
        select
          ~between:[ (moved, [ "tf"; "app" ]) ]
          [
            state
              "tf"
              ~last_plan:(plan ~sha:head ~created_at:"2026-09-22T10:00:00Z" ())
              ~last_apply:(run ~during:[ moved ] ~sha:head ~created_at:"2026-09-22T10:01:00Z" ());
            state
              "app"
              ~last_plan:(plan ~sha:head ~created_at:"2026-09-22T10:00:00Z" ())
              ~last_apply:(run ~sha:head ~created_at:"2026-09-22T10:01:00Z" ());
          ]
      in
      (* [app] ran with nothing that moved, thus the pair of [tf] says nothing about it. *)
      assert_to_run ~expected:[ "tf" ] selection;
      assert_applied ~expected:[ "app" ] selection;
      ())

let test_a_merged_apply_keeps_a_later_change =
  Oth.test ~name:"moved: a merged apply stays applied when the destination changes later" (fun _ ->
      let selection =
        select
          ~merged:true
          ~changes:[ ("dest", [ "tf" ]) ]
          [
            state
              "tf"
              ~last_plan:(plan ~sha:"pr" ~created_at:"2026-09-22T10:00:00Z" ())
              ~last_apply:(run ~sha:"dest" ~created_at:"2026-09-22T10:01:00Z" ());
          ]
      in
      assert_applied ~expected:[ "tf" ] selection;
      ())

let test_a_merged_apply_is_stale_when_it_moved =
  Oth.test ~name:"moved: a merged apply whose files changed during the run is not applied" (fun _ ->
      let selection =
        select
          ~merged:true
          ~between:[ (moved, [ "tf" ]) ]
          [
            state
              "tf"
              ~last_plan:(plan ~sha:"pr" ~created_at:"2026-09-22T10:00:00Z" ())
              ~last_apply:(run ~during:[ moved ] ~sha:"dest" ~created_at:"2026-09-22T10:01:00Z" ());
          ]
      in
      assert_to_run ~expected:[ "tf" ] selection;
      assert_applied ~expected:[] selection;
      ())

let test_a_stale_layer_holds_back_its_dependents =
  Oth.test ~name:"moved: a stale apply of a layer holds back the layer that depends on it" (fun _ ->
      let selection =
        select
          ~between:[ (moved, [ "base" ]) ]
          ~ls:[ [ "base" ]; [ "database" ] ]
          [
            state
              "base"
              ~last_plan:(plan ~sha:head ~created_at:"2026-09-22T10:00:00Z" ())
              ~last_apply:(run ~during:[ moved ] ~sha:head ~created_at:"2026-09-22T10:01:00Z" ());
            state "database" ~last_plan:(plan ~sha:head ~created_at:"2026-09-22T10:02:00Z" ());
          ]
      in
      assert_to_run ~expected:[ "base" ] selection;
      assert_applied ~expected:[] selection;
      ())

(* -- A plan that is running now -- *)

(* [in_progress] pairs a dirspace with the dirspaces whose files changed since its plan started.
   [force] is the dirspaces the tag query named: a request to run one now is not declined because
   a plan of it is in flight. *)
let without_in_progress ?(force = []) ~in_progress selection =
  Ipr.without_in_progress
    ~in_progress:(CCList.map (fun (dir, changed) -> (ds dir, dirspace_set changed)) in_progress)
    ~force:(dirspace_set force)
    selection

let test_in_progress_plan_is_a_noop =
  Oth.test ~name:"in progress: a dirspace a plan is planning now does not run again" (fun _ ->
      let selection = select [ state "ds_one" ] in
      assert_to_run ~expected:[ "ds_one" ] selection;
      let planned_now = without_in_progress ~in_progress:[ ("ds_one", []) ] selection in
      assert_planned ~expected:[] planned_now;
      assert_applied ~expected:[] selection;
      ())

let test_in_progress_plan_with_a_changed_file_runs =
  Oth.test
    ~name:"in progress: a push that changed the files of the dirspace plans it again"
    (fun _ ->
      let selection = select [ state "ds_one" ] in
      let planned_now = without_in_progress ~in_progress:[ ("ds_one", [ "ds_one" ]) ] selection in
      assert_planned ~expected:[ "ds_one" ] planned_now;
      ())

let test_in_progress_plan_keeps_the_other_dirspaces =
  Oth.test ~name:"in progress: only the dirspaces of the running plan are a noop" (fun _ ->
      let selection = select [ state "ds_one"; state "ds_two" ] in
      let planned_now = without_in_progress ~in_progress:[ ("ds_one", []) ] selection in
      assert_planned ~expected:[ "ds_two" ] planned_now;
      ())

let test_in_progress_plan_keeps_applied =
  Oth.test ~name:"in progress: a dirspace that counts as applied is not planned" (fun _ ->
      let selection =
        select
          [
            state
              "ds_one"
              ~last_apply:(run ~sha:head ~created_at:"2026-09-11T10:00:00Z" ())
              ~last_plan:(plan ~sha:head ~created_at:"2026-09-11T09:00:00Z" ());
          ]
      in
      assert_applied ~expected:[ "ds_one" ] selection;
      let planned_now = without_in_progress ~in_progress:[ ("ds_one", []) ] selection in
      assert_planned ~expected:[] planned_now;
      ())

let test_force_runs_an_in_progress_dirspace =
  Oth.test ~name:"in progress: a dirspace the tag query names still runs" (fun _ ->
      let selection = select ~force:[ "ds_one" ] [ state "ds_one" ] in
      let planned_now =
        without_in_progress ~force:[ "ds_one" ] ~in_progress:[ ("ds_one", []) ] selection
      in
      assert_planned ~expected:[ "ds_one" ] planned_now;
      ())

let test_in_progress_plan_clears_out_of_order =
  Oth.test ~name:"in progress: a dirspace out of order is a noop while its plan runs" (fun _ ->
      let selection =
        select
          ~ls:[ [ "ds_dep" ]; [ "ds_one" ] ]
          [
            state "ds_dep" ~last_plan:(plan ~sha:head ~created_at:"2026-09-11T11:00:00Z" ());
            state "ds_one" ~last_plan:(plan ~sha:head ~created_at:"2026-09-11T10:00:00Z" ());
          ]
      in
      assert_out_of_order ~expected:[ "ds_one" ] selection;
      let planned_now = without_in_progress ~in_progress:[ ("ds_one", []) ] selection in
      assert_planned ~expected:[] planned_now;
      ())

let test =
  Oth.parallel
    [
      test_tree_branches_do_not_order_each_other;
      test_tree_branch_keeps_its_order;
      test_no_plan_runs;
      test_failed_plan_runs;
      test_unchanged_plan_does_not_run;
      test_changed_plan_runs;
      test_everything_filtered_is_empty;
      test_apply_survives_an_unrelated_push;
      test_apply_lost_when_a_file_changed;
      test_clean_plan_counts_as_applied;
      test_working_layer_stays_at_the_third_layer;
      test_force_in_the_first_layer_rewinds;
      test_a_later_first_layer_run_invalidates_the_layers_after_it;
      test_a_forced_plan_outlives_the_force;
      test_the_layers_after_a_forced_apply_plan_again;
      test_force_in_the_last_layer_keeps_the_earlier_layers;
      test_one_dirspace_of_a_layer_is_forced;
      test_force_runs_an_unchanged_dirspace;
      test_force_outside_the_change_set_does_nothing;
      test_empty_force_changes_nothing;
      test_equal_times_are_deterministic;
      test_everything_changed_runs_everything;
      test_superseded_plan_runs;
      test_superseded_apply_is_not_applied;
      test_superseded_clean_plan_is_not_applied;
      test_superseded_reaches_only_its_dirspaces;
      test_empty_superseded_changes_nothing;
      test_failed_run_with_no_file_change_runs;
      test_failed_run_keeps_an_apply;
      test_failed_run_does_not_apply_an_unapplied_plan;
      test_empty_last_run_failed_changes_nothing;
      test_an_apply_with_no_plan_is_applied_only;
      test_the_lists_never_overlap;
      test_a_stale_apply_is_not_applied;
      test_an_apply_whose_files_did_not_move_is_applied;
      test_a_stale_plan_runs;
      test_a_plan_after_a_stale_apply_stands;
      test_an_unknown_pair_is_not_good;
      test_a_plan_behind_its_dependency_is_out_of_order;
      test_a_stale_plan_behind_its_dependency_is_not_out_of_order;
      test_forced_and_failed_are_not_out_of_order;
      test_a_merged_apply_keeps_a_later_change;
      test_a_merged_apply_is_stale_when_it_moved;
      test_a_stale_layer_holds_back_its_dependents;
      test_in_progress_plan_is_a_noop;
      test_in_progress_plan_with_a_changed_file_runs;
      test_in_progress_plan_keeps_the_other_dirspaces;
      test_in_progress_plan_keeps_applied;
      test_force_runs_an_in_progress_dirspace;
      test_in_progress_plan_clears_out_of_order;
    ]

let () =
  Random.self_init ();
  Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)
