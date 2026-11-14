"use client";

import { useEffect, useState } from "react";
import { CheckCircle2, Circle, ExternalLink } from "lucide-react";
import { useAuth } from "@/components/auth";
import { Button } from "@/components/ui/button";
import { useDeepLinkRouter } from "@/hooks";
import { listTenantMembers } from "@/lib/api/client";
import { canManageUsersInTenant, isTenantAdmin } from "@/lib/api/capabilities";
import { executeWithRetry, runAcrossProviders } from "@/lib/mql/providers";
import { SETUP_COPY } from "@/lib/getting-started/setup-progress";
import {
  dismissNextSteps,
  nextSteps,
  nextStepsDismissed,
  showNextSteps,
  type NextStepFacts,
} from "@/lib/getting-started/next-steps";
import { driftRunPresenceQuery, repositoriesWithRunsQuery } from "@/app/(console)/home/mqlQueries";

const COPY = SETUP_COPY.nextSteps;

async function loadFacts(tenantId: string, canListMembers: boolean): Promise<NextStepFacts> {
  const members = canListMembers
    ? listTenantMembers(tenantId, { limit: 1 }).then(
        (page) => page.total_count,
        () => null,
      )
    : Promise.resolve(null);
  const runs = runAcrossProviders(async (p) => {
    const [drift, repositories] = await Promise.all([
      executeWithRetry(driftRunPresenceQuery(p)),
      executeWithRetry(repositoriesWithRunsQuery(p)),
    ]);
    return { drift: drift.length > 0, repositories: repositories.length };
  }).then(
    ({ results, failed }) => {
      const drift = results.some((r) => r.value.drift);
      const repositories = results.reduce((sum, r) => sum + r.value.repositories, 0);
      // A provider that failed may hold the drift run or the second repository.
      return {
        hasDriftRun: drift ? true : failed.length > 0 ? null : false,
        repositoriesWithRuns: repositories > 1 || failed.length === 0 ? repositories : null,
      };
    },
    () => ({ hasDriftRun: null, repositoriesWithRuns: null }),
  );
  const [memberCount, facts] = await Promise.all([members, runs]);
  return { memberCount, ...facts };
}

/** What a new tenant sets up next. Hidden once every known step is done or this browser dismissed
 *  it for the tenant. */
export function NextSteps({ tenantId }: { tenantId: string }) {
  const router = useDeepLinkRouter();
  const { user } = useAuth();
  const canListMembers =
    isTenantAdmin(user?.capabilities, tenantId) || canManageUsersInTenant(user?.capabilities, tenantId);
  // Home renders only in the browser, after sign-in, so the stored flag is readable on render.
  const [dismissedHere, setDismissedHere] = useState<string | null>(null);
  const isDismissed = dismissedHere === tenantId || nextStepsDismissed(tenantId);
  const [facts, setFacts] = useState<{ tenantId: string; value: NextStepFacts } | null>(null);

  useEffect(() => {
    if (isDismissed) return;
    let cancelled = false;
    const t = window.setTimeout(() => {
      void loadFacts(tenantId, canListMembers).then((value) => {
        if (!cancelled) setFacts({ tenantId, value });
      });
    }, 0);
    return () => {
      cancelled = true;
      window.clearTimeout(t);
    };
  }, [tenantId, canListMembers, isDismissed]);

  if (isDismissed || facts?.tenantId !== tenantId) return null;
  const steps = nextSteps(facts.value);
  if (!showNextSteps(steps, isDismissed)) return null;

  return (
    <section
      aria-labelledby="home-next-steps"
      className="rounded-[var(--sg-card-radius)] border border-[var(--sg-border)] bg-[var(--sg-bg-1)] px-5 py-4"
    >
      <div className="mb-3 flex items-center justify-between gap-3">
        <h2 id="home-next-steps" className="text-base font-semibold text-[var(--sg-text)]">
          {COPY.title}
        </h2>
        <Button
          variant="ghost"
          size="sm"
          onClick={() => {
            dismissNextSteps(tenantId);
            setDismissedHere(tenantId);
          }}
        >
          {COPY.dismiss}
        </Button>
      </div>
      <ul className="divide-y divide-[var(--sg-border)]">
        {steps.map((step) => {
          const copy = COPY.steps[step.id];
          return (
            <li key={step.id} className="flex flex-col gap-2 py-3 sm:flex-row sm:items-center sm:gap-4">
              <div className="flex min-w-0 flex-1 items-start gap-3">
                {step.done ? (
                  <CheckCircle2 aria-hidden="true" className="mt-0.5 h-4 w-4 shrink-0 text-[var(--sg-success)]" />
                ) : (
                  <Circle aria-hidden="true" className="mt-0.5 h-4 w-4 shrink-0 text-[var(--sg-text-dim)]" />
                )}
                <div className="min-w-0 space-y-0.5">
                  <div
                    className={
                      step.done
                        ? "text-sm font-medium text-[var(--sg-text-muted)]"
                        : "text-sm font-medium text-[var(--sg-text)]"
                    }
                  >
                    {copy.title}
                    {step.done ? <span className="sr-only"> ({COPY.done})</span> : null}
                  </div>
                  <p className="text-sm text-[var(--sg-text-muted)]">{copy.body}</p>
                </div>
              </div>
              {step.done ? (
                <span aria-hidden="true" className="pl-7 text-xs font-medium text-[var(--sg-success)] sm:pl-0">
                  {COPY.done}
                </span>
              ) : step.external ? (
                <Button asChild variant="outline" size="sm" className="ml-7 self-start sm:ml-0 sm:self-auto">
                  <a href={step.href} target="_blank" rel="noopener noreferrer">
                    {copy.action}
                    <ExternalLink className="h-4 w-4" />
                  </a>
                </Button>
              ) : (
                <Button
                  variant="outline"
                  size="sm"
                  className="ml-7 self-start sm:ml-0 sm:self-auto"
                  {...router.nav(step.href)}
                >
                  {copy.action}
                </Button>
              )}
            </li>
          );
        })}
      </ul>
    </section>
  );
}
