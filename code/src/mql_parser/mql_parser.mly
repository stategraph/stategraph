%{
(* The first value that is present. A query writes a limit in one place only,
   thus at most one of the two is ever set. *)
let merge_opt a b =
  match a with
  | Some _ -> a
  | None -> b

  open struct module M = Mql_ast end
%}

%token <Mql_ast.ident> IDENTIFIER
%token <string> VARIABLE
%token <string> STRING
%token <string * string> DOLLAR_STRING
%token <int> INTEGER
%token <float> FLOAT

%token LPAREN RPAREN LBRACKET RBRACKET ARRAY_SUFFIX
%token NOT IS IS_NOT IS_DISTINCT_FROM IS_NOT_DISTINCT_FROM
%token SELECT FROM WHERE GROUP HAVING ORDER  LIMIT
%token DISTINCT FILTER OVER PARTITION
%token CASE WHEN THEN ELSE END INTERVAL AT_TIME_ZONE
%token FOR_UPDATE FOR_NO_KEY_UPDATE FOR_SHARE FOR_KEY_SHARE SKIP_LOCKED NOWAIT
%token INSERT INTO VALUES UPDATE SET DELETE RETURNING CONFLICT DO NOTHING DEFAULT
%token CREATE TABLE INDEX VIEW FUNCTION ALTER DROP ADD COLUMN CONSTRAINT
%token CONSTRAINTS DEFERRED IMMEDIATE
%token PRIMARY FOREIGN REFERENCES UNIQUE CHECK IF TEMP TEMPORARY CONCURRENTLY
%token CASCADE RESTRICT RENAME TO TYPE COMMENT TRUNCATE ANALYZE REPLACE ONLY KEY_KW
%token ATTACH RANGE LIST
%token LOCK_TABLE
%token <Mql_ast.lock_table_mode> LOCK_MODE
%token WITH_TIME_ZONE WITHOUT_TIME_ZONE NO_ACTION PRECISION VARYING
%token RETURNS LANGUAGE IMMUTABLE STABLE VOLATILE STRICT SECURITY PARALLEL COST ROWS
%token SETOF TRIGGER BEFORE AFTER INSTEAD OF EACH ROW STATEMENT EXECUTE EXTENSION LOCAL FOR
%token WITH MATERIALIZED AS BY ON RECURSIVE EXCEPT INTERSECT OFFSET NULLS FIRST LAST
%token INNER LEFT RIGHT JOIN FULL CROSS OUTER USING
%token DOT COMMA DOUBLE_COLON COLON SEMICOLON
%token PLUS MINUS STAR DIV MOD DOUBLE_PIPE
%token ASC DESC
%token JSON_VAL JSON_TEXT JSON_OBJ_QUERY JSON_OBJ_VAL JSON_SUBSET
%token REGEX_MATCH REGEX_NOT_MATCH REGEX_IMATCH REGEX_NOT_IMATCH
%token COLLATE WITH_ORDINALITY BIT_AND
%token EQUAL NOT_EQUAL LT LTE GT GTE IN LIKE ILIKE
%token AND OR
%token NULL TRUE FALSE
%token UNNEST EXISTS UNION ALL LATERAL ARRAY ESCAPE EXTRACT SUBSTRING POSITION CAST
%token GROUPING SETS NAMED_ARG GENERATED ALWAYS IDENTITY STORED INCLUDE COMMIT SERVER OPTIONS
%token GRANT REVOKE ROLE DATABASE LOGIN PASSWORD VALID
%token JSON_HAS_KEY

%token EOF

%left OR
%left AND
(* PostgreSQL binds [NOT] looser than [IS] and tighter than [AND], so it reads
   [not a = b] as [not (a = b)] and [not a and b] as [(not a) and b].  The
   production for [NOT expr] takes this precedence -- the [NOT] token itself
   stays at the [IN]/[LIKE] level, where the [DEFAULT] rule above reads it as
   the start of the next column constraint. *)
%nonassoc NOT_EXPR
/* PostgreSQL holds a comparison to no side: [a = b = c] is a fault, and not
   [(a = b) = c].  This grammar must agree with it.  To the left, the printer
   writes [(a = b) = c] as [a = b = c], because this grammar reads that text
   again as the same tree; PostgreSQL then refuses it.  [IS] is below a
   comparison, and [IN] and [LIKE] are above one, as in PostgreSQL. */
%nonassoc IS IS_NOT IS_DISTINCT_FROM IS_NOT_DISTINCT_FROM
%nonassoc EQUAL NOT_EQUAL LT LTE GT GTE
%nonassoc IN LIKE ILIKE NOT
/* [ESCAPE] has a higher precedence than [LIKE].  Thus the parser puts it in
   the [LIKE] and does not close the [LIKE] before it. */
%nonassoc ESCAPE
/* PostgreSQL holds each operator that is not in its table -- [||], the JSON
   operators and the two regular-expression operators -- at one precedence, to
   the left, above a comparison and below [+ - * / %].  This grammar must agree
   with it.  Where the two disagree, the printer writes text that PostgreSQL
   reads as a different expression: [Settle] drops a parenthesis whenever this
   grammar reads the text again as the same tree, and PostgreSQL then groups the
   operators in its own way.  [(a || b) + c] became [a || b + c], which
   PostgreSQL reads as [a || (b + c)]. */
%left DOUBLE_PIPE JSON_VAL JSON_TEXT JSON_OBJ_QUERY JSON_OBJ_VAL JSON_SUBSET JSON_HAS_KEY REGEX_MATCH REGEX_NOT_MATCH REGEX_IMATCH REGEX_NOT_IMATCH BIT_AND
%left PLUS MINUS
%left STAR DIV MOD
%right UMINUS
%left AT_TIME_ZONE
/* In PostgreSQL, [COLLATE] is above [AT TIME ZONE] and below [::]. */
%left COLLATE
%right DOUBLE_COLON
%left LBRACKET
/* Higher than NOT, so that in [DEFAULT false NOT NULL] the [NOT] starts the next
   column constraint instead of being shifted into the default expression.  One
   token of lookahead cannot tell [NOT NULL] from [NOT LIKE]; SQL resolves it the
   same way, and a DEFAULT whose expression begins [NOT LIKE] does not occur. */
%nonassoc DEFAULT_EXPR

%start <Mql_ast.t> start
%start <Mql_ast.t list> queries
%start <Mql_ast.expr> standalone_expr

%%

start:
  | q = statement EOF
    { q }
    [@name start]
  | q = statement SEMICOLON EOF
    { q }
    [@name start_terminated]

query_list:
  | q = statement
    { [ q ] }
    [@name query_list_one]
  | qs = query_list SEMICOLON q = statement
    { qs @ [ q ] }
    [@name query_list_more]

queries:
  | qs = query_list EOF
    { qs }
    [@name queries]
  | qs = query_list SEMICOLON EOF
    { qs }
    [@name queries_terminated]

standalone_expr:
  | e = expr EOF
    { e }
    [@name standalone_expr]

/* A CTE body is a full statement, not just a query: PostgreSQL allows a
   data-modifying CTE ([with d as (delete ... returning ...) select ...]).  It is
   gated the same way as a top-level one. */
cte:
  | tbl = ident cs = cte_columns_opt AS LPAREN q = statement RPAREN
    { (M.Cte_default, tbl, cs, q) }
    [@name cte_definition]
  | tbl = ident cs = cte_columns_opt AS MATERIALIZED LPAREN q = statement RPAREN
    { (M.Cte_materialized, tbl, cs, q) }
    [@name cte_definition_materialized]
  /* [NOT MATERIALIZED] makes PostgreSQL put the body of the CTE into the
     query that reads it. */
  | tbl = ident cs = cte_columns_opt AS NOT MATERIALIZED LPAREN q = statement RPAREN
    { (M.Cte_not_materialized, tbl, cs, q) }
    [@name cte_definition_not_materialized]

/* [WITH c(a, b) AS (...)] -- the names of the columns of the CTE. */
cte_columns_opt:
  | /* empty */
    { [ ] }
    [@name no_cte_columns]
  | LPAREN cs = using_cols RPAREN
    { cs }
    [@name cte_columns]

/* [WITH RECURSIVE] permits a CTE to refer to itself. */
recursive_opt:
  | /* empty */
    { false }
    [@name no_recursive]
  | RECURSIVE
    { true }
    [@name recursive]

ctes:
  | c = cte
    { [ c ] }
    [@name cte]
  | cs = ctes COMMA c = cte
    { cs @ [ c ] }
    [@name ctes]

/* [FOR UPDATE OF t] -- the tables that the lock holds. */
lock_of:
  | /* empty */
    { [ ] }
    [@name no_lock_of]
  | OF ns = using_cols
    { ns }
    [@name lock_of]

lock_strength:
  | FOR_UPDATE
    { M.Lock_update }
    [@name lock_update]
  | FOR_NO_KEY_UPDATE
    { M.Lock_no_key_update }
    [@name lock_no_key_update]
  | FOR_SHARE
    { M.Lock_share }
    [@name lock_share]
  | FOR_KEY_SHARE
    { M.Lock_key_share }
    [@name lock_key_share]

lock_wait:
  | /* empty */
    { M.Lock_wait }
    [@name lock_wait_default]
  | NOWAIT
    { M.Lock_nowait }
    [@name lock_nowait]
  | SKIP_LOCKED
    { M.Lock_skip_locked }
    [@name lock_skip_locked]

locking:
  | s = lock_strength o = lock_of w = lock_wait
    { { M.strength = s; wait = w; of_ = o } }
    [@name locking]

/* --- DDL shared pieces --------------------------------------------------- */

/* Words PostgreSQL does not reserve, so they must stay usable as ordinary
   names -- [resources.type] and [revision_hashes.key] are real columns here.
   This mirrors PostgreSQL's own [unreserved_keyword] rule. */
constraints_mode:
  | DEFERRED
    { true }
    [@name constraints_deferred]
  | IMMEDIATE
    { false }
    [@name constraints_immediate]

