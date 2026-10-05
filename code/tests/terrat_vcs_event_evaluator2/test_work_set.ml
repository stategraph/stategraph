(* The rule that decides which dirspaces run now, and whether the evaluator
   starts another round on its own.

   These are the two halves of a tree of runs (RFD 2305).  A run used to be a
   fixed list of layers, so a dirspace waited for every dirspace of the layer in
   front of it whether it depended on it or not.  Now the run that remains is
   put into layers again on every evaluation, so a dirspace waits for the
   dirspaces it depends on and for nothing else.

   The fixtures here are the system-test fixtures, built in OCaml so the whole
   sequence can be walked without a repository, a database or a VCS. *)

module Ws = Terrat_vcs_event_evaluator2.Work_set
module Tcm = Terrat_change_match3
module R = Terrat_base_repo_config_v1

let ctx = R.Ctx.make ~dest_branch:"main" ~branch:"test" ()
let tag_query s = CCResult.get_exn (Terrat_tag_query.of_string s)
let depends_on_q s = { R.Depends_on.tag_query = tag_query s; prune_on_no_change = false }

let dir ?tag ?depends_on () =
  R.Dirs.Dir.make
    ~workspaces:
      (Sln_map.String.of_list
         [
           ( "default",
             R.Dirs.Workspace.make
               ~tags:(CCOption.map_or ~default:[] (fun t -> [ t ]) tag)
               ~when_modified:
                 (R.When_modified.make ?depends_on:(CCOption.map depends_on_q depends_on) ())
               () );
         ])
    ()

let stack ?rules tq = R.Stacks.Stack.make ~type_:(R.Stacks.Type_.Stack (tag_query tq)) ?rules ()

let synthesize ~file_list ~dirs ?stacks () =
  let repo_config =
    CCResult.get_exn
      (R.derive
         ~ctx
         ~index:R.Index.empty
         ~file_list
         (R.of_view
            (R.View.make
               ~dirs:(Sln_map.String.of_list dirs)
               ?stacks:
                 (CCOption.map
                    (fun names -> R.Stacks.make ~names:(Sln_map.String.of_list names) ())
                    stacks)
               ())))
  in
  CCResult.get_exn (Tcm.synthesize_config ~index:R.Index.empty repo_config)

let changed filenames =
  CCList.map (fun filename -> Terrat_change.Diff.Change { filename }) filenames

let dirspace dir = { Terrat_dirspace.dir; workspace = "default" }

let dirs_of dirspace_configs =
  CCList.sort CCString.compare
  @@ CCList.map
       (fun {
              Tcm.Dirspace_config.dirspace = { Terrat_dirspace.dir; workspace = _ };
              file_pattern_matcher = _;
              lock_branch_target = _;
              stack_config = _;
              stack_name = _;
              stack_paths = _;
              tags = _;
              when_modified = _;
            }
          -> dir)
       dirspace_configs

let assert_dirs name expected actual =
  let show l = "[ " ^ CCString.concat "; " l ^ " ]" in
  Oth.Assert.true_
    ~fail_msg:(name ^ ": expected " ^ show expected ^ ", got " ^ show actual)
    (CCList.equal CCString.equal expected actual)

(* One evaluation.  [applied] is everything the database would call applied by
   now, which includes a dirspace whose last plan found no changes. *)
