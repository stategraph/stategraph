module T = Mql_parser

exception Lex_err of string

let digit = [%sedlex.regexp? '0' .. '9']
let exp = [%sedlex.regexp? 'e' | 'E']
let plus_minus = [%sedlex.regexp? '+' | '-']
let hex_digit = [%sedlex.regexp? '0' .. '9' | 'a' .. 'f' | 'A' .. 'F']
let identifier_start = [%sedlex.regexp? 'a' .. 'z' | 'A' .. 'Z' | '_']
let identifier_rest = [%sedlex.regexp? 'a' .. 'z' | 'A' .. 'Z' | '_' | '0' .. '9']

(* [AT TIME ZONE] is lexed as ONE token rather than three keywords: reserving
   [time] and [zone] individually would stop any column with those names from
   parsing, and neither is reserved in PostgreSQL.  Spelled out case-insensitively
   with flexible inter-word space, which is also stricter than the hand-enumerated
   case variants used by [is distinct from] above. *)
let ci_at = [%sedlex.regexp? ('a' | 'A'), ('t' | 'T')]
let ci_time = [%sedlex.regexp? ('t' | 'T'), ('i' | 'I'), ('m' | 'M'), ('e' | 'E')]
let ci_zone = [%sedlex.regexp? ('z' | 'Z'), ('o' | 'O'), ('n' | 'N'), ('e' | 'E')]
let at_time_zone = [%sedlex.regexp? ci_at, Plus white_space, ci_time, Plus white_space, ci_zone]

(* A type name of more than one word.  The lexer reads it as one token, for the
   same reason as [AT TIME ZONE]. *)
let ci_with = [%sedlex.regexp? ('w' | 'W'), ('i' | 'I'), ('t' | 'T'), ('h' | 'H')]
let ci_out = [%sedlex.regexp? ('o' | 'O'), ('u' | 'U'), ('t' | 'T')]
let ci_no = [%sedlex.regexp? ('n' | 'N'), ('o' | 'O')]

let ci_action =
  [%sedlex.regexp? ('a' | 'A'), ('c' | 'C'), ('t' | 'T'), ('i' | 'I'), ('o' | 'O'), ('n' | 'N')]

let with_time_zone = [%sedlex.regexp? ci_with, Plus white_space, ci_time, Plus white_space, ci_zone]

let without_time_zone =
  [%sedlex.regexp? ci_with, ci_out, Plus white_space, ci_time, Plus white_space, ci_zone]

let no_action = [%sedlex.regexp? ci_no, Plus white_space, ci_action]

(* [WITH ORDINALITY] after a call in a FROM clause.  The lexer reads it as one
   token, for the same reason as [AT TIME ZONE]: [ordinality] is then not a
   keyword, and the parser does not confuse this [WITH] with the [WITH] of a
   CTE. *)
let ci_ordinality =
  [%sedlex.regexp?
    ( ('o' | 'O'),
      ('r' | 'R'),
      ('d' | 'D'),
      ('i' | 'I'),
      ('n' | 'N'),
      ('a' | 'A'),
      ('l' | 'L'),
      ('i' | 'I'),
      ('t' | 'T'),
      ('y' | 'Y') )]

let with_ordinality = [%sedlex.regexp? ci_with, Plus white_space, ci_ordinality]

(* Locking clauses are lexed as whole phrases for the same reason as
   [AT TIME ZONE]: [update], [share], [key], [no], [skip] and [locked] are all
   non-reserved in PostgreSQL and all plausible column names -- [revision_hashes]
   already has a [key] column. Reserving them individually would break those
   queries. *)
let ci_for = [%sedlex.regexp? ('f' | 'F'), ('o' | 'O'), ('r' | 'R')]
let ci_key = [%sedlex.regexp? ('k' | 'K'), ('e' | 'E'), ('y' | 'Y')]

let ci_update =
  [%sedlex.regexp? ('u' | 'U'), ('p' | 'P'), ('d' | 'D'), ('a' | 'A'), ('t' | 'T'), ('e' | 'E')]

let ci_share = [%sedlex.regexp? ('s' | 'S'), ('h' | 'H'), ('a' | 'A'), ('r' | 'R'), ('e' | 'E')]
let ci_skip = [%sedlex.regexp? ('s' | 'S'), ('k' | 'K'), ('i' | 'I'), ('p' | 'P')]

