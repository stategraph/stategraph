module Tmpl = Terrat_vcs_github_comment_templates.Tmpl

let render tmpl kv =
  match Minijinja.render_template tmpl kv with
  | Ok body -> body
  | Error err -> failwith err

(* The same payload shape the provider builds for the [no matching dirspaces]
   messages, see [Terrat_vcs_provider2.Msg.no_matching_dirspaces_kv]. *)
let kv ~tag_query ~implicit_and ~suggestion =
  `Assoc
    [
      ("tag_query", `String tag_query);
      ("implicit_and", `Bool implicit_and);
      ( "suggestion",
        match suggestion with
        | Some suggestion -> `String suggestion
        | None -> `Null );
    ]

let test_apply_no_warning =
  Oth.test ~name:"Apply no warning" (fun _ ->
      let body =
        render
          Tmpl.apply_no_matching_dirspaces
          (kv ~tag_query:"dir:foo" ~implicit_and:false ~suggestion:None)
      in
      Oth.Assert.str_contains
        ~haystack:body
        ~needle:"There are no matching changes that are pending apply.";
      Oth.Assert.str_doesnt_contain ~haystack:body ~needle:"Did you mean")

let test_apply_warning_with_suggestion =
  Oth.test ~name:"Apply warning with suggestion" (fun _ ->
      let body =
        render
          Tmpl.apply_no_matching_dirspaces
          (kv
             ~tag_query:"dir:foo dir:bar"
             ~implicit_and:true
             ~suggestion:(Some "dir:foo or dir:bar"))
      in
      Oth.Assert.str_contains_all
        ~haystack:body
        ~needles:
          [
            "There are no matching changes that are pending apply.";
            "[!WARNING]";
            "Did you mean `or`?";
            "terrateam apply dir:foo or dir:bar";
          ])

let test_apply_warning_without_suggestion =
  Oth.test ~name:"Apply warning without suggestion" (fun _ ->
      let body =
        render
          Tmpl.apply_no_matching_dirspaces
          (kv ~tag_query:"dir:foo workspace:prod" ~implicit_and:true ~suggestion:None)
      in
      Oth.Assert.str_contains_all
        ~haystack:body
        ~needles:[ "Did you mean `or`?"; "`dir:foo workspace:prod`" ];
      (* Without a rewrite the only command offered is the unfiltered one. *)
      Oth.Assert.str_doesnt_contain ~haystack:body ~needle:"terrateam apply dir:")

let test_plan_no_warning =
  Oth.test ~name:"Plan no warning" (fun _ ->
      let body =
        render
          Tmpl.plan_no_matching_dirspaces
          (kv ~tag_query:"dir:foo" ~implicit_and:false ~suggestion:None)
      in
      Oth.Assert.str_contains ~haystack:body ~needle:"There are no matching changes to plan.";
      Oth.Assert.str_doesnt_contain ~haystack:body ~needle:"Did you mean")

let test_plan_warning_with_suggestion =
  Oth.test ~name:"Plan warning with suggestion" (fun _ ->
      let body =
        render
          Tmpl.plan_no_matching_dirspaces
          (kv
             ~tag_query:"dir:foo dir:bar"
             ~implicit_and:true
             ~suggestion:(Some "dir:foo or dir:bar"))
      in
      Oth.Assert.str_contains_all
        ~haystack:body
        ~needles:
          [
            "There are no matching changes to plan.";
            "Did you mean `or`?";
            "terrateam plan dir:foo or dir:bar";
          ])

let test_tag_query_dropped_dirspaces =
  Oth.test ~name:"Tag query dropped dirspaces" (fun _ ->
      let body =
        render
          Tmpl.tag_query_dropped_dirspaces
          (`Assoc
             [
               ("command", `String "terrateam apply");
               ("suggestion", `String "dir:a or dir:b or dir:c");
               ( "dirspaces",
                 `List
                   [
                     `Assoc [ ("dir", `String "b"); ("workspace", `String "default") ];
                     `Assoc [ ("dir", `String "c"); ("workspace", `String "default") ];
                   ] );
             ])
      in
      Oth.Assert.str_contains_all
        ~haystack:body
        ~needles:
          [
            "Some Directories Were Left Out";
            "| `b` | `default` |";
            "| `c` | `default` |";
            "terrateam apply dir:a or dir:b or dir:c";
          ])

let test_matches_in_later_layer =
  Oth.test ~name:"Matches in later layer" (fun _ ->
      let body =
        render
          Tmpl.matches_in_later_layer
          (`Assoc
             [
               ( "dirspaces",
                 `List
                   [
                     `Assoc [ ("dir", `String "tql/app"); ("workspace", `String "default") ];
                     `Assoc [ ("dir", `String "tql/web"); ("workspace", `String "prod") ];
                   ] );
             ])
      in
      Oth.Assert.str_contains_all
        ~haystack:body
        ~needles:
          [
            "Waiting On An Earlier Layer";
            "| `tql/app` | `default` |";
            "| `tql/web` | `prod` |";
            "terrateam plan";
          ])

(* Every [Operation_failed] template renders the request id, because it is the
   only handle support has on the failure. *)
let test_operation_failed_branch_not_found =
  Oth.test ~name:"Operation failed branch not found" (fun _ ->
      let body =
        render
          Tmpl.operation_failed_branch_not_found
          (`Assoc [ ("request_id", `String "req-123"); ("branch", `String "release/v2") ])
      in
      Oth.Assert.str_contains_all ~haystack:body ~needles:[ "req-123"; "release/v2" ])

let test_operation_failed_compute_aborted =
  Oth.test ~name:"Operation failed compute aborted" (fun _ ->
      let body =
        render
          Tmpl.operation_failed_compute_aborted
          (`Assoc [ ("request_id", `String "req-123"); ("num_aborts", `Int 11) ])
      in
      Oth.Assert.str_contains_all ~haystack:body ~needles:[ "req-123"; "11" ])

let test_operation_failed_db_err =
  Oth.test ~name:"Operation failed db err" (fun _ ->
      let body =
        render Tmpl.operation_failed_db_err (`Assoc [ ("request_id", `String "req-123") ])
      in
      Oth.Assert.str_contains ~haystack:body ~needle:"req-123")

let test_operation_failed_internal_err =
  Oth.test ~name:"Operation failed internal err" (fun _ ->
      let body =
        render
          Tmpl.operation_failed_internal_err
          (`Assoc [ ("request_id", `String "req-123"); ("tag", `String "EXPECTED_REPO_TREE") ])
      in
      Oth.Assert.str_contains_all ~haystack:body ~needles:[ "req-123"; "EXPECTED_REPO_TREE" ])

let test_operation_failed_vcs_api_err =
  Oth.test ~name:"Operation failed vcs api err" (fun _ ->
      let body =
        render
          Tmpl.operation_failed_vcs_api_err
          (`Assoc
             [ ("request_id", `String "req-123"); ("operation", `String "CREATE_COMMIT_CHECKS") ])
      in
      Oth.Assert.str_contains_all ~haystack:body ~needles:[ "req-123"; "CREATE_COMMIT_CHECKS" ])

let test_operation_failed_work_manifest_start_err =
  Oth.test ~name:"Operation failed work manifest start err" (fun _ ->
      let body =
        render
          Tmpl.operation_failed_work_manifest_start_err
          (`Assoc [ ("request_id", `String "req-123") ])
      in
      Oth.Assert.str_contains ~haystack:body ~needle:"req-123")

(* The bad-glob comment.  [pattern] is the glob as written in the repository
   configuration and [glob] is what it expands to; the template says so only
   when the two differ, because repeating an unsubstituted glob back at the
   reader tells them nothing. *)
let bad_glob_kv ~location ~pattern ~glob ~error =
  `Assoc
    [
      ("location", `String location);
      ("pattern", `String pattern);
      ("glob", `String glob);
      ("error", `String error);
    ]

let test_bad_glob_err_unsubstituted =
  Oth.test ~name:"Bad glob, nothing substituted" (fun _ ->
      let body =
        render
          Tmpl.repo_config_err_bad_glob_err
          (bad_glob_kv
             ~location:{|dirs."**"|}
             ~pattern:"**"
             ~glob:"**"
             ~error:"Ambiguous ** pattern not allowed unless surrounded by one or more slashes")
      in
      Oth.Assert.str_contains_all
        ~haystack:body
        ~needles:[ "Could not parse the glob `**`"; {|`dirs."**"`|}; "Ambiguous ** pattern" ];
      Oth.Assert.str_doesnt_contain ~haystack:body ~needle:"which expands to";
      ())

let test_bad_glob_err_substituted =
  Oth.test ~name:"Bad glob, ${DIR} substituted" (fun _ ->
      let body =
        render
          Tmpl.repo_config_err_bad_glob_err
          (bad_glob_kv
             ~location:{|dirs."a+b".workspaces."default".when_modified.file_patterns|}
             ~pattern:"${DIR}/*.tf"
             ~glob:"a+b/*.tf"
             ~error:"Unexpected character '+' in glob pattern")
      in
      Oth.Assert.str_contains_all
        ~haystack:body
        ~needles:
          [
            "Could not parse the glob `a+b/*.tf`";
            {|`dirs."a+b".workspaces."default".when_modified.file_patterns`|};
            "written as `${DIR}/*.tf`";
            "which expands to `a+b/*.tf`";
            "Unexpected character '+' in glob pattern";
          ];
      ())

(* The payload [Msg.Missing_plans] builds, one row per reason.  Snabela errors on
   a key a template asks for and the map does not carry, so the provider emits
   all three flags on every row and this pins that. *)
let missing_plans_kv rows =
  Snabela.Kv.(
    Map.of_list
      [
        ( "dirspaces",
          list
            (CCList.map
               (fun (dir, workspace, never_planned, invalidated, invalidated_by, last_run_failed) ->
                 Map.of_list
                   [
                     ("dir", string dir);
                     ("workspace", string workspace);
                     ("never_planned", bool never_planned);
                     ("last_run_failed", bool last_run_failed);
                     ("invalidated", bool invalidated);
                     ("invalidated_by", int invalidated_by);
                   ])
               rows) );
        ( "any_invalidated",
          bool (CCList.exists (fun (_, _, _, invalidated, _, _) -> invalidated) rows) );
      ])

let render_missing_plans rows =
  match Snabela.apply Tmpl.missing_plans (missing_plans_kv rows) with
  | Ok body -> body
  | Error (#Snabela.err as err) -> failwith (Snabela.show_err err)

let test_missing_plans_never_planned =
  Oth.test ~name:"Missing plans: never planned" (fun _ ->
      let body = render_missing_plans [ ("foo", "default", true, false, 0, false) ] in
      Oth.Assert.str_contains ~haystack:body ~needle:"Never planned on this ref";
      Oth.Assert.str_doesnt_contain ~haystack:body ~needle:"superseded")

let test_missing_plans_invalidated =
  Oth.test ~name:"Missing plans: invalidated names the pull request" (fun _ ->
      let body = render_missing_plans [ ("foo", "default", false, true, 849, false) ] in
      Oth.Assert.str_contains ~haystack:body ~needle:"Plan superseded by #849";
      Oth.Assert.str_doesnt_contain ~haystack:body ~needle:"Never planned")

let test_missing_plans_last_run_failed =
  Oth.test ~name:"Missing plans: last run failed" (fun _ ->
      let body = render_missing_plans [ ("foo", "default", false, false, 0, true) ] in
      Oth.Assert.str_contains ~haystack:body ~needle:"The last run for this directory failed";
      Oth.Assert.str_doesnt_contain ~haystack:body ~needle:"superseded")

let test_missing_plans_mixed_reasons =
  Oth.test ~name:"Missing plans: every reason renders in one table" (fun _ ->
      let body =
        render_missing_plans
          [
            ("a", "default", true, false, 0, false);
            ("b", "default", false, true, 12, false);
            ("c", "default", false, false, 0, true);
          ]
      in
      Oth.Assert.str_contains ~haystack:body ~needle:"Never planned on this ref";
      Oth.Assert.str_contains ~haystack:body ~needle:"Plan superseded by #12";
      Oth.Assert.str_contains ~haystack:body ~needle:"The last run for this directory failed")

(* The [work_manifests] payload both providers build for every message that lists work manifests,
   see [work_manifests_kv] in the service providers. *)
let work_manifests_kv rows =
  Snabela.Kv.(
    Map.of_list
      [
        ( "work_manifests",
          list
            (CCList.map
               (fun (id, is_pr, run_type, state, created_at) ->
                 Map.of_list
                   [
                     ("id", string id);
                     ("is_pr", bool is_pr);
                     ("run_type", string run_type);
                     ("state", string state);
                     ("created_at", string created_at);
                   ])
               rows) );
      ])

let render_snabela template kv =
  match Snabela.apply template kv with
  | Ok body -> body
  | Error (#Snabela.err as err) -> failwith (Snabela.show_err err)

(* An apply that waits behind running work has to name that work, and give the unlock command that
   clears it.  A pull request blocker unlocks by number.  See #1968. *)
let test_apply_queued_behind_pull_request =
  Oth.test ~name:"Apply queued behind a pull request" (fun _ ->
      let body =
        render_snabela
          Tmpl.apply_queued_behind_work_manifests
          (work_manifests_kv [ ("42", true, "Plan", "Running", "2026-8-21 9:14") ])
      in
      Oth.Assert.str_contains ~haystack:body ~needle:"Apply queued";
      Oth.Assert.str_contains_all
        ~haystack:body
        ~needles:[ "#42"; "Plan"; "Running"; "terrateam unlock 42" ])

(* A drift blocker unlocks with [terrateam unlock drift], not with a number.  A drift run has no
   pull request, so it must not be printed as one. *)
let test_apply_queued_behind_drift =
  Oth.test ~name:"Apply queued behind drift" (fun _ ->
      let body =
        render_snabela
          Tmpl.apply_queued_behind_work_manifests
          (work_manifests_kv [ ("drift", false, "Plan", "Running", "2026-8-21 0:02") ])
      in
      Oth.Assert.str_contains ~haystack:body ~needle:"terrateam unlock drift";
      Oth.Assert.str_doesnt_contain ~haystack:body ~needle:"#drift")

(* One command unlocks both kinds of blocker at the same time. *)
let test_apply_queued_behind_both_kinds =
  Oth.test ~name:"Apply queued behind a pull request and drift" (fun _ ->
      let body =
        render_snabela
          Tmpl.apply_queued_behind_work_manifests
          (work_manifests_kv
             [
               ("42", true, "Plan", "Running", "2026-8-21 9:14");
               ("drift", false, "Plan", "Running", "2026-8-21 0:02");
             ])
      in
      Oth.Assert.str_contains ~haystack:body ~needle:"terrateam unlock 42 drift")

(* The conflict message covers a queued apply as well as a running one, so it must not claim the
   apply is in progress.  The system tests match on this title. *)
let test_conflicting_work_manifests_title =
  Oth.test ~name:"Conflicting work manifests title" (fun _ ->
      let body =
        render_snabela
          Tmpl.conflicting_work_manifests
          (work_manifests_kv [ ("42", true, "Apply", "Queued", "2026-8-21 9:25") ])
      in
      Oth.Assert.str_contains ~haystack:body ~needle:"Apply already queued or running";
      Oth.Assert.str_doesnt_contain ~haystack:body ~needle:"Apply already in progress")

(* Every [<details>] the apply comment opens must close, and no [</details>] may
   run ahead of its open.  #1975: the per-dirspace [<details>] opened under
   [compact_dirspaces] but closed under [compact_view], so an apply of more than
   five dirspaces emitted one open per dirspace and a single close, and the
   reader saw every dirspace nested inside the previous one. *)
let details_balance body =
  let len = CCString.length body in
  let rec go idx depth min_depth =
    if idx >= len then (depth, min_depth)
    else if idx + 10 <= len && CCString.equal "</details>" (CCString.sub body idx 10) then
      go (idx + 10) (depth - 1) (CCInt.min min_depth (depth - 1))
    else if idx + 8 <= len && CCString.equal "<details" (CCString.sub body idx 8) then
      go (idx + 8) (depth + 1) min_depth
    else go (idx + 1) depth min_depth
  in
  go 0 0 0

let apply_complete2_kv ~compact_view ~applied ~num_dirspaces =
  `Assoc
    [
      ("overall_success", `Bool true);
      ("summary", `Bool true);
      ("account_status", `String "active");
      ("trial_end_days", `Int 0);
      ("is_layered_run", `Bool false);
      ("num_more_layers", `Int 0);
      ("denied_dirspaces", `List []);
      ("pre_hooks", `List []);
      ("post_hooks", `List []);
      ("gates", `List []);
      ("compact_view", `Bool compact_view);
      (* The publisher's own rule, see [Terrat_vcs_github_comment_publishers]. *)
      ("compact_dirspaces", `Bool (num_dirspaces > 5));
      ( "dirspaces",
        `List
          (CCList.map
             (fun idx ->
               `Assoc
                 [
                   ("dir", `String (Printf.sprintf "dir-%d" idx));
                   ("workspace", `String "default");
                   ("success", `Bool true);
                   ( "steps",
                     `List
                       [
                         `Assoc
                           [
                             ("name", `String "apply");
                             ("text", `String "Apply complete!");
                             ("show_output", `Bool true);
                             ("success", `Bool true);
                             ("raw", `Bool false);
                             ("text_decorator", `String "");
                           ];
                       ] );
                   ("has_changes", `Bool true);
                   ("run_url", `Null);
                   ("applied", `Bool applied);
                 ])
             (CCList.range 1 num_dirspaces)) );
    ]

let test_apply_complete2_details ~name ~compact_view ~applied ~num_dirspaces =
  Oth.test ~tags:[ "comment_details" ] ~name (fun _ ->
      let body =
        render Tmpl.apply_complete2 (apply_complete2_kv ~compact_view ~applied ~num_dirspaces)
      in
      let depth, min_depth = details_balance body in
      Oth.Assert.true_ (Printf.sprintf "%d <details> left open" depth) (depth = 0);
      Oth.Assert.true_
        (Printf.sprintf "</details> without an open, depth reached %d" min_depth)
        (min_depth >= 0);
      ())

let test_apply_complete2_details_many_dirspaces =
  test_apply_complete2_details
    ~name:"Apply complete: 10 dirspaces, normal view"
    ~compact_view:false
    ~applied:false
    ~num_dirspaces:10

let test_apply_complete2_details_few_dirspaces =
  test_apply_complete2_details
    ~name:"Apply complete: 3 dirspaces, normal view"
    ~compact_view:false
    ~applied:false
    ~num_dirspaces:3

let test_apply_complete2_details_few_dirspaces_compact_view =
  test_apply_complete2_details
    ~name:"Apply complete: 3 dirspaces, compact view"
    ~compact_view:true
    ~applied:false
    ~num_dirspaces:3

let test_apply_complete2_details_many_dirspaces_applied =
  test_apply_complete2_details
    ~name:"Apply complete: 10 dirspaces already applied"
    ~compact_view:false
    ~applied:true
    ~num_dirspaces:10

let test =
  Oth.parallel
    [
      test_operation_failed_branch_not_found;
      test_operation_failed_compute_aborted;
      test_operation_failed_db_err;
      test_operation_failed_internal_err;
      test_operation_failed_vcs_api_err;
      test_operation_failed_work_manifest_start_err;
      test_matches_in_later_layer;
      test_tag_query_dropped_dirspaces;
      test_apply_no_warning;
      test_apply_warning_with_suggestion;
      test_apply_warning_without_suggestion;
      test_plan_no_warning;
      test_plan_warning_with_suggestion;
      test_bad_glob_err_unsubstituted;
      test_bad_glob_err_substituted;
      test_missing_plans_never_planned;
      test_missing_plans_invalidated;
      test_missing_plans_last_run_failed;
      test_missing_plans_mixed_reasons;
      test_apply_queued_behind_pull_request;
      test_apply_queued_behind_drift;
      test_apply_queued_behind_both_kinds;
      test_conflicting_work_manifests_title;
      test_apply_complete2_details_many_dirspaces;
      test_apply_complete2_details_few_dirspaces;
      test_apply_complete2_details_few_dirspaces_compact_view;
      test_apply_complete2_details_many_dirspaces_applied;
    ]

let () =
  Random.self_init ();
  Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)
