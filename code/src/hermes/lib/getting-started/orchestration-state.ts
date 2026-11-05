"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import type { VcsProvider } from "@/lib/vcs/links";

export const ORCHESTRATION_STEPS = [
  "connect",
  "repo",
  "runnable",
  "credentials",
  "wait",
  "fork",
  "actions",
  "change",
  "done",
] as const;

export type OrchestrationStep = (typeof ORCHESTRATION_STEPS)[number];

export const ORCHESTRATION_OWN_STEPS: readonly OrchestrationStep[] = [
  "connect",
  "repo",
  "runnable",
  "credentials",
  "wait",
  "done",
];

export const ORCHESTRATION_GITHUB_FORK_STEPS: readonly OrchestrationStep[] = [
  "connect",
  "repo",
  "fork",
  "actions",
  "change",
  "done",
];

export const ORCHESTRATION_GITLAB_FORK_STEPS: readonly OrchestrationStep[] = [
  "connect",
  "repo",
  "fork",
  "change",
  "done",
];
export type CredentialStatus = "done" | "skipped";
export type RepositorySource = "own" | "demo";
export const DEMO_REPOSITORY_SEARCH_VALUE = "kick-the-tires";

export interface OrchestrationState {
  currentStep: OrchestrationStep;
  provider: VcsProvider | null;
  repo: string;
  repositorySource: RepositorySource;
  credentials: CredentialStatus | null;
}

export interface OrchestrationStateOverrides {
  currentStep?: OrchestrationStep;
  provider?: VcsProvider | null;
  repo?: string;
  repositorySource?: RepositorySource;
  credentials?: CredentialStatus | null;
}

export const INITIAL_ORCHESTRATION_STATE: OrchestrationState = {
  currentStep: "connect",
  provider: null,
  repo: "",
  repositorySource: "own",
  credentials: null,
};

interface StorageLike {
  getItem(key: string): string | null;
  setItem(key: string, value: string): void;
  removeItem(key: string): void;
}

const stepSet = new Set<string>(ORCHESTRATION_STEPS);

export function isOrchestrationStep(value: unknown): value is OrchestrationStep {
  return typeof value === "string" && stepSet.has(value);
}

export function isVcsProvider(value: unknown): value is VcsProvider {
  return value === "github" || value === "gitlab";
}

function isCredentialStatus(value: unknown): value is CredentialStatus {
  return value === "done" || value === "skipped";
}

export function isRepositorySource(value: unknown): value is RepositorySource {
  return value === "own" || value === "demo";
}

export function orchestrationStorageKey(tenantId: string): string {
  return `stategraph-orchestration-onboarding:${tenantId}`;
}

export function decodeOrchestrationState(value: unknown): OrchestrationState {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    return { ...INITIAL_ORCHESTRATION_STATE };
  }

  const record = value as Record<string, unknown>;
  return {
    currentStep: isOrchestrationStep(record.currentStep)
      ? record.currentStep
      : INITIAL_ORCHESTRATION_STATE.currentStep,
    provider: isVcsProvider(record.provider) ? record.provider : null,
    repo: typeof record.repo === "string" ? record.repo : "",
    repositorySource: isRepositorySource(record.repositorySource)
      ? record.repositorySource
      : INITIAL_ORCHESTRATION_STATE.repositorySource,
    credentials: isCredentialStatus(record.credentials) ? record.credentials : null,
  };
}

/** The state a mount starts from. A finished walkthrough does not resume at
 *  Done: without a step in the URL, Get started starts fresh. */
export function resumeOrchestrationState(
  stored: OrchestrationState,
  overrides: OrchestrationStateOverrides,
): OrchestrationState {
  const base =
    stored.currentStep === "done" && overrides.currentStep === undefined
      ? { ...INITIAL_ORCHESTRATION_STATE }
      : stored;
  return resolveOrchestrationState(base, overrides);
}

export function resolveOrchestrationState(
  stored: OrchestrationState,
  overrides: OrchestrationStateOverrides,
): OrchestrationState {
  return {
    currentStep: overrides.currentStep ?? stored.currentStep,
    provider: overrides.provider !== undefined ? overrides.provider : stored.provider,
    repo: overrides.repo !== undefined ? overrides.repo : stored.repo,
    repositorySource: overrides.repositorySource ?? stored.repositorySource,
    credentials:
      overrides.credentials !== undefined ? overrides.credentials : stored.credentials,
  };
}

