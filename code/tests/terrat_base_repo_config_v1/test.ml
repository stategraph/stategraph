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

let test_notifications_summary_mode_pull_request =
  Oth.test ~name:"of_version_1_json: notifications summary mode pull_request" (fun _ ->
      let module Sum = V1.Notifications.Summary in
      let json =
        `Assoc
          [
            ( "notifications",
              `Assoc
                [
                  ("summary", `Assoc [ ("enabled", `Bool true); ("mode", `String "pull_request") ]);
                ] );
          ]
      in
      let cfg =
        Oth.Assert.ok_show ~show:V1.show_of_version_1_json_err (V1.of_version_1_json json)
      in
      let { V1.Notifications.summary; policies = _; plan = _; apply = _ } = V1.notifications cfg in
      match summary with
      | { Sum.enabled = Some true; mode = Sum.Mode.Pull_request; output_details = _ } -> ()
      | _ -> failwith "Expected summary enabled=true with mode=Pull_request")

let test_notifications_summary_mode_default =
  Oth.test ~name:"of_version_1_json: notifications summary mode defaults to pull_request" (fun _ ->
      let module Sum = V1.Notifications.Summary in
      let json =
        `Assoc [ ("notifications", `Assoc [ ("summary", `Assoc [ ("enabled", `Bool true) ]) ]) ]
      in
      let cfg =
        Oth.Assert.ok_show ~show:V1.show_of_version_1_json_err (V1.of_version_1_json json)
      in
      let { V1.Notifications.summary; policies = _; plan = _; apply = _ } = V1.notifications cfg in
      match summary with
      | { Sum.enabled = Some true; mode = Sum.Mode.Pull_request; output_details = _ } -> ()
      | _ -> failwith "Expected summary enabled=true with default mode=Pull_request")

(* [enabled] has no default in the schema, so a configuration that never names the summary keeps
   [None].  [Summary.enabled] reads [None] as on, which is the default of the Enterprise Edition.
   The Open Source Edition forces [Some false] into the configuration it hands back, after its
   premium-feature gate has seen the [Some true] that only a repository can write. *)
let test_notifications_summary_enabled_unset =
  Oth.test ~name:"of_version_1_json: notifications summary enabled unset" (fun _ ->
      let module Sum = V1.Notifications.Summary in
      let cfg =
        Oth.Assert.ok_show ~show:V1.show_of_version_1_json_err (V1.of_version_1_json (`Assoc []))
      in
      let summary = (V1.notifications cfg).V1.Notifications.summary in
      (match summary.Sum.enabled with
      | None -> ()
      | Some _ -> failwith "Expected an unset summary enabled");
      Oth.Assert.true_ (Sum.enabled summary))

(* Every configuration layer of a merge passes through [to_version_1].  A repository that sets the
   mode and not [enabled] must come back with [enabled] still unset, or a layer would say something
   about the summary that its author never wrote. *)
let test_notifications_summary_enabled_unset_round_trip =
  Oth.test ~name:"to_version_1: an unset summary enabled stays unset" (fun _ ->
      let module Nn = Repo.Notifications in
      let module Sn = Repo.Notifications_summary in
      let round_trip summary expected =
        let json = `Assoc [ ("notifications", `Assoc [ ("summary", summary) ]) ] in
        let cfg =
          Oth.Assert.ok_show ~show:V1.show_of_version_1_json_err (V1.of_version_1_json json)
        in
        let v1 = V1.to_version_1 cfg in
        match
          CCOption.flat_map
            (fun notifications -> notifications.Nn.summary)
            v1.Repo.Version_1.notifications
        with
        | Some summary ->
            Oth.Assert.eq
              ~eq:(CCOption.equal CCBool.equal)
              ~pp:(fun f v ->
                Format.pp_print_string
                  f
                  (match v with
                  | Some b -> CCBool.to_string b
                  | None -> "unset"))
              expected
              summary.Sn.enabled
        | None -> failwith "Round-trip to Version_1 did not produce a summary"
      in
      round_trip (`Assoc [ ("mode", `String "header") ]) None;
      round_trip (`Assoc [ ("enabled", `Bool false) ]) (Some false))

(* [plan] and [apply] are read from the notifications section itself, beside the summary rather
   than inside it, so a configuration that never mentions the summary still sets them. *)
