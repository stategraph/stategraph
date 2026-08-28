module Http = Abb_curl.Make (Abb)

let base_url = Uri.of_string "https://api.github.com/"

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

type t = {
  auth : Authorization.t;
  base_url : Uri.t;
  headers : (string * string) list;
  call_timeout : float option;
}
[@@warning "-69"]

let create ?(user_agent = "Githubc2_abb") ?(base_url = base_url) ?call_timeout auth =
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
        ("accept", "application/vnd.github.v3+json");
        ( "authorization",
          match auth with
          | `Token token -> "token " ^ token
          | `Bearer bearer -> "Bearer " ^ bearer );
      ];
    call_timeout;
  }

let call t req =
  match t.call_timeout with
  | None -> Api.call Openapi.Request.(req |> with_base_url t.base_url |> add_headers t.headers)
  | Some timeout ->
      let open Abb.Future.Infix_monad in
      Abbs_future_combinators.first
        (Abb.Sys.sleep timeout >>= fun () -> Abbs_future_combinators.return_err `Timeout)
        (Api.call Openapi.Request.(req |> with_base_url t.base_url |> add_headers t.headers))
      >>= fun (r, fut) -> Abb.Future.abort fut >>= fun () -> Abb.Future.return r

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

let rec parse_links s =
  if String.length s > 0 then
    let open CCOption.Infix in
    match CCString.Split.left ~by:", " s with
    | Some (left, right) ->
        parse_link left >>= fun link -> parse_links right >>= fun rest -> Some (link :: rest)
    | None -> parse_link s >>= fun link -> Some [ link ]
  else Some []

let links resp =
  CCOption.get_or
    ~default:[]
    (parse_links
       (CCOption.get_or
          ~default:""
          (Http.Headers.get "link" (Http.Headers.of_list (Openapi.Response.headers resp)))))

let rec fold' t ~init ~f req =
  let open Abbs_future_combinators.Infix_result_monad in
  Api.call Openapi.Request.(req |> add_headers t.headers)
  >>= fun resp ->
  f init resp
  >>= fun init ->
  match List.assoc_opt "next" (links resp) with
  | Some next ->
      let req = Openapi.Request.with_url next req in
      fold' t ~init ~f req
  | None -> Abbs_future_combinators.return_ok init

let fold t ~init ~f req =
  let open Abbs_future_combinators.Infix_result_monad in
  (* With the initial call we want a standard call, with all URL replacement
     operations.  However on the next call we want to use the exact URL that we
     were given in pagination. *)
  call t req
  >>= fun resp ->
  f init resp
  >>= fun init ->
  match List.assoc_opt "next" (links resp) with
  | Some next ->
      let req = Openapi.Request.with_url next req in
      fold' t ~init ~f req
  | None -> Abbs_future_combinators.return_ok init

let collect_all t req =
  let open Abbs_future_combinators.Infix_result_monad in
  fold
    ~init:[]
    ~f:(fun acc resp ->
      match Openapi.Response.value resp with
      | `OK vs -> Abbs_future_combinators.return_ok (vs @ acc)
      | _ -> Abbs_future_combinators.return_err `Error)
    t
    req
  >>| fun res -> CCList.rev res
