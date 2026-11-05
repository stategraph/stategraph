"use client";

import { useCallback, useState } from "react";
import { RefreshCw } from "lucide-react";

import { Button } from "@/components/ui/button";
import { calculateStateCost, PricingNotConfiguredError } from "@/lib/api/client";
import { pollTask } from "@/lib/tasks";
import { track } from "@/lib/analytics";

export interface RecalculateButtonProps {
  stateId: string;
  /** Called after a successful recompute so the page can refetch. */
  onDone?: () => void;
  className?: string;
}

/**
 * Kicks off a fresh cost snapshot for a state (POST .../costs/calculate),
 * polls the async task to completion, then calls `onDone` to refetch. Disabled
 * with a spinner while running; surfaces a 503 "pricing not configured" (and
 * other failures) as inline error text -- there is no toast system.
 */
export function RecalculateButton({ stateId, onDone, className }: RecalculateButtonProps) {
  const [running, setRunning] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const run = useCallback(async () => {
    setRunning(true);
    setError(null);
    try {
      const task = await calculateStateCost(stateId);
      const final = await pollTask(task.id);
      track("cost_recalculation_finished", { result: final.state });
      if (final.state === "completed") {
        onDone?.();
      } else {
        setError(`Recalculation ${final.state}.`);
      }
    } catch (e) {
      if (e instanceof PricingNotConfiguredError) {
        setError("Pricing service is not configured on this server.");
      } else {
        setError(e instanceof Error ? e.message : "Failed to recalculate cost.");
      }
    } finally {
      setRunning(false);
    }
  }, [stateId, onDone]);

  return (
    <div className={`flex items-center gap-2 ${className ?? ""}`}>
      {error && <span className="text-xs text-[var(--sg-error)] max-w-[260px]">{error}</span>}
      <Button variant="outline" size="sm" onClick={run} disabled={running}>
        <RefreshCw className={`w-4 h-4 mr-2 ${running ? "animate-spin" : ""}`} />
        {running ? "Recalculating…" : "Recalculate"}
      </Button>
    </div>
  );
}
