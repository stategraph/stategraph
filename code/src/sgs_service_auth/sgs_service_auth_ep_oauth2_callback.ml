(* OAuth2 Callback Handler

   The provider redirects here after the user signs in. This handler completes the OAuth2 flow,
   finds or creates the user (based on external id + auth_origin), creates a StateGraph session,
   sets the session cookie, and redirects to the destination the sign-in started with.
*)

module Fc = Abbs_fc

let src = Logs.Src.create "ep_oauth2_callback"

module Logs = (val Logs.src_log src : Logs.LOG)
module Http = Abb_curl.Make (Abb)

module Sql = struct
  let find_user_by_external_id_sql =
    Mql_sql.read
      "select id from users where auth_origin = $auth_origin and external_id = $external_id"

  let find_user_by_external_id () =
    Pgsql_io.Typed_sql.(
      sql
      // Ret.uuid
      /^ find_user_by_external_id_sql
      /% Var.text "auth_origin"
      /% Var.text "external_id")

  let create_user_sql =
    Mql_sql.read
      "insert into users (name, type, auth_origin, auth_config_hash, external_id, email, \
       display_name, avatar_url, capability_trie, base_capability_trie) values ($name, 'user', \
       $auth_origin, $auth_config_hash, $external_id, $email, $display_name, $avatar_url, \
       $capability_trie, $capability_trie) returning id"

  let create_user () =
    Pgsql_io.Typed_sql.(
      sql
      // Ret.uuid
      /^ create_user_sql
      /% Var.text "name"
      /% Var.text "auth_origin"
      /% Var.text "auth_config_hash"
      /% Var.text "external_id"
      /% Var.text "email"
      /% Var.text "display_name"
      /% Var.(option (text "avatar_url"))
      /% Var.json "capability_trie")

  let update_user_avatar_sql =
    Mql_sql.read "update users set avatar_url = $avatar_url where id = $user_id"

  let update_user_avatar () =
    Pgsql_io.Typed_sql.(
      sql /^ update_user_avatar_sql /% Var.(option (text "avatar_url")) /% Var.uuid "user_id")
end

(* Google userinfo response - contains the picture URL *)
module Google_userinfo = struct
  type t = { picture : string option [@default None] } [@@deriving yojson { strict = false }]
end

