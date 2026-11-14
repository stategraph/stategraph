(* Tests for how dirspaceflows are partitioned into batches, where each batch becomes its own work
   manifest.

   The invariants a batch must satisfy:

   1. All dirspaceflows in a batch agree on (environment, runs_on).

   2. No batch contains two dirspaceflows in the same dir.

   3. No batch is larger than max_workspaces_per_batch.

   And, as much as the above allows, batches should be as large as possible: a user setting
   max_workspaces_per_batch should get batches of that size. *)

module Batch = Terrat_vcs_event_evaluator2.Batch
module Dsf = Terrat_change.Dirspaceflow
module Merge_steps = Terrat_vcs_event_evaluator2.Merge_steps
module Step = Terrat_work_manifest3.Step
module V1 = Terrat_base_repo_config_v1
module Ms = V1.Batch_runs.Merge_steps
module Phase = Terrat_job_context.Compute_node.Capabilities.Merge_phase
module Compute_node = Terrat_vcs_event_evaluator2.Compute_node
module Tjc = Terrat_job_context
module Wm = Terrat_work_manifest3
module We = V1.Workflows.Entry

(* The hard ceiling of a node, which is also the default of
   [batch_runs.max_work_manifests_per_node]. *)
let max_per_node = Compute_node.max_work_manifests_per_compute_node

let dsf ?environment ?runs_on ~dir ~workspace () =
  {
    Dsf.dirspace = { Terrat_dirspace.dir; workspace };
    workflow =
      Some
        {
          Dsf.Workflow.idx = 0;
          workflow = We.make ?environment ~runs_on ~tag_query:V1.Tag_query.any ();
        };
    variables = None;
  }

let batch_sizes batches = batches |> CCList.map (fun (_, dsfs) -> CCList.length dsfs)

(* Batches sorted by size so assertions do not depend on batch ordering. *)
let sorted_batch_sizes batches = batches |> batch_sizes |> CCList.sort CCInt.compare

let dirs_of_batch (_, dsfs) =
  CCList.map (fun { Dsf.dirspace = { Terrat_dirspace.dir; _ }; _ } -> dir) dsfs

let dirspaces_of batches =
  batches
  |> CCList.flat_map (fun (_, dsfs) -> CCList.map Dsf.to_dirspace dsfs)
  |> CCList.sort Terrat_dirspace.compare

let show_sizes batches =
  "[" ^ CCString.concat "; " (CCList.map CCInt.to_string (batch_sizes batches)) ^ "]"

let fail_sizes name expected batches =
  failwith (Printf.sprintf "%s: expected %s, got %s" name expected (show_sizes batches))

(* The regression.  Two dirs, each with a prod and a dev workspace.  Dir isolation only requires
   that no single batch hold two workspaces of the same dir, which is satisfied by {A/prod, B/prod}
   and {A/dev, B/dev}.  Partitioning by dir before grouping by environment mixes environments into
   the same partition, which the environment grouping then shatters into single-dirspace batches,
   making max_workspaces_per_batch unreachable. *)
let test_batches_across_dirs_within_an_environment =
  Oth.test ~name:"partition: batches across dirs within an environment" (fun _ ->
      let dirspaceflows =
        [
          dsf ~environment:"prod" ~dir:"a" ~workspace:"prod" ();
          dsf ~environment:"dev" ~dir:"a" ~workspace:"dev" ();
          dsf ~environment:"prod" ~dir:"b" ~workspace:"prod" ();
          dsf ~environment:"dev" ~dir:"b" ~workspace:"dev" ();
        ]
      in
      let batches = Batch.partition_by_run_params ~max_workspaces_per_batch:50 dirspaceflows in
      match sorted_batch_sizes batches with
      | [ 2; 2 ] -> ()
      | _ -> fail_sizes "two dirs x two envs, max=50" "two batches of 2 ([2; 2])" batches)

(* max_workspaces_per_batch is an int with no minimum in the config schema, and CCList.chunks raises
   Invalid_argument for n < 1. *)
