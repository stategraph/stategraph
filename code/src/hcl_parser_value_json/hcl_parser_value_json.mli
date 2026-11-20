(** HCL AST to/from JSON conversion following HashiCorp's HCL JSON format *)

type err =
  [ `Invalid_block_structure_err of string
  | `Invalid_expr_type_err of string
  | `Missing_field_err of string * string
  | `Unexpected_json_type_err of string * string
  | `Unknown_expr_type_err of string
  | `Invalid_attr_type_err of string
  ]
[@@deriving show]

(** Schema for disambiguating blocks from attributes during JSON decoding. Maps full path keys
    (e.g., [["terraform"; "backend"]]) to label counts. This allows the same block type name to be
    treated differently at different nesting levels. *)
module Schema : sig
  type t

  (** Create a schema from a list of (path, label_count) pairs where each path is the full list of
      block type names from the root. For example, [(["terraform"; "backend"], 1)] means ["backend"]
      is a 1-label block only when nested inside ["terraform"]. *)
  val make : (string list * int) list -> t

  (** Default schema for standard Terraform block types. *)
  val tf : t

  (** Combine two schemas. Right-biased: entries in the second schema override the first. *)
  val union : t -> t -> t
end

(** Convert an HCL AST to JSON *)
val of_ast : Hcl_ast.t -> Yojson.Safe.t

(** Convert a single HCL expression to JSON. Primitive values map directly; complex expressions are
    rendered back to HCL string form and wrapped in template interpolation syntax. *)
val expr_to_json : Hcl_parser_value.Expr.t -> Yojson.Safe.t

(** Convert JSON back to a single HCL expression. *)
val json_to_expr : Yojson.Safe.t -> (Hcl_parser_value.Expr.t, [> err ]) result

(** Convert a computed value, such as a state attribute or a data source result, to a literal
    expression. Each JSON string is the string itself: [${] and [%{] in it are text. *)
val literal_to_expr : Yojson.Safe.t -> (Hcl_parser_value.Expr.t, [> err ]) result

(** Convert JSON back to an HCL AST.
    @param schema Block schema for disambiguation. Defaults to {!Schema.tf}. *)
val to_ast : ?schema:Schema.t -> Yojson.Safe.t -> (Hcl_ast.t, [> err ]) result

(** Schema-free JSON encoding of HCL that has a 1-to-1 representation in JSON. Unlike the top-level
    encoding which follows HashiCorp's HCL JSON format and requires a schema to disambiguate blocks
    from attributes during decoding, this encoding is structurally unambiguous: blocks are always
    represented with ["labels"] and ["attrs"] keys, so no external schema or provider knowledge is
    needed to decode.

    Encoding rules:

    - Attributes become single-key JSON objects [{"name": value}]. Literal values (string, int,
      float, bool, null) map directly to JSON. Complex values (lists, objects, expressions) are
      serialized as HCL strings wrapped in template interpolation syntax ["${...}"].

    - Blocks become JSON objects [{"type": "...", "labels": [...], "attrs": [...]}] with the block
      type as a string field alongside labels and attrs. Labels is a JSON array of strings;
      identifier labels are wrapped in ["${...}"] to distinguish them from quoted string labels.
      Attrs is a JSON array where each element is either an attribute or a nested block.

    - The top-level AST is a JSON array of these objects, preserving order and allowing duplicate
      block types. *)
module Safe : sig
  type err =
    [ `Safe_invalid_json_structure_err of string
    | `Safe_invalid_expr_err of string
    | `Safe_unexpected_type_err of string * string
    ]
  [@@deriving show]

  (** Convert an HCL AST to JSON. Maps over the AST list, producing a JSON array where each element
      is a single block or attribute converted via {!of_singleton}. *)
  val of_ast : Hcl_ast.t -> Yojson.Safe.t

  (** Convert JSON back to an HCL AST. Expects a JSON array of singleton objects. *)
  val to_ast : Yojson.Safe.t -> (Hcl_ast.t, [> err ]) result

  (** Convert a single HCL block or attribute to JSON. Blocks produce
      [{"type": "...", "labels": [...], "attrs": [...]}]; attributes produce [{"name": value}]. *)
  val of_singleton : Hcl_parser_value.t -> Yojson.Safe.t

  (** Convert a JSON object back to an HCL block or attribute. Objects with ["type"], ["labels"],
      and ["attrs"] keys are decoded as blocks; single-key objects are decoded as attributes. *)
  val to_singleton : Yojson.Safe.t -> (Hcl_parser_value.t, [> err ]) result

  (** Convert a single HCL expression to JSON. Literal values (string, int, float, bool, null) map
      directly to their JSON equivalents. All other expressions are rendered to HCL string form and
      wrapped in template interpolation syntax ["${...}"]. *)
  val of_expr : Hcl_parser_value.Expr.t -> Yojson.Safe.t

  (** Convert JSON back to a single HCL expression. JSON primitives map to AST literals. Strings
      containing ["${...}"] are unwrapped and parsed as HCL expressions. *)
  val to_expr : Yojson.Safe.t -> (Hcl_parser_value.Expr.t, [> err ]) result
end
