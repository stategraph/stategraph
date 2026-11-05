/**
 * Wizard state machine for the state import flow (CLI-driven import, verify,
 * then the orchestration engine switch when the tenant has orchestration).
 *
 * Persists the position to localStorage so the user can resume where they
 * left off. The API key and the engine-step result stay in memory only.
 */

"use client";

import { useState, useCallback, useEffect, useMemo } from "react";

// ---------------------------------------------------------------------------
// Step definitions
// ---------------------------------------------------------------------------

export type WizardStep =
  | "velocity-api-key"
  | "velocity-credentials"
  | "velocity-import"
  | "velocity-verify"
  | "velocity-orchestration"
  | "velocity-done";

export const ORCHESTRATION_STEP: WizardStep = "velocity-orchestration";

// ---------------------------------------------------------------------------
// Wizard state
// ---------------------------------------------------------------------------

export interface WizardState {
  /** Current step in the wizard */
  currentStep: WizardStep;
  /** Whether the tenant has orchestration set up, which adds the engine step */
  orchestration: boolean;
  /** The API key created in this session, shown again on later steps */
  apiKey: string | null;
  /** Whether the engine step was completed in this session */
  engineDone: boolean;
  /** Whether the wizard has been completed at least once */
  completed: boolean;
  /** Whether the wizard banner has been dismissed on the home page */
  dismissed: boolean;
}

const INITIAL_STATE: WizardState = {
  currentStep: "velocity-api-key",
  orchestration: false,
  apiKey: null,
  engineDone: false,
  completed: false,
  dismissed: false,
};

// ---------------------------------------------------------------------------
// Step ordering (for navigation)
// ---------------------------------------------------------------------------

const BASE_STEPS: WizardStep[] = [
  "velocity-api-key",
  "velocity-credentials",
  "velocity-import",
  "velocity-verify",
  "velocity-done",
];

const ORCHESTRATION_STEPS: WizardStep[] = [
  "velocity-api-key",
  "velocity-credentials",
  "velocity-import",
  "velocity-verify",
  "velocity-orchestration",
  "velocity-done",
];

export function getSteps(orchestration: boolean): WizardStep[] {
  return orchestration ? ORCHESTRATION_STEPS : BASE_STEPS;
}

/** The step list for a state: the engine step is present when the tenant has
 *  orchestration, and also while the wizard sits on that step, so a deep link
 *  into it renders before the installation list has answered. */
export function getStepsForState(state: Pick<WizardState, "orchestration" | "currentStep">): WizardStep[] {
  return getSteps(state.orchestration || state.currentStep === ORCHESTRATION_STEP);
}

export function getStepIndex(step: WizardStep, orchestration: boolean): number {
  return getSteps(orchestration).indexOf(step);
}

export function getStepCount(orchestration: boolean): number {
  return getSteps(orchestration).length;
}

export function isFirstStep(step: WizardStep, orchestration: boolean): boolean {
  return getStepIndex(step, orchestration) === 0;
}

export function isLastStep(step: WizardStep, orchestration: boolean): boolean {
  const steps = getSteps(orchestration);
  return getStepIndex(step, orchestration) === steps.length - 1;
}

/** The `?step=` query values the wizard accepts as an entry point. */
export function stepFromParam(value: string | null): WizardStep | null {
  return value === "orchestration" ? ORCHESTRATION_STEP : null;
}

// ---------------------------------------------------------------------------
// Step labels (for progress indicator)
// ---------------------------------------------------------------------------

export const STEP_LABELS: Record<WizardStep, string> = {
  "velocity-api-key": "API Key",
  "velocity-credentials": "Configure CLI",
  "velocity-import": "Import State",
  "velocity-verify": "Verify",
  "velocity-orchestration": "Orchestration",
  "velocity-done": "Done",
};

// ---------------------------------------------------------------------------
// Persistence
// ---------------------------------------------------------------------------

const STORAGE_KEY = "stategraph-getting-started";

