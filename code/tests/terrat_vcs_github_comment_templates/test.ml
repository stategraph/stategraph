module Tmpl = Terrat_vcs_github_comment_templates.Tmpl

(* Every template is a function of the brand.  These helpers render the
   Stategraph text; the brand tests render a brand of their own. *)
let render_brand brand tmpl kv =
  match Minijinja.render_template (tmpl brand) kv with
  | Ok body -> body
  | Error err -> failwith err

let render tmpl kv = render_brand Terrat_brand.Stategraph tmpl kv

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
            "stategraph apply dir:foo or dir:bar";
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
      Oth.Assert.str_doesnt_contain ~haystack:body ~needle:"stategraph apply dir:")

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
            "stategraph plan dir:foo or dir:bar";
          ])

let test_tag_query_dropped_dirspaces =
  Oth.test ~name:"Tag query dropped dirspaces" (fun _ ->
      let render brand =
        render_brand
          brand
          Tmpl.tag_query_dropped_dirspaces
          (`Assoc
             [
               ("command", `String "apply");
               ("suggestion", `String "dir:a or dir:b or dir:c");
               ( "dirspaces",
                 `List
                   [
                     `Assoc [ ("dir", `String "b"); ("workspace", `String "default") ];
                     `Assoc [ ("dir", `String "c"); ("workspace", `String "default") ];
                   ] );
             ])
      in
      let body = render Terrat_brand.Stategraph in
      Oth.Assert.str_contains_all
        ~haystack:body
        ~needles:
          [
            "Some Directories Were Left Out";
            "| `b` | `default` |";
            "| `c` | `default` |";
            "stategraph apply dir:a or dir:b or dir:c";
          ];
      (* The trigger word comes from the template, so it follows the brand; the
         command itself is a rendered value and stays as it was handed over. *)
      Oth.Assert.str_contains
        ~haystack:(render Terrat_brand.Terrateam)
        ~needle:"terrateam apply dir:a or dir:b or dir:c")

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
            "stategraph plan";
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

(* A call the VCS never answered is a separate comment from a call that failed,
   so that the reader is told GitHub is unresponsive rather than that Stategraph
   broke. *)
let test_operation_failed_vcs_api_timeout_err =
  Oth.test ~name:"Operation failed vcs api timeout err" (fun _ ->
      let body =
        render
          Tmpl.operation_failed_vcs_api_timeout_err
          (`Assoc [ ("request_id", `String "req-123"); ("operation", `String "FETCH_PULL_REQUEST") ])
      in
      Oth.Assert.str_contains_all
        ~haystack:body
        ~needles:[ "req-123"; "FETCH_PULL_REQUEST"; "GitHub"; "timed out" ];
      Oth.Assert.str_doesnt_contain ~haystack:body ~needle:"UNKNOWN")

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
  match Snabela.apply (Tmpl.missing_plans Terrat_brand.Stategraph) (missing_plans_kv rows) with
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

(* These templates open on the brand name, and both brand names are command
   trigger words, so the bodies either image publishes come back as commands.
   The self marker is what keeps this system from answering its own comment.
   See [Terrat_comment.is_from_self] and the guard in the event endpoints.
   Both renderings are checked: "stategraph" joined [Terrat_comment.trigger_words]
   in #1592, so the shipped bodies parse for the same reason the Terrateam ones
   always did. *)
let test_published_bodies_carry_the_self_marker =
  Oth.test ~name:"Published bodies carry the self marker" (fun _ ->
      let templates =
        [
          ("operation_failed_branch_not_found", Tmpl.operation_failed_branch_not_found);
          ("operation_failed_compute_aborted", Tmpl.operation_failed_compute_aborted);
          ("operation_failed_db_err", Tmpl.operation_failed_db_err);
          ("operation_failed_internal_err", Tmpl.operation_failed_internal_err);
          ("operation_failed_work_manifest_start_err", Tmpl.operation_failed_work_manifest_start_err);
        ]
      in
      let parses_as_a_command tmpl =
        match Terrat_comment.parse tmpl with
        | Ok _ -> true
        | Error (`Unknown_action _) -> true
        | Error (`Tag_query_error _) -> true
        | Error `Not_terrateam -> false
      in
      CCList.iter
        (fun brand ->
          Oth.Assert.true_
            (CCList.exists (fun (_, tmpl) -> parses_as_a_command (tmpl brand)) templates);
          CCList.iter
            (fun (_, tmpl) ->
              Oth.Assert.true_
                (Terrat_comment.is_from_self (Terrat_comment.add_self_marker (tmpl brand))))
            templates)
        [ Terrat_brand.Stategraph; Terrat_brand.Terrateam ];
      ())

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
  match Snabela.apply (template Terrat_brand.Stategraph) kv with
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
        ~needles:[ "#42"; "Plan"; "Running"; "stategraph unlock 42" ])

