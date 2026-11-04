let src = Logs.Src.create "vcs"

module Logs = (val Logs.src_log src : Logs.LOG)

module type SELECT = sig
  type vcs_config

  val name : string
  val vcs_config : Terrat_config.t -> vcs_config option
end

module Github = struct
  type vcs_config = Terrat_config.Github.t

  let name = "terrat_github"
  let vcs_config = Terrat_config.github
end

module Gitlab = struct
  type vcs_config = Terrat_config.Gitlab.t

  let name = "terrat_gitlab"
  let vcs_config = Terrat_config.gitlab
end

module type S = sig
  include Sgs_service.S with type opt = Sgs_svc_mngr.t

  type 'a Sgs_service.ty += Ty : t Sgs_service.ty

  val service : t -> Terrat_vcs_service.service option
end

(* The VCS service is a functor over Stategraph: the service is instantiated at start, once the
   Stategraph service is up, with the module that reads this process's Stategraph database.  The
   instance lives in the existential [Terrat_vcs_service.service], the type its routes and stop go
   through. *)
module Make
    (Select : SELECT)
    (Vcs : functor
      (_ : Terrat_stategraph.S)
      -> Terrat_vcs_service.S with type Service.vcs_config = Select.vcs_config)
    (Stategraph_service : Sgs_service_terrat_stategraph.S) =
struct
  type started = {
    service : Terrat_vcs_service.service;
    session : Sgs_service_terrat_session.t;
  }

  type t = started option
  type opt = Sgs_svc_mngr.t
  type 'a Sgs_service.ty += Ty : t Sgs_service.ty

  let ty = Ty

  let matches (type a) (q : a Sgs_service.ty) : (t, a) Sgs_service.eq option =
    match q with
    | Ty -> Some Sgs_service.Refl
    | _ -> None

  let name = Select.name

  let start mgr =
    let open Abbs_fc.Infix_result_monad in
    Abbs_fc.Result.all4
      (Sgs_svc_mngr.load ~name:Sgs_service_terrat_config.name Sgs_service_terrat_config.Ty mgr)
      (Sgs_svc_mngr.load ~name:Sgs_service_terrat_exec.name Sgs_service_terrat_exec.Ty mgr)
      (Sgs_svc_mngr.load ~name:Sgs_service_terrat_session.name Sgs_service_terrat_session.Ty mgr)
      (Sgs_svc_mngr.load ~name:Stategraph_service.name Stategraph_service.Ty mgr)
    >>= fun (config, exec, session, stategraph) ->
    let storage = Sgs_service_terrat_config.storage config
    and config = Sgs_service_terrat_config.config config in
    match Select.vcs_config config with
    | None ->
        Logs.info (fun m -> m "%s is not configured: it serves no routes" name);
        Abbs_fc.return_ok None
    | Some vcs_config ->
        let module Stategraph = (val stategraph : Terrat_stategraph.S) in
        let module Vcs = Vcs (Stategraph) in
        Abbs_fc.Result.map_err
          ~f:(function
            | `Error -> `Start_fatal_err (name ^ " : could not start"))
          (Vcs.Service.start config vcs_config storage exec)
        >>| fun service ->
        Some { service = Terrat_vcs_service.Service ((module Vcs), service); session }

  let routes = function
    | Some { service = Terrat_vcs_service.Service ((module Vcs), service); session = _ } ->
        Vcs.Service.routes service
    | None -> []

  let wrap = function
    | Some { service = _; session } -> session
    | None -> CCFun.id

  let stop = function
    | Some { service = Terrat_vcs_service.Service ((module Vcs), service); session = _ } ->
        Vcs.Service.stop service
    | None -> Abb.Future.return ()

  let service = CCOption.map (fun { service; session = _ } -> service)
end

module Make_github
    (Vcs : functor
      (_ : Terrat_stategraph.S)
      -> Terrat_vcs_service.S with type Service.vcs_config = Terrat_config.Github.t)
    (Stategraph_service : Sgs_service_terrat_stategraph.S) =
  Make (Github) (Vcs) (Stategraph_service)

module Make_gitlab
    (Vcs : functor
      (_ : Terrat_stategraph.S)
      -> Terrat_vcs_service.S with type Service.vcs_config = Terrat_config.Gitlab.t)
    (Stategraph_service : Sgs_service_terrat_stategraph.S) =
  Make (Gitlab) (Vcs) (Stategraph_service)
