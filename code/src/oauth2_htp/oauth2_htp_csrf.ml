module Enc = Oauth2_htp_encryption

type err =
  [ Oauth2_htp_encryption.err
  | `Cookie_not_found
  | `Cookie_failed_validation
  | `Malformed_cookie of string
  ]
[@@deriving show]

module Payload = struct
  type t = { s : string } [@@deriving yojson { strict = false }]
end

type t = { state : string }

let cookie_name = "_oauth2_csrf"
let expire = Duration.of_min 15
let create () = { state = Enc.nonce 32 }
let hashed_state t = Enc.hash_nonce t.state
let check_state t hashed = Enc.check_nonce t.state hashed

let set_cookie ~now ~secret ~secure t =
  CCResult.map
    (fun encrypted ->
      {
        Oauth2_htp_cookie.name = cookie_name;
        value = Enc.signed_value ~seed:secret ~key:cookie_name ~value:encrypted ~now;
        max_age = Duration.to_sec expire;
        secure;
      })
    (Enc.encrypt ~secret (Yojson.Safe.to_string (Payload.to_yojson { Payload.s = t.state })))

let load ~now ~secret req =
  let open CCResult.Infix in
  match Sln_list.String.assoc_opt cookie_name (Oauth2_htp_request.cookies req) with
  | None -> Error `Cookie_not_found
  | Some value -> (
      match Enc.validate ~name:cookie_name ~value ~seed:secret ~expiration:expire ~now with
      | None -> Error `Cookie_failed_validation
      | Some (encrypted, _) -> (
          Enc.decrypt ~secret encrypted
          >>= fun payload ->
          match
            CCResult.flat_map
              Payload.of_yojson
              (try Ok (Yojson.Safe.from_string payload) with Yojson.Json_error msg -> Error msg)
          with
          | Ok { Payload.s } -> Ok { state = s }
          | Error msg -> Error (`Malformed_cookie msg)))

let clear ~secure = { Oauth2_htp_cookie.name = cookie_name; value = ""; max_age = -1; secure }
