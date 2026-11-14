(* The rules that decide whether commits that moved during a run make its work
   stale (RFD 2356).  Only a changed file of a dirspace of the run counts, and an
   unknown impact fails safe: a start restarts, a pull request result warns, a
   drift result reconciles again. *)

module St = Terrat_vcs_event_evaluator2.Staleness
module Dss = Terrat_data.Dirspace_set

let ds dir = { Terrat_dirspace.dir; workspace = "default" }
let tf = ds "tf"
let app = ds "app"
let docs = ds "docs"

(* [name] says what the case is.  [Oth.Assert.eq] prints both values when they
   differ, and the name goes on the line before them. *)
let assert_eq ~eq ~pp name expected actual =
  if not (eq expected actual) then Format.eprintf "%s@." name;
  Oth.Assert.eq ~eq ~pp expected actual

let assert_decision name expected actual = assert_eq ~eq:St.equal ~pp:St.pp name expected actual

let test_no_change_is_not_impacted =
  Oth.test ~name:"a move that changes no file of the run is not an impact" (fun _ ->
      assert_decision
        "a docs change leaves tf and app alone"
        St.Not_impacted
        (St.decide ~changed:(Some (Dss.of_list [ docs ])) [ tf; app ]);
      assert_decision
        "an empty commit is not an impact"
        St.Not_impacted
        (St.decide ~changed:(Some Dss.empty) [ tf; app ]);
      ())

let test_changed_dirspaces_are_impacted =
  Oth.test ~name:"only the changed dirspaces of the run are impacted" (fun _ ->
      assert_decision
        "tf changed, app did not, docs is not in the run"
        (St.Impacted [ tf ])
        (St.decide ~changed:(Some (Dss.of_list [ tf; docs ])) [ tf; app ]);
      assert_decision
        "the list is sorted and holds each dirspace once"
        (St.Impacted [ app; tf ])
        (St.decide ~changed:(Some (Dss.of_list [ tf; app ])) [ tf; app; tf ]);
      ())

let test_missing_tree_is_unknown =
  Oth.test ~name:"a tree that is not stored gives an unknown impact" (fun _ ->
      assert_decision "nothing was compared" St.Unknown (St.decide ~changed:None [ tf ]);
      ())

let test_start_restarts_unless_not_impacted =
  Oth.test ~name:"a start restarts unless it is proven not impacted" (fun _ ->
      let check name expected impact =
        assert_eq
          ~eq:St.Start.equal_decision
          ~pp:St.Start.pp_decision
          name
          expected
          (St.Start.decide impact)
      in
      check "not impacted runs" St.Start.Run St.Not_impacted;
      check "unknown restarts, it fails safe" St.Start.Restart St.Unknown;
      check "impacted restarts" St.Start.Restart (St.Impacted [ tf ]);
      ())

let test_pr_result_warns_on_unknown =
  Oth.test ~name:"a pull request result warns when the impact is unknown" (fun _ ->
      let check name expected impact =
        assert_eq
          ~eq:St.Pr_result.equal_decision
          ~pp:St.Pr_result.pp_decision
          name
          expected
          (St.Pr_result.decide impact)
      in
      check "not impacted is fresh" St.Pr_result.Fresh St.Not_impacted;
      check
        "impacted names the dirspaces"
        (St.Pr_result.Stale_files_changed [ tf ])
        (St.Impacted [ tf ]);
      check "unknown is stale, it never hides a change" St.Pr_result.Stale_files_unknown St.Unknown;
      ())

let test_drift_result_reconciles_on_unknown =
  Oth.test ~name:"a drift result reconciles again on an unknown impact" (fun _ ->
      let check name expected impact =
        assert_eq
          ~eq:St.Drift_result.equal_decision
          ~pp:St.Drift_result.pp_decision
          name
          expected
          (St.Drift_result.decide impact)
      in
      check "not impacted is resolved" St.Drift_result.Resolved St.Not_impacted;
      check "unknown reconciles again, it fails safe" St.Drift_result.Reconcile_again St.Unknown;
      check "impacted reconciles again" St.Drift_result.Reconcile_again (St.Impacted [ tf ]);
      ())

