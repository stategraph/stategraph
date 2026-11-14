module Apply = Terrat_job_type_apply
module Gate_approval = Terrat_job_type_gate_approval
module Help = Terrat_job_type_help
module Index = Terrat_job_type_index
module Kind = Terrat_job_type_kind
module Kind_drift = Terrat_job_type_kind_drift
module Plan = Terrat_job_type_plan
module Push = Terrat_job_type_push
module Repo_config = Terrat_job_type_repo_config
module Run_params = Terrat_job_type_run_params
module Type = Terrat_job_type_type
module Unlock = Terrat_job_type_unlock

module Event = struct
  type t = Type of Terrat_job_type_type.t [@@deriving show, eq]

  let of_yojson =
    Json_schema.one_of
      (let open CCResult in
       [ (fun v -> map (fun v -> Type v) (Terrat_job_type_type.of_yojson v)) ])

  let to_yojson = function
    | Type v -> Terrat_job_type_type.to_yojson v
end
