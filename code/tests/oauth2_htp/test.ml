(* Unit tests for the OAuth2 sign-in.  Anything that needs the network lives in the end to end
   suite. *)

module Enc = Oauth2_htp_encryption
module Oth_abb = Oth_abb.Make (Abb)

let secret_16 = "0123456789abcdef"
let secret_24 = "0123456789abcdef01234567"
let secret_32 = "0123456789abcdef0123456789abcdef"
let now = 1_700_000_000.

(* A request is read out of a {!Brtl_ctx}, so that is what the tests build. *)
let request ?(cookies = []) path =
  let headers =
    match cookies with
    | [] -> []
    | cookies ->
        [
          ( "Cookie",
            CCString.concat
              "; "
              (CCList.map
                 (fun c ->
                   Printf.sprintf "%s=%s" c.Oauth2_htp_cookie.name c.Oauth2_htp_cookie.value)
                 cookies) );
        ]
  in
  Oauth2_htp_request.of_ctx
    (Brtl_ctx.set_body
       ""
       (Brtl_ctx.create
          ""
          (Cohttp.Request.make ~headers:(Cohttp.Header.of_list headers) (Uri.of_string path))))

(* {2 Redirects} *)

let split_host_port_test =
  Oth_abb.test ~name:"redirect.split_host_port" (fun () ->
      let check ~input ~host ~port =
        let actual_host, actual_port = Oauth2_htp_redirect.split_host_port input in
        Oth_abb.Assert.Eq.string ~expected:host ~actual:actual_host;
        Oth_abb.Assert.Eq.string ~expected:port ~actual:actual_port
      in
      check ~input:"example.com" ~host:"example.com" ~port:"";
      check ~input:"example.com:8080" ~host:"example.com" ~port:"8080";
      check ~input:"example.com:*" ~host:"example.com" ~port:"*";
      (* A non numeric port is not a port at all; the whole input is the host. *)
      check ~input:"example.com:http" ~host:"example.com:http" ~port:"";
      check ~input:"[::1]:8080" ~host:"::1" ~port:"8080";
      check ~input:"[::1]" ~host:"::1" ~port:"";
      Abb.Future.return ())

let is_endpoint_allowed_test =
  Oth_abb.test ~name:"redirect.is_endpoint_allowed" (fun () ->
      let check ~url ~domains ~expected =
        Oth_abb.Assert.Eq.bool
          ~expected
          ~actual:(Oauth2_htp_redirect.is_endpoint_allowed (Uri.of_string url) domains)
      in
      check ~url:"https://example.com/x" ~domains:[ "example.com" ] ~expected:true;
      check ~url:"https://foo.example.com/x" ~domains:[ "example.com" ] ~expected:false;
      (* A leading dot or star matches the domain itself and any subdomain. *)
      check ~url:"https://foo.example.com/x" ~domains:[ ".example.com" ] ~expected:true;
      check ~url:"https://example.com/x" ~domains:[ ".example.com" ] ~expected:true;
      check ~url:"https://foo.example.com/x" ~domains:[ "*.example.com" ] ~expected:true;
      (* Without a port in the allowed domain only the default ports are allowed. *)
      check ~url:"https://example.com:8080/x" ~domains:[ "example.com" ] ~expected:false;
      check ~url:"https://example.com:8080/x" ~domains:[ "example.com:8080" ] ~expected:true;
      check ~url:"https://example.com:8080/x" ~domains:[ "example.com:*" ] ~expected:true;
      check ~url:"https://example.com/x" ~domains:[] ~expected:false;
      Abb.Future.return ())

let is_valid_redirect_test =
  Oth_abb.test ~name:"redirect.is_valid_redirect" (fun () ->
      let check redirect expected =
        Oth_abb.Assert.Eq.bool
          ~expected
          ~actual:
            (Oauth2_htp_redirect.is_valid_redirect ~allowed_domains:[ "example.com" ] redirect)
      in
      check "/foo" true;
      check "/foo/bar?a=b" true;
      check "" false;
      (* Protocol relative and mixed slash forms are open redirects. *)
      check "//evil.test" false;
      check "/\\evil.test" false;
      check "/ /evil.test" false;
      check "/../evil.test" false;
      check "https://example.com/x" true;
      check "https://evil.test/x" false;
      check "ftp://example.com/x" false;
      Abb.Future.return ())

