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

(* The runner applies an engine default when the plan step config it receives has no [extra_args]
   key, so an unset [extra_args] must stay unset through to_version_1, and an explicit list, even
   an empty one, must stay set. *)
let test_workflow_plan_extra_args_to_version_1_round_trip =
  Oth.test ~name:"workflows: plan extra_args set or unset round-trips through Version_1" (fun _ ->
      let module Items = Terrat_repo_config_workflow_op_list.Items in
      let module P = Terrat_repo_config_workflow_op_plan in
      let plan_step_json plan_step =
        let json = workflows_json [ workflow_entry ~plan:[ plan_step ] "" ] in
        let cfg = Oth.Assert.ok_pp ~pp:V1.pp_of_version_1_json_err (V1.of_version_1_json json) in
        let v1 = V1.to_version_1 cfg in
        let entry =
          Oth.Assert.List.length_one (CCOption.get_or ~default:[] v1.Repo.Version_1.workflows)
        in
        match entry.Repo.Workflow_entry.plan with
        | Some [ Items.Workflow_op_plan plan ] -> P.to_yojson plan
        | Some _ | None -> Oth.Assert.false_ "expected a plan step"
      in
      let extra_args_json plan_step =
        Yojson.Safe.Util.member "extra_args" (plan_step_json plan_step)
      in
      let with_extra_args args =
        `Assoc
          [ ("type", `String "plan"); ("extra_args", `List (CCList.map (fun a -> `String a) args)) ]
      in
      Oth.Assert.eq ~eq:Yojson.Safe.equal ~pp:Yojson.Safe.pp `Null (extra_args_json (step "plan"));
      Oth.Assert.eq
        ~eq:Yojson.Safe.equal
        ~pp:Yojson.Safe.pp
        (`List [])
        (extra_args_json (with_extra_args []));
      Oth.Assert.eq
        ~eq:Yojson.Safe.equal
        ~pp:Yojson.Safe.pp
        (`List [ `String "--foo" ])
        (extra_args_json (with_extra_args [ "--foo" ]));
      ())