non_reserved:
  | CONSTRAINTS
    { M.ident "constraints" }
    [@name nonreserved_constraints]
  | DEFERRED
    { M.ident "deferred" }
    [@name nonreserved_deferred]
  | IMMEDIATE
    { M.ident "immediate" }
    [@name nonreserved_immediate]
  | TYPE
    { M.ident "type" }
    [@name nonreserved_type]
  | KEY_KW
    { M.ident "key" }
    [@name nonreserved_key]
  | COMMENT
    { M.ident "comment" }
    [@name nonreserved_comment]
  | TO
    { M.ident "to" }
    [@name nonreserved_to]
  | REPLACE
    { M.ident "replace" }
    [@name nonreserved_replace]
  | INDEX
    { M.ident "index" }
    [@name nonreserved_index]
  | CASCADE
    { M.ident "cascade" }
    [@name nonreserved_cascade]
  | RESTRICT
    { M.ident "restrict" }
    [@name nonreserved_restrict]
  | TEMP
    { M.ident "temp" }
    [@name nonreserved_temp]
  | TEMPORARY
    { M.ident "temporary" }
    [@name nonreserved_temporary]
  | ANALYZE
    { M.ident "analyze" }
    [@name nonreserved_analyze]
  | TRUNCATE
    { M.ident "truncate" }
    [@name nonreserved_truncate]
  | ADD
    { M.ident "add" }
    [@name nonreserved_add]
  | VIEW
    { M.ident "view" }
    [@name nonreserved_view]
  | FUNCTION
    { M.ident "function" }
    [@name nonreserved_function]
  | RENAME
    { M.ident "rename" }
    [@name nonreserved_rename]
  /* PostgreSQL does not reserve these words.  Thus each one is usable as a
     name.
     [instances.identity] and [tenant_invitations.role] are real columns.

     [recursive] is not in this list.  It is directly after [with].  A CTE name is
     also in that position, thus the parser cannot identify which one it is.  No
     name in this repository is [recursive]. */
  | IDENTITY
    { M.ident "identity" }
    [@name nonreserved_identity]
  | STORED
    { M.ident "stored" }
    [@name nonreserved_stored]
  | INCLUDE
    { M.ident "include" }
    [@name nonreserved_include]
  | COMMIT
    { M.ident "commit" }
    [@name nonreserved_commit]
  | SERVER
    { M.ident "server" }
    [@name nonreserved_server]
  | OPTIONS
    { M.ident "options" }
    [@name nonreserved_options]
  | ALWAYS
    { M.ident "always" }
    [@name nonreserved_always]
  | GENERATED
    { M.ident "generated" }
    [@name nonreserved_generated]
  | FIRST
    { M.ident "first" }
    [@name nonreserved_first]
  | LAST
    { M.ident "last" }
    [@name nonreserved_last]
  | NULLS
    { M.ident "nulls" }
    [@name nonreserved_nulls]
  | SETS
    { M.ident "sets" }
    [@name nonreserved_sets]
  | GROUPING
    { M.ident "grouping" }
    [@name nonreserved_grouping]
  | ROLE
    { M.ident "role" }
    [@name nonreserved_role]
  | LOGIN
    { M.ident "login" }
    [@name nonreserved_login]
  | PASSWORD
    { M.ident "password" }
    [@name nonreserved_password]
  | DATABASE
    { M.ident "database" }
    [@name nonreserved_database]
  | ROW
    { M.ident "row" }
    [@name nonreserved_row]
  /* [count(*) AS rows] in a test of this repository. */
  | ROWS
    { M.ident "rows" }
    [@name nonreserved_rows]
  /* [local] names the hint channel of [hcl_hints] and a column of
     [transaction_hints]; PostgreSQL reads it as a column too.  The [SET LOCAL]
     of the grammar keeps [local_opt], and the parser shifts [LOCAL] there. */
  | LOCAL
    { M.ident "local" }
    [@name nonreserved_local]

ident:
  | i = IDENTIFIER
    { i }
    [@name ident_plain]
  | k = non_reserved
    { k }
    [@name ident_keyword]

/* The text that [position] finds.  A full expression here can contain an
   [IN].  Then the parser cannot identify the [IN] that separates the two
   operands.  This repository writes a text to look for, thus a text and a name
   are enough. */
position_needle:
  | s = STRING
    { M.String s }
    [@name position_needle_string]
  | i = ident
    { M.Identifier i }
    [@name position_needle_name]

/* A name that can have one word before it: a schema before a call,
   or a table before a column.  The two shapes are written out rather than
   made from an optional qualifier, because an optional one cannot be decided
   until the parser has read the dot. */
name_ref:
  | n = ident
    { (None, n) }
    [@name name_ref_bare]
  | q = ident DOT n = ident
    { (Some q, n) }
    [@name name_ref_qualified]

table_name:
  | n = ident
    { { M.qualifier = None; base = n } }
    [@name table_name_bare]
  | q = ident DOT n = ident
    { { M.qualifier = Some q; base = n } }
    [@name table_name_qualified]

table_names:
  | n = table_name
    { [ n ] }
    [@name table_name_one]
  | ns = table_names COMMA n = table_name
    { ns @ [ n ] }
    [@name table_name_more]

if_exists:
  | /* empty */
    { false }
    [@name no_if_exists]
  | IF EXISTS
    { true }
    [@name yes_if_exists]

if_not_exists:
  | /* empty */
    { false }
    [@name no_if_not_exists]
  | IF NOT EXISTS
    { true }
    [@name yes_if_not_exists]

drop_behavior:
  | /* empty */
    { None }
    [@name no_drop_behavior]
  | CASCADE
    { Some M.Cascade }
    [@name drop_cascade]
  | RESTRICT
    { Some M.Restrict }
    [@name drop_restrict]

type_args:
  | /* empty */
    { [ ] }
    [@name no_type_args]
  | LPAREN i = INTEGER RPAREN
    { [ i ] }
    [@name type_arg_one]
  | LPAREN i = INTEGER COMMA j = INTEGER RPAREN
    { [ i; j ] }
    [@name type_arg_two]

array_dims:
  | /* empty */
    { 0 }
    [@name no_array_dims]
  | d = array_dims ARRAY_SUFFIX
    { d + 1 }
    [@name more_array_dims]

type_extra:
  | /* empty */
    { M.No_extra }
    [@name no_type_extra]
  | WITH_TIME_ZONE
    { M.With_time_zone }
    [@name type_with_time_zone]
  | WITHOUT_TIME_ZONE
    { M.Without_time_zone }
    [@name type_without_time_zone]
  | PRECISION
    { M.Precision }
    [@name type_precision]
  | VARYING
    { M.Varying }
    [@name type_varying]

/* The word that names a type.  Some type names are also keywords of this
   grammar, thus [ident] alone is not enough.  Both productions make the same
   value, thus the printer can always use the first one. */
type_word:
  | i = ident
    { i }
    [@name type_word_ident]
  | INTERVAL
    { M.ident "interval" }
    [@name type_word_interval]

/* The target of a cast.  It can have arguments, an added word, and array
   suffixes, in the same way as a type name in a schema statement.

   The name is not qualified.  PostgreSQL reads [x::a.b] as a cast to the type
   [a.b], but this repository writes no such cast, and a qualifier here would
   make [x::a.b] ambiguous with a field selection. */
cast_type:
  | n = type_word a = type_args e = type_extra d = array_dims
    { { M.type_ident = { M.qualifier = None; base = n }; type_extra = e; args = a; array_dims = d } }
    [@name cast_type]

type_name:
  /* Args before the trailing words: [numeric(10, 2)], [timestamp(3) with time
     zone], [double precision].  A second argument slot after the words would be
     ambiguous with the first, so [character varying(255)] is not accepted -- it
     does not occur in this repo. */
  | n = table_name a = type_args e = type_extra d = array_dims
    { { M.type_ident = n; type_extra = e; args = a; array_dims = d } }
    [@name type_name]

ref_act:
  | CASCADE
    { M.Ract_cascade }
    [@name ract_cascade]
  | RESTRICT
    { M.Ract_restrict }
    [@name ract_restrict]
  | SET NULL
    { M.Ract_set_null }
    [@name ract_set_null]
  | SET DEFAULT
    { M.Ract_set_default }
    [@name ract_set_default]
  | NO_ACTION
    { M.Ract_no_action }
    [@name ract_no_action]

ref_action:
  | ON DELETE a = ref_act
    { M.On_delete a }
    [@name ref_on_delete]
  | ON UPDATE a = ref_act
    { M.On_update a }
    [@name ref_on_update]

ref_actions:
  | /* empty */
    { [ ] }
    [@name no_ref_actions]
  | as_ = ref_actions a = ref_action
    { as_ @ [ a ] }
    [@name more_ref_actions]

references_clause:
  | REFERENCES t = table_name acts = ref_actions
    { { M.ref_table = t; ref_columns = [ ]; ref_actions = acts } }
    [@name references_bare]
  | REFERENCES t = table_name LPAREN cs = using_cols RPAREN acts = ref_actions
    { { M.ref_table = t; ref_columns = cs; ref_actions = acts } }
    [@name references_cols]

column_constraint:
  | NOT NULL
    { M.Not_null }
    [@name col_not_null]
  | NULL
    { M.Null_allowed }
    [@name col_null]
  | DEFAULT e = expr %prec DEFAULT_EXPR
    { M.Default_value e }
    [@name col_default]
  | PRIMARY KEY_KW
    { M.Col_primary_key }
    [@name col_primary_key]
  | UNIQUE
    { M.Col_unique }
    [@name col_unique]
  | CHECK LPAREN e = expr RPAREN
    { M.Col_check e }
    [@name col_check]
  | r = references_clause
    { M.Col_references r }
    [@name col_references]
  | CONSTRAINT n = IDENTIFIER c = column_constraint
    { M.Col_named_constraint (n, c) }
    [@name col_named_constraint]
  /* PostgreSQL calculates the value from the row. */
  | GENERATED ALWAYS AS LPAREN e = expr RPAREN STORED
    { M.Col_generated_stored e }
    [@name col_generated_stored]
  /* PostgreSQL gives the value. */
  | GENERATED ALWAYS AS IDENTITY
    { M.Col_generated_identity }
    [@name col_generated_identity]