(* Fetch picture URL from Google's userinfo endpoint using access token *)
let fetch_google_picture ~token access_token =
  let uri = "https://www.googleapis.com/oauth2/v2/userinfo" in
  let headers = Http.Headers.of_list [ ("Authorization", "Bearer " ^ access_token) ] in
  let open Abb.Future.Infix_monad in
  Http.call ~headers `GET (Uri.of_string uri)
  >>= function
  | Ok (resp, body) ->
      let status = Http.Status.to_int (Http.Response.status resp) in
      if status = 200 then (
        Logs.debug (fun m -> m "%s : Google userinfo response: %s" token body);
        match Yojson.Safe.from_string body |> Google_userinfo.of_yojson with
        | Ok info -> Abb.Future.return info.Google_userinfo.picture
        | Error err ->
            Logs.warn (fun m -> m "%s : Failed to parse Google userinfo: %s" token err);
            Abb.Future.return None)
      else (
        Logs.warn (fun m -> m "%s : Google userinfo returned status %d" token status);
        Abb.Future.return None)
  | Error err ->
      Logs.warn (fun m ->
          m "%s : Failed to fetch Google userinfo: %a" token Http.pp_request_err err);
      Abb.Future.return None

(* Find or create user based on OAuth info *)
let add_user_to_default_tenant token db default_tenant_name user user_id =
  let open Fc.Infix_result_monad in
  match default_tenant_name with
  | Some tenant_name ->
      Sgs_tenant.find_or_create tenant_name db
      >>= fun tenant ->
      Sgs_tenant.add_user tenant user db
      >>| fun () ->
      Logs.info (fun m ->
          m "%s : TENANT_USER_ADDED : Added user %a to tenant %s" token Uuidm.pp user_id tenant_name);
      ()
  | None -> Abbs_fc.return_ok ()

let derive_personal_tenant_name ~display_name ~email =
  let trimmed_display =
    CCOption.flat_map
      (fun n ->
        let s = CCString.trim n in
        if s = "" then None else Some s)
      display_name
  in
  CCOption.get_or ~default:email trimmed_display

(* Communism mode: every new user gets a fresh single-member tenant. The
   tenant is the isolation boundary between users on shared infra, so we
   use Sgs_tenant.store (always inserts a new row) rather than
   find_or_create (which would collide users with the same display name
   into a shared tenant).

   Created before the user row rather than after, because the user's administrative authority is
   scoped to this tenant and the grant names its id. *)
let create_personal_tenant ~display_name ~email token db =
  let open Fc.Infix_result_monad in
  let tenant_name = derive_personal_tenant_name ~display_name ~email in
  Sgs_tenant.store tenant_name db
  >>| fun tenant ->
  Logs.info (fun m ->
      m
        "%s : PERSONAL_TENANT_CREATED : Tenant %a (name=%s)"
        token
        Uuidm.pp
        (Sgs_tenant.id tenant)
        tenant_name);
  tenant

let attach_personal_tenant token db tenant user user_id =
  let open Fc.Infix_result_monad in
  Sgs_tenant.add_user tenant user db
  >>| fun () ->
  Logs.info (fun m ->
      m
        "%s : TENANT_USER_ADDED : Added user %a to tenant %a"
        token
        Uuidm.pp
        user_id
        Uuidm.pp
        (Sgs_tenant.id tenant))

(* The installation-wide bootstrap: the first user to arrive when there are no installation-wide admin.

   Installation-wide admin is the grant being handed out here:
   a tenant-scoped admin administers only the tenants it names and can reach none of the
   installation-wide endpoints, so tenants-admin are unfit, which why this checks installation-wide admins.

   There is a small TOCTOU window between this count and the user insert, so two concurrent
   first-user registrations could both get admin.  This is acceptable for a bootstrap-only
   scenario. *)
let bootstrap_admin_scope db =
  let open Fc.Infix_result_monad in
  Sgs_user.count_instance_admins db
  >>| function
  | 0 -> `Instance
  | _ -> `No

let show_admin_scope = function
  | `No -> "none"
  | `Instance -> "instance"
  | `Tenants tenants -> "tenants=" ^ CCString.concat "," tenants

let find_or_create_user
    ~token
    ?default_tenant_name
    ~new_user_tenant
    ~auth_origin
    ~config_hash
    ~external_id
    ~email
    ~display_name
    ~avatar_url
    db =
  let open Fc.Infix_result_monad in
  (* First try to find existing user *)
  Pgsql_io.Prepared_stmt.fetch
    db
    (Sql.find_user_by_external_id ())
    ~f:CCFun.id
    auth_origin
    external_id
  >>= function
  | user_id :: _ -> (
      Logs.info (fun m -> m "%s : Found existing user %a for %s" token Uuidm.pp user_id email);
      (* Update avatar_url for existing user if we have one *)
      match avatar_url with
      | Some _ ->
          Pgsql_io.Prepared_stmt.execute db (Sql.update_user_avatar ()) avatar_url user_id
          >>| fun () -> (user_id, false)
      | None -> Abbs_fc.return_ok (user_id, false))
  | [] -> (
      (* Atomically: tenant creation, admin scope, user insert, tenant attach. The caller
         wraps this in a transaction, so a failure after the user insert does not
         leave an active user with no tenant membership and no recovery path. *)
      (* The installation-wide bootstrap is the default tenant's alone. A personal tenant grants its
         new user administrative authority over it instead: they are its only member, so they are
         its first user by construction. Without that grant a tenant owner has no authority over the
         tenant they own -- they cannot delete their own states or manage their own billing. Same
         rule aegis applies to its first user in sgs_service_license_ee_ep_magic_claim.ml. *)
      let name = CCOption.get_or ~default:email display_name in
      (match new_user_tenant with
        | `Personal_tenant ->
            create_personal_tenant ~display_name ~email token db
            >>| fun tenant -> (Some tenant, `Tenants [ Uuidm.to_string (Sgs_tenant.id tenant) ])
        | `Default_tenant -> bootstrap_admin_scope db >>| fun admin -> (None, admin))
      >>= fun (personal_tenant, admin) ->
      Sgs_user.caps_for ~admin db
      >>= fun capabilities ->
      Pgsql_io.Prepared_stmt.fetch
        db
        (Sql.create_user ())
        ~f:CCFun.id
        name
        auth_origin
        config_hash
        external_id
        email
        (CCOption.get_or ~default:name display_name)
        avatar_url
        (Sg_caps_json.to_json capabilities)
      >>= function
      | user_id :: _ ->
          Logs.info (fun m ->
              m
                "%s : Created new user %a for %s (admin=%s)"
                token
                Uuidm.pp
                user_id
                email
                (show_admin_scope admin));
          let user = Sgs_user.make ~id:user_id () in
          (* Communism mode isolates users via per-user tenants. Everything
                 else keeps the existing shared-default-tenant behavior. *)
          (match personal_tenant with
            | Some tenant -> attach_personal_tenant token db tenant user user_id
            | None -> add_user_to_default_tenant token db default_tenant_name user user_id)
          >>| fun () -> (user_id, true)
      | _ ->
          Logs.err (fun m -> m "%s : Failed to create user for %s" token email);
          Abbs_fc.return_err `User_create_failed)

(* In hosted (Communism) mode a sign-up and a login are the same OAuth action,
   so the only authoritative "brand-new account" signal is the user INSERT in
   find_or_create_user. Tag the post-login redirect with sg_signup=1 on first
   creation; the console's AuthProvider turns it into a GTM dataLayer "sign_up"
   event (and strips the param), letting analytics tell registrations from
   logins. rd is a path we control ("/" by default), so a plain separator
   choice is sufficient. *)
let append_signup_marker rd =
  let sep = if CCString.contains rd '?' then "&" else "?" in
  rd ^ sep ^ "sg_signup=1"

module Make (Cloud : Sgs_cloud.S) = struct
  (* Tell the Cloud control plane about the account so it can send the new-customer alert. Fired
   only on the INSERT above, which is the same authoritative signal
   [append_signup_marker] uses.

   Forked rather than awaited: Aegis allows itself 15s before giving up, and
   a login must not wait on a sibling service to answer. Errors are logged
   and dropped -- a missed alert is not worth failing a signup over, and the
   console-load path in Aegis still records the customer eventually. *)
  let report_first_touch token config ~user_id ~email =
    let open Abb.Future.Infix_monad in
    Abbs_fc.ignore
    @@ Abb.Future.fork
         (Cloud.record_first_touch
            ~config
            ~identity:{ Sgs_cloud.user_id = Uuidm.to_string user_id; email }
         >>| function
         | Ok () -> ()
         | Error err ->
             Logs.warn (fun m ->
                 m "%s : AEGIS_FIRST_TOUCH_FAILED : %s : %a" token email Sgs_cloud.pp_err err))

  (* Back to the login page, which says why. [prompt=1] keeps it from forwarding straight back to
     the provider. *)
  let respond_login_failed err ctx =
    let params =
      match err with
      | `Idp_error (error, description) ->
          [
            ("error", "idp");
            ("reason", if CCString.is_empty description then error else description);
          ]
      | `Invalid_state | `Missing_csrf_cookie | `Csrf_token_mismatch -> [ ("error", "expired") ]
      | `Unverified_email _ | `Unauthorized -> [ ("error", "denied") ]
    in
    let location =
      Uri.to_string (Uri.with_query' (Uri.of_string "/login") (("prompt", "1") :: params))
    in
    Brtl_ctx.set_response
      (Brtl_rspnc.create
         ~status:`Found
         ~headers:(Cohttp.Header.of_list [ ("Location", location) ])
         "")
      ctx

  (* Main callback handler *)
  let run config storage oauth2 _provider =
    Brtl_ep.run ~content_type:"text/html" ~f:(fun ctx ->
        let token = Brtl_ctx.token ctx in
        (* Every exit ends the sign-in, so a failed one expires the CSRF cookie too. *)
        let failed ctx =
          Brtl_ctx.set_response
            (Oauth2_htp_cookie.add_to_response
               (Oauth2_htp.clear_cookies (Sgs_service_oauth2.Provider.authenticator oauth2))
               (Brtl_ctx.response ctx))
            ctx
        in
        let open Abb.Future.Infix_monad in
        (* Get OAuth config to extract config_hash *)
        match Sgs_config.oauth2 config with
        | None ->
            Logs.err (fun m -> m "%s : OAuth callback but no OAuth configured" token);
            Abb.Future.return
              (failed (Sgs_eplib.respond_internal_error ~body:"OAuth not configured" ctx))
        | Some oauth_config -> (
            let auth_origin = Sgs_service_oauth2.Provider.provider_name oauth2 in
            let config_hash = oauth_config.Sgs_config.oauth2_config_hash in
            Abb.Sys.time ()
            >>= fun now ->
            Oauth2_htp.oauth_callback
              ~now
              (Sgs_service_oauth2.Provider.authenticator oauth2)
              (Oauth2_htp_request.of_ctx ctx)
            >>= function
            | Ok { Oauth2_htp.Callback_result.session; redirect = rd; set_cookies } -> (
                let rd =
                  match Sgs_redirect.url ~ui_base:(Sgs_config.ui_base config) rd with
                  | Some rd -> rd
                  | None ->
                      Logs.warn (fun m -> m "%s : UNSAFE_REDIRECT : %s" token rd);
                      "/"
                in
                let { Oauth2_htp_session.email; user; groups; access_token } = session in
                let external_id = if CCString.is_empty user then email else user in
                let display_name = None in
                (match oauth_config.Sgs_config.oauth2_provider with
                  | Sgs_config.Google _ when not (CCString.is_empty access_token) ->
                      fetch_google_picture ~token access_token
                  | Sgs_config.Google _ | Sgs_config.Oidc _ -> Abb.Future.return None)
                >>= fun avatar_url ->
                Logs.info (fun m ->
                    m
                      "%s : Avatar URL for %s: %s"
                      token
                      email
                      (CCOption.get_or ~default:"none" avatar_url));

                let default_tenant_name = Sgs_config.default_tenant_name config in
                let new_user_tenant = Cloud.new_user_tenant () in
                Pgsql_pool.with_conn storage ~f:(fun db ->
                    let open Fc.Infix_result_monad in
                    (* Find or create the user atomically. [enrich] is intentionally left outside the
                     transaction: a freshly created user must persist even if session enrichment
                     later fails, so the account is available on the next login. *)
                    Pgsql_io.tx db ~f:(fun () ->
                        find_or_create_user
                          ~token
                          ?default_tenant_name
                          ~new_user_tenant
                          ~auth_origin
                          ~config_hash
                          ~external_id
                          ~email
                          ~display_name
                          ~avatar_url
                          db
                        >>= fun (user_id, is_new) ->
                        (* Create session and set cookie via session middleware. Enrich the user so
                         the session is granted the user's capabilities. *)
                        Sgs_user.enrich (Sgs_user.make ~id:user_id ()) db
                        >>| fun user -> (user, is_new))
                    >>= fun (user, is_new) ->
                    (* Recompute-and-persist the effective capabilities before minting the session: the
                     user's manual baseline unioned with the grants of every group rule matching
                     their IdP [groups]. Login is the sole recompute point for the [capabilities]
                     column, and the fresh snapshot is what the session below is granted. When the
                     groups could not be read, the user keeps the capabilities of their last
                     sign-in. *)
                    (match groups with
                      | Some groups ->
                          Sgs_caps_rules.list_alive db
                          >>= fun rules ->
                          let group_caps = Sgs_caps_rules.eval rules ~groups in
                          Sgs_user.recompute_login_capabilities ~group_caps db (Sgs_user.id user)
                      | None ->
                          Logs.warn (fun m ->
                              m
                                "%s : OAUTH2_GROUPS_UNKNOWN : %s keeps the capabilities of their \
                                 last sign-in"
                                token
                                email);
                          Abbs_fc.return_ok (Sgs_user.capabilities user))
                    >>= fun capabilities ->
                    (* DB-backed login session carrying the just-recomputed capabilities; a later
                     capability change revokes it, forcing a fresh sign-in. *)
                    Sgs_user_session.Session.create_login ~capabilities (Sgs_user.to_minted user) db
                    >>= fun session ->
                    Sgs_user_session.Session.enrich session db
                    >>| fun session -> (Sgs_user_session.set session ctx, is_new, Sgs_user.id user))
                >>= function
                | Ok (ctx, is_new, user_id) ->
                    (if is_new then report_first_touch token config ~user_id ~email
                     else Abb.Future.return ())
                    >>= fun () ->
                    let rd = if is_new then append_signup_marker rd else rd in
                    let headers = Cohttp.Header.of_list [ ("Location", rd) ] in
                    Abb.Future.return
                      (Brtl_ctx.set_response
                         (Oauth2_htp_cookie.add_to_response
                            set_cookies
                            (Brtl_rspnc.create ~status:`Found ~headers ""))
                         ctx)
                | Error (#Pgsql_io.err as err) ->
                    Logs.err (fun m -> m "%s : Database error: %a" token Pgsql_io.pp_err err);
                    Abb.Future.return
                      (failed (Sgs_eplib.respond_internal_error ~body:"Database error" ctx))
                | Error (#Pgsql_pool.err as err) ->
                    Logs.err (fun m -> m "%s : Pool error: %a" token Pgsql_pool.pp_err err);
                    Abb.Future.return
                      (failed (Sgs_eplib.respond_internal_error ~body:"Database error" ctx))
                | Error _ ->
                    Abb.Future.return
                      (failed
                         (Sgs_eplib.respond_internal_error ~body:"Failed to create session" ctx)))
            | Error
                (( `Idp_error _
                 | `Invalid_state
                 | `Missing_csrf_cookie
                 | `Csrf_token_mismatch
                 | `Unverified_email _
                 | `Unauthorized ) as err) ->
                Logs.warn (fun m -> m "%s : OAUTH2_LOGIN_FAILED : %a" token Oauth2_htp.pp_err err);
                Abb.Future.return (failed (respond_login_failed err ctx))
            | Error err ->
                Logs.err (fun m -> m "%s : OAUTH2_CALLBACK : %a" token Oauth2_htp.pp_err err);
                Abb.Future.return
                  (failed (Sgs_eplib.respond_internal_error ~body:"Sign-in failed" ctx))))
end
