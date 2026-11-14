(* Tests for the comment resolver, [Comment_resolve]: which comments read the repository
   configuration, how a declared alias expands, and which parameter token stops a run before
   it exists. *)

module Cr = Terrat_vcs_event_evaluator2.Comment_resolve
module Tc = Terrat_comment
module Tjc = Terrat_job_context
module P = Terrat_base_repo_config_v1.Parameters

let tag_query = Terrat_tag_query.any

(* One configuration: the name [mode] accepts [DEBUG] and [RELEASE], the alias [debug] plans
   with [mode] at [DEBUG], and the alias [ship] applies with force and sets nothing. *)
let config =
  P.make
    ~names:
      (Sln_map.String.of_list
         [ ("mode", P.Parameter.make ~values:(Some [ "DEBUG"; "RELEASE" ]) ()) ])
    ~aliases:
      (Sln_map.String.of_list
         [
           ("debug", { P.Alias.action = `Plan; params = Sln_map.String.singleton "mode" "DEBUG" });
           ("ship", { P.Alias.action = `Apply_force; params = Sln_map.String.empty });
         ])
    ()

(* A configuration whose [mode] accepts no value at all. *)
let config_no_values =
  P.make ~names:(Sln_map.String.of_list [ ("mode", P.Parameter.make ~values:(Some []) ()) ]) ()

let resolve ~config comment = Cr.resolve ~config comment

let plan ?(config = Some config) parameters =
  resolve ~config (Tc.Plan { Tc.parameters; Tc.tag_query })

let alias ?(config = Some config) name = resolve ~config (Tc.Alias { name; tag_query })

let assert_plan ~expected_parameters result =
  match result with
  | Ok (Tjc.Job.Type_.Plan { tag_query = actual_tag_query; kind = None; parameters }) ->
      Oth.Assert.Eq.string
        ~expected:(Terrat_tag_query.to_string tag_query)
        ~actual:(Terrat_tag_query.to_string actual_tag_query);
      let bindings map =
        map |> Sln_map.String.to_list |> CCList.map (fun (name, value) -> name ^ "=" ^ value)
      in
      Oth.Assert.Eq.string_list
        ~expected:(bindings expected_parameters)
        ~actual:(bindings parameters)
  | _ -> Oth.Assert.false_ "expected the plan job"

