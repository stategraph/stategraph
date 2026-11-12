module Get_network_settings_for_org = struct
  module Parameters = struct
    type t = {
      network_settings_id : string;
      org : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "orgs" /% Path.string / "settings" / "network-settings" /% Path.string

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Network_settings.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/orgs/{org}/settings/network-settings/{network_settings_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("org", Var (params.org, String));
           ("network_settings_id", Var (params.network_settings_id, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Update_network_configuration_for_org = struct
  module Parameters = struct
    type t = {
      network_configuration_id : string;
      org : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Compute_service = struct
        let t_of_yojson = function
          | `String "actions" -> Ok `Actions
          | `String "none" -> Ok `None
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Actions -> `String "actions"
          | `None -> `String "none"

        type t =
          ([ `Actions
           | `None
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Failover_network_settings_ids = struct
        type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Network_settings_ids = struct
        type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = {
        compute_service : Compute_service.t option; [@default None]
        failover_network_enabled : bool option; [@default None]
        failover_network_settings_ids : Failover_network_settings_ids.t option; [@default None]
        name : string option; [@default None]
        network_settings_ids : Network_settings_ids.t option; [@default None]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "orgs" /% Path.string / "settings" / "network-configurations" /% Path.string

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Network_configuration.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/orgs/{org}/settings/network-configurations/{network_configuration_id}"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("org", Var (params.org, String));
           ("network_configuration_id", Var (params.network_configuration_id, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Patch
end

module Delete_network_configuration_from_org = struct
  module Parameters = struct
    type t = {
      network_configuration_id : string;
      org : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "orgs" /% Path.string / "settings" / "network-configurations" /% Path.string

  module Responses = struct
    module No_content = struct end

    type t = [ `No_content ] [@@deriving show, eq]

    let t = [ ("204", fun _ -> Ok `No_content) ]
  end

  let url = "/orgs/{org}/settings/network-configurations/{network_configuration_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("org", Var (params.org, String));
           ("network_configuration_id", Var (params.network_configuration_id, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Get_network_configuration_for_org = struct
  module Parameters = struct
    type t = {
      network_configuration_id : string;
      org : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "orgs" /% Path.string / "settings" / "network-configurations" /% Path.string

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Network_configuration.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/orgs/{org}/settings/network-configurations/{network_configuration_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("org", Var (params.org, String));
           ("network_configuration_id", Var (params.network_configuration_id, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Create_network_configuration_for_org = struct
  module Parameters = struct
    type t = { org : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Compute_service = struct
        let t_of_yojson = function
          | `String "actions" -> Ok `Actions
          | `String "none" -> Ok `None
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Actions -> `String "actions"
          | `None -> `String "none"

        type t =
          ([ `Actions
           | `None
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Failover_network_settings_ids = struct
        type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Network_settings_ids = struct
        type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = {
        compute_service : Compute_service.t option; [@default None]
        failover_network_enabled : bool option; [@default None]
        failover_network_settings_ids : Failover_network_settings_ids.t option; [@default None]
        name : string;
        network_settings_ids : Network_settings_ids.t;
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "orgs" /% Path.string / "settings" / "network-configurations"

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Network_configuration.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `Created of Created.t ] [@@deriving show, eq]

    let t = [ ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson) ]
  end

  let url = "/orgs/{org}/settings/network-configurations"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("org", Var (params.org, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module List_network_configurations_for_org = struct
  module Parameters = struct
    type t = {
      org : string;
      page : int; [@default 1]
      per_page : int; [@default 30]
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "orgs"
    /% Path.string
    / "settings"
    / "network-configurations"
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      module Primary = struct
        module Network_configurations = struct
          type t = Githubc2_components.Network_configuration.t list
          [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          network_configurations : Network_configurations.t;
          total_count : int;
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/orgs/{org}/settings/network-configurations"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("org", Var (params.org, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("per_page", Var (params.per_page, Int)); ("page", Var (params.page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end
