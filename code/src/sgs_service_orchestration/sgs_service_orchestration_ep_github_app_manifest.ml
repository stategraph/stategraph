let src = Logs.Src.create "service_orchestration_ep_github_app_manifest"

module Logs = (val Logs.src_log src : Logs.LOG)
module App = Sgs_service_orchestration_github_app
module R = Sgs_api_components_github_app_manifest_response

type outcome =
  | Unavailable
  | Invalid of {
      field : string;
      message : string;
    }
  | Exists
  | Form of {
      response : R.t;
      organization : string option;
    }

let invalid = function
  | `Bad_name_err ->
      Invalid
        {
          field = "name";
          message =
            Printf.sprintf "name is required and holds at most %d characters." App.Manifest.name_max;
        }
  | `Bad_organization_err ->
      Invalid
        { field = "organization"; message = "organization must be a GitHub organization login." }

let run' config user body db =
  let module B = Sgs_api_components_github_app_manifest_request in
  let open Abbs_fc.Infix_result_monad in
  if not (App.channel_available config) then Abbs_fc.return_ok Unavailable
  else
    match App.Manifest.validate ~name:body.B.name ~organization:body.B.organization with
    | Error err -> Abbs_fc.return_ok (invalid err)
    | Ok (name, organization) -> (
        App.select db
        >>= function
        (* GitHub creates the App the moment the operator submits, and shows its
           private key once. A server that already has one would store nothing,
           so it is refused before an App exists that nothing can clean up. *)
        | Some _ -> Abbs_fc.return_ok Exists
        | None ->
            Sgs_user_session.Session.fetch_key db
            >>| fun keys ->
            let state =
              Sgs_service_orchestration_github_claim_token.Manifest.mint
                ~signer:(Sgs_user_session.Session.Keys.signer keys)
                ~now:(Unix.gettimeofday ())
                ~user_id:(Uuidm.to_string (Sgs_user.id user))
                ()
            in
            let form =
              App.Manifest.build
                ~ui_base:(Sgs_config.ui_base config)
                ~terrat_api_base:(Sgs_config.terrat_api_base config)
                ~redirect_base:(Sgs_config.public_callback_base config)
                ~web_base:(Sgs_config.github_web_base config)
                ~name
                ~organization
                ~state
            in
            Form
              {
                response =
                  {
                    R.action_url = form.App.Manifest.action_url;
                    manifest = form.App.Manifest.manifest;
                  };
                organization;
              })

let run config storage body =
  Sgs_user_session.with_user ~caps:Sgs_user_session.Caps.admin_instance ~f:(fun user ->
      Brtl_ep.run_json ~f:(fun ctx ->
          let open Abb.Future.Infix_monad in
          let token = Brtl_ctx.token ctx in
          Pgsql_pool.with_conn storage ~f:(run' config user body)
          >>= function
          | Ok Unavailable ->
              Logs.warn (fun m -> m "%s : GITHUB_APP_MANIFEST_UNAVAILABLE" token);
              Abb.Future.return
                (Sgs_eplib.respond_error
                   ~status:`Service_unavailable
                   ~id:"GITHUB_APP_UNAVAILABLE"
                   ~data:
                     "The orchestration engine's admin channel is not configured on this server."
                   ctx)
          | Ok (Invalid { field; message }) ->
              Logs.warn (fun m -> m "%s : GITHUB_APP_MANIFEST_INVALID : %s" token field);
              Abb.Future.return
                (Sgs_eplib.respond_error
                   ~status:`Bad_request
                   ~id:"GITHUB_APP_MANIFEST_INVALID"
                   ~data:message
                   ctx)
          | Ok Exists ->
              Logs.warn (fun m -> m "%s : GITHUB_APP_MANIFEST_EXISTS" token);
              Abb.Future.return
                (Sgs_eplib.respond_error
                   ~status:`Conflict
                   ~id:"GITHUB_APP_EXISTS"
                   ~data:"This server already has a GitHub App."
                   ctx)
          | Ok (Form { response; organization }) ->
              Logs.info (fun m ->
                  m
                    "%s : GITHUB_APP_MANIFEST : user=%a organization=%s"
                    token
                    Uuidm.pp
                    (Sgs_user.id user)
                    (CCOption.get_or ~default:"" organization));
              Abb.Future.return
                (Brtl_ctx.set_response
                   (Brtl_rspnc.create ~status:`OK (Yojson.Safe.to_string @@ R.to_yojson response))
                   ctx)
          | Error ((`Key_not_found_err | `Bad_signing_key_err _) as err) ->
              Sgs_eplib.log_signing_key_err ctx err;
              Abb.Future.return (Sgs_eplib.respond_internal_error ctx)
          | Error ((#Pgsql_pool.err | #Pgsql_io.err) as err) ->
              Sgs_eplib.log_db_err ~src ctx err;
              Abb.Future.return (Sgs_eplib.respond_internal_error ctx)))
