(** Proving which GitHub installations a user administers (#1795).

    Linking an installation grants a tenant read access to the account's repositories, pull
    requests, runs and plan output, so a self-serve claim needs GitHub to confirm the caller
    administers that account. Establishes, from GitHub and never from the request, who the caller is
    and which organizations they actively administer, then reduces that to the set of installation
    ids they may claim. Presence in [GET /user/installations] is deliberately not treated as
    authority: GitHub returns installations to plain members and outside collaborators too. All
    matching is on GitHub's numeric ids, so a login rename cannot redirect a claim.

    The user's token is used within the request and never stored. *)

type oauth_err =
  [ (* GitHub refused the code exchange with a non-success status. *)
    `Oauth_exchange_failed_err
  | (* GitHub answered the exchange with no token, as it does for a spent or wrong code. *)
    `Oauth_bad_response_err
  | Abb_curl.Make(Abb).request_err
  ]
[@@deriving show]

type api_err =
  [ `Github_call_err of Githubc2_abb.call_err
  | (* GitHub answered a read with 304 Not Modified. *)
    `Github_not_modified_err
  | (* The App is missing organization [members: read], or the user revoked access. Every
       organization claim fails closed until it is granted. *)
    `Forbidden_err
  ]
[@@deriving show]

type err =
  [ oauth_err
  | api_err
  ]
[@@deriving show]

(** An installation as GitHub reports it to the authenticated user, reduced to what the decision
    needs. *)
type installation = {
  github_id : int;
  target_id : int;
  target_type : string;
}

(** [prove ~config code] exchanges the authorization code and returns the GitHub numeric ids of the
    installations the caller provably administers. The list may be empty, which is a legitimate
    answer, not an error. *)
val prove : config:Sgs_config.github_oauth -> string -> (int list, [> err ]) result Abb.Future.t

(** Exposed for tests: the pure decision, with GitHub's answers as inputs. *)
module Tests : sig
  val provable_installation_ids :
    user_id:int -> admin_org_ids:int list -> installation list -> int list

  val installation : github_id:int -> target_id:int -> target_type:string -> installation
end
