module Verifier = struct
  let z_of_string s =
    s
    |> Base64.decode_exn ~pad:false ~alphabet:Base64.uri_safe_alphabet
    |> CCString.to_list
    |> CCList.map (fun c -> Printf.sprintf "%02x" (Char.code c))
    |> CCString.concat ""
    |> Z.of_string_base 16

  module Pub_key = struct
    type t = Mirage_crypto_pk.Rsa.pub

    let create ~e ~n =
      CCOption.wrap
        (fun () ->
          let e = z_of_string e in
          let n = z_of_string n in
          (* TODO: Handle errors *)
          CCResult.get_exn (Mirage_crypto_pk.Rsa.pub ~e ~n))
        ()

    let of_pub_key = CCFun.id
  end

  module Ec_pub_key = struct
    module Ec = Mirage_crypto_ec

    type t =
      | P256 of Ec.P256.Dsa.pub
      | P384 of Ec.P384.Dsa.pub
      | P521 of Ec.P521.Dsa.pub
      | Ed25519 of Ec.Ed25519.pub

    let create ~crv ~x ~y =
      let open CCOption.Infix in
      let decode =
        CCOption.wrap (Base64.decode_exn ~pad:false ~alphabet:Base64.uri_safe_alphabet)
      in
      (* An uncompressed point: [0x04 || x || y]. *)
      let point = decode x >>= fun x -> y >>= decode >|= fun y -> "\x04" ^ x ^ y in
      let pub of_octets octets = octets >>= fun octets -> CCResult.to_opt (of_octets octets) in
      match crv with
      | "P-256" -> pub Ec.P256.Dsa.pub_of_octets point >|= fun k -> P256 k
      | "P-384" -> pub Ec.P384.Dsa.pub_of_octets point >|= fun k -> P384 k
      | "P-521" -> pub Ec.P521.Dsa.pub_of_octets point >|= fun k -> P521 k
      | "Ed25519" -> pub Ec.Ed25519.pub_of_octets (decode x) >|= fun k -> Ed25519 k
      | _ -> None
  end

  type t =
    | HS256 of string
    | HS512 of string
    | RS256 of Pub_key.t
    | RS384 of Pub_key.t
    | RS512 of Pub_key.t
    | PS256 of Pub_key.t
    | PS384 of Pub_key.t
    | PS512 of Pub_key.t
    | ES256 of Ec_pub_key.t
    | ES384 of Ec_pub_key.t
    | ES512 of Ec_pub_key.t
    | EdDSA of Ec_pub_key.t

  let pkcs1_verify hash key hp signature =
    try Mirage_crypto_pk.Rsa.PKCS1.verify ~hashp:(( = ) hash) ~key ~signature (`Message hp)
    with Invalid_argument _ | Failure _ -> false

  let pss_verify (module H : Digestif.S) key hp signature =
    let module Pss = Mirage_crypto_pk.Rsa.PSS (H) in
    try Pss.verify ~key ~signature (`Message hp) with Invalid_argument _ | Failure _ -> false

  (* A JWS ECDSA signature is [r || s], each the curve's byte length. *)
  let ecdsa_verify (module H : Digestif.S) ~byte_length verify hp signature =
    match CCString.length signature = 2 * byte_length with
    | false -> false
    | true -> (
        let rs =
          (CCString.sub signature 0 byte_length, CCString.sub signature byte_length byte_length)
        in
        try verify rs H.(to_raw_string (digest_string hp))
        with Invalid_argument _ | Failure _ -> false)

  let eddsa_verify key hp signature =
    try Mirage_crypto_ec.Ed25519.verify ~key signature ~msg:hp
    with Invalid_argument _ | Failure _ -> false

  (* Constant-time comparison to prevent timing attacks *)
  let mac_verify algo hp signature = Eqaf.equal (algo hp) signature

  let verify t hp signature =
    let module Ec = Mirage_crypto_ec in
    let f =
      match t with
      | HS256 x -> mac_verify (fun m -> Digestif.SHA256.(to_raw_string (hmac_string ~key:x m)))
      | HS512 x -> mac_verify (fun m -> Digestif.SHA512.(to_raw_string (hmac_string ~key:x m)))
      | RS256 x -> pkcs1_verify `SHA256 x
      | RS384 x -> pkcs1_verify `SHA384 x
      | RS512 x -> pkcs1_verify `SHA512 x
      | PS256 x -> pss_verify (module Digestif.SHA256) x
      | PS384 x -> pss_verify (module Digestif.SHA384) x
      | PS512 x -> pss_verify (module Digestif.SHA512) x
      | ES256 (Ec_pub_key.P256 key) ->
          ecdsa_verify
            (module Digestif.SHA256)
            ~byte_length:Ec.P256.Dsa.byte_length
            (Ec.P256.Dsa.verify ~key)
      | ES384 (Ec_pub_key.P384 key) ->
          ecdsa_verify
            (module Digestif.SHA384)
            ~byte_length:Ec.P384.Dsa.byte_length
            (Ec.P384.Dsa.verify ~key)
      | ES512 (Ec_pub_key.P521 key) ->
          ecdsa_verify
            (module Digestif.SHA512)
            ~byte_length:Ec.P521.Dsa.byte_length
            (Ec.P521.Dsa.verify ~key)
      | EdDSA (Ec_pub_key.Ed25519 key) -> eddsa_verify key
      | ES256 _ | ES384 _ | ES512 _ | EdDSA _ -> fun _ _ -> false
    in
    f hp signature

  let to_string = function
    | HS256 _ -> "HS256"
    | HS512 _ -> "HS512"
    | RS256 _ -> "RS256"
    | RS384 _ -> "RS384"
    | RS512 _ -> "RS512"
    | PS256 _ -> "PS256"
    | PS384 _ -> "PS384"
    | PS512 _ -> "PS512"
    | ES256 _ -> "ES256"
    | ES384 _ -> "ES384"
    | ES512 _ -> "ES512"
    | EdDSA _ -> "EdDSA"
end

module Signer = struct
  module Priv_key = struct
    type t = Mirage_crypto_pk.Rsa.priv

    let of_priv_key = CCFun.id
  end

  type t =
    | HS256 of string
    | HS512 of string
    | RS256 of Priv_key.t

  let rs256_sign key hp = Mirage_crypto_pk.Rsa.PKCS1.sign ~hash:`SHA256 ~key (`Message hp)
  let mac_sign algo hp = algo hp

  let sign t hp =
    let f =
      match t with
      | HS256 x -> mac_sign (fun m -> Digestif.SHA256.(to_raw_string (hmac_string ~key:x m)))
      | HS512 x -> mac_sign (fun m -> Digestif.SHA512.(to_raw_string (hmac_string ~key:x m)))
      | RS256 x -> rs256_sign x
    in
    f hp

  let to_string = function
    | HS256 _ -> "HS256"
    | HS512 _ -> "HS512"
    | RS256 _ -> "RS256"
end

module Header = struct
  type t = (string * string) list

  let create ?(rest = []) ?(typ = "JWT") alg = ("typ", typ) :: ("alg", alg) :: rest
  let algorithm = CCList.Assoc.get ~eq:String.equal "alg"
  let typ = CCList.Assoc.get_exn ~eq:String.equal "typ"
  let get = CCList.Assoc.get ~eq:String.equal
  let to_json t = `Assoc (Sln_list.String.sort_assoc (CCList.map (fun (c, v) -> (c, `String v)) t))

  let to_string header =
    let json = to_json header in
    Yojson.Safe.to_string json

  let of_json =
    CCOption.wrap (fun json ->
        let assoc = Yojson.Safe.Util.to_assoc json in
        CCList.map
          (fun (c, v) ->
            match v with
            | `String s -> (c, s)
            | _ -> failwith "bad json")
          assoc)

  let of_string str =
    let open CCOption.Infix in
    CCOption.wrap Yojson.Safe.from_string str >>= fun json -> of_json json
end

module Claim = struct
  type t = string

  let iss = "iss"
  let sub = "sub"
  let aud = "aud"
  let exp = "exp"
  let nbf = "nbf"
  let iat = "iat"
  let jti = "jti"
  let ctyp = "ctyp"
  let auth_time = "auth_time"
  let nonce = "nonce"
  let acr = "acr"
  let amr = "amr"
  let azp = "azp"
end

module Payload = struct
  module Claim_map = Sln_map.String

  type typs = Yojson.Safe.t
  type t = typs Claim_map.t

  let empty = Claim_map.empty
  let add_claim claim value t = Claim_map.add claim value t
  let find_claim claim t = Claim_map.get claim t

  let find_claim_string claim t =
    match find_claim claim t with
    | Some (`String v) -> Some v
    | _ -> None

  let find_claim_bool claim t =
    match find_claim claim t with
    | Some (`Bool v) -> Some v
    | _ -> None

  let find_claim_float claim t =
    match find_claim claim t with
    | Some (`Float v) -> Some v
    | _ -> None

  let find_claim_int claim t =
    match find_claim claim t with
    | Some (`Int v) -> Some v
    | _ -> None

  let of_json =
    CCOption.wrap (fun json ->
        CCListLabels.fold_left
          ~f:(fun acc (claim, v) -> add_claim claim v acc)
          ~init:empty
          (Yojson.Safe.Util.to_assoc json))

  let of_string str =
    let open CCOption.Infix in
    CCOption.wrap Yojson.Safe.from_string str >>= fun json -> of_json json

  let to_json t =
    let t = (t : t :> Yojson.Safe.t Claim_map.t) in
    `Assoc (Sln_list.String.sort_assoc (Claim_map.to_list t))

  let to_string t = Yojson.Safe.to_string (to_json t)
end

type decoded = string
type verified = unit

type 'a t = {
  header : Header.t;
  payload : Payload.t;
  signature : string;
  hp : 'a;
}

let b64_url_encode str = Base64.encode_exn ~pad:false ~alphabet:Base64.uri_safe_alphabet str

let b64_url_decode str =
  CCOption.wrap (Base64.decode_exn ~pad:false ~alphabet:Base64.uri_safe_alphabet) str

let of_header_and_payload signer header payload =
  let b64_header = b64_url_encode (Header.to_string header) in
  let b64_payload = b64_url_encode (Payload.to_string payload) in
  let unsigned_token = b64_header ^ "." ^ b64_payload in
  let signature = Signer.sign signer unsigned_token in
  { header; payload; signature; hp = () }

let header t = t.header
let payload t = t.payload
let signature t = t.signature

let token t =
  let b64_header = b64_url_encode (Header.to_string (header t)) in
  let b64_payload = b64_url_encode (Payload.to_string (payload t)) in
  let b64_signature = b64_url_encode (signature t) in
  b64_header ^ "." ^ b64_payload ^ "." ^ b64_signature

let of_token token =
  let token_splitted = CCString.split_on_char '.' token in
  match token_splitted with
  | [ header_encoded; payload_encoded; signature_encoded ] ->
      let open CCOption.Infix in
      b64_url_decode header_encoded
      >>= fun header_decoded ->
      Header.of_string header_decoded
      >>= fun header ->
      b64_url_decode payload_encoded
      >>= fun payload_decoded ->
      Payload.of_string payload_decoded
      >>= fun payload ->
      b64_url_decode signature_encoded
      >>= fun signature ->
      Some { header; payload; signature; hp = header_encoded ^ "." ^ payload_encoded }
  | _ -> None

let verify verifier t =
  match Header.algorithm t.header with
  | Some alg
    when String.equal alg (Verifier.to_string verifier) && Verifier.verify verifier t.hp t.signature
    -> Some { header = t.header; payload = t.payload; signature = t.signature; hp = () }
  | Some _ | None -> None
