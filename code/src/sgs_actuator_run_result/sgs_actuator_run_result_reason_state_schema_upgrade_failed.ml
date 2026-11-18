module Kind = struct
  let t_of_yojson = function
    | `String "state_schema_upgrade_failed" -> Ok `State_schema_upgrade_failed
    | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

  let t_to_yojson = function
    | `State_schema_upgrade_failed -> `String "state_schema_upgrade_failed"

  type t = ([ `State_schema_upgrade_failed ][@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
  [@@deriving yojson { strict = false; meta = true }, show, eq]
end

type t = {
  kind : Kind.t;
  upgrade_tx_id : string;
}
[@@deriving yojson { strict = false; meta = true }, make, show, eq]