let work_set
    ~config
    ~all_matches
    ~op
    ?(tq = Terrat_tag_query.any)
    ?(outputs = CCFun.const `No_comparison)
    ?(file_changed = [])
    ?(revived = [])
    applied =
  Ws.make
    ~outputs
    ~file_changed:(Terrat_data.Dirspace_set.of_list (CCList.map dirspace file_changed))
    ~revived:(Terrat_data.Dirspace_set.of_list (CCList.map dirspace revived))
    ~config
    ~op
    ~tag_query:tq
    ~applied:(Terrat_data.Dirspace_set.of_list (CCList.map dirspace applied))
    ~dir_exists:(fun _ -> true)
    ~all_matches

let remaining_after ~config ~all_matches applied =
  (work_set ~config ~all_matches ~op:Ws.Op.Layer_plan applied).Ws.all_unapplied_matches

(* ------------------------------------------------------------------ *)
(* core/stacks/0027: two environments, one stack each, apply_after on prod. *)

let two_environments ?(stacks = true) () =
  let env_dirs =
    [
      ("dev/networking", dir ~tag:"dev" ());
      ("dev/database", dir ~tag:"dev" ~depends_on:"dir:dev/networking" ());
      ("dev/app", dir ~tag:"dev" ~depends_on:"dir:dev/database" ());
      ("prod/networking", dir ~tag:"prod" ());
      ("prod/database", dir ~tag:"prod" ~depends_on:"dir:prod/networking" ());
      ("prod/app", dir ~tag:"prod" ~depends_on:"dir:prod/database" ());
    ]
  in
  synthesize
    ~file_list:(CCList.map (fun (d, _) -> d ^ "/main.tf") env_dirs)
    ~dirs:env_dirs
    ?stacks:
      (if stacks then
         Some
           [
             ("dev", stack "dev");
             ("prod", stack ~rules:(R.Stacks.Rules.make ~apply_after:[ "dev" ] ()) "prod");
           ]
       else None)
    ()

let networking_diff = changed [ "dev/networking/main.tf"; "prod/networking/main.tf" ]

(* The seven steps of core/stacks/0027, in order.  Before RFD 2305 the run
   stopped at step 3: prod/networking sat in the first layer, apply_after held
   it back, and dev/database sat in a later layer that could never be
   reached. *)
let test_two_environments_with_stacks =
  Oth.test ~name:"0027: the run walks both environments to the end" (fun _ ->
      let config = two_environments () in
      let all_matches = Tcm.match_diff_list config networking_diff in
      let plan applied =
        dirs_of (work_set ~config ~all_matches ~op:Ws.Op.Layer_plan applied).Ws.working_set_matches
      in
      let apply applied =
        dirs_of (work_set ~config ~all_matches ~op:Ws.Op.Apply applied).Ws.working_set_matches
      in
      (* 1. The two networking directories plan together: apply_after adds no
            plan edge, so the environments interleave. *)
      assert_dirs "autoplan" [ "dev/networking"; "prod/networking" ] (plan []);
      (* 2. apply_after holds prod/networking back, so the apply takes
            dev/networking on its own. *)
      assert_dirs "first apply" [ "dev/networking" ] (apply []);
      (* 3. dev/database is free, because its only dependency is applied.
            prod/networking is still free to plan. *)
      assert_dirs "second plan" [ "dev/database"; "prod/networking" ] (plan [ "dev/networking" ]);
      assert_dirs "second apply" [ "dev/database" ] (apply [ "dev/networking" ]);
      (* 4. dev/app. *)
      assert_dirs
        "third plan"
        [ "dev/app"; "prod/networking" ]
        (plan [ "dev/networking"; "dev/database" ]);
      assert_dirs "third apply" [ "dev/app" ] (apply [ "dev/networking"; "dev/database" ]);
      (* 5. No dev dirspace is left unapplied, so prod/networking is free. *)
      let dev = [ "dev/networking"; "dev/database"; "dev/app" ] in
      assert_dirs "fourth apply" [ "prod/networking" ] (apply dev);
      (* 6, 7. The rest of prod, one round each. *)
      assert_dirs "fifth plan" [ "prod/database" ] (plan ("prod/networking" :: dev));
      assert_dirs "fifth apply" [ "prod/database" ] (apply ("prod/networking" :: dev));
      let prod_db = "prod/database" :: "prod/networking" :: dev in
      assert_dirs "sixth plan" [ "prod/app" ] (plan prod_db);
      assert_dirs "sixth apply" [ "prod/app" ] (apply prod_db);
      (* Nothing left. *)
      Oth.Assert.true_
        ~fail_msg:"the run is over"
        (CCList.is_empty (remaining_after ~config ~all_matches ("prod/app" :: prod_db)));
      ())

(* The same six directories with no stacks.  A user can walk one branch of the
   tree to its end before starting the other one, which the fixed layers made
   impossible: after dev/networking applied, the first layer held only
   prod/networking, and dev/database could not plan until it applied. *)
let test_two_environments_without_stacks =
  Oth.test ~name:"no stacks: one branch can be walked to the end" (fun _ ->
      let config = two_environments ~stacks:false () in
      let all_matches = Tcm.match_diff_list config networking_diff in
      let plan applied =
        dirs_of (work_set ~config ~all_matches ~op:Ws.Op.Layer_plan applied).Ws.working_set_matches
      in
      let apply ~tq applied =
        dirs_of (work_set ~config ~all_matches ~op:Ws.Op.Apply ~tq applied).Ws.working_set_matches
      in
      assert_dirs "autoplan" [ "dev/networking"; "prod/networking" ] (plan []);
      (* The user picks one of the two with a tag query.  Nothing holds the
         other one back. *)
      assert_dirs
        "apply dev/networking"
        [ "dev/networking" ]
        (apply ~tq:(tag_query "dir:dev/networking") []);
      assert_dirs
        "dev/database joins prod/networking"
        [ "dev/database"; "prod/networking" ]
        (plan [ "dev/networking" ]);
      assert_dirs
        "apply dev/database"
        [ "dev/database" ]
        (apply ~tq:(tag_query "dir:dev/database") [ "dev/networking" ]);
      assert_dirs
        "dev/app joins prod/networking"
        [ "dev/app"; "prod/networking" ]
        (plan [ "dev/networking"; "dev/database" ]);
      let dev = [ "dev/networking"; "dev/database"; "dev/app" ] in
      (* With dev finished, only prod/networking is ready.  Nothing ordered the
         two environments, so the user was free to interleave them. *)
      assert_dirs "only prod/networking is left ready" [ "prod/networking" ] (plan dev);
      ())

(* ------------------------------------------------------------------ *)
(* next_round_ready. *)

let ready ~config ~all_matches ~applied ~just_ran =
  Ws.next_round_ready
    ~config
    ~all_unapplied_matches:(remaining_after ~config ~all_matches applied)
    ~just_ran:(CCList.map dirspace just_ran)

(* core/layered_runs/0008: base, then database1 and database2 together, then
   webservice.  An apply of one of the two databases frees nobody -- webservice
   still waits for the other one -- so no further plan may be set going.  This is
   the negative assertion the fixture makes. *)
let layered_run_0008 () =
  let ds =
    [
      ("base", dir ());
      ("database1", dir ~depends_on:"dir:base" ());
      ("database2", dir ~depends_on:"dir:base" ());
      ("webservice", dir ~depends_on:"dir:database1 or dir:database2" ());
    ]
  in
  synthesize ~file_list:(CCList.map (fun (d, _) -> d ^ "/main.tf") ds) ~dirs:ds ()

(* core/stacks/0004: one layer, ordered only by apply_after.  The apply of tf2
   frees tf1 to APPLY, but tf1 was already planned with tf2 in the first place,
   so there is nothing to plan and no round to start. *)
let stacks_0004 () =
  synthesize
    ~file_list:[ "tf1/main.tf"; "tf2/main.tf" ]
    ~dirs:[ ("tf1", dir ~tag:"tf1" ()); ("tf2", dir ~tag:"tf2" ()) ]
    ~stacks:
      [
        ("stack1", stack ~rules:(R.Stacks.Rules.make ~apply_after:[ "stack2" ] ()) "dir:tf1");
        ("stack2", stack "dir:tf2");
      ]
    ()

let test_next_round_ready =
  Oth.test ~name:"next_round_ready: a round starts only when the first layer gains" (fun _ ->
      let config = two_environments () in
      let all_matches = Tcm.match_diff_list config networking_diff in
      let ready_here = ready ~config ~all_matches in
      (* A plan leaves everything it planned in the run, so nothing is gained
         and the run does not plan the same layer again. *)
      Oth.Assert.true_
        ~fail_msg:"a plan does not start a round"
        (not (ready_here ~applied:[] ~just_ran:[ "dev/networking"; "prod/networking" ]));
      (* An apply that frees a dependent does start one. *)
      Oth.Assert.true_
        ~fail_msg:"applying dev/networking frees dev/database"
        (ready_here ~applied:[ "dev/networking" ] ~just_ran:[ "dev/networking" ]);
      (* An apply that frees nobody does not.  prod/networking was ready before
         dev/app applied and is still ready; nothing new joined it. *)
      let dev = [ "dev/networking"; "dev/database"; "dev/app" ] in
      Oth.Assert.true_
        ~fail_msg:"applying dev/app frees nobody"
        (not (ready_here ~applied:dev ~just_ran:[ "dev/app" ]));
      Oth.Assert.true_
        ~fail_msg:"applying prod/networking frees prod/database"
        (ready_here ~applied:("prod/networking" :: dev) ~just_ran:[ "prod/networking" ]);
      (* core/layered_runs/0008. *)
      let config = layered_run_0008 () in
      let all_matches = Tcm.match_diff_list config (changed [ "base/main.tf" ]) in
      Oth.Assert.true_
        ~fail_msg:"0008: a partial apply of a layer frees nobody"
        (not
           (ready ~config ~all_matches ~applied:[ "base"; "database1" ] ~just_ran:[ "database1" ]));
      (* core/stacks/0004. *)
      let config = stacks_0004 () in
      let all_matches = Tcm.match_diff_list config (changed [ "tf1/main.tf"; "tf2/main.tf" ]) in
      Oth.Assert.true_
        ~fail_msg:"0004: apply_after frees an apply, not a plan"
        (not (ready ~config ~all_matches ~applied:[ "tf2" ] ~just_ran:[ "tf2" ]));
      ())

(* An explicit tag query may name a dirspace that is already applied -- a
   dirspace whose last plan found no changes counts as applied -- so a scoped
   re-plan has to reach it.  A layer selection would come up empty and tell the
   user everything was applied. *)
let test_explicit_plan_reaches_an_applied_dirspace =
  Oth.test ~name:"an explicit query can re-plan an applied dirspace" (fun _ ->
      let config = two_environments () in
      let all_matches = Tcm.match_diff_list config networking_diff in
      let selected =
        dirs_of
          (work_set
             ~config
             ~all_matches
             ~op:Ws.Op.Explicit_plan
             ~tq:(tag_query "dir:dev/networking")
             [ "dev/networking" ])
            .Ws.working_set_matches
      in
      assert_dirs "explicit plan" [ "dev/networking" ] selected;
      (* The same query under a layer selection selects nothing, because
         dev/networking has left the run. *)
      assert_dirs
        "layer plan"
        []
        (dirs_of
           (work_set
              ~config
              ~all_matches
              ~op:Ws.Op.Layer_plan
              ~tq:(tag_query "dir:dev/networking")
              [ "dev/networking" ])
             .Ws.working_set_matches);
      ())

(* A directory that has been deleted cannot run, and it must not hold its
   dependents back either. *)
let test_a_deleted_directory_does_not_block =
  Oth.test ~name:"a dirspace whose directory is gone holds nothing back" (fun _ ->
      let config = two_environments () in
      let all_matches = Tcm.match_diff_list config networking_diff in
      let { Ws.working_set_matches; all_unapplied_matches = _; working_layer = _; pruned = _ } =
        Ws.make
          ~outputs:(CCFun.const `No_comparison)
          ~file_changed:Terrat_data.Dirspace_set.empty
          ~revived:Terrat_data.Dirspace_set.empty
          ~config
          ~op:Ws.Op.Layer_plan
          ~tag_query:Terrat_tag_query.any
          ~applied:Terrat_data.Dirspace_set.empty
          ~dir_exists:(fun d -> not (CCString.equal "dev/networking" d))
          ~all_matches
      in
      assert_dirs
        "dev/database takes the place of the deleted dev/networking"
        [ "dev/database"; "prod/networking" ]
        (dirs_of working_set_matches);
      ())

