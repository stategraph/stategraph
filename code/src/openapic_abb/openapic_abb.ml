module Http = Abb_curl.Make (Abb)

module Io = struct
  type 'a t = 'a Abb.Future.t
  type err = Http.request_err

  let ( >>= ) = Abb.Future.Infix_monad.( >>= )
  let return = Abb.Future.return

  let call' ?body ~headers ~meth uri =
    let meth' =
      match meth with
      | `Get -> `GET
      | `Delete -> `DELETE body
      | `Patch -> `PATCH body
      | `Put -> `PUT body
      | `Post -> `POST body
    in
    let headers' = Http.Headers.of_list headers in
    Http.call ~headers:headers' meth' uri
    >>= function
    | Ok (resp, body) ->
        let headers = resp |> Http.Response.headers |> Http.Headers.to_list in
        let status = resp |> Http.Response.status |> Http.Status.to_int in
        return (Ok (Openapi.Response.make ~headers ~request_uri:uri ~status body))
    | Error err -> return (Error (`Io_err err))

  let call ?body ~headers ~meth uri = call' ?body ~headers ~meth uri
end

module Api = Openapi.Make (Io)

module Authorization = struct
  type t =
    [ `Token of string
    | `Bearer of string
    ]
end

type call_err =
  [ `Conversion_err of string * string Openapi.Response.t
  | `Missing_response of string Openapi.Response.t
  | `Io_err of Http.request_err
  | `Timeout
  ]
[@@deriving show]

type 'a log =
  [ `Req of 'a Openapi.Request.t | `Resp of 'a Openapi.Response.t | `Err of call_err ] -> unit

module Page = struct
  type 'a t = 'a Openapi.Request.t -> 'a Openapi.Response.t -> 'a Openapi.Request.t option

  let github req resp =
    let parse_link s =
      let open CCOption.Infix in
      CCString.Split.left ~by:"; " s
      >>= fun (link, rel) ->
      let uri = Uri.of_string (String.sub link 1 (String.length link - 2)) in
      CCString.Split.left ~by:"=" rel
      >>= function
      | "rel", n ->
          let name = String.sub n 1 (String.length n - 2) in
          Some (name, uri)
      | _ -> None
    in
    let rec parse_links s =
      if String.length s > 0 then
        let open CCOption.Infix in
        match CCString.Split.left ~by:", " s with
        | Some (left, right) ->
            parse_link left >>= fun link -> parse_links right >>= fun rest -> Some (link :: rest)
        | None -> parse_link s >>= fun link -> Some [ link ]
      else Some []
    in
    let links resp =
      CCOption.get_or
        ~default:[]
        (parse_links
           (CCOption.get_or
              ~default:""
              (Http.Headers.get "link" (Http.Headers.of_list (Openapi.Response.headers resp)))))
    in
    match List.assoc_opt "next" (links resp) with
    | Some next -> Some (Openapi.Request.with_url next req)
    | None -> None

  let gitlab req resp =
    match
      Http.Headers.get "x-next-page" @@ Http.Headers.of_list @@ Openapi.Response.headers resp
    with
    | Some "" | None -> None
    | Some next_page ->
        req
        |> Openapi.Request.url
        |> CCFun.flip Uri.remove_query_param "page"
        |> CCFun.flip Uri.add_query_param' ("page", next_page)
        |> CCFun.flip Openapi.Request.with_url req
        |> CCOption.return
end

type t = {
  (* TODO: [auth] is captured by [create] but never read. Verify whether the auth header is
     actually being applied to outgoing requests, or wire it up if not. *)
  auth : Authorization.t;
  base_url : Uri.t;
  headers : (string * string) list;
  call_timeout : float option;
}
[@@warning "-69"]

let create ?(user_agent = "Openapic_abb") ?call_timeout ~base_url auth =
  let base_url =
    base_url
    |> Uri.to_string
    |> CCString.rev
    |> CCString.drop_while (( = ) '/')
    |> CCString.rev
    |> Uri.of_string
  in
  {
    auth;
    base_url;
    headers =
      [
        ("user-agent", user_agent);
        ("content-type", "application/json");
        ( "authorization",
          match auth with
          | `Token token -> "token " ^ token
          | `Bearer bearer -> "Bearer " ^ bearer );
      ];
    call_timeout;
  }

let maybe_with_base_url base_url req =
  (* As a heuristic, we will use if the URL has a scheme to decide if we should
     prepend the base url or the URL is already complete.  This is required for
     pagination, because some pagination systems provide partial URLs and others
     provide complete URLs. *)
  match Uri.scheme @@ Openapi.Request.url req with
  | None -> Openapi.Request.with_base_url base_url req
  | Some _ -> req

let call ?log t req =
  let open Abb.Future.Infix_monad in
  CCOption.iter (fun f -> f (`Req req)) log;
  match t.call_timeout with
  | None -> (
      Api.call Openapi.Request.(req |> maybe_with_base_url t.base_url |> add_headers t.headers)
      >>= function
      | Ok resp ->
          CCOption.iter (fun f -> f (`Resp resp)) log;
          Abbs_future_combinators.return_ok resp
      | Error (#call_err as call_err) ->
          CCOption.iter (fun f -> f (`Err call_err)) log;
          Abbs_future_combinators.return_err call_err)
  | Some timeout -> (
      Abbs_future_combinators.first
        (Abb.Sys.sleep timeout >>= fun () -> Abbs_future_combinators.return_err `Timeout)
        (Api.call Openapi.Request.(req |> with_base_url t.base_url |> add_headers t.headers))
      >>= fun (r, fut) ->
      Abb.Future.abort fut
      >>= fun () ->
      match r with
      | Ok resp ->
          CCOption.iter (fun f -> f (`Resp resp)) log;
          Abbs_future_combinators.return_ok resp
      | Error (#call_err as call_err) ->
          CCOption.iter (fun f -> f (`Err call_err)) log;
          Abbs_future_combinators.return_err call_err)

let rec fold' page t ~init ~f req =
  let open Abbs_future_combinators.Infix_result_monad in
  call t Openapi.Request.(req |> add_headers t.headers)
  >>= fun resp ->
  f init resp
  >>= fun init ->
  match page req resp with
  | Some req -> fold' page t ~init ~f req
  | None -> Abbs_future_combinators.return_ok init

let fold ~page t ~init ~f req =
  let open Abbs_future_combinators.Infix_result_monad in
  (* With the initial call we want a standard call, with all URL replacement
     operations.  However on the next call we want to use the exact URL that we
     were given in pagination. *)
  call t req
  >>= fun resp ->
  f init resp
  >>= fun init ->
  match page req resp with
  | Some req -> fold' page t ~init ~f req
  | None -> Abbs_future_combinators.return_ok init

let collect_all ~page t req =
  let open Abbs_future_combinators.Infix_result_monad in
  fold
    ~page
    ~init:[]
    ~f:(fun acc resp ->
      match Openapi.Response.value resp with
      | `OK vs -> Abbs_future_combinators.return_ok (vs @ acc)
      | _ -> Abbs_future_combinators.return_err `Error)
    t
    req
  >>| fun res -> CCList.rev res
