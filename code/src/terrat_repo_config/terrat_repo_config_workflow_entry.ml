module Lock_policy = struct
  let t_of_yojson = function
    | `String "apply" -> Ok `Apply
    | `String "merge" -> Ok `Merge
    | `String "none" -> Ok `None
    | `String "strict" -> Ok `Strict
    | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

  let t_to_yojson = function
    | `Apply -> `String "apply"
    | `Merge -> `String "merge"
    | `None -> `String "none"
    | `Strict -> `String "strict"

  type t =
    ([ `Apply
     | `Merge
     | `None
     | `Strict
     ]
    [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
  [@@deriving yojson { strict = false; meta = true }, show, eq]
end

type t = {
  apply : Terrat_repo_config_workflow_op_list.t option; [@default None]
  cdktf : bool; [@default false]
  engine : Terrat_repo_config_engine.t option; [@default None]
  environment : string option; [@default None]
  integrations : Terrat_repo_config_integrations.t option; [@default None]
  lock_policy : Lock_policy.t; [@default `Strict]
  plan : Terrat_repo_config_workflow_op_list.t option; [@default None]
  runs_on : Terrat_repo_config_runs_on.t option; [@default None]
  tag_query : string;
  terraform_version : string option; [@default None]
  terragrunt : bool; [@default false]
}
[@@deriving yojson { strict = true; meta = true }, make, show, eq]
