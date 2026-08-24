(* The repo-config-change predicate gates the
   access_control.terrateam_config_update policy: a filename it misses is a
   file that fully determines the run's config (hooks, workflows -- arbitrary
   commands with the repo's credentials) without passing that policy. Since
   #1592 the providers read .stategraph/config in preference to
   .terrateam/config, so BOTH spellings, in both extensions, must count. *)

let test_add_change_remove_each_config_file =
  Oth.test ~name:"add/change/remove of every config spelling is a repo config change" (fun _ ->
      Oth.Assert.List.all_true
        ~pp:Format.pp_print_string
        (fun filename ->
          CCList.for_all
            (fun diff ->
              Terrat_access_control2.Tests.is_repo_config_change
                [ Terrat_change.Diff.Add { filename = "unrelated.tf" }; diff ])
            Terrat_change.Diff.[ Add { filename }; Change { filename }; Remove { filename } ])
        Terrat_access_control2.Tests.repo_config_files)

let test_move_to_and_from_config_file =
  Oth.test ~name:"a move whose either side is a config file is a repo config change" (fun _ ->
      Oth.Assert.List.all_true
        ~pp:Format.pp_print_string
        (fun filename ->
          Terrat_access_control2.Tests.is_repo_config_change
            [ Terrat_change.Diff.Move { filename; previous_filename = "old.yml" } ]
          && Terrat_access_control2.Tests.is_repo_config_change
               [ Terrat_change.Diff.Move { filename = "new.yml"; previous_filename = filename } ])
        Terrat_access_control2.Tests.repo_config_files)

(* The other tests iterate over the exported list itself, so they cannot
   notice a NAME REMOVED from it -- and a missing name is exactly the bug the
   suite exists to prevent. This is the one place the names are spelled out:
   as the expectation, not as a fixture. *)
let test_list_covers_both_spellings_and_extensions =
  Oth.test ~name:"the matcher list covers both spellings in both extensions" (fun _ ->
      Oth.Assert.Eq.string_list
        ~expected:
          [
            ".stategraph/config.yaml";
            ".stategraph/config.yml";
            ".terrateam/config.yaml";
            ".terrateam/config.yml";
          ]
        ~actual:(Sln_list.String.sort Terrat_access_control2.Tests.repo_config_files))

let test_unrelated_changes_do_not_count =
  Oth.test ~name:"unrelated files (and near-misses) are not repo config changes" (fun _ ->
      Oth.Assert.not_true
        "near-misses misdetected as a repo config change"
        (Terrat_access_control2.Tests.is_repo_config_change
           Terrat_change.Diff.
             [
               Add { filename = "main.tf" };
               Change { filename = "docs/.terrateam/config.yml" };
               Remove { filename = ".terrateam/config.yml.bak" };
               Add { filename = ".stategraph/refactor.json" };
             ]))

let test =
  Oth.parallel
    [
      test_add_change_remove_each_config_file;
      test_move_to_and_from_config_file;
      test_list_covers_both_spellings_and_extensions;
      test_unrelated_changes_do_not_count;
    ]

let () = Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)
