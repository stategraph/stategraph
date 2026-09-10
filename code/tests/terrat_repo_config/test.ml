(* Round-trip and validation tests for Engine_stategraph at the schema layer. *)

module E = Terrat_repo_config.Engine
module Sg = Terrat_repo_config.Engine_stategraph
module Spn = Terrat_repo_config.Storage_plan_none
module W = Terrat_repo_config.Workflow_entry

let test_stategraph_minimal_round_trip =
  Oth.test ~name:"Engine_stategraph: minimal round-trip" (fun _ ->
      let json = `Assoc [ ("name", `String "stategraph") ] in
      match Sg.of_yojson json with
      | Ok t ->
          Oth.Assert.true_ "t.Sg.name = `Stategraph" (t.Sg.name = `Stategraph);
          Oth.Assert.none t.Sg.version;
          Oth.Assert.true_
            "Sg.to_yojson t = `Assoc [ (\"name\", `String \"stategraph\") ]"
            (Sg.to_yojson t = `Assoc [ ("name", `String "stategraph") ])
      | Error msg -> failwith msg)

let test_stategraph_with_version_round_trip =
  Oth.test ~name:"Engine_stategraph: with version round-trip" (fun _ ->
      let json = `Assoc [ ("name", `String "stategraph"); ("version", `String "1.2.1") ] in
      match Sg.of_yojson json with
      | Ok t -> (
          Oth.Assert.true_ "t.Sg.name = `Stategraph" (t.Sg.name = `Stategraph);
          Oth.Assert.true_ "t.Sg.version = Some \"1.2.1\"" (t.Sg.version = Some "1.2.1");
          let round_tripped = Sg.to_yojson t in
          match Sg.of_yojson round_tripped with
          | Ok t' -> Oth.Assert.true_ "t'.Sg.version = Some \"1.2.1\"" (t'.Sg.version = Some "1.2.1")
          | Error msg -> failwith msg)
      | Error msg -> failwith msg)

let test_stategraph_rejects_extra_field =
  Oth.test ~name:"Engine_stategraph: extra field rejected (strict=true)" (fun _ ->
      let json =
        `Assoc
          [
            ("name", `String "stategraph");
            ("version", `String "1.2.1");
            ("not_a_real_field", `String "value");
          ]
      in
      match Sg.of_yojson json with
      | Ok _ -> failwith "Expected strict=true to reject extra field, but it was accepted"
      | Error _ -> ())

let test_stategraph_rejects_wrong_name =
  Oth.test ~name:"Engine_stategraph: wrong const name rejected" (fun _ ->
      let json = `Assoc [ ("name", `String "not-stategraph") ] in
      match Sg.of_yojson json with
      | Ok _ -> failwith "Expected mismatched const to reject, but it was accepted"
      | Error _ -> ())

let test_engine_chain_picks_stategraph =
  Oth.test ~name:"Engine: of_yojson chain dispatches to Engine_stategraph" (fun _ ->
      let json = `Assoc [ ("name", `String "stategraph"); ("version", `String "1.2.1") ] in
      match E.of_yojson json with
      | Ok (E.Engine_stategraph t) ->
          Oth.Assert.true_ "t.Sg.name = `Stategraph" (t.Sg.name = `Stategraph);
          Oth.Assert.true_ "t.Sg.version = Some \"1.2.1\"" (t.Sg.version = Some "1.2.1")
      | Ok _ -> failwith "Expected Engine_stategraph variant, got a different engine"
      | Error msg -> failwith msg)