(* A work manifest with only what [uncovered_dirspaces] reads: its dirspaces and its time. *)
let wm ~created_at dirspaces =
  {
    Terrat_work_manifest3.account = ();
    base_ref = "";
    branch = None;
    branch_ref = "";
    changes =
      CCList.map
        (fun dirspace -> { Terrat_change.Dirspaceflow.dirspace; workflow = (); variables = None })
        dirspaces;
    completed_at = None;
    created_at;
    denied_dirspaces = ();
    environment = None;
    id = ();
    initiator = Terrat_work_manifest3.Initiator.System;
    params = Sln_map.String.empty;
    run_id = ();
    runs_on = None;
    state = ();
    steps = [];
    tag_query = Terrat_tag_query.any;
    target = ();
  }

let t0 = "2026-09-23T16:03:00Z"
let t1 = "2026-09-23T16:04:00Z"

let assert_dirspaces name expected actual =
  assert_eq ~eq:Dss.equal ~pp:(Dss.pp Terrat_dirspace.pp) name expected actual

(* After a restart, the slot makes the work of an abort again once, and not after each result. *)
let test_start_uncovered_dirspaces =
  Oth.test ~name:"an aborted work manifest is covered by its dirspaces or by newer work" (fun _ ->
      let uncovered = St.Start.uncovered_dirspaces in
      assert_dirspaces
        "no live work: the work of the abort is not done"
        (Dss.of_list [ tf ])
        (uncovered ~live:[] [ wm ~created_at:t0 [ tf ] ]);
      assert_dirspaces
        "a work manifest made with the aborted one does not cover other dirspaces"
        (Dss.of_list [ tf ])
        (uncovered ~live:[ wm ~created_at:t0 [ app ] ] [ wm ~created_at:t0 [ tf ] ]);
      assert_dirspaces
        "a live work manifest with the same dirspaces covers the abort"
        Dss.empty
        (uncovered ~live:[ wm ~created_at:t0 [ tf ] ] [ wm ~created_at:t0 [ tf ] ]);
      assert_dirspaces
        "newer work covers the abort, also when the commits moved and its dirspaces are different"
        Dss.empty
        (uncovered ~live:[ wm ~created_at:t1 [ app ] ] [ wm ~created_at:t0 [ tf ] ]);
      ())

let test_drift_restart_limit =
  Oth.test ~name:"a drift reconciles again only until the limit" (fun _ ->
      let check name expected restarts =
        assert_eq
          ~eq:St.Drift_result.equal_restart
          ~pp:St.Drift_result.pp_restart
          name
          expected
          (St.Drift_result.restart ~restart_on_change:true ~restarts)
      in
      check "no restart yet" St.Drift_result.Restart 0;
      check "the last restart under the limit" St.Drift_result.Restart 9;
      check "the limit stops the restarts" St.Drift_result.Limit_reached 10;
      ())

let test_drift_restart_disabled =
  Oth.test ~name:"a drift with restart_on_change off never reconciles again" (fun _ ->
      let check name restarts =
        assert_eq
          ~eq:St.Drift_result.equal_restart
          ~pp:St.Drift_result.pp_restart
          name
          St.Drift_result.Disabled
          (St.Drift_result.restart ~restart_on_change:false ~restarts)
      in
      check "no restart yet" 0;
      check "under the limit" 9;
      check "at the limit" 10;
      ())

let test_union =
  Oth.test ~name:"two comparisons of one run together" (fun _ ->
      let all = [ St.Not_impacted; St.Impacted [ tf ]; St.Impacted [ app ]; St.Unknown ] in
      assert_decision
        "not impacted with not impacted"
        St.Not_impacted
        (St.union St.Not_impacted St.Not_impacted);
      CCList.iter
        (fun impact ->
          assert_decision "not impacted adds nothing" impact (St.union St.Not_impacted impact);
          assert_decision "unknown wins, it fails safe" St.Unknown (St.union St.Unknown impact))
        all;
      assert_decision
        "the impacted dirspaces of both, sorted and once"
        (St.Impacted [ app; tf ])
        (St.union (St.Impacted [ tf; app ]) (St.Impacted [ tf ]));
      CCList.iter
        (fun a ->
          CCList.iter
            (fun b -> assert_decision "the order does not matter" (St.union a b) (St.union b a))
            all)
        all;
      ())