let test_max_workspaces_per_batch_of_zero =
  Oth.test ~name:"partition: max_workspaces_per_batch of zero does not raise" (fun _ ->
      let dirspaceflows =
        [ dsf ~dir:"a" ~workspace:"default" (); dsf ~dir:"b" ~workspace:"default" () ]
      in
      match Batch.partition_by_run_params ~max_workspaces_per_batch:0 dirspaceflows with
      | batches ->
          if CCList.length (dirspaces_of batches) <> 2 then failwith "max=0 dropped dirspaces"
      | exception Invalid_argument msg ->
          failwith (Printf.sprintf "max=0 raised Invalid_argument: %s" msg))

let test_environments_are_not_mixed =
  Oth.test ~name:"partition: a batch never mixes environments" (fun _ ->
      let dirspaceflows =
        CCList.flat_map
          (fun dir ->
            [
              dsf ~environment:"prod" ~dir ~workspace:"prod" ();
              dsf ~environment:"dev" ~dir ~workspace:"dev" ();
            ])
          [ "a"; "b"; "c"; "d" ]
      in
      let batches = Batch.partition_by_run_params ~max_workspaces_per_batch:50 dirspaceflows in
      CCList.iter
        (fun (_, dsfs) ->
          let envs =
            dsfs
            |> CCList.filter_map (fun { Dsf.workflow; _ } ->
                CCOption.map
                  (fun { Dsf.Workflow.workflow = { We.environment; _ }; _ } -> environment)
                  workflow)
            |> CCList.uniq ~eq:(CCOption.equal CCString.equal)
          in
          if CCList.length envs > 1 then failwith "a batch mixed environments")
        batches)

let test_runs_on_is_not_mixed =
  Oth.test ~name:"partition: a batch never mixes runs_on" (fun _ ->
      let dirspaceflows =
        CCList.flat_map
          (fun dir ->
            [
              dsf ~runs_on:(`String "big") ~dir ~workspace:"big" ();
              dsf ~runs_on:(`String "small") ~dir ~workspace:"small" ();
            ])
          [ "a"; "b"; "c"; "d" ]
      in
      let batches = Batch.partition_by_run_params ~max_workspaces_per_batch:50 dirspaceflows in
      CCList.iter
        (fun (_, dsfs) ->
          let runs_on =
            dsfs
            |> CCList.filter_map (fun { Dsf.workflow; _ } ->
                CCOption.map
                  (fun { Dsf.Workflow.workflow = { We.runs_on; _ }; _ } -> runs_on)
                  workflow)
            |> CCList.uniq ~eq:(CCOption.equal Yojson.Safe.equal)
          in
          if CCList.length runs_on > 1 then failwith "a batch mixed runs_on")
        batches)

let test_dirs_are_isolated_within_a_batch =
  Oth.test ~name:"partition: a batch never holds two workspaces of the same dir" (fun _ ->
      let dirspaceflows =
        CCList.flat_map
          (fun dir ->
            CCList.map
              (fun i -> dsf ~dir ~workspace:(Printf.sprintf "ws%d" i) ())
              (CCList.range 1 4))
          [ "a"; "b"; "c" ]
      in
      let batches = Batch.partition_by_run_params ~max_workspaces_per_batch:50 dirspaceflows in
      CCList.iter
        (fun batch ->
          let dirs = dirs_of_batch batch in
          if CCList.length (CCList.uniq ~eq:CCString.equal dirs) <> CCList.length dirs then
            failwith "a batch held two workspaces of the same dir")
        batches)

let test_chunks_at_max_workspaces_per_batch =
  Oth.test ~name:"partition: chunks at max_workspaces_per_batch" (fun _ ->
      let dirspaceflows =
        CCList.map
          (fun i -> dsf ~dir:(Printf.sprintf "dir%03d" i) ~workspace:"default" ())
          (CCList.range 1 100)
      in
      let batches = Batch.partition_by_run_params ~max_workspaces_per_batch:50 dirspaceflows in
      match sorted_batch_sizes batches with
      | [ 50; 50 ] -> ()
      | _ -> fail_sizes "100 distinct dirs, one env, max=50" "two batches of 50 ([50; 50])" batches)

