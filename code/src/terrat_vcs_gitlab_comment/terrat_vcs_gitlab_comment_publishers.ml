let src = Logs.Src.create "vcs_gitlab_comment_publishers"

module Logs = (val Logs.src_log src : Logs.LOG)
module Api = Terrat_vcs_api_gitlab
module Scope = Terrat_scope.Scope
module Tmpl = Terrat_vcs_gitlab_comment_templates.Tmpl
module Ui = Terrat_vcs_gitlab_comment_ui.Ui
module Visible_on = Terrat_base_repo_config_v1.Workflow_step.Visible_on

(* How much of a FAILING step's output to keep when a comment has to shrink. Terraform and its
   providers emit the error at the END of the output, so the tail is the part worth keeping. *)
let failing_output_budget = 4000

let tail_of ~max_bytes s =
  if CCString.length s <= max_bytes then s
  else
    let cut = CCString.length s - max_bytes in
    (* Resume at a line boundary so the kept text does not start mid-line. *)
    let start =
      match CCString.find ~start:cut ~sub:"\n" s with
      | -1 -> cut
      | i -> i + 1
    in
    "[... earlier output trimmed to fit the comment ...]\n"
    ^ CCString.sub s start (CCString.length s - start)

module Output = struct
  type t = {
    cmd : string option;
    name : string;
    raw : bool;
    (* False once compaction has taken this step's output away. The template renders a placeholder
       instead of [text]. *)
    show_output : bool;
    success : bool;
    text : string;
    text_decorator : string option;
    visible_on : Visible_on.t;
  }

  let make ?cmd ?text_decorator ?(raw = false) ~name ~success ~text ~visible_on () =
    (* If name looks like <namespace>/<action> then remove the namespace *)
    let name = CCOption.map_or ~default:name snd (CCString.Split.right ~by:"/" name) in
    { cmd; name; raw; show_output = true; success; text; text_decorator; visible_on }

  let to_kv { cmd; name; raw; show_output; success; text; text_decorator; visible_on = _ } =
    `Assoc
      (CCList.flatten
         [
           [
             ("name", `String name);
             ("text", `String text);
             ("show_output", `Bool show_output);
             ("success", `Bool success);
             ("raw", `Bool raw);
             ("text_decorator", `String (CCOption.get_or ~default:"" text_decorator));
           ];
           CCOption.map_or ~default:[] (fun cmd -> [ ("cmd", `String cmd) ]) cmd;
         ])

  (* Compaction in priority order. A comment that is too long has to lose something, and the last
     thing it should lose is the output saying why the run failed -- dropping every step's output
     wholesale is what made a 403 from a provider unreadable (#1540).

     A succeeding step's output is confirmation, not information, so it goes first. A failing step
     keeps its output, trimmed to the tail. *)
  let compact outputs =
    CCList.map
      (fun ({
              cmd = _;
              name = _;
              raw = _;
              show_output = _;
              success;
              text;
              text_decorator = _;
              visible_on = _;
            } as o)
         ->
        if success then { o with show_output = false; text = "" }
        else { o with text = tail_of ~max_bytes:failing_output_budget text })
      outputs

  let filter ~overall_success =
    CCList.filter (fun { visible_on; _ } ->
        visible_on = Visible_on.Always
        || (overall_success && visible_on = Visible_on.Success)
        || ((not overall_success) && visible_on = Visible_on.Failure))
end

let steps_has_changes steps =
  let module P = struct
    type t = { has_changes : bool [@default false] } [@@deriving of_yojson { strict = false }]
  end in
  let module O = Terrat_api_components.Workflow_step_output in
  match
    CCList.find_map
      (function
        | {
            O.step = "tf/plan" | "pulumi/plan" | "custom/plan" | "fly/plan" | "stategraph/plan";
            payload;
            success = _;
            _;
          } -> (
            match P.of_yojson (O.Payload.to_yojson payload) with
            | Ok { P.has_changes } -> Some has_changes
            | _ -> None)
        | _ -> None)
      steps
  with
  | Some has_changes -> has_changes
  | None -> false

(* Resource counts reported by the runner in the plan step's [resource_summary] payload,
   computed from `terraform show -json`.  When the runner or engine does not emit them the
   fields are None (rendered as "-") rather than guessed (#1929). *)
module Rs = Terrat_vcs_provider2.Resource_summary

let steps_success steps =
  let module O = Terrat_api_components.Workflow_step_output in
  CCList.for_all (fun { O.success; ignore_errors; _ } -> success || ignore_errors) steps

let kv_of_cost_estimation changed_dirspaces output =
  let module P = struct
    module S = struct
      type t = {
        prev_monthly_cost : float;
        total_monthly_cost : float;
        diff_monthly_cost : float;
      }
      [@@deriving of_yojson { strict = false }]
    end

    module Ds = struct
      type t = {
        dir : string;
        workspace : string;
        prev_monthly_cost : float;
        total_monthly_cost : float;
        diff_monthly_cost : float;
      }
      [@@deriving yojson { strict = false }]
    end

    type t = {
      summary : S.t;
      dirspaces : Ds.t list;
      currency : string;
    }
    [@@deriving of_yojson { strict = false }]
  end in
  let module O = Terrat_api_components.Workflow_step_output in
  if output.O.success then
    let open CCResult.Infix in
    P.of_yojson (O.Payload.to_yojson output.O.payload)
    >>= fun payload ->
    let summary = payload.P.summary in
    let changed_dirspaces = Terrat_data.Dirspace_set.of_list changed_dirspaces in
    Ok
      (`Assoc
         [
           ("name", `String "cost_estimation");
           ("success", `Bool output.O.success);
           ("prev_monthly_cost", `Float summary.P.S.prev_monthly_cost);
           ("total_monthly_cost", `Float summary.P.S.total_monthly_cost);
           ("diff_monthly_cost", `Float summary.P.S.diff_monthly_cost);
           ("currency", `String payload.P.currency);
           ( "dirspaces",
             `List
               (CCList.filter_map
                  (fun {
                         P.Ds.dir;
                         workspace;
                         total_monthly_cost;
                         prev_monthly_cost;
                         diff_monthly_cost;
                       }
                     ->
                    if
                      Terrat_data.Dirspace_set.mem
                        { Terrat_dirspace.dir; workspace }
                        changed_dirspaces
                    then
                      Some
                        (`Assoc
                           [
                             ("dir", `String dir);
                             ("workspace", `String workspace);
                             ("prev_monthly_cost", `Float prev_monthly_cost);
                             ("total_monthly_cost", `Float total_monthly_cost);
                             ("diff_monthly_cost", `Float diff_monthly_cost);
                           ])
                    else None)
                  payload.P.dirspaces) );
         ])
  else
    let module P = struct
      type t = { text : string } [@@deriving of_yojson { strict = false }]
    end in
    let open CCResult.Infix in
    P.of_yojson (O.Payload.to_yojson output.O.payload)
    >>= fun { P.text } ->
    Ok (`Assoc [ ("success", `Bool output.O.success); ("text", `String text) ])

(* [visible_on] as the runner writes it into a step payload. A step that sends no value at all
   keeps the step's own default: [output_of_raw] is for a payload that cannot be read, not for one
   that is simply quiet about visibility. A word neither side knows hides the step unless it
   fails, which is the safe way to be wrong. *)
let visible_on_of_payload ~default = function
  | None -> default
  | Some visible_on -> CCOption.get_or ~default:Visible_on.Failure (Visible_on.of_string visible_on)

let output_of_run ?(default_visible_on = Visible_on.Failure) output =
  let module P = struct
    type t = {
      cmd : string list option; [@default None]
      format : Yojson.Safe.t option; [@default None]
      text : string option; [@default None]
      visible_on : string option; [@default None]
    }
    [@@deriving of_yojson { strict = false }]
  end in
  let module O = Terrat_api_components.Workflow_step_output in
  let open CCResult.Infix in
  P.of_yojson (O.Payload.to_yojson output.O.payload)
  >>= fun { P.cmd; format; text; visible_on } ->
  let text_decorator, raw =
    match format with
    | None | Some (`String "code") -> (None, false)
    | Some (`String "raw") | Some (`String "markdown") -> (None, true)
    | Some (`Assoc fields) -> (
        match CCList.assoc_opt ~eq:CCString.equal "lang" fields with
        | Some (`String lang) -> (Some lang, false)
        | _ -> (None, false))
    | Some _ -> (None, false)
  in
  Ok
    (Output.make
       ?cmd:(CCOption.map (CCString.concat " ") cmd)
       ?text_decorator
       ~raw
       ~name:output.O.step
       ~success:output.O.success
       ~text:(CCOption.get_or ~default:"" text)
       ~visible_on:(visible_on_of_payload ~default:default_visible_on visible_on)
       ())