(* ------------------------------------------------------------------ *)
(* RFD 2110: pruning on outputs.  A dependent reached through an [outputs:]
   term runs only if the output it names changed between the baseline apply
   and the current apply of its dependency.  The outputs are in the custom
   engine layout, so each case reads as the JSON the engine printed. *)

let rfd_2110 = [ "rfd_2110" ]

(* [outputs] is (dir, baseline, current) for each applied dirspace.  [None] is
   an apply that recorded no outputs.  An applied dirspace with no entry is one
   whose plan had no changes: it recorded no outputs, and none of them changed. *)
let outputs_of outputs ds =
  match
    CCList.find_map
      (fun (dir, baseline, current) ->
        if Terrat_dirspace.equal (dirspace dir) ds then
          Some
            {
              Terrat_output_diff.shape = Terrat_output_diff.Raw;
              baseline = CCOption.map Yojson.Safe.from_string baseline;
              current = CCOption.map Yojson.Safe.from_string current;
            }
        else None)
      outputs
  with
  | Some diff -> `Diff diff
  | None -> `Unchanged

let synthesize_dirs ds =
  synthesize ~file_list:(CCList.map (fun (d, _) -> d ^ "/main.tf") ds) ~dirs:ds ()

(* One evaluation after [applied], asserting what runs now and what is left of
   the run.  An empty [remaining] is a run that is complete. *)