(* Dir isolation wins here: every workspace shares a dir, so each must get its own batch no matter
   what max_workspaces_per_batch says.  This case is not fixable by ordering. *)
let test_single_dir_gets_one_workspace_per_batch =
  Oth.test ~name:"partition: all workspaces in one dir get a batch each" (fun _ ->
      let dirspaceflows =
        CCList.map
          (fun i -> dsf ~dir:"a" ~workspace:(Printf.sprintf "ws%02d" i) ())
          (CCList.range 1 10)
      in
      let batches = Batch.partition_by_run_params ~max_workspaces_per_batch:50 dirspaceflows in
      if sorted_batch_sizes batches <> CCList.replicate 10 1 then
        fail_sizes "10 workspaces in one dir, max=50" "ten batches of 1" batches)

let test_partition_is_deterministic =
  Oth.test ~name:"partition: input order does not change the batches" (fun _ ->
      let dirspaceflows =
        CCList.flat_map
          (fun dir ->
            [
              dsf ~environment:"prod" ~dir ~workspace:"prod" ();
              dsf ~environment:"dev" ~dir ~workspace:"dev" ();
            ])
          [ "a"; "b"; "c"; "d" ]
      in
      let batches_of dsfs =
        dsfs
        |> Batch.partition_by_run_params ~max_workspaces_per_batch:3
        |> CCList.map (fun (_, dsfs) ->
            dsfs |> CCList.map Dsf.to_dirspace |> CCList.sort Terrat_dirspace.compare)
        |> CCList.sort (CCList.compare Terrat_dirspace.compare)
      in
      let expected = batches_of dirspaceflows in
      let reversed = batches_of (CCList.rev dirspaceflows) in
      if expected <> reversed then failwith "reversing the input changed the batches")

let test_every_dirspace_appears_exactly_once =
  Oth.test ~name:"partition: every dirspace appears in exactly one batch" (fun _ ->
      let dirspaceflows =
        CCList.flat_map
          (fun dir ->
            CCList.map
              (fun i ->
                dsf
                  ~environment:(Printf.sprintf "env%d" (i mod 3))
                  ~dir
                  ~workspace:(Printf.sprintf "ws%d" i)
                  ())
              (CCList.range 1 5))
          [ "a"; "b"; "c" ]
      in
      let batches = Batch.partition_by_run_params ~max_workspaces_per_batch:4 dirspaceflows in
      let expected =
        dirspaceflows |> CCList.map Dsf.to_dirspace |> CCList.sort Terrat_dirspace.compare
      in
      if dirspaces_of batches <> expected then
        failwith "batches did not contain exactly the input dirspaces")

(* The ladder of [batch_runs.merge_steps]: each value permits the steps of the value before
   it, and one step more.  The table pins every pair.  A wrong answer either loses an action
   run or gives a step the environment of a run that it must not join.

   Every pair is asked once for each phase a run can be in, because a rung of the ladder
   must give the same answer whatever the run has done.  Only [by_phase] reads the phase. *)
let test_merge_steps_ladder =
  Oth.test ~name:"merge_steps: the step ladder" (fun _ ->
      CCList.iter
        (fun (merge_steps, step, expected) ->
          CCList.iter
            (fun node_phase ->
              Oth.Assert.true_
                ~fail_msg:(Ms.show merge_steps ^ " " ^ Step.to_string step)
                (Merge_steps.permits merge_steps ~node_phase [ step ] = expected))
            [ None; Some Phase.Setup; Some Phase.Layer ])
        [
          (Ms.None, Step.Build_tree, false);
          (Ms.None, Step.Build_config, false);
          (Ms.None, Step.Index, false);
          (Ms.None, Step.Plan, false);
          (Ms.None, Step.Apply, false);
          (Ms.None, Step.Unsafe_apply, false);
          (Ms.Setup, Step.Build_tree, true);
          (Ms.Setup, Step.Build_config, true);
          (Ms.Setup, Step.Index, true);
          (Ms.Setup, Step.Plan, false);
          (Ms.Setup, Step.Apply, false);
          (Ms.Setup, Step.Unsafe_apply, false);
          (Ms.Setup_and_plan, Step.Build_tree, true);
          (Ms.Setup_and_plan, Step.Build_config, true);
          (Ms.Setup_and_plan, Step.Index, true);
          (Ms.Setup_and_plan, Step.Plan, true);
          (Ms.Setup_and_plan, Step.Apply, false);
          (Ms.Setup_and_plan, Step.Unsafe_apply, false);
          (Ms.All, Step.Build_tree, true);
          (Ms.All, Step.Build_config, true);
          (Ms.All, Step.Index, true);
          (Ms.All, Step.Plan, true);
          (Ms.All, Step.Apply, true);
          (Ms.All, Step.Unsafe_apply, true);
        ];
      ())

