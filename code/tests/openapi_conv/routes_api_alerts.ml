module List =
  struct
    module Parameters =
      struct
        module Cwes =
          struct
            module V0 = struct type t = string[@@deriving (show, eq)] end
            module V1 =
              struct type t = string list[@@deriving (show, eq)] end
            type t =
              | V0 of V0.t 
              | V1 of V1.t [@@deriving (show, eq)]
          end
        module Has =
          struct
            module V0 = struct type t = string[@@deriving (show, eq)] end
            module V1 =
              struct
                module Items =
                  struct
                    let t_of_yojson =
                      function
                      | `String "patch" -> Ok `Patch
                      | json ->
                          Error
                            ("Unknown value: " ^
                               (Yojson.Safe.pretty_to_string json))
                    let t_to_yojson = function | `Patch -> `String "patch"
                    type t =
                      (([ `Patch ])[@of_yojson t_of_yojson][@to_yojson
                                                             t_to_yojson])
                    [@@deriving (show, eq)]
                  end
                type t = Items.t list[@@deriving (show, eq)]
              end
            type t =
              | V0 of V0.t 
              | V1 of V1.t [@@deriving (show, eq)]
          end
        type t =
          {
          cwes: Cwes.t option [@default None];
          environment: string option [@default Some "none"];
          has: Has.t option [@default None]}[@@deriving (make, show, eq)]
      end
    let route base_route =
      let open Brtl_rtng.Route.Query in
        let open Brtl_rtng.Route in
          ((base_route /?
              (option
                 (ud_array "has"
                    (fun values ->
                       CCOption.choice
                         [CCOption.map (fun v -> Parameters.Has.V0 v)
                            (match values with
                             | value::[] -> CCOption.return value
                             | _ -> None);
                         CCOption.map (fun v -> Parameters.Has.V1 v)
                           (CCOption.sequence_l
                              (CCList.map
                                 (fun value ->
                                    CCResult.to_opt
                                      (Parameters.Has.V1.Items.t_of_yojson
                                         (`String value))) values))]))))
             /?
             (option
                (ud_array "cwes"
                   (fun values ->
                      CCOption.choice
                        [CCOption.map (fun v -> Parameters.Cwes.V0 v)
                           (match values with
                            | value::[] -> CCOption.return value
                            | _ -> None);
                        CCOption.map (fun v -> Parameters.Cwes.V1 v)
                          (CCOption.sequence_l
                             (CCList.map CCOption.return values))]))))
            /? (option_default (Some "none") (option (string "environment")))
    module Responses =
      struct
        module OK = struct  end
        type t = [ `OK ][@@deriving (show, eq)]
        let t = [("200", ((fun _ -> Ok `OK)))]
      end
    let url = "/alerts"
    let make params =
      Openapi.Request.make ~headers:[] ~url_params:[]
        ~query_params:(let open Openapi.Request.Var in
                         let open Parameters in
                           [("has",
                              ((match params.has with
                                | Some (Has.V0 v) -> Var (v, String)
                                | Some (Has.V1 v) ->
                                    Var
                                      (v,
                                        (Array
                                           (Enum Has.V1.Items.t_to_yojson)))
                                | None -> Var ((), Null))));
                           ("cwes",
                             ((match params.cwes with
                               | Some (Cwes.V0 v) -> Var (v, String)
                               | Some (Cwes.V1 v) -> Var (v, (Array String))
                               | None -> Var ((), Null))));
                           ("environment",
                             (Var (params.environment, (Option String))))])
        ~url ~responses:Responses.t `Get
  end
