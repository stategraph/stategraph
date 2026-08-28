module Tcm = Terrat_change_match3

module Dirspace_state = struct
  type t = {
    dirspace : Terrat_dirspace.t;
    state : Terrat_api_components.Stack_state.t;
  }
  [@@deriving show, eq]
end

module type M = sig
  module Installation_id : Terrat_vcs_api.ID
  module Repo_id : Terrat_vcs_api.ID
  module Pull_request_id : Terrat_vcs_api.ID
  module Config : Terrat_vcs_api.CONFIG

  type db

  val vcs : string
  val route_root : unit -> ('a, 'a) Brtl_rtng.Route.t

  val store_stacks :
    request_id:string ->
    installation_id:Installation_id.t ->
    repo_id:Repo_id.t ->
    pull_request_id:Pull_request_id.t ->
    Terrat_api_components.Stacks.t ->
    db ->
    (unit, [> `Error ]) result Abb.Future.t

  val query_stacks :
    request_id:string ->
    installation_id:Installation_id.t ->
    repo_id:Repo_id.t ->
    pull_request_id:Pull_request_id.t ->
    db ->
    (Terrat_api_components.Stacks.t option, [> `Error ]) result Abb.Future.t

  val query_dirspace_states :
    request_id:string ->
    installation_id:Installation_id.t ->
    repo_id:Repo_id.t ->
    pull_request_id:Pull_request_id.t ->
    db ->
    (Dirspace_state.t list, [> `Error ]) result Abb.Future.t

  val enforce_installation_access :
    request_id:string ->
    Terrat_user.t ->
    Installation_id.t ->
    Pgsql_io.t ->
    (unit, [> `Forbidden ]) result Abb.Future.t
end

module type S = sig
  module Installation_id : Terrat_vcs_api.ID
  module Repo_id : Terrat_vcs_api.ID
  module Pull_request_id : Terrat_vcs_api.ID
  module Config : Terrat_vcs_api.CONFIG

  type db

  val store :
    request_id:string ->
    installation_id:Installation_id.t ->
    repo_id:Repo_id.t ->
    pull_request_id:Pull_request_id.t ->
    Terrat_change_match3.Config.t ->
    db ->
    (unit, [> `Error ]) result Abb.Future.t

  val query :
    request_id:string ->
    installation_id:Installation_id.t ->
    repo_id:Repo_id.t ->
    pull_request_id:Pull_request_id.t ->
    db ->
    (Terrat_api_components.Stacks.t option, [> `Error ]) result Abb.Future.t

  val routes :
    Config.t ->
    Terrat_storage.t ->
    (Brtl_rtng.Method.t * Brtl_rtng.Handler.t Brtl_rtng.Route.Route.t) list
end