function loadState(): WizardState {
  if (typeof window === "undefined") return INITIAL_STATE;
  try {
    const stored = localStorage.getItem(STORAGE_KEY);
    if (!stored) return INITIAL_STATE;
    const parsed = JSON.parse(stored);
    if (typeof parsed === "object" && parsed !== null && "currentStep" in parsed) {
      const knownSteps = new Set<string>(ORCHESTRATION_STEPS);
      if (!knownSteps.has(parsed.currentStep)) {
        return INITIAL_STATE;
      }
      return {
        ...INITIAL_STATE,
        currentStep: parsed.currentStep,
        completed: parsed.completed === true,
        dismissed: parsed.dismissed === true,
      };
    }
    return INITIAL_STATE;
  } catch {
    return INITIAL_STATE;
  }
}

function saveState(state: WizardState): void {
  if (typeof window === "undefined") return;
  try {
    const { currentStep, completed, dismissed } = state;
    localStorage.setItem(STORAGE_KEY, JSON.stringify({ currentStep, completed, dismissed }));
  } catch {
    // localStorage full or unavailable - ignore
  }
}

// ---------------------------------------------------------------------------
// Hook
// ---------------------------------------------------------------------------

export interface WizardActions {
  /** Go to the next step in the current flow */
  nextStep: () => void;
  /** Go to the previous step in the current flow */
  prevStep: () => void;
  /** Jump to a specific step */
  goToStep: (step: WizardStep) => void;
  /** Record whether the tenant has orchestration set up */
  setOrchestration: (orchestration: boolean) => void;
  /** Keep the API key created in this session for later steps */
  setApiKey: (apiKey: string) => void;
  /** Record that the engine step was completed */
  markEngineDone: () => void;
  /** Mark the wizard as completed */
  markCompleted: () => void;
  /** Dismiss the home page banner */
  dismissBanner: () => void;
  /** Reset the entire wizard back to initial state */
  reset: () => void;
}

export function useWizardState(): [WizardState, WizardActions] {
  const [state, setState] = useState<WizardState>(() => {
    if (typeof window !== 'undefined') return loadState();
    return INITIAL_STATE;
  });

  // Persist on every change
  useEffect(() => {
    saveState(state);
  }, [state]);

  const update = useCallback((partial: Partial<WizardState>) => {
    setState((prev) => ({ ...prev, ...partial }));
  }, []);

  const nextStep = useCallback(() => {
    setState((prev) => {
      const steps = getStepsForState(prev);
      const idx = steps.indexOf(prev.currentStep);
      if (idx < steps.length - 1) {
        return { ...prev, currentStep: steps[idx + 1] };
      }
      return prev;
    });
  }, []);

  const prevStep = useCallback(() => {
    setState((prev) => {
      const steps = getStepsForState(prev);
      const idx = steps.indexOf(prev.currentStep);
      if (idx > 0) {
        return { ...prev, currentStep: steps[idx - 1] };
      }
      return prev;
    });
  }, []);

  const goToStep = useCallback((step: WizardStep) => {
    update({ currentStep: step });
  }, [update]);

  const setOrchestration = useCallback((orchestration: boolean) => {
    update({ orchestration });
  }, [update]);

  const setApiKey = useCallback((apiKey: string) => {
    update({ apiKey });
  }, [update]);

  const markEngineDone = useCallback(() => {
    update({ engineDone: true });
  }, [update]);

  const markCompleted = useCallback(() => {
    update({ completed: true });
  }, [update]);

  const dismissBanner = useCallback(() => {
    update({ dismissed: true });
  }, [update]);

  const reset = useCallback(() => {
    setState((prev) => ({ ...INITIAL_STATE, orchestration: prev.orchestration }));
  }, []);

  const actions = useMemo<WizardActions>(
    () => ({
      nextStep,
      prevStep,
      goToStep,
      setOrchestration,
      setApiKey,
      markEngineDone,
      markCompleted,
      dismissBanner,
      reset,
    }),
    [nextStep, prevStep, goToStep, setOrchestration, setApiKey, markEngineDone, markCompleted, dismissBanner, reset],
  );

  return [state, actions];
}
