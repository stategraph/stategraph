module Fp = Terrat_base_repo_config_v1.File_pattern

let is_negation = CCString.prefix ~pre:"!"

(* [body_matches] answers one question for both kinds of entry: does the entry match [value] with
   its [!] removed.  A negation is thus a positive test that the caller reads backwards, which is
   what lets the two kinds of list share this fold.

   The implicit ['*'] is a branch and not an entry that the list gets, because the glob that spells
   it differs with the kind of the entry, and a glob that does not cross a [/] would not spell it at
   all. *)
let match_list ~body_matches ~negate entries value =
  let negations, positives = CCList.partition negate entries in
  let no_negation_refuses =
    CCList.for_all (fun entry -> not (body_matches entry value)) negations
  in
  match (negations, positives) with
  | _ :: _, [] -> no_negation_refuses
  | _, positives ->
      CCList.exists (fun entry -> body_matches entry value) positives && no_negation_refuses

let match_user ~users = function
  | None -> true
  | Some user ->
      match_list
        ~body_matches:(fun entry value ->
          CCString.equal (if is_negation entry then CCString.drop 1 entry else entry) value)
        ~negate:is_negation
        users
        user

let match_file_patterns ~files file_patterns =
  (* [Fp.is_match] gives the answer a negated pattern already inverts, thus the body match is its
     negation again. *)
  let body_matches fp file =
    if Fp.is_negate fp then not (Fp.is_match fp file) else Fp.is_match fp file
  in
  CCList.exists (match_list ~body_matches ~negate:Fp.is_negate file_patterns) files

let changes_repo_config = CCList.exists Terrat_repo_config_file.mem

let match_derived_config ~diff repo_config_json =
  let module V1 = Terrat_base_repo_config_v1 in
  let open CCResult.Infix in
  V1.of_version_1_json_derived repo_config_json
  >>= (fun config -> Terrat_change_match3.synthesize_config ~index:V1.Index.empty config)
  >|= (fun config -> Terrat_change_match3.match_diff_list config diff)
  |> CCResult.to_opt
  |> CCOption.map CCFun.(CCList.flatten %> CCList.is_empty %> not)
