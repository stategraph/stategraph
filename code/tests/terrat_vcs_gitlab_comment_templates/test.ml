module Tmpl = Terrat_vcs_gitlab_comment_templates.Tmpl

(* Every template is a function of the brand.  This helper renders the
   Stategraph text; the brand test renders both brands. *)
let render_brand brand tmpl kv =
  match Minijinja.render_template (tmpl brand) kv with
  | Ok body -> body
  | Error err -> failwith err

let render tmpl kv = render_brand Terrat_brand.Stategraph tmpl kv

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

let apply_complete2_kv ~compact_view ~num_dirspaces =
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
      (* The publisher's own rule, see [Terrat_vcs_gitlab_comment_publishers]. *)
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
                 ])
             (CCList.range 1 num_dirspaces)) );
    ]

let test_apply_complete2_details ~name ~compact_view ~num_dirspaces =
  Oth.test ~tags:[ "comment_details" ] ~name (fun _ ->
      let body = render Tmpl.apply_complete2 (apply_complete2_kv ~compact_view ~num_dirspaces) in
      let depth, min_depth = details_balance body in
      Oth.Assert.true_ (depth = 0);
      Oth.Assert.true_ (min_depth >= 0);
      ())

let test_apply_complete2_details_many_dirspaces =
  test_apply_complete2_details
    ~name:"Apply complete: 10 dirspaces, normal view"
    ~compact_view:false
    ~num_dirspaces:10

let test_apply_complete2_details_few_dirspaces =
  test_apply_complete2_details
    ~name:"Apply complete: 3 dirspaces, normal view"
    ~compact_view:false
    ~num_dirspaces:3

let test_apply_complete2_details_few_dirspaces_compact_view =
  test_apply_complete2_details
    ~name:"Apply complete: 3 dirspaces, compact view"
    ~compact_view:true
    ~num_dirspaces:3

let test_operation_failed_internal_err =
  Oth.test ~name:"Operation failed internal err" (fun _ ->
      let body =
        render
          Tmpl.operation_failed_internal_err
          (`Assoc [ ("request_id", `String "req-123"); ("tag", `String "EXPECTED_REPO_TREE") ])
      in
      Oth.Assert.str_contains_all
        ~haystack:body
        ~needles:
          [
            "req-123"; "EXPECTED_REPO_TREE"; "the later layers were not planned"; "stategraph plan";
          ];
      (* Every tag this template renders names a database or in-process state failure, not a forge
         call, so the comment must not claim a retry happened. *)
      Oth.Assert.str_doesnt_contain ~haystack:body ~needle:"tried this call again")

(* A call the VCS never answered is a separate comment from a call that failed,
   so that the reader is told GitLab is unresponsive rather than that Stategraph
   broke. *)
(* A call the VCS refused for a rate limit is a separate comment from one it
   never answered: the reader is told to wait, not that GitLab is down. *)
let test_operation_failed_vcs_api_rate_limit_err =
  Oth.test ~name:"Operation failed vcs api rate limit err" (fun _ ->
      let body =
        render
          Tmpl.operation_failed_vcs_api_rate_limit_err
          (`Assoc [ ("request_id", `String "req-123"); ("operation", `String "FETCH_PULL_REQUEST") ])
      in
      Oth.Assert.str_contains_all
        ~haystack:body
        ~needles:[ "req-123"; "FETCH_PULL_REQUEST"; "GitLab"; "rate limit" ];
      Oth.Assert.str_doesnt_contain ~haystack:body ~needle:"UNKNOWN")