let test_engine_chain_to_yojson_dispatches =
  Oth.test ~name:"Engine: to_yojson on Engine_stategraph emits stategraph JSON" (fun _ ->
      let t = Sg.make ~name:`Stategraph ~version:(Some "1.2.1") () in
      let json = E.to_yojson (E.Engine_stategraph t) in
      Oth.Assert.true_
        "json = `Assoc [ (\"name\", `String \"stategraph\"); (\"version\", `String \"1.2.1\") ]"
        (json = `Assoc [ ("name", `String "stategraph"); ("version", `String "1.2.1") ]))

let test_stategraph_with_tf_fields_round_trip =
  Oth.test ~name:"Engine_stategraph: tf_cmd/tf_version/override_tf_cmd round-trip" (fun _ ->
      let json =
        `Assoc
          [
            ("name", `String "stategraph");
            ("override_tf_cmd", `String "tofu");
            ("tf_cmd", `String "tofu");
            ("tf_version", `String "1.7.0");
          ]
      in
      match Sg.of_yojson json with
      | Ok t ->
          Oth.Assert.true_ "t.Sg.tf_cmd = Some \"tofu\"" (t.Sg.tf_cmd = Some "tofu");
          Oth.Assert.true_ "t.Sg.tf_version = Some \"1.7.0\"" (t.Sg.tf_version = Some "1.7.0");
          Oth.Assert.true_
            "t.Sg.override_tf_cmd = Some \"tofu\""
            (t.Sg.override_tf_cmd = Some "tofu");
          Oth.Assert.true_ "Sg.to_yojson t = json" (Sg.to_yojson t = json)
      | Error msg -> failwith msg)

let test_engine_chain_unknown_falls_to_other =
  Oth.test ~name:"Engine: unknown name falls through to Engine_other" (fun _ ->
      let json = `Assoc [ ("name", `String "definitely-not-an-engine") ] in
      match E.of_yojson json with
      | Ok (E.Engine_other _) -> ()
      | Ok _ -> failwith "Expected Engine_other fallback, got a different engine"
      | Error _ ->
          failwith "Expected Engine_other to accept unknown engine names; got Error instead")

let storage_plan_none_json = `Assoc [ ("method", `String "none") ]

let storage_plan_none_unsafe_json =
  `Assoc [ ("method", `String "none"); ("unsafe_apply_without_plan", `Bool true) ]

let test_storage_plan_none_round_trip =
  Oth.test ~name:"Storage_plan_none: round-trip" (fun _ ->
      match Spn.of_yojson storage_plan_none_json with
      | Ok t ->
          Oth.Assert.true_ "t.Spn.method_ = `None" (t.Spn.method_ = `None);
          Oth.Assert.true_
            "t.Spn.unsafe_apply_without_plan = false"
            (not t.Spn.unsafe_apply_without_plan);
          Oth.Assert.true_
            "Spn.to_yojson t = `Assoc [ (\"method\", `String \"none\") ]"
            (Spn.to_yojson t = storage_plan_none_json)
      | Error msg -> failwith msg)