let output_of_plan ?(default_visible_on = Visible_on.Always) output =
  let module P = struct
    type t = {
      cmd : string list option; [@default None]
      text : string;
      plan : string option; [@default None]
      has_changes : bool option; [@default None]
      visible_on : string option; [@default None]
    }
    [@@deriving of_yojson { strict = false }]
  end in
  let module O = Terrat_api_components.Workflow_step_output in
  let open CCResult.Infix in
  P.of_yojson (O.Payload.to_yojson output.O.payload)
  >>= fun { P.cmd; text; has_changes = _; plan; visible_on } ->
  let visible_on = visible_on_of_payload ~default:default_visible_on visible_on in
  (* An engine with no diff of its own -- stategraph and pulumi both return [None] -- still sends
     the [plan] key, empty. An empty diff fence says nothing, so the command's own output is what
     is left worth showing, and it is not a diff. *)
  let text, text_decorator =
    match plan with
    | Some plan when not (CCString.is_empty plan) -> (plan, Some "diff")
    | Some _ | None -> (text, None)
  in
  if output.O.success then
    Ok
      (Output.make
         ?cmd:(CCOption.map (CCString.concat " ") cmd)
         ?text_decorator
         ~name:output.O.step
         ~success:output.O.success
         ~text
         ~visible_on
         ())
  else
    Ok
      (Output.make
         ?cmd:(CCOption.map (CCString.concat " ") cmd)
         ~name:output.O.step
         ~success:output.O.success
         ~text
         ~visible_on
         ())