let test_pr_result_stale_dirspaces =
  Oth.test ~name:"the stale dirspaces of a pull request result" (fun _ ->
      let check name expected decision =
        assert_eq
          ~eq:Dss.equal
          ~pp:(Dss.pp Terrat_dirspace.pp)
          name
          (Dss.of_list expected)
          (St.Pr_result.stale_dirspaces decision [ tf; app ])
      in
      check "a fresh result has none" [] St.Pr_result.Fresh;
      check "changed files make only those stale" [ tf ] (St.Pr_result.Stale_files_changed [ tf ]);
      check "an unknown impact makes all of them stale" [ tf; app ] St.Pr_result.Stale_files_unknown;
      ())

module Ds = Terrat_vcs_provider2.Dirspace_summary

let assert_summary name expected actual =
  assert_eq ~eq:(CCOption.equal Ds.equal) ~pp:(CCFormat.Dump.option Ds.pp) name expected actual

let test_summary_decide =
  Oth.test ~name:"the summary state of a dirspace from the runs that count" (fun _ ->
      let set = Dss.of_list in
      assert_summary
        "a dirspace kept applied is applied on the head"
        (Some Ds.Applied)
        (St.Summary.decide ~applied:(set [ tf ]) ~planned:(set [ tf ]) ~failed:Dss.empty tf);
      assert_summary
        "a planned dirspace"
        (Some Ds.Planned)
        (St.Summary.decide ~applied:Dss.empty ~planned:(set [ tf ]) ~failed:Dss.empty tf);
      assert_summary
        "a dirspace with no run that counts has no state"
        None
        (St.Summary.decide ~applied:Dss.empty ~planned:Dss.empty ~failed:Dss.empty tf);
      assert_summary
        "a newest run that failed decides the state"
        (Some Ds.Failed)
        (St.Summary.decide ~applied:(set [ tf ]) ~planned:(set [ tf ]) ~failed:(set [ tf ]) tf);
      ())

let test_summary_of_result =
  Oth.test ~name:"the summary state of a dirspace after a result" (fun _ ->
      let check ?(no_changes = Dss.empty) name expected ~run ~stale success =
        assert_summary
          name
          (Some expected)
          (Some (St.Summary.of_result ~run ~stale ~no_changes tf success))
      in
      check "a fresh apply" Ds.Applied ~run:`Apply ~stale:Dss.empty true;
      check "a fresh plan" Ds.Planned ~run:`Plan ~stale:Dss.empty true;
      check
        "a stale apply must be planned again"
        Ds.Stale
        ~run:`Apply
        ~stale:(Dss.of_list [ tf ])
        true;
      check
        "a stale plan must be planned again"
        Ds.Stale
        ~run:`Plan
        ~stale:(Dss.of_list [ tf ])
        true;
      check "a failed stale apply is failed" Ds.Failed ~run:`Apply ~stale:(Dss.of_list [ tf ]) false;
      check "a failed plan is failed" Ds.Failed ~run:`Plan ~stale:Dss.empty false;
      check
        "a plan with no changes is applied"
        Ds.Applied
        ~no_changes:(Dss.of_list [ tf ])
        ~run:`Plan
        ~stale:Dss.empty
        true;
      check
        "a stale plan with no changes must be planned again"
        Ds.Stale
        ~no_changes:(Dss.of_list [ tf ])
        ~run:`Plan
        ~stale:(Dss.of_list [ tf ])
        true;
      check
        "a failed plan with no changes is failed"
        Ds.Failed
        ~no_changes:(Dss.of_list [ tf ])
        ~run:`Plan
        ~stale:Dss.empty
        false;
      ())

let test =
  Oth.parallel
    [
      test_summary_decide;
      test_summary_of_result;
      test_union;
      test_pr_result_stale_dirspaces;
      test_drift_restart_limit;
      test_drift_restart_disabled;
      test_no_change_is_not_impacted;
      test_changed_dirspaces_are_impacted;
      test_missing_tree_is_unknown;
      test_start_restarts_unless_not_impacted;
      test_start_uncovered_dirspaces;
      test_pr_result_warns_on_unknown;
      test_drift_result_reconciles_on_unknown;
    ]

let () =
  Random.self_init ();
  Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)