column_constraints:
  | /* empty */
    { [ ] }
    [@name no_column_constraints]
  | cs = column_constraints c = column_constraint
    { cs @ [ c ] }
    [@name more_column_constraints]

column_def:
  | n = ident t = type_name cs = column_constraints
    { { M.col_name = n; col_type = t; col_constraints = cs } }
    [@name column_def]

/* [ON COMMIT DROP] -- a temporary table that PostgreSQL deletes at the end of the transaction. */
on_commit_drop_opt:
  | /* empty */
    { false }
    [@name no_on_commit_drop]
  | ON COMMIT DROP
    { true }
    [@name on_commit_drop]

foreign_option:
  | n = ident v = STRING
    { (n, v) }
    [@name foreign_option]

foreign_options:
  | o = foreign_option
    { [ o ] }
    [@name foreign_option_one]
  | os = foreign_options COMMA o = foreign_option
    { os @ [ o ] }
    [@name foreign_option_more]

table_constraint:
  | PRIMARY KEY_KW LPAREN cs = using_cols RPAREN inc = index_include_opt
    { M.Tbl_primary_key { columns = cs; include_ = inc } }
    [@name tbl_primary_key]
  /* Change an index that is already present to a constraint. */
  | PRIMARY KEY_KW USING INDEX i = ident
    { M.Tbl_primary_key_using_index i }
    [@name tbl_primary_key_using_index]
  | UNIQUE USING INDEX i = ident
    { M.Tbl_unique_using_index i }
    [@name tbl_unique_using_index]
  | UNIQUE LPAREN cs = using_cols RPAREN inc = index_include_opt
    { M.Tbl_unique { columns = cs; include_ = inc } }
    [@name tbl_unique]
  | CHECK LPAREN e = expr RPAREN
    { M.Tbl_check e }
    [@name tbl_check]
  | FOREIGN KEY_KW LPAREN cs = using_cols RPAREN r = references_clause
    { M.Tbl_foreign_key (cs, r) }
    [@name tbl_foreign_key]
  | CONSTRAINT n = IDENTIFIER c = table_constraint
    { M.Tbl_named_constraint (n, c) }
    [@name tbl_named_constraint]

/* --- DDL statements ------------------------------------------------------ */

table_option:
  | n = ident EQUAL e = expr
    { (n, e) }
    [@name table_option]

table_options:
  | o = table_option
    { [ o ] }
    [@name table_option_one]
  | os = table_options COMMA o = table_option
    { os @ [ o ] }
    [@name table_option_more]

/* How a partitioned table splits its rows. */
partition_strategy:
  | RANGE
    { M.Ps_range }
    [@name partition_strategy_range]
  | LIST
    { M.Ps_list }
    [@name partition_strategy_list]

/* [PARTITION BY strategy (key)] -- the clause of a partitioned table. */
table_partition:
  | PARTITION BY s = partition_strategy LPAREN es = expr_list RPAREN
    { { M.strategy = s; key = es } }
    [@name table_partition]

table_partition_opt:
  | /* empty */
    { None }
    [@name no_table_partition]
  | p = table_partition
    { Some p }
    [@name yes_table_partition]

/* The slice of the parent's values that one partition holds.  The bound is
   mandatory: [PARTITION OF] with no bound is not a form this repository
   writes. */
partition_bound:
  | FOR VALUES FROM LPAREN lo = expr_list RPAREN TO LPAREN hi = expr_list RPAREN
    { M.Pb_range (lo, hi) }
    [@name bound_range]
  | FOR VALUES IN LPAREN es = expr_list RPAREN
    { M.Pb_in es }
    [@name bound_in]
  | DEFAULT
    { M.Pb_default }
    [@name bound_default]

alter_action:
  | ADD COLUMN e = if_not_exists c = column_def
    { M.Add_column { if_not_exists = e; column = c } }
    [@name add_column]
  | ADD c = column_def
    { M.Add_column { if_not_exists = false; column = c } }
    [@name add_column_bare]
  | DROP COLUMN e = if_exists n = IDENTIFIER b = drop_behavior
    { M.Drop_column { if_exists = e; name = n; behavior = b } }
    [@name drop_column]
  | ALTER COLUMN n = IDENTIFIER a = alter_column_action
    { M.Alter_column (n, a) }
    [@name alter_column]
  | ALTER n = IDENTIFIER a = alter_column_action
    { M.Alter_column (n, a) }
    [@name alter_column_bare]
  | ADD c = table_constraint
    { M.Add_constraint c }
    [@name add_constraint]
  /* [NOT VALID] prevents a read of the rows that are already
     present. */
  | ADD c = table_constraint NOT VALID
    { M.Add_constraint_not_valid c }
    [@name add_constraint_not_valid]
  | DROP CONSTRAINT e = if_exists n = IDENTIFIER b = drop_behavior
    { M.Drop_constraint { if_exists = e; name = n; behavior = b } }
    [@name drop_constraint]
  | RENAME TO n = IDENTIFIER
    { M.Rename_to n }
    [@name rename_to]
  | RENAME COLUMN a = IDENTIFIER TO b = IDENTIFIER
    { M.Rename_column (a, b) }
    [@name rename_column]
  /* The settings of the table. */
  | SET LPAREN os = table_options RPAREN
    { M.Set_options os }
    [@name set_options]
  /* A partition that already holds rows joins the partitioned table. */
  | ATTACH PARTITION n = table_name b = partition_bound
    { M.Attach_partition { name = n; bound = b } }
    [@name attach_partition]

alter_column_action:
  | SET NOT NULL
    { M.Set_not_null }
    [@name set_not_null]
  | DROP NOT NULL
    { M.Drop_not_null }
    [@name drop_not_null]
  | SET DEFAULT e = expr
    { M.Set_default e }
    [@name set_default]
  | DROP DEFAULT
    { M.Drop_default }
    [@name drop_default]
  | TYPE t = type_name
    { M.Set_type { type_ = t; using = None } }
    [@name set_type]
  /* [TYPE t USING e] -- how to change the old value to the new value. */
  | TYPE t = type_name USING e = expr
    { M.Set_type { type_ = t; using = Some e } }
    [@name set_type_using]

alter_actions:
  | a = alter_action
    { [ a ] }
    [@name alter_action_one]
  | as_ = alter_actions COMMA a = alter_action
    { as_ @ [ a ] }
    [@name alter_action_more]

unique_opt:
  | /* empty */
    { false }
    [@name no_unique]
  | UNIQUE
    { true }
    [@name unique]

only_opt:
  | /* empty */
    { false }
    [@name no_only]
  | ONLY
    { true }
    [@name yes_only]

table_item:
  | c = column_def
    { M.Column_def c }
    [@name item_column]
  | c = table_constraint
    { M.Table_constraint c }
    [@name item_constraint]

table_items:
  | i = table_item
    { [ i ] }
    [@name table_item_one]
  | is = table_items COMMA i = table_item
    { is @ [ i ] }
    [@name table_item_more]

temp_opt:
  | /* empty */
    { false }
    [@name no_temp]
  | TEMP
    { true }
    [@name temp]
  | TEMPORARY
    { true }
    [@name temporary]

concurrently_opt:
  | /* empty */
    { false }
    [@name no_concurrently]
  | CONCURRENTLY
    { true }
    [@name concurrently]

or_replace_opt:
  | /* empty */
    { false }
    [@name no_or_replace]
  | OR REPLACE
    { true }
    [@name or_replace]

index_name_opt:
  | /* empty */
    { None }
    [@name no_index_name]
  | n = IDENTIFIER
    { Some n }
    [@name index_name]

index_method_opt:
  | /* empty */
    { None }
    [@name no_index_method]
  | USING m = IDENTIFIER
    { Some m }
    [@name index_method]

/* [gin_trgm_ops] -- the operator class that the index uses for this entry. */
index_opclass_opt:
  | /* empty */
    { None }
    [@name no_index_opclass]
  | c = IDENTIFIER
    { Some c }
    [@name index_opclass]

index_element:
  | e = expr c = index_opclass_opt
    { { M.idx_expr = e; idx_opclass = c; idx_order = None } }
    [@name index_element]
  | e = expr c = index_opclass_opt ASC
    { { M.idx_expr = e; idx_opclass = c; idx_order = Some M.Asc } }
    [@name index_element_asc]
  | e = expr c = index_opclass_opt DESC
    { { M.idx_expr = e; idx_opclass = c; idx_order = Some M.Desc } }
    [@name index_element_desc]

/* [INCLUDE (a, b)] -- columns that the index holds but does not sort on. */
index_include_opt:
  | /* empty */
    { [ ] }
    [@name no_index_include]
  | INCLUDE LPAREN cs = using_cols RPAREN
    { cs }
    [@name index_include]

index_elements:
  | e = index_element
    { [ e ] }
    [@name index_element_one]
  | es = index_elements COMMA e = index_element
    { es @ [ e ] }
    [@name index_element_more]

/* [NULLS NOT DISTINCT] -- see [Mql_ast.Create_index]. */
index_nulls_opt:
  | /* empty */
    { false }
    [@name no_index_nulls]
  | NULLS NOT DISTINCT
    { true }
    [@name index_nulls_not_distinct]

index_where_opt:
  | /* empty */
    { None }
    [@name no_index_where]
  | WHERE e = expr
    { Some e }
    [@name index_where]

view_columns_opt:
  | /* empty */
    { [ ] }
    [@name no_view_columns]
  | LPAREN cs = using_cols RPAREN
    { cs }
    [@name view_columns]


/* --- CREATE FUNCTION / TRIGGER ------------------------------------------- */

func_arg:
  | t = type_name
    { { M.arg_name = None; arg_type = t } }
    [@name func_arg_unnamed]
  | n = ident t = type_name
    { { M.arg_name = Some n; arg_type = t } }
    [@name func_arg_named]

func_args:
  | /* empty */
    { [ ] }
    [@name no_func_args]
  | a = func_arg
    { [ a ] }
    [@name func_arg_one]
  | as_ = func_args COMMA a = func_arg
    { as_ @ [ a ] }
    [@name func_arg_more]

