"use client";

import { type WizardActions } from "@/lib/getting-started";
import { CLI_COMMANDS } from "@/lib/getting-started/doc-constants";
import { Button } from "@/components/ui/button";
import { CodeBlock } from "./CodeBlock";
import { ArrowLeft, ArrowRight } from "lucide-react";

interface StepVelocityImportProps {
  actions: WizardActions;
}

export function StepVelocityImport({ actions }: StepVelocityImportProps) {
  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-semibold tracking-tight sm:text-3xl lg:text-4xl text-[var(--sg-text)]">
          Import your state
        </h2>
        <p className="mt-3 max-w-prose text-base lg:text-lg text-[var(--sg-text-muted)]">
          Pull your existing Terraform state and import it into Stategraph. This
          is a one-time operation. After this, Stategraph manages state through
          the CLI.
        </p>
      </div>

      <div className="space-y-3">
        <div className="text-sm font-medium text-[var(--sg-text)]">
          1. Navigate to your root module
        </div>
        <div className="text-sm text-[var(--sg-text-muted)]">
          Open a terminal in the directory containing your Terraform configuration files.
        </div>
      </div>

      <div className="space-y-3">
        <div className="text-sm font-medium text-[var(--sg-text)]">
          2. Pull your current state to a local file
        </div>
        <CodeBlock code={CLI_COMMANDS.pullState} />
      </div>

      <div className="space-y-3">
        <div className="text-sm font-medium text-[var(--sg-text)]">
          3. Import into Stategraph
        </div>
        <CodeBlock code={CLI_COMMANDS.importToVelocity} />
        <p className="text-xs text-[var(--sg-text-muted)]">
          Run{" "}
          <code className="text-xs bg-[var(--sg-bg-2)] px-1 py-0.5 rounded">
            stategraph import tf
          </code>{" "}
          from the root module directory and pass the path to the state file.
          If your Terraform configuration uses variables, pass the same{" "}
          <code className="text-xs bg-[var(--sg-bg-2)] px-1 py-0.5 rounded">
            --var-file
          </code>{" "}
          and{" "}
          <code className="text-xs bg-[var(--sg-bg-2)] px-1 py-0.5 rounded">
            --var
          </code>{" "}
          flags you use when running{" "}
          <code className="text-xs bg-[var(--sg-bg-2)] px-1 py-0.5 rounded">
            terraform plan
          </code>{" "}
          so that Stategraph correctly captures your variable definitions.
        </p>
      </div>

      <div className="rounded-md border border-[var(--sg-border-dim)] bg-[var(--sg-bg-2)] p-3 text-sm text-[var(--sg-text-muted)]">
        <span className="font-medium text-[var(--sg-text)]">
          Starting fresh?
        </span>{" "}
        If you don&apos;t have existing state, create an empty state instead:
        <div className="mt-2">
          <CodeBlock code={CLI_COMMANDS.createState} />
        </div>
      </div>

      <div className="space-y-3">
        <div className="text-sm font-medium text-[var(--sg-text)]">
          4. Commit the configuration
        </div>
        <p className="text-sm text-[var(--sg-text-muted)]">
          The import writes{" "}
          <code className="text-xs bg-[var(--sg-bg-2)] px-1 py-0.5 rounded">
            stategraph.json
          </code>{" "}
          next to your Terraform files. It tells the CLI which state this
          directory uses.
        </p>
        <CodeBlock code={CLI_COMMANDS.commitConfig} />
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
