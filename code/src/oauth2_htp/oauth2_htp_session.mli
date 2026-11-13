(** Who signed in, as the provider reported it. *)

type t = {
  user : string;
      (** The provider's stable id for the user: the [sub] claim, or GitHub's numeric user id. *)
  email : string;
  groups : string list option;
      (** The user's groups, or [None] when the provider could not read them. *)
  avatar_url : string option;
      (** The URL of the user's picture, when the provider reports one: Google's [picture] claim or
          GitHub's avatar. *)
  access_token : string;
}