let assert_run
    ?(op = Ws.Op.Layer_plan)
    ?tq
    ?revived
    ?pruned:expected_pruned
    ~config
    ~diff
    ~applied
    ~outputs
    ~working
    ~remaining
    name =
  let all_matches = Tcm.match_diff_list config (changed diff) in
  let { Ws.working_set_matches; all_unapplied_matches; working_layer = _; pruned } =
    work_set
      ~config
      ~all_matches
      ~op
      ?tq
      ~outputs:(outputs_of outputs)
      ~file_changed:(CCList.map Filename.dirname diff)
      ?revived
      applied
  in
  CCOption.iter
    (fun expected ->
      assert_dirs
        (name ^ ": pruned")
        expected
        (CCList.map
           (fun { Terrat_dirspace.dir; workspace = _ } -> dir)
           (Terrat_data.Dirspace_set.to_list pruned)))
    expected_pruned;
  assert_dirs (name ^ ": runs now") working (dirs_of working_set_matches);
  assert_dirs
    (name ^ ": left in the run")
    remaining
    (dirs_of (CCList.flatten all_unapplied_matches))

let chain_of_two () =
  synthesize_dirs [ ("ds1", dir ()); ("ds2", dir ~depends_on:"a in outputs:ds1" ()) ]

let test_rfd_2110_pr_1 =
  Oth.test ~tags:rfd_2110 ~name:"PR-1: an unchanged output prunes the dependent" (fun _ ->
      assert_run
        ~config:(chain_of_two ())
        ~diff:[ "ds1/main.tf" ]
        ~applied:[ "ds1" ]
        ~outputs:[ ("ds1", Some {|{"a": 1}|}, Some {|{"a": 1, "b": 2}|}) ]
        ~pruned:[ "ds2" ]
        ~working:[]
        ~remaining:[]
        "PR-1";
      ())