func_return:
  | t = type_name
    { M.Ret_type t }
    [@name ret_type]
  | SETOF t = type_name
    { M.Ret_setof t }
    [@name ret_setof]
  | TABLE LPAREN cs = table_cols RPAREN
    { M.Ret_table cs }
    [@name ret_table]
  | TRIGGER
    { M.Ret_trigger }
    [@name ret_trigger]

table_cols:
  | c = column_def
    { [ c ] }
    [@name table_col_one]
  | cs = table_cols COMMA c = column_def
    { cs @ [ c ] }
    [@name table_col_more]

func_clause:
  | RETURNS r = func_return
    { M.Func_returns r }
    [@name fc_returns]
  | LANGUAGE l = ident
    { M.Func_language l }
    [@name fc_language]
  /* The body is taken verbatim -- it is plpgsql or SQL in its own right. */
  | AS b = DOLLAR_STRING
    { M.Func_as_body b }
    [@name fc_as_body]
  | AS b = STRING
    { M.Func_as_string b }
    [@name fc_as_string]
  | IMMUTABLE
    { M.Func_volatility (M.ident "immutable") }
    [@name fc_immutable]
  | STABLE
    { M.Func_volatility (M.ident "stable") }
    [@name fc_stable]
  | VOLATILE
    { M.Func_volatility (M.ident "volatile") }
    [@name fc_volatile]
  | STRICT
    { M.Func_strict }
    [@name fc_strict]
  | SECURITY k = ident
    { M.Func_security k }
    [@name fc_security]
  | PARALLEL k = ident
    { M.Func_parallel k }
    [@name fc_parallel]
  | COST i = INTEGER
    { M.Func_cost i }
    [@name fc_cost]
  | ROWS i = INTEGER
    { M.Func_rows i }
    [@name fc_rows]

func_clauses:
  | /* empty */
    { [ ] }
    [@name no_func_clauses]
  | cs = func_clauses c = func_clause
    { cs @ [ c ] }
    [@name more_func_clauses]

trigger_timing:
  | BEFORE
    { M.Trg_before }
    [@name trg_before]
  | AFTER
    { M.Trg_after }
    [@name trg_after]
  | INSTEAD OF
    { M.Trg_instead_of }
    [@name trg_instead_of]

trigger_event:
  | INSERT
    { M.Trg_insert }
    [@name trg_insert]
  | UPDATE
    { M.Trg_update [ ] }
    [@name trg_update]
  /* The trigger operates only for these columns. */
  | UPDATE OF cs = using_cols
    { M.Trg_update cs }
    [@name trg_update_of]
  | DELETE
    { M.Trg_delete }
    [@name trg_delete]
  | TRUNCATE
    { M.Trg_truncate }
    [@name trg_truncate]

trigger_events:
  | e = trigger_event
    { [ e ] }
    [@name trg_event_one]
  | es = trigger_events OR e = trigger_event
    { es @ [ e ] }
    [@name trg_event_more]

for_each_row_opt:
  | /* empty */
    { false }
    [@name no_for_each]
  | FOR EACH ROW
    { true }
    [@name for_each_row]
  | FOR EACH STATEMENT
    { false }
    [@name for_each_statement]

/* What a COMMENT ON is about.  The word is a keyword of this grammar for a
   table and for a column, thus [ident] alone is not enough. */
/* [DROP FUNCTION f()] -- an argument list makes one function different from
   another function with the same name.  This repository writes only an empty
   list. */
empty_args_opt:
  | /* empty */
    { false }
    [@name no_empty_args]
  | LPAREN RPAREN
    { true }
    [@name empty_args]

comment_object:
  | o = ident
    { o }
    [@name comment_object_ident]
  | TABLE
    { M.ident "table" }
    [@name comment_object_table]
  | COLUMN
    { M.ident "column" }
    [@name comment_object_column]

/* The operation that a grant permits to the role.  Each of these words is a keyword of this
   grammar, thus [ident] alone is not enough. */
privilege:
  | SELECT
    { M.ident "select" }
    [@name privilege_select]
  | INSERT
    { M.ident "insert" }
    [@name privilege_insert]
  | UPDATE
    { M.ident "update" }
    [@name privilege_update]
  | DELETE
    { M.ident "delete" }
    [@name privilege_delete]

grant_columns:
  | /* empty */
    { [ ] }
    [@name no_grant_columns]
  | LPAREN cs = using_cols RPAREN
    { cs }
    [@name grant_columns]

login_opt:
  | /* empty */
    { false }
    [@name no_login]
  | LOGIN
    { true }
    [@name login]

password_opt:
  | /* empty */
    { None }
    [@name no_password]
  | PASSWORD p = STRING
    { Some p }
    [@name password]

drop_object:
  | o = IDENTIFIER
    { [ o ] }
    [@name drop_object_one]
  | FOREIGN TABLE
    { [ M.ident "foreign"; M.ident "table" ] }
    [@name drop_object_foreign_table]
  | TRIGGER
    { [ M.ident "trigger" ] }
    [@name drop_object_trigger]
  | FUNCTION
    { [ M.ident "function" ] }
    [@name drop_object_function]
  | TYPE
    { [ M.ident "type" ] }
    [@name drop_object_type]
  | EXTENSION
    { [ M.ident "extension" ] }
    [@name drop_object_extension]

drop_on_opt:
  | /* empty */
    { None }
    [@name no_drop_on]
  | ON t = table_name
    { Some t }
    [@name drop_on]

local_opt:
  | /* empty */
    { false }
    [@name no_local]
  | LOCAL
    { true }
    [@name local]

/* The [IN ... MODE] phrase of [LOCK TABLE].  Absent is [LOCK TABLE t] with no
   phrase. */
lock_table_mode_opt:
  | /* empty */
    { None }
    [@name no_lock_table_mode]
  | m = LOCK_MODE
    { Some m }
    [@name yes_lock_table_mode]

statement:
  | q = query
    { q }
    [@name stmt_query]
  | CREATE tmp = temp_opt TABLE e = if_not_exists n = table_name LPAREN is = table_items RPAREN
    p = table_partition_opt oc = on_commit_drop_opt
    { M.Create_table { if_not_exists = e; temp = tmp; name = n; body = M.Table_items is;
                       partition = p; on_commit_drop = oc } }
    [@name create_table_stmt]
  /* [CREATE TABLE t AS SELECT ...] -- the query gives the contents of the table. */
  | CREATE tmp = temp_opt TABLE e = if_not_exists n = table_name oc = on_commit_drop_opt
    AS q = insert_query
    { M.Create_table { if_not_exists = e; temp = tmp; name = n; body = M.Table_as_query q;
                       partition = None; on_commit_drop = oc } }
    [@name create_table_as_stmt]
  /* A partition of a partitioned table: the parent gives the columns and the
     bound gives the slice of its values. */
  | CREATE tmp = temp_opt TABLE e = if_not_exists n = table_name PARTITION OF
    parent = table_name b = partition_bound
    { M.Create_table { if_not_exists = e; temp = tmp; name = n;
                       body = M.Table_partition_of { parent = parent; bound = b };
                       partition = None; on_commit_drop = false } }
    [@name create_table_partition_of_stmt]
  /* A table that is in another database. */
  | CREATE FOREIGN TABLE e = if_not_exists n = table_name LPAREN is = table_items RPAREN
    SERVER srv = ident OPTIONS LPAREN os = foreign_options RPAREN
    { M.Create_table { if_not_exists = e; temp = false; name = n;
                       body = M.Table_foreign { items = is; server = srv; options = os };
                       partition = None; on_commit_drop = false } }
    [@name create_foreign_table_stmt]
  | CREATE u = unique_opt INDEX c = concurrently_opt e = if_not_exists nm = index_name_opt
    ON t = table_name m = index_method_opt LPAREN es = index_elements RPAREN
    inc = index_include_opt nd = index_nulls_opt w = index_where_opt
    { M.Create_index
        { unique = u; concurrently = c; if_not_exists = e; name = nm; table = t;
          method_ = m; columns = es; include_ = inc; nulls_not_distinct = nd; where = w } }
    [@name create_index_stmt]
  | CREATE r = or_replace_opt VIEW n = table_name cs = view_columns_opt AS q = statement
    { M.Create_view { or_replace = r; name = n; columns = cs; query = q } }
    [@name create_view_stmt]
  | CREATE r = or_replace_opt FUNCTION n = table_name LPAREN a = func_args RPAREN
    cs = func_clauses
    { M.Create_function { or_replace = r; name = n; args = a; clauses = cs } }
    [@name create_function_stmt]
  | CREATE r = or_replace_opt TRIGGER n = IDENTIFIER tm = trigger_timing
    es = trigger_events ON t = table_name fe = for_each_row_opt EXECUTE FUNCTION f = table_name
    LPAREN RPAREN
    { M.Create_trigger
        { or_replace = r; name = n; timing = tm; events = es; table = t;
          for_each_row = fe; execute = f } }
    [@name create_trigger_stmt]
  | CREATE EXTENSION e = if_not_exists n = IDENTIFIER
    { M.Create_extension { if_not_exists = e; name = n } }
    [@name create_extension_stmt]
  | SET CONSTRAINTS ALL d = constraints_mode
    { M.Set_constraints { names = []; deferred = d } }
    [@name set_constraints_all_stmt]
  | SET CONSTRAINTS ns = table_names d = constraints_mode
    { M.Set_constraints { names = ns; deferred = d } }
    [@name set_constraints_stmt]
  | SET l = local_opt n = table_name EQUAL v = expr
    { M.Set_stmt { local = l; name = n; value = v } }
    [@name set_stmt]
  | SET l = local_opt n = table_name TO v = expr
    { M.Set_stmt { local = l; name = n; value = v } }
    [@name set_to_stmt]
  | COMMENT ON o = comment_object n = table_name IS c = STRING
    { M.Comment_on { object_ = o; name = n; comment = Some c } }
    [@name comment_on_stmt]
  | COMMENT ON o = comment_object n = table_name IS NULL
    { M.Comment_on { object_ = o; name = n; comment = None } }
    [@name comment_on_null_stmt]
  /* [GRANT SELECT (a, b) ON t TO r]. */
  | GRANT p = privilege cs = grant_columns ON t = table_name TO r = ident
    { M.Grant { revoke = false; privilege = p; columns = cs; table = t; role = r } }
    [@name grant_stmt]
  | REVOKE p = privilege cs = grant_columns ON t = table_name FROM r = ident
    { M.Grant { revoke = true; privilege = p; columns = cs; table = t; role = r } }
    [@name revoke_stmt]
  /* Only the forms that this repository writes at the first start. */
  | CREATE ROLE n = ident l = login_opt p = password_opt
    { M.Create_role { name = n; login = l; password = p } }
    [@name create_role_stmt]
  | CREATE DATABASE n = ident
    { M.Create_database n }
    [@name create_database_stmt]
  /* [ALTER FUNCTION f() SET search_path = public, pg_catalog].  This repository
     writes only an empty argument list. */
  | ALTER FUNCTION n = table_name LPAREN RPAREN SET st = ident EQUAL vs = expr_list
    { M.Alter_function_set { name = n; setting = st; values = vs } }
    [@name alter_function_set_stmt]
  | ALTER TABLE e = if_exists o = only_opt n = table_name a = alter_actions
    { M.Alter_table { if_exists = e; only = o; name = n; actions = a } }
    [@name alter_table_stmt]
  | DROP o = drop_object e = if_exists ns = table_names a = empty_args_opt on = drop_on_opt b = drop_behavior
    { M.Drop { object_ = o; concurrently = false; empty_args = a; if_exists = e; names = ns;
               on_table = on; behavior = b } }
    [@name drop_stmt]
  | DROP TABLE c = concurrently_opt e = if_exists ns = table_names b = drop_behavior
    { M.Drop { object_ = [ M.ident "table" ]; concurrently = c; empty_args = false;
               if_exists = e; names = ns; on_table = None; behavior = b } }
    [@name drop_table_stmt]
  | DROP INDEX c = concurrently_opt e = if_exists ns = table_names b = drop_behavior
    { M.Drop { object_ = [ M.ident "index" ]; concurrently = c; empty_args = false;
               if_exists = e; names = ns; on_table = None; behavior = b } }
    [@name drop_index_stmt]
  | DROP VIEW c = concurrently_opt e = if_exists ns = table_names b = drop_behavior
    { M.Drop { object_ = [ M.ident "view" ]; concurrently = c; empty_args = false;
               if_exists = e; names = ns; on_table = None; behavior = b } }
    [@name drop_view_stmt]
  | TRUNCATE ns = table_names b = drop_behavior
    { M.Truncate { names = ns; behavior = b } }
    [@name truncate_stmt]
  | TRUNCATE TABLE ns = table_names b = drop_behavior
    { M.Truncate { names = ns; behavior = b } }
    [@name truncate_table_stmt]
  | ANALYZE ns = table_names
    { M.Analyze ns }
    [@name analyze_stmt]
  | ANALYZE
    { M.Analyze [ ] }
    [@name analyze_all_stmt]
  /* [LOCK TABLE t IN EXCLUSIVE MODE].  [lock table] and each whole
     [in ... mode] phrase is one token -- see [Mql_lexer]. */
  | LOCK_TABLE n = table_name m = lock_table_mode_opt
    { M.Lock_table { name = n; mode = m } }
    [@name lock_table_stmt]
  | d = dml_stmt
    { d }
    [@name stmt_dml]
  /* CTEs before a data-modifying statement:
     [with a as (...) delete from t where id in (select id from a)]. */
  | WITH r = recursive_opt cs = ctes d = dml_stmt
    { List.fold_right
        (fun (materialized, name, columns, query) body ->
           M.With { materialized; recursive = r; name; columns; query; body })
        cs
        d }
    [@name with_dml]

