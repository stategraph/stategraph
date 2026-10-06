(** Users Create Endpoint

    Creates a new user. Requires {!Sgs_user_session.Caps.users_manage_some}, and additionally an
    installation-wide [admin] grant to set [is_instance_admin].

    The new user joins the creator's tenants, less any the creator's grant does not reach, so a
    grant confined to one tenant staffs that tenant and no other. A creator whose grant reaches none
    of the tenants it belongs to is refused: the user would join nothing, and a user in no tenant is
    inside every scoped grant's reach rather than outside it. *)

(** POST /api/v1/users - Create a new user *)
val run : Sgs_config.t -> Sgs_storage.t -> Brtl_rtng.Handler.t
