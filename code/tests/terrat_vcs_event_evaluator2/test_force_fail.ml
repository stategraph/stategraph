(* The force-fail rule ([Terrat_vcs_event_evaluator2.Force_fail]).  A run that sets a parameter the
   configuration declares [fail_if_set] counts as failed once its work is done, and every other run
   counts as completed.  The rule is pure, so these cases need no provider. *)

module Ff = Terrat_vcs_event_evaluator2.Force_fail
module V1 = Terrat_base_repo_config_v1

(* [name] says what the case is.  [Oth.Assert.Eq.bool] prints both values when they differ, and the
   name goes on the line before them. *)
let assert_force_fail name expected actual =
  if not (Bool.equal expected actual) then Format.eprintf "%s@." name;
  Oth.Assert.Eq.bool ~expected ~actual

let pp_names fmt = function
  | [] -> Format.pp_print_string fmt "[]"
  | names -> Format.pp_print_string fmt ("[" ^ CCString.concat "; " names ^ "]")

let assert_names name expected actual =
  if not (CCList.equal CCString.equal expected actual) then Format.eprintf "%s@." name;
  Oth.Assert.eq ~eq:(CCList.equal CCString.equal) ~pp:pp_names expected actual

(* Fixtures.  A section declares names only: the rule reads [fail_if_set] and never [values], so
   no fixture needs one. *)
let parameter ~fail_if_set () = V1.Parameters.Parameter.make ~fail_if_set ()
let section names = V1.Parameters.make ~names:(Sln_map.String.of_list names) ()
let parameters bindings = Sln_map.String.of_list bindings

let test_fail_if_set_true_marks_failed =
  Oth.test ~name:"a parameter declared fail_if_set that the run sets marks the run failed" (fun _ ->
      let section = section [ ("mode", parameter ~fail_if_set:true ()) ] in
      let parameters = parameters [ ("mode", "DEBUG") ] in
      assert_names
        "fail_if_set names the set parameter"
        [ "mode" ]
        (Ff.fail_if_set section parameters);
      assert_force_fail "the run is forced to fail" true (Ff.force_fail section parameters))

let test_fail_if_set_false_stays_completed =
  Oth.test
    ~name:"a parameter declared fail_if_set false that the run set keeps the run completed"
    (fun _ ->
      let section = section [ ("mode", parameter ~fail_if_set:false ()) ] in
      let parameters = parameters [ ("mode", "DEBUG") ] in
      assert_names "fail_if_set names nothing" [] (Ff.fail_if_set section parameters);
      assert_force_fail "the run is not forced to fail" false (Ff.force_fail section parameters))

let test_fail_if_set_true_but_other_set =
  Oth.test ~name:"a fail_if_set parameter the run does not set keeps the run completed" (fun _ ->
      let section = section [ ("mode", parameter ~fail_if_set:true ()) ] in
      let parameters = parameters [ ("other", "1") ] in
      assert_names "fail_if_set names nothing" [] (Ff.fail_if_set section parameters);
      assert_force_fail "the run is not forced to fail" false (Ff.force_fail section parameters))

let test_undeclared_name_is_not_fail_if_set =
  Oth.test ~name:"a parameter the section does not declare is not a fail_if_set parameter" (fun _ ->
      let section = section [ ("mode", parameter ~fail_if_set:true ()) ] in
      let parameters = parameters [ ("nope", "1") ] in
      assert_names "fail_if_set names nothing" [] (Ff.fail_if_set section parameters);
      assert_force_fail "the run is not forced to fail" false (Ff.force_fail section parameters))

let test_no_parameter_is_completed =
  Oth.test ~name:"a run that sets no parameter is completed against a fail_if_set section" (fun _ ->
      let section =
        section
          [ ("mode", parameter ~fail_if_set:true ()); ("region", parameter ~fail_if_set:true ()) ]
      in
      let parameters = Sln_map.String.empty in
      assert_names "fail_if_set names nothing" [] (Ff.fail_if_set section parameters);
      assert_force_fail "the run is not forced to fail" false (Ff.force_fail section parameters))

let test_two_fail_if_set_parameters_mark_failed =
  Oth.test ~name:"two fail_if_set parameters the run sets mark the run failed" (fun _ ->
      let section =
        section
          [ ("mode", parameter ~fail_if_set:true ()); ("region", parameter ~fail_if_set:true ()) ]
      in
      let parameters = parameters [ ("mode", "DEBUG"); ("region", "us-east-1") ] in
      assert_names
        "fail_if_set names both set parameters"
        [ "mode"; "region" ]
        (Ff.fail_if_set section parameters);
      assert_force_fail "the run is forced to fail" true (Ff.force_fail section parameters))

let test_names_come_back_in_key_order =
  Oth.test ~name:"fail_if_set answers the names in the map's key order" (fun _ ->
      let section =
        section
          [ ("alpha", parameter ~fail_if_set:true ()); ("zulu", parameter ~fail_if_set:true ()) ]
      in
      let parameters = parameters [ ("zulu", "1"); ("alpha", "2") ] in
      assert_names
        "fail_if_set answers alphabetically"
        [ "alpha"; "zulu" ]
        (Ff.fail_if_set section parameters))

(* The forged result: every dirspace failed, the run failed, and the resource summary kept. *)
let test_force_fail_result_forges_every_dirspace =
  Oth.test ~name:"a forced-failed result reports every dirspace and the run failed" (fun _ ->
      let dirspace dir = { Terrat_change.Dirspace.dir; workspace = "default" } in
      let resource_summary =
        Terrat_vcs_provider2.Resource_summary.
          {
            imported = Some 1;
            created = Some 2;
            updated = Some 0;
            replaced = Some 0;
            deleted = Some 0;
          }
      in
      let result =
        Terrat_vcs_provider2.Work_manifest_result.
          {
            dirspaces_success = [ (dirspace "tf1", true); (dirspace "tf2", true) ];
            dirspaces_resource_summary = [ (dirspace "tf1", resource_summary) ];
            overall_success = true;
            pre_hooks_success = true;
            post_hooks_success = true;
          }
      in
      let forced = Ff.force_fail_result result in
      let module Wmr = Terrat_vcs_provider2.Work_manifest_result in
      Oth.Assert.Eq.bool ~expected:false ~actual:forced.Wmr.overall_success;
      Oth.Assert.Eq.bool_list
        ~expected:[ false; false ]
        ~actual:(CCList.map snd forced.Wmr.dirspaces_success);
      Oth.Assert.List.length
        ~expected:1
        forced.Terrat_vcs_provider2.Work_manifest_result.dirspaces_resource_summary;
      ())

let test =
  Oth.parallel
    [
      test_fail_if_set_true_marks_failed;
      test_fail_if_set_false_stays_completed;
      test_fail_if_set_true_but_other_set;
      test_undeclared_name_is_not_fail_if_set;
      test_no_parameter_is_completed;
      test_two_fail_if_set_parameters_mark_failed;
      test_names_come_back_in_key_order;
      test_force_fail_result_forges_every_dirspace;
    ]

let () =
  Random.self_init ();
  Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)