dml_stmt:
  | INSERT INTO tbl = table cs = insert_columns src = insert_source oc = on_conflict_opt r = returning_opt
    { M.Insert { table = tbl; columns = cs; source = src; on_conflict = oc; returning = r } }
    [@name insert_stmt]
  | UPDATE tbl = table SET as_ = assignments f = update_from_opt w = where_expr_opt r = returning_opt
    { M.Update { table = tbl; set_ = as_; from = f; where = w; returning = r } }
    [@name update_stmt]
  | DELETE FROM tbl = table u = delete_using_opt w = where_expr_opt r = returning_opt
    { M.Delete { table = tbl; using = u; where = w; returning = r } }
    [@name delete_stmt]

/* An INSERT's source query may not start with a paren: [insert_columns] is
   optional, so a leading [(] would be ambiguous between a column list and a
   parenthesized query, and one token of lookahead cannot tell them apart.
   PostgreSQL reads it as a column list too. */
union_term_no_paren:
  | s = select_core
    { M.Select s }
    [@name utnp_select]

query_body_no_paren:
  | t = union_term_no_paren
    { t }
    [@name qbnp_term]
  | l = query_body_no_paren o = set_op r = union_term
    { M.Set_op { op = o; all = false; left = l; right = r } }
    [@name qbnp_set_op]
  | l = query_body_no_paren o = set_op ALL r = union_term
    { M.Set_op { op = o; all = true; left = l; right = r } }
    [@name qbnp_set_op_all]

insert_query:
  | b = query_body_no_paren ol = order_by_opt
    { let (order_by, limit, offset) = ol in
      M.Query { body = b; order_by; limit; offset; locking = None } }
    [@name insert_query_body]
  | b = query_body_no_paren ol = order_by_opt lk = locking lim = limit_opt
    { let (order_by, limit, offset) = ol in
      let (limit2, offset2) = lim in
      M.Query { body = b; order_by; limit = merge_opt limit limit2;
                offset = merge_opt offset offset2; locking = Some lk } }
    [@name insert_query_body_locking]
  | WITH r = recursive_opt cs = ctes q = query
    { List.fold_right
        (fun (materialized, name, columns, query) body ->
           M.With { materialized; recursive = r; name; columns; query; body })
        cs
        q }
    [@name insert_query_with]

returning_opt:
  | /* empty */
    { None }
    [@name no_returning]
  | RETURNING sl = select_list
    { Some sl }
    [@name returning]

assignment:
  | c = ident EQUAL e = expr
    { M.Assign (c, e) }
    [@name assignment]
  /* [SET (a, b) = (1, 2)] sets more than one column from one row of values. */
  | LPAREN cs = using_cols RPAREN EQUAL LPAREN es = expr_list RPAREN
    { M.Assign_row (cs, es) }
    [@name assignment_row]

assignments:
  | a = assignment
    { [ a ] }
    [@name assignment_one]
  | as_ = assignments COMMA a = assignment
    { as_ @ [ a ] }
    [@name assignment_more]

insert_columns:
  | /* empty */
    { [ ] }
    [@name insert_no_columns]
  | LPAREN cs = using_cols RPAREN
    { cs }
    [@name insert_columns]

values_row:
  | LPAREN es = in_list RPAREN
    { es }
    [@name values_row]

values_rows:
  | r = values_row
    { [ r ] }
    [@name values_row_one]
  | rs = values_rows COMMA r = values_row
    { rs @ [ r ] }
    [@name values_row_more]

insert_source:
  | VALUES rs = values_rows
    { M.Insert_values rs }
    [@name insert_values]
  | q = insert_query
    { M.Insert_query q }
    [@name insert_source_query]
  | DEFAULT VALUES
    { M.Insert_default_values }
    [@name insert_default_values]

/* What PostgreSQL matches the new row against.  An entry can be an expression,
   as in [on conflict (repo, (params->>'branch'))], thus each one is read as an
   expression. */
conflict_target:
  | /* empty */
    { M.On_conflict_none }
    [@name no_conflict_target]
  | LPAREN es = conflict_elems RPAREN
    { M.On_conflict_elems { elems = es; where = None } }
    [@name conflict_target]
  /* [ON CONFLICT (a) WHERE p] names which partial index to match. */
  | LPAREN es = conflict_elems RPAREN WHERE e = expr
    { M.On_conflict_elems { elems = es; where = Some e } }
    [@name conflict_target_where]
  | ON CONSTRAINT n = ident
    { M.On_conflict_constraint n }
    [@name conflict_target_constraint]

/* One entry of a conflict target.  PostgreSQL takes a name as it is, but wants
   parentheses around anything else. */
conflict_elem:
  | c = ident
    { M.Conflict_col c }
    [@name conflict_col]
  | LPAREN e = expr RPAREN
    { M.Conflict_expr e }
    [@name conflict_expr]

conflict_elems:
  | e = conflict_elem
    { [ e ] }
    [@name conflict_elem_one]
  | es = conflict_elems COMMA e = conflict_elem
    { es @ [ e ] }
    [@name conflict_elem_more]

on_conflict_action:
  | DO NOTHING
    { M.Do_nothing }
    [@name do_nothing]
  | DO UPDATE SET as_ = assignments
    { M.Do_update { set_ = as_; where = None } }
    [@name do_update]
  | DO UPDATE SET as_ = assignments WHERE e = expr
    { M.Do_update { set_ = as_; where = Some e } }
    [@name do_update_where]

on_conflict_opt:
  | /* empty */
    { None }
    [@name no_on_conflict]
  | ON CONFLICT t = conflict_target a = on_conflict_action
    { Some { M.target = t; action = a } }
    [@name on_conflict]

/* [DELETE FROM t USING u WHERE ...] -- the rows to read during the delete operation. */
delete_using_opt:
  | /* empty */
    { [ ] }
    [@name delete_no_using]
  | USING ts = tables
    { ts }
    [@name delete_using]

update_from_opt:
  | /* empty */
    { [ ] }
    [@name update_no_from]
  /* Each entry can join, in the same way as an entry of a query's FROM. */
  | FROM ts = tables
    { ts }
    [@name update_from]

where_expr_opt:
  | /* empty */
    { None }
    [@name dml_no_where]
  | WHERE e = expr
    { Some e }
    [@name dml_where]

