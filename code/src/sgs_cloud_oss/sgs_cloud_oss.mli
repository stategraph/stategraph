(** No Stategraph Cloud: in-app setup, new users join the default tenant, the console creates the
    GitHub App, nothing to report when an account is created, and no control plane to email
    invitations, which are then link-only. *)

include Sgs_cloud.S
