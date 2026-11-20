module Cmdline = struct
  module C = Cmdliner

  let output_name =
    let doc = "Root name for output files" in
    C.Arg.(required & opt (some string) None & info [ "n"; "name" ] ~doc)

  let output_dir =
    let doc = "Directory to write outputs to" in
    C.Arg.(required & opt (some string) None & info [ "output-dir" ] ~doc)

  let input_file =
    let doc = "Input file" in
    C.Arg.(required & opt (some string) None & info [ "i"; "input" ] ~doc)

  let non_strict_records =
    let doc = "Do not require records to be strict" in
    C.Arg.(value & flag & info [ "non-strict-records" ] ~doc)

  let search_path =
    let doc =
      "Directory to search for files referenced by foreign $refs (e.g. \
       \"common.json#/definitions/Foo\"). May be passed multiple times; directories are searched \
       in the order given."
    in
    C.Arg.(value & opt_all dir [] & info [ "S"; "search-path" ] ~doc ~docv:"DIR")

  let file_link =
    let link_conv =
      C.Arg.Conv.make
        ~docv:"FILE=MODULE_BASE"
        ~parser:(fun s ->
          CCOption.to_result "Must be of form FILE=MODULE_BASE" (CCString.Split.left ~by:"=" s))
        ~pp:(fun fmt (file, module_base) -> Format.fprintf fmt "%s=%s" file module_base)
        ()
    in
    let doc =
      "Reference a foreign schema file as an existing OCaml module instead of inlining it. Refs \
       into FILE generate references to MODULE_BASE (e.g. \
       \"session-capabilities.json=Sgs_session_caps\" makes \
       \"session-capabilities.json#/definitions/Foo\" generate \"Sgs_session_caps_foo.t\"). May be \
       passed multiple times."
    in
    C.Arg.(value & opt_all link_conv [] & info [ "file-link" ] ~doc)

  let convert_cmd f =
    let doc = "Convert to Ocaml" in
    C.Cmd.v
      (C.Cmd.info "convert" ~doc)
      C.Term.(
        const f
        $ non_strict_records
        $ input_file
        $ output_name
        $ output_dir
        $ search_path
        $ file_link)

  let flatten_cmd f =
    let doc = "Print the input document with its foreign refs inlined" in
    C.Cmd.v (C.Cmd.info "flatten" ~doc) C.Term.(const f $ input_file $ search_path)

  let default_cmd = C.Term.(ret (const (`Help (`Pager, None))))
end

module Document = struct
  type t = {
    definitions : Json_schema_conv.Schema.t Json_schema_conv.Properties.t;
    one_of : Json_schema_conv.Schema.t list option; [@key "oneOf"] [@default None]
    ref_ : string option; [@key "$ref"] [@default None]
  }
  [@@deriving yojson { strict = false }, show]
end

let module_name_of_string s =
  s
  |> CCString.replace ~sub:"-" ~by:"_"
  |> CCString.replace ~sub:"$" ~by:"_"
  |> (function
  | s when CCString.prefix ~pre:"_" s -> CCString.drop_while (( = ) '_') s ^ "_"
  | s -> s)
  |> CCString.capitalize_ascii

let module_name_of_field_name defs s =
  if Sln_map.String.mem (CCString.replace ~sub:"_" ~by:"-" s) defs then
    module_name_of_string s ^ "_"
  else module_name_of_string s

let module_name_of_ref module_base ref_ =
  match CCString.split_on_char '/' ref_ with
  | [ "#"; "definitions"; n ] ->
      [ module_base ^ "_" ^ CCString.lowercase_ascii (module_name_of_string n) ]
  | [ "#"; "file-link"; mb; n ] ->
      (* Foreign ref mapped to an existing module via --file-link. *)
      [ mb ^ "_" ^ CCString.lowercase_ascii (module_name_of_string n) ]
  | _ -> failwith (Printf.sprintf "Unknown ref: %s" ref_)

