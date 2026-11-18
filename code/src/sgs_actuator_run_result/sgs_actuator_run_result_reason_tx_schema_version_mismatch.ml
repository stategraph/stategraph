module Kind = struct
  let t_of_yojson = function
    | `String "tx_schema_version_mismatch" -> Ok `Tx_schema_version_mismatch
    | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

  let t_to_yojson = function
    | `Tx_schema_version_mismatch -> `String "tx_schema_version_mismatch"

  type t = ([ `Tx_schema_version_mismatch ][@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
  [@@deriving yojson { strict = false; meta = true }, show, eq]
end

type t = {
  kind : Kind.t;
  planned_schema_version : int;
  server_schema_version : int;
}
[@@deriving yojson { strict = false; meta = true }, make, show, eq]
