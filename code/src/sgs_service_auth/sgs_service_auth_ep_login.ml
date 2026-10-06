(* Login Endpoint

   This endpoint initiates the OAuth2 login flow by redirecting to oauth2-proxy.
   After successful authentication, users are redirected to the /api/v1/oauth2/complete
   callback which creates the StateGraph session.

   Usage:
   - GET /api/v1/login?rd=/original/path
   - Redirects to /oauth2/start?rd=/api/v1/oauth2/complete?rd=/original/path
*)

let src = Logs.Src.create "ep_login"

module Logs = (val Logs.src_log src : Logs.LOG)

(* GET /api/v1/login/options - List available OAuth providers *)
let options config =
  Brtl_ep.run_json ~f:(fun ctx ->
      let options =
        match Sgs_config.oauth2 config with
        | None -> []
        | Some oauth_config ->
            let provider_name = oauth_config.Sgs_config.oauth2_provider_name in
            [
              {
                Sgs_api_components_login_option.name = provider_name;
                display_name = oauth_config.Sgs_config.oauth2_display_name;
                url = Printf.sprintf "/api/v1/login/%s" provider_name;
              };
            ]
      in
      let body =
        Yojson.Safe.to_string
          (Sgs_api_components_login_options.to_yojson { Sgs_api_components_login_options.options })
      in
      Abb.Future.return (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`OK body) ctx))

(* Build Auth0's logout URL — see rfds/701 - OIDC Logout Flow/ for
   the "why" behind this dispatch. Short version: when we're logged in via
   Auth0, just clearing our own session cookie isn't enough — Auth0
   still has its own login session, and the next time the user hits
   /authorize Auth0 silently re-authenticates them. To actually log
   out, we have to bounce the browser through Auth0's own logout
   endpoint, which clears Auth0's session and then bounces back to us.

   The frontend triggers this via `window.location.href = ...` so the
   browser follows the full chain (us → Auth0 → returnTo). *)
let build_auth0_logout_url ~oidc_issuer_url ~client_id ~return_to =
  let base = Uri.of_string oidc_issuer_url in
  let path =
    (* Append "/v2/logout" to whatever path the issuer URL already has,
       collapsing any trailing slash so we don't produce "//v2/logout"
       when the issuer is published as e.g. "https://x.auth0.com/". *)
    CCString.rdrop_while (( = ) '/') (Uri.path base) ^ "/v2/logout"
  in
  Uri.with_path base path
  |> CCFun.flip Uri.add_query_params' [ ("client_id", client_id); ("returnTo", return_to) ]
  |> Uri.to_string

(* Where a logout should land the browser: the IdP's own logout endpoint when the IdP
   supports one, and [rd] itself otherwise. [rd] must already be validated. *)
let logout_location config rd =
  match Sgs_config.oauth2 config with
  | Some oauth2_config -> (
      match oauth2_config.Sgs_config.oauth2_provider with
      | Sgs_config.Oidc { oidc_issuer_url; auth0_rp_logout }
        when auth0_rp_logout || CCString.mem ~sub:".auth0.com" oidc_issuer_url ->
          (* Auth0 case. Auth0 calls its logout endpoint "v2/logout"
             instead of using the standard-OIDC "end_session_endpoint"
             name, so we have to special-case it. We fire this arm
             when EITHER:
               - the issuer URL contains ".auth0.com" (standard Auth0
                 tenant domain — auto-detected), or
               - the operator set STATEGRAPH_OAUTH_OIDC_USE_AUTH0_LOGOUT
                 (needed when the Auth0 tenant uses a custom domain
                 that the substring check misses).

             Auth0 requires `returnTo` to be an absolute URL that's
             on the application's "Allowed Logout URLs" allowlist.
             The frontend sends an absolute URL in dev; in prod it
             sends just a path, which we make absolute against
             ui_base. Strip any trailing slash from ui_base or Auth0
             rejects the (exact-match) allowlist check. *)
          let return_to =
            if CCString.prefix ~pre:"http://" rd || CCString.prefix ~pre:"https://" rd then rd
            else CCString.rdrop_while (( = ) '/') (Sgs_config.ui_base config) ^ rd
          in
          build_auth0_logout_url
            ~oidc_issuer_url
            ~client_id:oauth2_config.Sgs_config.oauth2_client_id
            ~return_to
      | Sgs_config.Oidc _ ->
          (* Generic OIDC providers (Okta, Keycloak, Authentik, …):
             clear our own cookies and redirect to `rd`. The IdP
             session stays alive.

             This is NOT a regression — every OIDC user (Auth0
             included) was on this same local-only path before the
             SaaS Auth0 work. To give self-hosters proper logout we'd
             need to read `end_session_endpoint` from the IdP's
             discovery doc and pass the spec params
             (id_token_hint / post_logout_redirect_uri); see
             rfds/701 - OIDC Logout Flow/. Tracked as follow-up. *)
          rd
      | Sgs_config.Google _ -> rd)
  | None -> rd

(* GET /api/v1/logout — clear our cookies and redirect somewhere sensible.

   Glossary for the comments below:
     - IdP (Identity Provider) — the upstream auth service that owns the
       user's identity. For us that's Auth0, Google, Okta, etc.
     - RP (Relying Party) — us. We "rely on" the IdP to vouch for the
       user.
     - RP-initiated logout — when we (the RP) ask the IdP to end its own
       session with the user, on top of clearing our cookies. Without
       this step the IdP's session cookie sticks around and silently
       re-logs the user in next time they hit /authorize.

   See rfds/701 - OIDC Logout Flow/ for a flow diagram. *)
let logout config rd =
  (* [prompt=1] stops the login page from forwarding to the IdP, whose session can outlive ours and
     would log the user back in. *)
  let signed_out = "/login?prompt=1" in
  let rd = CCOption.get_or ~default:signed_out rd in
  Brtl_ep.run ~content_type:"text/html" ~f:(fun ctx ->
      let rd =
        match Sgs_redirect.url ~ui_base:(Sgs_config.ui_base config) rd with
        | Some rd -> rd
        | None ->
            Logs.warn (fun m -> m "%s : UNSAFE_REDIRECT : %s" (Brtl_ctx.token ctx) rd);
            signed_out
      in
      let location = logout_location config rd in
      Logs.info (fun m -> m "%s : LOGOUT : Redirecting to %s" (Brtl_ctx.token ctx) location);

      (* Clear the cookies by setting them to expire immediately. With orchestration on, the
         engine's session cookie is on the same origin, and it stays valid after logout unless we
         clear it too. *)
      let secure_suffix = if Sgs_config.secure_cookies config then "; Secure" else "" in
      let clear_cookie name =
        ( "Set-Cookie",
          Printf.sprintf
            "%s=; Path=/; Expires=Thu, 01 Jan 1970 00:00:00 GMT; HttpOnly; SameSite=Lax%s"
            name
            secure_suffix )
      in
      let terrat_cookies =
        if Sgs_config.orchestration_enabled config then
          [ Sgs_config.terrat_session_cookie_name config ]
        else []
      in
      let headers =
        Cohttp.Header.of_list
          (("Location", location)
          :: CCList.map clear_cookie ([ "_oauth2_proxy"; "session" ] @ terrat_cookies))
      in
      Abb.Future.return (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Found ~headers "") ctx))

(* GET /api/v1/login/{provider} - Initiate OAuth2 login flow *)
let run config oauth2_proxy provider rd =
  let rd = CCOption.get_or ~default:"/" rd in
  Brtl_ep.run ~content_type:"text/html" ~f:(fun ctx ->
      let rd =
        match Sgs_redirect.url ~ui_base:(Sgs_config.ui_base config) rd with
        | Some rd -> rd
        | None ->
            Logs.warn (fun m -> m "%s : UNSAFE_REDIRECT : %s" (Brtl_ctx.token ctx) rd);
            "/"
      in
      match oauth2_proxy with
      | None ->
          Logs.warn (fun m -> m "%s : Login attempt but OAuth not configured" (Brtl_ctx.token ctx));
          Abb.Future.return
            (Brtl_ctx.set_response
               (Brtl_rspnc.create ~status:`Service_unavailable "OAuth login not available")
               ctx)
      | Some _proxy ->
          (* Build the callback URL that oauth2-proxy will redirect to after auth *)
          let callback_url =
            Printf.sprintf "/api/v1/oauth2/%s/complete?rd=%s" provider (Uri.pct_encode rd)
          in
          (* Build the oauth2-proxy start URL with our callback as the redirect *)
          let oauth2_start_url =
            Printf.sprintf "/oauth2/%s/start?rd=%s" provider (Uri.pct_encode callback_url)
          in

          Logs.info (fun m ->
              m
                "%s : Initiating OAuth2 login for provider %s, rd=%s"
                (Brtl_ctx.token ctx)
                provider
                rd);

          let headers = Cohttp.Header.of_list [ ("Location", oauth2_start_url) ] in
          Abb.Future.return
            (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Found ~headers "") ctx))
