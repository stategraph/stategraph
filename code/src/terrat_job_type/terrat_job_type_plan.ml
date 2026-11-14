module Type_ = struct
  let t_of_yojson = function
    | `String "plan" -> Ok `Plan
    | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

  let t_to_yojson = function
    | `Plan -> `String "plan"

  type t = ([ `Plan ][@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
  [@@deriving yojson { strict = false; meta = true }, show, eq]
end

type t = {
  force_fail : bool option; [@default None]
  kind : Terrat_job_type_kind.t option; [@default None]
  run_params : Terrat_job_type_run_params.t option; [@default None]
  tag_query : string option; [@default None]
  type_ : Type_.t; [@key "type"]
}
[@@deriving yojson { strict = true; meta = true }, make, show, eq]
