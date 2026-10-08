type requirement =
  [ `Not_required
  | `Required of Sgs_config.t -> Pgsql_io.t -> (bool, Pgsql_io.err) result Abb.Future.t
  ]

(* The edition's check answers the closed [Pgsql_io.err]; the setup endpoints thread it through
   results that carry more errors, so it is widened here. *)
let passes_license_gate ~requirement config db =
  match requirement with
  | `Not_required -> Abbs_fc.return_ok true
  | `Required is_licensed ->
      let open Abb.Future.Infix_monad in
      is_licensed config db >>| CCResult.map_err (fun (#Pgsql_io.err as err) -> err)

let may_start ~requirement config db =
  let open Abbs_fc.Infix_result_monad in
  match requirement with
  | `Not_required -> Abbs_fc.return_ok true
  | `Required _ -> (
      Sgs_user.has_human_users db
      >>= function
      | false -> Abbs_fc.return_ok true
      | true -> passes_license_gate ~requirement config db)

module type LICENSE = sig
  val requirement : requirement
  val setup_complete : Sgs_config.t -> Sgs_storage.t -> Brtl_rtng.Handler.t
  val setup_admin : Sgs_config.t -> Sgs_storage.t -> Brtl_rtng.Handler.t
  val license_status : Sgs_config.t -> Sgs_storage.t -> Brtl_rtng.Handler.t
end

module Rt = struct
  let api_v1 () = Brtl_rtng.Route.(rel / "api" / "v1")
  let setup_complete () = Brtl_rtng.Route.(api_v1 () / "setup" / "complete")
  let setup_admin () = Brtl_rtng.Route.(api_v1 () / "setup" / "admin")
  let license_status () = Brtl_rtng.Route.(api_v1 () / "license" / "status")
end

module Make (L : LICENSE) = struct
  type t = unit
  type 'a Sgs_service.ty += Ty : t Sgs_service.ty

  let ty = Ty

  let matches (type a) (q : a Sgs_service.ty) : (t, a) Sgs_service.eq option =
    match q with
    | Ty -> Some Sgs_service.Refl
    | _ -> None

  let name = "license"

  type opt = Sgs_svc_mngr.t

  let start mgr =
    let open Abb.Future.Infix_monad in
    Abbs_fc.Result.all2 (Sgs_svc_mngr.config mgr) (Sgs_svc_mngr.storage mgr)
    >>= function
    | Error `Config_err ->
        Abbs_fc.return_err (`Start_err "SERVICE_MANAGER : could not get the config")
    | Error `Storage_err ->
        Abbs_fc.return_err (`Start_err "SERVICE_MANAGER : could not get the storage")
    | Ok (config, storage) -> (
        Pgsql_pool.with_conn storage ~f:(may_start ~requirement:L.requirement config)
        >>| function
        | Ok true -> Ok ()
        | Ok false ->
            Error
              (`Start_err
                 "LICENSE_REQUIRED : This installation has users but no valid license. Set \
                  STATEGRAPH_LICENSE_KEY to a valid license key and restart.")
        | Error (#Pgsql_pool.err as err) -> Error (`Start_err (Pgsql_pool.show_err err))
        | Error (#Pgsql_io.err as err) -> Error (`Start_err (Pgsql_io.show_err err)))

  let routes () config storage =
    Brtl_rtng.Route.
      [
        (`POST, Rt.setup_complete () --> L.setup_complete config storage);
        (`POST, Rt.setup_admin () --> L.setup_admin config storage);
        (`GET, Rt.license_status () --> L.license_status config storage);
      ]

  let stop () = Abb.Future.return ()
end