function browserStorage(): StorageLike | null {
  if (typeof window === "undefined") return null;
  try {
    return window.localStorage;
  } catch {
    return null;
  }
}

interface SearchParamsLike {
  get(name: string): string | null;
  has(name: string): boolean;
}

export function orchestrationOverridesFromSearchParams(
  searchParams: SearchParamsLike,
): OrchestrationStateOverrides {
  const rawStep = searchParams.get("step");
  const rawProvider = searchParams.get("provider");
  const demoSelected =
    searchParams.get("demo") === DEMO_REPOSITORY_SEARCH_VALUE;
  const hasExplicitRepository =
    searchParams.has("provider") || searchParams.has("repo");
  return {
    ...(isOrchestrationStep(rawStep) ? { currentStep: rawStep } : {}),
    ...(isVcsProvider(rawProvider) ? { provider: rawProvider } : {}),
    ...(searchParams.has("repo") ? { repo: searchParams.get("repo") ?? "" } : {}),
    ...(demoSelected
      ? { repositorySource: "demo" as const }
      : hasExplicitRepository
        ? { repositorySource: "own" as const }
        : {}),
  };
}

export function fillOrchestrationSearchParams(
  searchParams: URLSearchParams,
  state: OrchestrationState,
): URLSearchParams {
  const next = new URLSearchParams(searchParams);
  if (!isOrchestrationStep(next.get("step"))) next.set("step", state.currentStep);

  if (!isVcsProvider(next.get("provider"))) {
    if (state.provider) next.set("provider", state.provider);
    else next.delete("provider");
  }

  if (!next.has("repo") && state.repo) next.set("repo", state.repo);
  if (state.repositorySource === "demo") {
    next.set("demo", DEMO_REPOSITORY_SEARCH_VALUE);
  } else {
    next.delete("demo");
  }
  return next;
}

export function orchestrationStepSearchParams(
  searchParams: URLSearchParams,
  step: OrchestrationStep,
  provider: VcsProvider | null,
  repo: string,
  repositorySource: RepositorySource = "own",
): URLSearchParams {
  const next = new URLSearchParams(searchParams);
  next.set("path", "orchestrate");
  next.set("step", step);
  if (provider) next.set("provider", provider);
  else next.delete("provider");
  next.set("repo", repo);
  if (repositorySource === "demo") {
    next.set("demo", DEMO_REPOSITORY_SEARCH_VALUE);
  } else {
    next.delete("demo");
  }
  return next;
}

export function resetOrchestrationSearchParams(searchParams: URLSearchParams): URLSearchParams {
  const next = new URLSearchParams(searchParams);
  next.set("path", "orchestrate");
  next.set("step", "connect");
  next.delete("provider");
  next.delete("repo");
  next.delete("demo");
  return next;
}

export function stripTenantOrchestrationSearchParams(
  searchParams: URLSearchParams,
): URLSearchParams {
  const next = new URLSearchParams(searchParams);
  next.delete("step");
  next.delete("provider");
  next.delete("repo");
  next.delete("demo");
  return next;
}

export function isLiveOrchestrationTenantChange(
  pathname: string,
  searchParams: SearchParamsLike,
  nextTenantId: string,
): boolean {
  const previousTenantId = searchParams.get("tenant");
  return (
    previousTenantId !== null &&
    previousTenantId !== nextTenantId &&
    pathname.replace(/\/+$/, "") === "/getting-started" &&
    searchParams.get("path") === "orchestrate"
  );
}

/** Whether the URL belongs to [tenantId]. A tenant switch commits the new
 *  tenant before Next applies the cleaned URL (its patched replaceState runs
 *  inside a transition), so for one render the URL still carries the previous
 *  tenant's answers. A URL without a tenant param is a user's own deep link. */
export function searchParamsMatchTenant(searchParams: SearchParamsLike, tenantId: string): boolean {
  const urlTenant = searchParams.get("tenant");
  return urlTenant === null || urlTenant === tenantId;
}

export function loadOrchestrationState(
  tenantId: string,
  storage: StorageLike | null = browserStorage(),
): OrchestrationState {
  if (!storage) return { ...INITIAL_ORCHESTRATION_STATE };
  try {
    const value = storage.getItem(orchestrationStorageKey(tenantId));
    return value ? decodeOrchestrationState(JSON.parse(value)) : { ...INITIAL_ORCHESTRATION_STATE };
  } catch {
    return { ...INITIAL_ORCHESTRATION_STATE };
  }
}