let test_storage_plan_none_unsafe_round_trip =
  Oth.test ~name:"Storage_plan_none: unsafe_apply_without_plan round-trip" (fun _ ->
      match Spn.of_yojson storage_plan_none_unsafe_json with
      | Ok t ->
          Oth.Assert.true_ "t.Spn.method_ = `None" (t.Spn.method_ = `None);
          Oth.Assert.true_ "t.Spn.unsafe_apply_without_plan = true" t.Spn.unsafe_apply_without_plan;
          Oth.Assert.true_
            "Spn.to_yojson t preserves unsafe_apply_without_plan"
            (Spn.to_yojson t = storage_plan_none_unsafe_json)
      | Error msg -> failwith msg)

let test_workflow_entry_storage_plan_none =
  Oth.test ~name:"Workflow_entry: storage plans method none" (fun _ ->
      let json =
        `Assoc
          [ ("tag_query", `String ""); ("storage", `Assoc [ ("plans", storage_plan_none_json) ]) ]
      in
      match W.of_yojson json with
      | Ok
          {
            W.storage =
              Some
                {
                  W.Storage.plans =
                    Some
                      (W.Storage.Plans.Storage_plan_none
                         {
                           Terrat_repo_config.Storage_plan_none.method_ = `None;
                           unsafe_apply_without_plan = false;
                         });
                };
            _;
          } -> ()
      | Ok _ -> failwith "Expected workflow storage plans method none"
      | Error msg -> failwith msg)

module Ns = Terrat_repo_config.Notifications_summary

let eq_mode expected actual =
  Oth.Assert.eq ~eq:( = ) ~pp:(fun f v -> Format.pp_print_string f (Ns.Mode.show v)) expected actual

(* [enabled] has no default in the schema, so an omitted property stays [None].  That is how the
   Open Source Edition tells a repository that asked for the summary from one that said nothing. *)
let assert_enabled expected actual =
  Oth.Assert.eq
    ~eq:(CCOption.equal CCBool.equal)
    ~pp:(fun f v ->
      Format.pp_print_string
        f
        (match v with
        | Some b -> CCBool.to_string b
        | None -> "unset"))
    expected
    actual

let test_notifications_summary_pull_request_round_trip =
  Oth.test ~name:"Notifications_summary: mode pull_request round-trip" (fun _ ->
      let json = `Assoc [ ("enabled", `Bool true); ("mode", `String "pull_request") ] in
      let t = Oth.Assert.ok (Ns.of_yojson json) in
      assert_enabled (Some true) t.Ns.enabled;
      eq_mode `Pull_request t.Ns.mode;
      let round_tripped = Ns.to_yojson t in
      let t' = Oth.Assert.ok (Ns.of_yojson round_tripped) in
      eq_mode `Pull_request t'.Ns.mode)

let test_notifications_summary_header_round_trip =
  Oth.test ~name:"Notifications_summary: mode header round-trip" (fun _ ->
      let json = `Assoc [ ("enabled", `Bool true); ("mode", `String "header") ] in
      let t = Oth.Assert.ok (Ns.of_yojson json) in
      eq_mode `Header t.Ns.mode;
      let round_tripped = Ns.to_yojson t in
      let t' = Oth.Assert.ok (Ns.of_yojson round_tripped) in
      eq_mode `Header t'.Ns.mode)

let test_notifications_summary_mode_default =
  Oth.test ~name:"Notifications_summary: mode omitted defaults to pull_request" (fun _ ->
      let json = `Assoc [ ("enabled", `Bool true) ] in
      let t = Oth.Assert.ok (Ns.of_yojson json) in
      assert_enabled (Some true) t.Ns.enabled;
      eq_mode `Pull_request t.Ns.mode)

let test_notifications_summary_enabled_unset =
  Oth.test ~name:"Notifications_summary: enabled omitted stays unset" (fun _ ->
      let json = `Assoc [] in
      let t = Oth.Assert.ok (Ns.of_yojson json) in
      assert_enabled None t.Ns.enabled;
      eq_mode `Pull_request t.Ns.mode)

(* An unset [enabled] is written back as no property at all, so a layer of a configuration merge
   does not say something about the summary that its author never wrote. *)
let test_notifications_summary_enabled_unset_round_trip =
  Oth.test ~name:"Notifications_summary: unset enabled emits no property" (fun _ ->
      let t = Oth.Assert.ok (Ns.of_yojson (`Assoc [])) in
      match Ns.to_yojson t with
      | `Assoc kvs ->
          Oth.Assert.not_true
            ~fail_msg:"enabled property is present"
            (CCList.exists (fun (k, _) -> CCString.equal k "enabled") kvs)
      | _ -> Oth.Assert.false_ "Expected an object")

let test_notifications_summary_rejects_unknown_mode =
  Oth.test ~name:"Notifications_summary: unknown mode rejected" (fun _ ->
      let json = `Assoc [ ("enabled", `Bool true); ("mode", `String "sidebar") ] in
      match Ns.of_yojson json with
      | Ok _ -> failwith "Expected unknown mode to be rejected, but it was accepted"
      | Error _ -> ())

let test =
  Oth.parallel
    [
      test_stategraph_minimal_round_trip;
      test_stategraph_with_version_round_trip;
      test_stategraph_rejects_extra_field;
      test_stategraph_rejects_wrong_name;
      test_engine_chain_picks_stategraph;
      test_engine_chain_to_yojson_dispatches;
      test_stategraph_with_tf_fields_round_trip;
      test_engine_chain_unknown_falls_to_other;
      test_storage_plan_none_round_trip;
      test_storage_plan_none_unsafe_round_trip;
      test_workflow_entry_storage_plan_none;
      test_notifications_summary_pull_request_round_trip;
      test_notifications_summary_header_round_trip;
      test_notifications_summary_mode_default;
      test_notifications_summary_enabled_unset;
      test_notifications_summary_enabled_unset_round_trip;
      test_notifications_summary_rejects_unknown_mode;
    ]

let () =
  Random.self_init ();
  Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)
