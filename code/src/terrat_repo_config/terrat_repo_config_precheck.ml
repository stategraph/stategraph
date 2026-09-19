type t =
  | Precheck_user of Terrat_repo_config_precheck_user.t
  | Precheck_file_patterns of Terrat_repo_config_precheck_file_patterns.t
  | Precheck_config_file_patterns of Terrat_repo_config_precheck_config_file_patterns.t
[@@deriving show, eq]

let of_yojson =
  Json_schema.one_of
    (let open CCResult in
     [
       (fun v -> map (fun v -> Precheck_user v) (Terrat_repo_config_precheck_user.of_yojson v));
       (fun v ->
         map
           (fun v -> Precheck_file_patterns v)
           (Terrat_repo_config_precheck_file_patterns.of_yojson v));
       (fun v ->
         map
           (fun v -> Precheck_config_file_patterns v)
           (Terrat_repo_config_precheck_config_file_patterns.of_yojson v));
     ])

let to_yojson = function
  | Precheck_user v -> Terrat_repo_config_precheck_user.to_yojson v
  | Precheck_file_patterns v -> Terrat_repo_config_precheck_file_patterns.to_yojson v
  | Precheck_config_file_patterns v -> Terrat_repo_config_precheck_config_file_patterns.to_yojson v
