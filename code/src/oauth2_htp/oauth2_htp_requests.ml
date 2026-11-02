module Http = Abb_curl.Make (Abb)

type err =
  [ Http.request_err
  | `Unexpected_status of int * string
  | `Json_err of string
  ]
[@@deriving show]

module Result = struct
  type t = {
    response : Http.Response.t;
    body : string;
  }

  let status_code t = Http.Status.to_int (Http.Response.status t.response)
  let body t = t.body

  (* Only unmarshal the body if the response was successful. *)
  let unmarshal t =
    match status_code t with
    | 200 -> (
        try Ok (Yojson.Safe.from_string t.body)
        with Yojson.Json_error msg -> Error (`Json_err msg))
    | code -> Error (`Unexpected_status (code, t.body))
end

(* A sign-in waits on these calls, so one the remote end never answers must not hold it forever. *)
let timeout_ms = 30_000
let options = Http.Options.(with_opt (Curlopts [ Curl.CURLOPT_TIMEOUTMS timeout_ms ]) default)

let do_ ?(headers = []) ?body endpoint =
  let open Abb.Future.Infix_monad in
  let headers = Http.Headers.of_list headers in
  let uri = Uri.of_string endpoint in
  (match body with
    | Some body -> Http.post ~options ~headers ~body uri
    | None -> Http.get ~options ~headers uri)
  >>| CCResult.map (fun (response, body) -> { Result.response; body })

let unmarshal ?headers ?body endpoint =
  let open Abbs_fc.Infix_result_monad in
  do_ ?headers ?body endpoint >>= fun result -> Abb.Future.return (Result.unmarshal result)

let post_form ?(headers = []) endpoint params =
  unmarshal
    ~headers:(("Content-Type", "application/x-www-form-urlencoded") :: headers)
    ~body:(Oauth2_htp_values.encode params)
    endpoint
