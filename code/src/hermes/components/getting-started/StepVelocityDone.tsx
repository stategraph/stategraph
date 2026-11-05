"use client";

import { type WizardActions } from "@/lib/getting-started";
import { DOC_LINKS } from "@/lib/getting-started/doc-constants";
import { ORCHESTRATION_SETUP_HREF, type SetupStatus } from "@/lib/getting-started/setup-progress";
import type { VcsProvider } from "@/lib/vcs/links";
import { useDeepLinkRouter } from "@/hooks";
import { Button } from "@/components/ui/button";
import {
  CheckCircle2,
  BarChart3,
  Network,
  Search,
  ArrowLeft,
  ExternalLink,
} from "lucide-react";

interface StepVelocityDoneProps {
  actions: WizardActions;
  /** "done" once a first plan ran; "started" with an installation and no plan yet. */
  orchestration: SetupStatus;
  /** The engine step was completed in this session. */
  engineDone: boolean;
  provider: VcsProvider | null;
}

function Pill({ children }: { children: React.ReactNode }) {
  return (
    <div className="p-3 rounded-lg bg-[var(--sg-success)]/10 border border-[var(--sg-success)]/30 flex items-center gap-2 text-sm font-semibold text-[var(--sg-text)]">
      <CheckCircle2 className="h-4 w-4 text-[var(--sg-success)] flex-shrink-0" />
      {children}
    </div>
  );
}

function Card({
  title,
  body,
  action,
}: {
  title: string;
  body: string;
  action: React.ReactNode;
}) {
  return (
    <div className="h-full rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-0)] p-4 flex flex-col gap-3">
      <div className="text-base font-semibold text-[var(--sg-text)]">{title}</div>
      <p className="text-sm text-[var(--sg-text-muted)]">{body}</p>
      <div className="mt-auto">{action}</div>
    </div>
  );
}

export function StepVelocityDone({
  actions,
  orchestration,
  engineDone,
  provider,
}: StepVelocityDoneProps) {
  const router = useDeepLinkRouter();
  const change = provider === "gitlab" ? "merge request" : "pull request";

  const handleNavigate = (path: string) => {
    actions.markCompleted();
    router.push(path);
  };

  const consoleButton = (
    <Button variant={orchestration === "done" && engineDone ? "default" : "outline"} onClick={() => handleNavigate("/")}>
      Go to the console
    </Button>
  );

  return (
    <div className="space-y-6">
      <div className="space-y-2">
        <Pill>State is set up</Pill>
        {orchestration === "done" && engineDone && (
          <Pill>Orchestration runs on Infrastructure as a Database</Pill>
        )}
      </div>

      <div>
        <h2 className="text-2xl font-semibold tracking-tight sm:text-3xl lg:text-4xl text-[var(--sg-text)]">
          Your state lives in Stategraph
        </h2>
        <p className="mt-3 max-w-prose text-base lg:text-lg text-[var(--sg-text-muted)]">
          Plans are scoped to what changed and applies run concurrently. Query
          your infrastructure, follow cost, and see the blast radius of a change.
        </p>
      </div>

      {orchestration === "started" ? (
        <Card
          title="Finish setting up Stategraph Orchestration"
          body={`The app is installed. Add the workflow file and open a ${change}. Then come back here to switch the engine.`}
          action={
            <div className="flex flex-wrap gap-2">
              <Button onClick={() => handleNavigate(ORCHESTRATION_SETUP_HREF)}>
                Continue orchestration setup
              </Button>
              {consoleButton}
            </div>
          }
        />
      ) : orchestration === "todo" ? (
        <div className="space-y-3">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            <Card
              title="Set up Stategraph Orchestration"
              body={`Plan and apply from ${change}s on GitHub or GitLab, through the state you just imported.`}
              action={
                <Button onClick={() => handleNavigate(ORCHESTRATION_SETUP_HREF)}>
                  Set up orchestration
                </Button>
              }
            />
            <Card
              title="Run Terraform in your own CI?"
              body="Run stategraph plan and stategraph apply where you run Terraform today."
              action={
                <a
                  href={DOC_LINKS.ciGuides}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex items-center gap-1 text-sm text-[var(--sg-accent)] hover:underline"
                >
                  Open the CLI usage docs
                  <ExternalLink className="h-3 w-3" />
                </a>
              }
            />
          </div>
          {consoleButton}
        </div>
      ) : !engineDone ? (
        <Card
          title="Run your plans through Stategraph Infrastructure as a Database"
          body={`Your ${change}s still plan against your old backend. Switch the engine so they run against the state in Stategraph's database.`}
          action={
            <div className="flex flex-wrap gap-2">
              <Button onClick={() => actions.goToStep("velocity-orchestration")}>
                Switch the engine
              </Button>
              {consoleButton}
            </div>
          }
        />
      ) : (
        <div>{consoleButton}</div>
      )}

      <div className="space-y-3">
        <div className="text-sm font-medium text-[var(--sg-text)]">
          Explore your infrastructure
        </div>
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
          {[
            { icon: BarChart3, label: "Resources", path: "/instances" },
            { icon: Network, label: "Graph Explorer", path: "/graph-explorer" },
            { icon: Search, label: "Query", path: "/query" },
          ].map(({ icon: Icon, label, path }) => (
            <button
              key={path}
              onClick={() => handleNavigate(path)}
              className="flex items-center gap-2 p-3 rounded-lg border border-[var(--sg-border)] hover:border-[var(--sg-accent)] bg-[var(--sg-bg-0)] hover:bg-[var(--sg-accent-bg-active)] transition-colors text-sm text-[var(--sg-text)] cursor-pointer"
            >
              <Icon className="h-4 w-4 text-[var(--sg-text-dim)]" />
              {label}
            </button>
          ))}
        </div>
      </div>

      <div className="flex justify-between pt-2">
        <Button variant="outline" onClick={actions.prevStep}>
          <ArrowLeft className="h-4 w-4 mr-1" />
          Back
        </Button>
      </div>
    </div>
  );
}
