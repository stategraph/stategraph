(** HCL parsing to an AST that mirrors hclsyntax's.

    {1 What this AST represents, and what it does not}

    This is an abstract syntax tree in the same sense hclsyntax's is, and deliberately no richer: it
    carries what a config MEANS, not how it was written. Surface syntax that hclsyntax discards is
    absent here too — the [-] of a [<<-] heredoc and its body's original indentation (the
    common-indent strip is applied while parsing, as hclsyntax applies it), redundant parentheses,
    the column of a heredoc's closing marker, comments, and line structure. A number is a [float] or
    an [int], not the lexeme that produced it.

    That alignment is an invariant, not an accident. The fixture goldens in [tests/hcl_ast] hold
    this parser and the Go shim (hclsyntax) to the same AST for every fixture, with
    [ast_divergent_positive_fixtures] empty. Representing something hclsyntax throws away therefore
    costs that parity for every affected fixture, which is why enriching the AST is not the way to
    preserve surface syntax.

    Terraform keeps surface syntax in a different representation: hclwrite's CST, which is what
    [tofu fmt] rewrites. Byte-level fidelity to a source file — preserving comments, layout, or
    [<<-] — is a token-preserving printer, a separate concern from this AST. What {!To_string} does
    guarantee is that its output loads and means the same thing; see [Hcl_ast_to_string]. *)

type pos = {
  lnum : int;
  offset : int;
}
[@@deriving show, eq]