let log_output_step ?log_output ?(cmd = []) type_ =
  `Assoc
    (("type", `String type_)
    :: CCList.filter_map
         CCFun.id
         [
           CCOption.map (fun b -> ("log_output", `Bool b)) log_output;
           (match cmd with
           | [] -> None
           | cmd -> Some ("cmd", `List (CCList.map (fun c -> `String c) cmd)));
         ])

(* Version_1 JSON of the init, plan and run steps of the workflow, the apply step, and the plan
   pre hook, in that order. *)
let log_output_round_trip ?log_output () =
  let open Yojson.Safe.Util in
  let json =
    `Assoc
      [
        ( "workflows",
          `List
            [
              workflow_entry
                ~plan:
                  [
                    log_output_step ?log_output "init";
                    log_output_step ?log_output "plan";
                    log_output_step ?log_output ~cmd:[ "true" ] "run";
                  ]
                ~apply:[ log_output_step ?log_output "apply" ]
                "";
            ] );
        ( "hooks",
          `Assoc
            [
              ( "plan",
                `Assoc [ ("pre", `List [ log_output_step ?log_output ~cmd:[ "true" ] "run" ]) ] );
            ] );
      ]
  in
  let cfg = Oth.Assert.ok_pp ~pp:V1.pp_of_version_1_json_err (V1.of_version_1_json json) in
  let v1 = Repo.Version_1.to_yojson (V1.to_version_1 cfg) in
  let entry = CCList.hd (to_list (member "workflows" v1)) in
  to_list (member "plan" entry)
  @ to_list (member "apply" entry)
  @ to_list (member "pre" (member "plan" (member "hooks" v1)))

let test_workflow_log_output_to_version_1_round_trip =
  Oth.test ~name:"workflows: log_output round-trips through Version_1" (fun _ ->
      let assert_log_output expected steps =
        Oth.Assert.eq
          ~eq:(CCList.equal Yojson.Safe.equal)
          ~pp:(CCList.pp Yojson.Safe.pp)
          (CCList.replicate 5 expected)
          (CCList.map (Yojson.Safe.Util.member "log_output") steps)
      in
      (* A value equal to the schema default is omitted from the output. *)
      assert_log_output `Null (log_output_round_trip ());
      assert_log_output `Null (log_output_round_trip ~log_output:true ());
      assert_log_output (`Bool false) (log_output_round_trip ~log_output:false ());
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
       plan = { N.Plan.visible_on = N.Plan_visible_on.Never; _ };
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
       plan = { N.Plan.visible_on = N.Plan_visible_on.Never; _ };
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
       plan = { N.Plan.visible_on = N.Plan_visible_on.Always; _ };
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

let test_notifications_plan_change_or_failure =
  Oth.test ~name:"of_version_1_json: plan visible_on change_or_failure round-trips" (fun _ ->
      let module N = V1.Notifications in
      let module Nn = Repo.Notifications in
      let json =
        `Assoc
          [
            ( "notifications",
              `Assoc [ ("plan", `Assoc [ ("visible_on", `String "change_or_failure") ]) ] );
          ]
      in
      let cfg =
        Oth.Assert.ok_show ~show:V1.show_of_version_1_json_err (V1.of_version_1_json json)
      in
      (match V1.notifications cfg with
      | { N.plan = { N.Plan.visible_on = N.Plan_visible_on.Change_or_failure; _ }; _ } -> ()
      | n -> failwith ("unexpected notifications: " ^ N.show n));
      match (V1.to_version_1 cfg).Repo.Version_1.notifications with
      | Some { Nn.plan = Some { Nn.Plan.visible_on = Some `Change_or_failure; _ }; _ } -> ()
      | _ -> failwith "Round-trip to Version_1 did not keep change_or_failure")

let test_notifications_apply_change_or_failure_rejected =
  Oth.test ~name:"of_version_1_json: apply visible_on rejects change_or_failure" (fun _ ->
      let json =
        `Assoc
          [
            ( "notifications",
              `Assoc [ ("apply", `Assoc [ ("visible_on", `String "change_or_failure") ]) ] );
          ]
      in
      match V1.of_version_1_json json with
      | Error _ -> ()
      | Ok _ -> failwith "apply visible_on accepted change_or_failure")

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
      let module Pv = N.Plan_visible_on in
      let t ~enabled ~mode ~plan_vo ~apply_vo =
        N.make
          ~summary:(Sum.make ~enabled:(Some enabled) ~mode ())
          ~plan:(N.Plan.make ~visible_on:plan_vo ())
          ~apply:(N.Apply.make ~visible_on:apply_vo ())
          ()
      in
      let pr = Sum.Mode.Pull_request and hd = Sum.Mode.Header in
      (* (enabled, mode, plan_vo, apply_vo, run, success, has_changes, gates, expected) *)
      let cases =
        [
          (true, pr, Pv.Never, Vo.Never, `Plan, true, true, false, false);
          (true, pr, Pv.Never, Vo.Never, `Apply, true, true, false, false);
          (true, pr, Pv.Always, Vo.Always, `Plan, false, true, false, true);
          (true, pr, Pv.Always, Vo.Always, `Plan, true, false, false, true);
          (true, pr, Pv.Success, Vo.Never, `Plan, true, true, false, true);
          (true, pr, Pv.Success, Vo.Never, `Plan, false, true, false, false);
          (true, pr, Pv.Failure, Vo.Never, `Plan, false, true, false, true);
          (true, pr, Pv.Failure, Vo.Never, `Plan, true, true, false, false);
          (* change_or_failure: a successful plan posts only when it has changes *)
          (true, pr, Pv.Change_or_failure, Vo.Never, `Plan, true, true, false, true);
          (true, pr, Pv.Change_or_failure, Vo.Never, `Plan, true, false, false, false);
          (true, pr, Pv.Change_or_failure, Vo.Never, `Plan, false, false, false, true);
          (true, pr, Pv.Change_or_failure, Vo.Never, `Plan, false, true, false, true);
          (true, pr, Pv.Change_or_failure, Vo.Never, `Plan, true, false, true, true);
          (* visible_on is per run kind *)
          (true, pr, Pv.Never, Vo.Always, `Apply, true, true, false, true);
          (true, pr, Pv.Change_or_failure, Vo.Always, `Apply, true, false, false, true);
          (* forced posts: gates and access-control denials *)
          (true, pr, Pv.Never, Vo.Never, `Plan, true, true, true, true);
          (* header mode does not force the comment: the header goes with it *)
          (true, hd, Pv.Never, Vo.Never, `Plan, true, true, false, false);
          (true, hd, Pv.Always, Vo.Always, `Plan, true, true, false, true);
          (* summary disabled: the setting still decides *)
          (false, pr, Pv.Never, Vo.Never, `Plan, true, true, false, false);
          (false, pr, Pv.Always, Vo.Always, `Plan, true, true, false, true);
        ]
      in
      CCList.iter
        (fun (enabled, mode, plan_vo, apply_vo, run, success, has_changes, gates, expected) ->
          let t = t ~enabled ~mode ~plan_vo ~apply_vo in
          let actual =
            N.classic_comment_visible t ~run ~success ~has_changes ~gates_or_denials:gates
          in
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

(* [batch_runs.max_work_manifests_per_node] is how many work manifests one action run may perform.
   The default is nine, which is what a node already took before the key existed: the setup steps
   of a job share one run under the default [merge_steps] of [setup]. *)
let test_batch_runs_max_work_manifests_per_node_default =
  Oth.test ~name:"of_version_1_json: max_work_manifests_per_node defaults to 9" (fun _ ->
      let cfg = config_of_json (`Assoc []) in
      let { V1.Batch_runs.max_work_manifests_per_node; _ } = V1.batch_runs cfg in
      Oth.Assert.eq ~eq:CCInt.equal ~pp:CCInt.pp max_work_manifests_per_node 9;
      ())

let test_batch_runs_max_work_manifests_per_node_configured =
  Oth.test ~name:"of_version_1_json: max_work_manifests_per_node" (fun _ ->
      let json = `Assoc [ ("batch_runs", `Assoc [ ("max_work_manifests_per_node", `Int 3) ]) ] in
      let cfg = config_of_json json in
      let { V1.Batch_runs.max_work_manifests_per_node; _ } = V1.batch_runs cfg in
      Oth.Assert.eq ~eq:CCInt.equal ~pp:CCInt.pp max_work_manifests_per_node 3;
      ())

(* The key only lowers the cap.  Nine is the highest value the schema gives it, because the action
   stops after eleven turns of its loop. *)
let test_batch_runs_max_work_manifests_per_node_maximum =
  Oth.test ~name:"of_version_1_json: max_work_manifests_per_node accepts 9" (fun _ ->
      let json = `Assoc [ ("batch_runs", `Assoc [ ("max_work_manifests_per_node", `Int 9) ]) ] in
      let cfg = config_of_json json in
      let { V1.Batch_runs.max_work_manifests_per_node; _ } = V1.batch_runs cfg in
      Oth.Assert.eq ~eq:CCInt.equal ~pp:CCInt.pp max_work_manifests_per_node 9;
      ())

(* A value below one would let no work manifest join a node. *)
let test_batch_runs_max_work_manifests_per_node_below_minimum =
  Oth.test ~name:"of_version_1_json: max_work_manifests_per_node is at least 1" (fun _ ->
      let json = `Assoc [ ("batch_runs", `Assoc [ ("max_work_manifests_per_node", `Int 0) ]) ] in
      match Oth.Assert.error (V1.of_version_1_json json) with
      | `Repo_config_schema_err _ -> ()
      | err ->
          Oth.Assert.false_
            (Printf.sprintf
               "Expected max_work_manifests_per_node to be rejected, got %s"
               (V1.show_of_version_1_json_err err)))

(* A value above nine would leave a work manifest on a run that has gone.  The
   error names the key, because a value out of range is the only way to reach it. *)
let test_batch_runs_max_work_manifests_per_node_above_maximum =
  Oth.test ~name:"of_version_1_json: max_work_manifests_per_node is at most 9" (fun _ ->
      let json = `Assoc [ ("batch_runs", `Assoc [ ("max_work_manifests_per_node", `Int 10) ]) ] in
      match Oth.Assert.error (V1.of_version_1_json json) with
      | `Repo_config_schema_err _ as err ->
          Oth.Assert.str_contains
            ~haystack:(V1.show_of_version_1_json_err err)
            ~needle:"batch_runs.max_work_manifests_per_node"
      | err ->
          Oth.Assert.false_
            (Printf.sprintf
               "Expected max_work_manifests_per_node to be rejected, got %s"
               (V1.show_of_version_1_json_err err)))

(* Both fields are checked on their own, so two out-of-range values are both reported: the error
   payload is a list, and a projection that kept only one of them would hide the other. *)
let test_batch_runs_and_concurrent_runs_both_out_of_range =
  Oth.test ~name:"of_version_1_json: both schema errors are reported" (fun _ ->
      let json =
        `Assoc
          [
            ( "work_manifests",
              `Assoc [ ("concurrent_runs", `Int 0); ("start_timeout_sec", `Int 30) ] );
            ("batch_runs", `Assoc [ ("max_work_manifests_per_node", `Int 10) ]);
          ]
      in
      match Oth.Assert.error (V1.of_version_1_json json) with
      | `Repo_config_schema_err _ as err ->
          let shown = V1.show_of_version_1_json_err err in
          Oth.Assert.str_contains ~haystack:shown ~needle:"work_manifests.concurrent_runs";
          Oth.Assert.str_contains ~haystack:shown ~needle:"batch_runs.max_work_manifests_per_node"
      | err ->
          Oth.Assert.false_
            (Printf.sprintf
               "Expected both fields to be rejected, got %s"
               (V1.show_of_version_1_json_err err)))

(* A configured value comes back out of [to_version_1].  A block that holds only the default stays
   out of it, which the merge_steps tests above already show. *)
let test_batch_runs_max_work_manifests_per_node_round_trip =
  Oth.test ~name:"to_version_1: max_work_manifests_per_node round-trip" (fun _ ->
      let json = `Assoc [ ("batch_runs", `Assoc [ ("max_work_manifests_per_node", `Int 3) ]) ] in
      let v1 =
        V1.to_version_1
          (Oth.Assert.ok_show ~show:V1.show_of_version_1_json_err (V1.of_version_1_json json))
      in
      Oth.Assert.Eq.option
        ~eq:Repo.Batch_runs.equal
        ~pp:Repo.Batch_runs.pp
        ~expected:(Some (Repo.Batch_runs.make ~max_work_manifests_per_node:3 ()))
        ~actual:v1.Repo.Version_1.batch_runs)

(* [work_manifests.start_timeout_sec] is the number of seconds a dispatched work manifest has to
   call home before the stale check aborts it (RFD 2826).  The default is 180 seconds. *)
let test_work_manifests_start_timeout_default =
  Oth.test ~name:"of_version_1_json: work_manifests.start_timeout_sec defaults to 180" (fun _ ->
      let cfg = config_of_json (`Assoc []) in
      Oth.Assert.eq
        ~eq:V1.Work_manifests.equal
        ~pp:V1.Work_manifests.pp
        (V1.work_manifests cfg)
        (V1.Work_manifests.make ());
      ())

let test_work_manifests_start_timeout_configured =
  Oth.test ~name:"of_version_1_json: work_manifests.start_timeout_sec" (fun _ ->
      let json = `Assoc [ ("work_manifests", `Assoc [ ("start_timeout_sec", `Int 45) ]) ] in
      let cfg = config_of_json json in
      Oth.Assert.eq
        ~eq:V1.Work_manifests.equal
        ~pp:V1.Work_manifests.pp
        (V1.work_manifests cfg)
        (V1.Work_manifests.make ~start_timeout:(Duration.of_sec 45) ());
      ())

(* A timeout below one second has no meaning, and a value above [Int32.max_int] wraps when the
   server gives it to the database, so the parse rejects both. *)
let test_work_manifests_start_timeout_below_minimum =
  Oth.test ~name:"of_version_1_json: work_manifests.start_timeout_sec is at least 1" (fun _ ->
      let json = `Assoc [ ("work_manifests", `Assoc [ ("start_timeout_sec", `Int 0) ]) ] in
      match Oth.Assert.error (V1.of_version_1_json json) with
      | `Repo_config_schema_err _ -> ()
      | err ->
          Oth.Assert.false_
            (Printf.sprintf
               "Expected start_timeout_sec to be rejected, got %s"
               (V1.show_of_version_1_json_err err)))

let test_work_manifests_start_timeout_above_maximum =
  Oth.test
    ~name:"of_version_1_json: work_manifests.start_timeout_sec is at most Int32.max_int"
    (fun _ ->
      let json =
        `Assoc
          [
            ( "work_manifests",
              `Assoc [ ("start_timeout_sec", `Int (Int32.to_int Int32.max_int + 1)) ] );
          ]
      in
      match Oth.Assert.error (V1.of_version_1_json json) with
      | `Repo_config_schema_err _ -> ()
      | err ->
          Oth.Assert.false_
            (Printf.sprintf
               "Expected start_timeout_sec to be rejected, got %s"
               (V1.show_of_version_1_json_err err)))

(* The default is left out of [to_version_1], as every other default is, and a value that the user
   set comes back out unchanged. *)
let test_work_manifests_start_timeout_round_trip =
  Oth.test ~name:"to_version_1: work_manifests.start_timeout_sec round-trip" (fun _ ->
      let json = `Assoc [ ("work_manifests", `Assoc [ ("start_timeout_sec", `Int 45) ]) ] in
      let v1 =
        V1.to_version_1
          (Oth.Assert.ok_show ~show:V1.show_of_version_1_json_err (V1.of_version_1_json json))
      in
      Oth.Assert.Eq.option
        ~eq:Repo.Work_manifests.equal
        ~pp:Repo.Work_manifests.pp
        ~expected:
          (Some (Repo.Work_manifests.make ~start_timeout_sec:45 ~stale_timeout_sec:86400 ()))
        ~actual:v1.Repo.Version_1.work_manifests)

(* The key names its unit, so a configuration that uses the old [start_timeout] key must fail the
   parse instead of read as the default. *)
let test_work_manifests_old_key_rejected =
  Oth.test ~name:"of_version_1_json: work_manifests.start_timeout is rejected" (fun _ ->
      let json = `Assoc [ ("work_manifests", `Assoc [ ("start_timeout", `Int 45) ]) ] in
      ignore
        (Oth.Assert.error
           ~fail_msg:"work_manifests.start_timeout was accepted"
           (V1.of_version_1_json json)))

(* [work_manifests.stale_timeout_sec] is the age past which the hourly sweep aborts a run that is
   still running (RFD 2826).  The default is one day. *)
let test_work_manifests_stale_timeout_default =
  Oth.test ~name:"of_version_1_json: work_manifests.stale_timeout_sec defaults to one day" (fun _ ->
      let cfg = config_of_json (`Assoc []) in
      Oth.Assert.eq
        ~eq:V1.Work_manifests.equal
        ~pp:V1.Work_manifests.pp
        (V1.work_manifests cfg)
        (V1.Work_manifests.make
           ~start_timeout:(Duration.of_sec 180)
           ~stale_timeout:(Duration.of_day 1)
           ());
      ())

let test_work_manifests_stale_timeout_configured =
  Oth.test ~name:"of_version_1_json: work_manifests.stale_timeout_sec" (fun _ ->
      let json = `Assoc [ ("work_manifests", `Assoc [ ("stale_timeout_sec", `Int 45) ]) ] in
      let cfg = config_of_json json in
      Oth.Assert.eq
        ~eq:V1.Work_manifests.equal
        ~pp:V1.Work_manifests.pp
        (V1.work_manifests cfg)
        (V1.Work_manifests.make
           ~start_timeout:(Duration.of_sec 180)
           ~stale_timeout:(Duration.of_sec 45)
           ());
      ())

(* A timeout below one second has no meaning, and a value above [Int32.max_int] wraps when the
   server gives it to the database, so the parse rejects both. *)
let test_work_manifests_stale_timeout_below_minimum =
  Oth.test ~name:"of_version_1_json: work_manifests.stale_timeout_sec is at least 1" (fun _ ->
      let json = `Assoc [ ("work_manifests", `Assoc [ ("stale_timeout_sec", `Int 0) ]) ] in
      match Oth.Assert.error (V1.of_version_1_json json) with
      | `Repo_config_schema_err _ -> ()
      | err ->
          Oth.Assert.false_
            (Printf.sprintf
               "Expected stale_timeout_sec to be rejected, got %s"
               (V1.show_of_version_1_json_err err)))

let test_work_manifests_stale_timeout_above_maximum =
  Oth.test
    ~name:"of_version_1_json: work_manifests.stale_timeout_sec is at most Int32.max_int"
    (fun _ ->
      let json =
        `Assoc
          [
            ( "work_manifests",
              `Assoc [ ("stale_timeout_sec", `Int (Int32.to_int Int32.max_int + 1)) ] );
          ]
      in
      match Oth.Assert.error (V1.of_version_1_json json) with
      | `Repo_config_schema_err _ -> ()
      | err ->
          Oth.Assert.false_
            (Printf.sprintf
               "Expected stale_timeout_sec to be rejected, got %s"
               (V1.show_of_version_1_json_err err)))

(* A configured value comes back out of [to_version_1], and the default block stays out of it. *)
let test_work_manifests_stale_timeout_round_trip =
  Oth.test ~name:"to_version_1: work_manifests.stale_timeout_sec round-trip" (fun _ ->
      let json = `Assoc [ ("work_manifests", `Assoc [ ("stale_timeout_sec", `Int 45) ]) ] in
      let v1 =
        V1.to_version_1
          (Oth.Assert.ok_show ~show:V1.show_of_version_1_json_err (V1.of_version_1_json json))
      in
      Oth.Assert.Eq.option
        ~eq:Repo.Work_manifests.equal
        ~pp:Repo.Work_manifests.pp
        ~expected:(Some (Repo.Work_manifests.make ~start_timeout_sec:180 ~stale_timeout_sec:45 ()))
        ~actual:v1.Repo.Version_1.work_manifests)