module Make (M : M with type db = Pgsql_io.t) = struct
  module Installation_id = M.Installation_id
  module Repo_id = M.Repo_id
  module Pull_request_id = M.Pull_request_id
  module Config = M.Config

  type db = M.db

  let stack_state_ordering =
    [
      (* no changes is explicitly left out here because we treat no_changes
         special when determining stack stack *)
      `Plan_failed;
      `Plan_pending;
      `Apply_failed;
      `Apply_pending;
      `Apply_ready;
      `Apply_success;
    ]

  let outer_stack_name = function
    | [] -> assert false
    | { Tcm.Stack_config.paths; _ } :: _ -> CCList.hd @@ CCList.hd paths

  let inner_stacks dirspace_configs =
    CCList.map (fun { Tcm.Stack_config.name; paths; config = _ } ->
        let module Tac = Terrat_api_components in
        {
          Tac.Stack_inner.name;
          paths;
          state = `No_changes;
          dirspaces =
            CCList.filter_map
              (function
                | {
                    Tcm.Dirspace_config.stack_name;
                    dirspace = { Terrat_dirspace.dir; workspace };
                    _;
                  }
                  when CCString.equal stack_name name ->
                    Some
                      {
                        Tac.Stack_inner.Dirspaces.Items.dirspace = { Tac.Dirspace.dir; workspace };
                        state = `No_changes;
                      }
                | _ -> None)
              dirspace_configs;
        })

  let store ~request_id ~installation_id ~repo_id ~pull_request_id config db =
    let module Tac = Terrat_api_components in
    let stacks = Tcm.Config.stacks config in
    let topology =
      config
      |> Tcm.Config.stack_topology
      |> Sln_map.String.to_list
      |> Tsort.sort
      |> (function
      | Tsort.Sorted topo -> topo
      | Tsort.ErrorCycle _ -> assert false)
      |> CCList.uniq_succ ~eq:CCString.equal
      |> CCList.filter_map (fun s -> Sln_map.String.find_opt s stacks)
    in
    (* Group all stack entries together if their paths start with the same first
       element.  There can be multiple paths but we're just going to ignore that
       for simplicity for now. *)
    let stack_groups =
      CCList.group_succ
        ~eq:(fun { Tcm.Stack_config.paths = ps1; _ } { Tcm.Stack_config.paths = ps2; _ } ->
          match (ps1, ps2) with
          | (p1 :: _) :: _, (p2 :: _) :: _ -> CCString.equal p1 p2
          | _ -> false)
        topology
    in
    let dirspace_configs =
      Iter.to_list @@ Terrat_data.Dirspace_map.values @@ Tcm.Config.dirspace_configs config
    in
    let stacks =
      {
        Tac.Stacks.stacks =
          CCList.map
            (fun ss ->
              {
                Tac.Stack_outer.name = outer_stack_name ss;
                stacks = inner_stacks dirspace_configs ss;
                state = `No_changes;
                (* We store as "no_changes" in the database because when we
                   query it is when we will fill in the details. *)
              })
            stack_groups;
      }
    in
    M.store_stacks ~request_id ~installation_id ~repo_id ~pull_request_id stacks db

  let stack_state_of_dirspaces dirspaces =
    let module Tac = Terrat_api_components in
    let min_state =
      CCListLabels.fold_left ~f:CCInt.min ~init:(CCList.length stack_state_ordering)
      @@ CCList.filter_map
           (fun { Tac.Stack_inner.Dirspaces.Items.state; _ } ->
             CCList.find_index (Terrat_api_components.Stack_state.equal state) stack_state_ordering)
           dirspaces
    in
    if min_state = CCList.length stack_state_ordering then `No_changes
    else CCList.nth stack_state_ordering min_state

  let update_inner_stack_state dirspace_states s =
    let module Tac = Terrat_api_components in
    let { Tac.Stack_inner.dirspaces; _ } = s in
    let dirspaces =
      CCList.map
        (fun {
               Tac.Stack_inner.Dirspaces.Items.dirspace =
                 { Tac.Dirspace.dir; workspace } as dirspace;
               state = _;
             }
           ->
          {
            Tac.Stack_inner.Dirspaces.Items.dirspace;
            state =
              CCOption.get_or ~default:`No_changes
              @@ Terrat_data.Dirspace_map.find_opt
                   { Terrat_dirspace.dir; workspace }
                   dirspace_states;
          })
        dirspaces
    in
    let state = stack_state_of_dirspaces dirspaces in
    { s with Tac.Stack_inner.dirspaces; state }

  let outer_stack_state ss =
    let module Tac = Terrat_api_components in
    let dirspaces = CCList.flat_map (fun { Tac.Stack_inner.dirspaces; _ } -> dirspaces) ss in
    stack_state_of_dirspaces dirspaces

  let query ~request_id ~installation_id ~repo_id ~pull_request_id db =
    let module Tac = Terrat_api_components in
    let open Abbs_future_combinators.Infix_result_monad in
    M.query_stacks ~request_id ~installation_id ~repo_id ~pull_request_id db
    >>= function
    | Some stacks ->
        M.query_dirspace_states ~request_id ~installation_id ~repo_id ~pull_request_id db
        >>| fun dirspace_states ->
        let dirspace_states =
          Terrat_data.Dirspace_map.of_list
          @@ CCList.map
               (fun { Dirspace_state.dirspace; state } -> (dirspace, state))
               dirspace_states
        in
        let stacks =
          {
            Tac.Stacks.stacks =
              CCList.map
                (fun ({ Tac.Stack_outer.stacks; _ } as s) ->
                  let stacks = CCList.map (update_inner_stack_state dirspace_states) stacks in
                  { s with Tac.Stack_outer.stacks; state = outer_stack_state stacks })
                stacks.Tac.Stacks.stacks;
          }
        in
        Some stacks
    | None -> Abbs_future_combinators.return_ok None

  let enforce_installation_access user installation_id db ctx =
    M.enforce_installation_access ~request_id:(Brtl_ctx.token ctx) user installation_id db

  let get _config storage installation_id repo_id pull_request_id =
    Brtl_ep.run_result_json ~f:(fun ctx ->
        let open Abbs_future_combinators.Infix_result_monad in
        Terrat_session.with_session ctx
        >>= fun user ->
        let open Abb.Future.Infix_monad in
        Pgsql_pool.with_conn storage ~f:(fun db ->
            let open Abbs_future_combinators.Infix_result_monad in
            enforce_installation_access user installation_id db ctx
            >>= fun () ->
            query ~request_id:(Brtl_ctx.token ctx) ~installation_id ~repo_id ~pull_request_id db)
        >>= function
        | Ok (Some stacks) ->
            let body = Yojson.Safe.to_string @@ Terrat_api_components.Stacks.to_yojson stacks in
            Abbs_future_combinators.return_ok
              (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`OK body) ctx)
        | Ok None ->
            Abbs_future_combinators.return_ok
              (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Not_found "") ctx)
        | Error `Forbidden ->
            Abbs_future_combinators.return_err (Brtl_ctx.set_response `Forbidden ctx)
        | Error `Error ->
            Abbs_future_combinators.return_err (Brtl_ctx.set_response `Internal_server_error ctx)
        | Error #Pgsql_pool.err ->
            Abbs_future_combinators.return_err (Brtl_ctx.set_response `Internal_server_error ctx))

  module Rt = struct
    let stacks () =
      Brtl_rtng.Route.(
        M.route_root ()
        / M.vcs
        / "installations"
        /% Path.ud M.Installation_id.of_string
        / "repos"
        /% Path.ud M.Repo_id.of_string
        / "prs"
        /% Path.ud M.Pull_request_id.of_string
        / "stacks")
  end

  let routes config storage = Brtl_rtng.Route.[ (`GET, Rt.stacks () --> get config storage) ]
end
