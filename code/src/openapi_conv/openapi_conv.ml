module Properties = Json_schema_conv.Properties
module Value = Json_schema_conv.Value
module Additional_properties = Json_schema_conv.Additional_properties
module Schema = Json_schema_conv.Schema
module Gen = Json_schema_conv.Gen

module Parameter = struct
  type t_ = {
    name : string;
    in_ : string; [@key "in"]
    description : string option; [@default None]
    required : bool; [@default false]
    deprecated : bool; [@default false]
    allow_empty_value : bool; [@default false]
    schema : Schema.t;
  }
  [@@deriving yojson { strict = false }]

  type t = t_ Value.t [@@deriving yojson]
end

module Media_type = struct
  type t = { schema : Schema.t } [@@deriving yojson { strict = false }]
end

module Request_body = struct
  type t_ = {
    description : string; [@default ""]
    content : Media_type.t Properties.t;
    required : bool; [@default false]
  }
  [@@deriving yojson { strict = false }]

  type t = t_ Value.t [@@deriving yojson]
end

module Response = struct
  type t_ = { content : Media_type.t Properties.t [@default Sln_map.String.empty] }
  [@@deriving yojson { strict = false }]

  type t = t_ Value.t [@@deriving yojson]
end

module Operation = struct
  type t = {
    summary : string; [@default ""]
    description : string; [@default ""]
    operation_id : string option; [@key "operationId"]
    parameters : Parameter.t list; [@default []]
    request_body : Request_body.t option; [@default None] [@key "requestBody"]
    responses : Response.t Properties.t;
  }
  [@@deriving yojson { strict = false }]
end

module Path = struct
  type t = {
    summary : string; [@default ""]
    description : string; [@default ""]
    get : Operation.t option; [@default None]
    put : Operation.t option; [@default None]
    post : Operation.t option; [@default None]
    delete : Operation.t option; [@default None]
    patch : Operation.t option; [@default None]
    parameters : Parameter.t list Value.t option; [@default None]
  }
  [@@deriving yojson { strict = false }]
end

module Components = struct
  type t = {
    schemas : Schema.t Properties.t; [@default Sln_map.String.empty]
    responses : Response.t Properties.t; [@default Sln_map.String.empty]
    parameters : Parameter.t Properties.t; [@default Sln_map.String.empty]
    request_bodies : Request_body.t Properties.t;
        [@default Sln_map.String.empty] [@key "requestBodies"]
  }
  [@@deriving yojson { strict = false }]
end

module Document = struct
  type t = {
    paths : Path.t Properties.t;
    components : Components.t;
  }
  [@@deriving yojson { strict = false }]
end

let cleanup_name s =
  s
  |> CCString.replace ~by:"_" ~sub:"-"
  |> CCString.replace ~by:"_" ~sub:"["
  |> CCString.replace ~by:"_" ~sub:"]"
  |> CCString.replace ~by:"_" ~sub:"*"
  |> CCString.replace ~by:"_" ~sub:"$"
  |> CCString.replace ~by:"_" ~sub:"("
  |> CCString.replace ~by:"_" ~sub:")"
  |> CCString.replace ~by:"_" ~sub:"."
  |> CCString.replace ~by:"_" ~sub:"@"
  |> CCString.replace ~by:"_" ~sub:"\\"

let module_name_of_string s =
  s
  |> CCString.replace ~sub:"-" ~by:"_"
  |> (function
  | s when CCString.prefix ~pre:"_" s -> CCString.drop_while (( = ) '_') s ^ "_"
  | s -> s)
  |> cleanup_name
  |> CCString.capitalize_ascii

let module_name_of_field_name { Components.schemas; _ } s =
  if Sln_map.String.mem (CCString.replace ~sub:"_" ~by:"-" s) schemas then
    module_name_of_string s ^ "_"
  else module_name_of_string s

let rec resolve_ref typ lookup ref_ =
  match ref_ with
  | Value.Ref ref_ -> (
      match CCString.split_on_char '/' ref_ with
      | [ "#"; "components"; t; name ] when CCString.equal t typ -> (
          match lookup name with
          | Some (Value.Ref _ as ref_) -> resolve_ref typ lookup ref_
          | Some (Value.V v) -> v
          | None -> failwith (Printf.sprintf "Could not resolve ref: %s" ref_))
      | _ -> failwith (Printf.sprintf "Unknown ref typ: %s" ref_))
  | Value.V v -> v

let resolve_schema_ref { Components.schemas; _ } ref_ =
  match ref_ with
  | Value.Ref r
    when match CCString.split_on_char '/' r with
         | [ "#"; "file-link"; _; _ ] -> true
         | _ -> false ->
      (* File-linked schemas are referenced via their existing OCaml module and are not loaded,
         so there is no concrete schema to return.  A neutral (non-primitive, non-nullable,
         default-less) schema is correct: the field/variant renders as [<Module_base>_<name>.t]
         via [module_name_of_ref]/[variant_name_of_ref]. *)
      Schema.make_t_ ()
  | _ -> resolve_ref "schemas" (CCFun.flip Sln_map.String.get schemas) ref_

let resolve_response_ref { Components.responses; _ } =
  resolve_ref "responses" (CCFun.flip Sln_map.String.get responses)

let resolve_parameter_ref { Components.parameters; _ } =
  resolve_ref "parameters" (CCFun.flip Sln_map.String.get parameters)

(* TODO: Fix this because we are actually only converting Schemas into
   Components and not into Components.Schemas.  This might change if we start
   converting responses into Components too. *)
let module_name_of_ref base_module_name context ref_ =
  match CCString.split_on_char '/' ref_ with
  (* Foreign ref mapped to an existing module via --file-link; resolves the same way regardless
     of the context it appears in (component schema, operation response body, etc.). *)
  | [ "#"; "file-link"; mb; n ] -> [ mb ^ "_" ^ CCString.lowercase_ascii (module_name_of_string n) ]
  | _ -> (
      match context with
      | "schemas" | "parameters" | "responses" -> (
          match CCString.split_on_char '/' ref_ with
          | [ "#"; "components"; m; n ] when CCString.equal m context -> [ module_name_of_string n ]
          | [ "#"; "components"; m; n ] -> [ CCString.capitalize_ascii m; module_name_of_string n ]
          | _ -> failwith (Printf.sprintf "Unknown ref type: %s" ref_))
      | _ -> (
          match CCString.split_on_char '/' ref_ with
          | [ "#"; "components"; _m; n ] ->
              [ base_module_name ^ "_components"; module_name_of_string n ]
          | _ -> failwith (Printf.sprintf "Unknown ref type: %s" ref_)))

