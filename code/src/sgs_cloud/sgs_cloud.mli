(** What differs when Stategraph Cloud operates the deployment: how it runs, and the calls to its
    control plane. The services that depend on it take an implementation as a functor argument, so
    that an edition without Stategraph Cloud does not carry it. *)

(** The Stategraph user a call to the control plane is attributed to. *)
type identity = {
  user_id : string;
  email : string;
}

(** Why a call to the control plane failed. *)
type err =
  [ `Not_configured_err  (** The deployment has no control plane to call. *)
  | `Http_err of string  (** Network / curl-level failure. *)
  | `Bad_status_err of int * string  (** HTTP status was non-2xx; payload is the response body. *)
  | `Bad_json_err of string
    (** Response body wasn't valid JSON / didn't match the expected shape. *)
  ]
[@@deriving show]

(** What the control plane did with an invitation message. *)
type invite_delivery =
  [ `Emailed  (** The control plane sent the message through its mail provider. *)
  | `Logged_only
    (** The control plane has no mail provider key: it logged the message, and nobody was emailed.
    *)
  ]

module type S = sig
  (** Who sets the installation up. [`In_app]: its first operator, through the console's setup flow.
      [`Out_of_band]: the deployment, outside the application; setup is then always complete. *)
  val setup : unit -> [ `In_app | `Out_of_band ]

  (** Which tenant a new user joins at their first sign-in. [`Default_tenant]: the default tenant;
      the first user of the installation becomes its administrator. [`Personal_tenant]: a tenant
      created for them, of which they are the only member and the administrator. *)
  val new_user_tenant : unit -> [ `Default_tenant | `Personal_tenant ]

  (** Who supplies the orchestration GitHub App. [`Console]: the console creates one. [`Deployment]:
      the deployment supplies its own for every tenant, so the console must not create one. *)
  val github_app : unit -> [ `Console | `Deployment ]

  (** The [mode] field of [GET /api/v1/setup/status]; [None] omits it. *)
  val api_mode : unit -> string option

  (** Report a brand-new Stategraph account to the control plane, which records it and sends the
      new-customer alert exactly once. Repeat calls for the same user are accepted and silent. *)
  val record_first_touch :
    config:Sgs_config.t -> identity:identity -> (unit, [> err ]) result Abb.Future.t

  (** Ask the control plane to email one tenant invitation, and report whether it was actually
      delivered.

      Callers must treat [`Logged_only] as "the invitation exists but nobody was emailed" and
      surface the link for the inviter to pass on themselves — never as a failure that discards the
      invitation. [`Not_configured_err] means the same: invitations are then link-only. The
      [string option] names the transport that was used, for logging. *)
  val send_tenant_invite :
    config:Sgs_config.t ->
    identity:identity ->
    to_:string ->
    tenant_name:string ->
    inviter_name:string ->
    inviter_email:string option ->
    accept_url:string ->
    expires_at:string ->
    idempotency_key:string ->
    (invite_delivery * string option, [> err ]) result Abb.Future.t
end