let ci_locked =
  [%sedlex.regexp? ('l' | 'L'), ('o' | 'O'), ('c' | 'C'), ('k' | 'K'), ('e' | 'E'), ('d' | 'D')]

let ci_nowait =
  [%sedlex.regexp? ('n' | 'N'), ('o' | 'O'), ('w' | 'W'), ('a' | 'A'), ('i' | 'I'), ('t' | 'T')]

let sp = [%sedlex.regexp? Plus white_space]
let for_update = [%sedlex.regexp? ci_for, sp, ci_update]
let for_no_key_update = [%sedlex.regexp? ci_for, sp, ci_no, sp, ci_key, sp, ci_update]
let for_share = [%sedlex.regexp? ci_for, sp, ci_share]
let for_key_share = [%sedlex.regexp? ci_for, sp, ci_key, sp, ci_share]
let skip_locked = [%sedlex.regexp? ci_skip, sp, ci_locked]

(* [LOCK TABLE] and the [IN ... MODE] phrase of a table lock are lexed as whole
   phrases for the same reason as [AT TIME ZONE]: [lock], [table], [share],
   [exclusive] and [mode] are all non-reserved in PostgreSQL and plausible
   column names -- [x.mode] is a field access.  Reserving them one by one would
   break those queries.  Each [IN ... MODE] branch builds its mode variant
   here, so the phrase can hold only a mode that PostgreSQL names. *)
let ci_lock = [%sedlex.regexp? ('l' | 'L'), ('o' | 'O'), ('c' | 'C'), ('k' | 'K')]
let ci_in = [%sedlex.regexp? ('i' | 'I'), ('n' | 'N')]
let ci_table = [%sedlex.regexp? ('t' | 'T'), ('a' | 'A'), ('b' | 'B'), ('l' | 'L'), ('e' | 'E')]

let ci_access =
  [%sedlex.regexp? ('a' | 'A'), ('c' | 'C'), ('c' | 'C'), ('e' | 'E'), ('s' | 'S'), ('s' | 'S')]

let ci_row = [%sedlex.regexp? ('r' | 'R'), ('o' | 'O'), ('w' | 'W')]

let ci_exclusive =
  [%sedlex.regexp?
    ( ('e' | 'E'),
      ('x' | 'X'),
      ('c' | 'C'),
      ('l' | 'L'),
      ('u' | 'U'),
      ('s' | 'S'),
      ('i' | 'I'),
      ('v' | 'V'),
      ('e' | 'E') )]

let ci_mode = [%sedlex.regexp? ('m' | 'M'), ('o' | 'O'), ('d' | 'D'), ('e' | 'E')]
let lock_table = [%sedlex.regexp? ci_lock, sp, ci_table]
let in_access_share_mode = [%sedlex.regexp? ci_in, sp, ci_access, sp, ci_share, sp, ci_mode]
let in_row_share_mode = [%sedlex.regexp? ci_in, sp, ci_row, sp, ci_share, sp, ci_mode]
let in_row_exclusive_mode = [%sedlex.regexp? ci_in, sp, ci_row, sp, ci_exclusive, sp, ci_mode]
let in_share_mode = [%sedlex.regexp? ci_in, sp, ci_share, sp, ci_mode]

let in_share_row_exclusive_mode =
  [%sedlex.regexp? ci_in, sp, ci_share, sp, ci_row, sp, ci_exclusive, sp, ci_mode]

let in_exclusive_mode = [%sedlex.regexp? ci_in, sp, ci_exclusive, sp, ci_mode]
let in_access_exclusive_mode = [%sedlex.regexp? ci_in, sp, ci_access, sp, ci_exclusive, sp, ci_mode]
let lexeme buf = Sedlexing.Utf8.lexeme buf

(* Numeric literals are read with the OCaml readers, which are wider than the
   grammar: [int_of_string] raises [Failure] on a literal above [max_int], and
   [float_of_string] answers [Float.infinity] for a literal too large to hold.
   Both are refused here with [Lex_err]: an out-of-range literal is input the
   lexer cannot turn into a token, and a non-finite float would later render
   to text that cannot be read back. *)
let integer_of_lexeme buf =
  match int_of_string_opt (lexeme buf) with
  | Some i -> T.INTEGER i
  | None -> raise (Lex_err "Integer literal is out of range")

