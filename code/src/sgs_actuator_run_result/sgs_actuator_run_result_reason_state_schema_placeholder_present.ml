module Kind = struct
  let t_of_yojson = function
    | `String "state_schema_placeholder_present" -> Ok `State_schema_placeholder_present
    | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

  let t_to_yojson = function
    | `State_schema_placeholder_present -> `String "state_schema_placeholder_present"

  type t = ([ `State_schema_placeholder_present ][@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
  [@@deriving yojson { strict = false; meta = true }, show, eq]
end

type t = {
  kind : Kind.t;
  state : Sgs_actuator_run_result_state_schema_upgrade_state.t;
}
[@@deriving yojson { strict = false; meta = true }, make, show, eq]
