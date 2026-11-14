module Action = struct
  let t_of_yojson = function
    | `String "apply" -> Ok `Apply
    | `String "apply-autoapprove" -> Ok `Apply_autoapprove
    | `String "apply-force" -> Ok `Apply_force
    | `String "plan" -> Ok `Plan
    | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

  let t_to_yojson = function
    | `Apply -> `String "apply"
    | `Apply_autoapprove -> `String "apply-autoapprove"
    | `Apply_force -> `String "apply-force"
    | `Plan -> `String "plan"

  type t =
    ([ `Apply
     | `Apply_autoapprove
     | `Apply_force
     | `Plan
     ]
    [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
  [@@deriving yojson { strict = false; meta = true }, show, eq]
end

module Params = struct
  module Additional = struct
    type t = string [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  include Json_schema.Additional_properties.Make (Json_schema.Empty_obj) (Additional)
end

type t = {
  action : Action.t;
  params : Params.t option; [@default None]
}
[@@deriving yojson { strict = true; meta = true }, make, show, eq]
