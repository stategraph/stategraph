(** Users Update Endpoint

    Writes a user's [name] and [avatar_url], and for an installation admin its [email] and
    [is_instance_admin] too.

    Requires {!Sgs_user_session.Caps.users_manage_some} or being the subject, and then, for anyone
    but the subject, the authority {!Sgs_service_users_common.authority_over} tests: editing someone
    else's record is acting on their account.

    [email] and [is_instance_admin] are an installation admin's to write, and a request carrying
    either without that grant is refused whole. All of it lands or none of it does. *)

(** PUT /api/v1/users/update?user_id= - Update user information *)
val run : Sgs_config.t -> Sgs_storage.t -> Uuidm.t -> Brtl_rtng.Handler.t
