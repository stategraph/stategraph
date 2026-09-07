(* Round-trip tests for the new Engine.Stategraph variant in v1 base config.
   Drives through the public of_version_1_json / to_version_1 surface so we
   exercise the new pattern-match arms in of_version_1_engine and
   to_version_1_engine end to end. *)

module V1 = Terrat_base_repo_config_v1
module Repo = Terrat_repo_config
module Sg_schema = Terrat_repo_config.Engine_stategraph

let pp_engine = function
  | V1.Engine.Stategraph _ -> "Stategraph"
  | V1.Engine.Cdktf _ -> "Cdktf"
  | V1.Engine.Custom _ -> "Custom"
  | V1.Engine.Fly _ -> "Fly"
  | V1.Engine.Opentofu _ -> "Opentofu"
  | V1.Engine.Other _ -> "Other"
  | V1.Engine.Pulumi -> "Pulumi"
  | V1.Engine.Terraform _ -> "Terraform"
  | V1.Engine.Terragrunt _ -> "Terragrunt"

let test_of_version_1_json_minimal =
  Oth.test ~name:"of_version_1_json: stategraph engine (no version)" (fun _ ->
      let json = `Assoc [ ("engine", `Assoc [ ("name", `String "stategraph") ]) ] in
      match V1.of_version_1_json json with
      | Ok cfg -> (
          match V1.engine cfg with
          | V1.Engine.Stategraph { V1.Engine.Stategraph.version = None; _ } -> ()
          | other ->
              failwith
                (Printf.sprintf
                   "Expected Engine.Stategraph with version=None, got %s"
                   (pp_engine other)))
      | Error _ -> failwith "of_version_1_json failed on minimal stategraph engine config")

let test_of_version_1_json_with_version =
  Oth.test ~name:"of_version_1_json: stategraph engine (with version)" (fun _ ->
      let json =
        `Assoc
          [ ("engine", `Assoc [ ("name", `String "stategraph"); ("version", `String "1.2.1") ]) ]
      in
      match V1.of_version_1_json json with
      | Ok cfg -> (
          match V1.engine cfg with
          | V1.Engine.Stategraph { V1.Engine.Stategraph.version = Some "1.2.1"; _ } -> ()
          | other ->
              failwith
                (Printf.sprintf
                   "Expected Engine.Stategraph with version=Some 1.2.1, got %s"
                   (pp_engine other)))
      | Error _ -> failwith "of_version_1_json failed on stategraph engine with version")

let test_to_version_1_round_trip =
  Oth.test ~name:"to_version_1: stategraph engine round-trips through Version_1" (fun _ ->
      let json =
        `Assoc
          [ ("engine", `Assoc [ ("name", `String "stategraph"); ("version", `String "1.2.1") ]) ]
      in
      match V1.of_version_1_json json with
      | Ok cfg -> (
          let v1 = V1.to_version_1 cfg in
          match v1.Repo.Version_1.engine with
          | Some
              (Repo.Engine.Engine_stategraph
                 { Sg_schema.name = `Stategraph; version = Some "1.2.1"; _ }) -> ()
          | _ -> failwith "Round-trip to Version_1 did not produce Engine_stategraph")
      | Error _ -> failwith "of_version_1_json failed in round-trip setup")

(* Tests for the global [lock_policy] key.  A workflow entry that does not set
   [lock_policy] inherits the global value, an entry that sets it overrides the
   global value, and the global value round-trips through Version_1. *)

let pp_lock_policy = function
  | V1.Workflows.Entry.Lock_policy.Apply -> "apply"
  | V1.Workflows.Entry.Lock_policy.Merge -> "merge"
  | V1.Workflows.Entry.Lock_policy.None -> "none"
  | V1.Workflows.Entry.Lock_policy.Strict -> "strict"

let config_of_json json =
  match V1.of_version_1_json json with
  | Ok cfg -> cfg
  | Error _ -> failwith "of_version_1_json failed"

let assert_lock_policy expected actual =
  if not (V1.Workflows.Entry.Lock_policy.equal expected actual) then
    failwith
      (Printf.sprintf
         "Expected lock_policy %s, got %s"
         (pp_lock_policy expected)
         (pp_lock_policy actual))

let test_lock_policy_default =
  Oth.test ~name:"lock_policy: defaults to strict" (fun _ ->
      assert_lock_policy
        V1.Workflows.Entry.Lock_policy.Strict
        (V1.lock_policy (config_of_json (`Assoc []))))

let test_lock_policy_global =
  Oth.test ~name:"lock_policy: global value is read" (fun _ ->
      assert_lock_policy
        V1.Workflows.Entry.Lock_policy.Merge
        (V1.lock_policy (config_of_json (`Assoc [ ("lock_policy", `String "merge") ]))))

let test_lock_policy_workflow_inherits =
  Oth.test ~name:"lock_policy: workflow entry inherits the global value" (fun _ ->
      let json =
        `Assoc
          [
            ("lock_policy", `String "apply");
            ("workflows", `List [ `Assoc [ ("tag_query", `String "") ] ]);
          ]
      in
      match V1.workflows (config_of_json json) with
      | [ { V1.Workflows.Entry.lock_policy; _ } ] ->
          assert_lock_policy V1.Workflows.Entry.Lock_policy.Apply lock_policy
      | _ -> failwith "Expected exactly one workflow entry")

let test_lock_policy_workflow_overrides =
  Oth.test ~name:"lock_policy: workflow entry overrides the global value" (fun _ ->
      let json =
        `Assoc
          [
            ("lock_policy", `String "apply");
            ( "workflows",
              `List [ `Assoc [ ("tag_query", `String ""); ("lock_policy", `String "none") ] ] );
          ]
      in
      match V1.workflows (config_of_json json) with
      | [ { V1.Workflows.Entry.lock_policy; _ } ] ->
          assert_lock_policy V1.Workflows.Entry.Lock_policy.None lock_policy
      | _ -> failwith "Expected exactly one workflow entry")

let test_lock_policy_to_version_1_round_trip =
  Oth.test ~name:"lock_policy: global value round-trips through Version_1" (fun _ ->
      let cfg = config_of_json (`Assoc [ ("lock_policy", `String "none") ]) in
      let v1 = V1.to_version_1 cfg in
      match v1.Repo.Version_1.lock_policy with
      | `None -> ()
      | _ -> failwith "Round-trip to Version_1 did not preserve lock_policy")

let storage_none_json = `Assoc [ ("plans", `Assoc [ ("method", `String "none") ]) ]

