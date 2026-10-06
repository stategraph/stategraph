(** Users Delete Endpoint

    Soft deletes a user. Requires authority over users somewhere,
    {!Sgs_user_session.Caps.users_manage_some}, and then the authority
    {!Sgs_service_users_common.authority_over} tests. A grant confined to one tenant reaches the
    users of that tenant and no others. So a [users-manage] holder deletes ordinary users, and
    neither administrators nor other [users-manage] holders.

    An installation admin acts laterally, as it does everywhere that test is asked, so a peer is
    reachable and only the floor below stops it.

    Cannot delete yourself or the last installation admin. *)

(** DELETE /api/v1/users/delete?user_id= - Soft delete a user *)
val run : Sgs_config.t -> Sgs_storage.t -> Uuidm.t -> Brtl_rtng.Handler.t
