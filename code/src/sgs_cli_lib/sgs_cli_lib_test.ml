let exec f =
  match Abb.Scheduler.run_with_state f with
  | `Det (Ok n) -> exit n
  | `Det (Error (#Pgsql_pool.err as err)) ->
      Logs.err (fun m -> m "%a" Pgsql_pool.pp_err err);
      exit 1
  | `Det (Error (#Pgsql_io.err as err)) ->
      Logs.err (fun m -> m "%a" Pgsql_io.pp_err err);
      exit 1
  | `Det (Error _) -> exit 1
  | `Aborted ->
      Logs.err (fun m -> m "Aborted");
      exit 1
  | `Exn (exn, bt_opt) ->
      Logs.err (fun m -> m "%s" (Printexc.to_string exn));
      CCOption.iter
        (fun bt -> Logs.err (fun m -> m "%s" (Printexc.raw_backtrace_to_string bt)))
        bt_opt;
      exit 1

let load_config_and_storage () =
  match Sgs_config.create () with
  | Ok config ->
      let open Abb.Future.Infix_monad in
      Sgs_storage.create config >>= fun storage -> Abb.Future.return (config, storage)
  | Error (#Sgs_config.err as err) -> raise (Failure (Sgs_config.show_err err))

module Convs = struct
  let uuid =
    Cmdliner.Arg.Conv.make
      ~docv:"UUID"
      ~parser:(fun s ->
        match Uuidm.of_string s with
        | Some uuid -> Ok uuid
        | None -> Error "Invalid UUID")
      ~pp:Uuidm.pp
      ()
end

module Account = struct
  module Tenant = struct
    module Create = struct
      module Args = struct
        module C = Cmdliner

        let name =
          let doc = "Tenant name" in
          C.Arg.(required & opt (some string) None & info [ "n"; "name" ] ~doc)
      end

      let run name () =
        let go () =
          let open Abb.Future.Infix_monad in
          load_config_and_storage ()
          >>= fun (_config, storage) ->
          let open Abbs_fc.Infix_result_monad in
          Pgsql_pool.with_conn storage ~f:(Sgs_tenant.store name)
          >>| fun tenant ->
          Printf.printf "%s\n" (Uuidm.to_string @@ Sgs_tenant.id tenant);
          0
        in
        exec go

      let cmd logs =
        let module C = Cmdliner in
        let doc = "Create a new tenant" in
        let exits = C.Cmd.Exit.defaults in
        C.Cmd.v (C.Cmd.info "create" ~doc ~exits) C.Term.(const run $ Args.name $ logs)
    end

    module Add_user = struct
      module Args = struct
        module C = Cmdliner

        let tenant =
          let doc = "Tenant ID" in
          C.Arg.(required & opt (some Convs.uuid) None & info [ "tenant" ] ~doc)

        let user =
          let doc = "User ID" in
          C.Arg.(required & opt (some Convs.uuid) None & info [ "user" ] ~doc)
      end

      let run tenant_id user_id () =
        let go () =
          let open Abb.Future.Infix_monad in
          load_config_and_storage ()
          >>= fun (_config, storage) ->
          let open Abbs_fc.Infix_result_monad in
          Pgsql_pool.with_conn storage ~f:(fun db ->
              Sgs_tenant.add_user_idempotent
                (Sgs_tenant.make ~id:tenant_id ())
                (Sgs_user.make ~id:user_id ())
                db)
          >>| fun () ->
          Printf.printf
            "Added user %s to tenant %s\n"
            (Uuidm.to_string user_id)
            (Uuidm.to_string tenant_id);
          0
        in
        exec go

      let cmd logs =
        let module C = Cmdliner in
        let doc = "Add a user to a tenant" in
        let exits = C.Cmd.Exit.defaults in
        C.Cmd.v
          (C.Cmd.info "add-user" ~doc ~exits)
          C.Term.(const run $ Args.tenant $ Args.user $ logs)
    end

    let cmd logs =
      let module C = Cmdliner in
      let doc = "Manage tenants" in
      let info = C.Cmd.info ~doc "tenants" in
      C.Cmd.group info [ Create.cmd logs; Add_user.cmd logs ]
  end

  module User = struct
    module Create = struct
      module Sql = struct
        (* --reuse-existing lookups: there is no UNIQUE on users.name nor on
           tenants.name, so repeated runs of [test accounts users create]
           accumulate rows. Picking the oldest row keeps the choice stable
           across runs -- the principal you reused yesterday is the same one
           you reuse today. *)
        let select_user_by_name () =
          Pgsql_io.Typed_sql.(
            sql
            //
            (* id *)
            Ret.uuid
            /^ "select id from users where name = $name and type = 'user' order by created_at \
                limit 1"
            /% Var.text "name")

        let select_tenant_by_name () =
          Pgsql_io.Typed_sql.(
            sql
            //
            (* id *)
            Ret.uuid
            /^ "select id from tenants where name = $name order by created_at limit 1"
            /% Var.text "name")

        let set_user_password () =
          Pgsql_io.Typed_sql.(
            sql
            /^ "update users set password_hash = $password_hash where id = $user_id"
            /% Var.text "password_hash"
            /% Var.uuid "user_id")
      end

      module Args = struct
        module C = Cmdliner

        let name =
          let doc = "User name" in
          C.Arg.(required & opt (some string) None & info [ "n"; "name" ] ~doc)

        let admin =
          let doc = "Make the user an admin" in
          C.Arg.(value & flag & info [ "admin" ] ~doc)

        let password =
          let doc =
            "Give the user password authentication with this password, 8 to 128 characters. Unlike \
             the capability flags, this one is applied to a reused user too, replacing whatever \
             password it had."
          in
          C.Arg.(value & opt (some string) None & info [ "password" ] ~doc)

        let users_manage_tenant =
          let doc =
            "Grant $(b,users-manage) scoped to this tenant id; repeat for several. Cannot be given \
             together with $(b,--users-manage): a grant names every tenant or the tenants listed, \
             never both, so asking for both is refused rather than resolved."
          in
          C.Arg.(value & opt_all string [] & info [ "users-manage-tenant" ] ~doc)

        let users_manage =
          let doc =
            "Grant the user an unscoped $(b,users-manage) capability: authority over every user on \
             the installation, and not over the installation itself."
          in
          C.Arg.(value & flag & info [ "users-manage" ] ~doc)

        let reuse_existing =
          let doc =
            "Reuse the oldest user and tenant matching $(b,--name) (and ensure membership) instead \
             of inserting fresh rows. Mints a fresh access token + session either way. \
             $(b,--admin) and $(b,--users-manage) are ignored when an existing user is reused -- \
             the user's existing capabilities are kept."
          in
          C.Arg.(value & flag & info [ "reuse-existing" ] ~doc)

        let url =
          let doc = "Print the full set-cookie URL with the token instead of just the token." in
          C.Arg.(value & flag & info [ "url" ] ~doc)
      end

      (* What the two users-manage flags between them ask for. *)
      type users_manage_grant =
        | No_grant
        | Unscoped
        | Confined_to of string list

      let users_manage_grant ~users_manage ~users_manage_tenant =
        match (users_manage, users_manage_tenant) with
        | true, _ :: _ ->
            (* [exec] exits 1 on an error it does not recognise without printing anything, so the
               reason has to be said here or the command fails mute. *)
            Logs.err (fun m ->
                m
                  "--users-manage and --users-manage-tenant cannot be given together: one grants \
                   users-manage over every tenant, the other confines it to the tenants named");
            Error `Conflicting_users_manage_flags_err
        | true, [] -> Ok Unscoped
        | false, [] -> Ok No_grant
        | false, (_ :: _ as tenants) -> Ok (Confined_to tenants)

      (* The capabilities a freshly inserted user is given: the installation default, plus whatever
         the flags ask for. *)
      let capabilities_for ~admin ~users_manage ~users_manage_tenant db =
        let open Abbs_fc.Infix_result_monad in
        Abb.Future.return (users_manage_grant ~users_manage ~users_manage_tenant)
        >>= fun grant ->
        Sgs_user.caps_for ~admin:(if admin then `Instance else `No) db
        >>| fun caps ->
        let with_users_manage users_manage = { caps with Sg_caps.users_manage } in
        match grant with
        | No_grant -> caps
        | Unscoped -> with_users_manage Sg_caps_trie_scope.full
        | Confined_to tenants ->
            with_users_manage
              (CCResult.get_or
                 ~default:Sg_caps_trie_scope.empty
                 (Sg_caps_trie_scope.of_strings tenants))

      (* Look up the oldest existing user with the given name, or insert a new
         one if none exists. *)
      let find_or_create_user db ~name ~capabilities =
        let open Abbs_fc.Infix_result_monad in
        Pgsql_io.Prepared_stmt.fetch db (Sql.select_user_by_name ()) ~f:CCFun.id name
        >>= function
        | id :: _ -> Sgs_user.enrich (Sgs_user.make ~id ()) db
        | [] -> Sgs_user.store ~capabilities ~name ~type_:Sgs_user.Type_.User db

      (* Same idea for the tenant; returns just the id, which is all a
         [Sgs_tenant.make] handle for the membership add needs. *)
      let find_or_create_tenant_id db ~name =
        let open Abbs_fc.Infix_result_monad in
        Pgsql_io.Prepared_stmt.fetch db (Sql.select_tenant_by_name ()) ~f:CCFun.id name
        >>= function
        | id :: _ -> Abbs_fc.return_ok id
        | [] -> Sgs_tenant.store name db >>| fun t -> Sgs_tenant.id t

      let set_password password db user =
        match Sgs_user_password.validate_strength password with
        | Ok () ->
            Pgsql_io.Prepared_stmt.execute
              db
              (Sql.set_user_password ())
              (Sgs_user_password.hash password)
              (Sgs_user.id user)
        | Error msg ->
            Logs.err (fun m -> m "Invalid --password: %s" msg);
            Abbs_fc.return_err `Bad_password_err

      let run name admin users_manage users_manage_tenant password reuse_existing url () =
        let go () =
          let open Abb.Future.Infix_monad in
          load_config_and_storage ()
          >>= fun (_config, storage) ->
          let open Abbs_fc.Infix_result_monad in
          Pgsql_pool.with_conn storage ~f:(fun db ->
              Pgsql_io.tx db ~f:(fun () ->
                  capabilities_for ~admin ~users_manage ~users_manage_tenant db
                  >>= fun capabilities ->
                  (if reuse_existing then find_or_create_user db ~name ~capabilities
                   else Sgs_user.store ~capabilities ~name ~type_:Sgs_user.Type_.User db)
                  >>= fun user ->
                  (match password with
                    | None -> Abbs_fc.return_ok ()
                    | Some password -> set_password password db user)
                  >>= fun () ->
                  (if reuse_existing then find_or_create_tenant_id db ~name
                   else Sgs_tenant.store name db >>| fun t -> Sgs_tenant.id t)
                  >>= fun tenant_id ->
                  Sgs_tenant.add_user_idempotent (Sgs_tenant.make ~id:tenant_id ()) user db
                  >>= fun () ->
                  Sgs_user_access_token.store
                    ~name:"Automatically created session"
                    ~capabilities:(Sgs_user.capabilities user)
                    user
                    db
                  >>= fun access_token ->
                  Sgs_user_session.Session.fetch_key db
                  >>= fun key ->
                  let session =
                    Sgs_user_session.Session.create
                      ~expiration:
                        (Sgs_user_session.Session.Expiration.Access_token
                           (Sgs_user_access_token.id access_token))
                      (Sgs_user.to_minted user)
                  in
                  let open Abb.Future.Infix_monad in
                  Sgs_user_session.Session.to_token ~key session
                  >>= fun token ->
                  if url then Printf.printf "/api/v1/test/set-cookie?session-id=%s\n" token
                  else Printf.printf "%s\n" token;
                  Abbs_fc.return_ok 0))
        in
        exec go

      let cmd logs =
        let module C = Cmdliner in
        let doc = "Create a new user" in
        let exits = C.Cmd.Exit.defaults in
        C.Cmd.v
          (C.Cmd.info "create" ~doc ~exits)
          C.Term.(
            const run
            $ Args.name
            $ Args.admin
            $ Args.users_manage
            $ Args.users_manage_tenant
            $ Args.password
            $ Args.reuse_existing
            $ Args.url
            $ logs)
    end

    module Api_key = struct
      module Create = struct
        module Sql = struct
          let select_user_id_by_email () =
            Pgsql_io.Typed_sql.(
              sql // Ret.uuid /^ "select id from users where email = $email" /% Var.text "email")

          let select_user_id_by_id () =
            Pgsql_io.Typed_sql.(
              sql // Ret.uuid /^ "select id from users where id = $id" /% Var.uuid "id")
        end

        module Args = struct
          module C = Cmdliner

          let user =
            let doc =
              "Email or UUID of the user for whom to create an API key. Values containing '@' are \
               treated as emails, otherwise as UUIDs."
            in
            C.Arg.(required & opt (some string) None & info [ "user" ] ~doc)

          let name =
            let doc = "Human-readable name for this API key" in
            C.Arg.(required & opt (some string) None & info [ "n"; "name" ] ~doc)

          let expiration =
            let doc = "Lifetime in seconds (omit for no expiration)" in
            C.Arg.(value & opt (some int) None & info [ "expiration" ] ~doc)
        end

        let lookup_user_id db user_ident =
          let open Abbs_fc.Infix_result_monad in
          if CCString.contains user_ident '@' then
            Pgsql_io.Prepared_stmt.fetch db (Sql.select_user_id_by_email ()) ~f:CCFun.id user_ident
            >>| fun rows -> `Rows rows
          else
            match Uuidm.of_string user_ident with
            | None -> Abbs_fc.return_ok `Invalid_uuid
            | Some id ->
                Pgsql_io.Prepared_stmt.fetch db (Sql.select_user_id_by_id ()) ~f:CCFun.id id
                >>| fun rows -> `Rows rows

        let run user_ident name expiration_secs () =
          let go () =
            let open Abb.Future.Infix_monad in
            load_config_and_storage ()
            >>= fun (_config, storage) ->
            let open Abbs_fc.Infix_result_monad in
            Pgsql_pool.with_conn storage ~f:(fun db ->
                lookup_user_id db user_ident
                >>= function
                | `Invalid_uuid ->
                    Logs.err (fun m -> m "Invalid user UUID: %s" user_ident);
                    Abbs_fc.return_ok 1
                | `Rows [] ->
                    Logs.err (fun m -> m "User not found: %s" user_ident);
                    Abbs_fc.return_ok 1
                | `Rows (user_id :: _) ->
                    let expiration = CCOption.map Duration.of_sec expiration_secs in
                    Sgs_user.enrich (Sgs_user.make ~id:user_id ()) db
                    >>= fun user ->
                    Sgs_user_access_token.store
                      ?expiration
                      ~name
                      ~capabilities:(Sgs_user.capabilities user)
                      user
                      db
                    >>= fun access_token ->
                    Sgs_user_session.Session.fetch_key db
                    >>= fun key ->
                    let session =
                      Sgs_user_session.Session.create
                        ~expiration:
                          (Sgs_user_session.Session.Expiration.Access_token
                             (Sgs_user_access_token.id access_token))
                        (Sgs_user.to_minted user)
                    in
                    let open Abb.Future.Infix_monad in
                    Sgs_user_session.Session.to_token ~key session
                    >>= fun token ->
                    Printf.printf "%s\n" token;
                    Abbs_fc.return_ok 0)
          in
          exec go

        let cmd logs =
          let module C = Cmdliner in
          let doc = "Create an API key for an existing user (by email or UUID)" in
          let exits = C.Cmd.Exit.defaults in
          C.Cmd.v
            (C.Cmd.info "create" ~doc ~exits)
            C.Term.(const run $ Args.user $ Args.name $ Args.expiration $ logs)
      end

      let cmd logs =
        let module C = Cmdliner in
        let doc = "Manage API keys" in
        let info = C.Cmd.info ~doc "api-key" in
        C.Cmd.group info [ Create.cmd logs ]
    end

    module Login = struct
      module Args = struct
        module C = Cmdliner

        let user =
          let doc = "UUID of the user to log in." in
          C.Arg.(required & opt (some Convs.uuid) None & info [ "user" ] ~doc)

        let group =
          let doc =
            "A group the user is a member of; repeat for several. Rules are evaluated against \
             these."
          in
          C.Arg.(value & opt_all string [] & info [ "group" ] ~doc)
      end

      (* Replays exactly what the OAuth callback does at login: union every matching rule's grant
         onto the user's baseline and persist it as the effective capabilities. *)
      let run user_id groups () =
        let go () =
          let open Abb.Future.Infix_monad in
          load_config_and_storage ()
          >>= fun (_config, storage) ->
          let open Abbs_fc.Infix_result_monad in
          Pgsql_pool.with_conn storage ~f:(fun db ->
              Sgs_caps_rules.list_alive db
              >>= fun rules ->
              let group_caps = Sgs_caps_rules.eval rules ~groups in
              Sgs_user.recompute_login_capabilities ~group_caps db user_id
              >>| fun effective ->
              Printf.printf "%s\n" (Yojson.Safe.to_string (Sg_caps_json.to_json effective));
              0)
        in
        exec go

      let cmd logs =
        let module C = Cmdliner in
        let doc =
          "Log a user in, evaluating the group rules against the --group memberships given here \
           (as a real login evaluates them against the IdP's groups): persist and print the user's \
           recomputed capabilities (baseline union the matching grants). Test only."
        in
        let exits = C.Cmd.Exit.defaults in
        C.Cmd.v (C.Cmd.info "login" ~doc ~exits) C.Term.(const run $ Args.user $ Args.group $ logs)
    end

    let cmd logs =
      let module C = Cmdliner in
      let doc = "Manage user" in
      let info = C.Cmd.info ~doc "users" in
      C.Cmd.group info [ Create.cmd logs; Api_key.cmd logs; Login.cmd logs ]
  end

  let cmd logs =
    let module C = Cmdliner in
    let doc = "Manage accounts" in
    let info = C.Cmd.info ~doc "accounts" in
    C.Cmd.group info [ Tenant.cmd logs; User.cmd logs ]
end

let cmd logs =
  let module C = Cmdliner in
  let doc = "Test interface.  Do not use." in
  let info = C.Cmd.info ~doc "test" in
  C.Cmd.group info [ Account.cmd logs ]
