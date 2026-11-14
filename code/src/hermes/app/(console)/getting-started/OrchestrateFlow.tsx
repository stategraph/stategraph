"use client";

import { useEffect, useRef, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import {
  ArrowLeft,
  ArrowRight,
  Github,
  GitlabIcon,
  Loader2,
  RefreshCw,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { WizardShell } from "@/components/getting-started";
import { OrchestrationUnavailable } from "@/components/orchestration";
import { useSetupProgress, useTenant } from "@/contexts";
import { ENGINE_SETUP_HREF, STATE_SETUP_HREF } from "@/lib/getting-started/setup-progress";
import { useDeepLinkRouter } from "@/hooks";
import { pushGettingStartedEvent } from "@/lib/analytics";
import { providerName, type VcsProvider } from "@/lib/vcs/links";
import { useInstallationGate } from "./useInstallationGate";
import {
  fillOrchestrationSearchParams,
  isRepositorySlug,
  nextOrchestrationStepAfterRepository,
  orchestrationOverridesFromSearchParams,
  orchestrationRailSteps,
  orchestrationStepSearchParams,
  previousOrchestrationStep,
  resetOrchestrationSearchParams,
  searchParamsMatchTenant,
  useOrchestrationState,
  type CredentialStatus,
  type OrchestrationStep,
  type OrchestrationStateOverrides,
} from "@/lib/getting-started/orchestration-state";
import {
  DEMO_REPOSITORIES,
  ORCHESTRATION_COPY,
  orchestrationStepLabels,
} from "@/lib/getting-started/orchestration-constants";
import {
  ActionsStep,
  CredentialsStep,
  DoneStep,
  FirstChangeStep,
  ForkStep,
  PullRequestStep,
  StepHeading,
  WorkflowFileStep,
} from "./orchestrationSteps";
import type { OrchestrationAvailability } from "./useOrchestrationAvailability";

const COPY = ORCHESTRATION_COPY;

function OrchestrateFlowForTenant({
  tenantId,
  availability,
  onRetryAvailability,
  onBack,
  onConnect,
}: {
  tenantId: string;
  availability: OrchestrationAvailability;
  onRetryAvailability: () => void;
  onBack: () => void;
  onConnect: (provider: VcsProvider) => void;
}) {
  const router = useDeepLinkRouter();
  // Stable identity, unlike the deep-link router, which is rebuilt on every
  // query change; the fill effect below must not re-run on query changes.
  const nextRouter = useRouter();
  const searchParams = useSearchParams();
  const searchKey = searchParams.toString();
  const initialOverrides = orchestrationOverridesFromSearchParams(searchParams);
  const [state, actions] = useOrchestrationState(tenantId, initialOverrides);
  const { refresh: refreshSetupProgress } = useSetupProgress();
  const [planDetected, setPlanDetected] = useState(false);
  const pendingCredentials = useRef<{
    step: OrchestrationStep;
    status: CredentialStatus;
  } | null>(null);
  // A reset replaces the URL itself. Without this flag the URL-fill effect
  // below runs first, on the old query, and writes the old step back.
  const resetting = useRef(false);

  const currentStep = state.currentStep;
  const provider = state.provider;
  const repo = state.repo;
  const repositorySource = state.repositorySource;

  useEffect(() => {
    const overrides = orchestrationOverridesFromSearchParams(
      new URLSearchParams(searchKey),
    );
    if (
      pendingCredentials.current &&
      overrides.currentStep === pendingCredentials.current.step
    ) {
      overrides.credentials = pendingCredentials.current.status;
      pendingCredentials.current = null;
    }
    actions.update(overrides);
  }, [actions, searchKey]);

  // State to URL, on state changes only, against the live query. Running it on
  // query changes too would compare the new query with the state of the
  // previous commit and undo the navigation that just happened.
  useEffect(() => {
    if (resetting.current) {
      resetting.current = false;
      return;
    }
    const current = new URLSearchParams(window.location.search);
    const params = fillOrchestrationSearchParams(current, state);
    if (params.toString() !== current.toString()) {
      nextRouter.replace(`/getting-started?${params.toString()}`);
    }
  }, [nextRouter, state]);

  const goToStep = (
    nextStep: OrchestrationStep,
    overrides: Pick<
      OrchestrationStateOverrides,
      "provider" | "repo" | "repositorySource" | "credentials"
    > = {},
  ): void => {
    const nextProvider = overrides.provider !== undefined ? overrides.provider : provider;
    const nextRepo = overrides.repo !== undefined ? overrides.repo : repo;
    const nextRepositorySource =
      overrides.repositorySource ?? repositorySource;
    if (overrides.credentials) {
      pendingCredentials.current = {
        step: nextStep,
        status: overrides.credentials,
      };
    }
    // The URL is the only writer here. Updating the state as well would run
    // the fill effect on the old query and replace the pushed step with it.
    const params = orchestrationStepSearchParams(
      new URLSearchParams(window.location.search),
      nextStep,
      nextProvider,
      nextRepo,
      nextRepositorySource,
    );
    router.push(`/getting-started?${params.toString()}`);
  };

  const advance = (
    nextStep: OrchestrationStep,
    overrides: Pick<
      OrchestrationStateOverrides,
      "provider" | "repo" | "repositorySource" | "credentials"
    > = {},
  ): void => {
    pushGettingStartedEvent("getting_started_step_completed", {
      path: "orchestrate",
      step: currentStep,
      vcs_provider: overrides.provider ?? provider ?? undefined,
      repository_source: overrides.repositorySource ?? repositorySource,
    });
    if (nextStep === "done") {
      pushGettingStartedEvent("getting_started_completed", {
        path: "orchestrate",
        vcs_provider: overrides.provider ?? provider ?? undefined,
      });
    }
    goToStep(nextStep, overrides);
  };

  const previousStep = (): void => {
    const previous = previousOrchestrationStep(currentStep, repositorySource, provider);
    if (!previous) {
      onBack();
      return;
    }
    goToStep(previous);
  };

  const reset = (): void => {
    pendingCredentials.current = null;
    setPlanDetected(false);
    resetting.current = true;
    actions.reset();
    const params = resetOrchestrationSearchParams(new URLSearchParams(searchKey));
    router.replace(`/getting-started?${params.toString()}`);
  };

  const continueFromConnect = (nextProvider: VcsProvider): void => {
    goToStep("repo", {
      provider: nextProvider,
      repo: "",
      repositorySource: "own",
    });
  };

  const firstPlanDetected = (): void => {
    pushGettingStartedEvent("getting_started_first_run_detected", {
      path: "orchestrate",
      vcs_provider: provider ?? undefined,
      repository_source: repositorySource,
    });
    refreshSetupProgress();
    setPlanDetected(true);
    advance("done");
  };

  const setCredentials = (status: CredentialStatus): void => {
    advance("wait", { credentials: status });
  };

  const knownProvider: VcsProvider = provider ?? "github";

  const renderStep = () => {
    switch (currentStep) {
      case "connect":
        return (
          <AvailabilityConnectStep
            availability={availability}
            onRetry={onRetryAvailability}
            onBack={onBack}
            onConnect={onConnect}
            onContinue={continueFromConnect}
            onSetUpState={() => router.push("/migrate-stategraph?from=orchestrate")}
          />
        );
      case "repo":
        return (
          <RepositoryStep
            provider={provider}
            onBack={previousStep}
            onPickProvider={(nextProvider) =>
              actions.update({ provider: nextProvider, repositorySource: "own" })
            }
            onOwn={(nextProvider) =>
              advance(nextOrchestrationStepAfterRepository("own"), {
                provider: nextProvider,
                repo: "",
                repositorySource: "own",
              })
            }
            onDemo={(nextProvider) =>
              advance(nextOrchestrationStepAfterRepository("demo"), {
                provider: nextProvider,
                repo: "",
                repositorySource: "demo",
                credentials: "skipped",
              })
            }
          />
        );
      case "runnable":
        return (
          <WorkflowFileStep
            provider={provider}
            onBack={previousStep}
            onContinue={() => advance("credentials")}
          />
        );
      case "credentials":
        return (
          <CredentialsStep
            provider={provider}
            onBack={previousStep}
            onDone={() => setCredentials("done")}
            onSkip={() => setCredentials("skipped")}
          />
        );
      case "wait":
        return (
          <PullRequestStep
            provider={knownProvider}
            onBack={previousStep}
            onConfirm={() => advance("done")}
            onDetected={firstPlanDetected}
          />
        );
      case "fork":
        return (
          <ForkStepForProvider
            provider={knownProvider}
            repo={repo}
            onBack={previousStep}
            onConfirm={(nextRepo) =>
              advance(knownProvider === "github" ? "actions" : "change", { repo: nextRepo })
            }
          />
        );
      case "actions":
        return <ActionsStep onBack={previousStep} onConfirm={() => advance("change")} />;
      case "change":
        return (
          <FirstChangeStep
            provider={knownProvider}
            editUrl={
              knownProvider === "gitlab" && repo
                ? `https://gitlab.com/${repo}/-/edit/main/${COPY.change.editPath}`
                : undefined
            }
            onBack={previousStep}
            onConfirm={() => advance("done")}
            onDetected={firstPlanDetected}
          />
        );
      case "done":
        return (
          <DoneStep
            provider={knownProvider}
            planDetected={planDetected}
            onSetUpState={() => router.push(STATE_SETUP_HREF)}
            onSwitchEngine={() => router.push(ENGINE_SETUP_HREF)}
            onConsole={() => router.push("/")}
            onManageUsers={() => router.push("/settings/users")}
          />
        );
    }
  };

  return (
    <WizardShell
      steps={orchestrationRailSteps(provider, repositorySource)}
      labels={orchestrationStepLabels(provider)}
      currentStep={currentStep}
      onReset={reset}
    >
      {renderStep()}
    </WizardShell>
  );
}

export function OrchestrateFlow({
  availability,
  onRetryAvailability,
  onBack,
  onConnect,
}: {
  availability: OrchestrationAvailability;
  onRetryAvailability: () => void;
  onBack: () => void;
  onConnect: (provider: VcsProvider) => void;
}) {
  const { currentTenant, isLoading, error } = useTenant();
  const searchParams = useSearchParams();

  if (isLoading) {
    return (
      <div className="p-8 text-sm text-[var(--sg-text-muted)]">
        {COPY.loading}
      </div>
    );
  }

  if (error) {
    return (
      <div className="p-8 space-y-3" role="alert">
        <p className="text-sm font-medium text-[var(--sg-error)]">
          {COPY.tenantError}
        </p>
        <p className="text-sm text-[var(--sg-text-muted)]">{error}</p>
        <Button variant="outline" onClick={() => window.location.reload()}>
          {COPY.reload}
        </Button>
      </div>
    );
  }

  if (!currentTenant) {
    return (
      <div className="p-8 text-sm text-[var(--sg-text-muted)]">
        {COPY.noTenant}
      </div>
    );
  }

  // Hold the remount until the cleaned URL of a tenant switch commits, so the
  // new tenant never starts from the previous tenant's step, provider or repo.
  if (!searchParamsMatchTenant(searchParams, currentTenant.id)) {
    return (
      <div className="p-8 text-sm text-[var(--sg-text-muted)]">
        {COPY.loading}
      </div>
    );
  }

  return (
    <OrchestrateFlowForTenant
      key={currentTenant.id}
      tenantId={currentTenant.id}
      availability={availability}
      onRetryAvailability={onRetryAvailability}
      onBack={onBack}
      onConnect={onConnect}
    />
  );
}

function ProviderCard({
  provider,
  title,
  description,
  onConnect,
}: {
  provider: VcsProvider;
  title: string;
  description: string;
  onConnect: (provider: VcsProvider) => void;
}) {
  const Icon = provider === "github" ? Github : GitlabIcon;
  return (
    <button
      type="button"
      onClick={() => onConnect(provider)}
      className="group flex h-full w-full cursor-pointer flex-col gap-4 rounded-[var(--sg-card-radius)] border-2 border-[var(--sg-border)] bg-[var(--sg-bg-1)] p-5 text-left transition-colors hover:border-[var(--sg-accent)] hover:bg-[var(--sg-bg-2)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--sg-accent)] sm:gap-5 sm:p-8"
    >
      <span className="flex items-center gap-3">
        <Icon className="h-7 w-7 text-[var(--sg-accent)] sm:h-8 sm:w-8" />
        <span className="text-xl font-semibold text-[var(--sg-text)] sm:text-2xl">{title}</span>
        <ArrowRight className="ml-auto h-6 w-6 shrink-0 text-[var(--sg-text-muted)] transition-transform group-hover:translate-x-0.5" />
      </span>
      <span className="text-base text-[var(--sg-text-muted)] sm:text-lg">{description}</span>
    </button>
  );
}

function AvailabilityConnectStep({
  availability,
  onRetry,
  onBack,
  onConnect,
  onContinue,
  onSetUpState,
}: {
  availability: OrchestrationAvailability;
  onRetry: () => void;
  onBack: () => void;
  onConnect: (provider: VcsProvider) => void;
  onContinue: (provider: VcsProvider) => void;
  onSetUpState: () => void;
}) {
  // The page that led here has unmounted, so focus would drop to <body>: move
  // it to the notice, as every other step moves it to its heading. The shared
  // notice itself never takes focus, since other pages render it on load.
  const noticeRef = useRef<HTMLDivElement>(null);
  useEffect(() => {
    if (availability.status === "unavailable") noticeRef.current?.focus();
  }, [availability.status]);

  if (availability.status === "unavailable") {
    return (
      <div ref={noticeRef} tabIndex={-1} className="space-y-4 outline-none">
        <OrchestrationUnavailable />
        <div className="flex flex-col gap-2 sm:flex-row sm:justify-between">
          <Button variant="outline" onClick={onBack}>
            <ArrowLeft className="h-4 w-4" />
            {COPY.common.back}
          </Button>
          <div className="flex flex-col gap-2 sm:flex-row">
            <Button variant="outline" onClick={() => onContinue("github")}>
              {COPY.connect.githubContinue}
            </Button>
            <Button variant="outline" onClick={() => onContinue("gitlab")}>
              {COPY.connect.gitlabContinue}
            </Button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      {availability.status === "loading" ? (
        <div className="flex items-center gap-2 rounded-md border border-[var(--sg-border)] bg-[var(--sg-bg-2)] px-3 py-2 text-sm text-[var(--sg-text-muted)]" role="status">
          <Loader2 className="h-4 w-4 animate-spin" />
          {COPY.availability.checking}
        </div>
      ) : availability.status === "error" ? (
        <div className="space-y-2 rounded-md border border-[var(--sg-warning)]/30 bg-[var(--sg-warning)]/10 p-3" role="alert">
          <div className="text-sm font-medium text-[var(--sg-warning)]">
            {COPY.availability.errorTitle}
          </div>
          <code className="block break-words text-xs text-[var(--sg-text-muted)]">
            {availability.message}
          </code>
          <p className="text-xs text-[var(--sg-text-muted)]">
            {COPY.availability.errorBody}
          </p>
          <Button variant="outline" size="sm" onClick={onRetry}>
            <RefreshCw className="h-3.5 w-3.5" />
            {COPY.availability.retry}
          </Button>
        </div>
      ) : null}
      <ConnectStep onConnect={onConnect} onLinkedContinue={onContinue} onSetUpState={onSetUpState} />
    </div>
  );
}

function ConnectStep({
  onConnect,
  onLinkedContinue,
  onSetUpState,
}: {
  onConnect: (provider: VcsProvider) => void;
  onLinkedContinue: (provider: VcsProvider) => void;
  onSetUpState: () => void;
}) {
  const { currentTenant } = useTenant();
  const { state: linked } = useInstallationGate(currentTenant?.id ?? "", {
    enabled: currentTenant !== null,
  });
  const linkedProviders = Array.from(new Set(linked.rows.map((row) => row.provider))).filter(
    (p): p is VcsProvider => p === "github" || p === "gitlab",
  );
  return (
    <div className="space-y-6">
      <StepHeading title={COPY.connect.title} lead={COPY.connect.lead} />
      {linkedProviders.length > 0 ? (
        <div className="flex flex-wrap items-center justify-between gap-3 rounded-[var(--sg-card-radius)] border border-[var(--sg-success)]/30 bg-[var(--sg-success)]/10 px-4 py-3">
          <span className="text-sm text-[var(--sg-text)]">
            {linkedProviders.map(providerName).join(" and ")}{" "}
            {linkedProviders.length > 1 ? "installations are" : "installation is"} linked to this
            tenant.
          </span>
          <Button onClick={() => onLinkedContinue(linkedProviders[0])}>
            Continue to repository setup <ArrowRight className="h-4 w-4" />
          </Button>
        </div>
      ) : null}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <ProviderCard
          provider="github"
          title={COPY.connect.githubTitle}
          description={COPY.connect.githubDescription}
          onConnect={onConnect}
        />
        <ProviderCard
          provider="gitlab"
          title={COPY.connect.gitlabTitle}
          description={COPY.connect.gitlabDescription}
          onConnect={onConnect}
        />
      </div>
      <p className="text-xs text-[var(--sg-text-muted)]">{COPY.connect.adminHelp}</p>
      <div className="rounded-md border border-[var(--sg-border)] bg-[var(--sg-bg-2)] p-4 space-y-3">
        <div className="text-sm font-medium text-[var(--sg-text)]">{COPY.connect.ciTitle}</div>
        <p className="text-sm text-[var(--sg-text-muted)]">{COPY.connect.ciBody}</p>
        <Button variant="outline" onClick={onSetUpState}>
          {COPY.connect.ciAction} <ArrowRight className="h-4 w-4" />
        </Button>
      </div>
    </div>
  );
}

function RepositoryStep({
  provider,
  onBack,
  onPickProvider,
  onOwn,
  onDemo,
}: {
  provider: VcsProvider | null;
  onBack: () => void;
  onPickProvider: (provider: VcsProvider) => void;
  onOwn: (provider: VcsProvider) => void;
  onDemo: (provider: VcsProvider) => void;
}) {
  const known: VcsProvider = provider ?? "github";
  return (
    <div className="space-y-6">
      <StepHeading title={COPY.repo.title} lead={COPY.repo.lead[known]} />
      {provider === null ? (
        <fieldset className="space-y-2">
          <legend className="text-sm font-medium text-[var(--sg-text)]">
            {COPY.repo.providerLabel}
          </legend>
          <p className="text-xs text-[var(--sg-text-muted)]">{COPY.repo.providerRequirement}</p>
          <div className="flex gap-2">
            {(["github", "gitlab"] as const).map((value) => (
              <Button
                key={value}
                type="button"
                variant="outline"
                onClick={() => onPickProvider(value)}
              >
                {value === "github" ? COPY.repo.githubOption : COPY.repo.gitlabOption}
              </Button>
            ))}
          </div>
        </fieldset>
      ) : null}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <Card className="h-full gap-5 border-2">
          <CardHeader>
            <CardTitle className="text-xl">{COPY.repo.own.title}</CardTitle>
            <CardDescription className="text-base">{COPY.repo.own.body[known]}</CardDescription>
          </CardHeader>
          <CardContent className="mt-auto">
            <Button size="lg" onClick={() => onOwn(known)} disabled={provider === null}>
              {COPY.repo.own.action} <ArrowRight className="h-4 w-4" />
            </Button>
          </CardContent>
        </Card>
        <Card className="h-full gap-5 border-2">
          <CardHeader>
            <CardTitle className="text-xl">{COPY.repo.demo.title[known]}</CardTitle>
            <CardDescription className="text-base">{COPY.repo.demo.body[known]}</CardDescription>
          </CardHeader>
          <CardContent className="mt-auto">
            <Button size="lg" onClick={() => onDemo(known)} disabled={provider === null}>
              {COPY.repo.demo.action[known]} <ArrowRight className="h-4 w-4" />
            </Button>
          </CardContent>
        </Card>
      </div>
      <div>
        <Button variant="outline" onClick={onBack}>
          <ArrowLeft className="h-4 w-4" /> {COPY.common.back}
        </Button>
      </div>
    </div>
  );
}

function ForkStepForProvider({
  provider,
  repo,
  onBack,
  onConfirm,
}: {
  provider: VcsProvider;
  repo: string;
  onBack: () => void;
  onConfirm: (repo: string) => void;
}) {
  const [path, setPath] = useState(repo);
  const [error, setError] = useState<string | null>(null);

  if (provider === "github") {
    return <ForkStep provider="github" onBack={onBack} onConfirm={() => onConfirm("")} />;
  }

  const confirm = (): void => {
    const normalized = path.trim().replace(/^\/+|\/+$/g, "");
    if (
      !isRepositorySlug(normalized) ||
      normalized.toLowerCase() === DEMO_REPOSITORIES.gitlab.slug
    ) {
      setError(COPY.fork.pathInvalid);
      return;
    }
    setError(null);
    onConfirm(normalized);
  };

  return (
    <ForkStep
      provider="gitlab"
      path={{
        value: path,
        onChange: (value) => {
          setError(null);
          setPath(value);
        },
        error,
      }}
      onBack={onBack}
      onConfirm={confirm}
    />
  );
}
