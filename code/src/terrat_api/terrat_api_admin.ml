module Drifts = struct
  module Parameters = struct end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v1" / "admin" / "drifts"

  module Responses = struct
    module OK = struct
      module Results = struct
        module Items = struct
          type t = {
            completed_at : string option; [@default None]
            created_at : string;
            id : string;
            name : string;
            owner : string;
            run_type : Terrat_api_components.Run_type.t;
            state : string;
            unlocked : bool;
          }
          [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
      end

      type t = { results : Results.t } [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/api/v1/admin/drifts"

  let make () =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end
