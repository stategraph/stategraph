"use client";

import { cn } from "@/lib/utils";
import { RotateCcw, Check } from "lucide-react";
import { Button } from "@/components/ui/button";

interface WizardShellProps<Step extends string> {
  steps: readonly Step[];
  labels: Readonly<Record<Step, string>>;
  currentStep: Step;
  onReset: () => void;
  children: React.ReactNode;
}

export type WizardProgressState = "completed" | "current" | "upcoming";

export function wizardProgress<Step extends string>(
  steps: readonly Step[],
  currentStep: Step,
): WizardProgressState[] {
  const currentIndex = steps.indexOf(currentStep);
  return steps.map((_, index) => {
    if (index < currentIndex) return "completed";
    if (index === currentIndex) return "current";
    return "upcoming";
  });
}

/** Two columns on large screens: the step list on the left, the current step on the right. */
export function WizardShell<Step extends string>({
  steps,
  labels,
  currentStep,
  onReset,
  children,
}: WizardShellProps<Step>) {
  const progress = wizardProgress(steps, currentStep);
  const currentIndex = Math.max(0, steps.indexOf(currentStep));
  const position = `Step ${currentIndex + 1} of ${steps.length}`;
  const resetButton = (
    <Button variant="ghost" size="sm" onClick={onReset} className="text-[var(--sg-text-muted)]">
      <RotateCcw className="h-4 w-4 mr-1" />
      Start over
    </Button>
  );

  return (
    <div className="grid gap-6 lg:grid-cols-[minmax(240px,300px)_minmax(0,1fr)] lg:gap-14">
      {/* Phones and tablets: position, current step and a progress bar. */}
      <div className="space-y-2 lg:hidden">
        <div className="flex items-center justify-between gap-3">
          <span className="text-sm text-[var(--sg-text-muted)]">
            {position}
            {steps.length > 1 ? (
              <>
                {" "}
                <span aria-hidden="true">&middot;</span>{" "}
                <span className="font-semibold text-[var(--sg-text)]">{labels[currentStep]}</span>
              </>
            ) : null}
          </span>
          {resetButton}
        </div>
        {steps.length > 1 && (
          <div
            role="progressbar"
            aria-valuemin={1}
            aria-valuemax={steps.length}
            aria-valuenow={currentIndex + 1}
            aria-label={position}
            className="h-1.5 w-full overflow-hidden rounded-full bg-[var(--sg-bg-2)]"
          >
            <div
              className="h-full rounded-full bg-[var(--sg-accent)] transition-[width]"
              style={{ width: `${((currentIndex + 1) / steps.length) * 100}%` }}
            />
          </div>
        )}
      </div>

      {/* Large screens: the full step list. */}
      <aside className="hidden lg:sticky lg:top-6 lg:block lg:self-start">
        {steps.length > 1 && (
          <ol className="flex flex-col gap-1">
            {steps.map((step, index) => {
              const isCompleted = progress[index] === "completed";
              const isCurrent = progress[index] === "current";

              return (
                <li
                  key={step}
                  aria-current={isCurrent ? "step" : undefined}
                  className={cn(
                    "flex items-center gap-3 rounded-md px-3 py-2.5 text-base",
                    isCurrent
                      ? "border border-[var(--sg-border)] bg-[var(--sg-bg-1)] font-semibold text-[var(--sg-text)]"
                      : isCompleted
                        ? "text-[var(--sg-text)]"
                        : "text-[var(--sg-text-dim)]",
                  )}
                >
                  <span
                    aria-hidden="true"
                    className={cn(
                      "flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-sm font-medium",
                      isCompleted || isCurrent
                        ? "bg-[var(--sg-accent)] text-white"
                        : "bg-[var(--sg-bg-2)] text-[var(--sg-text-dim)]",
                    )}
                  >
                    {isCompleted ? <Check className="h-4 w-4" /> : index + 1}
                  </span>
                  <span>{labels[step]}</span>
                </li>
              );
            })}
          </ol>
        )}
        <div className="mt-6 flex items-center justify-between gap-3 px-3">
          <span className="text-sm text-[var(--sg-text-dim)]">{position}</span>
          {resetButton}
        </div>
      </aside>

      <section className="min-w-0">{children}</section>
    </div>
  );
}
