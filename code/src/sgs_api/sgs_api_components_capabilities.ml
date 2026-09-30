type t = {
  costs : Sgs_api_components_costs_availability.t;
  dedicated : Sgs_api_components_dedicated_availability.t;
  github_app : Sgs_api_components_github_app_availability.t;
  github_app_url : string option; [@default None]
  orchestration : Sgs_api_components_orchestration_availability.t;
  security : Sgs_api_components_security_availability.t;
}
[@@deriving yojson { strict = false; meta = true }, show, eq]
