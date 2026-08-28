module Search = struct
  module Col = struct
    type t = {
      vname : string;
      cname : string;
    }

    let create ~vname ~cname = { vname; cname }
  end

  type t = {
    limit : int;
    cols : Col.t list;
    dir : [ `Asc | `Desc ];
  }

  let create ~page_size ~dir cols = { limit = page_size; cols; dir }
end

type 'a t = {
  results : 'a list;
  next_page : bool;
}

(* Next here is in terms of ascending order. *)
let next_query search query =
  let col_names = CCList.map (fun col -> col.Search.Col.cname) search.Search.cols in
  let var_names = CCList.map (fun col -> "$" ^ col.Search.Col.vname) search.Search.cols in
  let null_checks = CCString.concat " or " (CCList.map (fun name -> name ^ " is null") var_names) in
  let cols = CCString.concat ", " col_names in

  (* Want to create something like:

     with query as (query)
     select * from query where ($v1 is null or $v2 is null .. or (c1, c2, .. cn) > ($v1, $v2, .. $vn))
     order by (c1, c2, .. cn) asc limit $limit
  *)
  Pgsql_io.Typed_sql.(
    sql
    /^ "with query as ("
    /% Var.smallint "limit"
    /^^ query
    /^ ") select * from query where"
    /^ "("
    /^ null_checks
    /^ " or ("
    /^ cols
    /^ ") > ("
    /^ CCString.concat ", " var_names
    /^ ")) order by ("
    /^ cols
    /^ ") asc limit $limit")

(* Prev here is in terms of ascending order. *)
let prev_query search query =
  let col_names = CCList.map (fun col -> col.Search.Col.cname) search.Search.cols in
  let var_names = CCList.map (fun col -> "$" ^ col.Search.Col.vname) search.Search.cols in
  let null_checks = CCString.concat " or " (CCList.map (fun name -> name ^ " is null") var_names) in
  let cols = CCString.concat ", " col_names in

  (* Want to create something like:

     with query as (query)
     select * from query where ($v1 is null or $v2 is null .. or (c1, c2, .. cn) < ($v1, $v2, .. $vn))
     order by (c1, c2, .. cn) desc limit $limit
  *)
  Pgsql_io.Typed_sql.(
    sql
    /^ "with query as ("
    /% Var.smallint "limit"
    /^^ query
    /^ ") select * from query where"
    /^ "("
    /^ null_checks
    /^ " or ("
    /^ cols
    /^ ") < ("
    /^ CCString.concat ", " var_names
    /^ ")) order by ("
    /^ cols
    /^ ") desc limit $limit")

let make_result search results =
  let next_page = CCList.length results > search.Search.limit in
  let results = CCList.take search.Search.limit results in
  { results; next_page }

let make_result_rev search results =
  let next_page = CCList.length results > search.Search.limit in
  let results = CCList.rev (CCList.take search.Search.limit results) in
  { results; next_page }

let next search conn query ~f =
  assert (search.Search.cols <> []);
  assert (search.Search.limit > 0);
  match search.Search.dir with
  | `Asc ->
      let sql = next_query search query in
      Pgsql_io.Prepared_stmt.kbind
        conn
        sql
        (Pgsql_io.Row_func.map sql ~f)
        (fun cursor ->
          let open Abbs_future_combinators.Infix_result_monad in
          Pgsql_io.Cursor.fetch cursor >>| fun results -> make_result search results)
        (search.Search.limit + 1)
  | `Desc ->
      let sql = prev_query search query in
      Pgsql_io.Prepared_stmt.kbind
        conn
        sql
        (Pgsql_io.Row_func.map sql ~f)
        (fun cursor ->
          let open Abbs_future_combinators.Infix_result_monad in
          Pgsql_io.Cursor.fetch cursor >>| fun results -> make_result search results)
        (search.Search.limit + 1)

let prev search conn query ~f =
  assert (search.Search.cols <> []);
  assert (search.Search.limit > 0);
  match search.Search.dir with
  | `Asc ->
      let sql = prev_query search query in
      Pgsql_io.Prepared_stmt.kbind
        conn
        sql
        (Pgsql_io.Row_func.map sql ~f)
        (fun cursor ->
          let open Abbs_future_combinators.Infix_result_monad in
          Pgsql_io.Cursor.fetch cursor >>| fun results -> make_result_rev search results)
        (search.Search.limit + 1)
  | `Desc ->
      let sql = next_query search query in
      Pgsql_io.Prepared_stmt.kbind
        conn
        sql
        (Pgsql_io.Row_func.map sql ~f)
        (fun cursor ->
          let open Abbs_future_combinators.Infix_result_monad in
          Pgsql_io.Cursor.fetch cursor >>| fun results -> make_result_rev search results)
        (search.Search.limit + 1)

let results t = t.results
let has_next_page t = t.next_page
