(** Responses shared by the GitHub App endpoints. *)

(** 503: this server does not store a GitHub App of its own, so there is nothing to manage. *)
val respond_unavailable : ('a, 'b) Brtl_ctx.t -> ('a, Brtl_rspnc.t) Brtl_ctx.t

(** 409: the App the caller named is not the one stored, or there is none. Reloading the console
    shows what is there. *)
val respond_stale : ('a, 'b) Brtl_ctx.t -> ('a, Brtl_rspnc.t) Brtl_ctx.t
