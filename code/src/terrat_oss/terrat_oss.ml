module Github = Terrat_vcs_service_github_oss.Make (Terrat_stategraph.Standalone)
module Gitlab = Terrat_vcs_service_gitlab_oss.Make (Terrat_stategraph.Standalone)
include Terrat_cli.Make (Github) (Gitlab)