let test_rfd_2110_pr_2 =
  Oth.test ~tags:rfd_2110 ~name:"PR-2: a changed output runs the dependent" (fun _ ->
      assert_run
        ~config:(chain_of_two ())
        ~diff:[ "ds1/main.tf" ]
        ~applied:[ "ds1" ]
        ~outputs:[ ("ds1", Some {|{"a": 1}|}, Some {|{"a": 2}|}) ]
        ~working:[ "ds2" ]
        ~remaining:[ "ds2" ]
        "PR-2";
      ())

let chain_of_three ds3_depends_on =
  synthesize_dirs
    [
      ("ds1", dir ());
      ("ds2", dir ~depends_on:"a in outputs:ds1" ());
      ("ds3", dir ~depends_on:ds3_depends_on ());
    ]

let test_rfd_2110_pr_3 =
  Oth.test ~tags:rfd_2110 ~name:"PR-3: a pruned dependent prunes its whole branch" (fun _ ->
      assert_run
        ~config:(chain_of_three "b in outputs:ds2")
        ~diff:[ "ds1/main.tf" ]
        ~applied:[ "ds1" ]
        ~outputs:[ ("ds1", Some {|{"a": 1}|}, Some {|{"a": 1}|}) ]
        ~pruned:[ "ds2"; "ds3" ]
        ~working:[]
        ~remaining:[]
        "PR-3";
      ())