let http_status_to_name = function
  | "100" -> "Continue"
  | "101" -> "Switching_protocols"
  | "102" -> "Processing"
  | "103" -> "Checkpoint"
  | "200" -> "OK"
  | "201" -> "Created"
  | "202" -> "Accepted"
  | "203" -> "Non_authoritative_information"
  | "204" -> "No_content"
  | "205" -> "Reset_content"
  | "206" -> "Partial_content"
  | "207" -> "Multi_status"
  | "208" -> "Already_reported"
  | "226" -> "Im_used"
  | "300" -> "Multiple_choices"
  | "301" -> "Moved_permanently"
  | "302" -> "Found"
  | "303" -> "See_other"
  | "304" -> "Not_modified"
  | "305" -> "Use_proxy"
  | "306" -> "Switch_proxy"
  | "307" -> "Temporary_redirect"
  | "308" -> "Permanent_redirect"
  | "400" -> "Bad_request"
  | "401" -> "Unauthorized"
  | "402" -> "Payment_required"
  | "403" -> "Forbidden"
  | "404" -> "Not_found"
  | "405" -> "Method_not_allowed"
  | "406" -> "Not_acceptable"
  | "407" -> "Proxy_authentication_required"
  | "408" -> "Request_timeout"
  | "409" -> "Conflict"
  | "410" -> "Gone"
  | "411" -> "Length_required"
  | "412" -> "Precondition_failed"
  | "413" -> "Request_entity_too_large"
  | "414" -> "Request_uri_too_long"
  | "415" -> "Unsupported_media_type"
  | "416" -> "Requested_range_not_satisfiable"
  | "417" -> "Expectation_failed"
  | "418" -> "I_m_a_teapot"
  | "420" -> "Enhance_your_calm"
  | "422" -> "Unprocessable_entity"
  | "423" -> "Locked"
  | "424" -> "Failed_dependency"
  | "426" -> "Upgrade_required"
  | "428" -> "Precondition_required"
  | "429" -> "Too_many_requests"
  | "431" -> "Request_header_fields_too_large"
  | "444" -> "No_response"
  | "449" -> "Retry_with"
  | "450" -> "Blocked_by_windows_parental_controls"
  | "451" -> "Wrong_exchange_server"
  | "499" -> "Client_closed_request"
  | "500" -> "Internal_server_error"
  | "501" -> "Not_implemented"
  | "502" -> "Bad_gateway"
  | "503" -> "Service_unavailable"
  | "504" -> "Gateway_timeout"
  | "505" -> "Http_version_not_supported"
  | "506" -> "Variant_also_negotiates"
  | "507" -> "Insufficient_storage"
  | "508" -> "Loop_detected"
  | "509" -> "Bandwidth_limit_exceeded"
  | "510" -> "Not_extended"
  | "511" -> "Network_authentication_required"
  | "598" -> "Network_read_timeout_error"
  | "599" -> "Network_connect_timeout_error"
  | code -> "Http_" ^ code

let get_json_media_type m =
  match Sln_map.String.get "application/json" m with
  | None -> Sln_map.String.get "*/*" m
  | r -> r

let module_name_of_operation_id s = s |> CCString.replace ~sub:"/" ~by:"_" |> module_name_of_string

let field_name_of_schema s =
  match CCString.lowercase_ascii s with
  | s when Gen.is_reserved_word s -> s ^ "_"
  | s when CCString.prefix ~pre:"_" s -> cleanup_name @@ CCString.drop_while (( = ) '_') s ^ "_"
  | s when CCString.prefix ~pre:"$" s -> cleanup_name @@ CCString.drop_while (( = ) '$') s ^ "_"
  | s when CCString.prefix ~pre:"@" s -> cleanup_name @@ CCString.drop_while (( = ) '@') s ^ "_"
  | "+1" -> "plus_one"
  | "-1" -> "minus_one"
  | s -> cleanup_name s

