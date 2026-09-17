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

(* A call the VCS never answered is a separate comment from a call that failed,
   so that the reader is told GitLab is unresponsive rather than that Stategraph
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
        ~needles:[ "req-123"; "FETCH_PULL_REQUEST"; "GitLab"; "timed out" ];
      Oth.Assert.str_doesnt_contain ~haystack:body ~needle:"UNKNOWN")

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

let plan_complete2_kv ?counts ~changes ~is_layered_run ~num_more_layers () =
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

let test =
  Oth.parallel
    [
      test_plan_complete2_brand;
      test_plan_complete2_no_changes_more_layers;
      test_plan_complete2_no_changes_last_layer;
      test_plan_complete2_no_changes_not_layered;
      test_plan_complete2_resource_summary;
      test_plan_complete2_resource_summary_missing;
      test_plan_complete2_changes_keep_apply;
      test_plan_complete2_mixed_keeps_apply;
      test_operation_failed_vcs_api_timeout_err;
      test_apply_complete2_details_many_dirspaces;
      test_apply_complete2_details_few_dirspaces;
      test_apply_complete2_details_few_dirspaces_compact_view;
      test_depends_on_crosses_stack;
      test_cycle_names_the_rule;
    ]

let () =
  Random.self_init ();
  Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)