let storage_none_unsafe_json =
  `Assoc
    [ ("plans", `Assoc [ ("method", `String "none"); ("unsafe_apply_without_plan", `Bool true) ]) ]

let assert_storage_disabled ?(unsafe_apply_without_plan = false) storage =
  match storage.V1.Storage.plans with
  | V1.Storage.Plans.Disabled disabled ->
      Oth.Assert.eq
        ~eq:Bool.equal
        ~pp:(fun ppf v -> Format.pp_print_string ppf (Bool.to_string v))
        unsafe_apply_without_plan
        disabled.V1.Storage.Plans.Disabled.unsafe_apply_without_plan
  | plans ->
      failwith
        (Printf.sprintf "Expected storage plans disabled, got %s" (V1.Storage.Plans.show plans))

let test_storage_none =
  Oth.test ~name:"storage: plans method none is read" (fun _ ->
      let cfg = config_of_json (`Assoc [ ("storage", storage_none_json) ]) in
      assert_storage_disabled (V1.storage cfg))

let test_storage_none_unsafe_apply_without_plan =
  Oth.test ~name:"storage: plans method none unsafe apply is read" (fun _ ->
      let cfg = config_of_json (`Assoc [ ("storage", storage_none_unsafe_json) ]) in
      assert_storage_disabled ~unsafe_apply_without_plan:true (V1.storage cfg))

let test_storage_none_to_version_1_round_trip =
  Oth.test ~name:"storage: plans method none round-trips through Version_1" (fun _ ->
      let cfg = config_of_json (`Assoc [ ("storage", storage_none_json) ]) in
      let v1 = V1.to_version_1 cfg in
      match v1.Repo.Version_1.storage with
      | Some
          {
            Repo.Version_1.Storage.plans =
              Some
                (Repo.Version_1.Storage.Plans.Storage_plan_none
                   { Repo.Storage_plan_none.method_ = `None; unsafe_apply_without_plan = false });
          } -> ()
      | _ -> failwith "Round-trip to Version_1 did not preserve storage.plans.method none")

