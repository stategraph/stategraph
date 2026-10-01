(** {0 MQL Endpoint}

    This endpoint provides an interface to the database using a subset of SQL, called MQL.

    For input, the endpoint takes:

    - Query (required) - An MQL string

    - Timezone (optional) - Perform the query based on a particular timezone.

    - Page (optional) - Which page to start the query from, this is only valid if the query can be
      automatically paginated.

    {0 Row limit and default truncation}

    A query may carry its own [LIMIT]. If it does not, the endpoint applies a server [default_limit]
    of {b 20} rows; an explicit [LIMIT] is in turn capped at [max_limit] of {b 1000}. Both values
    are also published in the schema endpoint payload ({!Schema.run} / [mql-schema-response]) so
    clients can discover them rather than hard-coding the magic numbers.

    When a query with {e no} explicit [LIMIT] matches more rows than [default_limit], the response
    is truncated by the server default. That response is otherwise indistinguishable from one that
    asked for [limit 20] and has a next page, so the endpoint sets the header
    [mql-default-limit-applied: 20] in {e exactly} that case (and never when the caller named its
    own [LIMIT]). A consumer that treats an unbounded result as complete (counts/sums/derives from
    it) can key on this header to paginate or fail loudly instead of silently undercounting. The
    flag is also surfaced programmatically on {!Sgs_mql_paged.page.default_limit_applied}.

    {0 Pagination}

    Because the input to this endpoint is raw MQL, which is a subset of SQL, pagination is not
    always possible.

    In order to automatically paginate, the query must have an [ORDER BY] clause. The [ORDER BY]
    clause must only contain identifiers or field selects. For example [ORDER BY foo] or
    [ORDER BY foo, bar, baz] or [ORDER BY foo.bar, bam.zoom].

    If a query has more than one page, the results of the query are returned and the header
    [mql-pagination-error] is set describing why the query cannot be paginated.

    List of pagination errors:

    - [COLUMN_NOT_IN_ROW <col name>] - The column in the order by cannot be found in the row.
    - [ORDER_BY_COL_NOT_IDENTIFIER <expr>] - The [ORDER BY] as an expression in it.
    - [ORDER_BY_MISSING] - There is no [ORDER BY] clause in the query.

    {0 Errors}

    Given the expressiveness of the endpoint there are numerous errors that a request can result in.
    These are returned as a [Bad_request_err] type.

    List of errors:

    - [APPLY_PAGE_ERR] - The provided page did not correspond to the query and could not be applied.
    - [TABLE_ACCESS_ERR] - The query attempts to access a table that is outside the white list.
    - [FUNC_ACCESS_ERR] - The query attempts to use a function that is outside the white list.
    - [AMBIGUOUS_COLUMN_ERR] - A column referenced in the query is ambiguous.
    - [UNKNOWN_COLUMN_ERR] - A column referenced in the query does not exist.
    - [INVALID_IDENTIFIER_ERR] - An identifier in the query is outside the permitted character set.
    - [QUERY_ERR] - The query failed while the underlying database was executing it.
    - [TIMEOUT_ERR] - The query took too long to execute and was timed out. *)

val run :
  Sgs_config.t ->
  Sgs_storage.t ->
  string ->
  string option ->
  Mql_to_pgsql.Page.t option ->
  Brtl_rtng.Handler.t

module Schema : sig
  val run : Sgs_config.t -> Brtl_rtng.Handler.t
end

module Tests : sig
  (** The {!Schema.run} response body per variant. *)
  val response_json : Yojson.Safe.t

  val response_json_orchestration : Yojson.Safe.t
end
