module Kind = struct
  let t_of_yojson = function
    | `String "state_schema_upgrade_rounds_exhausted" -> Ok `State_schema_upgrade_rounds_exhausted
    | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

  let t_to_yojson = function
    | `State_schema_upgrade_rounds_exhausted -> `String "state_schema_upgrade_rounds_exhausted"

  type t =
    ([ `State_schema_upgrade_rounds_exhausted ][@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
  [@@deriving yojson { strict = false; meta = true }, show, eq]
end

type t = {
  kind : Kind.t;
  rounds : int;
}
[@@deriving yojson { strict = false; meta = true }, make, show, eq]
