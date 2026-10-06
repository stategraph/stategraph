let src = Logs.Src.create "user_session"

module Logs = (val Logs.src_log src : Logs.LOG)

module Sql = struct
  (* [data] is hex of the key bytes whatever the type holds, so one decode serves
     both: a 'hmac' row yields the raw secret, an 'rsa' row the PEM text. *)
  let select_encryption_keys () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* data *)
      Ret.(u text (fun h -> Some (Cstruct.to_string (Cstruct.of_hex h))))
      //
      (* type *)
      Ret.text
      /^ "select data, type from encryption_keys order by rank")

  (* Takes the next free rank rather than a fixed one, because the HMAC rows own
     the ranks already in use. [where not exists] keeps a second instance from
     adding a redundant key once the first has committed one, and the [on
     conflict] settles the window where neither has. *)
  let insert_signing_key () =
    Pgsql_io.Typed_sql.(
      sql
      /^ "insert into encryption_keys (rank, type, data) select (select coalesce(max(rank), -1) + \
          1 from encryption_keys), 'rsa', $data where not exists (select 1 from encryption_keys \
          where type = 'rsa') on conflict (rank) do nothing"
      /% Var.text "data")
end

module Session = struct
  module Expiration = struct
    type t =
      | Duration of {
          duration : Duration.t;
          capabilities : Sg_caps.t;
        }
      | Access_token of Uuidm.t
    [@@deriving show]
  end

  module Metadata = struct
    type t = Yojson.Safe.t [@@deriving yojson, show]
  end

  type minted = Sgs_user.minted Sgs_user.t [@@deriving show]

  type stored = {
    user : Sgs_user.stored Sgs_user.t;
    capabilities : Sg_caps.t;
  }
  [@@deriving show]

  (* [user_id] is duplicated at the top level so that [to_token] can serialize any session
     without inspecting the state-specific payload [v].  Invariant: [user_id] equals the id of
     the user held in [v] ([v] itself for [minted], [v.user] for [stored]). *)
  type 'a t = {
    metadata : Metadata.t option;
    expiration : Expiration.t;
    user_id : Uuidm.t;
    v : 'a;
  }
  [@@deriving show]

  (* A [Duration] session lives only in its JWT: there is no row to delete, so it cannot be revoked
     before it expires.  Cap its lifetime so an unrevocable credential is at most a ten-minute
     problem.  Anything longer-lived must be DB-backed -- [create_login] for browser sign-ins,
     [Sgs_user_access_token] for API tokens -- where the row's deletion is the revocation. *)
  let max_jwt_duration = Duration.of_min 10

  let create ?metadata ~expiration user =
    let expiration =
      match expiration with
      | Expiration.Duration { duration; capabilities }
        when Duration.to_f duration > Duration.to_f max_jwt_duration ->
          Expiration.Duration { duration = max_jwt_duration; capabilities }
      | expiration -> expiration
    in
    { metadata; expiration; user_id = Sgs_user.id user; v = user }

  let user t = t.v.user
  let expiration t = t.expiration
  let metadata t = t.metadata

  (* Normalize liberally on read so downstream consumers (display, masking, enforcement) always see
     the canonical, evaluation-faithful representation, regardless of how it was stored. *)
  let capabilities t = t.v.capabilities

  (* The internal representation in JWT. *)
  module Repr = struct
    type t = {
      access_token_id : string option; [@default None]
      user_id : string;
      metadata : Metadata.t option;
      capabilities : Sg_caps.t option;
          [@default None]
          [@to_yojson fun c -> CCOption.map_or ~default:`Null Sg_caps_json.to_yojson c]
          [@of_yojson
            function
            | `Null -> Ok None
            | json -> CCResult.map CCOption.return (Sg_caps_json.of_yojson json)]
    }
    [@@deriving yojson { strict = false }]
  end

  type of_token_err =
    [ `User_not_found_err of Uuidm.t
    | `Decode_err
    | `Data_decode_err of string
    | `Expired_token_err of string
    | Sgs_user_access_token.query_err
    | Pgsql_io.err
    ]
  [@@deriving show]

  type fetch_key_err =
    [ `Key_not_found_err
    | `Bad_signing_key_err of string
    | Pgsql_io.err
    ]
  [@@deriving show]

  (* Signing material for session JWTs.

     [signing] mints. [verifying] carries its public half and every older one, so
     rotating a key does not invalidate a live session. [legacy_hmac] is the
     pre-RS256 material, the [hmac] rows of the same table, kept because an
     access token carries no exp claim and dies only with its row -- those keys
     cannot be retired on a timer, only once every such token has been re-issued
     (TER-005). *)
  module Keys = struct
    type t = {
      signing : Mirage_crypto_pk.Rsa.priv;
      verifying : Mirage_crypto_pk.Rsa.pub list;
      legacy_hmac : string list;
    }

    let signer { signing; verifying = _; legacy_hmac = _ } =
      Jwt.Signer.RS256 (Jwt.Signer.Priv_key.of_priv_key signing)

    let rs256_verifiers { signing = _; verifying; legacy_hmac = _ } =
      CCList.map (fun pub -> Jwt.Verifier.RS256 (Jwt.Verifier.Pub_key.of_pub_key pub)) verifying
  end

  type enrich_err =
    [ `User_not_found_err of Uuidm.t
    | Sgs_user_access_token.query_err
    | Pgsql_io.err
    ]
  [@@deriving show]

  let claim = "stategraph"

  (* Build a [stored] session: enrich the user from the database and pair it with the
     already-resolved capabilities.

     The capabilities are the credential's own snapshot, deliberately NOT intersected with the
     user's current capabilities: a token may be more expressive than what its holder could mint
     today.  Revocation is the credential's lifetime instead -- a [Duration] JWT is capped at
     [max_jwt_duration], and a DB-backed credential dies when its row does (capability changes
     delete login rows, see [Sgs_user.revoke_login_sessions]). *)
  let mk_stored ~metadata ~expiration ~user_id ~capabilities db =
    let open Abbs_fc.Infix_result_monad in
    Sgs_user.enrich (Sgs_user.make ~id:user_id ()) db
    >>| fun user -> { metadata; expiration; user_id; v = { user; capabilities } }

  (* RSA first because that is what everything minted since the cutover uses.
     [Jwt.verify] compares the token's own alg header against the verifier before
     it looks at the signature, so an HS256 token cannot be validated by an RSA
     public key, and a token claiming an algorithm we did not choose is rejected
     rather than confused. *)
  let verifiers ({ Keys.signing = _; verifying = _; legacy_hmac } as keys) =
    Keys.rs256_verifiers keys @ CCList.map (fun key -> Jwt.Verifier.HS256 key) legacy_hmac

  let sign_token ~signer payload =
    let header = Jwt.Header.create (Jwt.Signer.to_string signer) in
    Jwt.token (Jwt.of_header_and_payload signer header payload)

  (* An RS256 check compares no secret, so trying each verifier in turn leaks no
     key through timing. *)
  let verify_token ~verifiers token =
    match Jwt.of_token token with
    | None -> Error `Malformed_err
    | Some decoded ->
        CCList.find_map (fun verifier -> Jwt.verify verifier decoded) verifiers
        |> CCOption.map Jwt.payload
        |> CCOption.to_result `Bad_signature_err

  let of_token ~keys db token =
    let open Abb.Future.Infix_monad in
    Abb.Sys.time ()
    >>= fun now ->
    let mk exp access_token_id user_id metadata capabilities =
      let open Abbs_fc.Infix_result_monad in
      match (exp, access_token_id) with
      | Some exp, _ when exp < 0.0 -> Abbs_fc.return_err (`Expired_token_err token)
      | Some exp, _ ->
          (* Duration expiration: capabilities ride in the JWT. *)
          let caps = CCOption.get_or ~default:Sg_caps.empty capabilities in
          mk_stored
            ~metadata
            ~expiration:(Expiration.Duration { duration = Duration.of_f exp; capabilities = caps })
            ~user_id
            ~capabilities:caps
            db
      | None, Some access_token_id ->
          (* Access_token expiration: capabilities are stored on the access token in the DB. *)
          Sgs_user_access_token.query access_token_id db
          >>= fun access_token ->
          mk_stored
            ~metadata
            ~expiration:(Expiration.Access_token access_token_id)
            ~user_id:(Sgs_user_access_token.user_id access_token)
            ~capabilities:(Sgs_user_access_token.capabilities access_token)
            db
      | None, None -> assert false
    in
    match verify_token ~verifiers:(verifiers keys) token with
    | Ok payload -> (
        let exp =
          CCOption.map (fun exp -> CCFloat.of_int exp -. now)
          @@ Jwt.Payload.find_claim_int Jwt.Claim.exp payload
        in
        match Jwt.Payload.find_claim claim payload with
        | Some repr -> (
            match Repr.of_yojson repr with
            | Ok { Repr.access_token_id; user_id; metadata; capabilities } -> (
                match (Uuidm.of_string user_id, CCOption.map Uuidm.of_string access_token_id) with
                | Some id, ((None as access_token_id) | Some (Some _ as access_token_id)) ->
                    mk exp access_token_id id metadata capabilities
                | None, _ -> Abbs_fc.return_err (`Data_decode_err ("user_id: " ^ user_id))
                | _, Some None ->
                    Abbs_fc.return_err
                      (`Data_decode_err
                         ("access_token_id:" ^ CCOption.get_or ~default:"" access_token_id)))
            | Error err -> Abbs_fc.return_err (`Data_decode_err err))
        | None -> Abbs_fc.return_err `Decode_err)
    | Error (`Malformed_err | `Bad_signature_err) -> Abbs_fc.return_err `Decode_err

  let to_token ~key { metadata; expiration; user_id; _ } =
    let signer = Keys.signer key in
    let open Abb.Future.Infix_monad in
    Abb.Sys.time ()
    >>= fun now ->
    match expiration with
    | Expiration.Duration { duration; capabilities } ->
        let repr =
          {
            Repr.access_token_id = None;
            user_id = Uuidm.to_string user_id;
            metadata;
            capabilities = Some capabilities;
          }
        in
        let payload =
          Jwt.Payload.empty
          |> Jwt.Payload.add_claim claim (Repr.to_yojson repr)
          |> Jwt.Payload.add_claim
               Jwt.Claim.exp
               (`Int (CCFloat.to_int now + Duration.to_sec duration))
        in
        Abb.Future.return (sign_token ~signer payload)
    | Expiration.Access_token access_token_id ->
        let repr =
          {
            Repr.access_token_id = Some (Uuidm.to_string access_token_id);
            user_id = Uuidm.to_string user_id;
            metadata;
            capabilities = None;
          }
        in
        let payload = Jwt.Payload.empty |> Jwt.Payload.add_claim claim (Repr.to_yojson repr) in
        Abb.Future.return (sign_token ~signer payload)

  (* Enrich a minted session into a stored one: resolve its capabilities (from the JWT-carried
     caps for Duration, from the access token row for Access_token) and enrich its user. *)
  let enrich t db =
    let open Abbs_fc.Infix_result_monad in
    let go =
      match t.expiration with
      | Expiration.Duration { capabilities; _ } -> Abbs_fc.return_ok capabilities
      | Expiration.Access_token access_token_id ->
          Sgs_user_access_token.query access_token_id db
          >>| fun access_token -> Sgs_user_access_token.capabilities access_token
    in
    go
    >>= fun capabilities ->
    mk_stored ~metadata:t.metadata ~expiration:t.expiration ~user_id:t.user_id ~capabilities db

  (* How long a browser sign-in lives.  The bound is the access_tokens row's expiration, not a JWT
     exp claim -- the row is what makes the session revocable before then. *)
  let login_session_duration = Duration.of_hour 24

  (* A browser sign-in is a DB-backed credential: an [access_tokens] row of kind ['login'] holding
     the capability snapshot, referenced by the minted JWT.  The row's expiration bounds the
     session, and deleting the row revokes it -- which is exactly what capability changes do
     ([Sgs_user.revoke_login_sessions]) to force a fresh sign-in.  Expired rows are swept here,
     on sign-in, rather than by a background job. *)
  let create_login ?metadata ~capabilities user db =
    let open Abbs_fc.Infix_result_monad in
    Sgs_user_access_token.gc_expired_login_sessions db
    >>= fun () ->
    Sgs_user_access_token.store
      ~kind:`Login
      ~expiration:login_session_duration
      ~name:"login"
      ~capabilities
      user
      db
    >>| fun access_token ->
    create
      ?metadata
      ~expiration:(Expiration.Access_token (Sgs_user_access_token.id access_token))
      user

  let decode_signing_key pem =
    match X509.Private_key.decode_pem pem with
    | Ok (`RSA priv) -> Ok priv
    | Ok _ -> Error (`Bad_signing_key_err "encryption_keys holds a signing key that is not RSA")
    | Error (`Msg msg) -> Error (`Bad_signing_key_err msg)

  (* Rank order is what the query returns, so the head of each list is the
     lowest-ranked row of its type: the one that signs. *)
  let partition_keys rows =
    let of_type wanted =
      CCList.filter_map (fun (data, type_) -> if type_ = wanted then Some data else None) rows
    in
    (of_type "rsa", of_type "hmac")

  let fetch_key db =
    let open Abbs_fc.Infix_result_monad in
    Pgsql_io.Prepared_stmt.fetch db (Sql.select_encryption_keys ()) ~f:CCPair.make
    >>= fun rows ->
    (match partition_keys rows with
      | (_ :: _ as pems), legacy_hmac -> Abb.Future.return (Ok (pems, legacy_hmac))
      | [], _ ->
          (* First boot after the migration; postgres cannot generate an RSA
             key, so the server writes the row. [where not exists] plus [on
             conflict do nothing] and the re-read settle a race between
             instances starting together: whoever lost simply discards the key
             it generated. *)
          let priv = Mirage_crypto_pk.Rsa.generate ~bits:2048 () in
          Pgsql_io.Prepared_stmt.execute
            db
            (Sql.insert_signing_key ())
            (Cstruct.to_hex_string (Cstruct.of_string (X509.Private_key.encode_pem (`RSA priv))))
          >>= fun () ->
          Pgsql_io.Prepared_stmt.fetch db (Sql.select_encryption_keys ()) ~f:CCPair.make
          >>| partition_keys)
    >>= fun (pems, legacy_hmac) ->
    Abb.Future.return (CCResult.map_l decode_signing_key pems)
    >>= function
    | [] -> Abb.Future.return (Error `Key_not_found_err)
    | signing :: _ as privs ->
        Abb.Future.return
          (Ok
             {
               Keys.signing;
               verifying = CCList.map Mirage_crypto_pk.Rsa.pub_of_priv privs;
               legacy_hmac;
             })
end

let key : Session.stored Session.t Brtl_mw_session.Value.t Hmap.key = Brtl_mw_session.create_key ()

module Cookie = struct
  let cookie_name = "session"

  let load storage keys token =
    let open Abb.Future.Infix_monad in
    Pgsql_pool.with_conn storage ~f:(fun db -> Session.of_token ~keys db token)
    >>= function
    | Ok session -> Abb.Future.return (Some session)
    | Error (`User_not_found_err _) -> Abb.Future.return None
    | Error (#Session.of_token_err as err) ->
        Logs.err (fun m -> m "%a" Session.pp_of_token_err err);
        Abb.Future.return None
    | Error (#Pgsql_pool.err as err) ->
        Logs.err (fun m -> m "%a" Pgsql_pool.pp_err err);
        Abb.Future.return None

  let store _storage key id_opt session _ctx =
    match id_opt with
    | Some id -> Abb.Future.return id
    | None -> Session.to_token ~key session
end

module Bearer = struct
  let load storage keys token =
    let open Abb.Future.Infix_monad in
    Pgsql_pool.with_conn storage ~f:(fun db -> Session.of_token ~keys db token)
    >>= function
    | Ok user -> Abb.Future.return (Some user)
    | Error (`User_not_found_err _) -> Abb.Future.return None
    | Error (#Session.of_token_err as err) ->
        Logs.err (fun m -> m "%a" Session.pp_of_token_err err);
        Abb.Future.return None
    | Error (#Pgsql_pool.err as err) ->
        Logs.err (fun m -> m "%a" Pgsql_pool.pp_err err);
        Abb.Future.return None

  let store _storage _keys _ = raise (Failure "nyi")
end

let create ~secure_cookies storage =
  let open Abb.Future.Infix_monad in
  Pgsql_pool.with_conn storage ~f:(fun db -> Session.fetch_key db)
  >>= function
  | Error (#Pgsql_pool.err as err) ->
      Logs.err (fun m -> m "Failed to fetch session keys: %a" Pgsql_pool.pp_err err);
      assert false
  | Error (#Session.fetch_key_err as err) ->
      Logs.err (fun m -> m "Failed to fetch session keys: %a" Session.pp_fetch_key_err err);
      assert false
  | Ok keys ->
      let config =
        {
          Brtl_mw_session.Config.key;
          cookie =
            Some
              {
                Brtl_mw_session.Config.Cookie.name = Cookie.cookie_name;
                expiration = `Session;
                domain = None;
                path = Some "/";
                secure = secure_cookies;
                load = Cookie.load storage keys;
                store = Cookie.store storage keys;
              };
          bearer =
            Some
              {
                Brtl_mw_session.Config.Bearer.load = Bearer.load storage keys;
                store = Bearer.store storage keys;
              };
        }
      in
      Abb.Future.return @@ Brtl_mw_session.create config

let set session ctx =
  Brtl_mw_session.set_session_value key (Brtl_mw_session.Auth.Cookie session) ctx

let rem _ctx _db = raise (Failure "nyi")

module Caps = struct
  (* One reason a [~caps] predicate denied a request.  [kind] matches the generated
     [Sgs_capability_denied_reason_capability.Kind.t] poly-variant so the two map directly. *)
  type denial_reason = {
    kind : Sgs_capability_denied_reason_capability.Kind.t;
    detail : string;
  }
  [@@deriving eq]

  (* The outcome of evaluating a [~caps] predicate: [Allowed], or [Denied] with every unmet
     requirement.  [or_] accumulates the reasons of both branches when both deny. *)
  type result =
    | Allowed
    | Denied of denial_reason list

  (* A [~caps] predicate receives both the session-resolved capabilities and the acting user, so
     that capability checks ([satisfies]) and identity checks ([is_user]) can be composed. *)
  type t = Sg_caps.t -> Sgs_user.stored Sgs_user.t -> result

  let is_allowed = function
    | Allowed -> true
    | Denied _ -> false

  (* [or_ p q] is a [~caps] predicate satisfied when either [p] or [q] is.  When both deny, their
     reasons are concatenated (deduped) so the caller sees every unmet alternative; when either
     allows, the failure of the other is discarded. *)
  let or_ p q caps user =
    match p caps user with
    | Allowed -> Allowed
    | Denied r1 -> (
        match q caps user with
        | Allowed -> Allowed
        | Denied r2 -> Denied (CCList.uniq ~eq:equal_denial_reason (r1 @ r2)))

  (* A [~caps] predicate that matches every session: it imposes no requirement. *)
  let allow_all _caps _user = Allowed

  (* [is_user user_id] is a [~caps] predicate satisfied when the acting user's id equals
     [user_id]. *)
  let is_user user_id _caps user =
    match Uuidm.equal user_id (Sgs_user.id user) with
    | true -> Allowed
    | false ->
        Denied
          [ { kind = `Identity; detail = "must be acting as user " ^ Uuidm.to_string user_id } ]

  (* [satisfies required resolved] is [Allowed] when [resolved] allows everything [required] does.
     [Sg_caps.missing] is where that rule lives -- including the [admin] grant answering for preview
     and commit -- and it names each capability that was not held, which is what a denial reports. *)
  (* What a capability that was asked for and not held says to the caller. *)
  let detail_of = function
    | `Access_token_create -> "requires the access-token-create capability"
    | `Access_token_refresh -> "requires the access-token-refresh capability"
    | `Admin -> "requires the admin capability for the requested tenants"
    | `Commit -> "requires the commit capability for the requested tenants/states"
    | `Preview -> "requires the preview capability for the requested tenants/states"
    | `Sudo -> "requires the sudo capability for the requested users"
    | `Users_manage -> "requires the users-manage capability for the requested tenants"

  let satisfies required resolved _user =
    match Sg_caps.missing resolved required with
    | [] -> Allowed
    | missing ->
        Denied
          (CCList.map
             (fun capability ->
               {
                 kind = (capability :> Sgs_capability_denied_reason_capability.Kind.t);
                 detail = detail_of capability;
               })
             missing)

  let tenant_scope tenant_id =
    CCResult.get_or ~default:Sg_caps_trie_scope.empty (Sg_caps_trie_scope.of_strings [ tenant_id ])

  (* Reaching some tenant is not a capability set anything entails, so the two [_some] predicates
     ask the scope directly rather than through {!satisfies}. *)
  let reaches_some kind detail scope_of caps _user =
    if Sg_caps_trie_scope.is_empty (scope_of caps) then Denied [ { kind; detail } ] else Allowed

  let admin_instance = satisfies { Sg_caps.empty with Sg_caps.admin = Sg_caps_trie_scope.full }

  let users_manage_instance =
    or_
      admin_instance
      (satisfies { Sg_caps.empty with Sg_caps.users_manage = Sg_caps_trie_scope.full })

  (* [admin_tenant tenant_id] requires administrative authority over that one tenant; an
     installation-wide grant satisfies it too, since it reaches every tenant. *)
  let admin_tenant tenant_id =
    satisfies { Sg_caps.empty with Sg_caps.admin = tenant_scope tenant_id }

  let admin_some =
    reaches_some `Admin "requires the admin capability for some tenant" (fun caps ->
        caps.Sg_caps.admin)

  let users_manage_some =
    or_
      admin_some
      (reaches_some
         `Users_manage
         "requires the users-manage capability for some tenant"
         (fun caps -> caps.Sg_caps.users_manage))

  let users_manage_tenant tenant_id =
    satisfies { Sg_caps.empty with Sg_caps.users_manage = tenant_scope tenant_id }

  let manages_tenant_members tenant_id =
    or_ (admin_tenant tenant_id) (users_manage_tenant tenant_id)

  (* The capability-denied response body.  Exposed because a check whose input is only available
     after a database lookup cannot live in a [~caps] predicate, and such an endpoint must still
     deny in exactly the shape [with_session] does. *)
  let denied_body reasons =
    let module Rr = Sgs_capability_denied_reason in
    let module Rs = Sgs_capability_denied_response in
    let reasons =
      CCList.map
        (fun { kind; detail } ->
          Rr.Reason_capability { Sgs_capability_denied_reason_capability.kind; detail })
        reasons
    in
    Yojson.Safe.to_string
    @@ Rs.to_yojson { Rs.id = "CAPABILITY_UNAUTHORIZED"; reasons; truncated = false }
end

(* A session token minted before the capabilities changed shape carries an [admin] the current
   decoder rejects, so the session never loads and the request arrives looking unauthenticated.
   Recognise that from the raw credential -- the payload is only being classified, not trusted, so
   it is read without verifying the signature -- to answer with "your credential is out of date"
   instead of a bare unauthorized that reads like a permissions problem.

   Written as "anything but the shape this release mints", so it covers both shapes that came
   before: the bare boolean of the pre-tenant-scoping days and the object of the glob-list model. A
   scope is a list of rules, and nothing else is.

   Access tokens are unaffected: their capabilities live in the database and the migration rewrote
   them in place. *)
let credential_predates_caps_change ctx =
  let bearer =
    CCOption.flat_map
      (fun s ->
        match CCString.Split.left ~by:" " s with
        | Some (typ, token) when CCString.equal_caseless typ "bearer" -> Some (CCString.trim token)
        | _ -> None)
      (Cohttp.Header.get Brtl_ctx.(Request.headers (request ctx)) "authorization")
  in
  let assoc k = function
    | `Assoc kvs -> Sln_list.String.assoc_opt k kvs
    | _ -> None
  in
  CCOption.or_ ~else_:(Brtl_mw_session.get_session_key Cookie.cookie_name ctx) bearer
  |> CCOption.flat_map Jwt.of_token
  |> CCOption.map Jwt.payload
  |> CCOption.flat_map (Jwt.Payload.find_claim Session.claim)
  |> CCOption.flat_map (assoc "capabilities")
  |> CCOption.flat_map (assoc "admin")
  |> CCOption.map_or ~default:false (function
    | `List _ -> false
    | `Assoc _ | `Bool _ | `Float _ | `Int _ | `Intlit _ | `Null | `String _ | `Tuple _ | `Variant _
      -> true)

let unauthorized ctx =
  if credential_predates_caps_change ctx then (
    Logs.info (fun m -> m "%s : CREDENTIAL_PREDATES_CAPS_CHANGE" (Brtl_ctx.token ctx));
    let body =
      Yojson.Safe.to_string
      @@ Sgs_api_components_error_response.to_yojson
           {
             Sgs_api_components_error_response.id = "CREDENTIAL_EXPIRED";
             data =
               Some
                 "This credential was issued before a change to how permissions are stored and is \
                  no longer valid. Sign in again to get a new session, or create a new access \
                  token.";
           }
    in
    Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Unauthorized body) ctx)
  else Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Unauthorized "") ctx

let with_session ~caps ~f ctx =
  match Brtl_mw_session.get_session_value key ctx with
  | Some (Brtl_mw_session.Auth.Cookie session) | Some (Brtl_mw_session.Auth.Bearer session) -> (
      match caps (Session.capabilities session) (Session.user session) with
      | Caps.Allowed -> f session ctx
      | Caps.Denied reasons ->
          Abb.Future.return
            (Brtl_ctx.set_response
               (Brtl_rspnc.create ~status:`Forbidden (Caps.denied_body reasons))
               ctx))
  | None -> Abb.Future.return (unauthorized ctx)

let with_user ~caps ~f = with_session ~caps ~f:(fun session ctx -> f (Session.user session) ctx)
