"use client";

import { type WizardActions } from "@/lib/getting-started";
import { CLI_COMMANDS, VERIFICATION_CHECKLIST } from "@/lib/getting-started/doc-constants";
import { Button } from "@/components/ui/button";
import { CodeBlock } from "./CodeBlock";
import { ArrowLeft, ArrowRight, CheckCircle2 } from "lucide-react";

// Render `code` spans from a plain-text checklist item as React nodes
// (avoids dangerouslySetInnerHTML for what is just backtick formatting).
function renderInlineCode(text: string) {
  return text.split(/(`[^`]+`)/g).map((part, i) =>
    part.startsWith("`") && part.endsWith("`") ? (
      <code key={i} className="text-xs bg-[var(--sg-bg-2)] px-1 py-0.5 rounded">
        {part.slice(1, -1)}
      </code>
    ) : (
      part
    ),
  );
}

interface StepVelocityVerifyProps {
  actions: WizardActions;
}

export function StepVelocityVerify({ actions }: StepVelocityVerifyProps) {
  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-semibold tracking-tight sm:text-3xl lg:text-4xl text-[var(--sg-text)]">
          Verify the import
        </h2>
        <p className="mt-3 max-w-prose text-base lg:text-lg text-[var(--sg-text-muted)]">
          Run a plan through Stategraph to confirm everything imported correctly.
        </p>
      </div>

      <div className="space-y-3">
        <div className="text-sm text-[var(--sg-text-muted)]">
          Run a plan using the Stategraph CLI:
        </div>
        <CodeBlock code={CLI_COMMANDS.velocityPlan} />
        <p className="text-xs text-[var(--sg-text-muted)]">
          A clean plan (no changes) confirms the import was successful.
        </p>
      </div>

      <div className="space-y-3">
        <div className="text-sm font-medium text-[var(--sg-text)]">
          Checklist
        </div>
        <div className="space-y-2">
          {VERIFICATION_CHECKLIST.map((item, i) => (
            <div key={i} className="flex items-start gap-2 text-sm text-[var(--sg-text-muted)]">
              <CheckCircle2 className="h-4 w-4 text-[var(--sg-text-dim)] flex-shrink-0 mt-0.5" />
              <span>{renderInlineCode(item)}</span>
            </div>
          ))}
        </div>
      </div>

      {/* Actions */}
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
