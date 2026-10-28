(** The terrat UI service: the routes that only terrat's console (iris) and Terrateam API users
    call, as a service in the manager. Two of them have a path that stategraph serves too, so they
    answer at a path of their own, which the iris host of nginx rewrites to:

    {v
      GET  /api/v1/whoami        ->  GET /api/v1/terrateam/whoami
      GET  /api/v1/tasks/{id}    ->  GET /api/v1/terrateam/tasks/{id}
    v}

    [POST /api/v1/logout] and [GET /api/v1/server/config] keep their paths. Each route runs in
    terrat's session. Its start loads the terrat config and session services and the two VCS
    services, whose started services whoami lists. It has nothing to stop. *)

module Make (_ : Sgs_service_terrat_vcs.S) (_ : Sgs_service_terrat_vcs.S) :
  Sgs_service.S with type opt = Sgs_svc_mngr.t