(* {2 Encryption} *)

let secret_bytes_test =
  Oth_abb.test ~name:"encryption.secret_bytes" (fun () ->
      (* A base64 encoded secret that decodes to a valid AES length is decoded. *)
      let encoded = Base64.encode_string ~pad:false ~alphabet:Base64.uri_safe_alphabet secret_32 in
      Oth_abb.Assert.Eq.string ~expected:secret_32 ~actual:(Enc.secret_bytes encoded);
      (* Anything else is taken as the raw secret. *)
      Oth_abb.Assert.Eq.string ~expected:secret_16 ~actual:(Enc.secret_bytes secret_16);
      Oth_abb.Assert.Eq.string ~expected:"not base64 $$" ~actual:(Enc.secret_bytes "not base64 $$");
      Abb.Future.return ())

let cipher_test =
  Oth_abb.test ~name:"encryption.cipher" (fun () ->
      CCList.iter
        (fun secret ->
          CCList.iter
            (fun value ->
              let encrypted = Oth_abb.Assert.ok_pp ~pp:Enc.pp_err (Enc.encrypt ~secret value) in
              Oth_abb.Assert.Eq.string
                ~expected:value
                ~actual:(Oth_abb.Assert.ok_pp ~pp:Enc.pp_err (Enc.decrypt ~secret encrypted)))
            [ ""; "x"; "0123456789abcdef"; "0123456789abcdef0123456789abcdefzz" ])
        [ secret_16; secret_24; secret_32 ];
      let _ = Oth_abb.Assert.error_pp ~pp:(fun _ _ -> ()) (Enc.encrypt ~secret:"too short" "x") in
      let _ = Oth_abb.Assert.error_pp ~pp:(fun _ _ -> ()) (Enc.decrypt ~secret:secret_16 "short") in
      Abb.Future.return ())

let signed_value_test =
  Oth_abb.test ~name:"encryption.signed_value" (fun () ->
      let value = "the payload" in
      let signed = Enc.signed_value ~seed:"seed" ~key:"csrf" ~value ~now in
      let validate
          ?(name = "csrf")
          ?(seed = "seed")
          ?(expiration = Duration.of_hour 1)
          ?(now = now)
          value =
        Enc.validate ~name ~value ~seed ~expiration ~now
      in
      let decoded, t = Oth_abb.Assert.some (validate signed) in
      Oth_abb.Assert.Eq.string ~expected:value ~actual:decoded;
      Oth_abb.Assert.Eq.string ~expected:(CCFloat.to_string now) ~actual:(CCFloat.to_string t);
      (* A different seed, a different cookie name, or a tampered payload all fail the signature. *)
      Oth_abb.Assert.none_pp ~pp:(fun _ _ -> ()) (validate ~seed:"other" signed);
      Oth_abb.Assert.none_pp ~pp:(fun _ _ -> ()) (validate ~name:"other" signed);
      Oth_abb.Assert.none_pp ~pp:(fun _ _ -> ()) (validate ("x" ^ signed));
      (* Outside the expiration window it is rejected. *)
      Oth_abb.Assert.none_pp
        ~pp:(fun _ _ -> ())
        (validate ~expiration:(Duration.of_min 1) ~now:(now +. 3600.) signed);
      (* A value that is not three parts is not a signed value at all. *)
      Oth_abb.Assert.none_pp ~pp:(fun _ _ -> ()) (validate "not|signed");
      Abb.Future.return ())

let nonce_test =
  Oth_abb.test ~name:"encryption.nonce" (fun () ->
      let nonce = Enc.nonce 32 in
      Oth_abb.Assert.Eq.int ~expected:32 ~actual:(CCString.length nonce);
      let hashed = Enc.hash_nonce nonce in
      Oth_abb.Assert.true_ (Enc.check_nonce nonce hashed);
      Oth_abb.Assert.not_true (Enc.check_nonce (Enc.nonce 32) hashed);
      Abb.Future.return ())

