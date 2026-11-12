module GetApiV4ProjectsIdInvitedGroups = struct
  module Parameters = struct
    module Relation = struct
      module Items = struct
        let t_of_yojson = function
          | `String "direct" -> Ok `Direct
          | `String "inherited" -> Ok `Inherited
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Direct -> `String "direct"
          | `Inherited -> `String "inherited"

        type t =
          ([ `Direct
           | `Inherited
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving show, eq]
      end

      type t = Items.t list [@@deriving show, eq]
    end

    type t = {
      id : string;
      min_access_level : int option; [@default None]
      page : int; [@default 1]
      per_page : int; [@default 20]
      relation : Relation.t option; [@default None]
      search : string option; [@default None]
      with_custom_attributes : bool; [@default false]
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "api"
    / "v4"
    / "projects"
    /% Path.string
    / "invited_groups"
    /? option
         (array
            (ud "relation" (fun value ->
                 CCResult.to_opt (Parameters.Relation.Items.t_of_yojson (`String value)))))
    /? option (string "search")
    /? option
         (ud
            "min_access_level"
            (fun value ->
               match CCInt.of_string value with
               | Some 10 -> Some 10
               | Some 15 -> Some 15
               | Some 20 -> Some 20
               | Some 30 -> Some 30
               | Some 40 -> Some 40
               | Some 50 -> Some 50
               | _ -> None
              : string -> int option))
    /? option_default 1 (int "page")
    /? option_default 20 (int "per_page")
    /? option_default false (bool "with_custom_attributes")

  module Responses = struct
    module OK = struct end

    type t = [ `OK ] [@@deriving show, eq]

    let t = [ ("200", fun _ -> Ok `OK) ]
  end

  let url = "/api/v4/projects/{id}/invited_groups"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("relation", Var (params.relation, Option (Array (Enum Relation.Items.t_to_yojson))));
           ("search", Var (params.search, Option String));
           ("min_access_level", Var (params.min_access_level, Option Int));
           ("page", Var (params.page, Int));
           ("per_page", Var (params.per_page, Int));
           ("with_custom_attributes", Var (params.with_custom_attributes, Bool));
         ])
      ~url
      ~responses:Responses.t
      `Get
end
