module type Shared =
  Terrat_vcs_provider2.Shared
    with type Api.Account.Id.t = int
     and type Api.Account.t = Terrat_vcs_api_github.Account.t
     and type Api.Config.t = Terrat_vcs_api_github.Config.t
     and type Api.Config.vcs_config = Terrat_vcs_api_github.Config.vcs_config
     and type Api.User.Id.t = string
     and type Api.User.t = Terrat_vcs_api_github.User.t
     and type Api.Pull_request.Id.t = int
     and type Api.Repo.Id.t = int
     and type Api.Repo.t = Terrat_vcs_api_github.Repo.t
     and type Api.Ref.t = Terrat_vcs_api_github.Ref.t
     and type Api.Client.t = Terrat_vcs_api_github.Client.t

module type S = sig
  include Shared
  include Terrat_vcs_provider2.Edition
  module Stategraph : Terrat_stategraph.S
end
