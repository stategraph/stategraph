module Provider :
  Terrat_vcs_provider2_github.S
    with type Api.Config.t = Terrat_vcs_service_github_provider.Api.Config.t = struct
  let name = Terrat_vcs_service_github_provider.name
  let enforce_installation_access = Terrat_vcs_service_github_provider.enforce_installation_access

  module Api = Terrat_vcs_api_github
  module Unlock_id = Terrat_vcs_service_github_provider.Unlock_id
  module Db = Terrat_vcs_service_github_provider.Db
  module Apply_requirements = Terrat_vcs_service_github_provider.Apply_requirements

  (* The oss build clamps every installation's tier to the Open Source caps
     ([Terrat_tier.oss]); the ee build links the uncapped [Tier]. Nothing but
     this line turns the cap on. *)
  module Tier = Terrat_vcs_service_github_provider.Tier_capped
  module Gate = Terrat_vcs_service_github_provider.Gate
  module Work_manifest = Terrat_vcs_service_github_provider.Work_manifest
  module Repo_config = Terrat_vcs_service_github_provider.Repo_config
  module Access_control = Terrat_vcs_service_github_provider.Access_control
  module Comment = Terrat_vcs_service_github_provider.Comment
  module Commit_check = Terrat_vcs_service_github_provider.Commit_check
  module Ui = Terrat_vcs_service_github_provider.Ui
  module Job_context = Terrat_vcs_service_github_provider.Job_context
  module Stacks = Terrat_vcs_service_github_provider.Stacks
end

include
  Terrat_vcs_service_github.Make
    (Provider)
    (struct
      type config = Provider.Api.Config.t

      let routes _ _ = []
    end)
