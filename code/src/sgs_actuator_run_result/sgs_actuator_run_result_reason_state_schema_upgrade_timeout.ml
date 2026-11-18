module Kind = struct
  let t_of_yojson = function
    | `String "state_schema_upgrade_timeout" -> Ok `State_schema_upgrade_timeout
    | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

  let t_to_yojson = function
    | `State_schema_upgrade_timeout -> `String "state_schema_upgrade_timeout"

  type t = ([ `State_schema_upgrade_timeout ][@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
  [@@deriving yojson { strict = false; meta = true }, show, eq]
end

type t = {
  kind : Kind.t;
  seconds : int;
}
[@@deriving yojson { strict = false; meta = true }, make, show, eq]
