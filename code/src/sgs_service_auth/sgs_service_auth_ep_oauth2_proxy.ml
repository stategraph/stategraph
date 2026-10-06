(* OAuth2 Proxy Endpoint

   This endpoint proxies requests to the oauth2-proxy instance.
   It handles /oauth2/* routes and forwards them to the local oauth2-proxy.
*)

let src = Logs.Src.create "ep_oauth2_proxy"

module Logs = (val Logs.src_log src : Logs.LOG)
module Http = Abb_curl.Make (Abb)

(* Convert Cohttp method to Abb_curl method *)
let convert_method meth body =
  match meth with
  | `GET -> `GET
  | `POST -> `POST body
  | `PUT -> `PUT body
  | `DELETE -> `DELETE body
  | `PATCH -> `PATCH body
  | `HEAD -> `GET (* No HEAD support, fallback to GET *)
  | `OPTIONS -> `GET
  | `Other _ -> `GET
  | `CONNECT -> `GET
  | `TRACE -> `GET

(* Proxy a request to oauth2-proxy *)
let proxy_request oauth2_proxy_port path ctx =
  let request = Brtl_ctx.request ctx in
  let meth = Cohttp.Request.meth request in
  let headers = Cohttp.Request.headers request in

  (* Build the target URL for oauth2-proxy, preserving query params from original request *)
  let original_uri = Cohttp.Request.uri request in
  let uri =
    Uri.make ~scheme:"http" ~host:"127.0.0.1" ~port:oauth2_proxy_port ~path ()
    |> Fun.flip Uri.with_query (Uri.query original_uri)
  in

  (* Get request body if present *)
  let body = Brtl_ctx.body ctx in

  Logs.debug (fun m ->
      m
        "%s : Proxying %s %s to oauth2-proxy"
        (Brtl_ctx.token ctx)
        (Cohttp.Code.string_of_method meth)
        (Uri.path_and_query uri));

  (* Convert headers to list, filtering out hop-by-hop headers *)
  let skip_headers =
    [
      "host";
      "connection";
      "keep-alive";
      "transfer-encoding";
      "te";
      "trailer";
      "upgrade";
      "proxy-authorization";
      "proxy-connection";
    ]
  in
  let header_list =
    Cohttp.Header.fold
      (fun key value acc ->
        if CCList.mem ~eq:CCString.equal_caseless key skip_headers then acc else (key, value) :: acc)
      headers
      []
  in
  let curl_headers = Http.Headers.of_list header_list in

  let curl_method = convert_method meth (Some body) in

  let open Abb.Future.Infix_monad in
  (* Disable redirect following - we want to return 302 to the browser *)
  Http.call ~options:[] ~headers:curl_headers curl_method uri
  >>= function
  | Ok (resp, resp_body) ->
      let status = Cohttp.Code.status_of_code (Http.Status.to_int (Http.Response.status resp)) in
      let resp_headers = Http.Response.headers resp |> Http.Headers.to_list in

      (* Build response headers, filtering hop-by-hop headers *)
      let response_headers =
        CCList.filter
          (fun (k, _) -> not (CCList.mem ~eq:CCString.equal_caseless k skip_headers))
          resp_headers
      in

      Logs.debug (fun m ->
          m
            "%s : oauth2-proxy responded with %d"
            (Brtl_ctx.token ctx)
            (Http.Status.to_int (Http.Response.status resp)));

      let response =
        Brtl_rspnc.create ~status ~headers:(Cohttp.Header.of_list response_headers) resp_body
      in
      Abb.Future.return (Brtl_ctx.set_response response ctx)
  | Error err ->
      Logs.err (fun m ->
          m "%s : Failed to proxy to oauth2-proxy: %a" (Brtl_ctx.token ctx) Http.pp_request_err err);
      Abb.Future.return
        (Brtl_ctx.set_response
           (Brtl_rspnc.create ~status:`Bad_gateway "oauth2-proxy unavailable")
           ctx)

(* Run the proxy endpoint. The provider is extracted from the URL path but not used
   when proxying - oauth2-proxy expects /oauth2/{endpoint} not /oauth2/{provider}/{endpoint} *)
let run ~provider:_ oauth2_proxy endpoint =
  let port = Sgs_service_auth_oauth2_proxy.port oauth2_proxy in
  let path = Printf.sprintf "/oauth2/%s" endpoint in
  Brtl_ep.run ~content_type:"text/html" ~f:(fun ctx -> proxy_request port path ctx)
