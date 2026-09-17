module Api = Terrat_vcs_api_gitlab

let non_blank path content =
  if CCString.is_empty (CCString.trim content) then None else Some (path, content)

let fetch_content ~request_id client repo ref_ basename =
  let open Abbs_future_combinators.Infix_result_monad in
  let yml = basename ^ ".yml" in
  let yaml = basename ^ ".yaml" in
  Abbs_future_combinators.Result.all2
    (Api.fetch_file ~request_id client repo ref_ yml)
    (Api.fetch_file ~request_id client repo ref_ yaml)
  >>| function
  | Some content, _ -> non_blank yml content
  | None, Some content -> non_blank yaml content
  | None, None -> None

let decode repo ref_ = function
  | None -> Abbs_future_combinators.return_ok None
  | Some (path, content) ->
      let open Abbs_future_combinators.Infix_result_monad in
      let fname = Api.Repo.to_string repo ^ ":" ^ Api.Ref.to_string ref_ ^ ":" ^ path in
      Abb.Future.return
      @@ CCResult.map_err
           (fun (`Yaml_decode_err err) -> `Yaml_decode_err (fname, err))
           (Jsonu.of_yaml_string content)
      >>| fun json -> Some (fname, json)

let fetch_config ~request_id client repo ref_ basename =
  let open Abbs_future_combinators.Infix_result_monad in
  fetch_content ~request_id client repo ref_ basename >>= decode repo ref_

let fetch_config_path ~request_id client repo ref_ basename =
  let open Abbs_future_combinators.Infix_result_monad in
  fetch_content ~request_id client repo ref_ basename >>| CCOption.map fst

let config_basename brand = Terrat_brand.directory brand ^ "/config"

(* Config parity (#1442): the configuration of the brand that comes first wins;
   the other one keeps working so existing repos need no rename. *)
let find ~request_id client repo ref_ =
  let open Abbs_future_combinators.Infix_result_monad in
  let rec first = function
    | [] -> Abbs_future_combinators.return_ok None
    | brand :: brands -> (
        fetch_content ~request_id client repo ref_ (config_basename brand)
        >>= function
        | Some content -> Abbs_future_combinators.return_ok (Some (brand, content))
        | None -> first brands)
  in
  first Terrat_brand.all

let fetch ~request_id client repo ref_ =
  let open Abbs_future_combinators.Infix_result_monad in
  find ~request_id client repo ref_ >>= fun found -> decode repo ref_ (CCOption.map snd found)

let fetch_config_brand ~request_id client repo ref_ =
  let open Abbs_future_combinators.Infix_result_monad in
  find ~request_id client repo ref_ >>| CCOption.map fst
