module Ui : sig
  (** The console of [brand], and the installation of [account] inside it. *)
  val base_url :
    brand:Terrat_brand.t ->
    Terrat_vcs_api_github.Config.t ->
    Terrat_vcs_api_github.Account.t ->
    string

  (** The page of the console of [brand] that shows the plan of an installation. *)
  val subscription_url : brand:Terrat_brand.t -> Terrat_vcs_api_github.Config.t -> Uri.t

  val work_manifest_url :
    brand:Terrat_brand.t ->
    Terrat_vcs_api_github.Config.t ->
    Terrat_vcs_api_github.Account.t ->
    (Terrat_vcs_api_github.Repo.t * int) option ->
    ('a, Uuidm.t, 'b, 'c, 'd, 'e, 'f, 'g) Terrat_work_manifest3.t ->
    Uri.t option

  val run_url :
    brand:Terrat_brand.t ->
    Terrat_vcs_api_github.Config.t ->
    Terrat_vcs_api_github.Account.t ->
    Uuidm.t ->
    Uri.t option

  (** {!run_url} opened on the output of one dirspace of the run. *)
  val dirspace_run_url :
    brand:Terrat_brand.t ->
    Terrat_vcs_api_github.Config.t ->
    Terrat_vcs_api_github.Account.t ->
    Uuidm.t ->
    Terrat_dirspace.t ->
    Uri.t option
end