let float_of_lexeme buf =
  let f = float_of_string (lexeme buf) in
  if Float.is_finite f then T.FLOAT f else raise (Lex_err "Float literal is out of range")

let rec token ~variables buf =
  match%sedlex buf with
  | "select" | "SELECT" -> T.SELECT
  | "from" | "FROM" -> T.FROM
  | "inner" | "INNER" -> T.INNER
  | "left" | "LEFT" -> T.LEFT
  | "right" | "RIGHT" -> T.RIGHT
  | "join" | "JOIN" -> T.JOIN
  | "full" | "FULL" -> T.FULL
  | "cross" | "CROSS" -> T.CROSS
  | "outer" | "OUTER" -> T.OUTER
  | "using" | "USING" -> T.USING
  | "where" | "WHERE" -> T.WHERE
  | "in" | "IN" -> T.IN
  | "like" | "LIKE" -> T.LIKE
  | "ilike" | "ILIKE" -> T.ILIKE
  | "is not" | "IS not" | "is NOT" | "IS NOT" -> T.IS_NOT
  | "is distinct from"
  | "IS distinct from"
  | "IS DISTINCT from"
  | "IS DISTINCT FROM"
  | "is DISTINCT FROM"
  | "is distinct FROM" -> T.IS_DISTINCT_FROM
  | "is not distinct from"
  | "IS not distinct from"
  | "IS NOT distinct from"
  | "IS NOTDISTINCT from"
  | "IS NOT DISTINCT FROM"
  | "is NOT DISTINCT FROM"
  | "is not DISTINCT FROM"
  | "is not distinct FROM" -> T.IS_NOT_DISTINCT_FROM
  (* Standalone [DISTINCT].  The multi-word [is distinct from] tokens above win
     by sedlex's longest match, so this only fires on a bare [distinct]. *)
  | "distinct" | "DISTINCT" -> T.DISTINCT
  | "case" | "CASE" -> T.CASE
  | "when" | "WHEN" -> T.WHEN
  | "then" | "THEN" -> T.THEN
  | "else" | "ELSE" -> T.ELSE
  | "end" | "END" -> T.END
  | "interval" | "INTERVAL" -> T.INTERVAL
  (* DML keywords.  These DO become reserved, unlike the locking phrases above:
     each starts a statement and cannot be lexed as a phrase without swallowing
     legitimate uses ([select delete from t] would eat a [delete from]).  A column
     actually named one of these is still reachable by quoting it. *)
  | "insert" | "INSERT" -> T.INSERT
  | "into" | "INTO" -> T.INTO
  | "values" | "VALUES" -> T.VALUES
  | "update" | "UPDATE" -> T.UPDATE
  | "set" | "SET" -> T.SET
  | "delete" | "DELETE" -> T.DELETE
  | "returning" | "RETURNING" -> T.RETURNING
  | "conflict" | "CONFLICT" -> T.CONFLICT
  | "do" | "DO" -> T.DO
  | "nothing" | "NOTHING" -> T.NOTHING
  | "default" | "DEFAULT" -> T.DEFAULT
  (* DDL keywords.  Reserved for the same reason as the DML ones: each is
     structural rather than a value, and a column named one of them is still
     reachable by quoting. *)
  | "create" | "CREATE" -> T.CREATE
  | "table" | "TABLE" -> T.TABLE
  | "index" | "INDEX" -> T.INDEX
  | "view" | "VIEW" -> T.VIEW
  | "function" | "FUNCTION" -> T.FUNCTION
  | "alter" | "ALTER" -> T.ALTER
  | "drop" | "DROP" -> T.DROP
  | "add" | "ADD" -> T.ADD
  | "column" | "COLUMN" -> T.COLUMN
  | "constraint" | "CONSTRAINT" -> T.CONSTRAINT
  | "constraints" | "CONSTRAINTS" -> T.CONSTRAINTS
  | "deferred" | "DEFERRED" -> T.DEFERRED
  | "immediate" | "IMMEDIATE" -> T.IMMEDIATE
  | "primary" | "PRIMARY" -> T.PRIMARY
  | "foreign" | "FOREIGN" -> T.FOREIGN
  | "references" | "REFERENCES" -> T.REFERENCES
  | "unique" | "UNIQUE" -> T.UNIQUE
  | "check" | "CHECK" -> T.CHECK
  | "if" | "IF" -> T.IF
  | "temp" | "TEMP" -> T.TEMP
  | "temporary" | "TEMPORARY" -> T.TEMPORARY
  | "concurrently" | "CONCURRENTLY" -> T.CONCURRENTLY
  | "cascade" | "CASCADE" -> T.CASCADE
  | "restrict" | "RESTRICT" -> T.RESTRICT
  | "rename" | "RENAME" -> T.RENAME
  | "to" | "TO" -> T.TO
  | "type" | "TYPE" -> T.TYPE
  | "comment" | "COMMENT" -> T.COMMENT
  | "truncate" | "TRUNCATE" -> T.TRUNCATE
  | "analyze" | "ANALYZE" -> T.ANALYZE
  | "replace" | "REPLACE" -> T.REPLACE
  | "only" | "ONLY" -> T.ONLY
  | "key" | "KEY" -> T.KEY_KW
  (* [LOCK TABLE t IN ... MODE].  One token for [lock table] and one per whole
     [in ... mode] phrase -- see the comment at their regexp. *)
  | lock_table -> T.LOCK_TABLE
  | in_access_share_mode -> T.LOCK_MODE Mql_ast.Lock_mode_access_share
  | in_row_share_mode -> T.LOCK_MODE Mql_ast.Lock_mode_row_share
  | in_row_exclusive_mode -> T.LOCK_MODE Mql_ast.Lock_mode_row_exclusive
  | in_share_mode -> T.LOCK_MODE Mql_ast.Lock_mode_share
  | in_share_row_exclusive_mode -> T.LOCK_MODE Mql_ast.Lock_mode_share_row_exclusive
  | in_exclusive_mode -> T.LOCK_MODE Mql_ast.Lock_mode_exclusive
  | in_access_exclusive_mode -> T.LOCK_MODE Mql_ast.Lock_mode_access_exclusive
  | at_time_zone -> T.AT_TIME_ZONE
  | without_time_zone -> T.WITHOUT_TIME_ZONE
  | with_time_zone -> T.WITH_TIME_ZONE
  | no_action -> T.NO_ACTION
  | with_ordinality -> T.WITH_ORDINALITY
  | "precision" | "PRECISION" -> T.PRECISION
  | "varying" | "VARYING" -> T.VARYING
  | "returns" | "RETURNS" -> T.RETURNS
  | "language" | "LANGUAGE" -> T.LANGUAGE
  | "immutable" | "IMMUTABLE" -> T.IMMUTABLE
  | "stable" | "STABLE" -> T.STABLE
  | "volatile" | "VOLATILE" -> T.VOLATILE
  | "strict" | "STRICT" -> T.STRICT
  | "security" | "SECURITY" -> T.SECURITY
  | "parallel" | "PARALLEL" -> T.PARALLEL
  | "cost" | "COST" -> T.COST
  | "rows" | "ROWS" -> T.ROWS
  | "setof" | "SETOF" -> T.SETOF
  | "trigger" | "TRIGGER" -> T.TRIGGER
  | "before" | "BEFORE" -> T.BEFORE
  | "after" | "AFTER" -> T.AFTER
  | "instead" | "INSTEAD" -> T.INSTEAD
  | "of" | "OF" -> T.OF
  | "each" | "EACH" -> T.EACH
  | "row" | "ROW" -> T.ROW
  | "statement" | "STATEMENT" -> T.STATEMENT
  | "execute" | "EXECUTE" -> T.EXECUTE
  | "extension" | "EXTENSION" -> T.EXTENSION
  | "local" | "LOCAL" -> T.LOCAL
  | "for" | "FOR" -> T.FOR
  | for_no_key_update -> T.FOR_NO_KEY_UPDATE
  | for_key_share -> T.FOR_KEY_SHARE
  | for_update -> T.FOR_UPDATE
  | for_share -> T.FOR_SHARE
  | skip_locked -> T.SKIP_LOCKED
  | ci_nowait -> T.NOWAIT
  | "is" | "IS" -> T.IS
  | "not" | "NOT" -> T.NOT
  | "as" | "AS" -> T.AS
  | "with" | "WITH" -> T.WITH
  | "materialized" | "MATERIALIZED" -> T.MATERIALIZED
  | "group" | "GROUP" -> T.GROUP
  | "having" | "HAVING" -> T.HAVING
  | "order" | "ORDER" -> T.ORDER
  | "by" | "BY" -> T.BY
  | "on" | "ON" -> T.ON
  | "asc" | "ASC" -> T.ASC
  | "desc" | "DESC" -> T.DESC
  | "limit" | "LIMIT" -> T.LIMIT
  | "and" | "AND" -> T.AND
  | "or" | "OR" -> T.OR
  | "filter" | "FILTER" -> T.FILTER
  | "over" | "OVER" -> T.OVER
  | "lateral" | "LATERAL" -> T.LATERAL
  | "array" | "ARRAY" -> T.ARRAY
  | "grouping" | "GROUPING" -> T.GROUPING
  | "generated" | "GENERATED" -> T.GENERATED
  | "grant" | "GRANT" -> T.GRANT
  | "valid" | "VALID" -> T.VALID
  | "revoke" | "REVOKE" -> T.REVOKE
  | "role" | "ROLE" -> T.ROLE
  | "database" | "DATABASE" -> T.DATABASE
  | "login" | "LOGIN" -> T.LOGIN
  | "password" | "PASSWORD" -> T.PASSWORD
  | "always" | "ALWAYS" -> T.ALWAYS
  | "identity" | "IDENTITY" -> T.IDENTITY
  | "stored" | "STORED" -> T.STORED
  | "include" | "INCLUDE" -> T.INCLUDE
  | "commit" | "COMMIT" -> T.COMMIT
  | "server" | "SERVER" -> T.SERVER
  | "options" | "OPTIONS" -> T.OPTIONS
  | "sets" | "SETS" -> T.SETS
  | "recursive" | "RECURSIVE" -> T.RECURSIVE
  | "except" | "EXCEPT" -> T.EXCEPT
  | "intersect" | "INTERSECT" -> T.INTERSECT
  | "offset" | "OFFSET" -> T.OFFSET
  | "nulls" | "NULLS" -> T.NULLS
  | "first" | "FIRST" -> T.FIRST
  | "last" | "LAST" -> T.LAST
  | "escape" | "ESCAPE" -> T.ESCAPE
  | "extract" | "EXTRACT" -> T.EXTRACT
  | "cast" | "CAST" -> T.CAST
  | "substring" | "SUBSTRING" -> T.SUBSTRING
  | "position" | "POSITION" -> T.POSITION
  (* Partitioning.  Reserved like the other DDL keywords: each is structural
     rather than a value, and a column named one of them is still reachable by
     quoting.  [hash] deliberately stays unreserved -- a table or a column with
     that name keeps lexing as an identifier. *)
  | "attach" | "ATTACH" -> T.ATTACH
  | "range" | "RANGE" -> T.RANGE
  | "list" | "LIST" -> T.LIST
  | "partition" | "PARTITION" -> T.PARTITION
  | "true" | "TRUE" -> T.TRUE
  | "false" | "FALSE" -> T.FALSE
  | "null" | "NULL" -> T.NULL
  | "unnest" | "UNNEST" -> T.UNNEST
  | "exists" | "EXISTS" -> T.EXISTS
  | "union" | "UNION" -> T.UNION
  | "all" | "ALL" -> T.ALL
  | "collate" | "COLLATE" -> T.COLLATE
  (* The separator of a named argument: [make_interval(secs => 1)]. *)
  | "=>" -> T.NAMED_ARG
  | "->" -> T.JSON_VAL
  | "->>" -> T.JSON_TEXT
  | '=' -> T.EQUAL
  | "<>" -> T.NOT_EQUAL
  (* PostgreSQL accepts [!=] as a second spelling of [<>].  The AST does not
     record which spelling the SQL used. *)
  | "!=" -> T.NOT_EQUAL
  | '<' -> T.LT
  | "<=" -> T.LTE
  | '>' -> T.GT
  | ">=" -> T.GTE
  | "@>" -> T.JSON_SUBSET
  (* [d ? 'k'] -- does the object hold the key [k]. *)
  | "?" -> T.JSON_HAS_KEY
  | "#>>" -> T.JSON_OBJ_QUERY
  | "#>" -> T.JSON_OBJ_VAL
  | "~" -> T.REGEX_MATCH
  | "!~" -> T.REGEX_NOT_MATCH
  | "~*" -> T.REGEX_IMATCH
  | "!~*" -> T.REGEX_NOT_IMATCH
  | '&' -> T.BIT_AND
  (* The array-type suffix is one token: with [\[] and [\]] separate, [a::text[]]
     and [a::text[1]] are not LR(1)-distinguishable and menhir resolves the
     choice arbitrarily.  [[]] never occurs otherwise -- a subscript always has
     an index between the brackets.  Longest match puts this ahead of [\[]. *)
  | "[]" -> T.ARRAY_SUFFIX
  | '[' -> T.LBRACKET
  | ']' -> T.RBRACKET
  | '(' -> T.LPAREN
  | ')' -> T.RPAREN
  | '+' -> T.PLUS
  | '-' -> T.MINUS
  | '/' -> T.DIV
  | '%' -> T.MOD
  | '*' -> T.STAR
  | ',' -> T.COMMA
  | ';' -> T.SEMICOLON
  | "||" -> T.DOUBLE_PIPE
  | "::" -> T.DOUBLE_COLON
  (* The separator of an array slice: [a[1 : 2]].  The longest match selects [::]
     before this rule. *)
  | ':' -> T.COLON
  | '.' -> T.DOT
  (* Comments, as PostgreSQL defines them.  Both are skipped rather than
     tokenised, so they never reach the parser and are not reproduced by
     [Mql.Ast.to_string].  Listed before ['-'] and ['/'] for readability only --
     sedlex is longest-match, so ["--"] already beats ['-'].  A ['-'] inside a
     string literal is not a comment because [parse_string_literal] consumes to
     the closing quote without coming back here. *)
  | "--" -> line_comment ~variables buf
  | "/*" -> block_comment ~variables ~depth:1 buf
  | "'" -> parse_string_literal buf (Buffer.create 20)
  (* An escape string.  A backslash starts an escape sequence.  The plain form
     holds the backslash with no change.  The token holds the characters the sequence
     stands for, thus the printer writes them back as a plain string. *)
  | ('e' | 'E'), "'" -> parse_escape_string_literal buf (Buffer.create 20)
  | Plus digit, exp, Opt plus_minus, Plus digit -> float_of_lexeme buf
  | Plus digit, '.', Plus digit, exp, Opt plus_minus, Plus digit -> float_of_lexeme buf
  | Plus digit, '.', Plus digit -> float_of_lexeme buf
  | Plus digit -> integer_of_lexeme buf
  | identifier_start, Star identifier_rest ->
      T.IDENTIFIER { Mql_ast.name = lexeme buf; quoted = false }
  (* A quoted identifier.  A doubled quote inside one is an escaped quote,
     mirroring how a string literal escapes its own delimiter.  Everything else
     is taken verbatim, which is the point -- this is how a name that is a
     keyword, or that is case-sensitive, is written. *)
  | '"' -> parse_quoted_identifier buf (Buffer.create 20)
  (* A dollar-quoted string: [$$ ... $$] or [$tag$ ... $tag$].  Longest match is
     what keeps this apart from a [$name] variable -- for [$foo$] this matches 5
     characters and the variable rule only 4, while a bare [$foo] matches only
     the variable rule.  The body is taken verbatim: this is how a function body
     stays opaque instead of being parsed as SQL. *)
  | '$', Star identifier_rest, '$' ->
      let delim = lexeme buf in
      dollar_string buf delim (Buffer.create 64)
  (* A [pgsql_io] named variable.  The name is deliberately stricter than
     [Pgsql_io.Typed_sql.read_variable_name], which also admits a leading digit:
     MQL must not be able to emit a positional [$1]. *)
  | '$', identifier_start, Star identifier_rest ->
      if variables then T.VARIABLE (CCString.drop 1 (lexeme buf))
      else raise (Lex_err (Printf.sprintf "Variables are not enabled: %S" (lexeme buf)))
  | Plus white_space -> token ~variables buf
  | eof -> T.EOF
  | any -> raise (Lex_err (Printf.sprintf "Unexpected character: %S" (lexeme buf)))
  | _ -> raise (Lex_err (Printf.sprintf "Unexpected character: %S" (lexeme buf)))

(* Runs to the end of the line.  [eof] is a valid terminator: the last line of a
   query need not end in a newline. *)
and line_comment ~variables buf =
  match%sedlex buf with
  | '\n' -> token ~variables buf
  | eof -> T.EOF
  | any -> line_comment ~variables buf
  | _ -> raise (Lex_err "Unexpected character in line comment")

(* Block comments nest, as they do in PostgreSQL: ["/* a /* b */ c */"] is one
   comment, so commenting out a region that already contains a comment does what
   the author meant.  [depth] is what makes that work -- the first ["*/"] closes
   only the innermost one.  Unterminated is an error rather than an implicit
   close at eof, since silently swallowing the rest of a query would turn a typo
   into a different query. *)
and block_comment ~variables ~depth buf =
  match%sedlex buf with
  | "/*" -> block_comment ~variables ~depth:(depth + 1) buf
  | "*/" ->
      if depth = 1 then token ~variables buf else block_comment ~variables ~depth:(depth - 1) buf
  | eof -> raise (Lex_err "Unterminated block comment")
  | any -> block_comment ~variables ~depth buf
  | _ -> raise (Lex_err "Unexpected character in block comment")

(* Consume to the matching closing delimiter.  sedlex cannot match a delimiter
   chosen at run time, so the tail is scanned a character at a time and compared
   against [delim]. *)
and dollar_string buf delim acc =
  match%sedlex buf with
  | '$', Star identifier_rest, '$' ->
      let d = lexeme buf in
      if CCString.equal d delim then T.DOLLAR_STRING (delim, Buffer.contents acc)
      else (
        Buffer.add_string acc d;
        dollar_string buf delim acc)
  | eof -> raise (Lex_err ("Unterminated dollar-quoted string: " ^ delim))
  | any ->
      Buffer.add_string acc (lexeme buf);
      dollar_string buf delim acc
  | _ -> raise (Lex_err "Unexpected character in dollar-quoted string")

and parse_quoted_identifier buf acc =
  match%sedlex buf with
  | "\"\"" ->
      Buffer.add_char acc '"';
      parse_quoted_identifier buf acc
  | '"' -> T.IDENTIFIER { Mql_ast.name = Buffer.contents acc; quoted = true }
  | eof -> raise (Lex_err "Unterminated quoted identifier")
  | any ->
      Buffer.add_string acc (lexeme buf);
      parse_quoted_identifier buf acc
  | _ -> raise (Lex_err "Unexpected character in quoted identifier")

and parse_escape_string_literal buf acc =
  match%sedlex buf with
  | "''" ->
      Buffer.add_char acc '\'';
      parse_escape_string_literal buf acc
  | "\\'" ->
      Buffer.add_char acc '\'';
      parse_escape_string_literal buf acc
  | "\\n" ->
      Buffer.add_char acc '\n';
      parse_escape_string_literal buf acc
  | "\\t" ->
      Buffer.add_char acc '\t';
      parse_escape_string_literal buf acc
  | "\\r" ->
      Buffer.add_char acc '\r';
      parse_escape_string_literal buf acc
  | "\\b" ->
      Buffer.add_char acc '\b';
      parse_escape_string_literal buf acc
  | "\\f" ->
      Buffer.add_char acc '\012';
      parse_escape_string_literal buf acc
  | "\\\\" ->
      Buffer.add_char acc '\\';
      parse_escape_string_literal buf acc
  | '\\', any ->
      (* Each other escape is the character after the backslash. *)
      Buffer.add_string acc (CCString.drop 1 (lexeme buf));
      parse_escape_string_literal buf acc
  | "'" -> T.STRING (Buffer.contents acc)
  | eof -> raise (Lex_err "Unterminated escape string")
  | any ->
      Buffer.add_string acc (lexeme buf);
      parse_escape_string_literal buf acc
  | _ -> raise (Lex_err "Unexpected character in escape string")

and parse_string_literal buf acc =
  match%sedlex buf with
  | "''" ->
      Buffer.add_char acc '\'';
      parse_string_literal buf acc
  | "'" -> T.STRING (Buffer.contents acc)
  | any ->
      Buffer.add_string acc (lexeme buf);
      parse_string_literal buf acc
  | _ -> raise (Lex_err "Unexpected character in string literal")
