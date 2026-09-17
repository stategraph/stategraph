type pos = {
  lnum : int;
  offset : int;
}
[@@deriving show, eq]

type err = [ `Error of pos option * string * string ] [@@deriving show, eq]

(* No [show] or [pp] in the deriving clause: they are in [Hcl_ast_to_string] *)
type t = Hcl_parser_value.t list [@@deriving eq, yojson]

(* Parsing splits into two backends, exposed via [module Menhir] and
   [module Shim] (the latter under [Tests] since it's only meant to be
   called directly from the test suite). Everything below the module
   definitions is pretty-printer / AST-walker code that is
   parser-agnostic.

   The top-level [of_string] / [of_expr_string] / [parse_template_string]
   always dispatch to Menhir. To exercise the shim, tests call
   [Hcl_ast.Tests.Shim.*] directly. *)

module type PARSER = sig
  val of_string : string -> (t, [> err ]) result
  val of_expr_string : string -> (Hcl_parser_value.Expr.t, [> err ]) result

  (** [parse_template_string s] is [Ok None] when [s] contains no template syntax, [Ok (Some parts)]
      for a parsed template, and [Error] for a malformed template ([%{else}], [${}], unterminated
      [%{if}], etc.). Callers that want to round-trip an opaque string as a [Literal] when it
      contains no [${..}]/[%{..}] should treat both [Ok None] and [Error _] as "no parts" only if
      they're sure they're not silently masking a typo — otherwise propagate the [Error]. *)
  val parse_template_string :
    string -> (Hcl_parser_value.Template_part.t list option, [> err ]) result
end

module Menhir : PARSER = struct
  (* The hand-written Menhir-backend parser. This is the backend exposed
     via the top-level [of_string] etc. All [Hcl_parser] / [Hcl_lexer]
     references live inside this module. *)

  (* The top-level grammar requires [NEWLINE+] after each body item, so we
     append a trailing newline when the source doesn't already end in one.
     A bare trailing [\r] (no [\n] after) is an invalid line ending per
     hclsyntax — leave it as-is so the lexer emits its "Invalid character"
     error instead of silently turning [\r] at EOF into [\r\n]. *)
  let with_trailing_newline s =
    let n = CCString.length s in
    if n = 0 then "\n"
    else
      match s.[n - 1] with
      | '\n' -> s
      | '\r' -> s
      | _ -> s ^ "\n"

  let state checkpoint =
    let module I = Hcl_parser.MenhirInterpreter in
    I.current_state_number checkpoint

  let position checkpoint =
    let module I = Hcl_parser.MenhirInterpreter in
    match I.top checkpoint with
    | None -> None
    | Some (I.Element (_, _, { Lexing.pos_lnum; pos_bol; pos_fname = _; pos_cnum = _ }, _)) ->
        Some { lnum = pos_lnum; offset = pos_bol }

  let rec loop next_token lexbuf checkpoint =
    let module I = Hcl_parser.MenhirInterpreter in
    match checkpoint with
    | I.InputNeeded _ ->
        let token = next_token () in
        let checkpoint = I.offer checkpoint token in
        loop next_token lexbuf checkpoint
    | I.Shifting (_, _, _) | I.AboutToReduce (_, _) ->
        let checkpoint = I.resume checkpoint in
        loop next_token lexbuf checkpoint
    | I.HandlingError env ->
        Error
          (try (position env, Hcl_parser_errors.message (state env))
           with Not_found -> (position env, CCInt.to_string (state env)))
    | I.Accepted ast -> Ok ast
    | I.Rejected -> assert false

  (* Parse an HCL expression from a string using the Menhir grammar. Used
     as the [parse_expr_string] dependency of the template parser (for
     [${...}] and [%{if ...}] / [%{for ...}] content). Routes through
     [expr_paren_only] so NEWLINEs in the interpolation body are
     non-significant, matching how the shim's parser treats interpolation
     bodies. *)
  let parse_expr_string s =
    let lexbuf = Sedlexing.Utf8.from_string (with_trailing_newline (Hcl_ast_utf8.sanitize s)) in
    let lexer = Sedlexing.with_tokenizer Hcl_lexer.token lexbuf in
    match
      loop
        lexer
        lexbuf
        (Hcl_parser.Incremental.expr_paren_only (fst @@ Sedlexing.lexing_positions lexbuf))
    with
    | Ok expr -> Some expr
    | Error _ -> None
    | exception Hcl_lexer.Error _ -> None
    | exception Failure _ -> None

  module T = Hcl_ast_template.Make (struct
    let parse_expr_string = parse_expr_string
  end)

  let of_string s =
    (* Guarantee there is a new line at the end of the file.  The HCL spec
       requires a new line after a block but looks like it will accept
       files that do not have a new line. *)
    let lexbuf = Sedlexing.Utf8.from_string (with_trailing_newline (Hcl_ast_utf8.sanitize s)) in
    let lexer = Sedlexing.with_tokenizer Hcl_lexer.token lexbuf in
    let get_lexing_position () = Sedlexing.lexing_positions lexbuf |> snd in
    let to_pos () =
      let _, pos = Sedlexing.lexing_positions lexbuf in
      { lnum = pos.Lexing.pos_lnum; offset = pos.Lexing.pos_cnum - pos.Lexing.pos_bol }
    in
    match
      loop lexer lexbuf (Hcl_parser.Incremental.main (fst @@ Sedlexing.lexing_positions lexbuf))
    with
    | Ok r ->
        T.transform_ast r
        |> CCResult.map_err (fun e ->
            `Error (Some (to_pos ()), s, Hcl_ast_template.string_of_template_error e))
    | Error (pos, err) -> Error (`Error (pos, s, CCString.trim err))
    | exception (Hcl_lexer.Error { msg; lexeme } as _exn) ->
        let pos = get_lexing_position () in
        let hcl_pos =
          { lnum = pos.Lexing.pos_lnum; offset = pos.Lexing.pos_cnum - pos.Lexing.pos_bol }
        in
        let full_msg =
          if CCString.is_empty lexeme then msg else Printf.sprintf "%s: %S" msg lexeme
        in
        Error (`Error (Some hcl_pos, s, full_msg))
    | exception Failure msg ->
        let pos = get_lexing_position () in
        let hcl_pos =
          { lnum = pos.Lexing.pos_lnum; offset = pos.Lexing.pos_cnum - pos.Lexing.pos_bol }
        in
        Error (`Error (Some hcl_pos, s, msg))
    | exception Sedlexing.MalFormed ->
        let pos = get_lexing_position () in
        let hcl_pos =
          { lnum = pos.Lexing.pos_lnum; offset = pos.Lexing.pos_cnum - pos.Lexing.pos_bol }
        in
        Error (`Error (Some hcl_pos, s, "Invalid UTF-8 encoding"))

  let of_expr_string s =
    let lexbuf = Sedlexing.Utf8.from_string (with_trailing_newline (Hcl_ast_utf8.sanitize s)) in
    let lexer = Sedlexing.with_tokenizer Hcl_lexer.token lexbuf in
    let to_pos () =
      let _, pos = Sedlexing.lexing_positions lexbuf in
      { lnum = pos.Lexing.pos_lnum; offset = pos.Lexing.pos_cnum - pos.Lexing.pos_bol }
    in
    match
      loop
        lexer
        lexbuf
        (Hcl_parser.Incremental.expr_only (fst @@ Sedlexing.lexing_positions lexbuf))
    with
    | Ok expr -> (
        match T.transform_expr expr with
        | Ok e -> Ok e
        | Error err ->
            Error (`Error (Some (to_pos ()), s, Hcl_ast_template.string_of_template_error err)))
    | Error (pos, err) -> Error (`Error (pos, s, CCString.trim err))
    (* [of_string] catches these same three exceptions, and this function catches them for the same
       reason: its type says it answers with a result, and every caller reads it that way.  An
       unterminated quote reaches the lexer as an unclosed multi-line string, thus a malformed
       expression -- a client-supplied canon, an address that is not a traversal -- raises through
       an interface that looks total.

       [Failure] is one of the three because the GRAMMAR's actions raise it, and not only the
       standard library: measured through this function, [(1(2))] answers [Error "Function call
       requires identifier"] from [expr_to_fun_call], and [1e99999999999999999999] answers [Error
       "int_of_string"] from the exponent of a number literal.  Both are malformed input that
       [expr_only] reaches, thus narrowing these arms to the lexer's two exceptions would let them
       escape.  The cost of the broad arm is that a genuine bug inside [loop] also answers [Error]
       with a plausible message; closing that means giving the grammar an exception of its own in
       [hcl_parser.mly] first. *)
    | exception Hcl_lexer.Error { msg; lexeme } ->
        let full_msg =
          if CCString.is_empty lexeme then msg else Printf.sprintf "%s: %S" msg lexeme
        in
        Error (`Error (Some (to_pos ()), s, full_msg))
    | exception Failure msg -> Error (`Error (Some (to_pos ()), s, msg))
    | exception Sedlexing.MalFormed ->
        Error (`Error (Some (to_pos ()), s, "Invalid UTF-8 encoding"))

  let parse_template_string s =
    match T.parse_template_string s with
    | Ok x -> Ok x
    | Error err -> Error (`Error (None, s, Hcl_ast_template.string_of_template_error err))
end

module Shim : PARSER = struct
  (* The native-parser-backed path: delegates to [Hcl_native], which in
     turn drives the [sg_hcl_shim] subprocess. Error values from
     [Hcl_native] are translated into [`Error] so the public signatures of
     [of_string] / [of_expr_string] match [Menhir]. *)

  let to_err s = function
    | Ok v -> Ok v
    | Error (`Hcl_native_error msg) -> Error (`Error (None, s, msg))

  (* The native subprocess promotes [Expr.String] templates but leaves heredoc
     bodies raw, so apply the heredoc-only promotion to produce
     [Template_heredoc] consistently with the Menhir backend. *)
  module T = Hcl_ast_template.Make (struct
    let parse_expr_string s = Hcl_native.parse_expr_string s |> CCResult.to_opt
  end)

  let of_string s =
    let open CCResult.Infix in
    to_err s (Hcl_native.parse_string s)
    >>= fun ast ->
    T.promote_heredocs_ast ast
    |> CCResult.map_err (fun e -> `Error (None, s, Hcl_ast_template.string_of_template_error e))

  let of_expr_string s = to_err s (Hcl_native.parse_expr_string s)

  let parse_template_string s =
    (* Match the Menhir semantics: [Ok None] for plain strings with no
       template syntax, [Ok (Some parts)] when at least one [${..}] /
       [%{..}] appears, [Error _] when the shim rejects the run as
       malformed. hclsyntax would happily parse a plain string into a
       [Literal]-only template, but [Hcl_ast.parse_template_string]
       callers rely on [Ok None] to mean "nothing to interpolate"; the
       leading [contains_template_syntax] check preserves that. *)
    if not (Hcl_ast_template.contains_template_syntax s) then Ok None
    else
      match Hcl_native.parse_template_string s with
      | Ok parts -> Ok (Some parts)
      | Error (`Hcl_native_error msg) -> Error (`Error (None, s, msg))
end

module Tests = struct
  module Menhir = Menhir
  module Shim = Shim
end

let of_string = Menhir.of_string
let of_expr_string = Menhir.of_expr_string
let parse_template_string = Menhir.parse_template_string
let unescape_literal = Hcl_ast_template.unescape_literal
let map_expr = Hcl_ast_walker.map_in_body
let map_in_expr = Hcl_ast_walker.map_in_expr
let map f ast = CCList.map f ast

let find_attr name body =
  CCList.find_map
    (function
      | Hcl_parser_value.Attribute (n, expr) when CCString.equal n name -> Some expr
      | _ -> None)
    body

(* Pretty-printing functions live in [Hcl_ast_to_string] (a sibling module in this package) and are
   re-exposed here as [Hcl_ast.To_string] so callers go through one entry point. *)
module To_string = Hcl_ast_to_string

(* AST normalization lives in [Hcl_ast_normalize] (a sibling module in this package) and is
   re-exposed here as [Hcl_ast.Normalize] so callers go through one entry point. *)
module Normalize = Hcl_ast_normalize
