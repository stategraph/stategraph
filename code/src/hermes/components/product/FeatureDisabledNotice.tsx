import { ExternalLink, type LucideIcon } from "lucide-react";

import { Button } from "@/components/ui/button";

export interface FeatureDisabledNoticeProps {
  icon: LucideIcon;
  /** Heading, e.g. "Cost tracking isn't enabled on this server". */
  title: string;
  /** One-paragraph explanation ending with a pointer at the docs. */
  body: string;
  docsHref: string;
  /** Docs button label, e.g. "Read the cost docs". */
  docsLabel: string;
}

/**
 * The one shape for "this feature isn't available here" notices — feature
 * disabled on the server, self-hosted-only in COMMUNISM mode, orchestration
 * off. The convention: keep the page and its nav item visible and point the
 * user at how to turn the feature on, rather than hiding or redirecting.
 * Consumers (CostDisabledNotice and friends) supply only the copy, so every
 * such notice renders identically.
 */
export function FeatureDisabledNotice({ icon: Icon, title, body, docsHref, docsLabel }: FeatureDisabledNoticeProps) {
  return (
    <div className="flex flex-col items-center justify-center min-h-[60vh] px-6 text-center">
      <div
        className="h-16 w-16 rounded-2xl flex items-center justify-center mb-6"
        style={{
          background: "var(--sg-accent-bg)",
          border: "1px solid var(--sg-border)",
        }}
      >
        <Icon className="h-8 w-8" style={{ color: "var(--sg-accent)" }} />
      </div>
      <h1 className="text-2xl font-semibold text-[var(--sg-text)]">{title}</h1>
      <p className="mt-3 max-w-md text-sm leading-relaxed text-[var(--sg-text-muted)]">{body}</p>
      <a href={docsHref} target="_blank" rel="noopener noreferrer" className="mt-7">
        <Button size="lg" className="h-11 px-6 font-semibold">
          {docsLabel}
          <ExternalLink className="h-4 w-4 ml-2" />
        </Button>
      </a>
    </div>
  );
}
