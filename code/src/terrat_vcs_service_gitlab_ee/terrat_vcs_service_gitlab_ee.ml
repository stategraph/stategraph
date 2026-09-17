module Provider : module type of Terrat_vcs_service_gitlab_provider = struct
  let name = Terrat_vcs_service_gitlab_provider.name
  let enforce_installation_access = Terrat_vcs_service_gitlab_provider.enforce_installation_access

  module Api = Terrat_vcs_api_gitlab
  module Unlock_id = Terrat_vcs_service_gitlab_provider.Unlock_id
  module Db = Terrat_vcs_service_gitlab_provider.Db
  module Apply_requirements = Terrat_vcs_service_gitlab_provider.Apply_requirements
  module Tier = Terrat_vcs_service_gitlab_provider.Tier
  module Tier_capped = Terrat_vcs_service_gitlab_provider.Tier_capped

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

  module Gate = Terrat_vcs_service_gitlab_provider.Gate
  module Work_manifest = Terrat_vcs_service_gitlab_provider.Work_manifest

  module Repo_config = struct
    module Rc = Terrat_vcs_service_gitlab_repo_config

    let maybe_fetch_centralized_repo_config_file request_id client centralized_repo basename =
      match centralized_repo with
      | Some (remote_repo, branch) ->
          Rc.fetch_config ~request_id client (Api.Remote_repo.to_repo remote_repo) branch basename
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
          >>| function
          | Some branch_sha -> Some (remote_repo, branch_sha)
          | None -> None)
      | None -> Abbs_future_combinators.return_ok None

    module Brand =
      Terrat_vcs_provider2.Brand.Make
        (Api)
        (struct
          let provider = "gitlab_ee"
        end)

    let centralized ~request_id client repo =
      let open Abbs_future_combinators.Infix_result_monad in
      Api.fetch_centralized_repo ~request_id client (Api.Repo.owner repo)
      >>= fun centralized_repo ->
      maybe_fetch_centralized_repo_default_branch_sha request_id client centralized_repo
      >>= function
      | None -> Abbs_future_combinators.return_ok (None, None)
      | Some (remote_repo, branch) ->
          let centralized_repo = Api.Remote_repo.to_repo remote_repo in
          Rc.fetch_config_path
            ~request_id
            client
            centralized_repo
            branch
            ("config/" ^ Api.Repo.name repo ^ "/config")
          >>| fun forced_config ->
          let brand = Terrat_brand.of_repo_name (Api.Repo.name centralized_repo) in
          ((if CCOption.is_some forced_config then brand else None), brand)

    let fetch_brand ~request_id client repo =
      Brand.fetch
        ~request_id
        ~fetch_branch_sha:(Api.fetch_branch_sha ~request_id)
        ~config_brand:(Rc.fetch_config_brand ~request_id)
        ~centralized:(centralized ~request_id)
        client
        repo

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
        <*> Rc.fetch ~request_id client repo default_branch_ref
        <*> Rc.fetch ~request_id client repo ref_)
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
              >>| fun _ -> ()
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
          >>| fun (default_repo_config, repo_config) ->
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
          >>| fun repo_config -> (provenance, repo_config)
  end

  module Access_control = struct
    let query ~request_id client repo user = match_user ~request_id client repo user

    let is_ci_changed ~request_id client repo diff =
      let run =
        let open Abbs_future_combinators.Infix_result_monad in
        Api.find_workflow_file ~request_id repo client
        >>| function
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
            CCList.mem ~eq:CCString.equal path diff_paths
        | None -> false
      in
      let open Abb.Future.Infix_monad in
      run
      >>= function
      | Ok _ as ret -> Abb.Future.return ret
      | Error _ -> Abbs_future_combinators.return_err `Error
  end

  module Comment = Terrat_vcs_service_gitlab_provider.Comment
  module Commit_check = Terrat_vcs_service_gitlab_provider.Commit_check
  module Ui = Terrat_vcs_service_gitlab_provider.Ui
  module Job_context = Terrat_vcs_service_gitlab_provider.Job_context
  module Stacks = Terrat_vcs_service_gitlab_provider.Stacks
end

module Routes = struct
  type config = Provider.Api.Config.t

  module Ep_access_token =
    Terrat_vcs_access_token.Make
      (Provider)
      (struct
        let vcs = "gitlab"
      end)

  let routes config storage = Ep_access_token.routes config storage
end

include Terrat_vcs_service_gitlab.Make (Provider) (Routes)