let test_operation_failed_vcs_api_timeout_err =
  Oth.test ~name:"Operation failed vcs api timeout err" (fun _ ->
      let body =
        render
          Tmpl.operation_failed_vcs_api_timeout_err
          (`Assoc [ ("request_id", `String "req-123"); ("operation", `String "FETCH_PULL_REQUEST") ])
      in
      Oth.Assert.str_contains_all
        ~haystack:body
        ~needles:[ "req-123"; "FETCH_PULL_REQUEST"; "GitLab"; "timed out" ];
      Oth.Assert.str_doesnt_contain ~haystack:body ~needle:"UNKNOWN")

(* #2038: a plan whose dirspaces all came back with no changes must not tell the
   reader to apply, and a layered run must say the next layer follows on its
   own. *)
(* Resource counts from the plan step's [resource_summary] payload. *)
type counts = {
  imported : int;
  created : int;
  updated : int;
  replaced : int;
  deleted : int;
}

let plan_complete2_kv ?counts ~changes ~is_layered_run ~num_more_layers () =
  let imported, created, updated, replaced, deleted =
    CCOption.map
      (fun { imported; created; updated; replaced; deleted } ->
        ( CCInt.to_string imported,
          CCInt.to_string created,
          CCInt.to_string updated,
          CCInt.to_string replaced,
          CCInt.to_string deleted ))
      counts
    |> CCOption.get_or ~default:("-", "-", "-", "-", "-")
  in
  let resource_totals =
    `Assoc
      [
        ("imported", `String imported);
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
                   ("imported", `String imported);
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

let test_plan_complete2_upgrade_link =
  Oth.test ~tags:[ "plan_complete" ] ~name:"Plan complete: upgrade link" (fun _ ->
      let kv =
        Yojson.Safe.Util.combine
          (plan_complete2_kv ~changes:[ false ] ~is_layered_run:false ~num_more_layers:0 ())
          (`Assoc
             [
               ("runs_used", `Int 9);
               ("runs_limit", `Int 10);
               ("subscription_url", `String "https://app.stategraph.com/settings/");
             ])
      in
      let body = render_brand Terrat_brand.Terrateam Tmpl.plan_complete2 kv in
      Oth.Assert.str_contains
        ~haystack:body
        ~needle:"[upgrade your plan](https://app.stategraph.com/settings/)")

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
             ~counts:{ imported = 4; created = 2; updated = 1; replaced = 0; deleted = 3 }
             ~changes:[ true ]
             ~is_layered_run:false
             ~num_more_layers:0
             ())
      in
      Oth.Assert.str_contains_all
        ~haystack:body
        ~needles:
          [
            "| Result | Import | Create | Update | Replace | Delete |";
            "| 4 | 2 | 1 | 0 | 3 |";
            "**Total**";
            "| **4** | **2** | **1** | **0** | **3** |";
          ])

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
      Oth.Assert.str_contains_all
        ~haystack:body
        ~needles:[ "| - | - | - | - | - |"; "| **-** | **-** | **-** | **-** | **-** |" ])

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