let test_rfd_2110_pr_4 =
  Oth.test
    ~tags:rfd_2110
    ~name:"PR-4: a dependent that also reads a changed output of the root runs"
    (fun _ ->
      assert_run
        ~config:(chain_of_three "b in outputs:ds2 or c in outputs:ds1")
        ~diff:[ "ds1/main.tf" ]
        ~applied:[ "ds1" ]
        ~outputs:[ ("ds1", Some {|{"a": 1, "c": 1}|}, Some {|{"a": 1, "c": 2}|}) ]
        ~working:[ "ds3" ]
        ~remaining:[ "ds3" ]
        "PR-4";
      ())

let test_rfd_2110_pr_5 =
  Oth.test ~tags:rfd_2110 ~name:"PR-5: no output changed prunes the whole branch" (fun _ ->
      assert_run
        ~config:(chain_of_three "b in outputs:ds2 or c in outputs:ds1")
        ~diff:[ "ds1/main.tf" ]
        ~applied:[ "ds1" ]
        ~outputs:[ ("ds1", Some {|{"a": 1, "c": 1}|}, Some {|{"a": 1, "c": 1}|}) ]
        ~working:[]
        ~remaining:[]
        "PR-5";
      ())

(* A5: output pruning removes only a change that comes from [depends_on]. *)
let test_rfd_2110_pr_6 =
  Oth.test
    ~tags:rfd_2110
    ~name:"PR-6: a dependent with its own file changes is not pruned"
    (fun _ ->
      assert_run
        ~config:(chain_of_two ())
        ~diff:[ "ds1/main.tf"; "ds2/main.tf" ]
        ~applied:[ "ds1" ]
        ~outputs:[ ("ds1", Some {|{"a": 1}|}, Some {|{"a": 1}|}) ]
        ~working:[ "ds2" ]
        ~remaining:[ "ds2" ]
        "PR-6";
      ())

(* The RFD writes this query with [and].  A [depends_on] is evaluated against one
   candidate dependency at a time, so an [and] of two directories matches no
   candidate, and [or] is the query that makes [ds3] depend on both. *)
let test_rfd_2110_pr_7 =
  Oth.test ~tags:rfd_2110 ~name:"PR-7: a dependent waits for a dependency not yet applied" (fun _ ->
      let config =
        synthesize_dirs
          [
            ("ds1", dir ());
            ("ds2", dir ());
            ("ds3", dir ~depends_on:"a in outputs:ds1 or b in outputs:ds2" ());
          ]
      in
      assert_run
        ~config
        ~diff:[ "ds1/main.tf"; "ds2/main.tf" ]
        ~applied:[ "ds1" ]
        ~outputs:[ ("ds1", Some {|{"a": 1}|}, Some {|{"a": 2}|}) ]
        ~working:[ "ds2" ]
        ~remaining:[ "ds2"; "ds3" ]
        "PR-7";
      (* Not pruned either when [a] did not change: [b] can still change when
         [ds2] applies. *)
      assert_run
        ~config
        ~diff:[ "ds1/main.tf"; "ds2/main.tf" ]
        ~applied:[ "ds1" ]
        ~outputs:[ ("ds1", Some {|{"a": 1}|}, Some {|{"a": 1}|}) ]
        ~working:[ "ds2" ]
        ~remaining:[ "ds2"; "ds3" ]
        "PR-7 with a not changed";
      ())

(* A4: a dependency with no baseline has a baseline of [null]. *)
let test_rfd_2110_pr_8 =
  Oth.test ~tags:rfd_2110 ~name:"PR-8: a dependency with no baseline runs the dependent" (fun _ ->
      assert_run
        ~config:(chain_of_two ())
        ~diff:[ "ds1/main.tf" ]
        ~applied:[ "ds1" ]
        ~outputs:[ ("ds1", None, Some {|{"a": "x"}|}) ]
        ~working:[ "ds2" ]
        ~remaining:[ "ds2" ]
        "PR-8";
      ())

