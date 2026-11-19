(** What a user or a token is allowed to do.

    This replaces the capability record read from JSON ([Sgs_session_caps_capabilities]): every
    scope is a set of strings ({!Sg_caps_trie_scope}) instead of a list of glob patterns, so that
    {!union} and {!inter} are exact -- they allow exactly what their operands allow between them, or
    in common.

    Capabilities authorize changing and administering, not reading. What a session reads of a
    tenant's infrastructure -- its states, its transactions and their results, and what MQL answers
    over them -- is decided by its user's membership of that tenant, whatever capabilities the
    session holds. A tenant scope therefore limits what its grant may change or administer there; it
    does not confine the session to those tenants: an access token whose every grant names tenant A
    still reads every tenant its user is a member of. The administrative records of a tenant -- its
    members, invitations, group rules, billing sources and VCS installations -- are the exception:
    they are read under the [admin] or [users-manage] grant that changes them.

    A capability that reaches nothing is a capability that is not there: there is no option around a
    scope, and {!empty} allows nothing at all.

    An [admin] grant authorizes preview and commit over the tenants it names, whether or not the
    [commit] or [preview] scopes reach them. The two are kept apart in [t], so that taking a tenant
    out of [admin] also takes away the preview and commit it implied; {!authorizes} is where the two
    are read together. *)

module Scope = Sg_caps_trie_scope

(** What a preview or commit grant reaches, along the two axes enforcement checks separately: the
    resources a transaction modifies, and the nodes its bundle pulls in. *)
type actions = {
  modified : Sg_caps_reach.t;
  pulled_in : Sg_caps_reach.t;
}
[@@deriving show]

type t = {
  access_token_create : bool;
  access_token_refresh : bool;
  admin : Scope.t;  (** tenants *)
  users_manage : Scope.t;  (** tenants *)
  sudo : Scope.t;  (** user names *)
  commit : actions;
  preview : actions;
}
[@@deriving show]

(** Allows nothing: [authorizes] is false for every atom. It is the neutral element of {!union}, and
    {!inter} with it allows nothing. *)
val empty : t

(** Allows everything: [authorizes] is true for every atom. It is the neutral element of {!inter},
    and {!union} with it allows everything. It is what an unrestricted grant means, and the ceiling
    that restricts nothing. *)
val everything : t

(** One thing a capability set allows or refuses. It is what {!union} and {!inter} are exact about:
    they decide each of these the same way the operands do, together or in common. *)
type atom =
  | Access_token_create
  | Access_token_refresh
  | Admin of string  (** administer that tenant *)
  | Users_manage of string  (** manage the users of that tenant *)
  | Sudo of string  (** act as that user *)
  | Act of {
      action : [ `Commit | `Preview ];
      axis : [ `Modified | `Pulled_in ];
      tenant : string;
      state : string;
      address : string;
    }
[@@deriving show]

(** [authorizes caps atom] is true when [caps] allows [atom]. An [Act] atom is allowed when [admin]
    reaches its tenant, or when the grant of its action reaches the triple along its axis. *)
val authorizes : t -> atom -> bool

(** [union a b] allows an atom when [a] or [b] allows it. It is what a user's capabilities become
    when a group rule grants more. *)
val union : t -> t -> t

(** [inter a b] allows an atom when both [a] and [b] allow it. It is the ceiling every token-minting
    path applies. *)
val inter : t -> t -> t

(** One capability of a set, named so that a refusal can say which one was missing. *)
type capability =
  [ `Access_token_create
  | `Access_token_refresh
  | `Admin
  | `Commit
  | `Preview
  | `Sudo
  | `Users_manage
  ]

(** [missing a b] is the capabilities of [b] that [a] does not allow, in a fixed order. An [admin]
    grant answers for commit and preview over the tenants it names, so those two are asked of what
    the action reaches once admin is read into it. Ask {!entails} instead when only the answer
    matters. *)
val missing : t -> t -> capability list

(** [entails a b] is true when [a] allows every atom that [b] allows, which is [missing a b] being
    empty. *)
val entails : t -> t -> bool

(** [equivalent a b] is true when [a] entails [b] and [b] entails [a]. *)
val equivalent : t -> t -> bool
