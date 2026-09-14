module Provider : Terrat_vcs_provider2_gitlab.S = struct
  let name = Terrat_vcs_service_gitlab_provider.name
  let enforce_installation_access = Terrat_vcs_service_gitlab_provider.enforce_installation_access

  module Api = Terrat_vcs_api_gitlab
  module Unlock_id = Terrat_vcs_service_gitlab_provider.Unlock_id
  module Db = Terrat_vcs_service_gitlab_provider.Db
  module Apply_requirements = Terrat_vcs_service_gitlab_provider.Apply_requirements

  (* The oss build clamps every installation's tier to the Open Source caps
     ([Terrat_tier.oss]); the ee build links the uncapped [Tier]. Nothing but
     this line turns the cap on. *)
  module Tier = Terrat_vcs_service_gitlab_provider.Tier_capped
  module Gate = Terrat_vcs_service_gitlab_provider.Gate
  module Work_manifest = Terrat_vcs_service_gitlab_provider.Work_manifest
  module Repo_config = Terrat_vcs_service_gitlab_provider.Repo_config
  module Access_control = Terrat_vcs_service_gitlab_provider.Access_control
  module Comment = Terrat_vcs_service_gitlab_provider.Comment
  module Commit_check = Terrat_vcs_service_gitlab_provider.Commit_check
  module Ui = Terrat_vcs_service_gitlab_provider.Ui
  module Job_context = Terrat_vcs_service_gitlab_provider.Job_context
  module Stacks = Terrat_vcs_service_gitlab_provider.Stacks
end

include
  Terrat_vcs_service_gitlab.Make
    (Provider)
    (struct
      type config = Provider.Api.Config.t

      let routes _ _ = []
    end)
