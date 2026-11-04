module Ui : sig
  val work_manifest_url :
    brand:Terrat_brand.t ->
    Terrat_vcs_api_gitlab.Config.t ->
    Terrat_vcs_api_gitlab.Account.t ->
    (Terrat_vcs_api_gitlab.Repo.t * int) option ->
    ('a, Uuidm.t, 'b, 'c, 'd, 'e, 'f, 'g) Terrat_work_manifest3.t ->
    Uri.t option

  (** The page of the console of [brand] that shows the plan of an installation. *)
  val subscription_url : brand:Terrat_brand.t -> Terrat_vcs_api_gitlab.Config.t -> Uri.t
end