export function saveOrchestrationState(
  tenantId: string,
  state: OrchestrationState,
  storage: StorageLike | null = browserStorage(),
): void {
  if (!storage) return;
  try {
    storage.setItem(orchestrationStorageKey(tenantId), JSON.stringify(state));
  } catch {
    // Storage can be disabled or full. URL state still keeps the flow usable.
  }
}

export function clearOrchestrationState(
  tenantId: string,
  storage: StorageLike | null = browserStorage(),
): void {
  if (!storage) return;
  try {
    storage.removeItem(orchestrationStorageKey(tenantId));
  } catch {
    // Storage can be disabled. The in-memory reset still succeeds.
  }
}

export function isRepositorySlug(value: string): boolean {
  return /^[^/\s]+(?:\/[^/\s]+)+$/.test(value.trim());
}

export function orchestrationRailSteps(
  provider: VcsProvider | null,
  repositorySource: RepositorySource,
): readonly OrchestrationStep[] {
  if (repositorySource !== "demo") return ORCHESTRATION_OWN_STEPS;
  return provider === "gitlab"
    ? ORCHESTRATION_GITLAB_FORK_STEPS
    : ORCHESTRATION_GITHUB_FORK_STEPS;
}

export function nextOrchestrationStepAfterRepository(
  repositorySource: RepositorySource,
): OrchestrationStep {
  return repositorySource === "demo" ? "fork" : "runnable";
}

export function previousOrchestrationStep(
  step: OrchestrationStep,
  repositorySource: RepositorySource = "own",
  provider: VcsProvider | null = null,
): OrchestrationStep | null {
  const rail = orchestrationRailSteps(provider, repositorySource);
  const index = rail.indexOf(step);
  return index > 0 ? rail[index - 1] : null;
}

export interface OrchestrationActions {
  update: (partial: OrchestrationStateOverrides) => void;
  goToStep: (step: OrchestrationStep) => void;
  setProvider: (provider: VcsProvider | null) => void;
  setRepo: (repo: string) => void;
  setRepositorySource: (repositorySource: RepositorySource) => void;
  setCredentials: (credentials: CredentialStatus | null) => void;
  reset: () => void;
}

export function useOrchestrationState(
  tenantId: string,
  initialOverrides: OrchestrationStateOverrides = {},
): [OrchestrationState, OrchestrationActions] {
  const [state, setState] = useState<OrchestrationState>(() =>
    resumeOrchestrationState(loadOrchestrationState(tenantId), initialOverrides),
  );

  useEffect(() => {
    saveOrchestrationState(tenantId, state);
  }, [state, tenantId]);

  const update = useCallback((partial: OrchestrationStateOverrides): void => {
    setState((previous) => {
      const next = resolveOrchestrationState(previous, partial);
      return next.currentStep === previous.currentStep &&
        next.provider === previous.provider &&
        next.repo === previous.repo &&
        next.repositorySource === previous.repositorySource &&
        next.credentials === previous.credentials
        ? previous
        : next;
    });
  }, []);

  const goToStep = useCallback((currentStep: OrchestrationStep): void => {
    update({ currentStep });
  }, [update]);

  const setProvider = useCallback((provider: VcsProvider | null): void => {
    update({ provider });
  }, [update]);

  const setRepo = useCallback((repo: string): void => {
    update({ repo });
  }, [update]);

  const setRepositorySource = useCallback((repositorySource: RepositorySource): void => {
    update({ repositorySource });
  }, [update]);

  const setCredentials = useCallback((credentials: CredentialStatus | null): void => {
    update({ credentials });
  }, [update]);

  const reset = useCallback((): void => {
    clearOrchestrationState(tenantId);
    setState({ ...INITIAL_ORCHESTRATION_STATE });
  }, [tenantId]);

  const actions = useMemo<OrchestrationActions>(
    () => ({
      update,
      goToStep,
      setProvider,
      setRepo,
      setRepositorySource,
      setCredentials,
      reset,
    }),
    [
      goToStep,
      reset,
      setCredentials,
      setProvider,
      setRepo,
      setRepositorySource,
      update,
    ],
  );

  return [state, actions];
}