let test_storage_none_unsafe_to_version_1_round_trip =
  Oth.test ~name:"storage: plans method none unsafe apply round-trips through Version_1" (fun _ ->
      let cfg = config_of_json (`Assoc [ ("storage", storage_none_unsafe_json) ]) in
      let v1 = V1.to_version_1 cfg in
      match v1.Repo.Version_1.storage with
      | Some
          {
            Repo.Version_1.Storage.plans =
              Some
                (Repo.Version_1.Storage.Plans.Storage_plan_none
                   { Repo.Storage_plan_none.method_ = `None; unsafe_apply_without_plan = true });
          } -> ()
      | _ ->
          failwith
            "Round-trip to Version_1 did not preserve storage.plans.unsafe_apply_without_plan")

let test_workflow_storage_none =
  Oth.test ~name:"workflows: storage plans method none is read" (fun _ ->
      let json =
        `Assoc
          [
            ( "workflows",
              `List [ `Assoc [ ("tag_query", `String ""); ("storage", storage_none_json) ] ] );
          ]
      in
      let cfg = config_of_json json in
      match V1.workflows cfg with
      | [ { V1.Workflows.Entry.storage = Some storage; _ } ] -> assert_storage_disabled storage
      | _ -> failwith "Expected exactly one workflow entry with storage")

let test_workflow_storage_none_unsafe_apply_without_plan =
  Oth.test ~name:"workflows: storage plans method none unsafe apply is read" (fun _ ->
      let json =
        `Assoc
          [
            ( "workflows",
              `List [ `Assoc [ ("tag_query", `String ""); ("storage", storage_none_unsafe_json) ] ]
            );
          ]
      in
      let cfg = config_of_json json in
      match V1.workflows cfg with
      | [ { V1.Workflows.Entry.storage = Some storage; _ } ] ->
          assert_storage_disabled ~unsafe_apply_without_plan:true storage
      | _ -> failwith "Expected exactly one workflow entry with storage")

let test_workflow_storage_none_to_version_1_round_trip =
  Oth.test ~name:"workflows: storage plans method none round-trips through Version_1" (fun _ ->
      let json =
        `Assoc
          [
            ( "workflows",
              `List [ `Assoc [ ("tag_query", `String ""); ("storage", storage_none_json) ] ] );
          ]
      in
      let cfg = config_of_json json in
      let v1 = V1.to_version_1 cfg in
      match v1.Repo.Version_1.workflows with
      | Some
          [
            {
              Repo.Workflow_entry.storage =
                Some
                  {
                    Repo.Workflow_entry.Storage.plans =
                      Some
                        (Repo.Workflow_entry.Storage.Plans.Storage_plan_none
                           {
                             Repo.Storage_plan_none.method_ = `None;
                             unsafe_apply_without_plan = false;
                           });
                  };
              _;
            };
          ] -> ()
      | _ -> failwith "Round-trip to Version_1 did not preserve workflow storage")

let test_workflow_storage_none_unsafe_to_version_1_round_trip =
  Oth.test
    ~name:"workflows: storage plans method none unsafe apply round-trips through Version_1"
    (fun _ ->
      let json =
        `Assoc
          [
            ( "workflows",
              `List [ `Assoc [ ("tag_query", `String ""); ("storage", storage_none_unsafe_json) ] ]
            );
          ]
      in
      let cfg = config_of_json json in
      let v1 = V1.to_version_1 cfg in
      match v1.Repo.Version_1.workflows with
      | Some
          [
            {
              Repo.Workflow_entry.storage =
                Some
                  {
                    Repo.Workflow_entry.Storage.plans =
                      Some
                        (Repo.Workflow_entry.Storage.Plans.Storage_plan_none
                           {
                             Repo.Storage_plan_none.method_ = `None;
                             unsafe_apply_without_plan = true;
                           });
                  };
              _;
            };
          ] -> ()
      | _ -> failwith "Round-trip to Version_1 did not preserve workflow storage")

(* Tests for the requirement that an explicit [plan] step list contains a [plan]
   step and an explicit [apply] step list contains an [apply] step. *)

let workflows_json entries = `Assoc [ ("workflows", `List entries) ]
let step type_ = `Assoc [ ("type", `String type_) ]