let test_rfd_2110_pr_9 =
  Oth.test ~tags:rfd_2110 ~name:"PR-9: two independent chains are pruned independently" (fun _ ->
      assert_run
        ~config:
          (synthesize_dirs
             [
               ("ds1", dir ());
               ("ds2", dir ~depends_on:"a in outputs:ds1" ());
               ("ds4", dir ());
               ("ds5", dir ~depends_on:"a in outputs:ds4" ());
             ])
        ~diff:[ "ds1/main.tf"; "ds4/main.tf" ]
        ~applied:[ "ds1"; "ds4" ]
        ~outputs:
          [
            ("ds1", Some {|{"a": 1}|}, Some {|{"a": 1}|});
            ("ds4", Some {|{"a": 1}|}, Some {|{"a": 2}|});
          ]
        ~working:[ "ds5" ]
        ~remaining:[ "ds5" ]
        "PR-9";
      ())

let test_rfd_2110_pr_10 =
  Oth.test ~tags:rfd_2110 ~name:"PR-10: relative_outputs prunes inside a stack" (fun _ ->
      let ds =
        [
          ("st/ds1", dir ~tag:"st" ());
          ("st/ds2", dir ~tag:"st" ~depends_on:"relative_outputs:../ds1" ());
        ]
      in
      let config =
        synthesize
          ~file_list:(CCList.map (fun (d, _) -> d ^ "/main.tf") ds)
          ~dirs:ds
          ~stacks:[ ("st", stack "st") ]
          ()
      in
      (* The stack order is the order of [relative_outputs], as for [relative_dir]. *)
      assert_run
        ~config
        ~diff:[ "st/ds1/main.tf" ]
        ~applied:[]
        ~outputs:[]
        ~working:[ "st/ds1" ]
        ~remaining:[ "st/ds1"; "st/ds2" ]
        "PR-10 before the apply";
      assert_run
        ~config
        ~diff:[ "st/ds1/main.tf" ]
        ~applied:[ "st/ds1" ]
        ~outputs:[ ("st/ds1", Some {|{"a": 1}|}, Some {|{"a": 1}|}) ]
        ~working:[]
        ~remaining:[]
        "PR-10";
      ())

(* RFD 2110, "Explicit planning".  An explicit [terrateam plan dir:...] brings a
   pruned dirspace back into the run.  [revived] is what the caller passes for
   it: the dirspaces the query names, and the dirspaces that have a plan or an
   apply in the pull request, which is what keeps a revived dirspace in the run
   after the evaluation that carried the query. *)

let test_rfd_2110_pr_11 =
  Oth.test ~tags:rfd_2110 ~name:"PR-11: an explicit plan revives a pruned dependent" (fun _ ->
      assert_run
        ~op:Ws.Op.Explicit_plan
        ~tq:(tag_query "dir:ds2")
        ~revived:[ "ds2" ]
        ~config:(chain_of_two ())
        ~diff:[ "ds1/main.tf" ]
        ~applied:[ "ds1" ]
        ~outputs:[ ("ds1", Some {|{"a": 1}|}, Some {|{"a": 1}|}) ]
        ~working:[ "ds2" ]
        ~remaining:[ "ds2" ]
        "PR-11";
      ())

(* The revived dirspace is not applied yet, thus its [outputs:] terms mean the
   same as [dir:] and its dependent waits for it. *)
let test_rfd_2110_pr_12 =
  Oth.test ~tags:rfd_2110 ~name:"PR-12: the branch of a revived dirspace waits for it" (fun _ ->
      assert_run
        ~revived:[ "ds2" ]
        ~config:(chain_of_three "b in outputs:ds2")
        ~diff:[ "ds1/main.tf" ]
        ~applied:[ "ds1" ]
        ~outputs:[ ("ds1", Some {|{"a": 1}|}, Some {|{"a": 1}|}) ]
        ~pruned:[]
        ~working:[ "ds2" ]
        ~remaining:[ "ds2"; "ds3" ]
        "PR-12";
      ())

