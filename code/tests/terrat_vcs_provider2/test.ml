module Rs = Terrat_vcs_provider2.Resource_summary

let step ?(success = true) ~step_name payload_json =
  let module O = Terrat_api_components.Workflow_step_output in
  CCResult.get_or_failwith
  @@ O.of_yojson
       (`Assoc
          [
            ("ignore_errors", `Bool false);
            ("payload", payload_json);
            ( "scope",
              `Assoc
                [
                  ("type", `String "dirspace");
                  ("dir", `String "tf");
                  ("workspace", `String "default");
                ] );
            ("step", `String step_name);
            ("success", `Bool success);
          ])

let plan_step ?success () =
  step
    ?success
    ~step_name:"tf/plan"
    (`Assoc
       [
         ("has_changes", `Bool true);
         ( "resource_summary",
           `Assoc
             [ ("created", `Int 1); ("updated", `Int 0); ("replaced", `Int 0); ("deleted", `Int 0) ]
         );
       ])

let assert_summary = Oth.Assert.eq ~eq:Rs.equal ~pp:Rs.pp

let summary ?(imported = None) created updated replaced deleted =
  { Rs.created; deleted; imported; replaced; updated }

(* [describe] without a summary returns the description unchanged; with one it
   appends the four counts, "-" for unreported ones, clipped at 140 chars. *)
let test_describe_no_summary =
  Oth.test ~name:"describe_no_summary" (fun _ ->
      Oth.Assert.Eq.string ~expected:"Completed" ~actual:(Rs.describe ~description:"Completed" ());
      ())

let test_describe_full_summary =
  Oth.test ~name:"describe_full_summary" (fun _ ->
      Oth.Assert.Eq.string
        ~expected:"Completed · 1 create, 0 update, 0 replace, 0 delete"
        ~actual:
          (Rs.describe
             ~resource_summary:(summary (Some 1) (Some 0) (Some 0) (Some 0))
             ~description:"Completed"
             ());
      ())

(* The import count leads the counts only when it is above zero. *)
let test_describe_imports =
  Oth.test ~name:"describe_imports" (fun _ ->
      Oth.Assert.Eq.string
        ~expected:"Completed · 2 import, 1 create, 0 update, 0 replace, 0 delete"
        ~actual:
          (Rs.describe
             ~resource_summary:(summary ~imported:(Some 2) (Some 1) (Some 0) (Some 0) (Some 0))
             ~description:"Completed"
             ());
      Oth.Assert.Eq.string
        ~expected:"Completed · 1 create, 0 update, 0 replace, 0 delete"
        ~actual:
          (Rs.describe
             ~resource_summary:(summary ~imported:(Some 0) (Some 1) (Some 0) (Some 0) (Some 0))
             ~description:"Completed"
             ());
      ())

let test_describe_partial_summary_dashes =
  Oth.test ~name:"describe_partial_summary_dashes" (fun _ ->
      Oth.Assert.Eq.string
        ~expected:"Failed · - create, - update, 2 replace, - delete"
        ~actual:
          (Rs.describe ~resource_summary:(summary None None (Some 2) None) ~description:"Failed" ());
      ())

let test_describe_truncates_at_140 =
  Oth.test ~name:"describe_truncates_at_140" (fun _ ->
      let long = CCString.make 200 'x' in
      let text =
        Rs.describe ~resource_summary:(summary (Some 1) None None None) ~description:long ()
      in
      Oth.Assert.Eq.int ~expected:Rs.description_limit ~actual:(CCString.length text);
      ())

(* [of_steps] picks the plan step's summary and ignores other steps; an empty
   resource_summary object is treated as absent. *)
let test_of_steps_plan_step =
  Oth.test ~name:"of_steps_plan_step" (fun _ ->
      assert_summary
        (summary (Some 1) (Some 0) (Some 0) (Some 0))
        (Oth.Assert.some (Rs.of_steps [ plan_step () ]));
      ())

let test_of_steps_ignores_non_plan_steps =
  Oth.test ~name:"of_steps_ignores_non_plan_steps" (fun _ ->
      (* A summary on a non-plan step is ignored. *)
      Oth.Assert.none_pp
        ~pp:Rs.pp
        (Rs.of_steps
           [
             step
               ~step_name:"tf/init"
               (`Assoc [ ("resource_summary", `Assoc [ ("created", `Int 1) ]) ]);
           ]);
      (* A plan step's summary is still found after a summary-less init step. *)
      ignore (Oth.Assert.some (Rs.of_steps [ step ~step_name:"tf/init" (`Assoc []); plan_step () ]));
      ())

let test_of_steps_all_none_counts_treated_as_absent =
  Oth.test ~name:"of_steps_all_none_counts_treated_as_absent" (fun _ ->
      (* A resource_summary object that reports no count at all is treated as
         absent: the bare status word beats a row of dashes. *)
      let s =
        step
          ~step_name:"tf/plan"
          (`Assoc
             [
               ("has_changes", `Bool true);
               ( "resource_summary",
                 `Assoc
                   [
                     ("created", `Null); ("updated", `Null); ("replaced", `Null); ("deleted", `Null);
                   ] );
             ])
      in
      Oth.Assert.none_pp ~pp:Rs.pp (Rs.of_steps [ s ]);
      ())

let test_of_steps_empty_summary_absent =
  Oth.test ~name:"of_steps_empty_summary_absent" (fun _ ->
      let s = step ~step_name:"tf/plan" (`Assoc [ ("has_changes", `Bool true) ]) in
      Oth.Assert.none_pp ~pp:Rs.pp (Rs.of_steps [ s ]);
      ())

let test_of_steps_imported =
  Oth.test ~name:"of_steps_imported" (fun _ ->
      let plan_step counts =
        step
          ~step_name:"tf/plan"
          (`Assoc [ ("has_changes", `Bool true); ("resource_summary", `Assoc counts) ])
      in
      assert_summary
        (summary ~imported:(Some 3) (Some 0) (Some 1) (Some 0) (Some 0))
        (Oth.Assert.some
           (Rs.of_steps
              [
                plan_step
                  [
                    ("created", `Int 0);
                    ("updated", `Int 1);
                    ("replaced", `Int 0);
                    ("deleted", `Int 0);
                    ("imported", `Int 3);
                  ];
              ]));
      (* An import count alone is a reported summary. *)
      assert_summary
        (summary ~imported:(Some 1) None None None None)
        (Oth.Assert.some (Rs.of_steps [ plan_step [ ("imported", `Int 1) ] ]));
      ())

let test_total_sums_imported =
  Oth.test ~name:"total_sums_imported" (fun _ ->
      assert_summary
        (summary ~imported:(Some 3) (Some 1) (Some 0) (Some 0) (Some 0))
        (Rs.total
           [
             summary ~imported:(Some 2) (Some 1) (Some 0) (Some 0) (Some 0);
             summary ~imported:(Some 1) None None None None;
             Rs.none;
           ]);
      (* A run whose runner reports no import count totals it as 0, like every other slot. *)
      assert_summary
        (summary ~imported:(Some 0) (Some 1) (Some 0) (Some 0) (Some 0))
        (Rs.total [ summary (Some 1) (Some 0) (Some 0) (Some 0) ]);
      ())

module Ds = Terrat_vcs_provider2.Dirspace_summary

(* The database stores a summary state as text and reads it back. *)
let test_dirspace_summary_of_string =
  Oth.test ~name:"dirspace_summary_of_string" (fun _ ->
      CCList.iter
        (fun state ->
          Oth.Assert.Eq.option
            ~eq:Ds.equal
            ~pp:Ds.pp
            ~expected:(Some state)
            ~actual:(Ds.of_string (Ds.to_string state)))
        [ Ds.Applied; Ds.Planned; Ds.Failed; Ds.Stale ];
      Oth.Assert.Eq.option ~eq:Ds.equal ~pp:Ds.pp ~expected:None ~actual:(Ds.of_string "pending");
      ())

(* A work manifest with only what [work_manifest_unlock_ids] reads: its target. *)
let wm ~target =
  {
    Terrat_work_manifest3.account = ();
    base_ref = "";
    branch = None;
    branch_ref = "";
    changes = [];
    completed_at = None;
    created_at = "";
    denied_dirspaces = [];
    environment = None;
    id = Uuidm.nil;
    initiator = Terrat_work_manifest3.Initiator.System;
    params = Sln_map.String.empty;
    run_id = None;
    runs_on = None;
    state = Terrat_work_manifest3.State.Queued;
    steps = [];
    tag_query = Terrat_tag_query.any;
    target;
  }

let pr n = Terrat_vcs_provider2.Target.Pr n
let drift = Terrat_vcs_provider2.Target.Drift { repo = (); branch = "" }

(* Three stuck runs for one pull request render one unlock token, not three.
   This is the publisher-layer regression the template tests cannot catch. *)
let test_work_manifest_unlock_ids_dedupes_pull_requests =
  Oth.test ~name:"work_manifest_unlock_ids dedupes pull request numbers" (fun _ ->
      Oth.Assert.Eq.string_list
        ~expected:[ "123" ]
        ~actual:
          (Terrat_vcs_provider2.work_manifest_unlock_ids
             ~pull_request_id:CCFun.id
             (CCList.map (fun _ -> wm ~target:(pr 123)) [ 1; 2; 3 ]));
      ())

let test_work_manifest_unlock_ids_collapses_drift =
  Oth.test ~name:"work_manifest_unlock_ids collapses drift targets" (fun _ ->
      Oth.Assert.Eq.string_list
        ~expected:[ "drift" ]
        ~actual:
          (Terrat_vcs_provider2.work_manifest_unlock_ids
             ~pull_request_id:CCFun.id
             (CCList.map (fun _ -> wm ~target:drift) [ 1; 2 ]));
      ())

let test_work_manifest_unlock_ids_mixed_list =
  Oth.test ~name:"work_manifest_unlock_ids mixed list sorts lexicographically" (fun _ ->
      Oth.Assert.Eq.string_list
        ~expected:[ "123"; "45"; "drift" ]
        ~actual:
          (Terrat_vcs_provider2.work_manifest_unlock_ids
             ~pull_request_id:CCFun.id
             [
               wm ~target:(pr 123);
               wm ~target:(pr 123);
               wm ~target:drift;
               wm ~target:(pr 45);
               wm ~target:drift;
             ]);
      ())

let test_work_manifest_unlock_ids_singletons =
  Oth.test ~name:"work_manifest_unlock_ids singletons pass through" (fun _ ->
      Oth.Assert.Eq.string_list
        ~expected:[ "123" ]
        ~actual:
          (Terrat_vcs_provider2.work_manifest_unlock_ids
             ~pull_request_id:CCFun.id
             [ wm ~target:(pr 123) ]);
      Oth.Assert.Eq.string_list
        ~expected:[ "drift" ]
        ~actual:
          (Terrat_vcs_provider2.work_manifest_unlock_ids
             ~pull_request_id:CCFun.id
             [ wm ~target:drift ]);
      ())

let test_work_manifest_unlock_ids_empty =
  Oth.test ~name:"work_manifest_unlock_ids empty list" (fun _ ->
      Oth.Assert.Eq.string_list
        ~expected:[]
        ~actual:(Terrat_vcs_provider2.work_manifest_unlock_ids ~pull_request_id:CCFun.id []);
      ())

let test =
  Oth.serial
    [
      test_dirspace_summary_of_string;
      test_describe_no_summary;
      test_describe_full_summary;
      test_describe_imports;
      test_describe_partial_summary_dashes;
      test_describe_truncates_at_140;
      test_of_steps_plan_step;
      test_of_steps_ignores_non_plan_steps;
      test_of_steps_all_none_counts_treated_as_absent;
      test_of_steps_empty_summary_absent;
      test_of_steps_imported;
      test_total_sums_imported;
      test_work_manifest_unlock_ids_dedupes_pull_requests;
      test_work_manifest_unlock_ids_collapses_drift;
      test_work_manifest_unlock_ids_mixed_list;
      test_work_manifest_unlock_ids_singletons;
      test_work_manifest_unlock_ids_empty;
    ]

let () = Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)
