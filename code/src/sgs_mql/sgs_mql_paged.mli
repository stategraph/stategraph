(** MQL over the tenant-scoped catalog (#1720): the table allow-list, the compile-and-execute
    pipeline, the keyset pagination with its [Link] headers, and the typed paged response a list
    endpoint is built from -- build the query as an {!Mql.Build} AST and hand it to {!respond} with
    how to decode a row and shape the body. *)

(** Row-limit policy: a query that names no [LIMIT] gets [default_limit] rows, an explicit [LIMIT]
    is capped at [max_limit]. *)
val default_limit : int

val max_limit : int

(** The table/column allow-list, base variant (stategraph tables only). *)
val schema : Mql_to_pgsql.Schema.t

(** The orchestration variant: {!schema} plus the catalog-generated terrateam tables. *)
val schema_orchestration : Mql_to_pgsql.Schema.t

(** Pagination decision attached to a {!page}: either a cursor pair, or one of the diagnostic tags
    explaining why pagination is unavailable. *)
type pagination_decision =
  [ `Paginate of string option * string option
  | `Paginate_err of string
  | `Missing_order_by
  | `No_paginate
  ]
[@@deriving show]

(** One page of a query's result: the pagination decision, the row payload (each row already
    trimmed), the effective limit the caller asked for, and whether that limit was the server
    [default_limit] applied to a query with no explicit [LIMIT] that had more rows than the default
    ([default_limit_applied]) -- a result truncated by the server default rather than by the
    caller's own [LIMIT]. *)
type page = {
  pagination : pagination_decision;
  rows : Yojson.Safe.t list;
  limit : int;
  default_limit_applied : bool;
}
[@@deriving show]

type query_err =
  [ Mql_to_pgsql.apply_page_err
  | Mql_to_pgsql.of_mql_err
  | Pgsql_io.err
  | Pgsql_pool.err
  ]
[@@deriving show]

(** [query ?tz ?page config storage user ast] runs [ast] against the caller's tenants: the page
    cursor is applied, the query compiled against the catalog and executed under the configured
    statement timeout (and [tz], when given), the rows trimmed to the effective limit, and the
    next/prev cursors decided. *)
val query :
  ?tz:string ->
  ?page:Mql_to_pgsql.Page.t ->
  Sgs_config.t ->
  Sgs_storage.t ->
  Sgs_user.stored Sgs_user.t ->
  Mql.Ast.t ->
  (page, [> query_err ]) result Abb.Future.t

(** Build the [Link: rel="next", rel="prev"] response header given the prev/next cursor pair and the
    current request's URL. Each cursor is the opaque string {!query} returned. *)
val mk_pagination_headers :
  prev:string option -> next:string option -> (string, 'a) Brtl_ctx.t -> Cohttp.Header.t

(** Bound [ast] to [limit] rows when a positive one was asked for, else to [default] when the
    endpoint has one; otherwise the query keeps its own limit, or falls back to {!default_limit}. *)
val with_limit : ?default:int -> int option -> Mql.Ast.t -> Mql.Ast.t

(** Answer 400 with a [bad-request-err] body carrying [id] and the optional [data]. *)
val bad_request :
  id:string -> data:string option -> ('a, 'b) Brtl_ctx.t -> ('a, Brtl_rspnc.t) Brtl_ctx.t

(** [respond ~src ~tag ~decode_row ~body ~page config storage user ast ctx] serves one page of
    [ast]: the rows are decoded with [decode_row], the body is [body ~rows ~limit] ([limit] being
    the effective row limit, for responses that echo it), and the [Link] header carries the
    next/prev cursors when the page is one of several. [page] is the raw [page] query parameter;
    anything that is not a well-formed cursor (the only source of one is us) is the first page. *)
val respond :
  src:Logs.src ->
  tag:string ->
  decode_row:(Yojson.Safe.t -> ('row, string) result) ->
  body:(rows:'row list -> limit:int -> Yojson.Safe.t) ->
  page:string option ->
  Sgs_config.t ->
  Sgs_storage.t ->
  Sgs_user.stored Sgs_user.t ->
  Mql.Ast.t ->
  (string, 'a) Brtl_ctx.t ->
  (string, Brtl_rspnc.t) Brtl_ctx.t Abb.Future.t

module Tests : sig
  (** The page query with the terrateam CTE block spliced in ([orchestration:true]) or not, exactly
      as {!query} sends it modulo the user-query placeholder [{{q}}]. *)
  val select_page_sql : orchestration:bool -> string
end
