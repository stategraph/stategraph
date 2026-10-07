module License = Sgs_service_license.Make (Sgs_service_license_oss)
module Auth = Sgs_service_auth.Make (Sgs_cloud_oss)
module Tenants = Sgs_service_tenants.Make (Sgs_cloud_oss)
module Cli = Sgs_cli_lib.Make (Sgs_cloud_oss)

let () =
  Cli.main
    ~services:
      [
        (module License);
        (module Sgs_service_caps);
        (module Sgs_service_users);
        (module Tenants);
        (module Sgs_service_orchestration);
        (module Auth);
      ]
