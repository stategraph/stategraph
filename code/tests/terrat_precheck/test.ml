module P = Terrat_precheck
module Fp = Terrat_base_repo_config_v1.File_pattern

let fps patterns =
  CCList.map
    (fun p -> CCResult.get_exn (CCResult.map_err (fun _ -> Failure ("bad glob " ^ p)) (Fp.make p)))
    patterns

(* --- user ------------------------------------------------------------------------------------ *)

let test_user_only_negations_has_implicit_star =
  Oth.test ~name:"user: a list of negations only carries an implicit star" (fun _ ->
      let users = [ "!user02" ] in
      Oth.Assert.not_true ~fail_msg:"user02 is refused" (P.match_user ~users (Some "user02"));
      Oth.Assert.true_ ~fail_msg:"user01 is permitted" (P.match_user ~users (Some "user01"));
      ())

let test_user_mixed_list_has_no_implicit_star =
  Oth.test ~name:"user: a mixed list carries no implicit star" (fun _ ->
      let users = [ "user01"; "!user02" ] in
      Oth.Assert.true_
        ~fail_msg:"user01 matches a positive entry"
        (P.match_user ~users (Some "user01"));
      Oth.Assert.not_true ~fail_msg:"user02 is refused" (P.match_user ~users (Some "user02"));
      Oth.Assert.not_true
        ~fail_msg:"a third identity matches no positive entry"
        (P.match_user ~users (Some "someone_else"));
      ())

let test_user_empty_list_matches_nothing =
  Oth.test ~name:"user: an empty list matches nothing" (fun _ ->
      Oth.Assert.not_true (P.match_user ~users:[] (Some "user01"));
      ())

(* A check that cannot read the identity must not stop the work. *)
let test_user_absent_user_permits =
  Oth.test ~name:"user: an absent user gives true" (fun _ ->
      Oth.Assert.true_ (P.match_user ~users:[ "!user02" ] None);
      Oth.Assert.true_ (P.match_user ~users:[ "user01" ] None);
      ())

(* --- file patterns --------------------------------------------------------------------------- *)

let test_file_patterns_only_negations_has_implicit_star =
  Oth.test ~name:"file_patterns: a list of negations only carries an implicit star" (fun _ ->
      let file_patterns = fps [ "!docs/**" ] in
      Oth.Assert.not_true
        ~fail_msg:"a change under docs is refused"
        (P.match_file_patterns file_patterns ~files:[ "docs/readme.md" ]);
      Oth.Assert.true_
        ~fail_msg:"a change outside docs is permitted"
        (P.match_file_patterns file_patterns ~files:[ "infra/main.tf" ]);
      ())

let test_file_patterns_mixed_list_has_no_implicit_star =
  Oth.test ~name:"file_patterns: a mixed list carries no implicit star" (fun _ ->
      let file_patterns = fps [ "infra/**"; "!docs/**" ] in
      Oth.Assert.true_
        ~fail_msg:"a change under infra matches the positive pattern"
        (P.match_file_patterns file_patterns ~files:[ "infra/main.tf" ]);
      Oth.Assert.not_true
        ~fail_msg:"a change under app matches no positive pattern"
        (P.match_file_patterns file_patterns ~files:[ "app/main.tf" ]);
      Oth.Assert.not_true
        ~fail_msg:"a change under docs is refused"
        (P.match_file_patterns file_patterns ~files:[ "docs/readme.md" ]);
      ())

(* One file that matches is enough, because the check asks if the pull request is worth any work. *)
let test_file_patterns_any_file_matches =
  Oth.test ~name:"file_patterns: one file that matches is enough" (fun _ ->
      let file_patterns = fps [ "infra/**" ] in
      Oth.Assert.true_
        (P.match_file_patterns file_patterns ~files:[ "app/main.tf"; "infra/main.tf" ]);
      ())

let test_file_patterns_empty_list_matches_nothing =
  Oth.test ~name:"file_patterns: an empty list matches nothing" (fun _ ->
      Oth.Assert.not_true (P.match_file_patterns [] ~files:[ "infra/main.tf" ]);
      ())

let test_file_patterns_no_files_matches_nothing =
  Oth.test ~name:"file_patterns: no changed file matches nothing" (fun _ ->
      Oth.Assert.not_true (P.match_file_patterns (fps [ "infra/**" ]) ~files:[]);
      ())

(* A precheck glob is a repository path, thus it carries no [${DIR}] prefix and a leading [**]
   crosses a [/]. *)
let test_file_patterns_globs_are_repo_paths =
  Oth.test ~name:"file_patterns: a glob is a repository path" (fun _ ->
      Oth.Assert.true_
        (P.match_file_patterns (fps [ "infra/**/*.tf" ]) ~files:[ "infra/a/b/main.tf" ]);
      Oth.Assert.not_true (P.match_file_patterns (fps [ "infra/**/*.tf" ]) ~files:[ "app/main.tf" ]);
      ())

(* --- the configuration file ------------------------------------------------------------------ *)

