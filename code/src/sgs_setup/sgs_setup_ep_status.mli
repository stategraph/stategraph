(** [GET /api/v1/setup/status]: whether the deployment still needs its in-app setup, and its mode. A
    deployment set up out of band ({!Sgs_cloud.S.setup}) never needs it. *)
module Make (_ : Sgs_cloud.S) : sig
  val run : Sgs_storage.t -> Brtl_rtng.Handler.t
end