(* The payload [Terrat_vcs_service_gitlab_provider] builds for a [depends_on] that
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

(* One load of the module renders a template for both brands. *)
let test_plan_complete2_brand =
  Oth.test ~tags:[ "brand" ] ~name:"Plan complete: the heading follows the brand" (fun _ ->
      let kv = plan_complete2_kv ~changes:[ true ] ~is_layered_run:false ~num_more_layers:0 () in
      let stategraph = render_brand Terrat_brand.Stategraph Tmpl.plan_complete2 kv in
      Oth.Assert.str_contains ~haystack:stategraph ~needle:"## Stategraph Plan Output";
      Oth.Assert.str_doesnt_contain ~haystack:stategraph ~needle:"Terrateam";
      let terrateam = render_brand Terrat_brand.Terrateam Tmpl.plan_complete2 kv in
      Oth.Assert.str_contains ~haystack:terrateam ~needle:"## Terrateam Plan Output";
      Oth.Assert.str_doesnt_contain ~haystack:terrateam ~needle:"Stategraph")

(* The data of the stale message, rendered through the JSON the provider sends to the template, so
   the template and the record cannot disagree about a name.  See RFD 2356. *)
let stale_kv
    ?(is_plan = false)
    ?(files_unknown = false)
    ?(is_layered_run = false)
    ?(replan_dirs = [])
    ?(branch_move = Some ("aaaa111", "bbbb222"))
    ?dest_branch_move
    dirspaces =
  let module St = Terrat_vcs_provider2.Work_manifest_stale in
  let move = CCOption.map (fun (from_sha, to_sha) -> { St.Move.from_sha; to_sha }) in
  St.to_yojson
    {
      St.is_plan;
      files_unknown;
      run_sha = "aaaa111";
      branch_move = move branch_move;
      dest_branch_move = move dest_branch_move;
      dirspaces = CCList.map (fun (dir, workspace) -> { St.Dirspace.dir; workspace }) dirspaces;
      is_layered_run;
      replan_dirs;
    }

(* A plan whose files changed must tell the user to plan again, and name what changed. *)
let test_work_manifest_stale_plan =
  Oth.test ~name:"Stale plan names the changed dirspaces and asks for a new plan" (fun _ ->
      let body = render Tmpl.work_manifest_stale (stale_kv ~is_plan:true [ ("tf", "default") ]) in
      Oth.Assert.str_contains_all
        ~haystack:body
        ~needles:
          [
            "Commits moved during this plan";
            "aaaa111";
            "bbbb222";
            "| `tf` | `default` |";
            "This plan is stale.";
            "stategraph plan";
          ];
      Oth.Assert.str_doesnt_contain ~haystack:body ~needle:"The apply is complete";
      ())

(* A stale apply applied its commit and not the head: the message says so and asks for a new plan
   and apply. *)
let test_work_manifest_stale_apply =
  Oth.test ~name:"Stale apply does not apply the head and asks for a new plan" (fun _ ->
      let body = render Tmpl.work_manifest_stale (stale_kv [ ("tf", "default") ]) in
      Oth.Assert.str_contains_all
        ~haystack:body
        ~needles:
          [
            "Commits moved during this apply";
            "| `tf` | `default` |";
            "The files of these directories are different at the head, thus the head is not \
             applied.";
            "Plan and apply these directories again.";
            "stategraph plan";
          ];
      Oth.Assert.str_doesnt_contain ~haystack:body ~needle:"The apply is complete";
      Oth.Assert.str_doesnt_contain ~haystack:body ~needle:"You can continue";
      Oth.Assert.str_doesnt_contain ~haystack:body ~needle:"This plan is stale.";
      Oth.Assert.str_doesnt_contain ~haystack:body ~needle:"plan dir:";
      ())

(* An apply whose files cannot be compared does not apply the head either. *)
let test_work_manifest_stale_apply_files_unknown =
  Oth.test ~name:"Stale apply with unknown files does not apply the head" (fun _ ->
      let body = render Tmpl.work_manifest_stale (stale_kv ~files_unknown:true []) in
      Oth.Assert.str_contains
        ~haystack:body
        ~needle:"The files of the directories of this apply can be different at the head";
      ())

(* A move of the destination branch only names the commits of the destination branch: the branch of
   the run did not move. *)
let test_work_manifest_stale_dest_branch_move =
  Oth.test ~name:"Stale message names the commits of the destination branch" (fun _ ->
      let body =
        render
          Tmpl.work_manifest_stale
          (stale_kv
             ~branch_move:None
             ~dest_branch_move:("cccc333", "dddd444")
             [ ("tf", "default") ])
      in
      Oth.Assert.str_contains
        ~haystack:body
        ~needle:
          "The destination branch was at commit `cccc333` when the run started.  Its head is now \
           `dddd444`.";
      Oth.Assert.str_doesnt_contain ~haystack:body ~needle:"The branch was at commit";
      ())

(* A tree that is not stored means nothing was compared, which the message must say instead of
   listing directories. *)
let test_work_manifest_stale_files_unknown =
  Oth.test ~name:"Stale message when the files cannot be compared" (fun _ ->
      let body = render Tmpl.work_manifest_stale (stale_kv ~files_unknown:true []) in
      Oth.Assert.str_contains ~haystack:body ~needle:"cannot compare the files";
      Oth.Assert.str_doesnt_contain ~haystack:body ~needle:"| Directory | Workspace |";
      ())

(* A stale layer tells the user how to go back to it: one plan command per directory. *)
let test_work_manifest_stale_layer =
  Oth.test ~name:"Stale layer gives the commands to plan it again" (fun _ ->
      let body =
        render
          Tmpl.work_manifest_stale
          (stale_kv
             ~is_layered_run:true
             ~replan_dirs:[ "network"; "dns" ]
             [ ("network", "default") ])
      in
      Oth.Assert.str_contains_all
        ~haystack:body
        ~needles:
          [
            "The layers that depend on them do not run until the head is applied.";
            "stategraph plan dir:network";
            "stategraph plan dir:dns";
          ];
      Oth.Assert.str_doesnt_contain ~haystack:body ~needle:"The next layers run";
      ())

(* The trigger word is in the template, so the brand rewrite reaches it. *)
let test_work_manifest_stale_brand =
  Oth.test ~name:"Stale message uses the trigger word of the brand" (fun _ ->
      let body =
        render_brand
          Terrat_brand.Terrateam
          Tmpl.work_manifest_stale
          (stale_kv ~is_plan:true [ ("tf", "default") ])
      in
      Oth.Assert.str_contains ~haystack:body ~needle:"terrateam plan";
      ())

(* The publisher adds the stale report to the data of the output comment as the key [stale]. *)
let with_stale stale = function
  | `Assoc fields -> `Assoc (CCList.Assoc.set ~eq:CCString.equal "stale" stale fields)
  | kv -> kv

(* The lines of the warning in [body]: from [> [!WARNING]] to the first blank line. *)
let warning_lines body =
  CCString.lines body
  |> CCList.drop_while (fun line -> not (CCString.equal line "> [!WARNING]"))
  |> CCList.take_while (fun line -> not (CCString.is_empty line))

(* The last line of the warning links to the documentation of stale runs. *)
let stale_docs_link = function
  | Terrat_brand.Stategraph ->
      "> [How Stategraph handles commits that move during a \
       run](https://stategraph.com/docs/orchestration/workflows/stale-runs)"
  | Terrat_brand.Terrateam ->
      "> [How Terrateam handles commits that move during a \
       run](https://terrateam.io/docs/orchestration/workflows/stale-runs)"

(* Every line of the warning is in the quote, else the forge shows the rest as normal text. *)
let assert_warning ~needles body =
  let lines = warning_lines body in
  Oth.Assert.not_true (CCList.is_empty lines);
  Oth.Assert.true_ (CCList.for_all (CCString.prefix ~pre:">") lines);
  Oth.Assert.str_contains_all ~haystack:(CCString.concat "\n" lines) ~needles;
  Oth.Assert.str_contains ~haystack:body ~needle:(stale_docs_link Terrat_brand.Stategraph ^ "\n\n")

(* A stale apply shows the warning directly under the heading of the apply comment. *)
let test_apply_complete2_stale =
  Oth.test ~tags:[ "stale" ] ~name:"Apply complete: a stale apply shows a warning" (fun _ ->
      let body =
        render
          Tmpl.apply_complete2
          (with_stale
             (stale_kv [ ("tf", "default") ])
             (apply_complete2_kv ~compact_view:false ~num_dirspaces:1))
      in
      Oth.Assert.str_contains
        ~haystack:body
        ~needle:
          "## Applies :white_check_mark:\n\n> [!WARNING]\n> **Commits moved during this apply.**";
      assert_warning
        ~needles:
          [
            "The branch was at commit `aaaa111`";
            "> | `tf` | `default` |";
            "The files of these directories are different at the head, thus the head is not \
             applied.";
            "> stategraph plan";
          ]
        body;
      ())

(* A stale layer gives the commands to plan it again in the warning. *)
let test_apply_complete2_stale_layer =
  Oth.test ~tags:[ "stale" ] ~name:"Apply complete: a stale layer shows the plan commands" (fun _ ->
      let body =
        render
          Tmpl.apply_complete2
          (with_stale
             (stale_kv
                ~is_layered_run:true
                ~replan_dirs:[ "network"; "dns" ]
                [ ("network", "default") ])
             (apply_complete2_kv ~compact_view:false ~num_dirspaces:1))
      in
      assert_warning ~needles:[ "> stategraph plan dir:network"; "> stategraph plan dir:dns" ] body;
      ())

(* A failed plan is stale too: the warning is under the heading of the failure. *)
let test_plan_complete2_stale_failed =
  Oth.test ~tags:[ "stale" ] ~name:"Plan complete: a failed stale plan shows a warning" (fun _ ->
      let kv =
        match plan_complete2_kv ~changes:[ true ] ~is_layered_run:false ~num_more_layers:0 () with
        | `Assoc fields ->
            `Assoc (CCList.Assoc.set ~eq:CCString.equal "overall_success" (`Bool false) fields)
        | kv -> kv
      in
      let body =
        render Tmpl.plan_complete2 (with_stale (stale_kv ~is_plan:true ~files_unknown:true []) kv)
      in
      Oth.Assert.str_contains
        ~haystack:body
        ~needle:
          "## Plans :heavy_multiplication_x:\n\n> [!WARNING]\n> **Commits moved during this plan.**";
      assert_warning ~needles:[ "cannot compare the files"; "This plan is stale." ] body;
      ())

(* Each stale message links to the documentation of stale runs, in the name and on the site of its
   brand. *)
let test_stale_docs_link =
  Oth.test ~tags:[ "stale" ] ~name:"Stale messages link to the documentation" (fun _ ->
      let link brand = CCString.drop 2 (stale_docs_link brand) in
      let apply_kv =
        with_stale
          (stale_kv [ ("tf", "default") ])
          (apply_complete2_kv ~compact_view:false ~num_dirspaces:1)
      in
      let stale_msg_kv = stale_kv [ ("tf", "default") ] in
      CCList.iter
        (fun brand ->
          Oth.Assert.str_contains
            ~haystack:(render_brand brand Tmpl.apply_complete2 apply_kv)
            ~needle:(link brand);
          Oth.Assert.str_contains
            ~haystack:(render_brand brand Tmpl.work_manifest_stale stale_msg_kv)
            ~needle:(link brand))
        Terrat_brand.all;
      ())

(* A result that is not stale has no warning. *)
let test_plan_complete2_not_stale =
  Oth.test
    ~tags:[ "stale" ]
    ~name:"Plan complete: a plan that is not stale has no warning"
    (fun _ ->
      let body =
        render
          Tmpl.plan_complete2
          (with_stale
             `Null
             (plan_complete2_kv ~changes:[ true ] ~is_layered_run:false ~num_more_layers:0 ()))
      in
      Oth.Assert.str_doesnt_contain ~haystack:body ~needle:"Commits moved";
      Oth.Assert.str_doesnt_contain ~haystack:body ~needle:"[!WARNING]";
      ())

(* The GitLab work-manifest templates are Snabela templates; the helpers above render the Jinja
   ones.  The same renderer the GitHub template tests use. *)
let render_snabela template kv =
  match Snabela.apply (template Terrat_brand.Stategraph) kv with
  | Ok body -> body
  | Error (#Snabela.err as err) -> failwith (Snabela.show_err err)

(* A workflow that never started stops any layered run it belonged to: the body names the later
   layers and the command that plans them. *)
let test_failed_to_start_workflow =
  Oth.test ~name:"Failed to start workflow" (fun _ ->
      let body = render_snabela Tmpl.failed_to_start_workflow Snabela.Kv.Map.empty in
      Oth.Assert.str_contains_all
        ~haystack:body
        ~needles:
          [ "Unable to start workflow."; "the later layers were not planned"; "stategraph plan" ];
      (* A workflow start can fail without a retry, for example a first-attempt rate limit, so the
         comment must not claim one happened. *)
      Oth.Assert.str_doesnt_contain ~haystack:body ~needle:"tried this call again")

(* The [work_manifests] table rows both providers build for every message that lists work
   manifests, see [work_manifests_kv] in the service providers. *)
let work_manifests_rows rows =
  Snabela.Kv.(
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
         rows))

(* Builds the payload the publishers build.  The table has one row per listed run.  The unlock
   command iterates the [unlock_ids] list, and the publisher has already deduped that list. *)
let work_manifests_kv ~unlock_ids rows =
  Snabela.Kv.(
    Map.of_list
      [
        ("work_manifests", work_manifests_rows rows);
        ("unlock_ids", list (CCList.map (fun id -> Map.of_list [ ("id", string id) ]) unlock_ids));
      ])

let test_apply_queued_behind_pull_request =
  Oth.test ~name:"Apply queued behind a pull request" (fun _ ->
      let body =
        render_snabela
          Tmpl.apply_queued_behind_work_manifests
          (work_manifests_kv
             ~unlock_ids:[ "42" ]
             [ ("42", true, "Plan", "Running", "2026-8-21 9:14") ])
      in
      Oth.Assert.str_contains ~haystack:body ~needle:"Apply queued";
      Oth.Assert.str_contains_all
        ~haystack:body
        ~needles:[ "#42"; "Plan"; "Running"; "stategraph unlock 42" ])

let test_apply_queued_behind_drift =
  Oth.test ~name:"Apply queued behind drift" (fun _ ->
      let body =
        render_snabela
          Tmpl.apply_queued_behind_work_manifests
          (work_manifests_kv
             ~unlock_ids:[ "drift" ]
             [ ("drift", false, "Plan", "Running", "2026-8-21 0:02") ])
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
             ~unlock_ids:[ "42"; "drift" ]
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
          (work_manifests_kv
             ~unlock_ids:[ "42" ]
             [ ("42", true, "Apply", "Queued", "2026-8-21 9:25") ])
      in
      Oth.Assert.str_contains ~haystack:body ~needle:"Apply already queued or running";
      Oth.Assert.str_doesnt_contain ~haystack:body ~needle:"Apply already in progress")

(* The ids arrive pre-deduped from the publisher, so these tests cannot see a publisher that
   fails to dedupe.  What they pin is that the template iterates [unlock_ids], not
   [work_manifests]: the same pull request with three stuck runs renders one unlock token, not
   three, and every drift target shares the one [drift] token. *)
let test_maybe_stale_work_manifests_unlock_key =
  Oth.test ~name:"Maybe stale unlock command uses the unlock ids key" (fun _ ->
      let body =
        render_snabela
          Tmpl.maybe_stale_work_manifests
          (work_manifests_kv
             ~unlock_ids:[ "123"; "drift" ]
             [
               ("123", true, "Plan", "Queued", "2026-8-21 9:14");
               ("123", true, "Plan", "Queued", "2026-8-21 9:20");
               ("drift", false, "Plan", "Queued", "2026-8-21 0:02");
               ("drift", false, "Plan", "Queued", "2026-8-21 0:40");
               ("123", true, "Plan", "Queued", "2026-8-21 9:44");
             ])
      in
      Oth.Assert.str_contains ~haystack:body ~needle:"stategraph unlock 123 drift";
      Oth.Assert.str_doesnt_contain ~haystack:body ~needle:"unlock 123 123";
      Oth.Assert.str_doesnt_contain ~haystack:body ~needle:"drift drift";
      (* The table keeps one row per stuck run even though the command dedupes. *)
      Oth.Assert.str_contains ~haystack:body ~needle:"| #123 | Plan | Queued | 2026-8-21 9:44 UTC |";
      Oth.Assert.str_contains
        ~haystack:body
        ~needle:"| drift | Plan | Queued | 2026-8-21 0:40 UTC |";
      ())

let test_conflicting_work_manifests_unlock_key =
  Oth.test ~name:"Conflicting unlock command uses the unlock ids key" (fun _ ->
      let body =
        render_snabela
          Tmpl.conflicting_work_manifests
          (work_manifests_kv
             ~unlock_ids:[ "123"; "45" ]
             [
               ("123", true, "Apply", "Queued", "2026-8-21 9:11");
               ("123", true, "Apply", "Queued", "2026-8-21 9:12");
               ("45", true, "Plan", "Queued", "2026-8-21 8:50");
             ])
      in
      Oth.Assert.str_contains ~haystack:body ~needle:"stategraph unlock 123 45";
      Oth.Assert.str_doesnt_contain ~haystack:body ~needle:"unlock 123 123";
      Oth.Assert.str_contains
        ~haystack:body
        ~needle:"| #123 | Apply | Queued | 2026-8-21 9:12 UTC |";
      ())

(* The payload the providers build for [Msg.Missing_plans]: one reason string
   per row, with [invalidated_by] null unless the reason names the pull request
   that superseded the plan. *)
let missing_plans_kv rows =
  `Assoc
    [
      ( "dirspaces",
        `List
          (CCList.map
             (fun (dir, workspace, reason, invalidated_by) ->
               `Assoc
                 [
                   ("dir", `String dir);
                   ("workspace", `String workspace);
                   ("reason", `String reason);
                   ( "invalidated_by",
                     match invalidated_by with
                     | Some n -> `Int n
                     | None -> `Null );
                 ])
             rows) );
      ( "any_invalidated",
        `Bool (CCList.exists (fun (_, _, _, invalidated_by) -> invalidated_by <> None) rows) );
      ( "any_plan_in_progress",
        `Bool (CCList.exists (fun (_, _, reason, _) -> String.equal reason "plan_in_progress") rows)
      );
      ( "any_plan_needed",
        `Bool
          (CCList.exists
             (fun (_, _, reason, _) -> not (String.equal reason "plan_in_progress"))
             rows) );
    ]

let render_missing_plans rows = render Tmpl.missing_plans (missing_plans_kv rows)

let test_missing_plans_never_planned =
  Oth.test ~name:"Missing plans: never planned" (fun _ ->
      let body = render_missing_plans [ ("foo", "default", "never_planned", None) ] in
      Oth.Assert.str_contains ~haystack:body ~needle:"Never planned on this ref";
      Oth.Assert.str_doesnt_contain ~haystack:body ~needle:"superseded")

let test_missing_plans_invalidated =
  Oth.test ~name:"Missing plans: invalidated names the merge request" (fun _ ->
      let body = render_missing_plans [ ("foo", "default", "invalidated", Some 849) ] in
      Oth.Assert.str_contains ~haystack:body ~needle:"Plan superseded by #849";
      Oth.Assert.str_doesnt_contain ~haystack:body ~needle:"Never planned")

let test_missing_plans_last_run_failed =
  Oth.test ~name:"Missing plans: last run failed" (fun _ ->
      let body = render_missing_plans [ ("foo", "default", "last_run_failed", None) ] in
      Oth.Assert.str_contains ~haystack:body ~needle:"The last run for this directory failed";
      Oth.Assert.str_doesnt_contain ~haystack:body ~needle:"superseded")

let test_missing_plans_stale =
  Oth.test ~name:"Missing plans: a stale plan" (fun _ ->
      let body = render_missing_plans [ ("foo", "default", "stale", None) ] in
      Oth.Assert.str_contains
        ~haystack:body
        ~needle:"The commits moved while this directory was planned, plan it again";
      Oth.Assert.str_doesnt_contain ~haystack:body ~needle:"Never planned")

let test_missing_plans_out_of_order =
  Oth.test ~name:"Missing plans: a plan older than a run of its dependency" (fun _ ->
      let body = render_missing_plans [ ("foo", "default", "out_of_order", None) ] in
      Oth.Assert.str_contains
        ~haystack:body
        ~needle:"A directory this one depends on ran after this plan, plan it again";
      Oth.Assert.str_doesnt_contain ~haystack:body ~needle:"The commits moved")

let test_missing_plans_mixed_reasons =
  Oth.test ~name:"Missing plans: every reason renders in one table" (fun _ ->
      let body =
        render_missing_plans
          [
            ("a", "default", "never_planned", None);
            ("b", "default", "invalidated", Some 12);
            ("c", "default", "last_run_failed", None);
          ]
      in
      Oth.Assert.str_contains ~haystack:body ~needle:"Never planned on this ref";
      Oth.Assert.str_contains ~haystack:body ~needle:"Plan superseded by #12";
      Oth.Assert.str_contains ~haystack:body ~needle:"The last run for this directory failed")

let test_missing_plans_plan_in_progress =
  Oth.test ~name:"Missing plans: a plan in progress tells the user to wait" (fun _ ->
      let body = render_missing_plans [ ("foo", "default", "plan_in_progress", None) ] in
      Oth.Assert.str_contains ~haystack:body ~needle:"queued or running";
      Oth.Assert.str_contains ~haystack:body ~needle:"stategraph apply";
      Oth.Assert.str_doesnt_contain ~haystack:body ~needle:"stategraph plan")

let test_missing_plans_plan_in_progress_mixed =
  Oth.test
    ~name:"Missing plans: a mixed table shows both the plan and the apply instruction"
    (fun _ ->
      let body =
        render_missing_plans
          [ ("a", "default", "plan_in_progress", None); ("b", "default", "never_planned", None) ]
      in
      Oth.Assert.str_contains ~haystack:body ~needle:"Never planned on this ref";
      Oth.Assert.str_contains ~haystack:body ~needle:"stategraph plan";
      Oth.Assert.str_contains ~haystack:body ~needle:"stategraph apply")

(* The payload the providers build for [Msg.Plan_already_planned]: one reason
   string per row.  The two reasons are not the same answer, so each one has to
   reach the table on its own. *)
let plan_already_planned_kv rows =
  `Assoc
    [
      ( "dirspaces",
        `List
          (CCList.map
             (fun (dir, workspace, reason) ->
               `Assoc
                 [
                   ("dir", `String dir); ("workspace", `String workspace); ("reason", `String reason);
                 ])
             rows) );
      ( "any_already_planned",
        `Bool (CCList.exists (fun (_, _, reason) -> String.equal reason "already_planned") rows) );
    ]

let render_plan_already_planned rows =
  render Tmpl.plan_already_planned (plan_already_planned_kv rows)

let test_plan_already_planned_standing =
  Oth.test ~name:"Plan already planned: a standing plan says so" (fun _ ->
      let body = render_plan_already_planned [ ("foo", "default", "already_planned") ] in
      Oth.Assert.str_contains
        ~haystack:body
        ~needle:"Already has a plan for the files as they are now";
      Oth.Assert.str_contains ~haystack:body ~needle:"stategraph plan dir:<path>";
      Oth.Assert.str_doesnt_contain ~haystack:body ~needle:"queued or running")

let test_plan_already_planned_in_progress =
  Oth.test ~name:"Plan already planned: a plan in flight tells the user to wait" (fun _ ->
      let body = render_plan_already_planned [ ("foo", "default", "plan_in_progress") ] in
      Oth.Assert.str_contains
        ~haystack:body
        ~needle:"A plan for this directory is queued or running";
      Oth.Assert.str_doesnt_contain ~haystack:body ~needle:"Already has a plan";
      (* Nothing is waiting on a file change, so the force-a-plan hint would answer a question
         the user did not ask. *)
      Oth.Assert.str_doesnt_contain ~haystack:body ~needle:"stategraph plan dir:<path>")

let test_plan_already_planned_mixed =
  Oth.test ~name:"Plan already planned: both reasons render in one table" (fun _ ->
      let body =
        render_plan_already_planned
          [ ("a", "default", "already_planned"); ("b", "default", "plan_in_progress") ]
      in
      Oth.Assert.str_contains
        ~haystack:body
        ~needle:"Already has a plan for the files as they are now";
      Oth.Assert.str_contains
        ~haystack:body
        ~needle:"A plan for this directory is queued or running";
      Oth.Assert.str_contains ~haystack:body ~needle:"stategraph plan dir:<path>")

let test =
  Oth.parallel
    [
      test_work_manifest_stale_plan;
      test_work_manifest_stale_apply;
      test_work_manifest_stale_apply_files_unknown;
      test_work_manifest_stale_dest_branch_move;
      test_work_manifest_stale_files_unknown;
      test_work_manifest_stale_layer;
      test_work_manifest_stale_brand;
      test_apply_complete2_stale;
      test_stale_docs_link;
      test_apply_complete2_stale_layer;
      test_plan_complete2_stale_failed;
      test_plan_complete2_not_stale;
      test_plan_complete2_brand;
      test_plan_complete2_no_changes_more_layers;
      test_plan_complete2_no_changes_last_layer;
      test_plan_complete2_no_changes_not_layered;
      test_plan_complete2_upgrade_link;
      test_plan_complete2_resource_summary;
      test_plan_complete2_resource_summary_missing;
      test_plan_complete2_changes_keep_apply;
      test_plan_complete2_mixed_keeps_apply;
      test_operation_failed_internal_err;
      test_operation_failed_vcs_api_rate_limit_err;
      test_operation_failed_vcs_api_timeout_err;
      test_failed_to_start_workflow;
      test_apply_complete2_details_many_dirspaces;
      test_apply_complete2_details_few_dirspaces;
      test_apply_complete2_details_few_dirspaces_compact_view;
      test_depends_on_crosses_stack;
      test_cycle_names_the_rule;
      test_apply_queued_behind_pull_request;
      test_apply_queued_behind_drift;
      test_apply_queued_behind_both_kinds;
      test_conflicting_work_manifests_title;
      test_maybe_stale_work_manifests_unlock_key;
      test_conflicting_work_manifests_unlock_key;
      test_missing_plans_never_planned;
      test_missing_plans_invalidated;
      test_missing_plans_last_run_failed;
      test_missing_plans_stale;
      test_missing_plans_out_of_order;
      test_missing_plans_mixed_reasons;
      test_missing_plans_plan_in_progress;
      test_missing_plans_plan_in_progress_mixed;
      test_plan_already_planned_standing;
      test_plan_already_planned_in_progress;
      test_plan_already_planned_mixed;
    ]

let () =
  Random.self_init ();
  Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)
