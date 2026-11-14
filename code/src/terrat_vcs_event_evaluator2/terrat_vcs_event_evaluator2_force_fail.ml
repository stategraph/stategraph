(* The force-fail rule: whether a configuration set forces a run to count as failed whatever its
   actual result, and which of the run's parameters did it.  No IO and no configuration read, so
   the completion path in the tasks and the result comment share one implementation, and the unit
   test runs without a provider.

   [Sln_map.String.fold] iterates in increasing key order, so the answer is alphabetical and
   stable whatever the comment wrote. *)

let fail_if_set section parameters =
  let module P = Terrat_base_repo_config_v1.Parameters in
  Sln_map.String.fold
    (fun name _ names ->
      match Sln_map.String.find_opt name section.P.names with
      | Some { P.Parameter.fail_if_set = true; values = _ } -> name :: names
      | _ -> names)
    parameters
    []
  |> CCList.rev

let force_fail section parameters = not @@ CCList.is_empty (fail_if_set section parameters)

(* The result the surfaces read.  A forced-failed run reports every dirspace failed and the run
   failed, whatever its steps did: the commit checks, the dirspace summaries and the stored rows
   then take the same path they take for a run that failed.  The resource summary and the hook
   results stay as the run reported them. *)
let force_fail_result (result : Terrat_vcs_provider2.Work_manifest_result.t) =
  let module Wmr = Terrat_vcs_provider2.Work_manifest_result in
  {
    result with
    Wmr.overall_success = false;
    Wmr.dirspaces_success =
      CCList.map (fun (dirspace, _) -> (dirspace, false)) result.Wmr.dirspaces_success;
  }
