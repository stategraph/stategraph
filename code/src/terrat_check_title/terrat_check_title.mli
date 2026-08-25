(** Commit-check title branding (#1442 Phase 3).

    Internally, every producer and consumer -- both evaluators, both providers -- speaks the
    canonical ["terrateam <cmd>"] titles. The brand substitution happens only at the VCS boundary:
    {!branded} rewrites titles on the way out (create_commit_checks and friends) according to
    TERRAT_CHECK_TITLE_BRAND, and {!canonical} normalizes fetched titles on the way in. Customers'
    branch-protection required checks key on the exact emitted strings, so the default stays
    [Terrateam] (zero behavior change for standalone images); the unified image sets [stategraph].
    Reads accept both brands regardless of the flag, so in-flight work manifests and repos migrating
    between brands never orphan their checks. *)

type brand =
  | Terrateam
  | Stategraph

(** The brand from TERRAT_CHECK_TITLE_BRAND, read once. Unknown values fall back to [Terrateam]
    here; [Terrat_config.create] validates the variable and fails boot on garbage first. *)
val active : brand

(** [branded_with ~brand title] rewrites a canonical ["terrateam ..."] title to the brand's prefix;
    any other string passes through untouched. *)
val branded_with : brand:brand -> string -> string

(** [branded] is {!branded_with} with {!active}. *)
val branded : string -> string

(** [canonical title] maps a ["stategraph ..."] title back to ["terrateam ..."]; any other string
    passes through untouched. Applied to every fetched commit check, so internal comparisons accept
    both brands. *)
val canonical : string -> string
