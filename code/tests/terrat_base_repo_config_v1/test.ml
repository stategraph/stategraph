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

let test =
  Oth.parallel
    [
      test_of_version_1_json_minimal;
      test_of_version_1_json_with_version;
      test_to_version_1_round_trip;
    ]

let () =
  Random.self_init ();
  Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)
