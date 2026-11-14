module Aliases = struct
  include
    Json_schema.Additional_properties.Make
      (Json_schema.Empty_obj)
      (Terrat_repo_config_parameter_alias)
end

module Names = struct
  include
    Json_schema.Additional_properties.Make
      (Json_schema.Empty_obj)
      (Terrat_repo_config_parameter_name)
end

type t = {
  aliases : Aliases.t option; [@default None]
  names : Names.t option; [@default None]
}
[@@deriving yojson { strict = true; meta = true }, make, show, eq]