let test_rfd_2110_pr_13 =
  Oth.test
    ~tags:rfd_2110
    ~name:"PR-13: a revived dirspace with unchanged outputs prunes its branch again"
    (fun _ ->
      assert_run
        ~revived:[ "ds2" ]
        ~config:(chain_of_three "b in outputs:ds2")
        ~diff:[ "ds1/main.tf" ]
        ~applied:[ "ds1"; "ds2" ]
        ~outputs:
          [
            ("ds1", Some {|{"a": 1}|}, Some {|{"a": 1}|});
            ("ds2", Some {|{"b": 1}|}, Some {|{"b": 1}|});
          ]
        ~working:[]
        ~remaining:[]
        "PR-13";
      ())

let test_rfd_2110_pr_14 =
  Oth.test
    ~tags:rfd_2110
    ~name:"PR-14: a revived dirspace with changed outputs runs its branch"
    (fun _ ->
      assert_run
        ~revived:[ "ds2" ]
        ~config:(chain_of_three "b in outputs:ds2")
        ~diff:[ "ds1/main.tf" ]
        ~applied:[ "ds1"; "ds2" ]
        ~outputs:
          [
            ("ds1", Some {|{"a": 1}|}, Some {|{"a": 1}|});
            ("ds2", Some {|{"b": 1}|}, Some {|{"b": 2}|});
          ]
        ~working:[ "ds3" ]
        ~remaining:[ "ds3" ]
        "PR-14";
      ())

(* Only a dirspace of the unpruned run can be revived.  [ds4] is in the
   configuration but not in the run, thus it does nothing: in particular it does
   not keep [ds2] in the run through the [dir:ds4] term. *)
let test_rfd_2110_pr_15 =
  Oth.test
    ~tags:rfd_2110
    ~name:"PR-15: a dirspace outside the unpruned run cannot be revived"
    (fun _ ->
      assert_run
        ~op:Ws.Op.Explicit_plan
        ~tq:(tag_query "dir:ds4")
        ~revived:[ "ds4" ]
        ~config:
          (synthesize_dirs
             [
               ("ds1", dir ());
               ("ds2", dir ~depends_on:"a in outputs:ds1 or dir:ds4" ());
               ("ds4", dir ());
             ])
        ~diff:[ "ds1/main.tf" ]
        ~applied:[ "ds1" ]
        ~outputs:[ ("ds1", Some {|{"a": 1}|}, Some {|{"a": 1}|}) ]
        ~working:[]
        ~remaining:[]
        "PR-15";
      ())

(* RFD 2110, revdate 2026-10-03: a plan that is a no-op counts as applied and
   records no outputs, so no [outputs:] term matches it.  [ds1] is applied and
   has no entry in [outputs], which is what the database gives for it. *)
let test_rfd_2110_pr_16 =
  Oth.test ~tags:rfd_2110 ~name:"PR-16: a no-op dependency prunes the dependent" (fun _ ->
      assert_run
        ~config:(chain_of_two ())
        ~diff:[ "ds1/main.tf" ]
        ~applied:[ "ds1" ]
        ~outputs:[]
        ~pruned:[ "ds2" ]
        ~working:[]
        ~remaining:[]
        "PR-16";
      ())

let test =
  Oth.parallel
    [
      test_two_environments_with_stacks;
      test_two_environments_without_stacks;
      test_next_round_ready;
      test_explicit_plan_reaches_an_applied_dirspace;
      test_a_deleted_directory_does_not_block;
      test_rfd_2110_pr_1;
      test_rfd_2110_pr_2;
      test_rfd_2110_pr_3;
      test_rfd_2110_pr_4;
      test_rfd_2110_pr_5;
      test_rfd_2110_pr_6;
      test_rfd_2110_pr_7;
      test_rfd_2110_pr_8;
      test_rfd_2110_pr_9;
      test_rfd_2110_pr_10;
      test_rfd_2110_pr_11;
      test_rfd_2110_pr_12;
      test_rfd_2110_pr_13;
      test_rfd_2110_pr_14;
      test_rfd_2110_pr_15;
      test_rfd_2110_pr_16;
    ]

let () =
  Random.self_init ();
  Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)