(** [Error(position, input_we're_failing_on, error_message)] *)
type err = [ `Error of pos option * string * string ] [@@deriving show, eq]

(* No [show] or [pp] in the deriving clause: they are in [Hcl_ast_to_string] *)
type t = Hcl_parser_value.t list [@@deriving eq, yojson]

(** Interface of our HCL parser, whether it's our implementation or the shim-based one *)
module type PARSER = sig
  val of_string : string -> (t, [> err ]) result
  val of_expr_string : string -> (Hcl_parser_value.Expr.t, [> err ]) result

  (** [parse_template_string s] is [Ok None] when [s] contains no template syntax, [Ok (Some parts)]
      for a parsed template, and [Error] for a malformed template ([%{else}], [${}], unterminated
      [%{if}], etc.). *)
  val parse_template_string :
    string -> (Hcl_parser_value.Template_part.t list option, [> err ]) result
end

module Tests : sig
  (** [Menhir] exposes the hand-written Menhir parser directly. {b Only call this module in tests!}

      Production code should use the top-level functions ({!of_string} etc.). *)
  module Menhir : PARSER

  (** [Shim] routes parsing through the [sg_hcl_shim] subprocess, which wraps hashicorp/hcl/v2's
      native parser. {b Only call this module in tests!}

      Production code should use the top-level functions ({!of_string} etc.). *)
  module Shim : PARSER
end

(** Parse HCL source using the hand-written Menhir parser. *)
val of_string : string -> (t, [> err ]) result

(** Parse a single HCL expression (what appears inside [${...}] interpolations), using the Menhir
    parser. *)
val of_expr_string : string -> (Hcl_parser_value.Expr.t, [> err ]) result

(** Parse a string containing template syntax into a [Template_part.t list], using the Menhir
    parser. [Ok None] when the string contains no template syntax; [Ok (Some parts)] for a parsed
    template; [Error] for a malformed template ([%{else}], [${}], unterminated [%{if}], etc.). *)
val parse_template_string :
  string -> (Hcl_parser_value.Template_part.t list option, [> err ]) result

(** [unescape_literal s] resolves template escape sequences in a literal template body ([$${] ->
    [${], [%%{] -> [%{]); all other characters pass through unchanged. Apply this to a template body
    that {!parse_template_string} classified as pure-literal ([Ok None]) so escape sequences are
    still resolved (they are otherwise resolved inline while parsing a template with live syntax).
*)
val unescape_literal : string -> string

(** [map_expr f ast] recursively walks the AST, applying [f] to each expression. If [f] returns
    [Some replacement], that expression is used (without further recursion into it). If [f] returns
    [None], the traversal recurses into the expression's children. *)
val map_expr : (Hcl_parser_value.Expr.t -> Hcl_parser_value.Expr.t option) -> t -> t

(** [map f ast] applies [f] to each top-level item in the AST. *)
val map : (Hcl_parser_value.t -> Hcl_parser_value.t) -> t -> t

(** [map_in_expr f expr] is the expression-level counterpart of {!map_expr}: it walks a single
    expression bottom-up applying [f], returning [f]'s replacement when non-[None] and recursing
    otherwise. Useful for callers that need to apply [map_expr]-style rewriting to one expression
    without re-wrapping it in a body. *)
val map_in_expr :
  (Hcl_parser_value.Expr.t -> Hcl_parser_value.Expr.t option) ->
  Hcl_parser_value.Expr.t ->
  Hcl_parser_value.Expr.t

(** [fold_expr ~f ~init expr] is {!map_in_expr} with an accumulator that the walk passes down and
    back, starting from [init]. *)
val fold_expr :
  f:('a -> Hcl_parser_value.Expr.t -> ('a * Hcl_parser_value.Expr.t) option) ->
  init:'a ->
  Hcl_parser_value.Expr.t ->
  'a * Hcl_parser_value.Expr.t

(** [find_attr name body] returns the expression of the first attribute named [name] in [body], or
    [None] if no such attribute exists. *)
val find_attr : string -> Hcl_parser_value.t list -> Hcl_parser_value.Expr.t option

(** HCL AST → string conversion. Implementation lives in [Hcl_ast_to_string]; this sub-module is the
    public entry point. *)
module To_string : sig
  (** [pp_ast] renders HCL source text rather than the deriving-show debug dump; use it as
      [~pp:Hcl_ast.To_string.pp_ast] in test assertions. [show_ast] is an alias of {!ast}. *)
  type ast = t [@@deriving show]

  (** Convert an HCL AST back to its source-code string representation. *)
  val ast : ast -> string

  (** Convert template parts to HCL string representation (without surrounding quotes). *)
  val template : Hcl_parser_value.Template_part.t list -> string

  (** Render template parts as a heredoc body: literal bytes verbatim (newlines kept raw), with only
      the [${] / [%{] introducers re-escaped. Reconstructs the raw body of a [Template_heredoc]. *)
  val heredoc_template : Hcl_parser_value.Template_part.t list -> string

  (** Convert an expression to its HCL string representation. *)
  val expr : Hcl_parser_value.Expr.t -> string

  (** [expr_capped ~max_len e] renders [e] like {!expr} but stops once [max_len] bytes are produced,
      appending ["..."]. The render is abandoned mid-walk when the budget is spent, so the cost is
      O(max_len) rather than O(size of [e]) — for callers that render one large expression per line
      (e.g. a per-step trace) where the full text is neither readable nor affordable. *)
  val expr_capped : max_len:int -> Hcl_parser_value.Expr.t -> string

  (** [files ?comment_filenames files] concatenates the printed forms of each AST in [files]. With
      [comment_filenames:true] (the default) each entry is prefixed with a [# <filename>] HCL
      comment. Files are separated by a blank line. *)
  val files : ?comment_filenames:bool -> (string * ast) list -> string
end

(** Canonicalize an AST so that inputs which mean the same thing to OpenTofu but differ only in
    surface form collapse to one representation — for equality/hashing consumers such as revision
    comparison. Implementation lives in [Hcl_ast_normalize]; this sub-module is the public entry
    point.

    Normalized: object/map key order (stable sort on the evaluated key, last-wins preserved), the
    [Bare]/[Quoted] object-key distinction, body item order (attributes sorted by name and hoisted
    above child blocks, which keep their relative order), and the [Id]/[Lit] block-label
    distinction. {b Not} normalized: [Tuple] element order — a HCL [[...]] is a [Tuple] whether it
    is an ordered list or an order-insensitive set, and the AST carries no type information to
    distinguish them, so reordering could corrupt a genuine list. *)
module Normalize : sig
  (** Splice nested single-template interpolations into the parent's part list: [${"${X}"}] ->
      [${X}]. Recurses through [Template]/[Fun_call]/[Tuple]/[Object]; a wrapper buried inside a
      [Cond]/[Idx]/operator arm is left as-is. Callable on its own, and applied by the entry points
      below when [~normalize_templates:true]. *)
  val template : Hcl_parser_value.Expr.t -> Hcl_parser_value.Expr.t

  (** Normalize a single expression (recursively). With [~normalize_templates:true] (default
      [false]), also applies {!template} to flatten wrapped single-template interpolations. *)
  val expr : ?normalize_templates:bool -> Hcl_parser_value.Expr.t -> Hcl_parser_value.Expr.t

  (** Normalize a single top-level item (attribute or block, recursively). With
      [~normalize_templates:true] (default [false]), also applies {!template} to each contained
      attribute expression. *)
  val value : ?normalize_templates:bool -> Hcl_parser_value.t -> Hcl_parser_value.t

  (** Normalize a whole AST ([value] over each top-level item). With [~normalize_templates:true]
      (default [false]), also applies {!template} to each contained attribute expression. *)
  val ast : ?normalize_templates:bool -> t -> t
end
