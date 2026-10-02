let src = Logs.Src.create "ep_admin_create"

module Logs = (val Logs.src_log src : Logs.LOG)
module Fc = Abbs_fc

module Sql = struct
  let count_users () =
    Pgsql_io.Typed_sql.(sql // Ret.bigint /^ "select count(*) from users where type = 'user'")

  let create_user () =
    Pgsql_io.Typed_sql.(
      sql
      // Ret.uuid
      /^ "insert into users (email, name, password_hash, type, capability_trie, \
          base_capability_trie) values ($email, $name, $password_hash, 'user', $capability_trie, \
          $capability_trie) returning id"
      /% Var.text "email"
      /% Var.text "name"
      /% Var.text "password_hash"
      /% Var.json "capability_trie")

  let upsert_system_setting () =
    Pgsql_io.Typed_sql.(
      sql /^ [%blob "./sql/upsert_system_setting.sql"] /% Var.text "key" /% Var.json "value")
end

let add_user_to_default_tenant token db default_tenant_name user user_id =
  let open Fc.Infix_result_monad in
  match default_tenant_name with
  | Some tenant_name ->
      Sgs_tenant.find_or_create tenant_name db
      >>= fun tenant ->
      Sgs_tenant.add_user tenant user db
      >>| fun () ->
      Logs.info (fun m ->
          m
            "%s : SETUP_TENANT_ADDED : Added user %a to tenant %s"
            token
            Uuidm.pp
            user_id
            tenant_name);
      ()
  | None -> Abbs_fc.return_ok ()

let run' ?default_tenant_name ~requirement config token db email password name =
  let open Fc.Infix_result_monad in
  (* Gate setup on a valid license before creating anything. The key is expected
     to have been stored already via POST /api/v1/license (or supplied via the
     STATEGRAPH_LICENSE_KEY env var). *)
  Sgs_service_license.passes_license_gate ~requirement config db
  >>= fun licensed ->
  if not licensed then Abbs_fc.return_err `License_required_err
  else
    (* Check: No users exist *)
    Pgsql_io.Prepared_stmt.fetch db (Sql.count_users ()) ~f:CCFun.id
    >>= function
    | count :: _ when count > 0L ->
        Logs.warn (fun m ->
            m "%s : SETUP_ALREADY_COMPLETE Admin creation attempted but users exist" token);
        Abbs_fc.return_err `Users_exist_err
    | _ -> (
        (* Hash password *)
        let password_hash = Sgs_user_password.hash password in
        Sgs_user.caps_for ~admin:`Instance db
        >>= fun capabilities ->
        (* Create user *)
        Pgsql_io.Prepared_stmt.fetch
          db
          (Sql.create_user ())
          ~f:CCFun.id
          email
          name
          password_hash
          (Sg_caps_json.to_json capabilities)
        >>= function
        | user_id :: _ ->
            Logs.info (fun m ->
                m "%s : SETUP_ADMIN_CREATED Created admin user %a" token Uuidm.pp user_id);
            let user = Sgs_user.make ~id:user_id () in
            add_user_to_default_tenant token db default_tenant_name user user_id
            >>= fun () ->
            (* Fetch encryption key for session *)
            Sgs_user_session.Session.fetch_key db
            >>= fun key ->
            (* DB-backed login session; capability changes revoke it. *)
            Sgs_user_session.Session.create_login ~capabilities user db
            >>= fun session ->
            Fc.to_result @@ Sgs_user_session.Session.to_token ~key session
            >>= fun session_token ->
            (* Mark setup as completed *)
            Pgsql_io.Prepared_stmt.execute
              db
              (Sql.upsert_system_setting ())
              "setup_completed"
              (`Bool true)
            >>| fun () ->
            Logs.info (fun m -> m "%s : SETUP_COMPLETE Setup completed" token);
            (user_id, session_token)
        | [] -> assert false)