let variant_name_of_ref ref_ =
  match CCString.split_on_char '/' ref_ with
  | [ "#"; "definitions"; n ] -> [ module_name_of_string n ]
  | [ "#"; "file-link"; _; n ] -> [ module_name_of_string n ]
  | _ -> failwith (Printf.sprintf "Unknown ref: %s" ref_)

let field_name_of_schema s =
  match CCString.lowercase_ascii s with
  | s when Json_schema_conv.Gen.is_reserved_word s -> s ^ "_"
  | s when CCString.prefix ~pre:"_" s -> CCString.drop_while (( = ) '_') s ^ "_"
  | s when CCString.prefix ~pre:"$" s -> CCString.drop_while (( = ) '$') s ^ "_"
  | s when CCString.prefix ~pre:"@" s -> CCString.drop_while (( = ) '@') s ^ "_"
  | "+1" -> "plus_one"
  | "-1" -> "minus_one"
  | s -> (
      s
      |> CCString.replace ~sub:"-" ~by:"_"
      |> CCString.replace ~sub:"$" ~by:"_"
      |> function
      | s when CCString.prefix ~pre:"_" s -> CCString.drop_while (( = ) '_') s ^ "_"
      | s -> s)

let field_default_of_value typ enum default =
  let module Gen = Json_schema_conv.Gen in
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

let rec resolve_ref definitions ref_ =
  let module Value = Json_schema_conv.Value in
  match ref_ with
  | Value.Ref ref_ -> (
      match CCString.split_on_char '/' ref_ with
      | [ "#"; "definitions"; name ] -> (
          match Sln_map.String.get name definitions with
          | Some (Value.Ref _ as ref_) -> resolve_ref definitions ref_
          | Some (Value.V v) -> v
          | None -> failwith (Printf.sprintf "Could not resolve ref: %s" ref_))
      | [ "#"; "file-link"; _; _ ] ->
          (* File-linked schemas are referenced via their existing OCaml module and are not loaded,
             so we have no concrete schema to return.  A neutral (non-primitive, non-nullable,
             default-less) schema is correct for the common case: the field/variant renders as
             [<Module_base>_<name>.t] via [module_name_of_ref]/[variant_name_of_ref].  The fields of
             a file-linked schema cannot be merged into an enclosing allOf/oneOf base since they are
             not available here. *)
          Json_schema_conv.Schema.make_t_ ()
      | _ -> failwith (Printf.sprintf "Unknown ref: %s" ref_))
  | Value.V v -> v

let convert_def strict_records definitions module_base def =
  Json_schema_conv.convert_str_schema
    (Json_schema_conv.Config.make
       ~field_name_of_schema
       ~module_name_of_ref:(module_name_of_ref module_base)
       ~module_name_of_field_name:(module_name_of_field_name definitions)
       ~prim_type_attrs:
         Json_schema_conv.Gen.(deriving [ yojson_deriver (); show_deriver; eq_deriver ])
       ~record_type_attrs:(fun strict ->
         Json_schema_conv.Gen.(
           deriving
             [
               yojson_deriver ~strict:(strict && strict_records) ();
               make_deriver;
               show_deriver;
               eq_deriver;
             ]))
       ~record_field_attrs:(fun schema name required ->
         let field_name = field_name_of_schema name in
         CCList.flatten
           [
             (if CCString.equal field_name name then []
              else Json_schema_conv.Gen.yojson_key_name name);
             (if Sln_set.String.mem name required && not schema.Json_schema_conv.Schema.nullable
              then []
              else
                match schema.Json_schema_conv.Schema.default with
                | Some default when schema.Json_schema_conv.Schema.nullable ->
                    CCOption.map_or
                      ~default:[]
                      (fun default ->
                        Json_schema_conv.Gen.field_default
                          (Ast_helper.Exp.construct
                             (Location.mknoloc (Json_schema_conv.Gen.ident [ "Some" ]))
                             (Some default)))
                      (field_default_of_value
                         schema.Json_schema_conv.Schema.typ
                         schema.Json_schema_conv.Schema.enum
                         default)
                | Some default ->
                    CCOption.map_or
                      ~default:[]
                      (fun default -> Json_schema_conv.Gen.field_default default)
                      (field_default_of_value
                         schema.Json_schema_conv.Schema.typ
                         schema.Json_schema_conv.Schema.enum
                         default)
                | None -> Json_schema_conv.Gen.field_default_none);
           ])
       ~resolve_ref:(resolve_ref definitions)
       ~variant_name_of_ref
       ())
    def