(* A drift blocker unlocks with [stategraph unlock drift], not with a number.  A drift run has no
   pull request, so it must not be printed as one. *)
let test_apply_queued_behind_drift =
  Oth.test ~name:"Apply queued behind drift" (fun _ ->
      let body =
        render_snabela
          Tmpl.apply_queued_behind_work_manifests
          (work_manifests_kv [ ("drift", false, "Plan", "Running", "2026-8-21 0:02") ])
      in
      Oth.Assert.str_contains ~haystack:body ~needle:"stategraph unlock drift";
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
      Oth.Assert.str_contains ~haystack:body ~needle:"stategraph unlock 42 drift")

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

let apply_complete2_kv ?(summary_unified = false) ~compact_view ~applied ~num_dirspaces () =
  `Assoc
    [
      ("overall_success", `Bool true);
      ("summary", `Bool true);
      ("summary_unified", `Bool summary_unified);
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
        render Tmpl.apply_complete2 (apply_complete2_kv ~compact_view ~applied ~num_dirspaces ())
      in
      let depth, min_depth = details_balance body in
      Oth.Assert.true_ (depth = 0);
      Oth.Assert.true_ (min_depth >= 0);
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

(* The Terrateam brand of a template holds the Terrateam text of the shipped
   Stategraph text. *)
let test_terrateam_brand_rewrite =
  Oth.test ~tags:[ "brand" ] ~name:"Terrateam brand rewrite" (fun _ ->
      let body =
        render_brand
          Terrat_brand.Terrateam
          Tmpl.apply_no_matching_dirspaces
          (kv
             ~tag_query:"dir:foo dir:bar"
             ~implicit_and:true
             ~suggestion:(Some "dir:foo or dir:bar"))
      in
      Oth.Assert.str_contains ~haystack:body ~needle:"terrateam apply dir:foo or dir:bar";
      Oth.Assert.str_doesnt_contain ~haystack:body ~needle:"stategraph";
      Oth.Assert.str_doesnt_contain ~haystack:body ~needle:"Stategraph")

(* #1651: the unknown-command reply is the one place a reader learns the trigger
   word, so it is stored in the shipped Stategraph wording and reaches the
   Terrateam brand through the same rewrite as every other template.  The
   negative needles carry a trailing space: the bare brand name still appears in
   the docs links, which stay on terrateam.io under both brands. *)
let test_unknown_action_brand =
  Oth.test ~tags:[ "brand" ] ~name:"Unknown action lists Stategraph commands" (fun _ ->
      let body = Tmpl.terrateam_comment_unknown_action Terrat_brand.Stategraph in
      Oth.Assert.str_contains_all
        ~haystack:body
        ~needles:[ "List of Stategraph commands:"; "`stategraph plan`"; "`stategraph apply`" ];
      Oth.Assert.str_doesnt_contain ~haystack:body ~needle:"terrateam ";
      let body = Tmpl.terrateam_comment_unknown_action Terrat_brand.Terrateam in
      Oth.Assert.str_contains_all
        ~haystack:body
        ~needles:[ "List of Terrateam commands:"; "`terrateam plan`"; "`terrateam apply`" ];
      Oth.Assert.str_doesnt_contain ~haystack:body ~needle:"stategraph ")

(* #2038: a plan whose dirspaces all came back with no changes must not tell the
   reader to apply, and a layered run must say the next layer follows on its
   own. *)
