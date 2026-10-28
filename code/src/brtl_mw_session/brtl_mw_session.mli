(** Use cookies or bearer tokens for authenticating a user. *)

module Auth : sig
  type 'a t =
    | Cookie of 'a
    | Bearer of 'a
end

module Value : sig
  type 'a t
end

(** The type of an [id], which is the session token, an id can be a cookie or a bearer token. *)
type id = string

(** The type of a cookie name. *)
type cookie_name = string

(** The load function which transforms an [id] into the representation of the application. [None]
    means the [id] is not valid. *)
type 'a load = id -> 'a option Abb.Future.t

(** Store a mapping of an identifier to an application representation. If the [id] is [None] then
    generate an [id]. The [id] does not have to be the same as the [id] passed in, this allows for
    the hash to be some encoding of the application representation. *)
type 'a store = id option -> 'a -> (string, Brtl_rspnc.t) Brtl_ctx.t -> id Abb.Future.t

module Config : sig
  module Cookie : sig
    type 'a t = {
      name : cookie_name;  (** The name of the cookie. *)
      expiration : [ `Session | `Max_age of Int64.t ];  (** How long the cookie should last. *)
      domain : string option;  (** The optional domain the cookie applies to. *)
      path : string option;  (** The optional path the cookie applies to. *)
      secure : bool;  (** Whether to set the Secure flag on the cookie. *)
      load : 'a load;  (** The load function. This is called in the [pre_handler]. *)
      store : 'a store;
          (** The store function. This is called in the [post_handler] if the key in the context has
              been modified. *)
    }
  end

  module Bearer : sig
    type 'a t = {
      load : 'a load;  (** The load function. This is called in the [pre_handler]. *)
      store : 'a store;
          (** The store function. This is called in the [post_handler] if the key in the context has
              been modified. *)
    }
  end

  type 'a t = {
    key : 'a Value.t Hmap.key;  (** The key the value is stored in the [Brtl_ctx]. *)
    cookie : 'a Cookie.t option;  (** Configuration for cookie authentication *)
    bearer : 'a Bearer.t option;  (** Configuration for bearer token *)
  }
end

val create : 'a Config.t -> Brtl_mw.Mw.t

(** [wrap config handler] is [handler] with the session, for routes that need it when the rest of
    the listener does not: it loads the session of the request into the context, as the middleware
    does before the handler, then runs [handler], then stores the session if [handler] changed it,
    as the middleware does after. *)
val wrap :
  'a Config.t ->
  ((string, unit) Brtl_ctx.t -> (string, Brtl_rspnc.t) Brtl_ctx.t Abb.Future.t) ->
  (string, unit) Brtl_ctx.t ->
  (string, Brtl_rspnc.t) Brtl_ctx.t Abb.Future.t

val set_session_value :
  'a Value.t Hmap.key -> 'a Auth.t -> ('b, 'c) Brtl_ctx.t -> ('b, 'c) Brtl_ctx.t

val get_session_value : 'a Value.t Hmap.key -> ('b, 'c) Brtl_ctx.t -> 'a Auth.t option
val get_session_key : string -> ('a, 'b) Brtl_ctx.t -> id option
val rem_session_value : 'a Value.t Hmap.key -> ('b, 'c) Brtl_ctx.t -> ('b, 'c) Brtl_ctx.t
val create_key : unit -> 'a Value.t Hmap.key
