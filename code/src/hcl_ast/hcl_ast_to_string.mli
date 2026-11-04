(** HCL AST → source-text conversion.

    Re-exposed as [Hcl_ast.To_string], which is the entry point callers should use.

    {1 What this printer guarantees}

    The output is what tofu is handed and what we read back ourselves — from the DB, and on the
    actuator's restore path — so the contract is:

    - it loads: printing always produces text this parser accepts. Output that does not re-parse is
      a failed plan rather than a diff, a strictly worse failure than a wrong value;
    - it means the same thing: the printed config evaluates to the values the source did, down to
      whitespace inside strings and the precision of numbers;
    - it is stable: printing what was just read produces the same text again, so a value does not
      drift across the repeated parse/store/render cycles a reification performs.

    Those three are pinned over the whole fixture corpus by [printer_reparse] in [tests/hcl_ast],
    with value-level expectations taken from tofu in [tests/hcl_ast_to_string] and
    [tests/sg_tf_eval].

    It does NOT reproduce the source's surface syntax, and cannot: the AST does not carry it (see
    [Hcl_ast]). Comments are absent, multi-line expressions collapse to one line, [<<-] prints as
    [<<] over an already-stripped body, every binary operation and conditional is parenthesized, and
    a number prints in a canonical shortest form rather than as it was written. Byte-level agreement
    with [tofu fmt] is therefore not a property this printer can have — [tofu fmt] rewrites
    hclwrite's token-level CST, which preserves exactly what an AST drops. *)

(** [pp_ast] renders HCL source text rather than the deriving-show debug dump; use it as
    [~pp:Hcl_ast.To_string.pp_ast] in test assertions. [show_ast] is an alias of {!ast}. *)
type ast = Hcl_parser_value.t list [@@deriving show]

(** Convert an HCL AST back to its source-code string representation. *)
val ast : ast -> string

(** [escape_hcl_string s] is [s] with each HCL string-literal escape applied: a double quote, a
    backslash, a newline, a carriage return, and a tab each gain a backslash, and the template
    introducers [${] / [%{] are doubled, so the output re-parses to the same literal string rather
    than being interpreted as interpolation. *)
val escape_hcl_string : string -> string

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
    [comment_filenames:true] (the default) each entry is prefixed with a [# <filename>] HCL comment.
    Files are separated by a blank line. *)
val files : ?comment_filenames:bool -> (string * ast) list -> string