let assert_reply ~expected ~actual =
  match actual with
  | Error (`Parameter_err (`Undeclared actual_name)) -> (
      match expected with
      | `Undeclared expected_name ->
          Oth.Assert.Eq.string ~expected:expected_name ~actual:actual_name
      | _ -> Oth.Assert.false_ "expected an undeclared parameter reply")
  | Error (`Parameter_err (`Value_not_allowed (actual_name, actual_value, actual_allowed))) -> (
      match expected with
      | `Value_not_allowed (expected_name, expected_value, expected_allowed) ->
          Oth.Assert.Eq.string ~expected:expected_name ~actual:actual_name;
          Oth.Assert.Eq.string ~expected:expected_value ~actual:actual_value;
          Oth.Assert.Eq.string_list ~expected:expected_allowed ~actual:actual_allowed
      | _ -> Oth.Assert.false_ "expected a value-not-allowed reply")
  | Error (`Parameter_err (`Duplicate actual_name)) -> (
      match expected with
      | `Duplicate expected_name -> Oth.Assert.Eq.string ~expected:expected_name ~actual:actual_name
      | _ -> Oth.Assert.false_ "expected a duplicate reply")
  | Error `Unknown_command -> (
      match expected with
      | `Unknown_command -> ()
      | _ -> Oth.Assert.false_ "expected an unknown-command reply")
  | Error `Not_a_run -> (
      match expected with
      | `Not_a_run -> ()
      | _ -> Oth.Assert.false_ "expected a not-a-run reply")
  | Ok _ -> Oth.Assert.false_ "expected a rejection"

let test_needs_config_reads_the_configuration_only_when_it_must =
  Oth.test
    ~name:"needs_config reads the configuration only for an alias and set parameters"
    (fun _ ->
      Oth.Assert.Eq.bool ~expected:false ~actual:(Cr.needs_config Tc.Help);
      Oth.Assert.Eq.bool ~expected:false ~actual:(Cr.needs_config (Tc.Unlock [ "id" ]));
      Oth.Assert.Eq.bool
        ~expected:false
        ~actual:(Cr.needs_config (Tc.Plan { Tc.parameters = []; Tc.tag_query }));
      Oth.Assert.Eq.bool
        ~expected:true
        ~actual:(Cr.needs_config (Tc.Plan { Tc.parameters = [ ("mode", "DEBUG") ]; Tc.tag_query }));
      Oth.Assert.Eq.bool
        ~expected:true
        ~actual:(Cr.needs_config (Tc.Alias { name = "debug"; tag_query }));
      ())

let test_a_plain_plan_runs_when_the_configuration_does_not_decode =
  Oth.test ~name:"A plan without parameters runs against no configuration" (fun _ ->
      assert_plan ~expected_parameters:Sln_map.String.empty (plan ~config:None []))

let test_a_parameterized_plan_starts_the_run =
  Oth.test ~name:"A plan with an accepted parameter starts the run" (fun _ ->
      assert_plan
        ~expected_parameters:(Sln_map.String.singleton "mode" "DEBUG")
        (plan [ ("mode", "DEBUG") ]))

let test_an_alias_expands_into_its_action =
  Oth.test ~name:"A declared alias expands into the job of its action" (fun _ ->
      assert_plan ~expected_parameters:(Sln_map.String.singleton "mode" "DEBUG") (alias "debug");
      match alias "ship" with
      | Ok
          (Tjc.Job.Type_.Apply
             { tag_query = actual_tag_query; kind = None; force = true; parameters })
        when Sln_map.String.is_empty parameters ->
          Oth.Assert.Eq.string
            ~expected:(Terrat_tag_query.to_string tag_query)
            ~actual:(Terrat_tag_query.to_string actual_tag_query)
      | _ -> Oth.Assert.false_ "expected the forced apply job")

let test_an_undeclared_parameter_is_rejected =
  Oth.test ~name:"An undeclared parameter stops the run" (fun _ ->
      assert_reply ~expected:(`Undeclared "nope") ~actual:(plan [ ("nope", "1") ]))

let test_a_value_outside_values_is_rejected =
  Oth.test ~name:"A value outside values stops the run" (fun _ ->
      assert_reply
        ~expected:(`Value_not_allowed ("mode", "NOPE", [ "DEBUG"; "RELEASE" ]))
        ~actual:(plan [ ("mode", "NOPE") ]))

let test_an_absent_values_accepts_any_value =
  Oth.test ~name:"A parameter without values accepts any value" (fun _ ->
      let config =
        P.make ~names:(Sln_map.String.of_list [ ("mode", P.Parameter.make ~values:None ()) ]) ()
      in
      assert_plan
        ~expected_parameters:(Sln_map.String.singleton "mode" "WHATEVER")
        (plan ~config:(Some config) [ ("mode", "WHATEVER") ]))

let test_empty_values_accept_no_value =
  Oth.test ~name:"A parameter whose values is empty accepts no value" (fun _ ->
      assert_reply
        ~expected:(`Value_not_allowed ("mode", "DEBUG", []))
        ~actual:(plan ~config:(Some config_no_values) [ ("mode", "DEBUG") ]))

let test_a_parameter_set_twice_is_rejected =
  Oth.test ~name:"A parameter the comment sets twice stops the run" (fun _ ->
      assert_reply
        ~expected:(`Duplicate "mode")
        ~actual:(plan [ ("mode", "DEBUG"); ("mode", "RELEASE") ]))

let test_apply_autoapprove_is_not_a_run =
  Oth.test ~name:"apply-autoapprove answers not a run" (fun _ ->
      assert_reply
        ~expected:`Not_a_run
        ~actual:
          (resolve
             ~config:(Some config)
             (Tc.Apply_autoapprove { Tc.parameters = []; Tc.tag_query })))

let test_an_unknown_alias_is_an_unknown_command =
  Oth.test ~name:"An alias the configuration does not declare is an unknown command" (fun _ ->
      assert_reply ~expected:`Unknown_command ~actual:(alias "plna"))

let test =
  Oth.parallel
    [
      test_needs_config_reads_the_configuration_only_when_it_must;
      test_a_plain_plan_runs_when_the_configuration_does_not_decode;
      test_a_parameterized_plan_starts_the_run;
      test_an_alias_expands_into_its_action;
      test_an_undeclared_parameter_is_rejected;
      test_a_value_outside_values_is_rejected;
      test_an_absent_values_accepts_any_value;
      test_empty_values_accept_no_value;
      test_a_parameter_set_twice_is_rejected;
      test_apply_autoapprove_is_not_a_run;
      test_an_unknown_alias_is_an_unknown_command;
    ]

let () =
  Random.self_init ();
  Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)