let output_of_workflow_output output =
  let module O = Terrat_api_components.Workflow_step_output in
  match output.O.step with
  | "run" | "env" -> output_of_run output
  | "tf/init" | "pulumi/init" | "custom/init" | "fly/init" | "stategraph/init" ->
      output_of_run ~default_visible_on:Visible_on.Failure output
  | "tf/apply" | "pulumi/apply" | "custom/apply" | "fly/apply" | "stategraph/apply" ->
      output_of_run ~default_visible_on:Visible_on.Always output
  | "tf/plan" | "pulumi/plan" | "custom/plan" | "fly/plan" | "stategraph/plan" ->
      output_of_plan ~default_visible_on:Visible_on.Always output
  | _step -> output_of_run output

let output_of_raw output =
  let module O = Terrat_api_components.Workflow_step_output in
  let { O.step; success; payload; _ } = output in
  Output.make
    ~name:step
    ~success
    ~text:(Yojson.Safe.pretty_to_string (O.Payload.to_yojson payload))
    ~visible_on:Visible_on.Failure
    ()

let output_of_steps steps =
  let module O = Terrat_api_components.Workflow_step_output in
  CCList.filter_map
    (fun output ->
      match output.O.step with
      | "tf/cost-estimation" -> None
      | _ -> (
          match output_of_workflow_output output with
          | Ok output -> Some output
          | Error _ -> Some (output_of_raw output)))
    steps

let kv_of_outputs outputs = CCList.map Output.to_kv outputs

