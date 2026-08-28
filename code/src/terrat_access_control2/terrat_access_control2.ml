type query_err = [ `Error ] [@@deriving show]
type err = query_err [@@deriving show]

(* Both spellings of the repo config file, in both extensions the providers
   probe. [.stategraph/config] takes precedence over [.terrateam/config] at
   read time (see [fetch_repo_config_file_with_fallback] in the VCS services),
   so a change to EITHER must count as a repo-config change for the
   [access_control.terrateam_config_update] policy. *)
let repo_config_files =
  [
    ".stategraph/config.yml";
    ".stategraph/config.yaml";
    ".terrateam/config.yml";
    ".terrateam/config.yaml";
  ]

let repo_config_files_mem searched = Sln_list.String.mem searched repo_config_files

let is_repo_config_change =
  CCList.exists
    Terrat_change.Diff.(
      function
      | Add { filename } | Change { filename } | Remove { filename } ->
          repo_config_files_mem filename
      | Move { filename; previous_filename } ->
          repo_config_files_mem filename || repo_config_files_mem previous_filename)

module Policy = struct
  type t = {
    tag_query : Terrat_tag_query.t;
    policy : Terrat_base_repo_config_v1.Access_control.Match_list.t;
  }
  [@@deriving show]
end

module R = struct
  module Deny = struct
    type t = {
      change_match : Terrat_change_match3.Dirspace_config.t;
      policy : Terrat_base_repo_config_v1.Access_control.Match_list.t option;
    }
    [@@deriving show]
  end

  type t = {
    pass : Terrat_change_match3.Dirspace_config.t list;
    deny : Deny.t list;
  }
  [@@deriving show]
end

module type S = sig
  type client
  type repo

  val query :
    request_id:string ->
    client ->
    repo ->
    string ->
    Terrat_base_repo_config_v1.Access_control.Match.t ->
    (bool, [> query_err ]) result Abb.Future.t

  val is_ci_changed :
    request_id:string ->
    client ->
    repo ->
    Terrat_change.Diff.t list ->
    (bool, [> err ]) result Abb.Future.t
end

module Make (S : S) = struct
  module Ctx = struct
    type t = {
      request_id : string;
      client : S.client;
      config : Terrat_config.t;
      repo : S.repo;
      user : string;
    }
    [@@warning "-69"]

    let make ~request_id ~client ~config ~repo ~user () = { request_id; client; config; repo; user }
    let set_user user t = { t with user }
  end

  let rec test_queries ctx = function
    | [] -> Abbs_future_combinators.return_ok None
    | q :: qs -> (
        let open Abbs_future_combinators.Infix_result_monad in
        S.query ~request_id:ctx.Ctx.request_id ctx.Ctx.client ctx.Ctx.repo ctx.Ctx.user q
        >>= function
        | true -> Abbs_future_combinators.return_ok (Some q)
        | false -> test_queries ctx qs)

  let eval_ci_change ctx ci_config_change diff =
    let open Abbs_future_combinators.Infix_result_monad in
    S.is_ci_changed ~request_id:ctx.Ctx.request_id ctx.Ctx.client ctx.Ctx.repo diff
    >>= function
    | true -> test_queries ctx ci_config_change >>| fun res -> CCOption.is_some res
    | false -> Abbs_future_combinators.return_ok true

  let eval_files ctx files_policy diff =
    let files =
      CCList.flat_map
        (function
          | Terrat_change.Diff.(Add { filename } | Change { filename } | Remove { filename }) ->
              [ filename ]
          | Terrat_change.Diff.Move { filename; previous_filename } ->
              [ filename; previous_filename ])
        diff
    in
    let matching_files =
      Sln_map.String.filter (fun key _ -> CCList.mem ~eq:CCString.equal key files) files_policy
    in
    let open Abb.Future.Infix_monad in
    Abbs_future_combinators.List_result.iter
      ~f:(fun (fname, policy) ->
        let open Abbs_future_combinators.Infix_result_monad in
        test_queries ctx policy
        >>? function
        | Some _ -> Ok ()
        | None -> Error (`Denied (fname, policy)))
      (Sln_map.String.to_list matching_files)
    >>= function
    | Ok () -> Abbs_future_combinators.return_ok `Ok
    | Error (`Denied _ as ret) -> Abbs_future_combinators.return_ok ret
    | Error (#query_err as err) -> Abbs_future_combinators.return_err err

  let eval_repo_config ctx terrateam_config_change diff =
    let open Abbs_future_combinators.Infix_result_monad in
    if is_repo_config_change diff then
      test_queries ctx terrateam_config_change >>| fun res -> CCOption.is_some res
    else Abbs_future_combinators.return_ok true

  let eval ctx policies change_matches =
    Abbs_future_combinators.List_result.fold_left
      ~f:(fun (R.{ pass; deny } as r) change ->
        match
          CCList.find_opt
            (fun Policy.{ tag_query; _ } -> Terrat_change_match3.match_tag_query ~tag_query change)
            policies
        with
        | Some Policy.{ policy; _ } -> (
            let open Abbs_future_combinators.Infix_result_monad in
            test_queries ctx policy
            >>| function
            | Some _ -> R.{ r with pass = change :: pass }
            | None ->
                R.{ r with deny = Deny.{ change_match = change; policy = Some policy } :: deny })
        | None ->
            Abbs_future_combinators.return_ok
              R.{ r with deny = Deny.{ change_match = change; policy = None } :: deny })
      ~init:R.{ pass = []; deny = [] }
      change_matches

  let eval_match_list ctx match_list =
    let open Abbs_future_combinators.Infix_result_monad in
    test_queries ctx match_list >>| fun res -> CCOption.is_some res
end

module Tests = struct
  let repo_config_files = repo_config_files
  let is_repo_config_change = is_repo_config_change
end
