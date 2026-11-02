type err =
  [ `Invalid_key_size of int
  | `Ciphertext_too_short of int
  ]
[@@deriving show]

(* The AES block size, which is also the CFB segment size. *)
let block_size = 16
let b64_url_encode s = Base64.encode_string ~pad:true ~alphabet:Base64.uri_safe_alphabet s
let b64_url_decode s = Base64.decode ~pad:true ~alphabet:Base64.uri_safe_alphabet s
let b64_raw_url_encode s = Base64.encode_string ~pad:false ~alphabet:Base64.uri_safe_alphabet s
let b64_raw_url_decode s = Base64.decode ~pad:false ~alphabet:Base64.uri_safe_alphabet s

let xor a b =
  CCString.init (CCString.length a) (fun i -> Char.chr (Char.code a.[i] lxor Char.code b.[i]))

let secret_bytes secret =
  match b64_raw_url_decode (CCString.rdrop_while (Char.equal '=') secret) with
  (* Only return the decoded form if it is a valid AES length.  An unintentional decoding resulting
     in an invalid length would confuse a user that thought they used a 16, 24 or 32 length
     string. *)
  | Ok b when CCList.mem ~eq:CCInt.equal (CCString.length b) [ 16; 24; 32 ] -> b
  | Ok _ | Error (`Msg _) -> secret

let key_of_secret secret =
  let secret = secret_bytes secret in
  try Ok (Mirage_crypto.AES.ECB.of_secret secret)
  with Invalid_argument _ -> Error (`Invalid_key_size (CCString.length secret))

(* CFB128.  Each block of the input is XORed with the
   encryption of the previous ciphertext block (the IV, for the first block).  A trailing partial
   block is truncated, and the shift register keeps the tail of the previous IV, which is
   unobservable because no further block follows. *)
let cfb_crypt ~decrypt ~key ~iv data =
  let len = CCString.length data in
  let rec go off iv acc =
    match off >= len with
    | true -> CCString.concat "" (CCList.rev acc)
    | false ->
        let n = CCInt.min block_size (len - off) in
        let ks = Mirage_crypto.AES.ECB.encrypt ~key iv in
        let src = CCString.sub data off n in
        let dst = xor src (CCString.sub ks 0 n) in
        let feed = if decrypt then src else dst in
        go (off + n) (feed ^ CCString.sub iv n (block_size - n)) (dst :: acc)
  in
  go 0 iv []

let encrypt ~secret value =
  CCResult.map
    (fun key ->
      let iv = Mirage_crypto_rng.generate block_size in
      iv ^ cfb_crypt ~decrypt:false ~key ~iv value)
    (key_of_secret secret)

let decrypt ~secret ciphertext =
  match CCString.length ciphertext < block_size with
  | true -> Error (`Ciphertext_too_short (CCString.length ciphertext))
  | false ->
      CCResult.map
        (fun key ->
          let iv = CCString.sub ciphertext 0 block_size in
          cfb_crypt
            ~decrypt:true
            ~key
            ~iv
            (CCString.sub ciphertext block_size (CCString.length ciphertext - block_size)))
        (key_of_secret secret)

let nonce length = Mirage_crypto_rng.generate length
let hash_nonce nonce = b64_raw_url_encode Digestif.SHA256.(to_raw_string (digest_string nonce))
let check_nonce nonce hashed = Eqaf.equal (hash_nonce nonce) hashed

(* Cookies are stored in 3 parts (value + timestamp + signature) to enforce that the values are as
   originally set.  Additionally, the value is encrypted so it is opaque to the browser. *)
let cookie_signature ~seed parts =
  b64_url_encode Digestif.SHA256.(to_raw_string (hmac_string ~key:seed (CCString.concat "" parts)))

let check_signature ~seed signature parts =
  match (b64_url_decode signature, b64_url_decode (cookie_signature ~seed parts)) with
  | Ok input_mac, Ok expected_mac -> Eqaf.equal input_mac expected_mac
  | (Ok _ | Error (`Msg _)), _ -> false

let signed_value ~seed ~key ~value ~now =
  let encoded_value = b64_url_encode value in
  let time_str = Printf.sprintf "%d" (CCFloat.to_int now) in
  let sig_ = cookie_signature ~seed [ key; encoded_value; time_str ] in
  Printf.sprintf "%s|%s|%s" encoded_value time_str sig_

let validate ~name ~value ~seed ~expiration ~now =
  match CCString.split_on_char '|' value with
  | [ value; timestamp; signature ] when check_signature ~seed signature [ name; value; timestamp ]
    -> (
      match CCInt.of_string timestamp with
      | Some ts
        when CCFloat.of_int ts > now -. Duration.to_f expiration && CCFloat.of_int ts < now +. 300.
        -> (
          match b64_url_decode value with
          | Ok raw_value -> Some (raw_value, CCFloat.of_int ts)
          | Error (`Msg _) -> None)
      | Some _ | None -> None)
  | _ :: _ | [] -> None