let internal_error_body =
  Sgs_eplib.error_response_body ~id:"INTERNAL_SERVER_ERROR" ~data:"Failed to create admin user"

let run ~requirement config storage =
  Brtl_ep.run_json ~f:(fun ctx ->
      let token = Brtl_ctx.token ctx in
      let open Abb.Future.Infix_monad in
      (* Check: Only allow if OAuth is NOT configured *)
      match Sgs_config.oauth2 config with
      | Some _ ->
          Logs.warn (fun m ->
              m "%s : OAUTH_MODE_ACTIVE Admin creation attempted in OAuth mode" token);
          Abb.Future.return
            (Sgs_eplib.respond_error
               ~status:`Forbidden
               ~id:"OAUTH_MODE_ENABLED"
               ~data:"Admin setup not available when OAuth is configured"
               ctx)
      | None -> (
          (* Parse request body *)
          let body = Brtl_ctx.body ctx in
          match Sgs_api_components_setup_admin_request.of_yojson (Yojson.Safe.from_string body) with
          | Ok { Sgs_api_components_setup_admin_request.email; password; name; organization = _ }
            -> (
              (* Validate password strength *)
              match Sgs_user_password.validate_strength password with
              | Ok () -> (
                  let default_tenant_name = Sgs_config.default_tenant_name config in
                  Pgsql_pool.with_conn storage ~f:(fun db ->
                      (* Atomic: user insert, tenant attach, and the setup-completed marker
                         must all land together or not at all. *)
                      Pgsql_io.tx db ~f:(fun () ->
                          run' ?default_tenant_name ~requirement config token db email password name))
                  >>= function
                  | Ok (user_id, session_token) ->
                      let response =
                        {
                          Sgs_api_components_setup_admin_response.user_id = Uuidm.to_string user_id;
                          session_token;
                        }
                      in
                      let body =
                        Yojson.Safe.to_string
                        @@ Sgs_api_components_setup_admin_response.to_yojson response
                      in
                      Abb.Future.return
                        (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Created body) ctx)
                  | Error `License_required_err ->
                      Logs.warn (fun m ->
                          m
                            "%s : LICENSE_REQUIRED Admin creation attempted without a valid license"
                            token);
                      Abb.Future.return
                        (Sgs_eplib.respond_error
                           ~status:`Forbidden
                           ~id:"LICENSE_REQUIRED"
                           ~data:"A valid license key is required to complete setup."
                           ctx)
                  | Error `Users_exist_err ->
                      Logs.warn (fun m ->
                          m
                            "%s : SETUP_ALREADY_COMPLETE Admin creation attempted but users exist"
                            token);
                      Abb.Future.return
                        (Sgs_eplib.respond_error
                           ~status:`Conflict
                           ~id:"SETUP_ALREADY_COMPLETE"
                           ~data:"Admin user already exists"
                           ctx)
                  | Error ((`Bad_signing_key_err _ | `Key_not_found_err) as err) ->
                      Abb.Future.return
                        (Sgs_eplib.respond_signing_key_err ~body:internal_error_body ctx err)
                  | Error ((#Pgsql_pool.err | #Pgsql_io.err) as err) ->
                      Abb.Future.return
                        (Sgs_eplib.respond_db_err ~src ~body:internal_error_body ctx err))
              | Error msg ->
                  Logs.warn (fun m ->
                      m "%s : VALIDATION_FAILED Password validation failed: %s" token msg);
                  Abb.Future.return
                    (Sgs_eplib.respond_error
                       ~status:`Bad_request
                       ~id:"PASSWORD_VALIDATION_FAILED"
                       ~data:msg
                       ctx))
          | Error err ->
              Logs.warn (fun m -> m "%s : INVALID_REQUEST Invalid request body: %s" token err);
              Abb.Future.return
                (Sgs_eplib.respond_error
                   ~status:`Bad_request
                   ~id:"INVALID_REQUEST_BODY"
                   ~data:err
                   ctx)))