(* The key names its unit, as [start_timeout_sec] does, so a configuration that uses the unsuffixed
   [stale_timeout] key must fail the parse instead of read as the default. *)
let test_work_manifests_stale_old_key_rejected =
  Oth.test ~name:"of_version_1_json: work_manifests.stale_timeout is rejected" (fun _ ->
      let json = `Assoc [ ("work_manifests", `Assoc [ ("stale_timeout", `Int 45) ]) ] in
      ignore
        (Oth.Assert.error
           ~fail_msg:"work_manifests.stale_timeout was accepted"
           (V1.of_version_1_json json)))

let test_work_manifests_default_omitted =
  Oth.test ~name:"to_version_1: a default work_manifests block stays out" (fun _ ->
      let v1 =
        V1.to_version_1
          (Oth.Assert.ok_show
             ~show:V1.show_of_version_1_json_err
             (V1.of_version_1_json (`Assoc [])))
      in
      Oth.Assert.none
        ~fail_msg:"a default work_manifests was written out"
        v1.Repo.Version_1.work_manifests)

(* [work_manifests.concurrent_runs] is the number of work manifests that one job may run at the
   same time (RFD 2903).  The default is ten. *)
let test_work_manifests_concurrent_runs_default =
  Oth.test ~name:"of_version_1_json: work_manifests.concurrent_runs defaults to 10" (fun _ ->
      let cfg = config_of_json (`Assoc []) in
      Oth.Assert.eq
        ~eq:V1.Work_manifests.equal
        ~pp:V1.Work_manifests.pp
        (V1.work_manifests cfg)
        (V1.Work_manifests.make
           ~concurrent_runs:10
           ~start_timeout:(Duration.of_sec 180)
           ~stale_timeout:(Duration.of_day 1)
           ());
      ())

let test_work_manifests_concurrent_runs_configured =
  Oth.test ~name:"of_version_1_json: work_manifests.concurrent_runs" (fun _ ->
      let json = `Assoc [ ("work_manifests", `Assoc [ ("concurrent_runs", `Int 3) ]) ] in
      let cfg = config_of_json json in
      Oth.Assert.eq
        ~eq:V1.Work_manifests.equal
        ~pp:V1.Work_manifests.pp
        (V1.work_manifests cfg)
        (V1.Work_manifests.make
           ~concurrent_runs:3
           ~start_timeout:(Duration.of_sec 180)
           ~stale_timeout:(Duration.of_day 1)
           ());
      ())