let test_notifications_orthogonal_settings =
  Oth.test
    ~name:"of_version_1_json: notifications plan/apply visible_on and output_details"
    (fun _ ->
      let module N = V1.Notifications in
      let json =
        `Assoc
          [
            ( "notifications",
              `Assoc
                [
                  ("plan", `Assoc [ ("visible_on", `String "never") ]);
                  ("apply", `Assoc [ ("visible_on", `String "failure") ]);
                  ( "summary",
                    `Assoc
                      [
                        ("enabled", `Bool true);
                        ("mode", `String "pull_request");
                        ("output_details", `Assoc [ ("enabled", `Bool true) ]);
                      ] );
                ] );
          ]
      in
      let cfg =
        Oth.Assert.ok_show ~show:V1.show_of_version_1_json_err (V1.of_version_1_json json)
      in
      match V1.notifications cfg with
      | {
       N.policies = _;
       summary =
         {
           N.Summary.enabled = _;
           mode = N.Summary.Mode.Pull_request;
           output_details = { N.Summary.Output_details.enabled = true };
         };
       plan = { N.Plan.visible_on = N.Visible_on.Never; _ };
       apply = { N.Apply.visible_on = N.Visible_on.Failure; _ };
      } -> ()
      | n -> failwith ("unexpected notifications: " ^ N.show n))

(* No summary at all, so the summary is not what carries these: the plan and apply settings are
   read on their own. *)
let test_notifications_orthogonal_settings_without_summary =
  Oth.test ~name:"of_version_1_json: plan/apply visible_on without a summary" (fun _ ->
      let module N = V1.Notifications in
      let json =
        `Assoc
          [
            ( "notifications",
              `Assoc
                [
                  ("plan", `Assoc [ ("visible_on", `String "never") ]);
                  ("apply", `Assoc [ ("visible_on", `String "success") ]);
                ] );
          ]
      in
      let cfg =
        Oth.Assert.ok_show ~show:V1.show_of_version_1_json_err (V1.of_version_1_json json)
      in
      match V1.notifications cfg with
      | {
       N.policies = _;
       summary = _;
       plan = { N.Plan.visible_on = N.Visible_on.Never; _ };
       apply = { N.Apply.visible_on = N.Visible_on.Success; _ };
      } -> ()
      | n -> failwith ("unexpected notifications: " ^ N.show n))

let test_notifications_orthogonal_defaults =
  Oth.test ~name:"of_version_1_json: notifications orthogonal settings default" (fun _ ->
      let module N = V1.Notifications in
      let json =
        `Assoc [ ("notifications", `Assoc [ ("summary", `Assoc [ ("enabled", `Bool true) ]) ]) ]
      in
      let cfg =
        Oth.Assert.ok_show ~show:V1.show_of_version_1_json_err (V1.of_version_1_json json)
      in
      match V1.notifications cfg with
      | {
       N.policies = _;
       summary =
         {
           N.Summary.enabled = _;
           mode = _;
           output_details = { N.Summary.Output_details.enabled = false };
         };
       plan = { N.Plan.visible_on = N.Visible_on.Always; _ };
       apply = { N.Apply.visible_on = N.Visible_on.Always; _ };
      } -> ()
      | n -> failwith ("unexpected notifications: " ^ N.show n))

let test_notifications_orthogonal_round_trip =
  Oth.test ~name:"to_version_1: notifications orthogonal settings round-trip" (fun _ ->
      let module Nn = Repo.Notifications in
      let module Sn = Terrat_repo_config.Notifications_summary in
      let json =
        `Assoc
          [
            ( "notifications",
              `Assoc
                [
                  ("plan", `Assoc [ ("visible_on", `String "never") ]);
                  ("apply", `Assoc [ ("visible_on", `String "success") ]);
                  ( "summary",
                    `Assoc
                      [
                        ("enabled", `Bool true);
                        ("mode", `String "pull_request");
                        ("output_details", `Assoc [ ("enabled", `Bool true) ]);
                      ] );
                ] );
          ]
      in
      match V1.of_version_1_json json with
      | Ok cfg -> (
          let v1 = V1.to_version_1 cfg in
          match v1.Repo.Version_1.notifications with
          | Some
              {
                Nn.plan = Some { Nn.Plan.visible_on = Some `Never; status_checks = _ };
                apply = Some { Nn.Apply.visible_on = Some `Success; status_checks = _ };
                summary =
                  Some
                    {
                      Sn.enabled = Some true;
                      mode = `Pull_request;
                      output_details = Some { Sn.Output_details.enabled = true };
                    };
                policies = _;
              } -> ()
          | _ -> failwith "Round-trip to Version_1 did not produce the notifications settings")
      | Error err -> failwith ("of_version_1_json failed: " ^ V1.show_of_version_1_json_err err))

(* The per-dirspace commit checks: on unless the configuration turns them off, which is what a
   repository got before the setting existed.  [dirspace_status_checks_enabled] is what every
   check-creating site asks, so the table pins each run it maps. *)
let test_notifications_status_checks_defaults =
  Oth.test ~name:"of_version_1_json: status_checks defaults" (fun _ ->
      let module N = V1.Notifications in
      let cfg =
        Oth.Assert.ok_show ~show:V1.show_of_version_1_json_err (V1.of_version_1_json (`Assoc []))
      in
      let notifications = V1.notifications cfg in
      Oth.Assert.Eq.bool
        ~expected:true
        ~actual:notifications.N.plan.N.Plan.status_checks.N.Status_checks.enabled;
      Oth.Assert.Eq.bool
        ~expected:true
        ~actual:notifications.N.apply.N.Apply.status_checks.N.Status_checks.enabled;
      CCList.iter
        (fun run ->
          Oth.Assert.Eq.bool
            ~expected:true
            ~actual:(N.dirspace_status_checks_enabled notifications ~run))
        [ `Plan; `Apply; `Other ];
      ())

let test_notifications_status_checks_configured =
  Oth.test ~name:"of_version_1_json: status_checks configured" (fun _ ->
      let module N = V1.Notifications in
      let json =
        `Assoc
          [
            ( "notifications",
              `Assoc
                [
                  ("plan", `Assoc [ ("status_checks", `Assoc [ ("enabled", `Bool false) ]) ]);
                  ("apply", `Assoc [ ("status_checks", `Assoc [ ("enabled", `Bool false) ]) ]);
                ] );
          ]
      in
      let cfg =
        Oth.Assert.ok_show ~show:V1.show_of_version_1_json_err (V1.of_version_1_json json)
      in
      let notifications = V1.notifications cfg in
      Oth.Assert.eq
        ~eq:N.Plan.equal
        ~pp:N.Plan.pp
        notifications.N.plan
        (* The visible_on stays at its own default, which is what [make] is for. *)
        (N.Plan.make ~status_checks:(N.Status_checks.make ~enabled:false ()) ());
      Oth.Assert.eq
        ~eq:N.Apply.equal
        ~pp:N.Apply.pp
        notifications.N.apply
        (N.Apply.make ~status_checks:(N.Status_checks.make ~enabled:false ()) ());
      Oth.Assert.Eq.bool
        ~expected:false
        ~actual:(N.dirspace_status_checks_enabled notifications ~run:`Plan);
      Oth.Assert.Eq.bool
        ~expected:false
        ~actual:(N.dirspace_status_checks_enabled notifications ~run:`Apply);
      ())

let test_notifications_status_checks_round_trip =
  Oth.test ~name:"to_version_1: status_checks round-trip" (fun _ ->
      let module Nn = Repo.Notifications in
      let json =
        `Assoc
          [
            ( "notifications",
              `Assoc
                [
                  ("plan", `Assoc [ ("status_checks", `Assoc [ ("enabled", `Bool false) ]) ]);
                  ("apply", `Assoc [ ("status_checks", `Assoc [ ("enabled", `Bool true) ]) ]);
                ] );
          ]
      in
      match V1.of_version_1_json json with
      | Ok cfg -> (
          let v1 = V1.to_version_1 cfg in
          match v1.Repo.Version_1.notifications with
          | Some
              {
                Nn.plan =
                  Some { Nn.Plan.status_checks = Some { Nn.Plan.Status_checks.enabled = false }; _ };
                apply =
                  Some
                    { Nn.Apply.status_checks = Some { Nn.Apply.Status_checks.enabled = true }; _ };
                _;
              } -> ()
          | _ -> failwith "Round-trip to Version_1 did not produce the status_checks settings")
      | Error err -> failwith ("of_version_1_json failed: " ^ V1.show_of_version_1_json_err err))

(* The classic-comment decision table.  [visible_on] alone decides, apart from the gates and
   denials that always post: the summary's [enabled] and [mode] are in the table only to pin that
   they no longer change the answer. *)
let test_notifications_classic_comment_visible =
  Oth.test ~name:"classic_comment_visible decision table" (fun _ ->
      let module N = V1.Notifications in
      let module Sum = N.Summary in
      let module Vo = N.Visible_on in
      let t ~enabled ~mode ~plan_vo ~apply_vo =
        N.make
          ~summary:(Sum.make ~enabled:(Some enabled) ~mode ())
          ~plan:(N.Plan.make ~visible_on:plan_vo ())
          ~apply:(N.Apply.make ~visible_on:apply_vo ())
          ()
      in
      let pr = Sum.Mode.Pull_request and hd = Sum.Mode.Header in
      (* (enabled, mode, plan_vo, apply_vo, run, success, gates, expected) *)
      let cases =
        [
          (true, pr, Vo.Never, Vo.Never, `Plan, true, false, false);
          (true, pr, Vo.Never, Vo.Never, `Apply, true, false, false);
          (true, pr, Vo.Always, Vo.Always, `Plan, false, false, true);
          (true, pr, Vo.Success, Vo.Never, `Plan, true, false, true);
          (true, pr, Vo.Success, Vo.Never, `Plan, false, false, false);
          (true, pr, Vo.Failure, Vo.Never, `Plan, false, false, true);
          (true, pr, Vo.Failure, Vo.Never, `Plan, true, false, false);
          (* visible_on is per run kind *)
          (true, pr, Vo.Never, Vo.Always, `Apply, true, false, true);
          (* forced posts: gates and access-control denials *)
          (true, pr, Vo.Never, Vo.Never, `Plan, true, true, true);
          (* header mode does not force the comment: the header goes with it *)
          (true, hd, Vo.Never, Vo.Never, `Plan, true, false, false);
          (true, hd, Vo.Always, Vo.Always, `Plan, true, false, true);
          (* summary disabled: the setting still decides *)
          (false, pr, Vo.Never, Vo.Never, `Plan, true, false, false);
          (false, pr, Vo.Always, Vo.Always, `Plan, true, false, true);
        ]
      in
      CCList.iter
        (fun (enabled, mode, plan_vo, apply_vo, run, success, gates, expected) ->
          let t = t ~enabled ~mode ~plan_vo ~apply_vo in
          let actual = N.classic_comment_visible t ~run ~success ~gates_or_denials:gates in
          (* The message names the row: a bare equality assertion on a table of thirteen says
             which value was wrong and not which case produced it. *)
          Oth.Assert.true_ (actual = expected))
        cases)

let test_notifications_summary_mode_round_trip =
  Oth.test ~name:"to_version_1: notifications summary mode round-trips" (fun _ ->
      let module Sn = Repo.Notifications_summary in
      let round_trip mode_str expected =
        let json =
          `Assoc
            [
              ( "notifications",
                `Assoc
                  [ ("summary", `Assoc [ ("enabled", `Bool true); ("mode", `String mode_str) ]) ] );
            ]
        in
        let cfg =
          Oth.Assert.ok_show ~show:V1.show_of_version_1_json_err (V1.of_version_1_json json)
        in
        let v1 = V1.to_version_1 cfg in
        match v1.Repo.Version_1.notifications with
        | Some
            {
              Repo.Notifications.summary = Some { Sn.enabled = Some true; mode; output_details = _ };
              policies = _;
              plan = _;
              apply = _;
            } ->
            if mode <> expected then
              failwith (Printf.sprintf "Round-trip of mode %s produced a different mode" mode_str)
        | _ -> failwith "Round-trip to Version_1 did not produce a notifications summary"
      in
      round_trip "pull_request" `Pull_request;
      round_trip "header" `Header)

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

(* The custom engine's [resource_summary] program is read from the repository config and written
   back into the work manifest's engine block, which is where the runner picks it up.  Both
   directions are pinned here: a key that survives only one of them never reaches the runner. *)
let test_engine_custom_resource_summary =
  Oth.test ~name:"engine custom resource_summary round-trip" (fun _ ->
      let cmd = [ "my-summary"; "--json" ] in
      let json =
        `Assoc
          [
            ( "engine",
              `Assoc
                [
                  ("name", `String "custom");
                  ("plan", `List [ `String "my-plan" ]);
                  ("resource_summary", `List (CCList.map (fun s -> `String s) cmd));
                ] );
          ]
      in
      match V1.of_version_1_json json with
      | Ok cfg -> (
          (match V1.engine cfg with
          | V1.Engine.Custom { V1.Engine.Custom.resource_summary = Some rs; _ }
            when CCList.equal CCString.equal rs cmd -> ()
          | other ->
              failwith
                (Printf.sprintf
                   "of_version_1_json did not read resource_summary, got %s"
                   (pp_engine other)));
          match (V1.to_version_1 cfg).Repo.Version_1.engine with
          | Some (Repo.Engine.Engine_custom { Repo.Engine_custom.resource_summary = Some rs; _ })
            when CCList.equal CCString.equal rs cmd -> ()
          | _ -> failwith "to_version_1 did not write resource_summary back")
      | Error err -> failwith ("of_version_1_json failed: " ^ V1.show_of_version_1_json_err err))

(* [batch_runs.merge_steps] gives the highest step that may join an action run that is
   already going.  The default is [Setup], which is what a repository gets with no
   configuration.  [enabled] does not gate it: [enabled] caps the workspaces of a batch. *)
let test_batch_runs_merge_steps_defaults =
  Oth.test ~name:"of_version_1_json: merge_steps defaults" (fun _ ->
      let cfg =
        Oth.Assert.ok_show ~show:V1.show_of_version_1_json_err (V1.of_version_1_json (`Assoc []))
      in
      Oth.Assert.eq
        ~eq:V1.Batch_runs.equal
        ~pp:V1.Batch_runs.pp
        (V1.batch_runs cfg)
        (V1.Batch_runs.make ~merge_steps:V1.Batch_runs.Merge_steps.Setup ());
      ())

let test_batch_runs_merge_steps_each_value =
  Oth.test ~name:"of_version_1_json: merge_steps each value" (fun _ ->
      let module Ms = V1.Batch_runs.Merge_steps in
      CCList.iter
        (fun (value, expected) ->
          let json = `Assoc [ ("batch_runs", `Assoc [ ("merge_steps", `String value) ]) ] in
          let cfg =
            Oth.Assert.ok_show ~show:V1.show_of_version_1_json_err (V1.of_version_1_json json)
          in
          Oth.Assert.eq
            ~eq:V1.Batch_runs.equal
            ~pp:V1.Batch_runs.pp
            (V1.batch_runs cfg)
            (* [enabled] stays false, which shows that it does not gate this key. *)
            (V1.Batch_runs.make ~merge_steps:expected ()))
        [
          ("none", Ms.None);
          ("setup", Ms.Setup);
          ("setup_and_plan", Ms.Setup_and_plan);
          ("all", Ms.All);
          ("by_phase", Ms.By_phase);
        ];
      ())

let test_batch_runs_merge_steps_round_trip =
  Oth.test ~name:"to_version_1: merge_steps round-trip" (fun _ ->
      let json = `Assoc [ ("batch_runs", `Assoc [ ("merge_steps", `String "setup_and_plan") ]) ] in
      match V1.of_version_1_json json with
      | Ok cfg -> (
          let v1 = V1.to_version_1 cfg in
          match v1.Repo.Version_1.batch_runs with
          | Some { Repo.Batch_runs.merge_steps = `Setup_and_plan; _ } -> ()
          | Some _ | None -> failwith "Round-trip to Version_1 did not produce merge_steps")
      | Error err -> failwith ("of_version_1_json failed: " ^ V1.show_of_version_1_json_err err))

(* [by_phase] is the one value that is not a rung of the ladder, so it is the one a
   hand-written conversion is most likely to drop on the way back out. *)
let test_batch_runs_merge_steps_by_phase_round_trip =
  Oth.test ~name:"to_version_1: merge_steps by_phase round-trip" (fun _ ->
      let json = `Assoc [ ("batch_runs", `Assoc [ ("merge_steps", `String "by_phase") ]) ] in
      match V1.of_version_1_json json with
      | Ok cfg -> (
          let v1 = V1.to_version_1 cfg in
          match v1.Repo.Version_1.batch_runs with
          | Some { Repo.Batch_runs.merge_steps = `By_phase; _ } -> ()
          | Some _ | None -> failwith "Round-trip to Version_1 did not produce by_phase")
      | Error err -> failwith ("of_version_1_json failed: " ^ V1.show_of_version_1_json_err err))

(* Tests for the global [when_modified.prechecks] key (RFD 2111).  These pin the parse, the round
   trip, and the two boundaries that the evaluator relies on: a precheck glob is a repository path
   (no [${DIR}] rewrite), and no dir ever carries prechecks. *)

let precheck_json prechecks =
  `Assoc [ ("when_modified", `Assoc [ ("prechecks", `List prechecks) ]) ]

let prechecks_of_json json = (V1.when_modified (config_of_json json)).V1.When_modified.prechecks

let pp_precheck = function
  | V1.When_modified.Precheck.User _ -> "User"
  | V1.When_modified.Precheck.File_patterns _ -> "File_patterns"
  | V1.When_modified.Precheck.Config_file_patterns _ -> "Config_file_patterns"

let test_prechecks_default_empty =
  Oth.test ~name:"prechecks: an absent key gives the empty list" (fun _ ->
      Oth.Assert.List.empty (prechecks_of_json (`Assoc [])))

let test_prechecks_parse_all_kinds =
  Oth.test ~name:"prechecks: all three kinds parse, in order" (fun _ ->
      let json =
        precheck_json
          [
            `Assoc [ ("user", `List [ `String "!test_user" ]) ];
            `Assoc [ ("file_patterns", `List [ `String "infra/**/*.tf" ]) ];
            `Assoc [ ("config_file_patterns", `Assoc [ ("stale_config_min", `Int 1) ]) ];
          ]
      in
      match prechecks_of_json json with
      | [
       V1.When_modified.Precheck.User [ "!test_user" ];
       V1.When_modified.Precheck.File_patterns [ fp ];
       V1.When_modified.Precheck.Config_file_patterns
         { V1.When_modified.Precheck.Config_file_patterns.stale_config_min = 1 };
      ] ->
          if not (CCString.equal "infra/**/*.tf" (V1.File_pattern.file_pattern fp)) then
            failwith
              (Printf.sprintf
                 "Expected glob infra/**/*.tf, got %s"
                 (V1.File_pattern.file_pattern fp))
      | l ->
          failwith
            (Printf.sprintf
               "Unexpected prechecks: [%s]"
               (CCString.concat "; " (CCList.map pp_precheck l))))

(* [of_version_1_when_modified] puts a [${DIR}/] in front of its own [file_patterns], because the
   global [when_modified] becomes the default of every dir.  A precheck matches the changed files of
   the pull request, which are repository paths, so it must NOT get that rewrite. *)
let test_prechecks_globs_are_repo_paths =
  Oth.test ~name:"prechecks: a file_patterns glob keeps no ${DIR} prefix" (fun _ ->
      let json =
        `Assoc
          [
            ( "when_modified",
              `Assoc
                [
                  ("file_patterns", `List [ `String "*.tf" ]);
                  ("prechecks", `List [ `Assoc [ ("file_patterns", `List [ `String "*.tf" ]) ] ]);
                ] );
          ]
      in
      let wm = V1.when_modified (config_of_json json) in
      Oth.Assert.Eq.string_list
        ~expected:[ "${DIR}/*.tf" ]
        ~actual:(CCList.map V1.File_pattern.file_pattern wm.V1.When_modified.file_patterns);
      match wm.V1.When_modified.prechecks with
      | [ V1.When_modified.Precheck.File_patterns [ fp ] ]
        when CCString.equal "*.tf" (V1.File_pattern.file_pattern fp) -> ()
      | _ -> failwith "Expected the precheck glob to stay *.tf")

let test_prechecks_bad_glob_rejected =
  Oth.test ~name:"prechecks: a glob the parser rejects fails the parse" (fun _ ->
      let json = precheck_json [ `Assoc [ ("file_patterns", `List [ `String "<[" ]) ] ] in
      match Oth.Assert.error (V1.of_version_1_json json) with
      | `Glob_parse_err ("<[", _) -> ()
      | err ->
          Oth.Assert.false_
            (Printf.sprintf
               "Expected Glob_parse_err for a bad precheck glob, got %s"
               (V1.show_of_version_1_json_err err)))

let test_prechecks_round_trip =
  Oth.test ~name:"prechecks: the list round-trips through Version_1" (fun _ ->
      let json =
        precheck_json
          [
            `Assoc [ ("user", `List [ `String "!test_user" ]) ];
            `Assoc [ ("file_patterns", `List [ `String "infra/**/*.tf" ]) ];
            `Assoc [ ("config_file_patterns", `Assoc [ ("stale_config_min", `Int 60) ]) ];
          ]
      in
      let v1 = V1.to_version_1 (config_of_json json) in
      match v1.Repo.Version_1.when_modified with
      | Some
          {
            Repo.When_modified.prechecks =
              [
                Repo.Precheck.Precheck_user { Repo.Precheck_user.user = [ "!test_user" ] };
                Repo.Precheck.Precheck_file_patterns
                  { Repo.Precheck_file_patterns.file_patterns = [ "infra/**/*.tf" ] };
                Repo.Precheck.Precheck_config_file_patterns
                  {
                    Repo.Precheck_config_file_patterns.config_file_patterns =
                      { Repo.Precheck_config_file_patterns_value.stale_config_min = 60 };
                  };
              ];
            _;
          } -> ()
      | _ -> failwith "prechecks did not round-trip through Version_1")

(* The schema has no [prechecks] key under a dir [when_modified], so the schema check rejects the
   configuration before [of_version_1] ever sees it. *)
let test_prechecks_rejected_in_a_dir =
  Oth.test ~name:"prechecks: a dir that sets prechecks is a schema error" (fun _ ->
      let json =
        `Assoc
          [
            ( "dirs",
              `Assoc
                [
                  ( "infra",
                    `Assoc
                      [
                        ( "when_modified",
                          `Assoc
                            [
                              ( "prechecks",
                                `List [ `Assoc [ ("user", `List [ `String "!test_user" ]) ] ] );
                            ] );
                      ] );
                ] );
          ]
      in
      match Oth.Assert.error (V1.of_version_1_json json) with
      | `Repo_config_schema_err _ -> ()
      | err ->
          Oth.Assert.false_
            (Printf.sprintf
               "Expected a schema error for prechecks in a dir, got %s"
               (V1.show_of_version_1_json_err err)))

(* A dir that sets no [when_modified] of its own takes the global one whole.  It must not take the
   prechecks with it, or a later consumer could read a per-dir copy of a whole-pull-request
   decision. *)
let test_prechecks_not_inherited_by_a_dir =
  Oth.test ~name:"prechecks: a dir does not inherit the global list" (fun _ ->
      let json =
        `Assoc
          [
            ("dirs", `Assoc [ ("infra", `Assoc []) ]);
            ( "when_modified",
              `Assoc
                [ ("prechecks", `List [ `Assoc [ ("user", `List [ `String "!test_user" ]) ] ]) ] );
          ]
      in
      let cfg = config_of_json json in
      ignore (Oth.Assert.List.length_one (V1.when_modified cfg).V1.When_modified.prechecks);
      let dir =
        Oth.Assert.some
          ~fail_msg:"Expected a dir named infra"
          (Sln_map.String.find_opt "infra" (V1.dirs cfg))
      in
      Sln_map.String.iter
        (fun _name { V1.Dirs.Workspace.when_modified; _ } ->
          Oth.Assert.List.empty when_modified.V1.When_modified.prechecks)
        dir.V1.Dirs.Dir.workspaces)

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
      test_notifications_summary_mode_pull_request;
      test_notifications_summary_mode_default;
      test_notifications_summary_enabled_unset;
      test_notifications_summary_enabled_unset_round_trip;
      test_notifications_orthogonal_settings;
      test_notifications_orthogonal_settings_without_summary;
      test_notifications_orthogonal_defaults;
      test_notifications_orthogonal_round_trip;
      test_notifications_status_checks_defaults;
      test_notifications_status_checks_configured;
      test_notifications_status_checks_round_trip;
      test_notifications_classic_comment_visible;
      test_notifications_summary_mode_round_trip;
      test_engine_custom_resource_summary;
      test_batch_runs_merge_steps_defaults;
      test_batch_runs_merge_steps_each_value;
      test_batch_runs_merge_steps_round_trip;
      test_batch_runs_merge_steps_by_phase_round_trip;
      test_prechecks_default_empty;
      test_prechecks_parse_all_kinds;
      test_prechecks_globs_are_repo_paths;
      test_prechecks_bad_glob_rejected;
      test_prechecks_round_trip;
      test_prechecks_rejected_in_a_dir;
      test_prechecks_not_inherited_by_a_dir;
    ]

let () =
  Random.self_init ();
  Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)