(* A work manifest of no step, or of more than one, takes an action run of its own.  The rule
   answers for one step. *)
let test_merge_steps_only_one_step_joins =
  Oth.test ~name:"merge_steps: only one step joins" (fun _ ->
      CCList.iter
        (fun merge_steps ->
          Oth.Assert.true_
            ~fail_msg:("no step: " ^ Ms.show merge_steps)
            (not (Merge_steps.permits merge_steps ~node_phase:(Some Phase.Setup) []));
          Oth.Assert.true_
            ~fail_msg:("two steps: " ^ Ms.show merge_steps)
            (not
               (Merge_steps.permits
                  merge_steps
                  ~node_phase:(Some Phase.Setup)
                  [ Step.Build_tree; Step.Plan ])))
        [ Ms.All; Ms.By_phase ];
      ())

(* [by_phase] is not a rung of the ladder.  It permits every step, as [all] does, but only
   into a run of the same phase, so the setup work and the layer work never share a run.
   The table pins every pair of phase and step.

   This is the whole of the value: a wrong answer here either puts a plan on the run of the
   config builder, which is what [by_phase] exists to stop, or breaks the chain of layers
   into a run for each layer, which is what it exists to save. *)
let test_merge_steps_by_phase =
  Oth.test ~name:"merge_steps: by_phase holds a wall between the phases" (fun _ ->
      CCList.iter
        (fun (node_phase, step, expected) ->
          Oth.Assert.true_
            ~fail_msg:(Phase.show node_phase ^ " " ^ Step.to_string step)
            (Merge_steps.permits Ms.By_phase ~node_phase:(Some node_phase) [ step ] = expected))
        [
          (Phase.Setup, Step.Build_tree, true);
          (Phase.Setup, Step.Build_config, true);
          (Phase.Setup, Step.Index, true);
          (Phase.Setup, Step.Plan, false);
          (Phase.Setup, Step.Apply, false);
          (Phase.Setup, Step.Unsafe_apply, false);
          (Phase.Layer, Step.Build_tree, false);
          (Phase.Layer, Step.Build_config, false);
          (Phase.Layer, Step.Index, false);
          (Phase.Layer, Step.Plan, true);
          (Phase.Layer, Step.Apply, true);
          (Phase.Layer, Step.Unsafe_apply, true);
        ];
      ())

(* A run that has no phase takes nothing under [by_phase].  A row an earlier version of the
   server wrote has no phase, and so has a run made for a work manifest of no step or of
   several.  The safe answer is a run of its own, and not a guess. *)
let test_merge_steps_by_phase_needs_a_phase =
  Oth.test ~name:"merge_steps: by_phase gives nothing to a run with no phase" (fun _ ->
      CCList.iter
        (fun step ->
          Oth.Assert.true_
            ~fail_msg:(Step.to_string step)
            (not (Merge_steps.permits Ms.By_phase ~node_phase:None [ step ])))
        [ Step.Build_tree; Step.Build_config; Step.Index; Step.Plan; Step.Apply; Step.Unsafe_apply ];
      ())

(* [phase_of] is what writes the phase of a run when the run is made, so it must agree with
   the wall that [permits] holds.  A work manifest of no step, or of several, has no phase,
   which is what makes such a run take nothing. *)
