(** Commit-check titles.

    Every producer and consumer -- both evaluators, both providers -- speaks the canonical
    ["terrateam <cmd>"] titles. {!branded_with} rewrites titles on the way out
    (create_commit_checks) for the brand of the repository, and {!canonical} normalizes fetched
    titles on the way in. Customers' branch-protection required checks key on the exact emitted
    strings. Reads accept both brands, so in-flight work manifests and repositories that change
    brand never orphan their checks. *)

(** [branded_with ~brand title] rewrites a canonical ["terrateam ..."] title to the brand's prefix;
    any other string passes through untouched. *)
val branded_with : brand:Terrat_brand.t -> string -> string

(** [canonical title] maps a ["stategraph ..."] title back to ["terrateam ..."]; any other string
    passes through untouched. Applied to every fetched commit check, so internal comparisons accept
    both brands. *)
val canonical : string -> string