(* Resource counts from the plan step's [resource_summary] payload. *)
type counts = {
  created : int;
  updated : int;
  replaced : int;
  deleted : int;
}

let plan_complete2_kv
    ?counts
    ?(summary_unified = false)
    ~changes
    ~is_layered_run
    ~num_more_layers
    () =
  let created, updated, replaced, deleted =
    CCOption.map
      (fun { created; updated; replaced; deleted } ->
        ( CCInt.to_string created,
          CCInt.to_string updated,
          CCInt.to_string replaced,
          CCInt.to_string deleted ))
      counts
    |> CCOption.get_or ~default:("-", "-", "-", "-")
  in
  let resource_totals =
    `Assoc
      [
        ("created", `String created);
        ("updated", `String updated);
        ("replaced", `String replaced);
        ("deleted", `String deleted);
      ]
  in
  `Assoc
    [
      ("overall_success", `Bool true);
      ("summary", `Bool true);
      ("summary_unified", `Bool summary_unified);
      ("account_status", `String "active");
      ("trial_end_days", `Int 0);
      ("is_layered_run", `Bool is_layered_run);
      ("num_more_layers", `Int num_more_layers);
      ("denied_dirspaces", `List []);
      ("pre_hooks", `List []);
      ("post_hooks", `List []);
      ("gates", `List []);
      ("compact_view", `Bool false);
      ("compact_dirspaces", `Bool false);
      ( "dirspaces",
        `List
          (CCList.mapi
             (fun idx has_changes ->
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
                             ("name", `String "tf/plan");
                             ("text", `String "No changes.");
                             ("show_output", `Bool true);
                             ("success", `Bool true);
                             ("raw", `Bool false);
                             ("text_decorator", `String "diff");
                           ];
                       ] );
                   ("has_changes", `Bool has_changes);
                   ("run_url", `Null);
                   ("applied", `Bool false);
                   ("created", `String created);
                   ("updated", `String updated);
                   ("replaced", `String replaced);
                   ("deleted", `String deleted);
                 ])
             changes) );
      ("resource_totals", resource_totals);
    ]

let apply_footer = "To apply all these changes, comment:"
let no_changes_layer = "There are no changes in this layer."
let next_layer = "The next layer will now be planned."

let test_plan_complete2_no_changes_more_layers =
  Oth.test ~tags:[ "plan_complete" ] ~name:"Plan complete: no changes, more layers" (fun _ ->
      let body =
        render
          Tmpl.plan_complete2
          (plan_complete2_kv ~changes:[ false ] ~is_layered_run:true ~num_more_layers:3 ())
      in
      Oth.Assert.str_contains_all ~haystack:body ~needles:[ no_changes_layer; next_layer ];
      Oth.Assert.str_doesnt_contain ~haystack:body ~needle:apply_footer)

(* [num_more_layers] counts the layer just planned, so one remaining layer means
   this is the last one. *)
let test_plan_complete2_no_changes_last_layer =
  Oth.test ~tags:[ "plan_complete" ] ~name:"Plan complete: no changes, last layer" (fun _ ->
      let body =
        render
          Tmpl.plan_complete2
          (plan_complete2_kv ~changes:[ false ] ~is_layered_run:true ~num_more_layers:1 ())
      in
      Oth.Assert.str_contains ~haystack:body ~needle:no_changes_layer;
      Oth.Assert.str_contains ~haystack:body ~needle:"with 1 layer remaining to apply";
      Oth.Assert.str_doesnt_contain ~haystack:body ~needle:next_layer;
      Oth.Assert.str_doesnt_contain ~haystack:body ~needle:apply_footer)

let test_plan_complete2_no_changes_not_layered =
  Oth.test ~tags:[ "plan_complete" ] ~name:"Plan complete: no changes, not layered" (fun _ ->
      let body =
        render
          Tmpl.plan_complete2
          (plan_complete2_kv ~changes:[ false ] ~is_layered_run:false ~num_more_layers:0 ())
      in
      Oth.Assert.str_contains ~haystack:body ~needle:"There are no changes.";
      Oth.Assert.str_doesnt_contain ~haystack:body ~needle:"in this layer";
      Oth.Assert.str_doesnt_contain ~haystack:body ~needle:apply_footer)

(* The summary header carries the per-dirspace resource counts from the plan step's
   [resource_summary] payload, plus a totals row (#1929). *)
let test_plan_complete2_resource_summary =
  Oth.test ~tags:[ "plan_complete" ] ~name:"Plan complete: resource summary counts" (fun _ ->
      let body =
        render
          Tmpl.plan_complete2
          (plan_complete2_kv
             ~counts:{ created = 2; updated = 1; replaced = 0; deleted = 3 }
             ~changes:[ true ]
             ~is_layered_run:false
             ~num_more_layers:0
             ())
      in
      Oth.Assert.str_contains ~haystack:body ~needle:"Created | Updated | Replaced | Deleted";
      Oth.Assert.str_contains ~haystack:body ~needle:"| 2 | 1 | 0 | 3 |";
      Oth.Assert.str_contains ~haystack:body ~needle:"**Total**";
      Oth.Assert.str_contains ~haystack:body ~needle:"**2** | **1** | **0** | **3**")

let test_plan_complete2_resource_summary_missing =
  Oth.test
    ~tags:[ "plan_complete" ]
    ~name:"Plan complete: missing resource summary renders dashes"
    (fun _ ->
      let body =
        render
          Tmpl.plan_complete2
          (plan_complete2_kv ~changes:[ true ] ~is_layered_run:false ~num_more_layers:0 ())
      in
      Oth.Assert.str_contains ~haystack:body ~needle:"| - | - | - | - |";
      Oth.Assert.str_contains ~haystack:body ~needle:"**-** | **-** | **-** | **-** |")

(* In pull_request summary mode the classic comment collapses its changes table into a
   [<details>] whose summary line carries the totals of the table (#1929). *)
let test_plan_complete2_unified_details =
  Oth.test
    ~tags:[ "plan_complete" ]
    ~name:"Plan complete: unified mode wraps the changes table in details"
    (fun _ ->
      let body =
        render
          Tmpl.plan_complete2
          (plan_complete2_kv
             ~summary_unified:true
             ~counts:{ created = 2; updated = 1; replaced = 0; deleted = 3 }
             ~changes:[ true ]
             ~is_layered_run:false
             ~num_more_layers:0
             ())
      in
      Oth.Assert.str_contains
        ~haystack:body
        ~needle:"<summary>1 dirspace · 1 with changes · 0 no changes · 0 failed</summary>";
      (* A blank line must follow the </summary>: without it GitHub renders the
         table as literal text. *)
      Oth.Assert.str_contains
        ~haystack:body
        ~needle:"</summary>\n\n| Directory | Workspace | Result |";
      (* The counts live in the summary line, not repeated bold above it. *)
      Oth.Assert.str_doesnt_contain ~haystack:body ~needle:"**1 dirspace";
      let depth, min_depth = details_balance body in
      Oth.Assert.true_ (depth = 0);
      Oth.Assert.true_ (min_depth >= 0))

(* Header mode, or the summary disabled: the table stays unwrapped and always present. *)
let test_plan_complete2_header_keeps_table_open =
  Oth.test
    ~tags:[ "plan_complete" ]
    ~name:"Plan complete: header mode keeps the changes table unwrapped"
    (fun _ ->
      let body =
        render
          Tmpl.plan_complete2
          (plan_complete2_kv
             ~counts:{ created = 2; updated = 1; replaced = 0; deleted = 3 }
             ~changes:[ true ]
             ~is_layered_run:false
             ~num_more_layers:0
             ())
      in
      Oth.Assert.str_contains ~haystack:body ~needle:"Created | Updated | Replaced | Deleted";
      (* Header mode keeps the bold counts line and the table unwrapped: no
         summary wrapping the table. *)
      Oth.Assert.str_contains
        ~haystack:body
        ~needle:"**1 dirspace · 1 with changes · 0 no changes · 0 failed**\n\n| Directory |";
      Oth.Assert.str_doesnt_contain ~haystack:body ~needle:"<summary>1 dirspace")

let test_apply_complete2_unified_details =
  Oth.test
    ~tags:[ "comment_details" ]
    ~name:"Apply complete: unified mode wraps the dirspace table in details"
    (fun _ ->
      let body =
        render
          Tmpl.apply_complete2
          (apply_complete2_kv
             ~summary_unified:true
             ~compact_view:false
             ~applied:false
             ~num_dirspaces:3
             ())
      in
      Oth.Assert.str_contains
        ~haystack:body
        ~needle:"<summary>3 dirspaces · 3 applied · 0 failed</summary>";
      (* A blank line must follow the </summary>: without it GitHub renders the
         table as literal text. *)
      Oth.Assert.str_contains
        ~haystack:body
        ~needle:"</summary>\n\n| Directory | Workspace | Result |";
      (* The counts live in the summary line, not repeated bold above it. *)
      Oth.Assert.str_doesnt_contain ~haystack:body ~needle:"**3 dirspaces";
      let depth, min_depth = details_balance body in
      Oth.Assert.true_ (depth = 0);
      Oth.Assert.true_ (min_depth >= 0))

let test_plan_complete2_changes_keep_apply =
  Oth.test ~tags:[ "plan_complete" ] ~name:"Plan complete: changes keep the apply footer" (fun _ ->
      let body =
        render
          Tmpl.plan_complete2
          (plan_complete2_kv ~changes:[ true ] ~is_layered_run:true ~num_more_layers:3 ())
      in
      Oth.Assert.str_contains ~haystack:body ~needle:apply_footer;
      Oth.Assert.str_doesnt_contain ~haystack:body ~needle:"There are no changes")

(* One dirspace with changes is enough to make the apply instruction correct. *)
let test_plan_complete2_mixed_keeps_apply =
  Oth.test
    ~tags:[ "plan_complete" ]
    ~name:"Plan complete: mixed dirspaces keep the apply footer"
    (fun _ ->
      let body =
        render
          Tmpl.plan_complete2
          (plan_complete2_kv ~changes:[ true; false ] ~is_layered_run:true ~num_more_layers:3 ())
      in
      Oth.Assert.str_contains ~haystack:body ~needle:apply_footer;
      Oth.Assert.str_doesnt_contain ~haystack:body ~needle:no_changes_layer)

(* The payload [Terrat_vcs_service_github_provider] builds for a [depends_on] that
   reaches out of its stack.  The message is only useful if it names both
   directories AND both stacks: the directory alone does not say which stack it
   is in, and the stack alone does not say which line declares the
   dependency. *)
let test_depends_on_crosses_stack =
  Oth.test ~name:"depends_on crosses a stack boundary" (fun _ ->
      let body =
        render
          Tmpl.synthesize_config_err_depends_on_crosses_stack
          (`Assoc
             [
               ("dir", `String "dev/database");
               ("workspace", `String "default");
               ("stack", `String "dev");
               ("depends_on_dir", `String "prod/networking");
               ("depends_on_workspace", `String "default");
               ("depends_on_stack", `String "prod");
             ])
      in
      Oth.Assert.str_contains_all
        ~haystack:body
        ~needles:
          [
            "`depends_on` crosses a stack boundary";
            "dev/database";
            "dev";
            "prod/networking";
            "prod";
          ])

(* A cycle that mixes a [depends_on] with a stack rule.  Naming only the
   dirspaces leaves the user to guess which of the two configuration sections
   made each edge, so every line has to carry its rule. *)
let test_cycle_names_the_rule =
  Oth.test ~name:"the cycle message names the rule of each edge" (fun _ ->
      let edge ~dependent ~dependency ~rule =
        `Assoc
          [
            ("dependent_dir", `String dependent);
            ("dependent_workspace", `String "default");
            ("dependency_dir", `String dependency);
            ("dependency_workspace", `String "default");
            ("rule", `String rule);
          ]
      in
      let body =
        render
          Tmpl.synthesize_config_err_cycle
          (`Assoc
             [
               ( "cycle",
                 `List
                   [
                     edge ~dependent:"d1" ~dependency:"d2" ~rule:"plan_after";
                     edge ~dependent:"d2" ~dependency:"d1" ~rule:"depends_on";
                   ] );
             ])
      in
      Oth.Assert.str_contains_all
        ~haystack:body
        ~needles:
          [
            (* The heading the system tests match on. *)
            "## Cycle in dependency graph";
            "`d1:default` waits for `d2:default` because of `plan_after`";
            "`d2:default` waits for `d1:default` because of `depends_on`";
          ])

let test =
  Oth.parallel
    [
      test_plan_complete2_no_changes_more_layers;
      test_plan_complete2_no_changes_last_layer;
      test_plan_complete2_no_changes_not_layered;
      test_plan_complete2_resource_summary;
      test_plan_complete2_resource_summary_missing;
      test_plan_complete2_unified_details;
      test_plan_complete2_header_keeps_table_open;
      test_apply_complete2_unified_details;
      test_plan_complete2_changes_keep_apply;
      test_plan_complete2_mixed_keeps_apply;
      test_published_bodies_carry_the_self_marker;
      test_operation_failed_branch_not_found;
      test_operation_failed_compute_aborted;
      test_operation_failed_db_err;
      test_operation_failed_internal_err;
      test_operation_failed_vcs_api_err;
      test_operation_failed_vcs_api_timeout_err;
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
      test_terrateam_brand_rewrite;
      test_unknown_action_brand;
      test_depends_on_crosses_stack;
      test_cycle_names_the_rule;
    ]

let () =
  Random.self_init ();
  Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)