let test_changes_repo_config =
  Oth.test ~name:"changes_repo_config: every name of the configuration file" (fun _ ->
      Oth.Assert.List.all
        ~pp:Format.pp_print_string
        (fun path -> P.changes_repo_config [ "infra/main.tf"; path ])
        [
          ".stategraph/config.yml";
          ".stategraph/config.yaml";
          ".terrateam/config.yml";
          ".terrateam/config.yaml";
        ];
      ())

let test_changes_repo_config_other_files =
  Oth.test ~name:"changes_repo_config: another file is not the configuration" (fun _ ->
      Oth.Assert.not_true (P.changes_repo_config [ "infra/main.tf"; "docs/readme.md" ]);
      Oth.Assert.not_true (P.changes_repo_config [ ".terrateam/other.yml" ]);
      Oth.Assert.not_true (P.changes_repo_config []);
      ())

(* --- the derived configuration ---------------------------------------------------------------- *)

(* Build the JSON exactly as the evaluator stores it: derive a raw configuration over a file list,
   then [to_version_1 |> to_yojson].  A hand-written [{"dirs": {"infra": {}}}] would not do -- the
   stored copy has the dirs already expanded and the [${DIR}] of every glob already substituted, and
   that is the whole reason the check needs no tree of its own. *)
let derived_json ~file_list raw_json =
  let module V1 = Terrat_base_repo_config_v1 in
  let config =
    Oth.Assert.ok_show ~show:V1.show_of_version_1_json_err (V1.of_version_1_json raw_json)
  in
  V1.derive
    ~ctx:(V1.Ctx.make ~dest_branch:"main" ~branch:"feature" ())
    ~index:V1.Index.empty
    ~file_list
    config
  |> Oth.Assert.ok_show ~show:V1.show_derive_err
  |> V1.to_version_1
  |> Terrat_repo_config.Version_1.to_yojson

let changed filename = [ Terrat_change.Diff.Change { filename } ]

(* The config builder of the destination branch wrote a dir for [infra] only, and the destination
   branch holds no other Terraform, thus [derive] adds none of its own. *)
let infra_only_json =
  derived_json ~file_list:[ "infra/main.tf" ] (`Assoc [ ("dirs", `Assoc [ ("infra", `Assoc []) ]) ])

let test_derived_config_no_match =
  Oth.test ~name:"match_derived_config: a change outside every dir gives false" (fun _ ->
      Oth.Assert.Eq.bool
        ~expected:false
        ~actual:
          (Oth.Assert.some
             ~fail_msg:"Expected the configuration to parse"
             (P.match_derived_config ~diff:(changed "app/main.tf") infra_only_json));
      ())

let test_derived_config_match =
  Oth.test ~name:"match_derived_config: a change inside a dir gives true" (fun _ ->
      Oth.Assert.Eq.bool
        ~expected:true
        ~actual:
          (Oth.Assert.some
             ~fail_msg:"Expected the configuration to parse"
             (P.match_derived_config ~diff:(changed "infra/main.tf") infra_only_json));
      ())

(* A dir that [derive] found by itself is in the stored configuration too, thus it matches.  This is
   why a fixture that wants a dir to match nothing must keep that dir off the destination branch. *)
let test_derived_config_matches_an_auto_detected_dir =
  Oth.test ~name:"match_derived_config: a dir that derive found by itself still matches" (fun _ ->
      let json =
        derived_json
          ~file_list:[ "infra/main.tf"; "app/main.tf" ]
          (`Assoc [ ("dirs", `Assoc [ ("infra", `Assoc []) ]) ])
      in
      Oth.Assert.Eq.bool
        ~expected:true
        ~actual:
          (Oth.Assert.some
             ~fail_msg:"Expected the configuration to parse"
             (P.match_derived_config ~diff:(changed "app/main.tf") json));
      ())

(* The stored copy is a cache.  A cache that cannot be read decides nothing. *)
let test_derived_config_unreadable =
  Oth.test ~name:"match_derived_config: a configuration that does not parse gives None" (fun _ ->
      Oth.Assert.none (P.match_derived_config ~diff:(changed "infra/main.tf") (`String "nonsense"));
      ())

let test =
  Oth.parallel
    [
      test_user_only_negations_has_implicit_star;
      test_user_mixed_list_has_no_implicit_star;
      test_user_empty_list_matches_nothing;
      test_user_absent_user_permits;
      test_file_patterns_only_negations_has_implicit_star;
      test_file_patterns_mixed_list_has_no_implicit_star;
      test_file_patterns_any_file_matches;
      test_file_patterns_empty_list_matches_nothing;
      test_file_patterns_no_files_matches_nothing;
      test_file_patterns_globs_are_repo_paths;
      test_changes_repo_config;
      test_changes_repo_config_other_files;
      test_derived_config_no_match;
      test_derived_config_match;
      test_derived_config_matches_an_auto_detected_dir;
      test_derived_config_unreadable;
    ]

let () =
  Random.self_init ();
  Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)