let test_phase_of =
  Oth.test ~name:"merge_steps: the phase of a work manifest" (fun _ ->
      CCList.iter
        (fun (steps, expected) ->
          Oth.Assert.true_
            ~fail_msg:(CCString.concat "," (CCList.map Step.to_string steps))
            (Merge_steps.phase_of steps = expected))
        [
          ([ Step.Build_tree ], Some Phase.Setup);
          ([ Step.Build_config ], Some Phase.Setup);
          ([ Step.Index ], Some Phase.Setup);
          ([ Step.Plan ], Some Phase.Layer);
          ([ Step.Apply ], Some Phase.Layer);
          ([ Step.Unsafe_apply ], Some Phase.Layer);
          ([], None);
          ([ Step.Build_tree; Step.Plan ], None);
        ];
      ())

(* A work manifest, with only the fields these two rules read given a value that
   matters.  [dirspaceflows] is what the node is charged for. *)
let wm ?(branch_ref = "deadbeef") ?(environment = None) ?(dirspaceflows = []) steps =
  {
    Wm.account = ();
    base_ref = "base";
    branch = None;
    branch_ref;
    changes = dirspaceflows;
    completed_at = None;
    created_at = "";
    denied_dirspaces = [];
    environment;
    id = Uuidm.nil;
    initiator = Wm.Initiator.System;
    params = Sln_map.String.empty;
    run_id = None;
    runs_on = None;
    state = Wm.State.Queued;
    steps;
    tag_query = Terrat_tag_query.any;
    target = ();
  }

(* A node that is going, made from the capabilities of the work manifest it was
   made for.  [Starting] is the one state that can take more work. *)
let node work_manifest =
  {
    Tjc.Compute_node.id = Uuidm.nil;
    state = Tjc.Compute_node.State.Starting;
    capabilities = Compute_node.capabilities_of work_manifest;
    created_at = "";
    updated_at = "";
  }

(* The wiring of [by_phase]: [capabilities_of] must write the phase of the work
   manifest the node is made for.  A node with no phase takes nothing under
   [by_phase], so a regression here turns [by_phase] into [none] without a word,
   and the count of action runs is the only thing that would show it. *)
let test_capabilities_of_writes_the_phase =
  Oth.test ~name:"compute_node: the capabilities carry the phase of the work" (fun _ ->
      CCList.iter
        (fun (steps, expected) ->
          let { Tjc.Compute_node.Capabilities.merge_phase; _ } =
            Compute_node.capabilities_of (wm steps)
          in
          Oth.Assert.true_
            ~fail_msg:(CCString.concat "," (CCList.map Step.to_string steps))
            (merge_phase = expected))
        [
          ([ Step.Build_tree ], Some Phase.Setup);
          ([ Step.Build_config ], Some Phase.Setup);
          ([ Step.Index ], Some Phase.Setup);
          ([ Step.Plan ], Some Phase.Layer);
          ([ Step.Apply ], Some Phase.Layer);
          ([ Step.Unsafe_apply ], Some Phase.Layer);
          ([], None);
          ([ Step.Build_tree; Step.Plan ], None);
        ];
      ())

(* The other half of the wiring: [can_run] must read the phase the node carries.
   This is the rule of [by_phase] asked of a node and a work manifest, and not of
   a phase written by hand, so it fails if either end of the wire breaks.

   [setup_and_plan] is asked the same pairs to show what the wall is worth: it
   lets the plan join the run of the setup steps, and [by_phase] does not. *)
