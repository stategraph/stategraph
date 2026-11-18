module Kind = struct
  let t_of_yojson = function
    | `String "state_schema_remote_module_missing" -> Ok `State_schema_remote_module_missing
    | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

  let t_to_yojson = function
    | `State_schema_remote_module_missing -> `String "state_schema_remote_module_missing"

  type t =
    ([ `State_schema_remote_module_missing ][@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
  [@@deriving yojson { strict = false; meta = true }, show, eq]
end

type t = {
  kind : Kind.t;
  source : string;
  state : Sgs_actuator_run_result_state_schema_upgrade_state.t;
  version : string option; [@default None]
}
[@@deriving yojson { strict = false; meta = true }, make, show, eq]