query:
  | b = query_body ol = order_by_opt
    { let (order_by, limit, offset) = ol in
      M.Query { body = b; order_by; limit; offset; locking = None } }
    [@name query]
  /* PostgreSQL accepts a limit before the locking clause or after it.  The
     AST does not record which place it was written in, thus it renders back in
     front of the locking clause. */
  | b = query_body ol = order_by_opt lk = locking lim = limit_opt
    { let (order_by, limit, offset) = ol in
      let (limit2, offset2) = lim in
      M.Query { body = b; order_by; limit = merge_opt limit limit2;
                offset = merge_opt offset offset2; locking = Some lk } }
    [@name query_locking]
  | WITH r = recursive_opt cs = ctes q = query
    { List.fold_right
        (fun (materialized, name, columns, query) body ->
           M.With { materialized; recursive = r; name; columns; query; body })
        cs
        q }
    [@name with_query]

query_body:
  | t = union_term
    { t }
    [@name qb_term]
  | l = query_body o = set_op r = union_term
    { M.Set_op { op = o; all = false; left = l; right = r } }
    [@name qb_set_op]
  | l = query_body o = set_op ALL r = union_term
    { M.Set_op { op = o; all = true; left = l; right = r } }
    [@name qb_set_op_all]

/* [UNION], [EXCEPT] and [INTERSECT] join two bodies the same way. */
set_op:
  | UNION
    { M.Union }
    [@name set_op_union]
  | EXCEPT
    { M.Except }
    [@name set_op_except]
  | INTERSECT
    { M.Intersect }
    [@name set_op_intersect]

union_term:
  | s = select_core
    { M.Select s }
    [@name ut_select]
  | LPAREN q = query RPAREN
    { M.Paren q }
    [@name ut_paren]

distinct_opt:
  | /* empty */
    { None }
    [@name no_distinct]
  | DISTINCT
    { Some M.Distinct }
    [@name distinct]
  | DISTINCT ON LPAREN es = expr_list RPAREN
    { Some (M.Distinct_on es) }
    [@name distinct_on]

select_core:
  | SELECT d = distinct_opt sl = select_list FROM ts = tables rest = where_opt
    { let (where, group_by, having) = rest in
      M.{ distinct = d; select_list = sl; from = ts; where; group_by; having } }
    [@name select_core]
  /* [FROM] is optional in SQL ([select 1]).  An empty [from] list is how the AST
     spells that, so no new constructor is needed. */
  | SELECT d = distinct_opt sl = select_list rest = where_opt
    { let (where, group_by, having) = rest in
      M.{ distinct = d; select_list = sl; from = [ ]; where; group_by; having } }
    [@name select_core_no_from]

/* [OUTER] is noise in SQL: [LEFT OUTER JOIN] means [LEFT JOIN].  It is accepted
   and not reproduced, so the rendering is canonical. */
outer_opt:
  | /* empty */
    { () }
    [@name no_outer]
  | OUTER
    { () }
    [@name outer]

join_cond:
  | ON e = expr
    { M.On e }
    [@name join_on]
  | USING LPAREN cs = using_cols RPAREN
    { M.Using cs }
    [@name join_using]

using_cols:
  | c = ident
    { [ c ] }
    [@name using_col]
  | cs = using_cols COMMA c = ident
    { cs @ [ c ] }
    [@name using_cols]

/* A join target is each form that a FROM clause accepts: a table, a derived
   table, or a call. */
join:
  | INNER JOIN t = from_item c = join_cond
    { { M.join_type = M.Inner; table = t; on_ = c } }
    [@name inner_join]
  /* [JOIN] with no word before it is an inner join.  The AST does not
     record which spelling the SQL used, thus it renders back as [inner join]. */
  | JOIN t = from_item c = join_cond
    { { M.join_type = M.Inner; table = t; on_ = c } }
    [@name bare_join]
  | LEFT outer_opt JOIN t = from_item c = join_cond
    { { M.join_type = M.Left; table = t; on_ = c } }
    [@name left_join]
  | RIGHT outer_opt JOIN t = from_item c = join_cond
    { { M.join_type = M.Right; table = t; on_ = c } }
    [@name right_join]
  | FULL outer_opt JOIN t = from_item c = join_cond
    { { M.join_type = M.Full; table = t; on_ = c } }
    [@name full_join]
  /* A CROSS JOIN takes no condition -- SQL forbids one. */
  | CROSS JOIN t = from_item
    { { M.join_type = M.Cross; table = t; on_ = M.No_cond } }
    [@name cross_join]

joins:
  | j = join
    { [ j ] }
    [@name join]
  | js = joins j = join
    { js @ [ j ] }
    [@name joins]

where_opt:
  | WHERE e = expr rest = group_by_opt
    { let (group_by, having) = rest in
      (Some e, group_by, having) }
    [@name where]
  | rest = group_by_opt
    { let (group_by, having) = rest in
      (None, group_by, having) }
    [@name no_where]

/* A list of expressions with a comma between them.  Used in each position that
   has a list of plain expressions: a GROUP BY, a conflict target, an array, an
   UNNEST. */
expr_list:
  | e = expr
    { [ e ] }
    [@name expr_list_one]
  | es = expr_list COMMA e = expr
    { es @ [ e ] }
    [@name expr_list_more]

group_by_opt:
  | GROUP BY es = expr_list HAVING having = expr
    { (Some (M.Group_exprs es), Some having) }
    [@name group_by_having]
  | GROUP BY es = expr_list
    { (Some (M.Group_exprs es), None) }
    [@name group_by_no_having]
  | GROUP BY GROUPING SETS LPAREN gs = grouping_sets RPAREN HAVING having = expr
    { (Some (M.Group_sets gs), Some having) }
    [@name group_sets_having]
  | GROUP BY GROUPING SETS LPAREN gs = grouping_sets RPAREN
    { (Some (M.Group_sets gs), None) }
    [@name group_sets_no_having]
  /* A [HAVING] with no [GROUP BY]: the query is one group, and the filter
     keeps it or removes it. */
  | HAVING having = expr
    { (None, Some having) }
    [@name having_no_group_by]
  | /* empty */
    { (None, None) }
    [@name no_group_by]

/* [NULLS FIRST] / [NULLS LAST] -- the position of the empty values. */
nulls_opt:
  | /* empty */
    { None }
    [@name no_nulls_order]
  | NULLS FIRST
    { Some M.Nulls_first }
    [@name nulls_first]
  | NULLS LAST
    { Some M.Nulls_last }
    [@name nulls_last]

/* One set of [GROUPING SETS ((a), ())].  A set can be empty, and an empty set
   is not an expression, thus the sets are read here and not as expressions. */
grouping_set:
  | LPAREN RPAREN
    { [ ] }
    [@name grouping_set_empty]
  | LPAREN es = expr_list RPAREN
    { es }
    [@name grouping_set]

grouping_sets:
  | g = grouping_set
    { [ g ] }
    [@name grouping_sets_one]
  | gs = grouping_sets COMMA g = grouping_set
    { gs @ [ g ] }
    [@name grouping_sets_more]

order_by_expr:
  | e = expr DESC n = nulls_opt
    { { M.ob_expr = e; ob_order = Some M.Desc; ob_nulls = n } }
    [@name order_by_desc]
  | e = expr ASC n = nulls_opt
    { { M.ob_expr = e; ob_order = Some M.Asc; ob_nulls = n } }
    [@name order_by_asc]
  | e = expr n = nulls_opt
    { { M.ob_expr = e; ob_order = None; ob_nulls = n } }
    [@name order_by_bare]

order_by_exprs:
  | e = order_by_expr
    { [ e ] }
    [@name order_by_expr]
  | es = order_by_exprs COMMA e = order_by_expr
    { es @ [ e ] }
    [@name order_by_exprs]

order_by_opt:
  | ORDER BY t = order_by_exprs rest = limit_opt
    { let (limit, offset) = rest in
      (Some t, limit, offset) }
    [@name order_by]
  | rest = limit_opt
    { let (limit, offset) = rest in
      (None, limit, offset) }
    [@name no_order_by]

limit_opt:
  | /* empty */
    { (None, None) }
    [@name eof]
  | LIMIT i = INTEGER o = offset_opt
    { (Some (M.Int i), o) }
    [@name limit]
  | LIMIT v = VARIABLE o = offset_opt
    { (Some (M.Variable v), o) }
    [@name limit_variable]
  | o = offset_only
    { (None, Some o) }
    [@name offset_no_limit]

/* [OFFSET n] -- the quantity of rows to omit. */
offset_opt:
  | /* empty */
    { None }
    [@name no_offset]
  | OFFSET i = INTEGER
    { Some (M.Int i) }
    [@name offset]
  | OFFSET v = VARIABLE
    { Some (M.Variable v) }
    [@name offset_variable]

offset_only:
  | OFFSET i = INTEGER
    { M.Int i }
    [@name offset_only]
  | OFFSET v = VARIABLE
    { M.Variable v }
    [@name offset_only_variable]

select_list:
  | STAR
    { M.Star }
    [@name select_list_star]
  | slc = select_list_columns
    { M.Columns slc }
    [@name select_list]

column:
  | e = expr AS alias = ident
    { { M.expr = e; alias = Some alias } }
    [@name column_with_alias]
  /* [AS] is optional in SQL.  Renders back as the [AS] form -- the AST does not
     record which spelling the SQL used. */
  | e = expr alias = ident
    { { M.expr = e; alias = Some alias } }
    [@name column_with_alias_no_as]
  | e = expr
    { { M.expr = e; alias = None } }
    [@name column_no_alias]

select_list_columns:
  | c = column
    { [ c ] }
    [@name select_list_column]
  | slc = select_list_columns COMMA c = column
    { slc @ [ c ] }
    [@name select_list_columns]

/* A table in a FROM clause.  It uses [table_name], thus a name can have the
   schema before it. */
