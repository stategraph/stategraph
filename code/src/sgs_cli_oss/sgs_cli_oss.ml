module License = Sgs_service_license.Make (Sgs_service_license_oss)
module Auth = Sgs_service_auth.Make (Sgs_cloud_oss)
module Tenants = Sgs_service_tenants.Make (Sgs_cloud_oss)
module Setup = Sgs_service_setup.Make (Sgs_cloud_oss)
module Config = Sgs_service_config.Make (Sgs_cloud_oss)

let () =
  Sgs_cli_lib.main
    ~services:
      [
        (module Config);
        (module License);
        (module Setup);
        (module Sgs_service_caps);
        (module Sgs_service_users);
        (module Tenants);
        (module Sgs_service_orchestration);
        (module Auth);
      ]
