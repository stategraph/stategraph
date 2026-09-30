(** The orchestration GitHub App the console creates: the manifest that sends the operator to
    GitHub, the conversion of GitHub's code into the App, and the row in the orchestration database,
    reached through the admin FDW channel. The environment wins over the row on every read. *)

(** The App row as sgs may read it: the PEM and the webhook secret are not among the columns the
    provisioner role may select. [loaded] is set once an engine process has started with the App. *)
module Stored : sig
  type t = {
    id : int64;
    slug : string;
    client_id : string;
    client_secret : string;
    html_url : string;
    loaded : bool;
  }
end

(** What GitHub's conversion answers, reduced to the columns of the row. *)
module Created : sig
  type t = {
    id : int64;
    slug : string;
    pem : string;
    client_id : string;
    client_secret : string;
    webhook_secret : string;
    html_url : string;
  }
end

type status = {
  configured : bool;
  ready : bool;
}

(** The console may create an App: the deployment is self-hosted, orchestration is on, and the
    provisioner password is set, so the admin FDW channel exists. Reads answer [None] and the
    manifest endpoint answers 503 without it. COMMUNISM runs one App of its own from the
    environment, so it is never creatable there. *)
val channel_available : Sgs_config.t -> bool

(** The row, or [None] when there is none. *)
val select : Pgsql_io.t -> (Stored.t option, [> Pgsql_io.err ]) result Abb.Future.t

type insert_err =
  [ Pgsql_io.err
  | `Already_created_err  (** the table holds one row, and it exists *)
  ]
[@@deriving show]

val insert : Created.t -> Pgsql_io.t -> (unit, [> insert_err ]) result Abb.Future.t

(** The pure precedence: an App in the environment is configured and ready and hides the row; a row
    is configured, and ready once loaded. *)
val status_of : env_app_id:string option -> stored:Stored.t option -> status

val app_url_of : env_app_url:string option -> stored:Stored.t option -> string option

(** The OAuth client of the environment, else the row's. *)
val oauth_of : Sgs_config.t -> stored:Stored.t option -> Sgs_config.github_oauth option

(** The row when the channel is available, else [None]. *)
val stored : Sgs_config.t -> Pgsql_io.t -> (Stored.t option, [> Pgsql_io.err ]) result Abb.Future.t

(** {!oauth_of} over {!stored}. *)
val oauth :
  Sgs_config.t ->
  Pgsql_io.t ->
  (Sgs_config.github_oauth option, [> Pgsql_io.err ]) result Abb.Future.t

(** The path of the claim callback, under {!Sgs_config.oauth_redirect_base}: the manifest registers
    it with GitHub and the claim handshake redirects to it, so it is spelled once. *)
val claim_callback_path : string

module Manifest : sig
  type form = {
    action_url : string;  (** GitHub's form target, with the state in its query *)
    manifest : string;  (** the manifest as JSON text, the value of the [manifest] form field *)
  }

  val name_max : int

  (** The name trimmed and at most {!name_max} characters; the organization trimmed, [None] when
      blank, and a GitHub login otherwise. *)
  val validate :
    name:string ->
    organization:string option ->
    (string * string option, [> `Bad_name_err | `Bad_organization_err ]) result

  (** The manifest and the form target. The webhook and the engine's callback are under
      [terrat_api_base]; the manifest callback, the claim callback and the setup URL are under
      [redirect_base]; the App's homepage is [ui_base]. *)
  val build :
    ui_base:string ->
    terrat_api_base:string ->
    redirect_base:string ->
    web_base:string ->
    name:string ->
    organization:string option ->
    state:string ->
    form
end

type convert_err =
  [ `Conversion_failed_err of int  (** GitHub answered with this non-success status *)
  | `Conversion_bad_response_err
    (** GitHub answered success without the fields of an App, or with a private key that is not an
        RSA key the engine can decode *)
  | Abb_curl.Make(Abb).request_err
  ]
[@@deriving show]

(** [POST {api_base}/app-manifests/{code}/conversions]. *)
val convert : api_base:string -> string -> (Created.t, [> convert_err ]) result Abb.Future.t

(** The App a callback stored, reduced to what a log may carry. *)
type created = {
  user_id : string;
  app_id : int64;
  slug : string;
}

type create_err =
  [ `Bad_state_err of Sgs_service_orchestration_github_claim_token.verify_err
  | `Convert_err of convert_err
  | insert_err
  ]
[@@deriving show]

(** The callback: verify the state against the session keys, convert the code with [convert], and
    insert the row. *)
val create_from_code :
  convert:(string -> (Created.t, convert_err) result Abb.Future.t) ->
  keys:Sgs_user_session.Session.Keys.t ->
  now:float ->
  state:string ->
  code:string ->
  Pgsql_io.t ->
  (created, [> create_err ]) result Abb.Future.t