let test_can_run_reads_the_phase_of_the_node =
  Oth.test ~name:"compute_node: can_run holds the wall of by_phase" (fun _ ->
      let setup_node = node (wm [ Step.Build_tree ]) in
      let layer_node = node (wm [ Step.Plan ]) in
      CCList.iter
        (fun (merge_steps, node, steps, expected) ->
          Oth.Assert.true_
            ~fail_msg:
              (Ms.show merge_steps ^ " " ^ CCString.concat "," (CCList.map Step.to_string steps))
            (Compute_node.can_run
               ~merge_steps
               ~max_work_manifests_per_node:max_per_node
               node
               (wm steps)
            = expected))
        [
          (Ms.By_phase, setup_node, [ Step.Build_config ], true);
          (Ms.By_phase, setup_node, [ Step.Index ], true);
          (Ms.By_phase, setup_node, [ Step.Plan ], false);
          (Ms.By_phase, setup_node, [ Step.Apply ], false);
          (Ms.By_phase, layer_node, [ Step.Plan ], true);
          (Ms.By_phase, layer_node, [ Step.Apply ], true);
          (Ms.By_phase, layer_node, [ Step.Build_config ], false);
          (* The same pairs under the rung that has no wall. *)
          (Ms.Setup_and_plan, setup_node, [ Step.Build_config ], true);
          (Ms.Setup_and_plan, setup_node, [ Step.Plan ], true);
          (Ms.Setup_and_plan, setup_node, [ Step.Apply ], false);
        ];
      ())

(* The wall is the only thing [by_phase] adds.  Every other test a node must pass
   still holds, so a work manifest of the right phase that disagrees on the ref
   still takes a run of its own. *)
let test_by_phase_keeps_the_other_tests =
  Oth.test ~name:"compute_node: by_phase does not lift the other tests" (fun _ ->
      let layer_node = node (wm [ Step.Plan ]) in
      Oth.Assert.true_
        ~fail_msg:"a plan of the same phase and the same ref joins"
        (Compute_node.can_run
           ~merge_steps:Ms.By_phase
           ~max_work_manifests_per_node:max_per_node
           layer_node
           (wm [ Step.Plan ]));
      Oth.Assert.true_
        ~fail_msg:"a plan of the same phase but another ref takes a run of its own"
        (not
           (Compute_node.can_run
              ~merge_steps:Ms.By_phase
              ~max_work_manifests_per_node:max_per_node
              layer_node
              (wm ~branch_ref:"cafebabe" [ Step.Plan ])));
      Oth.Assert.true_
        ~fail_msg:"a plan of the same phase but another environment takes a run of its own"
        (not
           (Compute_node.can_run
              ~merge_steps:Ms.By_phase
              ~max_work_manifests_per_node:max_per_node
              layer_node
              (wm ~environment:(Some "production") [ Step.Plan ])));
      Oth.Assert.true_
        ~fail_msg:"a Running node takes no more work"
        (not
           (Compute_node.can_run
              ~merge_steps:Ms.By_phase
              ~max_work_manifests_per_node:max_per_node
              { layer_node with Tjc.Compute_node.state = Tjc.Compute_node.State.Running }
              (wm [ Step.Plan ])));
      ())

(* The even spread of one creation call.  Ten work manifests with a cap of nine
   make two nodes of five, not nine and one: a node of nine and one makes the last
   work manifest wait for a whole run of its own. *)
let test_spread_over_nodes_is_even =
  Oth.test ~name:"compute_node: spread_over_nodes is even" (fun _ ->
      let sizes ~max_per_node count =
        Compute_node.spread_over_nodes ~max_per_node (CCList.init count CCInt.to_string)
        |> CCList.map CCList.length
      in
      CCList.iter
        (fun (max_per_node, count, expected) ->
          Oth.Assert.eq
            ~eq:(CCList.equal CCInt.equal)
            ~pp:(CCList.pp CCInt.pp)
            expected
            (sizes ~max_per_node count))
        [
          (9, 10, [ 5; 5 ]);
          (9, 19, [ 7; 6; 6 ]);
          (1, 3, [ 1; 1; 1 ]);
          (9, 5, [ 5 ]);
          (9, 100, [ 9; 9; 9; 9; 8; 8; 8; 8; 8; 8; 8; 8 ]);
        ];
      ())

(* The cap is the hard ceiling and the list is never split above it, and no work
   manifest is lost or repeated.  A cap below one is clamped, because the schema
   rejects it but a configuration built in memory can hold it. *)
