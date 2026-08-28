type create_err =
  [ `Refresh_token_err
  | `Missing_api_key_err
  | Openapic_abb.call_err
  ]
[@@deriving show]

exception Create_err_exn of create_err

type t = {
  base_url : Uri.t;
  api_key : string;
  call_timeout : float option;
  mutable client : Openapic_abb.t;
}

let create' ?call_timeout ~api_key ~base_url () =
  let open Abbs_future_combinators.Infix_result_monad in
  try
    let client =
      Openapic_abb.create ~user_agent:"Ttm Client" ?call_timeout ~base_url (`Bearer api_key)
    in
    Openapic_abb.call client Terrat_api_access_token.Refresh.(make ())
    >>? fun resp ->
    match Openapi.Response.value resp with
    | `OK { Terrat_api_access_token.Refresh.Responses.OK.token } ->
        Ok
          {
            base_url;
            api_key;
            call_timeout;
            client =
              Openapic_abb.create ~user_agent:"Ttm Client" ?call_timeout ~base_url (`Bearer token);
          }
    | `Forbidden -> Error `Refresh_token_err
  with Create_err_exn err ->
    Abbs_future_combinators.return_err (err : create_err :> [> create_err ])

let create ?call_timeout ?api_key ~base_url () =
  try
    let api_key =
      match api_key with
      | Some api_key -> api_key
      | None -> (
          match Sys.getenv_opt "TTM_API_KEY" with
          | Some api_key -> api_key
          | None -> raise (Create_err_exn `Missing_api_key_err))
    in
    let client =
      Openapic_abb.create ~user_agent:"Ttm Client" ?call_timeout ~base_url (`Bearer api_key)
    in
    Abbs_future_combinators.return_ok { base_url; api_key; call_timeout; client }
  with Create_err_exn err ->
    Abbs_future_combinators.return_err (err : create_err :> [> create_err ])

let call ?(tries = 3) t req =
  let open Abbs_future_combinators.Infix_result_monad in
  Abbs_future_combinators.retry
    ~f:(fun () ->
      Openapic_abb.call t.client req
      >>= function
      | resp when Openapi.Response.status resp = 403 ->
          (* It's a Forbidden response, so assume the token needs to be re-upped *)
          create' ?call_timeout:t.call_timeout ~api_key:t.api_key ~base_url:t.base_url ()
          >>| fun c ->
          t.client <- c.client;
          resp
      | resp -> Abbs_future_combinators.return_ok resp)
    ~while_:
      (Abbs_future_combinators.finite_tries tries (function
        | Error `Refresh_token_err -> false
        | Error _ -> true
        | Ok resp ->
            (* Retry on server side failures or forbidden on the remote side *)
            Openapi.Response.(status resp >= 500 || status resp = 403)))
    ~betwixt:
      (Abbs_future_combinators.series ~start:1.5 ~step:(( *. ) 1.5) (fun n _ -> Abb.Sys.sleep n))
