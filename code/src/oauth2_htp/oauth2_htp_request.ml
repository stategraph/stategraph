type t = {
  query : Oauth2_htp_values.t;
  headers : Cohttp.Header.t;
  body : string;
}

let of_ctx ctx =
  let request = Brtl_ctx.request ctx in
  {
    query = Uri.query (Brtl_ctx.uri ctx);
    headers = Cohttp.Request.headers request;
    body = Brtl_ctx.body ctx;
  }

(* The query and a form encoded body together, the query first. *)
let form t =
  match Cohttp.Header.get t.headers "content-type" with
  | Some content_type when CCString.mem ~sub:"application/x-www-form-urlencoded" content_type ->
      t.query @ Oauth2_htp_values.of_query_string t.body
  | Some _ | None -> t.query

let form_value k t = Oauth2_htp_values.get k (form t)
let cookies t = Cohttp.Cookie.Cookie_hdr.extract t.headers