let test_spread_over_nodes_holds_the_cap =
  Oth.test ~name:"compute_node: spread_over_nodes never splits above the cap" (fun _ ->
      CCList.iter
        (fun (max_per_node, count) ->
          let groups =
            Compute_node.spread_over_nodes ~max_per_node (CCList.init count CCInt.to_string)
          in
          let cap =
            CCInt.max 1 (CCInt.min max_per_node Compute_node.max_work_manifests_per_compute_node)
          in
          CCList.iter
            (fun group ->
              Oth.Assert.true_
                ~fail_msg:
                  (Printf.sprintf "a group of %d is above the cap of %d" (CCList.length group) cap)
                (CCList.length group <= cap))
            groups;
          Oth.Assert.eq
            ~eq:CCInt.equal
            ~pp:CCInt.pp
            count
            (CCList.fold_left (fun n group -> n + CCList.length group) 0 groups))
        [ (9, 10); (9, 0); (1, 5); (0, 5); (100, 20); (3, 7) ];
      ())

(* A node the server has just made is [Queued], and it must take the rest of the
   work of the call that made it.  A [Running] node takes nothing: its result
   evaluation forks, and it gives its next layer a node of its own. *)
let test_can_run_admits_a_queued_node =
  Oth.test ~name:"compute_node: can_run admits a queued node and refuses a running one" (fun _ ->
      let node_in state = { (node (wm [ Step.Build_tree ])) with Tjc.Compute_node.state } in
      let open Tjc.Compute_node.State in
      CCList.iter
        (fun (name, state, expected) ->
          Oth.Assert.true_
            ~fail_msg:name
            (Compute_node.can_run
               ~merge_steps:Ms.Setup
               ~max_work_manifests_per_node:max_per_node
               (node_in state)
               (wm [ Step.Build_config ])
            = expected))
        [
          ("queued", Queued, true);
          ("starting", Starting, true);
          ("running", Running, false);
          ("terminated", Terminated, false);
        ];
      ())

(* The cap bounds the node: a node that has performed its cap takes nothing more,
   whatever state it is in.  The clamp holds at both ends. *)
let test_can_run_holds_the_cap =
  Oth.test ~name:"compute_node: can_run holds the configured cap" (fun _ ->
      let node_with ~used =
        let n = node (wm [ Step.Build_tree ]) in
        {
          n with
          Tjc.Compute_node.capabilities =
            {
              n.Tjc.Compute_node.capabilities with
              Tjc.Compute_node.Capabilities.used_work_manifests = used;
            };
        }
      in
      CCList.iter
        (fun (max_per_node, used, expected) ->
          Oth.Assert.true_
            ~fail_msg:(Printf.sprintf "cap %d, used %d" max_per_node used)
            (Compute_node.can_run
               ~merge_steps:Ms.Setup
               ~max_work_manifests_per_node:max_per_node
               (node_with ~used)
               (wm [ Step.Build_config ])
            = expected))
        [
          (9, 0, true);
          (9, 8, true);
          (9, 9, false);
          (3, 2, true);
          (3, 3, false);
          (0, 0, true);
          (0, 1, false);
          (100, 9, false);
        ];
      ())

let test =
  Oth.parallel
    [
      test_batches_across_dirs_within_an_environment;
      test_max_workspaces_per_batch_of_zero;
      test_environments_are_not_mixed;
      test_runs_on_is_not_mixed;
      test_dirs_are_isolated_within_a_batch;
      test_chunks_at_max_workspaces_per_batch;
      test_single_dir_gets_one_workspace_per_batch;
      test_partition_is_deterministic;
      test_every_dirspace_appears_exactly_once;
      test_merge_steps_ladder;
      test_merge_steps_only_one_step_joins;
      test_merge_steps_by_phase;
      test_merge_steps_by_phase_needs_a_phase;
      test_phase_of;
      test_capabilities_of_writes_the_phase;
      test_can_run_reads_the_phase_of_the_node;
      test_by_phase_keeps_the_other_tests;
      test_spread_over_nodes_is_even;
      test_spread_over_nodes_holds_the_cap;
      test_can_run_admits_a_queued_node;
      test_can_run_holds_the_cap;
    ]

let () =
  Random.self_init ();
  Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)
