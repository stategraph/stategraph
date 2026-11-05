import { Server } from "lucide-react";

import { FeatureDisabledNotice } from "./FeatureDisabledNotice";

export interface SelfHostedOnlyNoticeProps {
  /** Feature name shown in the heading, e.g. "Gap Analysis". */
  feature: string;
}

/**
 * Shown in place of a feature's UI when the server runs in COMMUNISM mode (the
 * shared hosted substrate) and that feature is only available on self-hosted
 * Stategraph for now. Keeping the nav item visible and rendering this notice --
 * rather than hiding the page -- mirrors the CostDisabledNotice convention and
 * keeps the section layout consistent.
 */
export function SelfHostedOnlyNotice({ feature }: SelfHostedOnlyNoticeProps) {
  return (
    <FeatureDisabledNotice
      icon={Server}
      title={`${feature} is only available on self-hosted Stategraph`}
      body="This feature isn't available on hosted Stategraph at the moment. Run a self-hosted deployment to use it. See the docs to get started."
      docsHref="https://stategraph.com/docs/deployment"
      docsLabel="Read the self-hosting docs"
    />
  );
}
