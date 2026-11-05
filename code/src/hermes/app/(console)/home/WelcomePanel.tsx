"use client";

import { ArrowRight, BookOpen } from "lucide-react";
import { useSetupProgress } from "@/contexts";
import { DeepLink } from "@/components/navigation";
import { SlackIcon } from "@/components/ui/brand-icons";
import {
  ORCHESTRATION_SETUP_HREF,
  orchestrationStatus,
  stateStatus,
} from "@/lib/getting-started/setup-progress";

const ROW =
  "flex items-center gap-2 rounded-md border border-[var(--sg-border)] bg-[var(--sg-bg-1)] px-4 py-3 text-sm font-medium text-[var(--sg-accent)] transition-colors hover:bg-[var(--sg-bg-2)]";

/** The welcome panel on Home while a setup is unfinished. Nothing once both are done. */
export function WelcomePanel() {
  const progress = useSetupProgress();
  if (progress.isLoading) return null;

  // Gone as soon as either product works: a tenant that only wants one of them
  // is not nagged about the other. Get started in the sidebar and the Done
  // steps still lead to the second one.
  const orchestration = orchestrationStatus(progress);
  if (orchestration === "done" || stateStatus(progress) === "done") return null;

  const lead =
    orchestration === "started"
      ? "The Stategraph app is installed. Finish the setup: pick a repository and open your first pull request."
      : "New to Stategraph? Set up Orchestration first: install the app, pick a repository, open a pull request. Or set up Infrastructure as a Database from the same page.";
  const action = orchestration === "started" ? "Continue setup" : "Get started";

  return (
    <section className="mb-8 flex items-center gap-6 rounded-[var(--sg-card-radius)] border border-[var(--sg-accent)]/20 bg-[var(--sg-accent-bg)] p-6 sm:p-8">
      <div className="min-w-0 flex-1 space-y-4">
        <div className="space-y-2">
          <h2 className="text-2xl font-semibold text-[var(--sg-text)] sm:text-3xl">Welcome to Stategraph</h2>
          <p className="max-w-prose text-base text-[var(--sg-text-muted)]">{lead}</p>
        </div>
        <div className="grid gap-2">
          <DeepLink href={ORCHESTRATION_SETUP_HREF} className={ROW}>
            <ArrowRight className="h-4 w-4" />
            {action}
          </DeepLink>
          <a href="https://stategraph.com/docs" target="_blank" rel="noopener noreferrer" className={ROW}>
            <BookOpen className="h-4 w-4" />
            Getting started guide
          </a>
          <a href="https://stategraph.com/slack" target="_blank" rel="noopener noreferrer" className={ROW}>
            <SlackIcon className="h-4 w-4" />
            Join our Slack
          </a>
        </div>
      </div>
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img
        src="/logos/stategraph_logo_symbol_blue.svg"
        alt=""
        aria-hidden="true"
        className="hidden h-40 w-40 shrink-0 opacity-70 lg:block"
      />
    </section>
  );
}