(* One concurrent run is the smallest value that has meaning. *)
let test_work_manifests_concurrent_runs_minimum =
  Oth.test ~name:"of_version_1_json: work_manifests.concurrent_runs accepts 1" (fun _ ->
      let json = `Assoc [ ("work_manifests", `Assoc [ ("concurrent_runs", `Int 1) ]) ] in
      let cfg = config_of_json json in
      let { V1.Work_manifests.concurrent_runs; _ } = V1.work_manifests cfg in
      Oth.Assert.eq ~eq:CCInt.equal ~pp:CCInt.pp concurrent_runs 1;
      ())

(* A value below one has no meaning, and a value above [Int32.max_int] wraps when the server
   gives it to the database, so the parse rejects both. *)
let test_work_manifests_concurrent_runs_below_minimum =
  Oth.test ~name:"of_version_1_json: work_manifests.concurrent_runs is at least 1" (fun _ ->
      let json = `Assoc [ ("work_manifests", `Assoc [ ("concurrent_runs", `Int 0) ]) ] in
      match Oth.Assert.error (V1.of_version_1_json json) with
      | `Repo_config_schema_err _ -> ()
      | err ->
          Oth.Assert.false_
            (Printf.sprintf
               "Expected concurrent_runs to be rejected, got %s"
               (V1.show_of_version_1_json_err err)))

let test_work_manifests_concurrent_runs_above_maximum =
  Oth.test
    ~name:"of_version_1_json: work_manifests.concurrent_runs is at most Int32.max_int"
    (fun _ ->
      let json =
        `Assoc
          [
            ("work_manifests", `Assoc [ ("concurrent_runs", `Int (Int32.to_int Int32.max_int + 1)) ]);
          ]
      in
      match Oth.Assert.error (V1.of_version_1_json json) with
      | `Repo_config_schema_err _ -> ()
      | err ->
          Oth.Assert.false_
            (Printf.sprintf
               "Expected concurrent_runs to be rejected, got %s"
               (V1.show_of_version_1_json_err err)))

(* A configured value comes back out of [to_version_1], and the default block stays out of it. *)
let test_work_manifests_concurrent_runs_round_trip =
  Oth.test ~name:"to_version_1: work_manifests.concurrent_runs round-trip" (fun _ ->
      let json = `Assoc [ ("work_manifests", `Assoc [ ("concurrent_runs", `Int 3) ]) ] in
      let v1 =
        V1.to_version_1
          (Oth.Assert.ok_show ~show:V1.show_of_version_1_json_err (V1.of_version_1_json json))
      in
      Oth.Assert.Eq.option
        ~eq:Repo.Work_manifests.equal
        ~pp:Repo.Work_manifests.pp
        ~expected:(Some (Repo.Work_manifests.make ~concurrent_runs:3 ~start_timeout_sec:180 ()))
        ~actual:v1.Repo.Version_1.work_manifests)

