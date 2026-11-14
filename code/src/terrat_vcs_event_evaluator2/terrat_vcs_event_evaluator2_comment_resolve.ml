module Tc = Terrat_comment
module Tjc = Terrat_job_context
module Msg = Terrat_vcs_provider2.Msg

(* The parameters section of the repository configuration, as the configuration decode built
   it.  The aliases and the names both sit in maps keyed by their declared name. *)
module P = Terrat_base_repo_config_v1.Parameters

type reply =
  [ `Not_a_run
  | `Parameter_err of Msg.parameter_err
  | `Unknown_command
  ]

(* [needs_config c] answers whether resolving [c] reads the repository configuration: only an
   alias, which the configuration declares, and a run command that carries parameters, which
   the configuration validates, need it.  A run command without parameters and every other
   command resolve the same way on a repository whose configuration does not decode. *)
let needs_config = function
  | Tc.Alias _ -> true
  | Tc.Apply { Tc.parameters; _ }
  | Tc.Apply_force { Tc.parameters; _ }
  | Tc.Plan { Tc.parameters; _ } -> parameters <> []
  | Tc.Apply_autoapprove _
  | Tc.Feedback _
  | Tc.Gate_approval _
  | Tc.Help
  | Tc.Index
  | Tc.Repo_config
  | Tc.Unlock _ -> false

(* [validate config parameters] reads the parameter tokens of the comment, in written order,
   against [config] and answers the reply for the first token that fails: a name the comment
   sets twice, a name the configuration does not declare, or a value outside the values the
   configuration allows.  An absent [values] accepts any string, and [Some []] accepts none.
   An empty list passes without touching [config], which is how a plain [plan] runs when the
   configuration does not decode. *)
let rec validate config = function
  | [] -> Ok ()
  | (name, value) :: rest -> (
      if Sln_list.String.mem_assoc name rest then Error (`Parameter_err (`Duplicate name))
      else
        match Sln_map.String.find_opt name config.P.names with
        | None -> Error (`Parameter_err (`Undeclared name))
        | Some { P.Parameter.values; _ } -> (
            match values with
            | Some allowed when not (CCList.mem ~eq:CCString.equal value allowed) ->
                Error (`Parameter_err (`Value_not_allowed (name, value, allowed)))
            | _ -> validate config rest))

(* [check config parameters] answers the resolved map when every token passes {!validate}: the
   tokens in written order, which the duplicate rule makes duplicate-free. *)
let check config parameters =
  match validate config parameters with
  | Ok () -> Ok (Sln_map.String.of_list parameters)
  | Error _ as reply -> reply

(* [job_of_action ~tag_query alias] expands a declared alias into the job of the verb its
   [action] names, with the alias's [params] as the parameters of the run.  The configuration
   decode validated the alias already, so its params need no check here.  [apply-autoapprove]
   decodes and validates, but the evaluator does not run it, so it answers [Not_a_run]. *)
let job_of_action ~tag_query alias =
  let parameters = alias.P.Alias.params in
  match alias.P.Alias.action with
  | `Apply -> Ok (Tjc.Job.Type_.Apply { tag_query; kind = None; force = false; parameters })
  | `Apply_autoapprove -> Error `Not_a_run
  | `Apply_force -> Ok (Tjc.Job.Type_.Apply { tag_query; kind = None; force = true; parameters })
  | `Plan -> Ok (Tjc.Job.Type_.Plan { tag_query; kind = None; parameters })

let resolve ~config comment =
  let config = CCOption.get_or ~default:(P.make ()) config in
  match comment with
  | Tc.Alias { name; tag_query } -> (
      match Sln_map.String.find_opt name config.P.aliases with
      | Some alias -> job_of_action ~tag_query alias
      | None ->
          (* An alias the configuration does not declare is a command this system does not
             have, exactly like a misspelled verb. *)
          Error `Unknown_command)
  | Tc.Apply { Tc.parameters; Tc.tag_query } ->
      CCResult.map
        (fun parameters ->
          Tjc.Job.Type_.Apply { tag_query; kind = None; force = false; parameters })
        (check config parameters)
  | Tc.Apply_autoapprove _ -> Error `Not_a_run
  | Tc.Apply_force { Tc.parameters; Tc.tag_query } ->
      CCResult.map
        (fun parameters -> Tjc.Job.Type_.Apply { tag_query; kind = None; force = true; parameters })
        (check config parameters)
  | Tc.Feedback _ ->
      (* The pull request evaluation answers a feedback comment before this table sees it, so
         this member is unreachable; it keeps the match exhaustive. *)
      Error `Not_a_run
  | Tc.Gate_approval { tokens } -> Ok (Tjc.Job.Type_.Gate_approval { tokens })
  | Tc.Help -> Ok Tjc.Job.Type_.Help
  | Tc.Index -> Ok Tjc.Job.Type_.Index
  | Tc.Plan { Tc.parameters; Tc.tag_query } ->
      CCResult.map
        (fun parameters -> Tjc.Job.Type_.Plan { tag_query; kind = None; parameters })
        (check config parameters)
  | Tc.Repo_config -> Ok Tjc.Job.Type_.Repo_config
  | Tc.Unlock unlocks -> Ok (Tjc.Job.Type_.Unlock (Sln_list.String.sort_uniq unlocks))
