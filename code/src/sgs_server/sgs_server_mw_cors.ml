(* Simple CORS middleware for development - allows all origins *)

let pre_handler default_origin ctx =
  let request = Brtl_ctx.request ctx in
  match Cohttp.Request.meth request with
  | `OPTIONS ->
      (* Return 200 OK with CORS headers for preflight *)
      (* Get the Origin header from the request *)
      let origin =
        CCOption.get_or ~default:default_origin
        @@ Cohttp.Header.get (Cohttp.Request.headers request) "origin"
      in
      let response =
        Brtl_rspnc.create ~status:`OK ""
        |> Brtl_rspnc.add_header "Access-Control-Allow-Origin" origin
        |> Brtl_rspnc.add_header "Access-Control-Allow-Methods" "GET, POST, PUT, DELETE, OPTIONS"
        |> Brtl_rspnc.add_header
             "Access-Control-Allow-Headers"
             "Content-Type, Authorization, Cookie"
        |> Brtl_rspnc.add_header "Access-Control-Allow-Credentials" "true"
      in
      Abb.Future.return (Brtl_mw.Pre_handler.Stop (Brtl_ctx.set_response response ctx))
  | _ ->
      (* Continue processing *)
      Abb.Future.return (Brtl_mw.Pre_handler.Cont ctx)

let post_handler default_origin ctx =
  (* Add CORS headers to all responses *)
  (* Get the Origin header from the request *)
  let request = Brtl_ctx.request ctx in
  let origin =
    CCOption.get_or ~default:default_origin
    @@ Cohttp.Header.get (Cohttp.Request.headers request) "origin"
  in
  let response =
    Brtl_ctx.response ctx
    |> Brtl_rspnc.add_header "Access-Control-Allow-Origin" origin
    |> Brtl_rspnc.add_header "Access-Control-Allow-Credentials" "true"
    |> Brtl_rspnc.add_header "Access-Control-Expose-Headers" "link"
  in
  Abb.Future.return (Brtl_ctx.set_response response ctx)

let create ~default_origin () =
  Brtl_mw.Mw.create
    (pre_handler default_origin)
    (post_handler default_origin)
    Brtl_mw.early_exit_handler_noop
