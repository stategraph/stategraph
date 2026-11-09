include
  Terrat_vcs_api.S
    with type Account.Id.t = int
     and type Config.vcs_config = Terrat_config.Github.t
     and type Client.native = Githubc2_abb.t
     and type User.Id.t = string
     and type Pull_request.Id.t = int
     and type Repo.Id.t = int

module Directory_entry : sig
  type kind =
    [ `Dir
    | `File
    | `Submodule
    | `Symlink
    ]
  [@@deriving show, eq]

  type t [@@deriving show, eq]

  val make : kind:kind -> name:string -> size:int -> unit -> t
  val kind : t -> kind
  val name : t -> string
  val size : t -> int
end

type fetch_directory_err =
  [ Terrat_vcs_api.call_err
  | `Listing_unavailable
  ]
[@@deriving show]

(** List the entries of one directory. A path that does not exist, or that holds a file, a symlink
    or a submodule, holds no entries and reads as [None].

    [`Listing_unavailable] means the contents endpoint refused to list the directory, which it does
    when the directory holds too many entries. It is not a failure of the call: read the names you
    want directly instead. *)
val fetch_directory :
  request_id:string ->
  Client.t ->
  Repo.t ->
  Ref.t ->
  string ->
  (Directory_entry.t list option, [> fetch_directory_err ]) result Abb.Future.t

type retryable_missing_response_err = [ `Missing_response of string Openapi.Response.t ]
[@@deriving show]

(** Whether a failed call to the forge is a transport fault worth trying again. [`Missing_response]
    is the answer that did not come back: the request reached the forge and the reply was lost. A
    rate limit and a timeout have their own answers at the call sites and are not retried here. A
    [`Missing_response] whose body says the ref is gone is a verdict on the work, not a fault, and
    trying it again cannot change it. *)
val retryable_missing_response : ('a, [> retryable_missing_response_err ]) result -> bool

(** Whether the body of a response says the ref the call names is gone. The retry rule
    {!retryable_missing_response} refuses such a response and the dispatch call site treats it as
    success; this one predicate keeps the substring the two rules read from drifting apart. *)
val ref_not_found : string Openapi.Response.t -> bool