let workflow_entry ?apply ?plan tag_query =
  `Assoc
    (("tag_query", `String tag_query)
    :: CCList.filter_map
         CCFun.id
         [
           CCOption.map (fun steps -> ("apply", `List steps)) apply;
           CCOption.map (fun steps -> ("plan", `List steps)) plan;
         ])

let test_workflow_plan_requires_plan_step =
  Oth.test ~name:"workflows: plan steps without a plan step are rejected" (fun _ ->
      let json = workflows_json [ workflow_entry ~plan:[ step "init"; step "checkov" ] "" ] in
      match Oth.Assert.error (V1.of_version_1_json json) with
      | `Workflows_missing_plan_step_err (0, "") -> ()
      | err ->
          Oth.Assert.false_
            (Printf.sprintf
               "Expected Workflows_missing_plan_step_err (0, \"\"), got %s"
               (V1.show_of_version_1_json_err err)))

let test_workflow_apply_requires_apply_step =
  Oth.test ~name:"workflows: apply steps without an apply step are rejected" (fun _ ->
      let json = workflows_json [ workflow_entry ~apply:[ step "init"; step "plan" ] "" ] in
      match Oth.Assert.error (V1.of_version_1_json json) with
      | `Workflows_missing_apply_step_err (0, "") -> ()
      | err ->
          Oth.Assert.false_
            (Printf.sprintf
               "Expected Workflows_missing_apply_step_err (0, \"\"), got %s"
               (V1.show_of_version_1_json_err err)))

