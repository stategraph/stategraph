type err =
  [ `Invalid_block_structure_err of string
  | `Invalid_expr_type_err of string
  | `Missing_field_err of string * string
  | `Unexpected_json_type_err of string * string
  | `Unknown_expr_type_err of string
  | `Invalid_attr_type_err of string
  ]
[@@deriving show]

module Expr = Hcl_parser_value.Expr
module Obj_key = Hcl_parser_value.Obj_key
module Template_part = Hcl_parser_value.Template_part
module Block_label = Hcl_parser_value.Block_label

module Schema = struct
  module Path_map = CCMap.Make (struct
    type t = string list [@@deriving ord]
  end)

  type t = int Path_map.t

  let make pairs = Path_map.of_list pairs
  let union a b = Path_map.union (fun _k _a b -> Some b) a b

  (* Standard Terraform block types and their label counts.
     Paths are used to disambiguate blocks from attributes at different nesting
     levels.  For example, ["terraform"; "backend"] maps to 1 label, while
     ["data"; "backend"] has no entry and is treated as an attribute.
     0-label blocks are included so external JSON (without List wrapper) is
     still recognized as blocks rather than attributes. *)
  let tf =
    make
      [
        (* Top-level blocks — from configFileSchema in parser_config.go *)
        ([ "resource" ], 2);
        ([ "data" ], 2);
        ([ "ephemeral" ], 2);
        ([ "variable" ], 1);
        ([ "output" ], 1);
        ([ "provider" ], 1);
        ([ "module" ], 1);
        ([ "check" ], 1);
        ([ "action" ], 2);
        ([ "terraform" ], 0);
        ([ "locals" ], 0);
        ([ "moved" ], 0);
        ([ "import" ], 0);
        ([ "removed" ], 0);
        (* Nested in terraform — from terraformBlockSchema *)
        ([ "terraform"; "backend" ], 1);
        ([ "terraform"; "cloud" ], 0);
        ([ "terraform"; "required_providers" ], 0);
        ([ "terraform"; "provider_meta" ], 1);
        ([ "terraform"; "encryption" ], 0);
        (* Nested in resource — from ResourceBlockSchema in resource.go *)
        ([ "resource"; "lifecycle" ], 0);
        ([ "resource"; "connection" ], 0);
        ([ "resource"; "provisioner" ], 1);
        (* Nested in resource > lifecycle *)
        ([ "resource"; "lifecycle"; "precondition" ], 0);
        ([ "resource"; "lifecycle"; "postcondition" ], 0);
        ([ "resource"; "lifecycle"; "action_trigger" ], 0);
        (* Nested in data — from dataBlockSchema *)
        ([ "data"; "lifecycle" ], 0);
        ([ "data"; "lifecycle"; "precondition" ], 0);
        ([ "data"; "lifecycle"; "postcondition" ], 0);
        (* Nested in variable — from variableBlockSchema in named_values.go *)
        ([ "variable"; "validation" ], 0);
        (* Nested in output — from outputBlockSchema *)
        ([ "output"; "precondition" ], 0);
        (* Nested in action — from actionBlockSchema in action.go *)
        ([ "action"; "config" ], 0);
        (* Nested in check — from checkBlockSchema in checks.go *)
        ([ "check"; "data" ], 2);
        ([ "check"; "assert" ], 0);
      ]
end

(* Check if a string is a pure template interpolation: "${...}" with nothing else.
   Uses Hcl_ast.parse_template_string and checks if result is a single Interpolation.
   Malformed templates ([Error _]) and any other shape fall through to [false].

   "Nothing else" includes whitespace: [" ${x} "] is a template that renders a padded string, so
   unwrapping it to the bare expression would drop the padding. *)
let is_pure_interpolation_string s =
  match Hcl_ast.parse_template_string s with
  | Ok (Some [ Template_part.Interpolation _ ]) -> true
  | _ -> false

