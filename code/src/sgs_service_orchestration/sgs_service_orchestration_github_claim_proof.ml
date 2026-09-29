type err =
  [ `Missing_proof_err
  | Sgs_service_orchestration_github_claim_token.verify_err
  | `Proof_user_mismatch_err
  | `Proof_tenant_mismatch_err
  ]
[@@deriving show]

let cookie_name = "sg_github_claim_proof"

(* The cookie travels with the browser, so without the user and tenant checks it
   would still be honored after a switch of tenant, or after someone else signs
   in on a shared machine. *)
let of_ctx ~verifiers ~now ~user ~tenant ctx =
  let headers = Brtl_ctx.(Request.headers (request ctx)) in
  let cookies = Cohttp.Cookie.Cookie_hdr.extract headers in
  match CCList.Assoc.get ~eq:CCString.equal cookie_name cookies with
  | None -> Error `Missing_proof_err
  | Some token -> (
      match Sgs_service_orchestration_github_claim_token.Proof.verify ~verifiers ~now token with
      | Ok
          {
            Sgs_service_orchestration_github_claim_token.Proof.user_id;
            tenant_id = _;
            installation_core_ids = _;
            exp = _;
          }
        when not (CCString.equal user_id (Uuidm.to_string (Sgs_user.id user))) ->
          Error `Proof_user_mismatch_err
      | Ok
          {
            Sgs_service_orchestration_github_claim_token.Proof.user_id = _;
            tenant_id;
            installation_core_ids = _;
            exp = _;
          }
        when not (CCString.equal tenant_id (Uuidm.to_string (Sgs_tenant.id tenant))) ->
          Error `Proof_tenant_mismatch_err
      | Ok proof -> Ok proof
      | Error (#Sgs_service_orchestration_github_claim_token.verify_err as err) -> Error err)
