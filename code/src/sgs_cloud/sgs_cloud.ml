type identity = {
  user_id : string;
  email : string;
}

type err =
  [ `Not_configured_err
  | `Http_err of string
  | `Bad_status_err of int * string
  | `Bad_json_err of string
  ]
[@@deriving show]

module type S = sig
  val setup : unit -> [ `In_app | `Out_of_band ]
  val new_user_tenant : unit -> [ `Default_tenant | `Personal_tenant ]
  val github_app : unit -> [ `Console | `Deployment ]
  val api_mode : unit -> string option

  val record_first_touch :
    config:Sgs_config.t -> identity:identity -> (unit, [> err ]) result Abb.Future.t

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
    (bool * string option, [> err ]) result Abb.Future.t
end
