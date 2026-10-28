type err =
  [ `No_encryption_keys_err
  | Pgsql_pool.err
  | Pgsql_io.err
  ]

val show_err : err -> string

(** The session middleware. [cookie_name] names the browser session cookie. It needs the keys of the
    [encryption_keys] table, which the migrations create. *)
val try_create :
  cookie_name:string -> Terrat_storage.t -> (Brtl_mw.Mw.t, [> err ]) result Abb.Future.t

(** The same session as {!try_create}, as a wrapper of the handlers of the routes that need it
    rather than as a middleware. *)
val try_create_wrapper :
  cookie_name:string ->
  Terrat_storage.t ->
  (Brtl_rtng.Handler.t -> Brtl_rtng.Handler.t, [> err ]) result Abb.Future.t

val create_user_session : Terrat_user.t -> ('a, 'b) Brtl_ctx.t -> ('a, 'b) Brtl_ctx.t

(** Delete the session that the [cookie_name] cookie of the request refers to. Give the same
    [cookie_name] as to {!try_create}. *)
val rem_session :
  cookie_name:string ->
  Terrat_storage.t ->
  ('a, 'b) Brtl_ctx.t ->
  (('a, 'b) Brtl_ctx.t, [> Pgsql_pool.err | Pgsql_io.err ]) result Abb.Future.t

(** If a user is authenticated, continue with the operation otherwise fail. If [caps] is specified,
    the user must be authenticated with the provided capabilities. *)
val with_session :
  ?caps:Terrat_user.Capability.t list ->
  (string, 'a) Brtl_ctx.t ->
  (Terrat_user.t, (string, [> `Location of Uri.t | `Forbidden ]) Brtl_ctx.t) result Abb.Future.t
