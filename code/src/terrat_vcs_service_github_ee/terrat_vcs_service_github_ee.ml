let src = Logs.Src.create "vcs_service_github_oss"

module Logs = (val Logs.src_log src : Logs.LOG)

module Provider :
  Terrat_vcs_provider2_github.S
    with type Api.Config.t = Terrat_vcs_service_github_provider.Api.Config.t = struct
  let name = Terrat_vcs_service_github_provider.name
  let enforce_installation_access = Terrat_vcs_service_github_provider.enforce_installation_access

  module Api = Terrat_vcs_api_github
  module Unlock_id = Terrat_vcs_service_github_provider.Unlock_id
  module Db = Terrat_vcs_service_github_provider.Db
  module Apply_requirements = Terrat_vcs_service_github_provider.Apply_requirements
  module Tier = Terrat_vcs_service_github_provider.Tier

  (* Order matters here.  Roles closer to the beginning of the search are more
         powerful than those closer to the end *)
  let repo_permission_levels =
    [
      ("admin", "admin");
      ("maintain", "maintain");
      ("write", "write");
      ("triage", "triage");
      ("read", "read");
    ]

  let match_user ~request_id client repo user =
    let module M = Terrat_base_repo_config_v1.Access_control.Match in
    function
    | M.User value -> Abbs_future_combinators.return_ok (CCString.equal value user)
    | M.Team value -> (
        let open Abb.Future.Infix_monad in
        Api.is_member_of_team ~request_id ~team:value ~user:(Api.User.make user) repo client
        >>= function
        | Ok res -> Abbs_future_combinators.return_ok res
        | Error _ -> Abbs_future_combinators.return_err `Error)
    | M.Role value -> (
        let open Abb.Future.Infix_monad in
        match CCList.find_idx CCFun.(fst %> CCString.equal value) repo_permission_levels with
        | Some (idx, _) -> (
            Api.get_repo_role ~request_id repo (Api.User.make user) client
            >>= function
            | Ok (Some role) -> (
                match CCList.find_idx CCFun.(snd %> CCString.equal role) repo_permission_levels with
                | Some (idx_role, _) ->
                    (* Test if their actual role has an index less than or
                           equal to the index of the role in the query. *)
                    Abbs_future_combinators.return_ok (idx_role <= idx)
                | None -> Abbs_future_combinators.return_ok false)
            | Ok None -> Abbs_future_combinators.return_ok false
            | Error _ -> Abbs_future_combinators.return_err `Error)
        | None -> raise (Failure "nyi")
        (* Abb.Future.return (Error (`Invalid_query query)) *))
    | M.Any -> Abbs_future_combinators.return_ok true

  module Gate = struct
    module Sql = struct
      let read s =
        s
        |> CCString.split_on_char '\n'
        |> CCList.filter CCFun.(CCString.prefix ~pre:"--" %> not)
        |> CCString.concat "\n"

      let gate = CCFun.(Terrat_gate.of_yojson %> CCResult.to_opt)

      let insert_gate_approval =
        Pgsql_io.Typed_sql.(
          sql
          /^ read [%blob "sql/insert_gate_approval.sql"]
          /% Var.text "approver"
          /% Var.text "token"
          /% Var.bigint "repository"
          /% Var.bigint "pull_number"
          /% Var.text "sha")

      let select_gate_approvals =
        Pgsql_io.Typed_sql.(
          sql
          //
          (* token *)
          Ret.text
          //
          (* approver *)
          Ret.text
          /^ read [%blob "sql/select_gate_approvals.sql"]
          /% Var.bigint "repository"
          /% Var.bigint "pull_number")

      let select_gates =
        Pgsql_io.Typed_sql.(
          sql
          //
          (* name *)
          Ret.(option text)
          //
          (* token *)
          Ret.(option text)
          //
          (* gate *)
          Ret.u Ret.json gate
          //
          (* dir *)
          Ret.text
          //
          (* workspace *)
          Ret.text
          /^ read [%blob "sql/select_gates.sql"]
          /% Var.bigint "repository"
          /% Var.bigint "pull_number"
          /% Var.(str_array (text "dirs"))
          /% Var.(str_array (text "workspaces")))
    end

    let add_approval ~request_id ~token ~approver pull_request db =
      let open Abb.Future.Infix_monad in
      let repo_id = CCInt64.of_int @@ Api.Repo.id @@ Terrat_pull_request.repo pull_request in
      let pull_number = CCInt64.of_int @@ Terrat_pull_request.id pull_request in
      let sha = Api.Ref.to_string @@ Terrat_pull_request.branch_ref pull_request in
      Pgsql_io.Prepared_stmt.execute
        db
        Sql.insert_gate_approval
        approver
        token
        repo_id
        pull_number
        sha
      >>= function
      | Ok () -> Abbs_future_combinators.return_ok ()
      | Error (#Pgsql_io.err as err) ->
          Logs.err (fun m -> m "%s : %a" request_id Pgsql_io.pp_err err);
          Abbs_future_combinators.return_err `Error

    let eval ~request_id client dirspaces pull_request db =
      let module Match_set = CCSet.Make (Terrat_base_repo_config_v1.Access_control.Match) in
      let module Match_map = CCMap.Make (Terrat_base_repo_config_v1.Access_control.Match) in
      let run =
        let open Abbs_future_combinators.Infix_result_monad in
        let repo = Terrat_pull_request.repo pull_request in
        let repo_id = CCInt64.of_int @@ Api.Repo.id @@ Terrat_pull_request.repo pull_request in
        let pull_number = CCInt64.of_int @@ Terrat_pull_request.id pull_request in
        Pgsql_io.Prepared_stmt.fetch
          db
          Sql.select_gate_approvals
          ~f:(fun token approver -> (token, approver))
          repo_id
          pull_number
        >>= fun approvers ->
        CCList.iter
          (fun (token, approver) ->
            Logs.info (fun m ->
                m "%s : CHECK_GATE : token=%s : approver=%s" request_id token approver))
          approvers;
        let approvers_map =
          CCList.fold_left
            (fun acc (token, approver) -> Sln_map.String.add_to_list token approver acc)
            Sln_map.String.empty
            approvers
        in
        Api.fetch_pull_request_reviews
          ~request_id
          (Api.Pull_request.repo pull_request)
          (Api.Pull_request.id pull_request)
          client
        >>= fun reviews ->
        let approved_reviewers =
          Sln_set.String.of_list
          @@ CCList.filter_map
               (let module R = Terrat_pull_request_review in
                function
                | { R.status = R.Status.Approved; user; _ } -> user
                | _ -> None)
               reviews
        in
        (* This is all users that have approved this pull request either by the
           VCS UI or explicit gate keeper *)
        let all_approvers =
          Sln_set.String.to_list
            (Sln_set.String.union
               approved_reviewers
               (Sln_set.String.of_list @@ CCList.map snd approvers))
        in
        Pgsql_io.Prepared_stmt.fetch
          db
          Sql.select_gates
          ~f:(fun name token gate dir workspace ->
            (token, name, gate, { Terrat_dirspace.dir; workspace }))
          repo_id
          pull_number
          (CCList.map (fun { Terrat_dirspace.dir; _ } -> dir) dirspaces)
          (CCList.map (fun { Terrat_dirspace.workspace; _ } -> workspace) dirspaces)
        >>= fun gates ->
        let gates_map =
          Terrat_data.Dirspace_map.to_list
          @@ CCList.fold_left
               (fun acc (token, name, gate, dirspace) ->
                 Terrat_data.Dirspace_map.add_to_list dirspace (token, name, gate) acc)
               Terrat_data.Dirspace_map.empty
               gates
        in
        let all_queries =
          Match_set.to_list
          @@ Match_set.of_list
          @@ CCList.flat_map
               (fun (_, gates) ->
                 CCList.flat_map
                   (fun (_, _, { Terrat_gate.all_of; any_of; any_of_count = _ }) -> all_of @ any_of)
                   gates)
               gates_map
        in
        (* Given all of the queries and all approvers, match an approver against
           the query.  This way we can go from query -> list of users who match
           it. *)
        Abbs_future_combinators.List_result.map
          ~f:(fun q ->
            Abbs_future_combinators.List_result.map
              ~f:(fun approver ->
                match_user ~request_id client repo approver q
                >>= function
                | true -> Abbs_future_combinators.return_ok (Some approver)
                | false -> Abbs_future_combinators.return_ok None)
              all_approvers
            >>= fun res ->
            let res = CCList.filter_map CCFun.id res in
            Abbs_future_combinators.return_ok (q, res))
          all_queries
        >>= fun query_results ->
        let query_to_users = Match_map.of_list query_results in
        Abbs_future_combinators.return_ok
          (CCList.flat_map
             (fun (dirspace, gates) ->
               CCList.filter_map
                 (fun (token, name, { Terrat_gate.all_of; any_of; any_of_count }) ->
                   let { Terrat_dirspace.dir; workspace } = dirspace in
                   Logs.info (fun m ->
                       m
                         "%s : GATE : dir=%s : workspace=%s : token=%s : name=%s : all_of=%s"
                         request_id
                         dir
                         workspace
                         (CCOption.get_or ~default:"" token)
                         (CCOption.get_or ~default:"" name)
                         (CCString.concat " " @@ CCList.map Terrat_gate.Match.to_string all_of));
                   Logs.info (fun m ->
                       m
                         "%s : GATE : dir=%s : workspace=%s : token=%s : name=%s : any_of=%s"
                         request_id
                         dir
                         workspace
                         (CCOption.get_or ~default:"" token)
                         (CCOption.get_or ~default:"" name)
                         (CCString.concat " " @@ CCList.map Terrat_gate.Match.to_string any_of));
                   Logs.info (fun m ->
                       m
                         "%s : GATE : dir=%s : workspace=%s : token=%s : name=%s : any_of_count=%d"
                         request_id
                         dir
                         workspace
                         (CCOption.get_or ~default:"" token)
                         (CCOption.get_or ~default:"" name)
                         any_of_count);
                   (* Given a gate, we want to know if it has been approved
                         by everyone that must be.  If [token] is [Some string]
                         then that means we need to match it to the specific
                         token approvers, if it is not then it means we need to
                         match it against the VCS approvers. *)
                   let gate_approvers =
                     match token with
                     | Some token ->
                         Sln_set.String.of_list
                         @@ CCOption.get_or ~default:[]
                         @@ Sln_map.String.find_opt token approvers_map
                     | None -> approved_reviewers
                   in
                   (* A map of query to users who have approved that token.
                         An empty list for the query means that it has not been
                         approved by anyone. *)
                   let all_of =
                     CCList.map
                       (fun m ->
                         ( m,
                           CCList.filter CCFun.(flip Sln_set.String.mem gate_approvers)
                           @@ CCOption.get_or ~default:[]
                           @@ Match_map.find_opt m query_to_users ))
                       all_of
                   in
                   (* Set of users that have approved the token for the any_of matches. *)
                   let any_of_set =
                     Sln_set.String.of_list
                     @@ CCList.filter CCFun.(flip Sln_set.String.mem gate_approvers)
                     @@ CCList.flat_map
                          CCFun.(
                            flip Match_map.find_opt query_to_users %> CCOption.get_or ~default:[])
                          any_of
                   in
                   let passed =
                     CCList.for_all CCFun.(snd %> CCList.is_empty %> not) all_of
                     && any_of_count <= Sln_set.String.cardinal any_of_set
                   in
                   let all_of =
                     CCList.filter_map
                       (function
                         | q, [] -> Some q
                         | _q, _ -> None)
                       all_of
                   in
                   let result =
                     {
                       Terrat_gate.all_of;
                       any_of;
                       any_of_count = CCInt.max 0 (any_of_count - Sln_set.String.cardinal any_of_set);
                     }
                   in
                   Logs.info (fun m ->
                       m
                         "%s : GATE : RESULT : dir=%s : workspace=%s : token=%s : name=%s : \
                          all_of=%s"
                         request_id
                         dir
                         workspace
                         (CCOption.get_or ~default:"" token)
                         (CCOption.get_or ~default:"" name)
                         (CCString.concat " " @@ CCList.map Terrat_gate.Match.to_string all_of));
                   Logs.info (fun m ->
                       m
                         "%s : GATE : RESULT : dir=%s : workspace=%s : token=%s : name=%s : \
                          any_of=%s"
                         request_id
                         dir
                         workspace
                         (CCOption.get_or ~default:"" token)
                         (CCOption.get_or ~default:"" name)
                         (CCString.concat " " @@ CCList.map Terrat_gate.Match.to_string any_of));
                   Logs.info (fun m ->
                       m
                         "%s : GATE : RESULT : dir=%s : workspace=%s : token=%s : name=%s : \
                          any_of_count=%d"
                         request_id
                         dir
                         workspace
                         (CCOption.get_or ~default:"" token)
                         (CCOption.get_or ~default:"" name)
                         any_of_count);
                   Logs.info (fun m ->
                       m
                         "%s : GATE : RESULT : dir=%s : workspace=%s : token=%s : name=%s : \
                          passed=%s"
                         request_id
                         dir
                         workspace
                         (CCOption.get_or ~default:"" token)
                         (CCOption.get_or ~default:"" name)
                         (Bool.to_string passed));
                   if passed then None
                   else
                     Some
                       {
                         Terrat_vcs_provider2.Gate_eval.dirspace =
                           (if
                              Terrat_dirspace.equal
                                dirspace
                                { Terrat_dirspace.dir = ""; workspace = "" }
                            then None
                            else Some dirspace);
                         token;
                         name;
                         result;
                       })
                 gates)
             gates_map)
      in
      let open Abb.Future.Infix_monad in
      run
      >>= function
      | Ok res -> Abbs_future_combinators.return_ok res
      | Error (#Pgsql_io.err as err) ->
          Logs.err (fun m -> m "%s : %a" request_id Pgsql_io.pp_err err);
          Abbs_future_combinators.return_err `Error
      | Error (`Vcs_api_timeout_err operation) ->
          Logs.err (fun m -> m "%s : VCS_API_TIMEOUT : %s" request_id operation);
          Abbs_future_combinators.return_err `Error
      | Error `Error ->
          Logs.err (fun m -> m "%s" request_id);
          Abbs_future_combinators.return_err `Error
  end

  module Work_manifest = Terrat_vcs_service_github_provider.Work_manifest

  module Repo_config = struct
    let fetch_repo_config_file request_id client repo ref_ basename =
      let open Abbs_future_combinators.Infix_result_monad in
      Abbs_future_combinators.Infix_result_app.(
        (fun yml yaml ->
          match (yml, yaml) with
          | Some yml, _ ->
              Some
                ( Api.Repo.to_string repo ^ ":" ^ Api.Ref.to_string ref_ ^ ":" ^ basename ^ ".yml",
                  yml )
          | _, Some yaml ->
              Some
                ( Api.Repo.to_string repo ^ ":" ^ Api.Ref.to_string ref_ ^ ":" ^ basename ^ ".yaml",
                  yaml )
          | _, _ -> None)
        <$> Api.fetch_file ~request_id client repo ref_ (basename ^ ".yml")
        <*> Api.fetch_file ~request_id client repo ref_ (basename ^ ".yaml"))
      >>= function
      | None -> Abbs_future_combinators.return_ok None
      | Some (_, content) when CCString.is_empty (CCString.trim content) ->
          Abbs_future_combinators.return_ok None
      | Some (fname, content) ->
          Abb.Future.return
          @@ CCResult.map_err
               (fun (`Yaml_decode_err err) -> `Yaml_decode_err (fname, err))
               (Jsonu.of_yaml_string content)
          >>= fun json -> Abbs_future_combinators.return_ok (Some (fname, json))

    (* Config parity (#1442): [.stategraph/config] wins when both exist;
       [.terrateam/config] keeps working so existing repos need no rename. *)
    let fetch_repo_config_file_with_fallback request_id client repo ref_ =
      let open Abbs_future_combinators.Infix_result_monad in
      fetch_repo_config_file request_id client repo ref_ ".stategraph/config"
      >>= function
      | Some _ as r -> Abb.Future.return (Ok r)
      | None -> fetch_repo_config_file request_id client repo ref_ ".terrateam/config"

    let maybe_fetch_centralized_repo_config_file request_id client centralized_repo basename =
      match centralized_repo with
      | Some (remote_repo, branch) ->
          fetch_repo_config_file
            request_id
            client
            (Api.Remote_repo.to_repo remote_repo)
            branch
            basename
      | None -> Abbs_future_combinators.return_ok None

    let maybe_fetch_centralized_repo_default_branch_sha request_id client centralized_repo =
      match centralized_repo with
      | Some remote_repo -> (
          let open Abbs_future_combinators.Infix_result_monad in
          Api.fetch_branch_sha
            ~request_id
            client
            (Api.Remote_repo.to_repo remote_repo)
            (Api.Remote_repo.default_branch remote_repo)
          >>= function
          | Some branch_sha -> Abbs_future_combinators.return_ok (Some (remote_repo, branch_sha))
          | None -> Abbs_future_combinators.return_ok None)
      | None -> Abbs_future_combinators.return_ok None

    let fetch_with_provenance ?system_defaults ?built_config request_id client repo ref_ =
      let open Abbs_future_combinators.Infix_result_monad in
      Abbs_future_combinators.Infix_result_app.(
        (fun remote_repo centralized_repo -> (remote_repo, centralized_repo))
        <$> Api.fetch_remote_repo ~request_id client repo
        <*> Api.fetch_centralized_repo ~request_id client (Api.Repo.owner repo))
      >>= fun (remote_repo, centralized_repo) ->
      Abbs_future_combinators.Infix_result_app.(
        (fun default_branch_sha centralized_repo -> (default_branch_sha, centralized_repo))
        <$> Api.fetch_branch_sha
              ~request_id
              client
              (Api.Remote_repo.to_repo remote_repo)
              (Api.Remote_repo.default_branch remote_repo)
        <*> maybe_fetch_centralized_repo_default_branch_sha request_id client centralized_repo)
      >>= fun (default_branch_sha, centralized_repo) ->
      let default_branch_ref =
        CCOption.get_or ~default:(Api.Remote_repo.default_branch remote_repo) default_branch_sha
      in
      Abbs_future_combinators.Infix_result_app.(
        (fun global_default
             global_overrides
             repo_defaults
             repo_overrides
             repo_forced_config
             default_repo_config
             repo_config
           ->
          ( global_default,
            global_overrides,
            repo_defaults,
            repo_overrides,
            repo_forced_config,
            default_repo_config,
            repo_config ))
        <$> maybe_fetch_centralized_repo_config_file
              request_id
              client
              centralized_repo
              "config/defaults"
        <*> maybe_fetch_centralized_repo_config_file
              request_id
              client
              centralized_repo
              "config/overrides"
        <*> maybe_fetch_centralized_repo_config_file
              request_id
              client
              centralized_repo
              ("config/" ^ Api.Repo.name repo ^ "/defaults")
        <*> maybe_fetch_centralized_repo_config_file
              request_id
              client
              centralized_repo
              ("config/" ^ Api.Repo.name repo ^ "/overrides")
        <*> maybe_fetch_centralized_repo_config_file
              request_id
              client
              centralized_repo
              ("config/" ^ Api.Repo.name repo ^ "/config")
        <*> fetch_repo_config_file_with_fallback request_id client repo default_branch_ref
        <*> fetch_repo_config_file_with_fallback request_id client repo ref_)
      >>= fun ( global_defaults,
                global_overrides,
                repo_defaults,
                repo_overrides,
                repo_forced_config,
                default_repo_config,
                repo_config )
            ->
      let wrap_err fname =
        Abbs_future_combinators.Result.map_err ~f:(function
          | `Repo_config_schema_err err -> `Repo_config_schema_err (fname, err)
          | #Terrat_base_repo_config_v1.of_version_1_err as err -> err)
      in
      let validate_configs =
        Abbs_future_combinators.List_result.iter ~f:(function
          | Some (fname, json) ->
              wrap_err fname (Abb.Future.return (Terrat_base_repo_config_v1.of_version_1_json json))
              >>= fun _ -> Abbs_future_combinators.return_ok ()
          | None -> Abbs_future_combinators.return_ok ())
      in
      let get_json = function
        | None -> `Assoc []
        | Some (_, json) -> json
      in
      let get_fname = CCOption.map (fun (fname, _) -> fname) in
      let collect_provenance =
        CCList.filter_map (function
          | Some (fname, _) -> Some fname
          | None -> None)
      in
      (* Merge one configuration layer on top of another. Lists are joined with
         [`Prepend_dedup]: an entry the override already carries is not taken from the base as
         well, so a hook or a workflow declared both in the repository configuration and in the
         output of the config builder is kept once. *)
      let merge ~base v =
        CCResult.map_err
          (fun (`Type_mismatch_err err) ->
            `Config_merge_err
              ( ( CCOption.get_or ~default:"" (get_fname base),
                  CCOption.get_or ~default:"" (get_fname v) ),
                err ))
          (CCResult.map
             (fun r ->
               Some
                 ( Printf.sprintf
                     "%s,%s"
                     (CCOption.get_or ~default:"" (get_fname base))
                     (CCOption.get_or ~default:"" (get_fname v)),
                   r ))
             (Jsonu.merge ~list:`Prepend_dedup ~base:(get_json base) (get_json v)))
      in
      let system_defaults =
        CCOption.map
          (fun config ->
            ( "system_defaults",
              Terrat_repo_config.Version_1.to_yojson
                (Terrat_base_repo_config_v1.to_version_1 config) ))
          system_defaults
      in
      let built_config = CCOption.map (fun config -> ("config_builder", config)) built_config in
      match
        (repo_defaults, repo_overrides, repo_forced_config, default_repo_config, repo_config)
      with
      | repo_defaults, repo_overrides, None, default_repo_config, repo_config ->
          let provenance =
            collect_provenance
              [
                system_defaults;
                global_defaults;
                global_overrides;
                repo_defaults;
                repo_overrides;
                default_repo_config;
                built_config;
                repo_config;
              ]
          in
          validate_configs
            [
              system_defaults;
              global_defaults;
              global_overrides;
              repo_defaults;
              repo_overrides;
              default_repo_config;
              built_config;
              repo_config;
            ]
          >>= fun () ->
          Abb.Future.return (merge ~base:system_defaults global_defaults)
          >>= fun global_defaults ->
          Abb.Future.return (merge ~base:global_defaults repo_defaults)
          >>= fun repo_defaults ->
          Abb.Future.return (merge ~base:repo_defaults default_repo_config)
          >>= fun default_repo_config ->
          Abb.Future.return (merge ~base:default_repo_config global_overrides)
          >>= fun default_repo_config ->
          Abb.Future.return (merge ~base:default_repo_config repo_overrides)
          >>= fun default_repo_config ->
          Abb.Future.return (merge ~base:repo_defaults built_config)
          >>= fun built_config ->
          Abb.Future.return (merge ~base:built_config repo_config)
          >>= fun repo_config ->
          Abb.Future.return (merge ~base:repo_config global_overrides)
          >>= fun repo_config ->
          Abb.Future.return (merge ~base:repo_config repo_overrides)
          >>= fun repo_config ->
          Abbs_future_combinators.Infix_result_app.(
            (fun default_repo_config repo_config -> (default_repo_config, repo_config))
            <$> wrap_err
                  "default"
                  (Abb.Future.return
                     (Terrat_base_repo_config_v1.of_version_1_json (get_json default_repo_config)))
            <*> wrap_err
                  "repo"
                  (Abb.Future.return
                     (Terrat_base_repo_config_v1.of_version_1_json (get_json repo_config))))
          >>= fun (default_repo_config, repo_config) ->
          Abbs_future_combinators.return_ok
            ( provenance,
              Terrat_base_repo_config_v1.merge_with_default_branch_config
                ~default:default_repo_config
                repo_config )
      | _, _, (Some (_, _) as forced_repo_config), _, _ ->
          let provenance =
            collect_provenance
              [ system_defaults; global_defaults; built_config; forced_repo_config ]
          in
          validate_configs [ system_defaults; global_defaults; built_config; forced_repo_config ]
          >>= fun () ->
          Abb.Future.return (merge ~base:system_defaults global_defaults)
          >>= fun global_defaults ->
          Abb.Future.return (merge ~base:global_defaults built_config)
          >>= fun repo_config ->
          Abb.Future.return (merge ~base:repo_config forced_repo_config)
          >>= fun repo_config ->
          wrap_err
            "repo"
            (Abb.Future.return
               (Terrat_base_repo_config_v1.of_version_1_json (get_json repo_config)))
          >>= fun repo_config -> Abbs_future_combinators.return_ok (provenance, repo_config)
  end

  module Access_control = struct
    let query ~request_id client repo user = match_user ~request_id client repo user

    let is_ci_changed ~request_id client repo diff =
      let run =
        let open Abbs_future_combinators.Infix_result_monad in
        Api.find_workflow_file ~request_id repo client
        >>= function
        | Some path ->
            let diff_paths =
              CCList.flat_map
                (function
                  | Terrat_change.Diff.(
                      Add { filename } | Change { filename } | Remove { filename }) -> [ filename ]
                  | Terrat_change.Diff.Move { filename; previous_filename } ->
                      [ filename; previous_filename ])
                diff
            in
            Abbs_future_combinators.return_ok (CCList.mem ~eq:CCString.equal path diff_paths)
        | None -> Abbs_future_combinators.return_ok false
      in
      let open Abb.Future.Infix_monad in
      run
      >>= function
      | Ok _ as ret -> Abb.Future.return ret
      | Error _ -> Abbs_future_combinators.return_err `Error
  end

  module Commit_check = Terrat_vcs_service_github_provider.Commit_check
  module Ui = Terrat_vcs_service_github_provider.Ui
  module Comment = Terrat_vcs_service_github_provider.Comment
  module Job_context = Terrat_vcs_service_github_provider.Job_context
  module Stacks = Terrat_vcs_service_github_provider.Stacks
end

module Routes = struct
  type config = Provider.Api.Config.t

  module Ep_access_token =
    Terrat_vcs_access_token.Make
      (Provider)
      (struct
        let vcs = "github"
      end)

  let routes config storage = Ep_access_token.routes config storage
end

include Terrat_vcs_service_github.Make (Provider) (Routes)
