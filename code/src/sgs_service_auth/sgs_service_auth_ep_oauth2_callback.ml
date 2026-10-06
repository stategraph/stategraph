(* OAuth2 Callback Handler

   This endpoint is called after oauth2-proxy successfully authenticates a user.
   It creates/finds the user in the StateGraph database and generates a StateGraph
   session cookie, then redirects to the final destination.

   Flow:
   1. User authenticates via oauth2-proxy
   2. oauth2-proxy redirects to /api/v1/oauth2/complete?rd=<original_url>
   3. This handler:
      a. Calls oauth2-proxy /oauth2/userinfo to get user info
      b. Creates/finds user in database (based on email + auth_origin)
      c. Creates StateGraph session
      d. Sets session cookie
      e. Redirects to rd (original URL)
*)

module Fc = Abbs_fc

let src = Logs.Src.create "ep_oauth2_callback"

module Logs = (val Logs.src_log src : Logs.LOG)
module Http = Abb_curl.Make (Abb)

module Sql = struct
  let find_user_by_external_id () =
    Pgsql_io.Typed_sql.(
      sql
      // Ret.uuid
      /^ "select id from users where auth_origin = $auth_origin and external_id = $external_id"
      /% Var.text "auth_origin"
      /% Var.text "external_id")

  let create_user () =
    Pgsql_io.Typed_sql.(
      sql
      // Ret.uuid
      /^ "insert into users (name, type, auth_origin, auth_config_hash, external_id, email, \
          display_name, avatar_url, capability_trie, base_capability_trie) values ($name, 'user', \
          $auth_origin, $auth_config_hash, $external_id, $email, $display_name, $avatar_url, \
          $capability_trie, $capability_trie) returning id"
      /% Var.text "name"
      /% Var.text "auth_origin"
      /% Var.text "auth_config_hash"
      /% Var.text "external_id"
      /% Var.text "email"
      /% Var.text "display_name"
      /% Var.(option (text "avatar_url"))
      /% Var.json "capability_trie")

  let update_user_avatar () =
    Pgsql_io.Typed_sql.(
      sql
      /^ "update users set avatar_url = $avatar_url where id = $user_id"
      /% Var.(option (text "avatar_url"))
      /% Var.uuid "user_id")
end

(* User info returned from oauth2-proxy /oauth2/userinfo *)
module User_info = struct
  type t = {
    email : string;
    user : string option; [@default None]
    preferred_username : string option; [@default None]
    groups : string list; [@default []]
    picture : string option; [@default None]
  }
  [@@deriving yojson { strict = false }]
end

(* Google userinfo response - contains the picture URL *)
module Google_userinfo = struct
  type t = { picture : string option [@default None] } [@@deriving yojson { strict = false }]
end