let test_workflow_empty_plan_rejected =
  Oth.test ~name:"workflows: an explicitly empty plan step list is rejected" (fun _ ->
      let json = workflows_json [ workflow_entry ~plan:[] "" ] in
      match Oth.Assert.error (V1.of_version_1_json json) with
      | `Workflows_missing_plan_step_err (0, "") -> ()
      | err ->
          Oth.Assert.false_
            (Printf.sprintf
               "Expected Workflows_missing_plan_step_err (0, \"\"), got %s"
               (V1.show_of_version_1_json_err err)))

let test_workflow_omitted_steps_use_defaults =
  Oth.test ~name:"workflows: omitting plan and apply uses the defaults" (fun _ ->
      let json = workflows_json [ workflow_entry "" ] in
      let cfg = Oth.Assert.ok_pp ~pp:V1.pp_of_version_1_json_err (V1.of_version_1_json json) in
      let { V1.Workflows.Entry.apply; plan; _ } = Oth.Assert.List.length_one (V1.workflows cfg) in
      let module Op = V1.Workflows.Entry.Op in
      let module Op_list = V1.Workflows.Entry.Op_list in
      Oth.Assert.eq
        ~eq:Op_list.equal
        ~pp:Op_list.pp
        [ Op.Init (V1.Workflow_step.Init.make ()); Op.Plan (V1.Workflow_step.Plan.make ()) ]
        plan;
      Oth.Assert.eq
        ~eq:Op_list.equal
        ~pp:Op_list.pp
        [ Op.Init (V1.Workflow_step.Init.make ()); Op.Apply (V1.Workflow_step.Apply.make ()) ]
        apply;
      ())

let step_visible_on type_ visible_on =
  `Assoc [ ("type", `String type_); ("visible_on", `String visible_on) ]

let assert_visible_on expected actual =
  Oth.Assert.eq
    ~eq:V1.Workflow_step.Visible_on.equal
    ~pp:V1.Workflow_step.Visible_on.pp
    expected
    actual

let assert_v1_visible_on expected actual =
  Oth.Assert.eq
    ~eq:(CCOption.equal Repo.Visible_on.equal)
    ~pp:(CCOption.pp Repo.Visible_on.pp)
    (Some expected)
    actual

(* The runner used to write these three values as constants, so the defaults have to keep saying
   what the runner said: a plan and an apply are always shown, an init only when the run fails. *)
let test_workflow_visible_on_defaults =
  Oth.test ~name:"workflows: visible_on defaults on init, plan and apply" (fun _ ->
      let module Op = V1.Workflows.Entry.Op in
      let json =
        workflows_json
          [ workflow_entry ~plan:[ step "init"; step "plan" ] ~apply:[ step "apply" ] "" ]
      in
      let cfg = Oth.Assert.ok_pp ~pp:V1.pp_of_version_1_json_err (V1.of_version_1_json json) in
      let { V1.Workflows.Entry.apply; plan; _ } = Oth.Assert.List.length_one (V1.workflows cfg) in
      (match plan with
      | [ Op.Init init; Op.Plan plan ] ->
          assert_visible_on
            V1.Workflow_step.Visible_on.Failure
            init.V1.Workflow_step.Init.visible_on;
          assert_visible_on V1.Workflow_step.Visible_on.Always plan.V1.Workflow_step.Plan.visible_on
      | _ -> Oth.Assert.false_ "expected an init and a plan step");
      (match apply with
      | [ Op.Apply apply ] ->
          assert_visible_on
            V1.Workflow_step.Visible_on.Always
            apply.V1.Workflow_step.Apply.visible_on
      | _ -> Oth.Assert.false_ "expected an apply step");
      ())

let test_workflow_visible_on_is_read =
  Oth.test ~name:"workflows: visible_on is read on init, plan and apply" (fun _ ->
      let module Op = V1.Workflows.Entry.Op in
      let json =
        workflows_json
          [
            workflow_entry
              ~plan:[ step_visible_on "init" "always"; step_visible_on "plan" "failure" ]
              ~apply:[ step_visible_on "apply" "success" ]
              "";
          ]
      in
      let cfg = Oth.Assert.ok_pp ~pp:V1.pp_of_version_1_json_err (V1.of_version_1_json json) in
      let { V1.Workflows.Entry.apply; plan; _ } = Oth.Assert.List.length_one (V1.workflows cfg) in
      (match plan with
      | [ Op.Init init; Op.Plan plan ] ->
          assert_visible_on V1.Workflow_step.Visible_on.Always init.V1.Workflow_step.Init.visible_on;
          assert_visible_on
            V1.Workflow_step.Visible_on.Failure
            plan.V1.Workflow_step.Plan.visible_on
      | _ -> Oth.Assert.false_ "expected an init and a plan step");
      (match apply with
      | [ Op.Apply apply ] ->
          assert_visible_on
            V1.Workflow_step.Visible_on.Success
            apply.V1.Workflow_step.Apply.visible_on
      | _ -> Oth.Assert.false_ "expected an apply step");
      ())

(* The runner reads its step configuration out of the Version_1 config the server sends back, so a
   value that does not survive to_version_1 never reaches the step that has to obey it. *)
let test_workflow_visible_on_to_version_1_round_trip =
  Oth.test ~name:"workflows: visible_on round-trips through Version_1" (fun _ ->
      let module Items = Terrat_repo_config_workflow_op_list.Items in
      let json =
        workflows_json
          [
            workflow_entry
              ~plan:[ step_visible_on "init" "always"; step_visible_on "plan" "failure" ]
              ~apply:[ step_visible_on "apply" "success" ]
              "";
          ]
      in
      let cfg = Oth.Assert.ok_pp ~pp:V1.pp_of_version_1_json_err (V1.of_version_1_json json) in
      let v1 = V1.to_version_1 cfg in
      let entry =
        Oth.Assert.List.length_one (CCOption.get_or ~default:[] v1.Repo.Version_1.workflows)
      in
      (match entry.Repo.Workflow_entry.plan with
      | Some [ Items.Workflow_op_init init; Items.Workflow_op_plan plan ] ->
          assert_v1_visible_on `Always init.Terrat_repo_config_workflow_op_init.visible_on;
          assert_v1_visible_on `Failure plan.Terrat_repo_config_workflow_op_plan.visible_on
      | Some _ | None -> Oth.Assert.false_ "expected an init and a plan step");
      (match entry.Repo.Workflow_entry.apply with
      | Some [ Items.Workflow_op_apply apply ] ->
          assert_v1_visible_on `Success apply.Terrat_repo_config_workflow_op_apply.visible_on
      | Some _ | None -> Oth.Assert.false_ "expected an apply step");
      ())

let test_workflow_extra_steps_allowed =
  Oth.test ~name:"workflows: extra steps around plan and apply are allowed" (fun _ ->
      let json =
        workflows_json
          [
            workflow_entry
              ~plan:[ step "init"; step "plan"; step "checkov" ]
              ~apply:[ step "checkov"; step "init"; step "apply" ]
              "";
          ]
      in
      let cfg = Oth.Assert.ok_pp ~pp:V1.pp_of_version_1_json_err (V1.of_version_1_json json) in
      Oth.Assert.List.length ~expected:1 (V1.workflows cfg);
      ())

let test_workflow_missing_step_reports_index =
  Oth.test ~name:"workflows: the reported index identifies the offending entry" (fun _ ->
      let json =
        workflows_json
          [
            workflow_entry ~plan:[ step "init"; step "plan" ] "dir:foo";
            workflow_entry ~plan:[ step "init" ] "dir:bar";
          ]
      in
      match Oth.Assert.error (V1.of_version_1_json json) with
      | `Workflows_missing_plan_step_err (1, "dir:bar") -> ()
      | err ->
          Oth.Assert.false_
            (Printf.sprintf
               "Expected Workflows_missing_plan_step_err (1, \"dir:bar\"), got %s"
               (V1.show_of_version_1_json_err err)))

(* A glob in the repository configuration that the glob parser rejects.

   The [dirs] section is keyed by directory, and a key containing a '*' is a
   glob that [derive] expands over the repository.  Nothing about the JSON
   schema constrains those keys -- [dirs] is declared with
   [additionalProperties] and no key pattern -- so the check has to be in the
   code.  A key the glob parser rejects used to load without an error and then
   raise [CCResult.Get_error] out of [derive], which reached the user as an
   unexplained internal error.

   [of_version_1_json] now rejects such a key at parse, and [derive] reports
   [`Bad_glob_err] rather than raising, so a configuration that reaches
   [derive] by another route is still described rather than fatal. *)

let derive_ctx = V1.Ctx.make ~dest_branch:"main" ~branch:"topic" ()
let dirs_json key = `Assoc [ ("dirs", `Assoc [ (key, `Assoc [ ("when_modified", `Assoc []) ]) ]) ]

(* A configuration holding [key] built without going through the parse, which
   is the only way to hand [derive] a key the parse now rejects. *)
let dirs_view key =
  V1.of_view (V1.View.make ~dirs:(Sln_map.String.of_list [ (key, V1.Dirs.Dir.make ()) ]) ())

let derive_dirs_key ?(file_list = [ "foo/main.tf" ]) key =
  V1.derive ~ctx:derive_ctx ~index:V1.Index.empty ~file_list (dirs_view key)

let assert_bad_glob ~expected_glob ~expected_pattern = function
  | `Bad_glob_err { V1.Bad_glob.location; pattern; glob; err } ->
      Oth.Assert.eq ~eq:CCString.equal ~pp:CCString.pp expected_glob glob;
      Oth.Assert.eq ~eq:CCString.equal ~pp:CCString.pp expected_pattern pattern;
      Oth.Assert.str_contains ~haystack:location ~needle:expected_glob;
      Oth.Assert.not_true ~fail_msg:"the parser message is empty" (CCString.is_empty err)
  | err ->
      Oth.Assert.false_
        (Printf.sprintf "Expected Bad_glob_err, got %s" (V1.show_of_version_1_json_err err))

let test_parse_rejects_bad_glob_dir_key =
  Oth.test
    ~tags:[ "repo_config_glob_dirs" ]
    ~name:"of_version_1_json: a dirs key that is not a valid glob is rejected"
    (fun _ ->
      (* '+' is not a character the glob parser accepts. *)
      assert_bad_glob
        ~expected_glob:"foo/*+"
        ~expected_pattern:"foo/*+"
        (Oth.Assert.error (V1.of_version_1_json (dirs_json "foo/*+")));
      ())

let test_parse_rejects_ambiguous_star_star_dir_key =
  Oth.test
    ~tags:[ "repo_config_glob_dirs" ]
    ~name:"of_version_1_json: a dirs key with an ambiguous ** is rejected"
    (fun _ ->
      (* The glob parser accepts ** only next to a slash, so a bare ** fails. *)
      assert_bad_glob
        ~expected_glob:"**"
        ~expected_pattern:"**"
        (Oth.Assert.error (V1.of_version_1_json (dirs_json "**")));
      ())

let test_parse_accepts_valid_glob_dir_keys =
  Oth.test
    ~tags:[ "repo_config_glob_dirs" ]
    ~name:"of_version_1_json: valid dirs globs are accepted"
    (fun _ ->
      CCList.iter
        (fun key ->
          let cfg =
            Oth.Assert.ok_pp ~pp:V1.pp_of_version_1_json_err (V1.of_version_1_json (dirs_json key))
          in
          Oth.Assert.List.length ~expected:1 (Sln_map.String.to_list (V1.dirs cfg)))
        [ "foo/*"; "**/*"; "modules/**"; "*"; "*/*"; "services/*/terraform"; "!ignored/*" ];
      ())

let test_derive_reports_bad_glob_dir_key =
  Oth.test
    ~tags:[ "repo_config_glob_dirs" ]
    ~name:"derive: a dirs glob the parser rejects is reported, not raised"
    (fun _ ->
      assert_bad_glob
        ~expected_glob:"foo/*+"
        ~expected_pattern:"foo/*+"
        (Oth.Assert.error (derive_dirs_key "foo/*+"));
      ())

let test_derive_reports_ambiguous_star_star =
  Oth.test
    ~tags:[ "repo_config_glob_dirs" ]
    ~name:"derive: a dirs glob with an ambiguous ** is reported, not raised"
    (fun _ ->
      assert_bad_glob
        ~expected_glob:"**"
        ~expected_pattern:"**"
        (Oth.Assert.error (derive_dirs_key "**"));
      ())

(* The error has to stand on its own in a log line: whoever reads it must be
   able to act without the repository configuration in front of them. *)
let test_bad_glob_shows_everything_needed_to_diagnose =
  Oth.test
    ~tags:[ "repo_config_glob_dirs" ]
    ~name:"derive: the reported error names the glob, the location and the cause"
    (fun _ ->
      let shown = V1.show_derive_err (Oth.Assert.error (derive_dirs_key "team:*")) in
      Oth.Assert.str_contains_all
        ~haystack:shown
        ~needles:[ "team:*"; "dirs."; "Unexpected character" ];
      ())

let test_derive_glob_dir_valid =
  Oth.test ~tags:[ "repo_config_glob_dirs" ] ~name:"derive: a valid dirs glob succeeds" (fun _ ->
      let (_ : V1.derived V1.t) = Oth.Assert.ok_pp ~pp:V1.pp_derive_err (derive_dirs_key "foo/*") in
      ())

let test =
  Oth.parallel
    [
      test_of_version_1_json_minimal;
      test_of_version_1_json_with_version;
      test_to_version_1_round_trip;
      test_lock_policy_default;
      test_lock_policy_global;
      test_lock_policy_workflow_inherits;
      test_lock_policy_workflow_overrides;
      test_lock_policy_to_version_1_round_trip;
      test_storage_none;
      test_storage_none_unsafe_apply_without_plan;
      test_storage_none_to_version_1_round_trip;
      test_storage_none_unsafe_to_version_1_round_trip;
      test_workflow_storage_none;
      test_workflow_storage_none_unsafe_apply_without_plan;
      test_workflow_storage_none_to_version_1_round_trip;
      test_workflow_storage_none_unsafe_to_version_1_round_trip;
      test_workflow_plan_requires_plan_step;
      test_workflow_apply_requires_apply_step;
      test_workflow_empty_plan_rejected;
      test_workflow_omitted_steps_use_defaults;
      test_workflow_visible_on_defaults;
      test_workflow_visible_on_is_read;
      test_workflow_visible_on_to_version_1_round_trip;
      test_workflow_extra_steps_allowed;
      test_workflow_missing_step_reports_index;
      test_parse_rejects_bad_glob_dir_key;
      test_parse_rejects_ambiguous_star_star_dir_key;
      test_parse_accepts_valid_glob_dir_keys;
      test_derive_reports_bad_glob_dir_key;
      test_derive_reports_ambiguous_star_star;
      test_bad_glob_shows_everything_needed_to_diagnose;
      test_derive_glob_dir_valid;
    ]

let () =
  Random.self_init ();
  Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)
