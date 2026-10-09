type t = Sgs_config.t
type 'a Sgs_service.ty += Ty : t Sgs_service.ty

let name = "config"

(* The registrable service: it creates the config itself, with the Cloud hint telling it whether
   a GitHub App is deployment-managed. It shares the witness above, so [load] finds it. *)
module Make (Cloud : Sgs_cloud.S) = struct
  type t = Sgs_config.t
  type opt = Sgs_svc_mngr.t

  let ty = Ty

  let matches (type a) (q : a Sgs_service.ty) : (t, a) Sgs_service.eq option =
    match q with
    | Ty -> Some Sgs_service.Refl
    | _ -> None

  let name = name

  (* A config that fails to load refuses the start, and the manager retries it forever: the logs
     repeat the failure until the operator fixes the environment. *)
  let start _ =
    let github_app_managed =
      match Cloud.github_app () with
      | `Deployment -> true
      | `Console -> false
    in
    match Sgs_config.create ~github_app_managed () with
    | Ok config -> Abbs_fc.return_ok config
    | Error (#Sgs_config.err as err) -> Abbs_fc.return_err (`Start_err (Sgs_config.show_err err))

  let routes _ = []
  let stop _ = Abb.Future.return ()
end
