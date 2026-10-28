(** Terrat's VCS services (GitHub, GitLab) as stategraph services. A VCS service serves the routes
    of its VCS, each in terrat's session ({!Sgs_service_terrat_session}), and runs its hourly work
    (drift, cleanups). Its start loads the terrat config, executor and session services, so it
    refuses with [`Start_missing_deps_err] until they are up. A VCS that the terrat config does not
    configure starts with no routes and no work. *)

module type S = sig
  include Sgs_service.S with type opt = Sgs_svc_mngr.t

  (** Names this service in a match on {!Sgs_service.ty}. *)
  type 'a Sgs_service.ty += Ty : t Sgs_service.ty

  (** The started VCS service, [None] when the VCS is not configured. *)
  val service : t -> Terrat_vcs_service.service option
end

(** GitHub: the GitHub App of the terrat config, which {!Sgs_service_terrat_config} settles from the
    environment or the database. *)
module Make_github
    (_ : Terrat_vcs_service.S with type Service.vcs_config = Terrat_config.Github.t) : S

(** GitLab: the GitLab config of the environment. *)
module Make_gitlab
    (_ : Terrat_vcs_service.S with type Service.vcs_config = Terrat_config.Gitlab.t) : S
