(** Who signed in, as the provider reported it. *)

type t = {
  user : string;  (** The provider's stable id for the user: the [sub] claim. *)
  email : string;
  groups : string list option;
      (** The user's groups, or [None] when the provider could not read them. *)
  access_token : string;
}