table:
  | t = table_name AS alias = ident
    { { M.table_qualifier = t.M.qualifier; name = t.M.base; alias = Some alias } }
    [@name table_with_alias]
  /* [AS] is optional in SQL.  Renders back as the [AS] form. */
  | t = table_name alias = ident
    { { M.table_qualifier = t.M.qualifier; name = t.M.base; alias = Some alias } }
    [@name table_with_alias_no_as]
  | t = table_name
    { { M.table_qualifier = t.M.qualifier; name = t.M.base; alias = None } }
    [@name table_no_alias]

/* The column names that a FROM item gives to its result: [AS v(dir, workspace)].
   This repository writes names only, never types. */
/* One column name that a FROM item gives to its result.  A call that makes a
   record needs a type for each column. */
column_alias:
  | n = ident
    { { M.ca_name = n; ca_type = None } }
    [@name column_alias]
  | n = ident t = type_name
    { { M.ca_name = n; ca_type = Some t } }
    [@name column_alias_typed]

column_aliases:
  | c = column_alias
    { [ c ] }
    [@name column_alias_one]
  | cs = column_aliases COMMA c = column_alias
    { cs @ [ c ] }
    [@name column_alias_more]

column_alias_list:
  | /* empty */
    { [ ] }
    [@name no_column_alias_list]
  | LPAREN cs = column_aliases RPAREN
    { cs }
    [@name column_alias_list]

/* A call in the position of a table.  Only a call: a larger expression here is
   ambiguous with a table name. */
from_func:
  | name = ident LPAREN RPAREN
    { M.Func { M.qualifier = None; name; distinct = false; args = M.Func_exprs [];
               agg_order_by = None; filter = None; over = None } }
    [@name from_func_no_args]
  | name = ident LPAREN args = fun_args RPAREN
    { M.Func { M.qualifier = None; name; distinct = false; args = M.Func_exprs args;
               agg_order_by = None; filter = None; over = None } }
    [@name from_func_call]

/* [WITH ORDINALITY] -- the call gives one more column, the number of each
   row. */
ordinality_opt:
  | /* empty */
    { false }
    [@name no_ordinality]
  | WITH_ORDINALITY
    { true }
    [@name ordinality]

/* The alias of a FROM item.  [AS] is optional in SQL.  The AST does not record
   which spelling the SQL used. */
from_alias:
  | /* empty */
    { None }
    [@name no_from_alias]
  | AS a = ident
    { Some a }
    [@name from_alias_as]
  | a = ident
    { Some a }
    [@name from_alias_bare]

from_item:
  | t = table
    { M.Table_ref t }
    [@name from_table]
  /* A derived table.  [insert_query] rather than [query] so the inner query
     cannot itself start with a paren, which would be ambiguous with the
     surrounding one. */
  | LPAREN q = insert_query RPAREN AS alias = ident cs = column_alias_list
    { M.Derived_table { query = q; alias; columns = cs; lateral_ = false } }
    [@name from_derived]
  | LPAREN q = insert_query RPAREN alias = ident cs = column_alias_list
    { M.Derived_table { query = q; alias; columns = cs; lateral_ = false } }
    [@name from_derived_no_as]
  /* [LATERAL] permits the item to read the columns of the items before it. */
  | LATERAL LPAREN q = insert_query RPAREN AS alias = ident cs = column_alias_list
    { M.Derived_table { query = q; alias; columns = cs; lateral_ = true } }
    [@name from_lateral_derived]
  | LATERAL LPAREN q = insert_query RPAREN alias = ident cs = column_alias_list
    { M.Derived_table { query = q; alias; columns = cs; lateral_ = true } }
    [@name from_lateral_derived_no_as]
  | UNNEST LPAREN es = expr_list RPAREN AS alias = ident cs = column_alias_list
    { M.Unnest { exprs = es; alias; columns = cs } }
    [@name from_unnest]
  /* An UNNEST with no alias.  PostgreSQL gives the name [unnest] to the
     column. */
  | UNNEST LPAREN es = expr_list RPAREN
    { M.Func_table
        { expr = M.Func { M.qualifier = None; name = M.ident "unnest"; distinct = false;
                          args = M.Func_exprs (List.map (fun e -> M.Arg e) es);
                          agg_order_by = None; filter = None;
                          over = None };
          ordinality = false; alias = None; columns = [ ]; lateral_ = false } }
    [@name from_unnest_no_alias]
  | UNNEST LPAREN es = expr_list RPAREN alias = ident cs = column_alias_list
    { M.Unnest { exprs = es; alias; columns = cs } }
    [@name from_unnest_no_as]
  | e = from_func o = ordinality_opt a = from_alias cs = column_alias_list
    { M.Func_table { expr = e; ordinality = o; alias = a; columns = cs; lateral_ = false } }
    [@name from_func_item]
  | LATERAL e = from_func o = ordinality_opt a = from_alias cs = column_alias_list
    { M.Func_table { expr = e; ordinality = o; alias = a; columns = cs; lateral_ = true } }
    [@name from_lateral_func_item]
  | LATERAL UNNEST LPAREN es = expr_list RPAREN a = from_alias cs = column_alias_list
    { M.Func_table
        { expr = M.Func { M.qualifier = None; name = M.ident "unnest"; distinct = false;
                          args = M.Func_exprs (List.map (fun e -> M.Arg e) es);
                          agg_order_by = None; filter = None;
                          over = None };
          ordinality = false; alias = a; columns = cs; lateral_ = true } }
    [@name from_lateral_unnest]

/* One entry of a FROM clause: a table with the joins that attach to it.  The
   two shapes are written out rather than made from an optional join list: an
   optional one would make the parser choose before it has read a join word. */
from_entry:
  | t = from_item
    { { M.fe_table = t; fe_joins = [ ] } }
    [@name from_entry]
  | t = from_item js = joins
    { { M.fe_table = t; fe_joins = js } }
    [@name from_entry_joins]

tables:
  | t = from_entry
    { [ t ] }
    [@name table]
  | ts = tables COMMA t = from_entry
    { ts @ [ t ] }
    [@name tables]

