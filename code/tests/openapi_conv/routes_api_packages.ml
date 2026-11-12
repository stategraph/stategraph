module Get =
  struct
    module Parameters =
      struct
        type t = {
          arch: string ;
          version: string }[@@deriving (make, show, eq)]
      end
    let route () =
      let open Brtl_rtng.Route in
        ((rel / "packages") /%
           (Path.ud
              (fun segment -> CCString.chop_prefix ~pre:"binary-" segment)))
          /%
          (Path.ud (fun segment -> CCString.chop_suffix ~suf:".info" segment))
    module Responses =
      struct
        module OK = struct  end
        type t = [ `OK ][@@deriving (show, eq)]
        let t = [("200", ((fun _ -> Ok `OK)))]
      end
    let url = "/packages/binary-{arch}/{version}.info"
    let make params =
      Openapi.Request.make ~headers:[]
        ~url_params:(let open Openapi.Request.Var in
                       let open Parameters in
                         [("arch", (Var (params.arch, String)));
                         ("version", (Var (params.version, String)))])
        ~query_params:[] ~url ~responses:Responses.t `Get
  end
