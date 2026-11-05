module Merge_strategy = struct
  let t_of_yojson = function
    | `String "auto" -> Ok `Auto
    | `String "merge" -> Ok `Merge
    | `String "rebase" -> Ok `Rebase
    | `String "squash" -> Ok `Squash
    | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

  let t_to_yojson = function
    | `Auto -> `String "auto"
    | `Merge -> `String "merge"
    | `Rebase -> `String "rebase"
    | `Squash -> `String "squash"

  type t =
    ([ `Auto
     | `Merge
     | `Rebase
     | `Squash
     ]
    [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
  [@@deriving yojson { strict = false; meta = true }, show, eq]
end

module Require_explicit_apply = struct
  module V0 = struct
    type t = bool [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  module V1 = struct
    let t_of_yojson = function
      | `String "include_layers" -> Ok `Include_layers
      | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

    let t_to_yojson = function
      | `Include_layers -> `String "include_layers"

    type t = ([ `Include_layers ][@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  type t =
    | V0 of V0.t
    | V1 of V1.t
  [@@deriving show, eq]

  let of_yojson =
    Json_schema.one_of
      (let open CCResult in
       [
         (fun v -> map (fun v -> V0 v) (V0.of_yojson v));
         (fun v -> map (fun v -> V1 v) (V1.of_yojson v));
       ])

  let to_yojson = function
    | V0 v -> V0.to_yojson v
    | V1 v -> V1.to_yojson v
end

type t = {
  delete_branch : bool; [@default false]
  enabled : bool; [@default false]
  merge_strategy : Merge_strategy.t; [@default `Auto]
  require_explicit_apply : Require_explicit_apply.t option; [@default None]
  retain_pr_title : bool; [@default false]
}
[@@deriving yojson { strict = true; meta = true }, make, show, eq]
