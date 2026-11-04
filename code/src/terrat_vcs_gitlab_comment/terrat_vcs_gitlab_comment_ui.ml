module Ui = struct
  (* GitLab has no console run pages, so the brand selects nothing. *)
  let work_manifest_url ~brand:_ _config _account _pull_request_ref _work_manifest = None

  let subscription_url ~brand config =
    let base =
      Uri.to_string (Terrat_config.web_base_url (Terrat_vcs_api_gitlab.Config.config config) brand)
    in
    let suffix =
      match brand with
      | Terrat_brand.Stategraph -> "/settings/"
      | Terrat_brand.Terrateam -> "/#/subscription"
    in
    Uri.of_string (base ^ suffix)
end