let convert_document strict_records output_dir output_name { Document.definitions; one_of; ref_ } =
  let module_base = CCString.capitalize_ascii output_name in
  let event =
    match (one_of, ref_) with
    | Some one_of, _ -> Json_schema_conv.{ (Schema.make_t_ ()) with Schema.one_of = Some one_of }
    | None, Some ref_ ->
        (* This is a bit of a hack to support a ref as a hook entrypoint.  Using
           a $ref gets translated to a singular oneOf. *)
        Json_schema_conv.{ (Schema.make_t_ ()) with Schema.one_of = Some [ Value.Ref ref_ ] }
    | None, None -> assert false
  in
  Sln_map.String.iter
    (fun name def ->
      let module_name = module_base ^ "_" ^ CCString.lowercase_ascii (module_name_of_string name) in
      let structure =
        match def with
        | Json_schema_conv.Value.Ref ref_ ->
            (* A definition that is only a ref is an alias of the module of its target. *)
            Ast_helper.
              [
                Str.include_
                  (Incl.mk
                     (Mod.ident
                        (Location.mknoloc
                           (Json_schema_conv.Gen.ident (module_name_of_ref module_base ref_)))));
              ]
        | Json_schema_conv.Value.V def -> convert_def strict_records definitions module_base def
      in
      CCIO.with_out
        (Filename.concat output_dir (CCString.lowercase_ascii module_name ^ ".ml"))
        (fun oc -> CCIO.write_line oc (Pprintast.string_of_structure structure)))
    definitions;
  let structure =
    Ast_helper.(
      CCList.map
        (fun name ->
          let module_name =
            module_base ^ "_" ^ CCString.lowercase_ascii (module_name_of_string name)
          in
          Str.module_
            (Mb.mk
               (Location.mknoloc (Some (module_name_of_string name)))
               (Mod.ident (Location.mknoloc (Json_schema_conv.Gen.ident [ module_name ])))))
        (definitions |> Sln_map.String.to_list |> CCList.map fst |> CCList.sort CCString.compare)
      @ [
          Str.module_
            (Mb.mk
               (Location.mknoloc (Some (module_name_of_string "event")))
               (Mod.structure (convert_def strict_records definitions module_base event)));
        ])
  in
  CCIO.with_out
    (Filename.concat output_dir (output_name ^ ".ml"))
    (fun oc -> CCIO.write_line oc (Pprintast.string_of_structure structure))

let convert non_strict_records input_file output_name output_dir search_path file_link =
  let strict_records = not non_strict_records in
  let json =
    Json_schema_flatten.flatten_document
      ~search_path
      ~file_link
      ~root_file:input_file
      (Yojson.Safe.from_file input_file)
  in
  match Document.of_yojson json with
  | Ok document -> convert_document strict_records output_dir output_name document
  | Error err -> print_endline err

let flatten input_file search_path =
  Json_schema_flatten.flatten_document
    ~search_path
    ~file_link:[]
    ~root_file:input_file
    (Yojson.Safe.from_file input_file)
  |> Yojson.Safe.pretty_to_string
  |> print_endline

let cmds = Cmdline.[ convert_cmd convert; flatten_cmd flatten ]

let () =
  let info = Cmdliner.Cmd.info "json_schema_hooks_cli" in
  exit @@ Cmdliner.Cmd.eval @@ Cmdliner.Cmd.group ~default:Cmdline.default_cmd info cmds
