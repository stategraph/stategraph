import { Shield } from "lucide-react";

import { FeatureDisabledNotice } from "@/components/product";

/**
 * Shown on Security pages when the server has security scanning disabled
 * (capabilities.security.enabled is false -- STATEGRAPH_SECURITY is not "true"
 * or "1"). Mirrors {@link CostDisabledNotice}: keep the page
 * visible and point the user at how to turn the feature on, rather than hiding
 * or redirecting.
 */
export function SecurityDisabledNotice() {
  return (
    <FeatureDisabledNotice
      icon={Shield}
      title="Security scanning isn't enabled on this server"
      body="Stategraph scans the Terraform in each state for misconfigurations and enriches every finding with graph context once scanning is enabled. See the docs to turn it on."
      docsHref="https://stategraph.com/docs/security"
      docsLabel="Read the security docs"
    />
  );
}
