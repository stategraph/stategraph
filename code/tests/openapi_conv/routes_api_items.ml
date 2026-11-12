module Get =
  struct
    module Parameters =
      struct
        type t =
          {
          big: int64 ;
          count: int ;
          limit: int [@default 5];
          name: string ;
          tenant_id: string }[@@deriving (make, show, eq)]
      end
    let route () =
      let open Brtl_rtng.Route.Query in
        let open Brtl_rtng.Route in
          ((((((rel / "tenants") /% Path.uuid) / "items") /% Path.string) /%
              Path.int)
             /% (Path.ud CCInt64.of_string))
            /? (option_default 5 (int "limit"))
    module Responses =
      struct
        module OK = struct  end
        type t = [ `OK ][@@deriving (show, eq)]
        let t = [("200", ((fun _ -> Ok `OK)))]
      end
    let url = "/tenants/{tenant_id}/items/{name}/{count}/{big}"
    let make params =
      Openapi.Request.make ~headers:[]
        ~url_params:(let open Openapi.Request.Var in
                       let open Parameters in
                         [("tenant_id", (Var (params.tenant_id, String)));
                         ("name", (Var (params.name, String)));
                         ("count", (Var (params.count, Int)));
                         ("big", (Var (params.big, Int64)))])
        ~query_params:(let open Openapi.Request.Var in
                         let open Parameters in
                           [("limit", (Var (params.limit, Int)))]) ~url
        ~responses:Responses.t `Get
  end
