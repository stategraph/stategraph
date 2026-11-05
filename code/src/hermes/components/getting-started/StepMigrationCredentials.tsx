"use client";

import { type WizardActions } from "@/lib/getting-started";
import {
  CLI_COMMANDS,
  apiKeyCommand,
  getApiBaseCommand,
  tenantListExample,
} from "@/lib/getting-started/doc-constants";
import { useTenant } from "@/contexts";
import { Button } from "@/components/ui/button";
import { CodeBlock } from "./CodeBlock";
import { ArrowLeft, ArrowRight } from "lucide-react";

interface StepVelocityCredentialsProps {
  actions: WizardActions;
  apiKey: string | null;
}

export function StepMigrationCredentials({
  actions,
  apiKey,
}: StepVelocityCredentialsProps) {
  const { currentTenant } = useTenant();

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-semibold tracking-tight sm:text-3xl lg:text-4xl text-[var(--sg-text)]">
          Configure the CLI
        </h2>
        <p className="mt-3 max-w-prose text-base lg:text-lg text-[var(--sg-text-muted)]">
          Point the Stategraph CLI at your server and set up your tenant.
        </p>
      </div>

      <div className="space-y-3">
        <div className="text-sm font-medium text-[var(--sg-text)]">
          1. Install the Stategraph CLI
        </div>
        <CodeBlock code="curl -fsSL https://get.stategraph.com/install.sh | sh" />
        <p className="text-xs text-[var(--sg-text-muted)]">
          Prefer a different install method? See{" "}
          <a
            href="https://stategraph.com/docs/cli"
            target="_blank"
            rel="noreferrer"
            className="text-[var(--sg-accent)] hover:underline"
          >
            stategraph.com/docs/cli
          </a>
          .
        </p>
      </div>

      <div className="space-y-3">
        <div className="text-sm font-medium text-[var(--sg-text)]">
          2. Point the CLI at Stategraph
        </div>
        <CodeBlock code={`${getApiBaseCommand()}\n${apiKeyCommand(apiKey)}`} />
      </div>

      <div className="space-y-3">
        <div className="text-sm font-medium text-[var(--sg-text)]">
          3. Select your tenant
        </div>
        <CodeBlock code={CLI_COMMANDS.listTenants} />
        <div className="text-xs text-[var(--sg-text-dim)]">Example output:</div>
        <CodeBlock code={tenantListExample(currentTenant?.name ?? "Default")} />
        <CodeBlock code={CLI_COMMANDS.exportTenantId} />
        <p className="text-xs text-[var(--sg-text-muted)]">
          Replace{" "}
          <code className="text-xs bg-[var(--sg-bg-2)] px-1 py-0.5 rounded">
            &lt;tenant-id&gt;
          </code>{" "}
          with the ID your own command printed, not the one in the example above.
          Set it once to skip{" "}
          <code className="text-xs bg-[var(--sg-bg-2)] px-1 py-0.5 rounded">
            --tenant
          </code>{" "}
          on every command.
        </p>
      </div>

      <div className="flex justify-between pt-2">
        <Button variant="outline" onClick={actions.prevStep}>
          <ArrowLeft className="h-4 w-4 mr-1" />
          Back
        </Button>
        <Button onClick={actions.nextStep}>
          Continue
          <ArrowRight className="h-4 w-4 ml-1" />
        </Button>
      </div>
    </div>
  );
}
