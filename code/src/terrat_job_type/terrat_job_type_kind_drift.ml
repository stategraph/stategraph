module Type_ = struct
  let t_of_yojson = function
    | `String "drift" -> Ok `Drift
    | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

  let t_to_yojson = function
    | `Drift -> `String "drift"

  type t = ([ `Drift ][@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
  [@@deriving yojson { strict = false; meta = true }, show, eq]
end

type t = {
  reconcile : bool; [@default false]
  restart_on_change : bool; [@default true]
  type_ : Type_.t; [@key "type"]
}
[@@deriving yojson { strict = true; meta = true }, make, show, eq]
