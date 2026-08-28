module Make
    (S : Terrat_vcs_provider2.S)
    (Keys : module type of Terrat_vcs_event_evaluator2_targets.Make (S)) =
struct
  let src = Logs.Src.create ("vcs_event_evaluator2_access_control." ^ S.name)

  module Logs = (val Logs.src_log src : Logs.LOG)
  module V1 = Terrat_base_repo_config_v1
  module Ace = Keys.Access_control_engine
  module Ac = V1.Access_control
  module P = V1.Access_control.Policy

  let eval_ci_change access_control diff =
    let ci_config_update = access_control.Ace.config.Ac.ci_config_update in
    if access_control.Ace.config.Ac.enabled then
      Abbs_time_it.run
        (fun t ->
          Logs.info (fun m ->
              m "%s : ACCESS_CONTROL_EVAL_CI_CHANGE : time=%f" access_control.Ace.request_id t))
        (fun () ->
          let open Abbs_future_combinators.Infix_result_monad in
          Ace.Access_control.eval_ci_change access_control.Ace.ctx ci_config_update diff
          >>| function
          | true -> None
          | false -> Some ci_config_update)
    else (
      Logs.info (fun m -> m "%s : ACCESS_CONTROL_DISABLED" access_control.Ace.request_id);
      Abbs_future_combinators.return_ok None)

  let eval_files access_control diff =
    let files_policy = access_control.Ace.config.Ac.files in
    if access_control.Ace.config.Ac.enabled then
      Abbs_time_it.run
        (fun t ->
          Logs.info (fun m ->
              m "%s : ACCESS_CONTROL_EVAL_FILES : time=%f" access_control.Ace.request_id t))
        (fun () ->
          let open Abbs_future_combinators.Infix_result_monad in
          Ace.Access_control.eval_files access_control.Ace.ctx files_policy diff
          >>| function
          | `Ok -> None
          | `Denied denied -> Some denied)
    else (
      Logs.info (fun m -> m "%s : ACCESS_CONTROL_DISABLED" access_control.Ace.request_id);
      Abbs_future_combinators.return_ok None)

  let eval_repo_config access_control diff =
    let terrateam_config_update = access_control.Ace.config.Ac.terrateam_config_update in
    if access_control.Ace.config.Ac.enabled then
      Abbs_time_it.run
        (fun t ->
          Logs.info (fun m ->
              m "%s : ACCESS_CONTROL_EVAL_REPO_CONFIG : time=%f" access_control.Ace.request_id t))
        (fun () ->
          let open Abbs_future_combinators.Infix_result_monad in
          Ace.Access_control.eval_repo_config access_control.Ace.ctx terrateam_config_update diff
          >>| function
          | true -> None
          | false -> Some terrateam_config_update)
    else (
      Logs.info (fun m -> m "%s : ACCESS_CONTROL_DISABLED" access_control.Ace.request_id);
      Abbs_future_combinators.return_ok None)

  let eval' access_control change_matches selector =
    if access_control.Ace.config.Ac.enabled then
      let policies =
        (* Policies have been specified, but that doesn't mean the specific
           operation that is being executed has a configuration.  So iterate
           through and pluck out the specific configuration and take the default
           if that configuration was not specified. *)
        access_control.Ace.config.Ac.policies
        |> CCList.map (fun ({ P.tag_query; _ } as p) ->
            Terrat_access_control2.Policy.{ tag_query; policy = selector p })
      in
      Abbs_time_it.run
        (fun t ->
          Logs.info (fun m ->
              m "%s : ACCESS_CONTROL_SUPERAPPROVAL_EVAL : time=%f" access_control.Ace.request_id t))
        (fun () -> Ace.Access_control.eval access_control.Ace.ctx policies change_matches)
    else (
      Logs.info (fun m -> m "%s : ACCESS_CONTROL_DISABLED" access_control.Ace.request_id);
      Abbs_future_combinators.return_ok
        Terrat_access_control2.R.{ pass = change_matches; deny = [] })

  let eval_superapproved access_control reviewers change_matches =
    let open Abbs_future_combinators.Infix_result_monad in
    (* First, let's see if this user can even apply any of the denied changes if
       there is a superapproval. If there isn't, we return the original
       response, otherwise we have to see if any of the changes have super
       approvals. *)
    eval' access_control change_matches (fun { P.apply_with_superapproval; _ } ->
        apply_with_superapproval)
    >>= function
    | { Terrat_access_control2.R.pass = _ :: _ as pass; deny = _ } ->
        (* Now, of those that passed, let's see if any have been approved by a
             super approver.  To do this we'll iterate over the approvers. *)
        let pass_with_superapproval =
          pass
          |> CCList.map (fun ({ Terrat_change_match3.Dirspace_config.dirspace; _ } as ch) ->
              (dirspace, ch))
          |> Terrat_data.Dirspace_map.of_list
        in
        Abbs_future_combinators.List_result.fold_left
          ~f:(fun acc user ->
            let changes = acc |> Terrat_data.Dirspace_map.to_list |> CCList.map snd in
            let ctx = Ace.Access_control.Ctx.set_user user access_control.Ace.ctx in
            let t' = { access_control with Ace.ctx } in
            eval' t' changes (fun { P.superapproval; _ } -> superapproval)
            >>| fun { Terrat_access_control2.R.pass; _ } ->
            let acc =
              CCListLabels.fold_left
                ~f:(fun acc { Terrat_change_match3.Dirspace_config.dirspace; _ } ->
                  Terrat_data.Dirspace_map.remove dirspace acc)
                ~init:acc
                pass
            in
            acc)
          ~init:pass_with_superapproval
          reviewers
        >>| fun unapproved ->
        Terrat_data.Dirspace_map.fold
          (fun k _ acc -> Terrat_data.Dirspace_map.remove k acc)
          unapproved
          pass_with_superapproval
    | _ ->
        Logs.debug (fun m ->
            m
              "%s : ACCESS_CONTROL : NO_MATCHING_CHANGES_FOR_SUPERAPPROVAL"
              access_control.Ace.request_id);
        Abbs_future_combinators.return_ok Terrat_data.Dirspace_map.empty

  let eval_tf_operation access_control matches = function
    | `Plan -> eval' access_control matches (fun { P.plan; _ } -> plan)
    | `Apply reviewers -> (
        let open Abbs_future_combinators.Infix_result_monad in
        eval' access_control matches (fun { P.apply; _ } -> apply)
        >>= function
        | { Terrat_access_control2.R.pass; deny = _ :: _ as deny } ->
            (* If we have some denies, then let's see if any of them can be
                 applied with because of a super approver.  If not, we'll return
                 the original response. *)
            Logs.debug (fun m ->
                m "%s : ACCESS_CONTROL : EVAL_SUPERAPPROVAL" access_control.Ace.request_id);
            let denied_change_matches =
              CCList.map
                (fun { Terrat_access_control2.R.Deny.change_match; _ } -> change_match)
                deny
            in
            eval_superapproved access_control reviewers denied_change_matches
            >>| fun superapproved ->
            let pass =
              pass @ (superapproved |> Terrat_data.Dirspace_map.to_list |> CCList.map snd)
            in
            let deny =
              CCList.filter
                (fun {
                       Terrat_access_control2.R.Deny.change_match =
                         { Terrat_change_match3.Dirspace_config.dirspace; _ };
                       _;
                     }
                   -> not (Terrat_data.Dirspace_map.mem dirspace superapproved))
                deny
            in
            { Terrat_access_control2.R.pass; deny }
        | r -> Abbs_future_combinators.return_ok r)
    | `Apply_force -> eval' access_control matches (fun { P.apply_force; _ } -> apply_force)

  let plan_require_all_dirspace_access access_control =
    access_control.Ace.config.Ac.plan_require_all_dirspace_access

  let apply_require_all_dirspace_access access_control =
    access_control.Ace.config.Ac.apply_require_all_dirspace_access

  let eval_match_list access_control match_list =
    Ace.Access_control.eval_match_list access_control.Ace.ctx match_list
end
