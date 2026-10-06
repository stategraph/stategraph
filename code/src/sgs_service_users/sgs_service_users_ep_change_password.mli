(** Users Change Password Endpoint

    Replacing a password answers to three rules.

    - Anyone replaces its own, and must produce the current one. An installation admin included, so
      that a stolen session cannot lock the owner out of an account without knowing the password it
      replaces.
    - Authority over users replaces the password of a user holding strictly less, inside the tenants
      that authority reaches, without producing the current one —
      {!Sgs_service_users_common.authority_over} is the exact test.
    - Nobody else replaces the password of a peer or a superior. One [users-manage] holder cannot
      take over another's account, and administrators of different tenants cannot take over each
      other's.

    An installation admin is the exception to the last rule, and acts laterally: there is nothing
    above the top of the lattice for strict containment to protect, and refusing it would leave a
    locked-out administrator with no way to be helped. *)

(** POST /api/v1/users/change-password?user_id= - Change a user's password *)
val run : Sgs_config.t -> Sgs_storage.t -> Uuidm.t -> Brtl_rtng.Handler.t