(* {2 Email domains} *)

(* {2 JWKS} *)

let jwk_test =
  Oth_abb.test ~name:"jwk" (fun () ->
      let jwks =
        {|{"keys":[{"kty":"RSA","use":"sig","alg":"RS256","kid":"k1","n":"AQAB","e":"AQAB","x5c":["MIIBfake"],"x5t":"fake"}]}|}
      in
      let jwk = Oth_abb.Assert.some (Jwk.of_string jwks) in
      let key = Oth_abb.Assert.some (Jwk.get_kid "k1" jwk) in
      Oth_abb.Assert.Eq.string
        ~expected:"AQAB"
        ~actual:(CCOption.get_or ~default:"" (Jwk.Key.get "n" key));
      Oth_abb.Assert.none (Jwk.Key.get "x5c" key);
      (* A key without a kid is still one of the set. *)
      let jwk =
        Oth_abb.Assert.some
          (Jwk.of_string
             {|{"keys":[{"kty":"EC","crv":"P-256","x":"AA","y":"AA"},{"kty":"RSA","kid":"k1","n":"AQAB","e":"AQAB"}]}|})
      in
      Oth_abb.Assert.Eq.int ~expected:2 ~actual:(CCList.length (Jwk.keys jwk));
      ignore (Oth_abb.Assert.some (Jwk.get_kid "k1" jwk));
      Abb.Future.return ())

(* {2 JSON} *)

