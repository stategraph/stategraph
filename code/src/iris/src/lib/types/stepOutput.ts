/**
 * Workflow step output as returned by the work manifest outputs endpoint.
 *
 * The payload is free-form JSON built by the runner, so the fields below are the
 * ones the UI knows how to read rather than a closed schema. For a plan step the
 * runner sends both halves of the operation: `text` is the stdout of the
 * engine's plan command and `plan` is the stdout of its diff command.
 */

import type { TerraformJsonPlan } from './terraform';

/** The plan step's `resource_summary` payload: four count slots.
 *  The runner omits an unreported slot or sends it as null, so every field is
 *  optional and nullable, and the UI renders such a slot as `-` (the backend
 *  `count_str` convention). */
export interface ResourceSummary {
  imported?: number | null;
  created?: number | null;
  updated?: number | null;
  replaced?: number | null;
  deleted?: number | null;
}

export interface StepOutputPayload {
  text?: string;
  plan?: string;
  cmd?: string[];
  exit_code?: number;
  plan_text?: string;
  diff?: TerraformJsonPlan | string; // JSON plan data (object or string)
  format?: string | { type?: string; lang?: string };
  has_changes?: boolean;
  // Plan-step resource counts for the collapsed dirspace header line;
  // absent on legacy runners and no-change plans.
  resource_summary?: ResourceSummary;
  ignore_errors?: boolean;
  visible_on?: string;
  summary?: {
    total_monthly_cost?: number;
    diff_monthly_cost?: number;
    prev_monthly_cost?: number;
  };
  currency?: string;
  dirspaces?: Array<{
    dir: string;
    workspace: string;
    total_monthly_cost: number;
    diff_monthly_cost: number;
    prev_monthly_cost: number;
  }>;
  // Lite mode properties
  _isLiteMode?: boolean;
  _originalStep?: string;
  _loadTimestamp?: number;
  _loadError?: boolean;
}

export interface OutputItem {
  payload?: StepOutputPayload;
  scope?: {
    dir?: string;
    workspace?: string;
    type?: string;
  };
  step?: string;
  state?: string;
  ignore_errors?: boolean;
  idx?: number;
}
