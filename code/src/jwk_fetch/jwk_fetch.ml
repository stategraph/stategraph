module Http = Cohttp_abb.Make (Abb)

type err =
  [ Cohttp_abb.request_err
  | `Bad_response
  ]

let get_max_age cache_control =
  let vs = CCString.split_on_char ',' cache_control in
  let assoc =
    CCList.map
      (fun s ->
        let s = CCString.trim s in
        CCOption.get_or ~default:(s, "") (CCString.Split.left ~by:"=" s))
      vs
  in
  match CCList.Assoc.get ~eq:CCString.equal "max-age" assoc with
  | Some max_age -> CCOption.get_or ~default:0 (CCInt.of_string max_age)
  | None -> 0

let fetch uri =
  let open Abbs_future_combinators.Infix_result_monad in
  Http.Client.get uri
  >>? function
  | resp, body when resp.Http.Response.status = `OK -> (
      let headers = Http.Response.headers resp in
      let cache_control = CCOption.get_or ~default:"" (Cohttp.Header.get headers "cache-control") in
      let max_age = get_max_age cache_control in
      match Jwk.of_string body with
      | Some jwk -> Ok (jwk, max_age)
      | None -> Error `Bad_response)
  | _ -> Error `Bad_response