let field_default_of_value typ enum default =
  match (default, typ, enum) with
  | `String s, Some "boolean", _ ->
      Some Ast_helper.(Exp.construct (Location.mknoloc (Gen.ident [ s ])) None)
  | `String s, _, Some enum_json -> (
      match Gen.variant_name_of_default enum_json s with
      | Some tag -> Some Ast_helper.(Exp.variant tag None)
      | None -> Some Ast_helper.(Exp.constant (Const.string s)))
  | `String s, _, None -> Some Ast_helper.(Exp.constant (Const.string s))
  | `Bool b, _, _ ->
      Some Ast_helper.(Exp.construct (Location.mknoloc (Gen.ident [ Bool.to_string b ])) None)
  | `Float fl, _, _ -> Some Ast_helper.(Exp.constant (Const.float (CCFloat.to_string fl)))
  | `Int int, _, _ -> Some Ast_helper.(Exp.constant (Const.integer (CCInt.to_string int)))
  | `List [], _, _ -> Some Json_schema_conv.Gen.(make_list [])
  | `List (`String _ :: _ as v), _, _ ->
      Some
        Json_schema_conv.Gen.(
          make_list
            (CCList.map
               (fun s -> Ast_helper.(Exp.constant (Const.string s)))
               (Yojson.Safe.Util.filter_string v)))
  | `List _, _, _ -> (* TODO: Add more *) None
  | json, _, _ ->
      failwith (Printf.sprintf "Unknown field default value: %s" (Yojson.Safe.to_string json))

let record_field_attrs schema name required =
  CCList.flatten
    [
      (match schema.Schema.default with
      | Some default when schema.Schema.nullable ->
          CCOption.map_or
            ~default:[]
            (fun default ->
              Gen.field_default
                (Ast_helper.Exp.construct (Location.mknoloc (Gen.ident [ "Some" ])) (Some default)))
            (field_default_of_value schema.Schema.typ schema.Schema.enum default)
      | Some default ->
          CCOption.map_or
            ~default:[]
            (fun default -> Gen.field_default default)
            (field_default_of_value schema.Schema.typ schema.Schema.enum default)
      | None when (not (Sln_set.String.mem name required)) || schema.Schema.nullable ->
          Gen.field_default_none
      | None -> []);
      (if CCString.equal (field_name_of_schema name) name then [] else Gen.yojson_key_name name);
    ]

let request_param_of_op_params base_module_name components param_in params =
  let params =
    params
    |> CCList.filter_map (fun p ->
        let p = resolve_parameter_ref components p in
        if CCString.equal p.Parameter.in_ param_in then Some p else None)
  in
  match params with
  | [] -> Gen.make_list []
  | params ->
      let option obj =
        Ast_helper.(Exp.construct (Location.mknoloc (Gen.ident [ "Option" ])) (Some obj))
      in
      let scalar v = Ast_helper.(Exp.construct (Location.mknoloc (Gen.ident [ v ])) None) in
      let array obj =
        Ast_helper.(Exp.construct (Location.mknoloc (Gen.ident [ "Array" ])) (Some obj))
      in
      let enum_module_of_schema_value param_module schema_value =
        match schema_value with
        | Value.Ref ref_ -> module_name_of_ref base_module_name "paths" ref_
        | Value.V _ -> [ param_module ]
      in
      let rec type_desc_of_schema ~enum_module = function
        | { Schema.typ = Some "string"; enum = Some _; _ } ->
            Ast_helper.Exp.construct
              (Location.mknoloc (Gen.ident [ "Enum" ]))
              (Some
                 (Ast_helper.Exp.ident
                    (Location.mknoloc (Gen.ident (enum_module @ [ "t_to_yojson" ])))))
        | { Schema.typ = Some _; format; _ } as schema when Json_schema_conv.is_prim_type schema
          -> (
            match Json_schema_conv.extract_prim_type schema with
            | Some ("string" | "file") -> scalar "String"
            | Some "integer" when format = Some "int64" -> scalar "Int64"
            | Some "integer" -> scalar "Int"
            | Some "boolean" -> scalar "Bool"
            | Some "number" -> assert false
            | _ -> assert false)
        | { Schema.typ = Some "array"; items = Some items; _ } ->
            let items_enum_module =
              match items with
              | Value.Ref ref_ -> module_name_of_ref base_module_name "paths" ref_
              | Value.V _ -> enum_module @ [ "Items" ]
            in
            array
              (type_desc_of_schema
                 ~enum_module:items_enum_module
                 (resolve_schema_ref components items))
        | schema -> failwith (Schema.show_t_ schema)
      in
      let open Ast_helper in
      Exp.struct_item
        (Str.open_
           (Opn.mk (Mod.ident (Location.mknoloc (Gen.ident [ "Openapi"; "Request"; "Var" ])))))
        (Exp.struct_item
           (Str.open_ (Opn.mk (Mod.ident (Location.mknoloc (Gen.ident [ "Parameters" ])))))
           (params
           |> CCList.map (fun p ->
               let param_name =
                 Exp.ident
                   (Location.mknoloc
                      (Gen.ident [ "params"; field_name_of_schema p.Parameter.name ]))
               in
               let type_desc =
                 match resolve_schema_ref components p.Parameter.schema with
                 | { Schema.one_of = Some schemas; _ } as schema ->
                     let is_optional =
                       not
                         ((p.Parameter.required || CCOption.is_some schema.Schema.default)
                         && not schema.Schema.nullable)
                     in
                     let wrap_option =
                       if is_optional then fun v ->
                         Pat.construct (Location.mknoloc (Gen.ident [ "Some" ])) (Some ([], v))
                       else CCFun.id
                     in
                     Exp.match_
                       param_name
                       ((CCList.mapi (fun idx schema ->
                             Exp.case
                               (wrap_option
                                  (Pat.construct
                                     (Location.mknoloc
                                        (Gen.ident
                                           [
                                             module_name_of_string p.Parameter.name;
                                             Printf.sprintf "V%d" idx;
                                           ]))
                                     (Some ([], Pat.var (Location.mknoloc "v")))))
                               (Exp.construct
                                  (Location.mknoloc (Gen.ident [ "Var" ]))
                                  (Some
                                     (Gen.tuple
                                        [
                                          Exp.ident (Location.mknoloc (Gen.ident [ "v" ]));
                                          (* The type of branch [idx] lives in
                                             [<Param>.V<idx>], the same module the
                                             pattern above constructs, so an enum
                                             inside the branch is reached through
                                             it.  Naming the parameter module alone
                                             produces a reference to a module that
                                             does not exist. *)
                                          type_desc_of_schema
                                            ~enum_module:
                                              [
                                                module_name_of_string p.Parameter.name;
                                                Printf.sprintf "V%d" idx;
                                              ]
                                            schema;
                                        ]))))
                        @@ CCList.map (resolve_schema_ref components) schemas)
                       @
                       if is_optional then
                         [
                           Exp.case
                             (Pat.construct (Location.mknoloc (Gen.ident [ "None" ])) None)
                             (Exp.construct
                                (Location.mknoloc (Gen.ident [ "Var" ]))
                                (Some
                                   (Gen.tuple
                                      [
                                        Exp.tuple [];
                                        Exp.ident (Location.mknoloc (Gen.ident [ "Null" ]));
                                      ])));
                         ]
                       else [])
                 | schema ->
                     let enum_module =
                       enum_module_of_schema_value
                         (module_name_of_string p.Parameter.name)
                         p.Parameter.schema
                     in
                     let type_desc = type_desc_of_schema ~enum_module schema in
                     let type_desc =
                       if
                         (p.Parameter.required || CCOption.is_some schema.Schema.default)
                         && not schema.Schema.nullable
                       then type_desc
                       else option type_desc
                     in
                     Exp.construct
                       (Location.mknoloc (Gen.ident [ "Var" ]))
                       (Some (Gen.tuple [ param_name; type_desc ]))
               in
               Gen.tuple [ Exp.constant (Const.string p.Parameter.name); type_desc ])
           |> Gen.make_list))

let exp_ident name = Ast_helper.Exp.ident (Location.mknoloc (Gen.ident name))
let exp_apply f args = Ast_helper.Exp.apply f (CCList.map (fun arg -> (Asttypes.Nolabel, arg)) args)

(* [fun <var> -> <body>] *)
let exp_fun var body =
  Ast_helper.Exp.function_
    [
      {
        Parsetree.pparam_loc = Location.none;
        pparam_desc =
          Parsetree.Pparam_val (Asttypes.Nolabel, None, Ast_helper.Pat.var (Location.mknoloc var));
      };
    ]
    None
    (Parsetree.Pfunction_body body)

(* [fun value -> CCResult.to_opt (<enum_module>.t_of_yojson (`String value))]: the generated enum
   module maps each string to its variant, so the parser does not repeat the values. *)
let enum_query_parser enum_module =
  exp_fun
    "value"
    (exp_apply
       (exp_ident [ "CCResult"; "to_opt" ])
       [
         exp_apply
           (exp_ident (enum_module @ [ "t_of_yojson" ]))
           [ Ast_helper.Exp.variant "String" (Some (exp_ident [ "value" ])) ];
       ])

let integer_enum_query_extractor
    param_name
    values
    ~parse_function
    ~parse_enum_value
    ~to_string
    ~to_constant
    typ =
  let open Ast_helper in
  let values =
    CCList.map parse_enum_value values
    |> CCList.uniq ~eq:(fun a b -> CCString.equal (to_string a) (to_string b))
  in
  let some = Location.mknoloc (Gen.ident [ "Some" ]) in
  let cases =
    CCList.map
      (fun value ->
        let constant = to_constant value in
        Exp.case
          (Pat.construct some (Some ([], Pat.constant constant)))
          (Exp.construct some (Some (Exp.constant constant))))
      values
  in
  let fallback =
    Exp.case (Pat.any ()) (Exp.construct (Location.mknoloc (Gen.ident [ "None" ])) None)
  in
  let parse =
    exp_fun
      "value"
      (Exp.match_
         (exp_apply (exp_ident parse_function) [ exp_ident [ "value" ] ])
         (cases @ [ fallback ]))
  in
  let parse =
    Exp.constraint_ parse (Typ.arrow Asttypes.Nolabel Gen.prim_string (Gen.option [ typ ]))
  in
  exp_apply (exp_ident [ "ud" ]) [ Exp.constant (Const.string param_name); parse ]

(* A query string does not tell a scalar from a one element array: the client sends [V0 "a"] and
   [V1 [ "a" ]] both as [name=a]. The alternatives are tried in the order of the schema, and a scalar
   alternative matches only one value. Thus [name=a] gives the first scalar alternative, and
   [name=a,b] gives the first array alternative. The values are parsed into the types of the
   variant module of the parameter, [Parameters.<Name>.V<idx>], which the client also uses. *)
let one_of_query_extractor base_module_name components param_name alternatives =
  let open Ast_helper in
  (* An expression of type [string -> 'a option]. *)
  let scalar_parser enum_module = function
    | { Schema.typ = Some "string"; enum = Some _; _ } -> enum_query_parser enum_module
    | { Schema.typ = Some ("string" | "text" | "symbol" | "file"); _ } ->
        exp_ident [ "CCOption"; "return" ]
    | { Schema.typ = Some "integer"; format = Some "int64"; enum = None; _ } ->
        exp_ident [ "CCInt64"; "of_string" ]
    | { Schema.typ = Some "integer"; enum = None; _ } -> exp_ident [ "CCInt"; "of_string" ]
    | { Schema.typ = Some "boolean"; _ } -> exp_ident [ "bool_of_string_opt" ]
    | schema -> failwith ("Unsupported oneOf query parameter alternative: " ^ Schema.show_t_ schema)
  in
  let values = exp_ident [ "values" ] in
  let alternative idx schema_value =
    let variant = [ "Parameters"; module_name_of_string param_name; Printf.sprintf "V%d" idx ] in
    let parsed =
      match resolve_schema_ref components schema_value with
      | { Schema.typ = Some "array"; items = Some items; _ } ->
          let items_enum_module =
            match items with
            | Value.Ref ref_ -> module_name_of_ref base_module_name "paths" ref_
            | Value.V _ -> variant @ [ "Items" ]
          in
          exp_apply
            (exp_ident [ "CCOption"; "sequence_l" ])
            [
              exp_apply
                (exp_ident [ "CCList"; "map" ])
                [ scalar_parser items_enum_module (resolve_schema_ref components items); values ];
            ]
      | schema ->
          let one_value =
            Pat.construct
              (Location.mknoloc (Gen.ident [ "::" ]))
              (Some
                 ( [],
                   Pat.tuple
                     [
                       (None, Pat.var (Location.mknoloc "value"));
                       (None, Pat.construct (Location.mknoloc (Gen.ident [ "[]" ])) None);
                     ]
                     Asttypes.Closed ))
          in
          Exp.match_
            values
            [
              Exp.case
                one_value
                (exp_apply (scalar_parser variant schema) [ exp_ident [ "value" ] ]);
              Exp.case (Pat.any ()) (Exp.construct (Location.mknoloc (Gen.ident [ "None" ])) None);
            ]
    in
    exp_apply
      (exp_ident [ "CCOption"; "map" ])
      [
        exp_fun
          "v"
          (Exp.construct (Location.mknoloc (Gen.ident variant)) (Some (exp_ident [ "v" ])));
        parsed;
      ]
  in
  exp_apply
    (exp_ident [ "ud_array" ])
    [
      Exp.constant (Const.string param_name);
      exp_fun
        "values"
        (exp_apply
           (exp_ident [ "CCOption"; "choice" ])
           [ Gen.make_list (CCList.mapi alternative alternatives) ]);
    ]

let rec query_extractor_of_schema
    ?(enum_module_suffix = [])
    base_module_name
    components
    param_name
    schema_value
    schema =
  let open Ast_helper in
  let query_apply name args = exp_apply (exp_ident [ name ]) args in
  let string s = Exp.constant (Const.string s) in
  match schema with
  | { Schema.typ = Some "array"; items = Some items; _ } ->
      query_apply
        "array"
        [
          query_extractor_of_schema
            base_module_name
            components
            param_name
            items
            (resolve_schema_ref components items)
            ~enum_module_suffix:
              (match items with
              | Value.Ref _ -> []
              | Value.V _ -> "Items" :: enum_module_suffix);
        ]
  | { Schema.typ = Some "string"; enum = Some _; _ } ->
      let enum_module =
        match schema_value with
        | Value.Ref ref_ -> module_name_of_ref base_module_name "paths" ref_
        | Value.V _ -> [ "Parameters"; module_name_of_string param_name ] @ enum_module_suffix
      in
      query_apply "ud" [ string param_name; enum_query_parser enum_module ]
  | { Schema.typ = Some "string"; format = Some "uuid"; _ } ->
      query_apply "uuid" [ string param_name ]
  | { Schema.typ = Some ("string" | "text" | "symbol" | "file"); _ } ->
      query_apply "string" [ string param_name ]
  | { Schema.typ = Some "integer"; format = Some "int64"; enum = Some values; _ } ->
      integer_enum_query_extractor
        param_name
        values
        ~parse_function:[ "CCInt64"; "of_string" ]
        ~parse_enum_value:(function
          | `Int value -> Int64.of_int value
          | `Intlit value -> (
              match CCInt64.of_string value with
              | Some value -> value
              | None -> failwith ("Integer enum value is out of int64 range: " ^ value))
          | value -> failwith ("Expected integer enum value, got: " ^ Yojson.Safe.to_string value))
        ~to_string:Int64.to_string
        ~to_constant:Const.int64
        (Gen.qualified_type [ "int64" ])
  | { Schema.typ = Some "integer"; format = Some "int64"; _ } ->
      query_apply "ud" [ string param_name; exp_ident [ "CCInt64"; "of_string" ] ]
  | { Schema.typ = Some "integer"; enum = Some values; _ } ->
      integer_enum_query_extractor
        param_name
        values
        ~parse_function:[ "CCInt"; "of_string" ]
        ~parse_enum_value:(function
          | `Int value -> value
          | `Intlit value -> (
              match CCInt.of_string value with
              | Some value -> value
              | None -> failwith ("Integer enum value is out of int range: " ^ value))
          | value -> failwith ("Expected integer enum value, got: " ^ Yojson.Safe.to_string value))
        ~to_string:string_of_int
        ~to_constant:Const.int
        Gen.prim_int
  | { Schema.typ = Some "integer"; _ } -> query_apply "int" [ string param_name ]
  | { Schema.typ = Some "boolean"; _ } -> query_apply "bool" [ string param_name ]
  | { Schema.one_of = Some alternatives; _ } ->
      one_of_query_extractor base_module_name components param_name alternatives
  | schema -> failwith ("Unsupported query parameter schema: " ^ Schema.show_t_ schema)

let query_default_of_schema param_name schema =
  match schema.Schema.default with
  | None -> None
  | Some default -> (
      let fail () =
        failwith
          (Printf.sprintf
             "Unsupported query parameter default for %S: %s"
             param_name
             (Yojson.Safe.to_string default))
      in
      let supported =
        match default with
        | `String _ | `Bool _ | `Float _ | `Int _ | `List [] -> true
        | `List values ->
            CCList.for_all
              (function
                | `String _ -> true
                | _ -> false)
              values
        | _ -> false
      in
      if not supported then fail ();
      match field_default_of_value schema.Schema.typ schema.Schema.enum default with
      | Some default -> Some default
      | None -> fail ())

(* Keep server route query parsing tied to the same OpenAPI parameter declarations used by the
   generated client request. The helper is deliberately just a route transformer, so a service can
   compose it with its hand-written path and body matchers. *)
let route_function base_module_name components params =
  let params =
    params
    |> CCList.filter_map (fun param ->
        let param = resolve_parameter_ref components param in
        if CCString.equal param.Parameter.in_ "query" then Some param else None)
  in
  match params with
  | [] -> None
  | params ->
      let open Ast_helper in
      let route = exp_ident [ "base_route" ] in
      let route =
        CCList.fold_left
          (fun route param ->
            let schema = resolve_schema_ref components param.Parameter.schema in
            let extractor =
              query_extractor_of_schema
                base_module_name
                components
                param.Parameter.name
                param.Parameter.schema
                schema
            in
            let extractor =
              match (param.Parameter.required, schema.Schema.nullable) with
              | true, false -> extractor
              | _, true -> (
                  match query_default_of_schema param.Parameter.name schema with
                  | Some default ->
                      let default =
                        Exp.construct (Location.mknoloc (Gen.ident [ "Some" ])) (Some default)
                      in
                      exp_apply
                        (exp_ident [ "option_default" ])
                        [ default; exp_apply (exp_ident [ "option" ]) [ extractor ] ]
                  | None -> exp_apply (exp_ident [ "option" ]) [ extractor ])
              | false, false -> (
                  match query_default_of_schema param.Parameter.name schema with
                  | Some default ->
                      exp_apply (exp_ident [ "option_default" ]) [ default; extractor ]
                  | None -> exp_apply (exp_ident [ "option" ]) [ extractor ])
            in
            exp_apply (exp_ident [ "/?" ]) [ route; extractor ])
          route
          params
      in
      let route =
        Exp.struct_item
          (Str.open_ (Opn.mk (Mod.ident (Location.mknoloc (Gen.ident [ "Brtl_rtng"; "Route" ])))))
          route
      in
      let route =
        Exp.struct_item
          (Str.open_
             (Opn.mk (Mod.ident (Location.mknoloc (Gen.ident [ "Brtl_rtng"; "Route"; "Query" ])))))
          route
      in
      Some (Gen.make_func "route" (exp_fun "base_route" route))

(* To convert an operation we need to convert the parameters, request body, and
   responses.  The resulting module will have a function to create a
   [Openapi.Request] value.

   We will convert [parameters] to a module called [Parameters] as a record. *)
let convert_str_operation strict_records base_module_name components uritmpl op_typ op =
  assert (CCOption.is_some op.Operation.operation_id);
  let operation_id = CCOption.get_exn_or "operation_id" op.Operation.operation_id in
  let params_config =
    Json_schema_conv.Config.make
      ~create_yojson_funcs:false
      ~field_name_of_schema
      ~module_name_of_ref:(module_name_of_ref base_module_name "paths")
      ~module_name_of_field_name:module_name_of_string
      ~prim_type_attrs:Gen.(deriving [ show_deriver; eq_deriver ])
      ~record_type_attrs:(fun _ -> Gen.(deriving [ make_deriver; show_deriver; eq_deriver ]))
      ~record_field_attrs
      ~resolve_ref:(resolve_schema_ref components)
      ~variant_name_of_ref:(module_name_of_ref base_module_name "paths")
      ()
  in
  let parameters_module =
    let config = params_config in
    let parameters =
      Schema.
        {
          (make_t_ ()) with
          typ = Some "object";
          additional_properties = Additional_properties.Bool false;
          properties =
            Sln_map.String.of_list
              (CCList.map
                 (fun p ->
                   let { Parameter.name; schema; _ } = resolve_parameter_ref components p in
                   (name, schema))
                 op.Operation.parameters);
          required =
            Sln_set.String.of_list
              (CCList.filter_map
                 (fun p ->
                   let p = resolve_parameter_ref components p in
                   let schema_is_ref =
                     match p.Parameter.schema with
                     | Value.Ref _ -> true
                     | _ -> false
                   in
                   let schema = Json_schema_conv.Config.resolve_ref config p.Parameter.schema in
                   (* Things that are considered required:

                      - The parameter is marked as required

                      - The schema is a ref and the ref is nullable, that means
                      if this parameter is not marked as required, the
                      "optionness" is taken care of at the schema definition. *)
                   if p.Parameter.required || (schema_is_ref && schema.Schema.nullable) then
                     Some p.Parameter.name
                   else None)
                 op.Operation.parameters);
        }
    in
    [
      Ast_helper.(
        Str.module_
          (Mb.mk
             (Location.mknoloc (Some "Parameters"))
             (Mod.structure
                (match op.Operation.parameters with
                | [] -> []
                | _ -> Json_schema_conv.convert_str_schema config parameters))));
    ]
  in
  let request_body =
    let config =
      Json_schema_conv.Config.make
        ~field_name_of_schema
        ~module_name_of_ref:(module_name_of_ref base_module_name "paths")
        ~module_name_of_field_name:module_name_of_string
        ~prim_type_attrs:
          Gen.(deriving [ yojson_deriver ~strict:false ~meta:true (); show_deriver; eq_deriver ])
        ~record_type_attrs:(fun strict ->
          Gen.(
            deriving
              [
                make_deriver;
                yojson_deriver ~strict:(strict && strict_records) ~meta:true ();
                show_deriver;
                eq_deriver;
              ]))
        ~record_field_attrs
        ~resolve_ref:(resolve_schema_ref components)
        ~variant_name_of_ref:(module_name_of_ref base_module_name "paths")
        ()
    in
    match op.Operation.request_body with
    | Some (Value.V request_body) -> (
        match get_json_media_type request_body.Request_body.content with
        | Some { Media_type.schema = Value.V schema } ->
            [
              Ast_helper.(
                Str.module_
                  (Mb.mk
                     (Location.mknoloc (Some "Request_body"))
                     (Mod.structure (Json_schema_conv.convert_str_schema config schema))));
            ]
        | Some { Media_type.schema = Value.Ref ref_ } ->
            [
              Ast_helper.(
                Str.module_
                  (Mb.mk
                     (Location.mknoloc (Some "Request_body"))
                     (Mod.structure
                        [
                          Gen.make_str_type
                            ~attrs:(Json_schema_conv.Config.prim_type_attrs config)
                            "t"
                            (Gen.qualified_type
                               (Json_schema_conv.Config.module_name_of_ref config ref_ @ [ "t" ]));
                        ])));
            ]
        | None -> [])
    | Some (Value.Ref ref_) -> failwith (Printf.sprintf "Unexpected ref in request body: %s" ref_)
    | None -> []
  in
  let responses =
    let config =
      Json_schema_conv.Config.make
        ~field_name_of_schema
        ~module_name_of_ref:(module_name_of_ref base_module_name "paths")
        ~module_name_of_field_name:module_name_of_string
        ~prim_type_attrs:
          Gen.(deriving [ yojson_deriver ~strict:false ~meta:false (); show_deriver; eq_deriver ])
        ~record_type_attrs:(fun strict ->
          Gen.(
            deriving
              [ yojson_deriver ~strict:(strict && strict_records) (); show_deriver; eq_deriver ]))
        ~record_field_attrs
        ~resolve_ref:(resolve_schema_ref components)
        ~variant_name_of_ref:(module_name_of_ref base_module_name "paths")
        ()
    in
    let resolved_responses =
      op.Operation.responses
      |> Sln_map.String.to_list
      |> Sln_list.String.sort_assoc
      |> CCList.map (fun (c, r) -> (c, resolve_response_ref components r))
    in
    Ast_helper.(
      Str.module_
        (Mb.mk
           (Location.mknoloc (Some "Responses"))
           (Mod.structure
           @@ CCList.map
                (fun (code, r) ->
                  Str.module_
                    (Mb.mk
                       (Location.mknoloc (Some (http_status_to_name code)))
                       (Mod.structure
                          (match get_json_media_type r.Response.content with
                          | Some { Media_type.schema = Value.V schema } ->
                              Json_schema_conv.convert_str_schema config schema
                          | Some { Media_type.schema = Value.Ref ref_ } ->
                              [
                                Gen.make_str_type
                                  ~attrs:(Json_schema_conv.Config.prim_type_attrs config)
                                  (Json_schema_conv.Config.tidx_to_string config)
                                  (Gen.qualified_type
                                     (Json_schema_conv.Config.module_name_of_ref config ref_
                                     @ [ "t" ]));
                              ]
                          | None -> []))))
                resolved_responses
           @ [
               Str.type_
                 Asttypes.Recursive
                 [
                   Type.mk
                     ~attrs:Gen.(deriving [ show_deriver; eq_deriver ])
                     ~manifest:
                       (Typ.variant
                          (CCList.map
                             (fun (code, r) ->
                               Rf.tag
                                 (Location.mknoloc (http_status_to_name code))
                                 false
                                 (match get_json_media_type r.Response.content with
                                 | Some _ ->
                                     [
                                       Typ.constr
                                         (Location.mknoloc
                                            (Gen.ident [ http_status_to_name code; "t" ]))
                                         [];
                                     ]
                                 | None -> []))
                             resolved_responses)
                          Asttypes.Closed
                          None)
                     (Location.mknoloc "t");
                 ];
               Str.value
                 Asttypes.Nonrecursive
                 [
                   Vb.mk
                     (Pat.var (Location.mknoloc "t"))
                     (resolved_responses
                     |> CCList.map (fun (code, r) ->
                         match get_json_media_type r.Response.content with
                         | Some _r ->
                             Gen.tuple
                               [
                                 Exp.constant (Const.string code);
                                 Exp.apply
                                   (Exp.ident
                                      (Location.mknoloc (Gen.ident [ "Openapi"; "of_json_body" ])))
                                   [
                                     ( Asttypes.Nolabel,
                                       Exp.function_
                                         [
                                           {
                                             Parsetree.pparam_loc = Location.none;
                                             pparam_desc =
                                               Parsetree.Pparam_val
                                                 ( Asttypes.Nolabel,
                                                   None,
                                                   Pat.var (Location.mknoloc "v") );
                                           };
                                         ]
                                         None
                                         (Parsetree.Pfunction_body
                                            (Exp.variant
                                               (http_status_to_name code)
                                               (Some
                                                  (Exp.ident (Location.mknoloc (Gen.ident [ "v" ]))))))
                                     );
                                     ( Asttypes.Nolabel,
                                       Exp.ident
                                         (Location.mknoloc
                                            (Gen.ident [ http_status_to_name code; "of_yojson" ]))
                                     );
                                   ];
                               ]
                         | None ->
                             Gen.tuple
                               [
                                 Exp.constant (Const.string code);
                                 Exp.function_
                                   [
                                     {
                                       Parsetree.pparam_loc = Location.none;
                                       pparam_desc =
                                         Parsetree.Pparam_val
                                           (Asttypes.Nolabel, None, Pat.var (Location.mknoloc "_"));
                                     };
                                   ]
                                   None
                                   (Parsetree.Pfunction_body
                                      (Exp.construct
                                         (Location.mknoloc (Gen.ident [ "Ok" ]))
                                         (Some (Exp.variant (http_status_to_name code) None))));
                               ])
                     |> Gen.make_list);
                 ];
             ])))
  in
  let url =
    Ast_helper.(
      Str.value
        Asttypes.Nonrecursive
        [ Vb.mk (Pat.var (Location.mknoloc "url")) (Exp.constant (Const.string uritmpl)) ])
  in
  let make_body =
    Ast_helper.(
      Exp.apply
        (Exp.ident (Location.mknoloc (Gen.ident [ "Openapi"; "Request"; "make" ])))
        (CCList.flatten
           [
             (match op.Operation.request_body with
             | Some (Value.V request_body)
               when request_body.Request_body.required
                    && CCOption.is_some (get_json_media_type request_body.Request_body.content) ->
                 (* TODO: Handle reference bodies that are required *)
                 [
                   ( Asttypes.Labelled "body",
                     Exp.apply
                       (Exp.ident (Location.mknoloc (Gen.ident [ "Request_body"; "to_yojson" ])))
                       [ (Asttypes.Nolabel, Exp.ident (Location.mknoloc (Gen.ident [ "body" ]))) ]
                   );
                 ]
             | Some (Value.V request_body)
               when CCOption.is_some (get_json_media_type request_body.Request_body.content) ->
                 [
                   ( Asttypes.Optional "body",
                     Exp.apply
                       (Exp.ident (Location.mknoloc (Gen.ident [ "CCOption"; "map" ])))
                       [
                         ( Asttypes.Nolabel,
                           Exp.ident (Location.mknoloc (Gen.ident [ "Request_body"; "to_yojson" ]))
                         );
                         (Asttypes.Nolabel, Exp.ident (Location.mknoloc (Gen.ident [ "body" ])));
                       ] );
                 ]
             | Some (Value.V _) -> []
             | Some (Value.Ref _) -> failwith "request body ref not supported"
             | None -> []);
             [
               (Asttypes.Labelled "headers", Gen.make_list []);
               ( Asttypes.Labelled "url_params",
                 request_param_of_op_params
                   base_module_name
                   components
                   "path"
                   op.Operation.parameters );
               ( Asttypes.Labelled "query_params",
                 request_param_of_op_params
                   base_module_name
                   components
                   "query"
                   op.Operation.parameters );
               (Asttypes.Labelled "url", Exp.ident (Location.mknoloc (Gen.ident [ "url" ])));
               ( Asttypes.Labelled "responses",
                 Exp.ident (Location.mknoloc (Gen.ident [ "Responses"; "t" ])) );
               ( Asttypes.Nolabel,
                 Exp.variant
                   (match op_typ with
                   | `Get -> "Get"
                   | `Post -> "Post"
                   | `Put -> "Put"
                   | `Patch -> "Patch"
                   | `Delete -> "Delete")
                   None );
             ];
           ]))
  in
  (* The portion of the make function for params *)
  let make_params =
    let open Ast_helper in
    match op.Operation.parameters with
    | [] ->
        Exp.function_
          [
            {
              Parsetree.pparam_loc = Location.none;
              pparam_desc =
                Parsetree.Pparam_val
                  ( Asttypes.Nolabel,
                    None,
                    Pat.construct (Location.mknoloc (Gen.ident [ "()" ])) None );
            };
          ]
          None
          (Parsetree.Pfunction_body make_body)
    | _ ->
        Exp.function_
          [
            {
              Parsetree.pparam_loc = Location.none;
              pparam_desc =
                Parsetree.Pparam_val (Asttypes.Nolabel, None, Pat.var (Location.mknoloc "params"));
            };
          ]
          None
          (Parsetree.Pfunction_body make_body)
  in
  let make =
    Gen.make_func
      "make"
      (match op.Operation.request_body with
      | Some (Value.V request_body)
        when request_body.Request_body.required
             && CCOption.is_some (get_json_media_type request_body.Request_body.content) ->
          (* TODO: Handle ref that is required *)
          Ast_helper.(
            Exp.function_
              [
                {
                  Parsetree.pparam_loc = Location.none;
                  pparam_desc =
                    Parsetree.Pparam_val
                      (Asttypes.Labelled "body", None, Pat.var (Location.mknoloc "body"));
                };
              ]
              None
              (Parsetree.Pfunction_body make_params))
      | Some (Value.V request_body)
        when CCOption.is_some (get_json_media_type request_body.Request_body.content) ->
          Ast_helper.(
            Exp.function_
              [
                {
                  Parsetree.pparam_loc = Location.none;
                  pparam_desc =
                    Parsetree.Pparam_val
                      (Asttypes.Optional "body", None, Pat.var (Location.mknoloc "body"));
                };
              ]
              None
              (Parsetree.Pfunction_body make_params))
      | Some (Value.Ref _) -> failwith "request body ref not supported"
      | Some (Value.V _) | None -> make_params)
  in
  ( operation_id,
    parameters_module
    @ request_body
    @ CCOption.to_list (route_function base_module_name components op.Operation.parameters)
    @ [ responses; url; make ] )

let convert_str_components
    strict_records
    output_dir
    base_module_name
    ({ Components.schemas; responses = _; _ } as components) =
  let module_name_of_ref ref_ =
    match CCString.split_on_char '/' ref_ with
    | [ "#"; "components"; _; n ] ->
        [ base_module_name ^ "_components_" ^ CCString.lowercase_ascii (module_name_of_string n) ]
    | [ "#"; "file-link"; mb; n ] ->
        (* Foreign ref mapped to an existing module via --file-link. *)
        [ mb ^ "_" ^ CCString.lowercase_ascii (module_name_of_string n) ]
    | _ -> failwith (Printf.sprintf "Unknown ref type: %s" ref_)
  in
  let variant_name_of_ref ref_ =
    match CCString.split_on_char '/' ref_ with
    | [ "#"; "components"; _; n ] -> [ module_name_of_string n ]
    | [ "#"; "file-link"; _; n ] -> [ module_name_of_string n ]
    | _ -> failwith (Printf.sprintf "Unknown ref type: %s" ref_)
  in
  let config =
    Json_schema_conv.Config.make
      ~field_name_of_schema
      ~module_name_of_ref
      ~module_name_of_field_name:(module_name_of_field_name components)
      ~prim_type_attrs:Gen.(deriving [ yojson_deriver ~strict:false (); show_deriver; eq_deriver ])
      ~record_type_attrs:(fun strict ->
        Gen.(
          deriving
            [ yojson_deriver ~strict:(strict && strict_records) (); show_deriver; eq_deriver ]))
      ~record_field_attrs
      ~resolve_ref:(resolve_schema_ref components)
      ~variant_name_of_ref
      ()
  in
  CCList.iter
    (fun (name, schema) ->
      match schema with
      | Value.Ref _ -> ()
      | Value.V schema ->
          let m = Json_schema_conv.convert_str_schema config schema in
          CCIO.with_out
            (Filename.concat
               output_dir
               (CCString.lowercase_ascii
                  (base_module_name ^ "_components_" ^ module_name_of_string name ^ ".ml")))
            (fun oc -> CCIO.write_line oc (Pprintast.string_of_structure m)))
    (Sln_map.String.to_list schemas);
  let sts =
    CCList.map
      (fun name ->
        let module_name =
          base_module_name ^ "_components_" ^ CCString.lowercase_ascii (module_name_of_string name)
        in
        Ast_helper.(
          Str.module_
            (Mb.mk
               (Location.mknoloc (Some (module_name_of_string name)))
               (Mod.ident (Location.mknoloc (Json_schema_conv.Gen.ident [ module_name ]))))))
      (schemas |> Sln_map.String.to_list |> CCList.map fst |> CCList.sort CCString.compare)
  in
  CCIO.with_out
    (Filename.concat output_dir (CCString.lowercase_ascii (base_module_name ^ "_components.ml")))
    (fun oc -> CCIO.write_line oc (Pprintast.string_of_structure sts))

let convert_str_paths strict_records output_base base_module_name components paths =
  let modules =
    CCList.map
      (fun (uritmpl, path) ->
        assert (path.Path.parameters = None);
        CCList.map
          (CCFun.uncurry (convert_str_operation strict_records base_module_name components uritmpl))
          (CCList.filter_map
             (fun (t, op) -> CCOption.map (fun op -> (t, op)) op)
             [
               (`Get, path.Path.get);
               (`Put, path.Path.put);
               (`Post, path.Path.post);
               (`Delete, path.Path.delete);
               (`Patch, path.Path.patch);
             ]))
      (Sln_map.String.to_list paths)
    |> CCList.flatten
    |> CCList.map (fun ((op, _) as v) -> (fst @@ CCString.Split.left_exn ~by:"/" op, [ v ]))
    |> Sln_map.String.of_list_with ~f:(fun _ -> CCList.append)
  in
  CCList.iter
    (fun (name, operations) ->
      let modules =
        CCList.map
          (fun (operation_id, body) ->
            let op_name = snd @@ CCString.Split.left_exn ~by:"/" operation_id in
            Ast_helper.(
              Str.module_
                (Mb.mk
                   (Location.mknoloc (Some (module_name_of_operation_id op_name)))
                   (Mod.structure body))))
          operations
      in
      CCIO.with_out
        (output_base ^ "_" ^ CCString.lowercase_ascii (module_name_of_string name) ^ ".ml")
        (fun oc -> CCIO.write_line oc (Pprintast.string_of_structure modules)))
    (Sln_map.String.to_list modules)

let convert_str_document strict_records output_dir base_module_name { Document.paths; components } =
  let output_base = Filename.concat output_dir (CCString.lowercase_ascii base_module_name) in
  convert_str_components strict_records output_dir base_module_name components;
  convert_str_paths strict_records output_base base_module_name components paths

let convert ~strict_records ~search_path ~file_link ~input_file ~output_name ~output_dir =
  let base_module_name = CCString.capitalize_ascii output_name in
  let json =
    Json_schema_flatten.flatten_document
      ~search_path
      ~file_link
      ~root_file:input_file
      (Yojson.Safe.from_file input_file)
  in
  match Document.of_yojson json with
  | Ok document -> convert_str_document strict_records output_dir base_module_name document
  | Error err -> print_endline ("ERROR: " ^ err)
