"use client";

import { type WizardActions } from "@/lib/getting-started";
import {
  ENGINE_CONFIG,
  consoleOrigin,
  githubSecretsCommands,
  gitlabVariablesTable,
} from "@/lib/getting-started/doc-constants";
import type { VcsProvider } from "@/lib/vcs/links";
import { Button } from "@/components/ui/button";
import { CodeBlock } from "./CodeBlock";
import { ArrowLeft, ArrowRight } from "lucide-react";

interface StepVelocityOrchestrationProps {
  actions: WizardActions;
  /** The linked provider, or null when both or neither is known. */
  provider: VcsProvider | null;
  apiKey: string | null;
  tenantId: string;
}

function Inline({ children }: { children: React.ReactNode }) {
  return (
    <code className="text-xs bg-[var(--sg-bg-2)] px-1 py-0.5 rounded">{children}</code>
  );
}

export function StepVelocityOrchestration({
  actions,
  provider,
  apiKey,
  tenantId,
}: StepVelocityOrchestrationProps) {
  const gitlab = provider === "gitlab";
  const change = "pull request";
  const secrets = { apiBase: consoleOrigin(), apiKey, tenantId };

  const done = () => {
    actions.markEngineDone();
    actions.nextStep();
  };

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-semibold tracking-tight sm:text-3xl lg:text-4xl text-[var(--sg-text)]">
          Run your plans through Stategraph Infrastructure as a Database
        </h2>
        <p className="mt-3 max-w-prose text-base lg:text-lg text-[var(--sg-text-muted)]">
          {gitlab ? "Your project" : "Your repository"} plans from {change}s
          against your old backend. Switch it to the Stategraph engine, so those
          plans run against the state you just imported into Stategraph&apos;s
          database. Four steps.
        </p>
      </div>

      <div className="space-y-3">
        <div className="text-sm font-medium text-[var(--sg-text)]">
          1. Add three secrets to {gitlab ? "GitLab" : "GitHub"}
        </div>
        {gitlab ? (
          <>
            <p className="text-sm text-[var(--sg-text-muted)]">
              Project &rarr; Settings &rarr; CI/CD &rarr; Variables. Mask the key.
            </p>
            <CodeBlock code={gitlabVariablesTable(secrets)} language="variables" />
          </>
        ) : (
          <>
            <p className="text-sm text-[var(--sg-text-muted)]">
              Repository &rarr; Settings &rarr; Secrets and variables &rarr; Actions
              &rarr; New repository secret. The Stategraph workflow forwards every
              secret to the runner.
            </p>
            <CodeBlock code={githubSecretsCommands(secrets)} />
            {provider === null && (
              <p className="text-xs text-[var(--sg-text-muted)]">
                GitLab: Project &rarr; Settings &rarr; CI/CD &rarr; Variables, the
                same three names. Mask the key.
              </p>
            )}
          </>
        )}
      </div>

      <div className="space-y-3">
        <div className="text-sm font-medium text-[var(--sg-text)]">
          2. Commit a stategraph.json in every directory Orchestration runs
        </div>
        <p className="text-sm text-[var(--sg-text-muted)]">
          The import wrote one in the directory you imported. Repeat{" "}
          <Inline>stategraph import tf</Inline>, or{" "}
          <Inline>stategraph states create</Inline> for a directory with no
          state, in each other root directory. Commit the files.
        </p>
      </div>

      <div className="space-y-3">
        <div className="text-sm font-medium text-[var(--sg-text)]">
          3. Switch the engine in {ENGINE_CONFIG.path}
        </div>
        <CodeBlock code={ENGINE_CONFIG.global} language="yaml" />
        <p className="text-xs text-[var(--sg-text-muted)]">
          OpenTofu? Add <Inline>{ENGINE_CONFIG.tofu}</Inline> under{" "}
          <Inline>engine</Inline>.
        </p>
        <p className="text-sm text-[var(--sg-text-muted)]">
          Switch one directory at a time instead:
        </p>
        <CodeBlock code={ENGINE_CONFIG.perDirectory} language="yaml" />
      </div>

      <div className="space-y-3">
        <div className="text-sm font-medium text-[var(--sg-text)]">
          4. Open a {change}
        </div>
        <ul className="list-disc pl-5 space-y-1 text-sm text-[var(--sg-text-muted)]">
          <li>The plan comment now comes from Stategraph, scoped to what changed.</li>
          <li>
            Comment <Inline>stategraph apply</Inline> to apply. The apply commits
            to the state in Stategraph. Your old backend is no longer written.
          </li>
        </ul>
      </div>

      <div className="flex flex-wrap justify-between gap-2 pt-2">
        <Button variant="outline" onClick={actions.prevStep}>
          <ArrowLeft className="h-4 w-4 mr-1" />
          Back
        </Button>
        <div className="flex gap-2">
          <Button variant="ghost" onClick={actions.nextStep}>
            Skip for now
          </Button>
          <Button onClick={done}>
            Done
            <ArrowRight className="h-4 w-4 ml-1" />
          </Button>
        </div>
      </div>
    </div>
  );
}