(* The SQL that reads work_manifests.concurrent_runs casts the value out of the derived config
   JSON without a guard (RFD 2903).  The server writes this key, and the writer emits a JSON
   number for it.  The repository config schema rejects a value outside the range, so a row the
   server wrote always casts.  The two tests below pin that fact on the encoded JSON rather than
   on the record. *)

(* Walks the encoded config down to [work_manifests.concurrent_runs]. *)
let encoded_concurrent_runs v1 =
  Yojson.Safe.Util.member
    "concurrent_runs"
    (Yojson.Safe.Util.member "work_manifests" (Repo.Version_1.to_yojson v1))

let test_work_manifests_concurrent_runs_to_yojson =
  Oth.test ~name:"to_yojson: work_manifests.concurrent_runs is a JSON integer" (fun _ ->
      let json = `Assoc [ ("work_manifests", `Assoc [ ("concurrent_runs", `Int 3) ]) ] in
      let cfg =
        Oth.Assert.ok_show ~show:V1.show_of_version_1_json_err (V1.of_version_1_json json)
      in
      Oth.Assert.eq
        ~eq:Yojson.Safe.equal
        ~pp:Yojson.Safe.pp
        (`Int 3)
        (encoded_concurrent_runs (V1.to_version_1 cfg)))

(* The writer drops a block that equals its default, so a default config encodes no
   [work_manifests] key at all. *)
let test_work_manifests_default_absent_from_to_yojson =
  Oth.test ~name:"to_yojson: a default config writes no work_manifests key" (fun _ ->
      let cfg =
        Oth.Assert.ok_show ~show:V1.show_of_version_1_json_err (V1.of_version_1_json (`Assoc []))
      in
      let encoded = Repo.Version_1.to_yojson (V1.to_version_1 cfg) in
      Oth.Assert.eq
        ~eq:Yojson.Safe.equal
        ~pp:Yojson.Safe.pp
        `Null
        (Yojson.Safe.Util.member "work_manifests" encoded))

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

(* The global [autoplan] is the default of every dir, including a dir that sets a [when_modified]
   of its own: the dir inherits the keys it does not set.  A test that must see the run a comment
   starts turns autoplan off this way, and an autoplan of the same pull request would otherwise plan
   the dirspace first and answer the comment as already planned. *)
let test_autoplan_off_reaches_a_dir_with_its_own_when_modified =
  Oth.test ~name:"when_modified: a global autoplan false reaches every dir" (fun _ ->
      let json =
        `Assoc
          [
            ( "dirs",
              `Assoc
                [
                  ( "database",
                    `Assoc [ ("when_modified", `Assoc [ ("depends_on", `String "dir:base") ]) ] );
                ] );
            ("when_modified", `Assoc [ ("autoplan", `Bool false) ]);
          ]
      in
      let cfg = config_of_json json in
      Oth.Assert.Eq.bool ~expected:false ~actual:(V1.when_modified cfg).V1.When_modified.autoplan;
      let dir =
        Oth.Assert.some
          ~fail_msg:"Expected a dir named database"
          (Sln_map.String.find_opt "database" (V1.dirs cfg))
      in
      let workspaces = Sln_map.String.to_list dir.V1.Dirs.Dir.workspaces in
      ignore (Oth.Assert.List.non_empty workspaces);
      CCList.iter
        (fun (_name, { V1.Dirs.Workspace.when_modified; _ }) ->
          Oth.Assert.Eq.bool ~expected:false ~actual:when_modified.V1.When_modified.autoplan)
        workspaces)

(* A pull request that changes nothing the repository manages still has to satisfy a branch
   protection rule that keys on the apply check, so the completed check of a noop is on unless the
   configuration turns it off. *)
let test_apply_requirements_noop_check_default =
  Oth.test
    ~name:"apply_requirements: create_completed_apply_check_on_noop defaults to true"
    (fun _ ->
      let ar = V1.apply_requirements (config_of_json (`Assoc [])) in
      if not ar.V1.Apply_requirements.create_completed_apply_check_on_noop then
        failwith "create_completed_apply_check_on_noop defaults to false")

(* The opt-out is what a repository that wants no such check uses, and it has to survive the
   parse. *)
let test_apply_requirements_noop_check_off =
  Oth.test
    ~name:"apply_requirements: create_completed_apply_check_on_noop can be turned off"
    (fun _ ->
      let json =
        `Assoc
          [
            ("apply_requirements", `Assoc [ ("create_completed_apply_check_on_noop", `Bool false) ]);
          ]
      in
      let ar = V1.apply_requirements (config_of_json json) in
      if ar.V1.Apply_requirements.create_completed_apply_check_on_noop then
        failwith "create_completed_apply_check_on_noop ignored the false value")

(* [require_explicit_apply] takes a boolean or the string [include_layers].  Stored built configs
   are Version_1 JSON, so each value must come back out of [to_version_1] as it went in. *)

let automerge_json require_explicit_apply =
  `Assoc [ ("automerge", `Assoc [ ("require_explicit_apply", require_explicit_apply) ]) ]

let assert_require_explicit_apply expected cfg =
  Oth.Assert.eq
    ~eq:V1.Automerge.Require_explicit_apply.equal
    ~pp:V1.Automerge.Require_explicit_apply.pp
    expected
    (V1.automerge cfg).V1.Automerge.require_explicit_apply

let require_explicit_apply_values =
  V1.Automerge.Require_explicit_apply.
    [ (`Bool false, Disabled); (`Bool true, Enabled); (`String "include_layers", Include_layers) ]

let test_automerge_require_explicit_apply_default =
  Oth.test ~name:"automerge: require_explicit_apply defaults to disabled" (fun _ ->
      assert_require_explicit_apply
        V1.Automerge.Require_explicit_apply.Disabled
        (config_of_json (`Assoc [ ("automerge", `Assoc [ ("enabled", `Bool true) ]) ])))

let test_automerge_require_explicit_apply_values =
  Oth.test ~name:"automerge: require_explicit_apply reads each value" (fun _ ->
      CCList.iter
        (fun (json, expected) ->
          assert_require_explicit_apply expected (config_of_json (automerge_json json)))
        require_explicit_apply_values)

let test_automerge_require_explicit_apply_round_trip =
  Oth.test ~name:"automerge: require_explicit_apply round-trips through Version_1" (fun _ ->
      CCList.iter
        (fun (json, expected) ->
          let v1 = V1.to_version_1 (config_of_json (automerge_json json)) in
          assert_require_explicit_apply expected (config_of_json (Repo.Version_1.to_yojson v1)))
        require_explicit_apply_values)

let test_automerge_require_explicit_apply_unknown_rejected =
  Oth.test ~name:"automerge: require_explicit_apply rejects an unknown string" (fun _ ->
      match V1.of_version_1_json (automerge_json (`String "layers")) with
      | Ok _ -> failwith "require_explicit_apply accepted an unknown string"
      | Error _ -> ())

(* Tests for the [parameters] section: the schema shape decodes into the derived
   [V1.Parameters] module, the defaults collapse, the schema and the decoder agree on
   [values: null], a structurally valid but cross-field-invalid section still decodes, and the
   section round-trips through Version_1. *)

let parameters_json ?aliases ?names () =
  let fields =
    CCList.filter_map
      CCFun.id
      [
        CCOption.map (fun a -> ("aliases", `Assoc a)) aliases;
        CCOption.map (fun n -> ("names", `Assoc n)) names;
      ]
  in
  `Assoc [ ("parameters", `Assoc fields) ]

let parameters_of_json json = V1.parameters (config_of_json json)

let test_parameters_absent_section_is_empty =
  Oth.test ~name:"parameters: an absent section gives two empty maps" (fun _ ->
      Oth.Assert.eq
        ~eq:V1.Parameters.equal
        ~pp:V1.Parameters.pp
        (V1.Parameters.make ())
        (parameters_of_json (`Assoc [])))

let test_parameters_names_values_and_fail_if_set =
  Oth.test ~name:"parameters: names values list and fail_if_set are read" (fun _ ->
      let json =
        parameters_json
          ~names:
            [
              ( "mode",
                `Assoc
                  [
                    ("fail_if_set", `Bool true);
                    ("values", `List [ `String "DEBUG"; `String "RELEASE" ]);
                  ] );
            ]
          ()
      in
      match Sln_map.String.find_opt "mode" (parameters_of_json json).V1.Parameters.names with
      | Some p ->
          Oth.Assert.Eq.bool ~expected:true ~actual:p.V1.Parameters.Parameter.fail_if_set;
          Oth.Assert.Eq.string_list
            ~expected:[ "DEBUG"; "RELEASE" ]
            ~actual:
              (match p.V1.Parameters.Parameter.values with
              | Some values -> values
              | None -> failwith "values absent")
      | None -> failwith "parameter mode is missing")

let test_parameters_empty_body_defaults =
  Oth.test ~name:"parameters: an empty parameter body takes both defaults" (fun _ ->
      let json = parameters_json ~names:[ ("mode", `Assoc []) ] () in
      match Sln_map.String.find_opt "mode" (parameters_of_json json).V1.Parameters.names with
      | Some p ->
          Oth.Assert.Eq.bool ~expected:false ~actual:p.V1.Parameters.Parameter.fail_if_set;
          Oth.Assert.none p.V1.Parameters.Parameter.values
      | None -> failwith "parameter mode is missing")

let test_parameters_values_null_reads_as_none =
  Oth.test ~name:"parameters: values null reads as none, like an absent values" (fun _ ->
      let json = parameters_json ~names:[ ("mode", `Assoc [ ("values", `Null) ]) ] () in
      match Sln_map.String.find_opt "mode" (parameters_of_json json).V1.Parameters.names with
      | Some p -> Oth.Assert.none p.V1.Parameters.Parameter.values
      | None -> failwith "parameter mode is missing")

let test_parameters_schema_decoder_agree =
  Oth.test
    ~name:"parameters: a values null next to a parallel_runs error names only parallel_runs"
    (fun _ ->
      let json =
        `Assoc
          [
            ("parameters", `Assoc [ ("names", `Assoc [ ("mode", `Assoc [ ("values", `Null) ]) ]) ]);
            ("parallel_runs", `String "abc");
          ]
      in
      match Oth.Assert.error (V1.of_version_1_json json) with
      | `Repo_config_schema_err errs ->
          let shown = V1.show_of_version_1_json_err (`Repo_config_schema_err errs) in
          Oth.Assert.str_contains ~haystack:shown ~needle:"parallel_runs";
          Oth.Assert.str_doesnt_contain ~haystack:shown ~needle:"parameters"
      | err -> failwith ("Expected Repo_config_schema_err, got " ^ V1.show_of_version_1_json_err err))

let test_parameters_alias_params_are_read =
  Oth.test ~name:"parameters: an alias with params is read" (fun _ ->
      let json =
        parameters_json
          ~aliases:
            [
              ( "debug",
                `Assoc
                  [ ("action", `String "plan"); ("params", `Assoc [ ("mode", `String "DEBUG") ]) ]
              );
            ]
          ~names:[ ("mode", `Assoc []) ]
          ()
      in
      match Sln_map.String.find_opt "debug" (parameters_of_json json).V1.Parameters.aliases with
      | Some a ->
          Oth.Assert.Eq.bool
            ~expected:true
            ~actual:
              (match a.V1.Parameters.Alias.action with
              | `Plan -> true
              | _ -> false);
          Oth.Assert.Eq.string
            ~expected:"DEBUG"
            ~actual:(Sln_map.String.find "mode" a.V1.Parameters.Alias.params)
      | None -> failwith "alias debug is missing")

let test_parameters_alias_without_params =
  Oth.test ~name:"parameters: an alias without params takes the empty map" (fun _ ->
      let json = parameters_json ~aliases:[ ("debug", `Assoc [ ("action", `String "plan") ]) ] () in
      match Sln_map.String.find_opt "debug" (parameters_of_json json).V1.Parameters.aliases with
      | Some a -> Oth.Assert.true_ (Sln_map.String.is_empty a.V1.Parameters.Alias.params)
      | None -> failwith "alias debug is missing")

let test_parameters_alias_every_action_decodes =
  Oth.test ~name:"parameters: an alias carrying each of the four run actions decodes" (fun _ ->
      CCList.iter
        (fun action ->
          let json =
            parameters_json ~aliases:[ ("debug", `Assoc [ ("action", `String action) ]) ] ()
          in
          match Sln_map.String.find_opt "debug" (parameters_of_json json).V1.Parameters.aliases with
          | Some a ->
              Oth.Assert.true_
                ~fail_msg:("the action " ^ action ^ " did not decode")
                (match a.V1.Parameters.Alias.action with
                | `Apply -> CCString.equal action "apply"
                | `Apply_autoapprove -> CCString.equal action "apply-autoapprove"
                | `Apply_force -> CCString.equal action "apply-force"
                | `Plan -> CCString.equal action "plan")
          | None -> failwith "alias debug is missing")
        [ "plan"; "apply"; "apply-force"; "apply-autoapprove" ])

let test_parameters_structural_rejections =
  Oth.test ~name:"parameters: structurally invalid sections are rejected" (fun _ ->
      let cases =
        [
          ( "values holds a non-string",
            Some [ ("mode", `Assoc [ ("values", `List [ `Int 1 ]) ]) ],
            None );
          ( "values is a bare string",
            Some [ ("mode", `Assoc [ ("values", `String "DEBUG") ]) ],
            None );
          ("an alias has no action", None, Some [ ("debug", `Assoc [ ("params", `Assoc []) ]) ]);
          ( "an action outside the enum",
            None,
            Some [ ("debug", `Assoc [ ("action", `String "destroy") ]) ] );
          ( "an unknown key in a parameter",
            Some [ ("mode", `Assoc [ ("bogus", `Bool true) ]) ],
            None );
        ]
      in
      CCList.iter
        (fun (what, names, aliases) ->
          match V1.of_version_1_json (parameters_json ?aliases ?names ()) with
          | Ok _ -> failwith ("parameters: accepted " ^ what)
          | Error (`Repo_config_schema_err _) -> ()
          | Error err ->
              failwith
                ("parameters: unexpected error for "
                ^ what
                ^ ": "
                ^ V1.show_of_version_1_json_err err))
        cases)

let test_parameters_round_trip =
  Oth.test ~name:"parameters: a full section round-trips through Version_1" (fun _ ->
      let json =
        parameters_json
          ~aliases:
            [
              ( "debug",
                `Assoc
                  [ ("action", `String "plan"); ("params", `Assoc [ ("mode", `String "DEBUG") ]) ]
              );
            ]
          ~names:
            [
              ( "mode",
                `Assoc
                  [
                    ("fail_if_set", `Bool true);
                    ("values", `List [ `String "DEBUG"; `String "RELEASE" ]);
                  ] );
            ]
          ()
      in
      let cfg = config_of_json json in
      let round_tripped = config_of_json (Repo.Version_1.to_yojson (V1.to_version_1 cfg)) in
      Oth.Assert.eq
        ~eq:V1.Parameters.equal
        ~pp:V1.Parameters.pp
        (V1.parameters cfg)
        (V1.parameters round_tripped))

let test_parameters_absent_round_trips_absent =
  Oth.test ~name:"parameters: a config without the key round-trips to no parameters" (fun _ ->
      let cfg = config_of_json (`Assoc []) in
      Oth.Assert.none (V1.to_version_1 cfg).Repo.Version_1.parameters)

let test_parameters_round_trip_omits_absent_values =
  Oth.test
    ~name:"parameters: to_version_1 omits the values key of a parameter with no values"
    (fun _ ->
      let cfg =
        config_of_json
          (parameters_json ~names:[ ("mode", `Assoc [ ("fail_if_set", `Bool true) ]) ] ())
      in
      let encoded = Repo.Version_1.to_yojson (V1.to_version_1 cfg) in
      let mode =
        Yojson.Safe.Util.member
          "mode"
          (Yojson.Safe.Util.member "names" (Yojson.Safe.Util.member "parameters" encoded))
      in
      Oth.Assert.true_ (Yojson.Safe.Util.member "values" mode = `Null))

(* Cross-field rules: [of_version_1] applies the alias rules after the schema check.  The shadow
   rule wins over a bad [params] in the same alias, and the first failing alias in key order
   names the error.  The reserved-name list is a copy of [V1.reserved_alias_names], which is not
   exported; the duplication pins the ten words. *)

let test_parameters_rule_alias_unknown_parameter_rejected =
  Oth.test ~name:"parameters: an alias param naming an undeclared parameter is rejected" (fun _ ->
      let json =
        parameters_json
          ~aliases:
            [
              ( "debug",
                `Assoc
                  [ ("action", `String "plan"); ("params", `Assoc [ ("mode", `String "DEBUG") ]) ]
              );
            ]
          ()
      in
      match V1.of_version_1_json json with
      | Ok _ -> failwith "parameters: accepted an alias param naming an undeclared parameter"
      | Error (`Parameters_alias_unknown_parameter_err ("debug", "mode")) -> ()
      | Error err -> failwith ("parameters: unexpected error " ^ V1.show_of_version_1_json_err err))

let test_parameters_rule_value_not_allowed_rejected =
  Oth.test ~name:"parameters: an alias param value outside values is rejected" (fun _ ->
      let json =
        parameters_json
          ~aliases:
            [
              ( "debug",
                `Assoc
                  [ ("action", `String "plan"); ("params", `Assoc [ ("mode", `String "RELEASE") ]) ]
              );
            ]
          ~names:[ ("mode", `Assoc [ ("values", `List [ `String "DEBUG" ]) ]) ]
          ()
      in
      match V1.of_version_1_json json with
      | Ok _ -> failwith "parameters: accepted a value outside values"
      | Error (`Parameters_alias_value_not_allowed_err ("debug", "mode", "RELEASE")) -> ()
      | Error err -> failwith ("parameters: unexpected error " ^ V1.show_of_version_1_json_err err))

let test_parameters_rule_values_absent_accepts_any =
  Oth.test ~name:"parameters: a parameter without values accepts any alias param value" (fun _ ->
      let json =
        parameters_json
          ~aliases:
            [
              ( "debug",
                `Assoc
                  [
                    ("action", `String "plan"); ("params", `Assoc [ ("mode", `String "ANYTHING") ]);
                  ] );
            ]
          ~names:[ ("mode", `Assoc []) ]
          ()
      in
      match V1.of_version_1_json json with
      | Ok cfg -> (
          match Sln_map.String.find_opt "debug" (V1.parameters cfg).V1.Parameters.aliases with
          | Some alias ->
              Oth.Assert.Eq.string
                ~expected:"ANYTHING"
                ~actual:(Sln_map.String.find "mode" alias.V1.Parameters.Alias.params)
          | None -> failwith "alias debug is missing")
      | Error err -> failwith ("parameters: unexpected error " ^ V1.show_of_version_1_json_err err))

let test_parameters_rule_values_empty_accepts_none =
  Oth.test ~name:"parameters: a parameter with an empty values list accepts no value" (fun _ ->
      let json =
        parameters_json
          ~aliases:
            [
              ( "debug",
                `Assoc
                  [ ("action", `String "plan"); ("params", `Assoc [ ("mode", `String "DEBUG") ]) ]
              );
            ]
          ~names:[ ("mode", `Assoc [ ("values", `List []) ]) ]
          ()
      in
      match V1.of_version_1_json json with
      | Ok _ -> failwith "parameters: accepted a value against an empty values list"
      | Error (`Parameters_alias_value_not_allowed_err ("debug", "mode", "DEBUG")) -> ()
      | Error err -> failwith ("parameters: unexpected error " ^ V1.show_of_version_1_json_err err))

let test_parameters_rule_reserved_alias_names_rejected =
  Oth.test ~name:"parameters: an alias named a command word is rejected" (fun _ ->
      CCList.iter
        (fun name ->
          let json =
            parameters_json ~aliases:[ (name, `Assoc [ ("action", `String "plan") ]) ] ()
          in
          match V1.of_version_1_json json with
          | Ok _ -> failwith ("parameters: accepted the alias " ^ name)
          | Error (`Parameters_alias_shadows_verb_err shadowed) ->
              Oth.Assert.Eq.string ~expected:name ~actual:shadowed
          | Error err ->
              failwith
                ("parameters: unexpected error for "
                ^ name
                ^ ": "
                ^ V1.show_of_version_1_json_err err))
        [
          "unlock";
          "plan";
          "apply";
          "apply-autoapprove";
          "apply-force";
          "help";
          "feedback";
          "repo-config";
          "index";
          "gate";
        ])

let test_parameters_rule_alias_name_is_case_sensitive =
  Oth.test ~name:"parameters: an alias whose name only differs in case is accepted" (fun _ ->
      let json = parameters_json ~aliases:[ ("Plan", `Assoc [ ("action", `String "plan") ]) ] () in
      match V1.of_version_1_json json with
      | Ok cfg -> (
          match Sln_map.String.find_opt "Plan" (V1.parameters cfg).V1.Parameters.aliases with
          | Some _ -> ()
          | None -> failwith "alias Plan is missing")
      | Error err -> failwith ("parameters: unexpected error " ^ V1.show_of_version_1_json_err err))

let test_parameters_rule_shadow_wins_over_bad_params =
  Oth.test ~name:"parameters: the shadow rule wins over a bad params of the same alias" (fun _ ->
      let json =
        parameters_json
          ~aliases:
            [
              ( "apply",
                `Assoc
                  [ ("action", `String "plan"); ("params", `Assoc [ ("mode", `String "NOPE") ]) ] );
            ]
          ()
      in
      match V1.of_version_1_json json with
      | Ok _ -> failwith "parameters: accepted an alias that shadows a command"
      | Error (`Parameters_alias_shadows_verb_err "apply") -> ()
      | Error err -> failwith ("parameters: unexpected error " ^ V1.show_of_version_1_json_err err))

let test_parameters_rule_first_failing_alias_wins =
  Oth.test ~name:"parameters: the first failing alias in key order names the error" (fun _ ->
      let alias name =
        ( name,
          `Assoc [ ("action", `String "plan"); ("params", `Assoc [ ("mode", `String "NOPE") ]) ] )
      in
      let json = parameters_json ~aliases:[ alias "aaa"; alias "zzz" ] () in
      match V1.of_version_1_json json with
      | Ok _ -> failwith "parameters: accepted aliases naming an undeclared parameter"
      | Error (`Parameters_alias_unknown_parameter_err ("aaa", "mode")) -> ()
      | Error err -> failwith ("parameters: unexpected error " ^ V1.show_of_version_1_json_err err))

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
      test_workflow_plan_extra_args_to_version_1_round_trip;
      test_workflow_log_output_to_version_1_round_trip;
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
      test_notifications_plan_change_or_failure;
      test_notifications_apply_change_or_failure_rejected;
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
      test_batch_runs_max_work_manifests_per_node_default;
      test_batch_runs_max_work_manifests_per_node_configured;
      test_batch_runs_max_work_manifests_per_node_maximum;
      test_batch_runs_max_work_manifests_per_node_below_minimum;
      test_batch_runs_max_work_manifests_per_node_above_maximum;
      test_batch_runs_and_concurrent_runs_both_out_of_range;
      test_batch_runs_max_work_manifests_per_node_round_trip;
      test_work_manifests_start_timeout_default;
      test_work_manifests_start_timeout_configured;
      test_work_manifests_start_timeout_below_minimum;
      test_work_manifests_start_timeout_above_maximum;
      test_work_manifests_start_timeout_round_trip;
      test_work_manifests_old_key_rejected;
      test_work_manifests_stale_timeout_default;
      test_work_manifests_stale_timeout_configured;
      test_work_manifests_stale_timeout_below_minimum;
      test_work_manifests_stale_timeout_above_maximum;
      test_work_manifests_stale_timeout_round_trip;
      test_work_manifests_stale_old_key_rejected;
      test_work_manifests_default_omitted;
      test_work_manifests_concurrent_runs_default;
      test_work_manifests_concurrent_runs_configured;
      test_work_manifests_concurrent_runs_minimum;
      test_work_manifests_concurrent_runs_below_minimum;
      test_work_manifests_concurrent_runs_above_maximum;
      test_work_manifests_concurrent_runs_round_trip;
      test_work_manifests_concurrent_runs_to_yojson;
      test_work_manifests_default_absent_from_to_yojson;
      test_prechecks_default_empty;
      test_prechecks_parse_all_kinds;
      test_prechecks_globs_are_repo_paths;
      test_prechecks_bad_glob_rejected;
      test_prechecks_round_trip;
      test_prechecks_rejected_in_a_dir;
      test_prechecks_not_inherited_by_a_dir;
      test_autoplan_off_reaches_a_dir_with_its_own_when_modified;
      test_apply_requirements_noop_check_default;
      test_apply_requirements_noop_check_off;
      test_automerge_require_explicit_apply_default;
      test_automerge_require_explicit_apply_values;
      test_automerge_require_explicit_apply_round_trip;
      test_automerge_require_explicit_apply_unknown_rejected;
      test_parameters_absent_section_is_empty;
      test_parameters_names_values_and_fail_if_set;
      test_parameters_empty_body_defaults;
      test_parameters_values_null_reads_as_none;
      test_parameters_schema_decoder_agree;
      test_parameters_alias_params_are_read;
      test_parameters_alias_without_params;
      test_parameters_alias_every_action_decodes;
      test_parameters_structural_rejections;
      test_parameters_round_trip;
      test_parameters_absent_round_trips_absent;
      test_parameters_round_trip_omits_absent_values;
      test_parameters_rule_alias_unknown_parameter_rejected;
      test_parameters_rule_value_not_allowed_rejected;
      test_parameters_rule_values_absent_accepts_any;
      test_parameters_rule_values_empty_accepts_none;
      test_parameters_rule_reserved_alias_names_rejected;
      test_parameters_rule_alias_name_is_case_sensitive;
      test_parameters_rule_shadow_wins_over_bad_params;
      test_parameters_rule_first_failing_alias_wins;
    ]

let () =
  Random.self_init ();
  Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)