(* Extract the expression from a template interpolation string "${...}" *)
let unwrap_interpolation s =
  (* Remove "${" prefix and "}" suffix *)
  let without_prefix = CCString.drop 2 s in
  let without_suffix = CCString.take (CCString.length without_prefix - 1) without_prefix in
  CCString.trim without_suffix

(* Wrap an expression in template interpolation syntax "${ ... }" *)
let wrap_interpolation expr_str = "${ " ^ expr_str ^ " }"

(* Recover an expression that was serialized as the wrapped form ["${ <expr> }"]
   by [expr_to_json] / [Safe.of_expr]. Unlike [is_pure_interpolation_string], this
   does NOT require [parse_template_string] to round-trip the inner text: an object
   or heredoc body carrying quotes/backslashes (e.g. a cloud-build [script]) desyncs
   the template lexer, which previously failed the pure-interpolation check and
   collapsed the whole value back to a literal string — double-escaping its [${]
   introducers to [$${]. Parsing the unwrapped text directly with [of_expr_string]
   avoids that.

   This is unambiguous: a genuine literal [Expr.String] is serialized via
   [escape_literal], so a literal whose text begins with [${] is stored as [$${...].
   Any single-[$] ["${ ... }"] that parses as an expression therefore can only be a
   wrapped expression, never a literal. Multi-part templates ([foo${x}], [${x}${y}])
   fail [of_expr_string] and fall through to the template path unchanged.

   The [${] / [}] have to sit at the very ends of the string, with no whitespace outside them:
   [wrap_interpolation] puts its padding INSIDE the braces, so anything outside is the author's own
   template text. [" ${var.x} "] is a two-space-padded string, and reading it as [var.x] both drops
   the padding — a spurious plan diff ever after — and changes the type, since an unwrapped number
   stops being stringified. *)
let wrapped_expr_of_string s =
  if CCString.prefix ~pre:"${" s && CCString.suffix ~suf:"}" s then
    CCOption.of_result @@ Hcl_ast.of_expr_string (unwrap_interpolation s)
  else None

(* Convert an expression to JSON using template interpolation for complex expressions *)
let rec expr_to_json expr =
  match expr with
  | Expr.String s ->
      (* A JSON string value is itself HCL template syntax, so a literal [${]
         must be re-escaped to [$${] — otherwise it round-trips back as an
         interpolation. [escape_literal] is the inverse of the [unescape_literal]
         applied to [Expr.String] at parse time. *)
      `String (Hcl_ast_template.escape_literal s)
  | Expr.Int i -> `Int i
  | Expr.Float f -> `Float f
  | Expr.Bool b -> `Bool b
  | Expr.Null -> `Null
  | Expr.Tuple elements -> `List (CCList.map expr_to_json elements)
  | Expr.Object pairs
    when CCList.for_all
           (fun (key, _value) ->
             match key with
             | Obj_key.Bare _ | Obj_key.Quoted _ -> true
             | _ -> false)
           pairs ->
      (* [Bare] and [Quoted] both denote literal string keys, so they map
         cleanly to JSON [`Assoc]. JSON loses the bareword-vs-quoted
         distinction; the round-trip via [json_to_expr] picks [Bare] as
         the default — matching what most JSON-authored Terraform writes. *)
      `Assoc
        (CCList.map
           (fun (key, value) ->
             match key with
             | Obj_key.Bare s | Obj_key.Quoted s -> (s, expr_to_json value)
             | _ -> assert false)
           pairs)
  | Expr.Template parts ->
      (* Render as RAW template content (literals verbatim, only [${]/[%{] escaped) so
         [json_to_expr]'s raw re-parse round-trips it; the quoted form backslash-escapes
         embedded double-quotes which the re-parse reads as a literal backslash
         (over-escaping). Mirrors the [Safe.of_expr] Template case. *)
      `String (Hcl_ast.To_string.heredoc_template parts)
  | Expr.Id _
  | Expr.Object _
  | Expr.Fun_call _
  | Expr.For_tuple _
  | Expr.For_object _
  | Expr.Cond _
  | Expr.Idx _
  | Expr.Attr _
  | Expr.Splat
  | Expr.Not _
  | Expr.Minus _
  | Expr.Add _
  | Expr.Subtract _
  | Expr.Mult _
  | Expr.Div _
  | Expr.Log_and _
  | Expr.Log_or _
  | Expr.Equal _
  | Expr.Not_equal _
  | Expr.Gt _
  | Expr.Lt _
  | Expr.Gte _
  | Expr.Lte _
  | Expr.Mod _
  | Expr.Heredoc _
  | Expr.Heredoc' _
  | Expr.Template_heredoc _
  | Expr.Ellipsis _ ->
      (* Complex expressions (including Objects) - wrap in interpolation syntax *)
      `String (wrap_interpolation (Hcl_ast.To_string.expr expr))

(* Convert JSON back to an expression, unwrapping template interpolations *)
let rec json_to_expr (json : Yojson.Safe.t) =
  match json with
  | `String s -> (
      match wrapped_expr_of_string s with
      (* Wrapped expression "${ expr }" - unwrap to the inner expression (preserves type) *)
      | Some expr -> Ok expr
      | None -> (
          (* Check for template syntax and parse if present. Malformed templates
             ([%{else}], [${}], unterminated [%{if}]) bubble up as
             [`Invalid_expr_type_err] so callers don't silently round-trip the
             garbled bytes back as an [Expr.String] literal. *)
          match Hcl_ast.parse_template_string s with
          | Ok (Some parts) -> Ok (Expr.Template parts)
          (* No template syntax: resolve [$${] / [%%{] escapes so the literal
             matches what the HCL parser produces, mirroring [transform_string]. *)
          | Ok None -> Ok (Expr.String (Hcl_ast_template.unescape_literal s))
          | Error _ -> Error (`Invalid_expr_type_err s)))
  | `Int i -> Ok (Expr.Int i)
  | `Float f -> Ok (Expr.Float f)
  | `Bool b -> Ok (Expr.Bool b)
  | `Null -> Ok Expr.Null
  | `List elements ->
      let rec convert_list acc = function
        | [] -> Ok (Expr.Tuple (CCList.rev acc))
        | x :: xs -> (
            match json_to_expr x with
            | Ok expr -> convert_list (expr :: acc) xs
            | Error e -> Error e)
      in
      convert_list [] elements
  | `Assoc pairs ->
      let rec convert_pairs acc = function
        | [] -> Ok (Expr.Object (CCList.rev acc))
        | (key, value) :: rest -> (
            match json_to_expr value with
            | Ok expr ->
                (* [Obj_key.Bare]: default to bareword keys, more idiomatic
                   than quoting every JSON key. The [Bare]-vs-[Quoted]
                   distinction is lost on JSON encoding anyway. *)
                convert_pairs ((Obj_key.Bare key, expr) :: acc) rest
            | Error e -> Error e)
      in
      convert_pairs [] pairs
  | `Intlit s -> Error (`Invalid_expr_type_err ("intlit: " ^ s))

(* Convert a block body (list of AST values) to JSON *)
let rec body_to_json body =
  let fields =
    CCList.map
      (fun value ->
        match value with
        | Hcl_parser_value.Attribute (name, expr) -> (`Attr, name, expr_to_json expr)
        | Hcl_parser_value.Block { type_; labels; body } ->
            let nested = block_to_json_value type_ labels body in
            (`Block, type_, nested))
      body
  in
  (* Merge duplicate block keys into arrays per HCL JSON spec *)
  let seen = Hashtbl.create 16 in
  let order = ref [] in
  CCList.iter
    (fun (kind, key, value) ->
      match kind with
      | `Attr -> order := (key, `Single value) :: !order
      | `Block -> (
          match Hashtbl.find_opt seen key with
          | None ->
              let r = ref [ value ] in
              Hashtbl.replace seen key r;
              order := (key, `Block_ref r) :: !order
          | Some r -> r := value :: !r))
    fields;
  let merged =
    CCList.rev_map
      (fun (key, entry) ->
        match entry with
        | `Single v -> (key, v)
        | `Block_ref r -> (
            let items = CCList.rev !r in
            match items with
            | [ single ] -> (key, single)
            | _ ->
                (* Flatten: each item is `List [body], concat into one list *)
                let flattened =
                  CCList.flat_map
                    (fun item ->
                      match item with
                      | `List inner -> inner
                      | other -> [ other ])
                    items
                in
                (key, `List flattened)))
      !order
  in
  `Assoc merged

(* Convert a block with its labels to a nested JSON structure.
   When labels are exhausted, wrap the body in a single-element list to distinguish
   block bodies from label nesting during deserialization. *)
and block_to_json_value _type_ labels body =
  match labels with
  | [] -> `List [ body_to_json body ]
  | Block_label.Id s :: rest | Block_label.Lit s :: rest ->
      `Assoc [ (s, block_to_json_value _type_ rest body) ]

(* Convert an HCL AST to JSON *)
let of_ast ast = body_to_json ast

(* Decode JSON back to an AST block, given the block type, remaining label count,
   accumulated labels, schema, and the nested JSON structure.
   When label_count > 0, peel one label from a single-key assoc.
   When label_count = 0, unwrap the List body wrapper. *)
let rec json_to_block schema path type_ labels label_count (json : Yojson.Safe.t) =
  let open CCResult.Infix in
  match label_count with
  | n when n > 0 -> (
      match json with
      | `Assoc pairs ->
          (* one block per name key: a multi-key assoc encodes repeated blocks
             (multiple names under a type). *)
          CCResult.map_l
            (fun (label, nested) ->
              json_to_block schema path type_ (labels @ [ Block_label.Lit label ]) (n - 1) nested)
            pairs
          >|= CCList.flatten
      | _ -> Error (`Invalid_block_structure_err (Yojson.Safe.to_string json)))
  | _ -> (
      let body_block pairs =
        json_to_body schema path pairs
        >>= fun body -> Ok (Hcl_parser_value.Block { type_; labels; body })
      in
      (* label_count = 0: a List wraps one or more bodies (an array of bodies under
         a label encodes repeated blocks); a bare Assoc is a single unwrapped body. *)
      match json with
      | `List items ->
          CCResult.map_l
            (function
              | `Assoc pairs -> body_block pairs
              | item -> Error (`Invalid_block_structure_err (Yojson.Safe.to_string item)))
            items
      | `Assoc pairs -> body_block pairs >>= fun b -> Ok [ b ]
      | _ -> Error (`Invalid_block_structure_err (Yojson.Safe.to_string json)))

(* Decode a list of JSON key-value pairs to AST body elements *)
and json_to_body schema path pairs =
  let open CCResult.Infix in
  let rec loop acc = function
    | [] -> Ok (CCList.rev acc)
    | (key, _value) :: rest when String.equal key "//" ->
        (* Handle the special case "//" for comments attribute (defined in the spec) *)
        loop acc rest
    | (key, value) :: rest -> (
        match Schema.Path_map.find_opt (path @ [ key ]) schema with
        | Some label_count ->
            expand_schema_block schema (path @ [ key ]) key label_count value
            >>= fun blocks -> loop (CCList.rev_append blocks acc) rest
        | None ->
            json_to_expr value
            >>= fun expr -> loop (Hcl_parser_value.Attribute (key, expr) :: acc) rest)
  in
  loop [] pairs

(* Expand a single Assoc of first-labels into blocks *)
and expand_schema_assoc schema path key label_count pairs =
  let open CCResult.Infix in
  let rec loop acc = function
    | [] -> Ok (CCList.rev acc)
    | (label, nested) :: rest ->
        json_to_block schema path key [ Block_label.Lit label ] (label_count - 1) nested
        >>= fun blocks -> loop (CCList.rev_append blocks acc) rest
  in
  loop [] pairs

(* Expand a schema-identified block.
   For label_count > 0: value is an Assoc (labels as keys) or List of Assocs
   (multiple blocks of same type merged by of_ast).
   For label_count = 0: value is an Assoc (block body) or List (multiple/wrapped blocks). *)
and expand_schema_block schema path key label_count (json : Yojson.Safe.t) =
  let open CCResult.Infix in
  match label_count with
  | 0 ->
      (* 0-label block: Assoc is body, List is multiple blocks or of_ast wrapper *)
      expand_zero_label_block schema path key json
  | _ -> (
      match json with
      | `Assoc pairs -> expand_schema_assoc schema path key label_count pairs
      | `List items ->
          let rec loop acc = function
            | [] -> Ok (CCList.rev acc)
            | `Assoc pairs :: rest ->
                expand_schema_assoc schema path key label_count pairs
                >>= fun blocks -> loop (CCList.rev_append blocks acc) rest
            | item :: _ -> Error (`Invalid_block_structure_err (Yojson.Safe.to_string item))
          in
          loop [] items
      | _ -> Error (`Invalid_block_structure_err (Yojson.Safe.to_string json)))

(* Expand a 0-label block from its JSON value.
   Accepts List-wrapped (from of_ast), bare Assoc (from external JSON), or List of Assocs. *)
and expand_zero_label_block schema path key (json : Yojson.Safe.t) =
  let open CCResult.Infix in
  match json with
  | `List items ->
      let rec loop acc = function
        | [] -> Ok (CCList.rev acc)
        | item :: rest ->
            json_to_block schema path key [] 0 (`List [ item ])
            >>= fun blocks -> loop (CCList.rev_append blocks acc) rest
      in
      loop [] items
  | `Assoc pairs ->
      (* Bare Assoc: the body itself (external JSON without List wrapper) *)
      json_to_body schema path pairs
      >>= fun body -> Ok [ Hcl_parser_value.Block { type_ = key; labels = []; body } ]
  | _ -> Error (`Invalid_block_structure_err (Yojson.Safe.to_string json))

(* Convert JSON back to AST *)
let to_ast ?(schema = Schema.tf) json =
  match json with
  | `Assoc pairs -> json_to_body schema [] pairs
  | _ -> Error (`Unexpected_json_type_err ("object", Yojson.Safe.to_string json))

module Safe = struct
  type err =
    [ `Safe_invalid_json_structure_err of string
    | `Safe_invalid_expr_err of string
    | `Safe_unexpected_type_err of string * string
    ]
  [@@deriving show]

  type block = {
    type_ : string; [@key "type"]
    labels : string list;
    attrs : Yojson.Safe.t list;
  }
  [@@deriving yojson]

  let of_expr expr =
    match expr with
    | Expr.String s -> `String (Hcl_ast_template.escape_literal s)
    | Expr.Int i -> `Int i
    | Expr.Float f -> `Float f
    | Expr.Bool b -> `Bool b
    | Expr.Null -> `Null
    | Expr.Template parts ->
        (* Render the template as RAW content (literals verbatim, only [${]/[%{]
           introducers escaped) -- NOT the quoted form. [to_expr] re-parses this
           string as raw template content ([parse_template_string]), matching the
           plain [Expr.String] encode ([escape_literal]). The quoted form
           ([To_string.template] -> [escape_hcl_string]) backslash-escapes embedded
           double-quotes, which the raw re-parse then reads as a literal backslash, so
           each store/reify pass doubled the backslashes on quoted content. *)
        `String (Hcl_ast.To_string.heredoc_template parts)
    | Expr.Id _
    | Expr.Tuple _
    | Expr.Object _
    | Expr.Fun_call _
    | Expr.For_tuple _
    | Expr.For_object _
    | Expr.Cond _
    | Expr.Idx _
    | Expr.Attr _
    | Expr.Splat
    | Expr.Not _
    | Expr.Minus _
    | Expr.Add _
    | Expr.Subtract _
    | Expr.Mult _
    | Expr.Div _
    | Expr.Log_and _
    | Expr.Log_or _
    | Expr.Equal _
    | Expr.Not_equal _
    | Expr.Gt _
    | Expr.Lt _
    | Expr.Gte _
    | Expr.Lte _
    | Expr.Mod _
    | Expr.Heredoc _
    | Expr.Heredoc' _
    | Expr.Template_heredoc _
    | Expr.Ellipsis _ -> `String (wrap_interpolation (Hcl_ast.To_string.expr expr))

  let to_expr (json : Yojson.Safe.t) =
    match json with
    | `String s -> (
        match wrapped_expr_of_string s with
        | Some expr -> Ok expr
        | None -> (
            match Hcl_ast.parse_template_string s with
            | Ok (Some parts) -> Ok (Expr.Template parts)
            (* No template syntax: resolve [$${] / [%%{] escapes, mirroring
               [transform_string] and [json_to_expr]. *)
            | Ok None -> Ok (Expr.String (Hcl_ast_template.unescape_literal s))
            | Error _ -> Error (`Safe_invalid_expr_err s)))
    | `Int i -> Ok (Expr.Int i)
    | `Float f -> Ok (Expr.Float f)
    | `Bool b -> Ok (Expr.Bool b)
    | `Null -> Ok Expr.Null
    | `Assoc _ | `List _ | `Intlit _ ->
        Error
          (`Safe_unexpected_type_err
             ("primitive or interpolation string", Yojson.Safe.to_string json))

  let label_to_string = function
    | Block_label.Lit s -> s
    | Block_label.Id s -> wrap_interpolation s

  let label_of_string s =
    if is_pure_interpolation_string s then Ok (Block_label.Id (unwrap_interpolation s))
    else Ok (Block_label.Lit s)

  let rec of_singleton value =
    match value with
    | Hcl_parser_value.Attribute (name, expr) -> `Assoc [ (name, of_expr expr) ]
    | Hcl_parser_value.Block { type_; labels; body } ->
        block_to_yojson
          {
            type_;
            labels = CCList.map label_to_string labels;
            attrs = CCList.map of_singleton body;
          }

  let rec to_singleton (json : Yojson.Safe.t) =
    let open CCResult.Infix in
    match block_of_yojson json with
    | Ok { type_; labels; attrs } ->
        let rec parse_labels acc = function
          | [] -> Ok (CCList.rev acc)
          | s :: rest -> label_of_string s >>= fun l -> parse_labels (l :: acc) rest
        in
        parse_labels [] labels
        >>= fun labels ->
        let rec parse_attrs acc = function
          | [] -> Ok (CCList.rev acc)
          | item :: rest -> to_singleton item >>= fun attr -> parse_attrs (attr :: acc) rest
        in
        parse_attrs [] attrs >>= fun body -> Ok (Hcl_parser_value.Block { type_; labels; body })
    | Error _ -> (
        match json with
        | `Assoc [ (key, value) ] ->
            to_expr value >>= fun expr -> Ok (Hcl_parser_value.Attribute (key, expr))
        | _ ->
            Error
              (`Safe_invalid_json_structure_err
                 ("expected block or single-key attribute object: " ^ Yojson.Safe.to_string json)))

  let of_ast ast = `List (CCList.map of_singleton ast)

  let to_ast (json : Yojson.Safe.t) =
    let open CCResult.Infix in
    match json with
    | `List items ->
        let rec loop acc = function
          | [] -> Ok (CCList.rev acc)
          | item :: rest -> to_singleton item >>= fun value -> loop (value :: acc) rest
        in
        loop [] items
    | _ -> Error (`Safe_unexpected_type_err ("array", Yojson.Safe.to_string json))
end