(* The template input for one section of a comment: the steps that [visible_on] keeps, trimmed when
   the section is compacted. *)
let steps_kv ~overall_success ~compact steps =
  let outputs = steps |> output_of_steps |> Output.filter ~overall_success in
  kv_of_outputs (if compact then Output.compact outputs else outputs)

let dirspace_compare (dirspace1, steps1) (dirspace2, steps2) =
  let module Cmp = struct
    type t = bool * bool * Terrat_dirspace.t [@@deriving ord]
  end in
  let has_changes1 = steps_has_changes steps1 in
  let success1 = steps_success steps1 in
  let has_changes2 = steps_has_changes steps2 in
  let success2 = steps_success steps2 in
  (* The same order the unified summary comment renders its table in: failed
     first, then successes with changes before successes without, then
     dirspace.  [success] is [false] before [true] and [not has_changes] puts
     changes first, so the key is exactly that order -- the two tables must
     not disagree about it. *)
  Cmp.compare (success1, not has_changes1, dirspace1) (success2, not has_changes2, dirspace2)

module Comment_api = struct
  (* The comment is how a failure reaches the user, so a call the VCS never
     answered while commenting cannot be told apart for them.  It is reported
     the same as every other comment failure. *)
  let comment_on_pull_request ~request_id client pull_request _msg_type body =
    let open Abb.Future.Infix_monad in
    Api.comment_on_pull_request ~request_id client pull_request body
    >>= function
    | Ok comment_id -> Abbs_future_combinators.return_ok comment_id
    | Error (`Error | `Vcs_api_timeout_err _) -> Abbs_future_combinators.return_err `Error

  let apply_template_and_publish ~request_id client pull_request msg_type template kv =
    Logs.info (fun m -> m "%s : PUBLISH : %s" request_id msg_type);
    match Snabela.apply template kv with
    | Ok body ->
        Abbs_future_combinators.Result.ignore
        @@ comment_on_pull_request ~request_id client pull_request msg_type body
    | Error (#Snabela.err as err) ->
        Logs.err (fun m -> m "%s : TEMPLATE_ERROR : %a" request_id Snabela.pp_err err);
        Abbs_future_combinators.return_err `Error

  let apply_template_and_publish_jinja ~request_id client pull_request msg_type template kv =
    Logs.info (fun m -> m "%s : PUBLISH : %s" request_id msg_type);
    match Minijinja.render_template template kv with
    | Ok body -> comment_on_pull_request ~request_id client pull_request msg_type body
    | Error err ->
        Logs.err (fun m -> m "%s : TEMPLATE_ERROR : %s" request_id err);
        Abbs_future_combinators.return_err `Error
end

module Publisher_tools = struct
  let create_run_output
      ~brand
      ~view
      ~compacted_dirspaces
      ~summary
      ~pull_number
      ~dirspace_run_urls
      request_id
      account_status
      tier_runs
      config
      is_layered_run
      num_remaining_layers
      by_scope
      gates
      work_manifest =
    let module Wm = Terrat_work_manifest3 in
    let module O = Terrat_api_components.Workflow_step_output in
    (* Per-dirspace, so one oversized plan diff cannot blank the error text on every OTHER dirspace
       in the same comment (#1540). *)
    let is_compacted dirspace =
      CCList.exists (fun d -> Terrat_dirspace.compare d dirspace = 0) compacted_dirspaces
    in
    let hooks_pre =
      CCList.Assoc.get ~eq:Scope.equal (Scope.Run { flow = "hooks"; subflow = "pre" }) by_scope
    in
    let hooks_post =
      CCList.Assoc.get ~eq:Scope.equal (Scope.Run { flow = "hooks"; subflow = "post" }) by_scope
    in
    let dirspaces =
      by_scope
      |> CCList.filter_map (function
        | Scope.Dirspace dirspace, steps -> Some (dirspace, steps)
        | _ -> None)
      |> CCList.sort dirspace_compare
    in
    let overall_success =
      CCList.for_all
        (fun (_, steps) ->
          CCList.for_all (fun { O.success; ignore_errors; _ } -> success || ignore_errors) steps)
        by_scope
    in
    (* Resource counts per dirspace, plus totals over the dirspaces that reported them.  All
       "-" when no dirspace's runner emitted a summary (#1929). *)
    let resource_totals =
      let { Rs.created; deleted; replaced; updated } =
        Rs.total (CCList.map (fun (_, steps) -> Rs.of_steps_or_none steps) dirspaces)
      in
      `Assoc
        [
          ("created", `String (Rs.count_str created));
          ("updated", `String (Rs.count_str updated));
          ("replaced", `String (Rs.count_str replaced));
          ("deleted", `String (Rs.count_str deleted));
        ]
    in
    let denied_dirspaces =
      match work_manifest.Wm.denied_dirspaces with
      | [] -> [ ("denied_dirspaces", `List []) ]
      | dirspaces ->
          [
            ( "denied_dirspaces",
              `List
                (CCList.map
                   (fun { Wm.Deny.dirspace = { Terrat_dirspace.dir; workspace }; policy } ->
                     `Assoc
                       (CCList.flatten
                          [
                            [ ("dir", `String dir); ("workspace", `String workspace) ];
                            (match policy with
                            | Some policy ->
                                [
                                  ( "policy",
                                    `List
                                      (CCList.map
                                         (fun p ->
                                           `Assoc
                                             [
                                               ( "item",
                                                 `String
                                                   (Terrat_base_repo_config_v1.Access_control.Match
                                                    .to_string
                                                      p) );
                                             ])
                                         policy) );
                                ]
                            | None -> []);
                          ]))
                   dirspaces) );
          ]
    in
    let cost_estimation =
      hooks_pre
      |> CCOption.get_or ~default:[]
      |> CCList.filter (fun { O.step; _ } -> CCString.equal step "tf/cost-estimation")
      |> function
      | [] -> []
      | o :: _ -> (
          let changed_dirspaces =
            CCList.map
              (fun { Terrat_change.Dirspaceflow.dirspace; _ } -> dirspace)
              work_manifest.Wm.changes
          in
          match kv_of_cost_estimation changed_dirspaces o with
          | Ok kv -> [ ("cost_estimation", kv) ]
          | Error _ -> [ ("cost_estimation", Output.to_kv (output_of_raw o)) ])
    in
    let kv =
      `Assoc
        (CCList.flatten
           [
             CCOption.map_or
               ~default:[]
               (fun work_manifest_url ->
                 [ ("work_manifest_url", `String (Uri.to_string work_manifest_url)) ])
               (Ui.work_manifest_url config work_manifest.Wm.account pull_number work_manifest);
             CCOption.map_or
               ~default:[]
               (fun env -> [ ("environment", `String env) ])
               work_manifest.Wm.environment;
             CCOption.map_or
               ~default:[]
               (fun { Terrat_tier.Check.used; limit } ->
                 [ ("runs_used", `Int used); ("runs_limit", `Int limit) ])
               tier_runs;
             [
               ( "account_status",
                 `String
                   (match account_status with
                   | `Trial_ending duration when Duration.to_day duration < 15 ->
                       (* Only mark as trial ending if less than two weeks from now *)
                       "trial_ending"
                   | `Trial_ending _ | `Active -> "active"
                   | `Expired -> "expired"
                   | `Disabled -> "disabled") );
               ( "trial_end_days",
                 match account_status with
                 | `Trial_ending duration -> `Int (Duration.to_day duration)
                 | _ -> `Int 0 );
               ("is_layered_run", `Bool is_layered_run);
               ("num_more_layers", `Int num_remaining_layers);
               ("overall_success", `Bool overall_success);
               ( "pre_hooks",
                 `List
                   (hooks_pre
                   |> CCOption.get_or ~default:[]
                   |> steps_kv ~overall_success ~compact:(view = `Compact)) );
               ( "post_hooks",
                 `List
                   (hooks_post
                   |> CCOption.get_or ~default:[]
                   |> steps_kv ~overall_success ~compact:(view = `Compact)) );
               ("compact_view", `Bool (view = `Compact));
               ("compact_dirspaces", `Bool (CCList.length dirspaces > 5));
               ("summary", `Bool summary);
               ("resource_totals", resource_totals);
               ( "dirspaces",
                 `List
                   (CCList.map
                      (fun (({ Terrat_dirspace.dir; workspace } as dirspace), steps) ->
                        let has_changes = steps_has_changes steps in
                        let success = steps_success steps in
                        let rs = Rs.of_steps_or_none steps in
                        let run_url =
                          match
                            CCList.assoc_opt
                              ~eq:(fun a b -> Terrat_dirspace.compare a b = 0)
                              dirspace
                              dirspace_run_urls
                          with
                          | Some url -> `String url
                          | None -> `Null
                        in
                        `Assoc
                          (CCList.flatten
                             [
                               [
                                 ("dir", `String dir);
                                 ("workspace", `String workspace);
                                 ("success", `Bool success);
                                 ( "steps",
                                   `List
                                     (steps
                                     |> steps_kv ~overall_success ~compact:(is_compacted dirspace))
                                 );
                                 ("has_changes", `Bool has_changes);
                                 ("run_url", run_url);
                                 ("created", `String (Rs.count_str rs.Rs.created));
                                 ("updated", `String (Rs.count_str rs.Rs.updated));
                                 ("replaced", `String (Rs.count_str rs.Rs.replaced));
                                 ("deleted", `String (Rs.count_str rs.Rs.deleted));
                               ];
                             ]))
                      dirspaces) );
               ( "gates",
                 let module G = Terrat_api_components.Gate in
                 `List
                   (CCList.map
                      (fun { G.all_of; any_of; any_of_count; dir; token; name; workspace } ->
                        let all_of = CCOption.get_or ~default:[] all_of in
                        let any_of = CCOption.get_or ~default:[] any_of in
                        let any_of_count = CCOption.get_or ~default:0 any_of_count in
                        let dir = CCOption.get_or ~default:"" dir in
                        let workspace = CCOption.get_or ~default:"" workspace in
                        `Assoc
                          [
                            ( "token",
                              CCOption.map_or ~default:`Null (fun token -> `String token) token );
                            ("name", CCOption.map_or ~default:`Null (fun name -> `String name) name);
                            ("dir", `String dir);
                            ("workspace", `String workspace);
                            ( "all_of",
                              `List (CCList.map (fun q -> `Assoc [ ("q", `String q) ]) all_of) );
                            ( "any_of",
                              `List
                                (CCList.map
                                   (fun q -> `Assoc [ ("q", `String q) ])
                                   (if any_of_count = 0 then [] else any_of)) );
                            ("any_of_count", `Int any_of_count);
                          ])
                   @@ CCList.sort
                        (fun { G.token = t1; name = n1; _ } { G.token = t2; name = n2; _ } ->
                          let module Cmp = struct
                            type t = string option * string option [@@deriving ord]
                          end in
                          Cmp.compare (t1, n1) (t2, n2))
                   @@ CCOption.get_or ~default:[] gates) );
             ];
             denied_dirspaces;
             cost_estimation;
           ])
    in
    let tmpl =
      match CCList.rev work_manifest.Wm.steps with
      | [] | Wm.Step.Index :: _ | Wm.Step.Build_config :: _ | Wm.Step.Build_tree :: _ ->
          assert false
      | Wm.Step.Plan :: _ -> Tmpl.plan_complete2 brand
      | Wm.Step.(Apply | Unsafe_apply) :: _ -> Tmpl.apply_complete2 brand
    in
    match Minijinja.render_template tmpl kv with
    | Ok body -> body
    | Error err ->
        Logs.err (fun m -> m "%s : ERROR : %s" request_id err);
        assert false
end
