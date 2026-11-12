module Get =
  struct
    module Parameters =
      struct
        module Color =
          struct
            let t_of_yojson =
              function
              | `String "green" -> Ok `Green
              | `String "red" -> Ok `Red
              | json ->
                  Error
                    ("Unknown value: " ^ (Yojson.Safe.pretty_to_string json))
            let t_to_yojson =
              function | `Green -> `String "green" | `Red -> `String "red"
            type t =
              (([ `Green  | `Red ])[@of_yojson t_of_yojson][@to_yojson
                                                             t_to_yojson])
            [@@deriving (show, eq)]
          end
        module Workflow =
          struct
            module V0 = struct type t = int[@@deriving (show, eq)] end
            module V1 = struct type t = string[@@deriving (show, eq)] end
            type t =
              | V0 of V0.t 
              | V1 of V1.t [@@deriving (show, eq)]
          end
        type t = {
          color: Color.t ;
          workflow: Workflow.t }[@@deriving (make, show, eq)]
      end
    let route () =
      let open Brtl_rtng.Route in
        ((rel / "colors") /%
           (Path.ud
              (fun value ->
                 CCResult.to_opt
                   (Parameters.Color.t_of_yojson (`String value)))))
          /%
          (Path.ud
             (fun value ->
                CCOption.choice
                  [CCOption.map (fun v -> Parameters.Workflow.V0 v)
                     (CCInt.of_string value);
                  CCOption.map (fun v -> Parameters.Workflow.V1 v)
                    (CCOption.return value)]))
    module Responses =
      struct
        module OK = struct  end
        type t = [ `OK ][@@deriving (show, eq)]
        let t = [("200", ((fun _ -> Ok `OK)))]
      end
    let url = "/colors/{color}/{workflow}"
    let make params =
      Openapi.Request.make ~headers:[]
        ~url_params:(let open Openapi.Request.Var in
                       let open Parameters in
                         [("color",
                            (Var (params.color, (Enum Color.t_to_yojson))));
                         ("workflow",
                           ((match params.workflow with
                             | Workflow.V0 v -> Var (v, Int)
                             | Workflow.V1 v -> Var (v, String))))])
        ~query_params:[] ~url ~responses:Responses.t `Get
  end
