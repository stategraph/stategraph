module Source = struct
  let t_of_yojson = function
    | `String "environment" -> Ok `Environment
    | `String "none" -> Ok `None
    | `String "stored" -> Ok `Stored
    | `String "unknown" -> Ok `Unknown
    | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

  let t_to_yojson = function
    | `Environment -> `String "environment"
    | `None -> `String "none"
    | `Stored -> `String "stored"
    | `Unknown -> `String "unknown"

  type t =
    ([ `Environment
     | `None
     | `Stored
     | `Unknown
     ]
    [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
  [@@deriving yojson { strict = false; meta = true }, show, eq]
end

type t = {
  app : Sgs_api_components_github_app_stored.t option; [@default None]
  source : Source.t;
}
[@@deriving yojson { strict = false; meta = true }, show, eq]
