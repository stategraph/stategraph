module Kind = struct
  let t_of_yojson = function
    | `String "failure" -> Ok `Failure
    | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

  let t_to_yojson = function
    | `Failure -> `String "failure"

  type t = ([ `Failure ][@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
  [@@deriving yojson { strict = false; meta = true }, show, eq]
end

module Stategraph_import_id_dropped = struct
  type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
end

type t = {
  kind : Kind.t;
  reason : Sgs_actuator_run_result_run_failure_reason.t;
  stategraph_import_id_dropped : Stategraph_import_id_dropped.t option; [@default None]
}
[@@deriving yojson { strict = false; meta = true }, show, eq]