let json_test =
  Oth_abb.test ~name:"json" (fun () ->
      let module Json = Oauth2_htp_json in
      let json_equal expected actual =
        Oth_abb.Assert.true_ (CCOption.equal Yojson.Safe.equal expected actual)
      in
      let obj = `Assoc [ ("a", `Int 1); ("n", `Null) ] in
      json_equal (Some (`Int 1)) (Json.member "a" obj);
      json_equal (Some `Null) (Json.member "n" obj);
      Oth_abb.Assert.none (Json.member "b" obj);
      Oth_abb.Assert.none (Json.member "a" (`List [ obj ]));
      Oth_abb.Assert.Eq.string
        ~expected:"x"
        ~actual:(Oth_abb.Assert.some (Json.string (`String "x")));
      Oth_abb.Assert.none (Json.string (`Int 1));
      Oth_abb.Assert.none (Json.string `Null);
      Oth_abb.Assert.not_true @@ Oth_abb.Assert.some (Json.bool (`Bool false));
      Oth_abb.Assert.none (Json.bool (`String "true"));
      Oth_abb.Assert.List.length ~expected:1 (Oth_abb.Assert.some (Json.list (`List [ `Null ])));
      Oth_abb.Assert.none (Json.list obj);
      Abb.Future.return ())

(* {2 Email domains} *)

let validator_test =
  Oth_abb.test ~name:"validator" (fun () ->
      let validate =
        Oauth2_htp_validator.create ~email_domains:[ "example.com"; ".sub.example.org" ]
      in
      Oth_abb.Assert.true_ (validate "a@example.com");
      Oth_abb.Assert.true_ (validate "A@EXAMPLE.COM");
      Oth_abb.Assert.true_ (validate "a@deep.sub.example.org");
      Oth_abb.Assert.not_true (validate "a@other.com");
      Oth_abb.Assert.not_true (validate "a@notexample.com");
      Oth_abb.Assert.not_true (validate "");
      let allow_all = Oauth2_htp_validator.create ~email_domains:[ "*" ] in
      Oth_abb.Assert.true_ (allow_all "a@anywhere.test");
      Oth_abb.Assert.not_true (allow_all "");
      Abb.Future.return ())

(* {2 CSRF cookie} *)

let csrf_test =
  Oth_abb.test ~name:"csrf" (fun () ->
      let csrf = Oauth2_htp_csrf.create () in
      let state = Oauth2_htp_csrf.hashed_state csrf in
      Oth_abb.Assert.true_ (Oauth2_htp_csrf.check_state csrf state);
      Oth_abb.Assert.not_true (Oauth2_htp_csrf.check_state (Oauth2_htp_csrf.create ()) state);
      let cookie =
        Oth_abb.Assert.ok_pp
          ~pp:Oauth2_htp_csrf.pp_err
          (Oauth2_htp_csrf.set_cookie ~now ~secret:secret_32 ~secure:true csrf)
      in
      Oth_abb.Assert.str_contains_all
        ~haystack:(Oauth2_htp_cookie.to_set_cookie_header cookie)
        ~needles:
          [
            Oauth2_htp_csrf.cookie_name ^ "=";
            "Path=/";
            "Max-Age=900";
            "HttpOnly";
            "Secure";
            "SameSite=Lax";
          ];
      (* The round trip goes through the request's Cookie header, as it would from a browser. *)
      let req = request ~cookies:[ cookie ] "/" in
      let loaded =
        Oth_abb.Assert.ok_pp
          ~pp:Oauth2_htp_csrf.pp_err
          (Oauth2_htp_csrf.load ~now ~secret:secret_32 req)
      in
      Oth_abb.Assert.true_ (Oauth2_htp_csrf.check_state loaded state);
      let expect_error ?(now = now) ?(secret = secret_32) req expected =
        match Oauth2_htp_csrf.load ~now ~secret req with
        | Error err when expected err -> ()
        | Error err -> Oth_abb.Assert.false_ (Oauth2_htp_csrf.show_err err)
        | Ok _ -> Oth_abb.Assert.false_ "the CSRF cookie loaded"
      in
      (* A cookie signed with a different secret, an expired one and a missing one do not load. *)
      expect_error ~secret:secret_16 req (function
        | `Cookie_failed_validation -> true
        | _ -> false);
      expect_error ~now:(now +. 3600.) req (function
        | `Cookie_failed_validation -> true
        | _ -> false);
      expect_error (request "/") (function
        | `Cookie_not_found -> true
        | _ -> false);
      Oth_abb.Assert.Eq.int
        ~expected:(-1)
        ~actual:(Oauth2_htp_csrf.clear ~secure:true).Oauth2_htp_cookie.max_age;
      Abb.Future.return ())

(* {2 The flow} *)

let config ?(email_domains = [ "example.com" ]) () =
  Oauth2_htp.Config.make
    ~login_params:[ ("prompt", "select_account") ]
    ~provider:(Oauth2_htp.Config.Google { group = None })
    ~client_id:"client"
    ~client_secret:"secret"
    ~redirect_url:"https://proxy.test/oauth2/google/callback"
    ~whitelist_domains:[ "app.test" ]
    ~email_domains
    ~cookie_secret:secret_32
    ~cookie_secure:true
    ()

let create () =
  let open Abb.Future.Infix_monad in
  Oauth2_htp.create (config ()) >>| Oth_abb.Assert.ok_pp ~pp:Oauth2_htp.pp_err

let start t rd =
  let open Abb.Future.Infix_monad in
  Oauth2_htp.oauth_start t ~now (request ("/oauth2/google/start?rd=" ^ Form_urlencode.encode rd))
  >>| Oth_abb.Assert.ok_pp ~pp:Oauth2_htp.pp_err

let state_of start =
  Oauth2_htp_values.get "state" (Uri.query (Uri.of_string start.Oauth2_htp.Start_result.login_url))

let oauth_start_test =
  Oth_abb.test ~name:"oauth2_htp.oauth_start" (fun () ->
      let open Abb.Future.Infix_monad in
      create ()
      >>= fun t ->
      start t "/app?a=b"
      >>= fun res ->
      let login_url = Uri.of_string res.Oauth2_htp.Start_result.login_url in
      Oth_abb.Assert.Eq.string
        ~expected:"https://accounts.google.com/o/oauth2/auth"
        ~actual:(Uri.to_string (Uri.with_query login_url []));
      CCList.iter
        (fun (k, v) ->
          Oth_abb.Assert.Eq.string
            ~expected:v
            ~actual:(Oauth2_htp_values.get k (Uri.query login_url)))
        [
          ("client_id", "client");
          ("redirect_uri", "https://proxy.test/oauth2/google/callback");
          ("response_type", "code");
          ("scope", "openid email profile");
          ("prompt", "select_account");
        ];
      (* The state carries the hashed CSRF nonce and the application redirect, and the CSRF cookie
         that comes back agrees with it. *)
      let nonce, redirect = Oth_abb.Assert.some (CCString.Split.left ~by:":" (state_of res)) in
      Oth_abb.Assert.Eq.string ~expected:"/app?a=b" ~actual:redirect;
      let cookie = Oth_abb.Assert.List.length_one res.Oauth2_htp.Start_result.set_cookies in
      let csrf =
        Oth_abb.Assert.ok_pp
          ~pp:Oauth2_htp_csrf.pp_err
          (Oauth2_htp_csrf.load ~now ~secret:secret_32 (request ~cookies:[ cookie ] "/"))
      in
      Oth_abb.Assert.true_ (Oauth2_htp_csrf.check_state csrf nonce);
      (* An unsafe destination is replaced by the root, and an absolute one must be whitelisted. *)
      start t "//evil.test/x"
      >>= fun res ->
      Oth_abb.Assert.str_contains ~haystack:(state_of res) ~needle:":/";
      Oth_abb.Assert.str_doesnt_contain ~haystack:(state_of res) ~needle:"evil";
      start t "https://app.test/x"
      >>= fun res ->
      Oth_abb.Assert.str_contains ~haystack:(state_of res) ~needle:":https://app.test/x";
      Abb.Future.return ())

let oauth_callback_rejects_test =
  Oth_abb.test ~name:"oauth2_htp.oauth_callback_rejects" (fun () ->
      let open Abb.Future.Infix_monad in
      create ()
      >>= fun t ->
      start t "/app"
      >>= fun res ->
      let cookies = res.Oauth2_htp.Start_result.set_cookies in
      let state = state_of res in
      let expect req expected =
        Oauth2_htp.oauth_callback t ~now req
        >>| function
        | Error err when expected err -> ()
        | Error err -> Oth_abb.Assert.false_ (Oauth2_htp.show_err err)
        | Ok _ -> Oth_abb.Assert.false_ "the callback signed someone in"
      in
      let callback query = "/oauth2/google/callback?" ^ query in
      (* An error reflected by the IdP short-circuits everything else. *)
      expect
        (request (callback "error=access_denied"))
        (function
          | `Idp_error ("access_denied", "") -> true
          | _ -> false)
      >>= fun () ->
      (* A state that does not decode is rejected before any network call. *)
      expect
        (request ~cookies (callback "state=nocolon"))
        (function
          | `Invalid_state -> true
          | _ -> false)
      >>= fun () ->
      (* A well formed state with no CSRF cookie present is rejected. *)
      expect
        (request (callback ("code=c&state=" ^ Form_urlencode.encode state)))
        (function
          | `Missing_csrf_cookie -> true
          | _ -> false)
      >>= fun () ->
      (* So is a state the CSRF cookie does not agree with. *)
      expect
        (request ~cookies (callback "code=c&state=forged%3A%2Fapp"))
        (function
          | `Csrf_token_mismatch -> true
          | _ -> false)
      >>= fun () ->
      (* And a matching state without a code. *)
      expect
        (request ~cookies (callback ("state=" ^ Form_urlencode.encode state)))
        (function
          | `Missing_code -> true
          | _ -> false))

let () =
  Mirage_crypto_rng_unix.use_default ();
  Oth_abb.run
    ~file:__FILE__
    ~setup:(fun () -> Abb.Future.return (Ok ()))
    ~teardown:(fun _ -> Abb.Future.return ())
    (fun _ ->
      Oth_abb.parallel
        [
          split_host_port_test;
          is_endpoint_allowed_test;
          is_valid_redirect_test;
          secret_bytes_test;
          cipher_test;
          signed_value_test;
          nonce_test;
          jwk_test;
          json_test;
          validator_test;
          csrf_test;
          oauth_start_test;
          oauth_callback_rejects_test;
        ])
