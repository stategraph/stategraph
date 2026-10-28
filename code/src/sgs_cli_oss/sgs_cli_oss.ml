module License = Sgs_service_license.Make (Sgs_service_license_oss) (Sgs_cloud_oss)
module Auth = Sgs_service_auth.Make (Sgs_cloud_oss)
module Tenants = Sgs_service_tenants.Make (Sgs_cloud_oss)
module Config = Sgs_service_config.Make (Sgs_cloud_oss)
module Terrat_github = Sgs_service_terrat_vcs.Make_github (Terrat_vcs_service_github_oss)
module Terrat_gitlab = Sgs_service_terrat_vcs.Make_gitlab (Terrat_vcs_service_gitlab_oss)
module Terrat_ui = Sgs_service_terrat_ui.Make (Terrat_github) (Terrat_gitlab)

let () =
  Sgs_cli_lib.main
    ~orchestration_services:
      [
        (module Sgs_service_terrat_config);
        (module Sgs_service_terrat_exec);
        (module Sgs_service_terrat_session);
        (module Sgs_service_terrat_api);
        (module Terrat_github);
        (module Terrat_gitlab);
        (module Terrat_ui);
      ]
    ~services:
      [
        (module Config);
        (module License);
        (module Sgs_service_caps);
        (module Sgs_service_users);
        (module Tenants);
        (module Sgs_service_orchestration);
        (module Auth);
        (module Sgs_service_scheduler);
      ]
