(** A cookie to set on the response. Every cookie is [Path=/], [HttpOnly] and [SameSite=Lax]. *)

type t = {
  name : string;
  value : string;
  max_age : int;  (** A negative age expires the cookie. *)
  secure : bool;
}

val to_set_cookie_header : t -> string
val add_to_response : t list -> Brtl_rspnc.t -> Brtl_rspnc.t
