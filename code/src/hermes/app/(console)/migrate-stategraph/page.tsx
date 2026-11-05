"use client";

import { Suspense, useEffect, useMemo, useRef } from "react";
import { useSearchParams } from "next/navigation";
import { useSetupProgress, useTenant } from "@/contexts";
import {
  ORCHESTRATION_SETUP_HREF,
  orchestrationStatus,
  type SetupStatus,
} from "@/lib/getting-started/setup-progress";
import {
  getStepsForState,
  STEP_LABELS,
  stepFromParam,
  useWizardState,
} from "@/lib/getting-started";
import {
  SetupShell,
  WizardShell,
  StepMigrationApiKey,
  StepMigrationCredentials,
  StepVelocityImport,
  StepVelocityVerify,
  StepVelocityOrchestration,
  StepVelocityDone,
} from "@/components/getting-started";
import {
  useInstallationGate,
} from "../getting-started/useInstallationGate";
import type { VcsProvider } from "@/lib/vcs/links";

const ORCHESTRATE_HREF = ORCHESTRATION_SETUP_HREF;

function MigrateContent() {
  const [state, actions] = useWizardState();
  const searchParams = useSearchParams();
  const { currentTenant } = useTenant();
  const tenantId = currentTenant?.id ?? "";

  const { state: installations } = useInstallationGate(tenantId, {
    enabled: tenantId !== "",
  });
  const progress = useSetupProgress();
  const orchestrationState: SetupStatus = progress.isLoading ? "todo" : orchestrationStatus(progress);
  const orchestration = orchestrationState === "done";
  const provider = useMemo<VcsProvider | null>(() => {
    const providers = new Set(installations.rows.map((row) => row.provider));
    if (providers.size === 1 && providers.has("gitlab")) return "gitlab";
    if (providers.size === 1 && providers.has("github")) return "github";
    return null;
  }, [installations.rows]);

  useEffect(() => {
    actions.setOrchestration(orchestration);
  }, [actions, orchestration]);

  const didReset = useRef(false);
  const entryStep = stepFromParam(searchParams.get("step"));
  useEffect(() => {
    if (!didReset.current) {
      didReset.current = true;
      actions.reset();
    }
    if (entryStep) actions.goToStep(entryStep);
  }, [actions, entryStep]);

  // Same-route clicks (sidebar "Migrate", breadcrumb "Migrate") don't
  // remount the page, so the mount-time reset above doesn't fire. Catch
  // any anchor clicks that target /migrate-stategraph and reset.
  useEffect(() => {
    function onClick(e: MouseEvent) {
      const anchor = (e.target as HTMLElement | null)?.closest("a");
      if (!anchor) return;
      try {
        const url = new URL(anchor.href, window.location.origin);
        const path = url.pathname.replace(/\/$/, "");
        if (path === "/migrate-stategraph") {
          actions.reset();
          const step = stepFromParam(url.searchParams.get("step"));
          if (step) actions.goToStep(step);
        }
      } catch {
        // ignore non-URL hrefs (mailto:, javascript:, etc.)
      }
    }
    document.addEventListener("click", onClick);
    return () => document.removeEventListener("click", onClick);
  }, [actions]);

  const fromOrchestrate = searchParams.get("from") === "orchestrate";

  const renderStep = () => {
    switch (state.currentStep) {
      case "velocity-api-key":
        return (
          <StepMigrationApiKey
            actions={actions}
            backHref={fromOrchestrate ? ORCHESTRATE_HREF : null}
            backLabel="Back to orchestration setup"
          />
        );
      case "velocity-credentials":
        return <StepMigrationCredentials actions={actions} apiKey={state.apiKey} />;
      case "velocity-import":
        return <StepVelocityImport actions={actions} />;
      case "velocity-verify":
        return <StepVelocityVerify actions={actions} />;
      case "velocity-orchestration":
        return (
          <StepVelocityOrchestration
            actions={actions}
            provider={provider}
            apiKey={state.apiKey}
            tenantId={tenantId}
          />
        );
      case "velocity-done":
        return (
          <StepVelocityDone
            actions={actions}
            orchestration={orchestrationState}
            engineDone={state.engineDone}
            provider={provider}
          />
        );
    }
  };

  return (
    <SetupShell>
      <WizardShell
        steps={getStepsForState(state)}
        labels={STEP_LABELS}
        currentStep={state.currentStep}
        onReset={actions.reset}
      >
        {renderStep()}
      </WizardShell>
    </SetupShell>
  );
}

export default function MigratePage() {
  return (
    <Suspense
      fallback={
        <div className="flex items-center justify-center min-h-[400px]">
          <div className="text-[var(--sg-text-muted)]">Loading...</div>
        </div>
      }
    >
      <MigrateContent />
    </Suspense>
  );
}
