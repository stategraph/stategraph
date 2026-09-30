let src = Logs.Src.create "service_orchestration_github_claim_common"

module Logs_lib = Logs
module Logs = (val Logs.src_log src : Logs.LOG)

(* The session key and the App's OAuth client, in one connection. Both claim
   endpoints need both, and resolving the client is what keeps a console-created
   App working, so neither endpoint is left to remember it. *)
let keys_and_oauth config db =
  let open Abbs_fc.Infix_result_monad in
  Sgs_user_session.Session.fetch_key db
  >>= fun keys -> Sgs_service_orchestration_github_app.oauth config db >>| fun oauth -> (keys, oauth)

let log_unavailable ?(src = src) ctx = function
  | `Orchestration_disabled ->
      Sgs_service_orchestration_common.log_orchestration_unavailable ~src ctx
  | `Oauth_not_configured ->
      Logs_lib.warn ~src (fun m -> m "%s : GITHUB_CLAIM_OAUTH_NOT_CONFIGURED" (Brtl_ctx.token ctx))

type proof_access_err =
  [ Sgs_service_orchestration_github_claim_proof.err
  | `Key_not_found_err
  | `Bad_signing_key_err of string
  | Sgs_eplib.tenant_access_err
  ]

let respond_proof_access_err ?(src = src) ctx = function
  | #Sgs_service_orchestration_github_claim_proof.err as err ->
      Logs_lib.warn ~src (fun m ->
          m
            "%s : GITHUB_CLAIM_PROOF_REJECTED : %a"
            (Brtl_ctx.token ctx)
            Sgs_service_orchestration_github_claim_proof.pp_err
            err);
      Sgs_eplib.respond_error
        ~status:`Precondition_failed
        ~id:"GITHUB_PROOF_REQUIRED"
        ~data:"Prove GitHub access before claiming an installation."
        ctx
  | (`Key_not_found_err | `Bad_signing_key_err _) as err ->
      Sgs_eplib.respond_signing_key_err ctx err
  | #Sgs_eplib.tenant_access_err as err -> Sgs_eplib.respond_tenant_access_err ctx err

let default_redirect = "/getting-started/?path=github"

type redirect_result =
  [ `Ready
  | `Installed
  | `No_admin
  | `Forbidden
  | `Expired
  | `Error
  | `Unavailable
  | `Not_member
  ]

let redirect_result_to_string = function
  | `Ready -> "ready"
  | `Installed -> "installed"
  | `No_admin -> "no_admin"
  | `Forbidden -> "forbidden"
  | `Expired -> "expired"
  | `Error -> "error"
  | `Unavailable -> "unavailable"
  | `Not_member -> "not_member"

(* Scoped to the API prefix and HttpOnly so the token is never readable by page
   scripts and never sent on ordinary page loads. Cohttp's Set_cookie_hdr has no
   SameSite field, so the attribute is appended after serialisation, as
   Brtl_mw_session does. Strict keeps it off every cross-site request, the claim
   POST included. The browser still stores it from this redirect, and only the
   console's same-site fetches ever send it back. *)
let set_proof_cookie ~config ~proof headers =
  let cookie, value =
    Cohttp.Cookie.Set_cookie_hdr.serialize
      (Cohttp.Cookie.Set_cookie_hdr.make
         ~expiration:
           (`Max_age (Int64.of_float Sgs_service_orchestration_github_claim_token.proof_ttl))
         ~path:"/api/v1"
         ~secure:(Sgs_config.secure_cookies config)
         ~http_only:true
         (Sgs_service_orchestration_github_claim_proof.cookie_name, proof))
  in
  Cohttp.Header.add headers cookie (value ^ "; SameSite=Strict")

let redirect_target ~config ctx = function
  | None -> default_redirect
  | Some rd -> (
      match Sgs_redirect.url ~ui_base:(Sgs_config.ui_base config) rd with
      | Some rd -> rd
      | None ->
          Logs.warn (fun m -> m "%s : UNSAFE_REDIRECT : %s" (Brtl_ctx.token ctx) rd);
          default_redirect)

(* [rd] was validated by start, either just now or before it was signed into
   the state. It still goes through [redirect_target] here, because this is
   where the Location header is written. *)
let return_location ~config ~param ~rd ~value ctx =
  let path = redirect_target ~config ctx rd in
  Printf.sprintf "%s%s%s=%s" path (if CCString.contains path '?' then "&" else "?") param value

(* Start and the callback are both reached by a full-page navigation, not a
   console fetch, so the honest thing on a failure is to put the user back on
   the console with a machine-readable reason rather than render an API error in
   a browser tab. *)
let redirect_with ?proof ~config ~rd ~result ctx =
  let location =
    return_location ~config ~param:"github_claim" ~rd ~value:(redirect_result_to_string result) ctx
  in
  let headers = Cohttp.Header.init () in
  let headers =
    CCOption.map_or ~default:headers (fun proof -> set_proof_cookie ~config ~proof headers) proof
  in
  Abb.Future.return (Sgs_service_orchestration_common.respond_found ~headers ~location ctx)

type fault_err =
  [ `Key_not_found_err
  | `Bad_signing_key_err of string
  | Pgsql_io.err
  | Pgsql_pool.err
  ]

let redirect_fault ?src ~config ~rd ctx = function
  | (`Key_not_found_err | `Bad_signing_key_err _) as err ->
      Sgs_eplib.log_signing_key_err ctx err;
      redirect_with ~config ~rd ~result:`Error ctx
  | (#Pgsql_io.err | #Pgsql_pool.err) as err ->
      Sgs_eplib.log_db_err ?src ctx err;
      redirect_with ~config ~rd ~result:`Error ctx
