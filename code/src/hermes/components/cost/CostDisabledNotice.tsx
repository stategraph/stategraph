import { DollarSign } from "lucide-react";

import { FeatureDisabledNotice } from "@/components/product";

/**
 * Shown on every cost page (Analysis, Overview, Explorer) when the server has
 * cost disabled (capabilities.costs.enabled is false). Keeping all the cost
 * pages visible and showing the same notice -- rather than hiding or
 * redirecting some of them -- keeps the Costs section consistent and points the
 * user at how to turn cost on.
 */
export function CostDisabledNotice() {
  return (
    <FeatureDisabledNotice
      icon={DollarSign}
      title="Cost tracking isn't enabled on this server"
      body="Stategraph prices the resources in your state automatically once cost estimation is enabled. See the docs to turn it on."
      docsHref="https://stategraph.com/docs/cost"
      docsLabel="Read the cost docs"
    />
  );
}