expr:
  | LPAREN t = tuple RPAREN
    { M.Tuple t }
    [@name tuple]
  | LPAREN e = expr RPAREN
    { e }
    [@name paren]
  | e1 = expr PLUS e2 = expr
    { M.Add (e1, e2) }
    [@name add]
  | e1 = expr MINUS e2 = expr
    { M.Sub (e1, e2) }
    [@name sub]
  | e1 = expr STAR e2 = expr
    { M.Mult (e1, e2) }
    [@name mult]
  | e1 = expr DIV e2 = expr
    { M.Div (e1, e2) }
    [@name div]
  | e1 = expr AND e2 = expr
    { M.And (e1, e2) }
    [@name and_]
  | e1 = expr OR e2 = expr
    { M.Or (e1, e2) }
    [@name or_]
  | e1 = expr EQUAL e2 = expr
    { M.Eq (e1, e2) }
    [@name equal]
  | e1 = expr NOT_EQUAL e2 = expr
    { M.Not_eq (e1, e2) }
    [@name not_equal]
  | e1 = expr IS e2 = expr
    { M.Is (e1, e2) }
    [@name is_]
  | e1 = expr IS_NOT e2 = expr
    { M.Is_not (e1, e2) }
    [@name is_not]
  | e1 = expr LIKE e2 = expr
    { M.Like (e1, e2) }
    [@name like]
  | e1 = expr NOT LIKE e2 = expr
    { M.Not_like (e1, e2) }
    [@name not_like]
  | e1 = expr ILIKE e2 = expr
    { M.Ilike (e1, e2) }
    [@name ilike]
  | e1 = expr NOT ILIKE e2 = expr
    { M.Not_ilike (e1, e2) }
    [@name not_ilike]
  | e1 = expr LT e2 = expr
    { M.Lt (e1, e2) }
    [@name lt]
  | e1 = expr LTE e2 = expr
    { M.Lte (e1, e2) }
    [@name lte]
  | e1 = expr GT e2 = expr
    { M.Gt (e1, e2) }
    [@name gt]
  | e1 = expr GTE e2 = expr
    { M.Gte (e1, e2) }
    [@name gte]
  | e1 = expr IS_DISTINCT_FROM e2 = expr
    { M.Is_distinct_from (e1, e2) }
    [@name is_distinct_from]
  | e1 = expr IS_NOT_DISTINCT_FROM e2 = expr
    { M.Is_not_distinct_from (e1, e2) }
    [@name is_not_distinct_from]
  | e1 = expr IN LPAREN t = in_list RPAREN
    { M.In (e1, t) }
    [@name in_]
  /* [insert_query] rather than [query] so that the inner query cannot itself
     start with a parenthesis.  With [query] here, [x in ((select ...))] has two
     readings: a query in parentheses, or a list of one scalar subquery. */
  | e1 = expr IN LPAREN q = insert_query RPAREN
    { M.In_query (e1, q) }
    [@name in_query]
  | EXISTS LPAREN q = insert_query RPAREN
    { M.Exists q }
    [@name exists]
  | e1 = expr MOD e2 = expr
    { M.Mod (e1, e2) }
    [@name mod_]
  | e1 = expr LBRACKET e2 = expr COLON e3 = expr RBRACKET
    { M.Slice (e1, e2, e3) }
    [@name slice]
  | e1 = expr LBRACKET e2 = expr RBRACKET
    { M.Index (e1, e2) }
    [@name index]
  | e1 = expr DOUBLE_COLON t = cast_type
    { M.Cast (e1, t) }
    [@name cast]
  | e1 = expr DOUBLE_PIPE e2 = expr
    { M.Concat (e1, e2) }
    [@name concat]
  | e1 = expr JSON_VAL e2 = expr
    { M.Json_val (e1, e2) }
    [@name json_val]
  | e1 = expr JSON_TEXT e2 = expr
    { M.Json_text (e1, e2) }
    [@name json_text]
  /* A literal path is [Json_obj_query], which a query from outside can use.
     Each other path is [Json_obj_query_path]. */
  | e1 = expr JSON_OBJ_QUERY e2 = expr
    { match e2 with
      | M.String q -> M.Json_obj_query (e1, q)
      | e2 -> M.Json_obj_query_path (e1, e2) }
    [@name json_obj_query]
  | e1 = expr JSON_SUBSET e2 = expr
    { M.Json_subset (e1, e2) }
    [@name json_subset]
  | MINUS e = expr %prec UMINUS
    { M.Negate e }
    [@name negate]
  (* [NOT_EXPR], the precedence the precedence table gives [NOT]: looser than
     [IS], tighter than [AND], as in PostgreSQL. *)
  | NOT e = expr %prec NOT_EXPR
    { M.Not e }
    [@name not_]
  /* A call over a star.  A star is not an expression, thus this form is
     separate.  The name is read the same way as for any other call, which is
     what keeps [count] usable as a column name. */
  | n = name_ref LPAREN STAR RPAREN f = func_filter o = func_over
    { M.Func { M.qualifier = fst n; name = snd n; distinct = false; args = M.Func_star;
               agg_order_by = None; filter = f; over = o } }
    [@name count_star]
  | n = name_ref LPAREN RPAREN f = func_filter o = func_over
    { M.Func { M.qualifier = fst n; name = snd n; distinct = false; args = M.Func_exprs [];
               agg_order_by = None; filter = f; over = o } }
    [@name fun_no_args]
  | n = name_ref LPAREN d = func_distinct args = fun_args ob = func_agg_order RPAREN f = func_filter o = func_over
    { M.Func { M.qualifier = fst n; name = snd n; distinct = d; args = M.Func_exprs args;
               agg_order_by = ob; filter = f; over = o } }
    [@name fun_call]
  | e1 = expr AT_TIME_ZONE e2 = expr
    { M.At_time_zone (e1, e2) }
    [@name at_time_zone]
  /* A query in the position of a value.  [insert_query] rather than
     [query] so that the inner query cannot itself start with a parenthesis. */
  | LPAREN q = insert_query RPAREN
    { M.Scalar_subquery q }
    [@name scalar_subquery]
  /* An empty array.  The lexer reads [\[\]] as one token, thus the empty form
     is not an open bracket and a close bracket. */
  | ARRAY ARRAY_SUFFIX
    { M.Array_lit [ ] }
    [@name array_lit_empty]
  | ARRAY LBRACKET es = expr_list RBRACKET
    { M.Array_lit es }
    [@name array_lit]
  | ARRAY LPAREN q = insert_query RPAREN
    { M.Array_query q }
    [@name array_query]
  | e1 = expr JSON_HAS_KEY e2 = expr
    { M.Json_has_key (e1, e2) }
    [@name json_has_key]
  | e1 = expr LIKE e2 = expr ESCAPE e3 = expr
    { M.Like_escape (e1, e2, e3) }
    [@name like_escape]
  /* The standard form of [e::t].  It makes the same node, thus the renderer
     writes it as [e::t]. */
  | CAST LPAREN e = expr AS t = cast_type RPAREN
    { M.Cast (e, t) }
    [@name cast_fn]
  /* The word before [from] is the name of a field of a date. */
  | EXTRACT LPAREN f = ident FROM e = expr RPAREN
    { M.Extract (f, e) }
    [@name extract]
  | SUBSTRING LPAREN e1 = expr FROM e2 = expr RPAREN
    { M.Substring_from (e1, e2) }
    [@name substring_from]
  | POSITION LPAREN e1 = position_needle IN e2 = expr RPAREN
    { M.Position_in (e1, e2) }
    [@name position_in]
  | e1 = expr NOT IN LPAREN t = in_list RPAREN
    { M.Not_in (e1, t) }
    [@name not_in]
  | e1 = expr NOT IN LPAREN q = insert_query RPAREN
    { M.Not_in_query (e1, q) }
    [@name not_in_query]
  /* [unnest], [left] and [right] are keywords of this grammar.  Thus each
     one needs its own rule to be a call. */
  | UNNEST LPAREN args = fun_args RPAREN
    { M.Func { M.qualifier = None; name = M.ident "unnest"; distinct = false;
               args = M.Func_exprs args; agg_order_by = None; filter = None; over = None } }
    [@name unnest_call]
  | LEFT LPAREN args = fun_args RPAREN
    { M.Func { M.qualifier = None; name = M.ident "left"; distinct = false;
               args = M.Func_exprs args; agg_order_by = None; filter = None; over = None } }
    [@name left_call]
  | RIGHT LPAREN args = fun_args RPAREN
    { M.Func { M.qualifier = None; name = M.ident "right"; distinct = false;
               args = M.Func_exprs args; agg_order_by = None; filter = None; over = None } }
    [@name right_call]
  | e1 = expr REGEX_MATCH e2 = expr
    { M.Regex_match (e1, e2) }
    [@name regex_match]
  | e1 = expr REGEX_NOT_MATCH e2 = expr
    { M.Regex_not_match (e1, e2) }
    [@name regex_not_match]
  /* The same split as for [#>>]. */
  | e1 = expr JSON_OBJ_VAL e2 = expr
    { match e2 with
      | M.String q -> M.Json_obj_val (e1, q)
      | e2 -> M.Json_obj_val_path (e1, e2) }
    [@name json_obj_val]
  | e1 = expr REGEX_IMATCH e2 = expr
    { M.Regex_imatch (e1, e2) }
    [@name regex_imatch]
  | e1 = expr REGEX_NOT_IMATCH e2 = expr
    { M.Regex_not_imatch (e1, e2) }
    [@name regex_not_imatch]
  | e = expr COLLATE c = ident
    { M.Collate (e, c) }
    [@name collate]
  /* [a & b] -- the bits that are in each of the two integers. */
  | e1 = expr BIT_AND e2 = expr
    { M.Bit_and (e1, e2) }
    [@name bit_and]
  /* [a <> ALL (b)] -- the comparison is true for each element of [b].  [all] is
     a keyword of this grammar, thus the call needs its own rule.  The tree is a
     call, as for [a = ANY (b)]: [any] is not a keyword, thus that form already
     reads as a call. */
  | ALL LPAREN e = expr RPAREN
    { M.Func { M.qualifier = None; name = M.ident "all"; distinct = false;
               args = M.Func_exprs [ M.Arg e ]; agg_order_by = None; filter = None;
               over = None } }
    [@name all_call]
  | INTERVAL s = STRING
    { M.Interval s }
    [@name interval]
  | CASE bs = case_branches e = case_else END
    { M.Case { operand = None; branches = bs; else_ = e } }
    [@name case]
  | CASE op = expr bs = case_branches e = case_else END
    { M.Case { operand = Some op; branches = bs; else_ = e } }
    [@name case_operand]
  /* A name, with the schema or the table before it when the SQL has one.
     Both shapes go through [name_ref] so that the parser can tell a name from a
     call with one word of lookahead. */
  | n = name_ref
    { match n with
      | (None, i) -> M.Identifier i
      | (Some q, i) -> M.Field_select (M.Identifier q, i) }
    [@name name_expr]
  /* [t.*] in a select list. */
  | i = ident DOT STAR
    { M.Qualified_star (M.Identifier i) }
    [@name qualified_star]
  | v = VARIABLE
    { M.Variable v }
    [@name variable]
  | s = STRING
    { M.String s }
    [@name string]
  | i = INTEGER
    { M.Int i }
    [@name integer]
  | fl = FLOAT
    { M.Float fl }
    [@name float]
  | NULL
    { M.Null }
    [@name null]
  | TRUE
    { M.True }
    [@name true_]
  | FALSE
    { M.False }
    [@name false_]
   

case_branches:
  | WHEN c = expr THEN v = expr
    { [ (c, v) ] }
    [@name case_branch]
  | bs = case_branches WHEN c = expr THEN v = expr
    { bs @ [ (c, v) ] }
    [@name case_branches]

case_else:
  | /* empty */
    { None }
    [@name case_no_else]
  | ELSE e = expr
    { Some e }
    [@name case_with_else]

/* [count(DISTINCT x)].  An aggregate takes each value once. */
func_distinct:
  | /* empty */
    { false }
    [@name no_func_distinct]
  | DISTINCT
    { true }
    [@name func_distinct]

/* [string_agg(x, ',' ORDER BY y)].  This sort order belongs to the aggregate and
   not to the query. */
func_agg_order:
  | /* empty */
    { None }
    [@name no_func_agg_order]
  | ORDER BY o = order_by_exprs
    { Some o }
    [@name func_agg_order]

/* [FILTER (WHERE p)].  The aggregate reads only the rows that agree with [p]. */
func_filter:
  | /* empty */
    { None }
    [@name no_func_filter]
  | FILTER LPAREN WHERE e = expr RPAREN
    { Some e }
    [@name func_filter]

window_partition:
  | /* empty */
    { [ ] }
    [@name no_window_partition]
  | PARTITION BY es = expr_list
    { es }
    [@name window_partition]

window_order:
  | /* empty */
    { None }
    [@name no_window_order]
  | ORDER BY o = order_by_exprs
    { Some o }
    [@name window_order]

/* This grammar has no frame clause and no [WINDOW] clause.  This repository
   writes no such clause. */
window_spec:
  | p = window_partition o = window_order
    { { M.partition_by = p; window_order_by = o } }
    [@name window_spec]

func_over:
  | /* empty */
    { None }
    [@name no_func_over]
  | OVER LPAREN w = window_spec RPAREN
    { Some w }
    [@name func_over]

fun_arg:
  | e = expr
    { M.Arg e }
    [@name fun_arg_plain]
  /* PostgreSQL permits a call to give a name to each argument:
     [make_interval(secs => 1)]. */
  | n = ident NAMED_ARG e = expr
    { M.Arg_named (n, e) }
    [@name fun_arg_named]

fun_args:
  | arg = fun_arg
    { [ arg ] }
    [@name fun_arg]
  | args = fun_args COMMA arg = fun_arg
    { args @ [arg] }
    [@name fun_args]

tuple:
  | e1 = expr COMMA e2 = expr
    { [e1; e2] }
    [@name t_tuple]
  | t = tuple COMMA e1 = expr
    { t @ [ e1 ] }
    [@name tt_tuple]

in_list:
  | e = expr
    { [ e ] }
    [@name in_list_one]
  | l = in_list COMMA e = expr
    { l @ [ e ] }
    [@name in_list_more]