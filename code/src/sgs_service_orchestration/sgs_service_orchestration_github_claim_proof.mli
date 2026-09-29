(** Reading the proof cookie the GitHub claim callback set (#1795).

    Checks every binding the proof carries: signature, expiry, the user it was minted for, and the
    tenant it was minted against. An endpoint that uses this cannot honor a proof belonging to
    another user or tenant. *)

type err =
  [ `Missing_proof_err
  | Sgs_service_orchestration_github_claim_token.verify_err
  | `Proof_user_mismatch_err
  | `Proof_tenant_mismatch_err
  ]
[@@deriving show]

val cookie_name : string

(** [verifiers] are the session's RS256 verifiers, see
    {!Sgs_user_session.Session.Keys.rs256_verifiers}. *)
val of_ctx :
  verifiers:Jwt.Verifier.t list ->
  now:float ->
  user:Sgs_user.stored Sgs_user.t ->
  tenant:'a Sgs_tenant.t ->
  ('b, 'c) Brtl_ctx.t ->
  (Sgs_service_orchestration_github_claim_token.Proof.t, [> err ]) result