(* Fetch user info from oauth2-proxy, forwarding the oauth2-proxy cookie *)
let fetch_user_info ~token oauth2_proxy_port cookie_header =
  let uri = Printf.sprintf "http://127.0.0.1:%d/oauth2/userinfo" oauth2_proxy_port in
  let headers = Http.Headers.of_list [ ("Cookie", cookie_header) ] in
  let open Abb.Future.Infix_monad in
  Http.call ~headers `GET (Uri.of_string uri)
  >>= function
  | Ok (resp, body) ->
      let status = Http.Status.to_int (Http.Response.status resp) in
      if status = 200 then (
        match Yojson.Safe.from_string body |> User_info.of_yojson with
        | Ok info -> Abbs_fc.return_ok info
        | Error err ->
            Logs.err (fun m -> m "%s : Failed to parse userinfo: %s body=%s" token err body);
            Abbs_fc.return_err `Parse_error)
      else (
        Logs.err (fun m -> m "%s : userinfo returned status %d body=%s" token status body);
        Abbs_fc.return_err `Userinfo_failed)
  | Error err ->
      Logs.err (fun m -> m "%s : Failed to fetch userinfo: %a" token Http.pp_request_err err);
      Abbs_fc.return_err `Fetch_error

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

(* Fetch access token from oauth2-proxy /oauth2/auth endpoint *)
let fetch_access_token ~token oauth2_proxy_port cookie_header =
  let uri = Printf.sprintf "http://127.0.0.1:%d/oauth2/auth" oauth2_proxy_port in
  let headers = Http.Headers.of_list [ ("Cookie", cookie_header) ] in
  let open Abb.Future.Infix_monad in
  Http.call ~headers `GET (Uri.of_string uri)
  >>= function
  | Ok (resp, _body) ->
      let status = Http.Status.to_int (Http.Response.status resp) in
      if status = 202 || status = 200 then (
        (* Access token is in X-Auth-Request-Access-Token header *)
        let resp_headers = Http.Response.headers resp in
        let access_token = Http.Headers.get "x-auth-request-access-token" resp_headers in
        Logs.debug (fun m ->
            m
              "%s : Got access token from /oauth2/auth: %s"
              token
              (match access_token with
              | Some t -> CCString.sub t 0 (min 20 (CCString.length t)) ^ "..."
              | None -> "none"));
        Abb.Future.return access_token)
      else (
        Logs.warn (fun m -> m "%s : /oauth2/auth returned status %d" token status);
        Abb.Future.return None)
  | Error err ->
      Logs.warn (fun m -> m "%s : Failed to fetch /oauth2/auth: %a" token Http.pp_request_err err);
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
      (* Communism-mode deployments provision installation operators out-of-band (see
             sgs_setup_ep_status.ml), so the installation-wide bootstrap never fires in that mode.
             What the new user does get is administrative authority over their own tenant: the
             tenant is created for them here and they are its only member, so they are its first
             user by construction.  Without that grant a tenant owner has no authority over the
             tenant they own -- they cannot delete their own states or manage their own billing.
             Same rule aegis applies to its first user in
             sgs_service_license_ee_ep_magic_claim.ml. *)
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

  (* Main callback handler *)
  let run config storage oauth2_proxy provider rd =
    let rd = CCOption.get_or ~default:"/" rd in
    Brtl_ep.run ~content_type:"text/html" ~f:(fun ctx ->
        let port = Sgs_service_auth_oauth2_proxy.port oauth2_proxy in
        let token = Brtl_ctx.token ctx in
        let rd =
          match Sgs_redirect.url ~ui_base:(Sgs_config.ui_base config) rd with
          | Some rd -> rd
          | None ->
              Logs.warn (fun m -> m "%s : UNSAFE_REDIRECT : %s" token rd);
              "/"
        in
        let open Abb.Future.Infix_monad in
        (* Get OAuth config to extract auth_origin and config_hash *)
        match Sgs_config.oauth2 config with
        | None ->
            Logs.err (fun m -> m "%s : OAuth callback but no OAuth configured" token);
            Abb.Future.return (Sgs_eplib.respond_internal_error ~body:"OAuth not configured" ctx)
        | Some oauth_config -> (
            let auth_origin = provider in
            let config_hash = oauth_config.Sgs_config.oauth2_config_hash in

            (* Extract cookie header from the browser request *)
            let request = Brtl_ctx.request ctx in
            let headers = Cohttp.Request.headers request in
            let cookie_header = CCOption.get_or ~default:"" (Cohttp.Header.get headers "cookie") in

            Logs.debug (fun m ->
                m
                  "%s : OAuth2 callback - fetching userinfo with cookie: %s"
                  token
                  (if CCString.length cookie_header > 50 then
                     CCString.sub cookie_header 0 50 ^ "..."
                   else cookie_header));

            (* Fetch user info from oauth2-proxy, forwarding the oauth2-proxy cookie *)
            fetch_user_info ~token port cookie_header
            >>= function
            | Ok User_info.{ email; user; preferred_username; groups; picture = _ } -> (
                let external_id = CCOption.get_or ~default:email user in
                let display_name = preferred_username in

                (* Fetch access token and then get picture from Google *)
                fetch_access_token ~token port cookie_header
                >>= fun access_token_opt ->
                (match access_token_opt with
                  | Some access_token -> fetch_google_picture ~token access_token
                  | None ->
                      Logs.warn (fun m ->
                          m "%s : No access token available for fetching picture" token);
                      Abb.Future.return None)
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
                     column, and the fresh snapshot is what the session below is granted. *)
                    Sgs_caps_rules.list_alive db
                    >>= fun rules ->
                    let group_caps = Sgs_caps_rules.eval rules ~groups in
                    Sgs_user.recompute_login_capabilities ~group_caps db (Sgs_user.id user)
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
                      (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Found ~headers "") ctx)
                | Error (#Pgsql_io.err as err) ->
                    Logs.err (fun m -> m "%s : Database error: %a" token Pgsql_io.pp_err err);
                    Abb.Future.return (Sgs_eplib.respond_internal_error ~body:"Database error" ctx)
                | Error (#Pgsql_pool.err as err) ->
                    Logs.err (fun m -> m "%s : Pool error: %a" token Pgsql_pool.pp_err err);
                    Abb.Future.return (Sgs_eplib.respond_internal_error ~body:"Database error" ctx)
                | Error _ ->
                    Abb.Future.return
                      (Sgs_eplib.respond_internal_error ~body:"Failed to create session" ctx))
            | Error _ ->
                Abb.Future.return
                  (Brtl_ctx.set_response
                     (Brtl_rspnc.create ~status:`Unauthorized "Authentication failed")
                     ctx)))
end
