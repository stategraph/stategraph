"use client";

import { useCallback, useState } from "react";
import { RefreshCw } from "lucide-react";

import { Button } from "@/components/ui/button";
import { triggerStateSecurityScan } from "@/lib/api/client";
import { pollTask } from "@/lib/tasks";
import { track } from "@/lib/analytics";

export interface ScanButtonProps {
  stateId: string;
  /** Called after a scan completes so the page can refetch its findings. */
  onDone?: () => void;
  className?: string;
}

/**
 * Kicks off a fresh current security scan for a state
 * (POST .../security/scan), polls the async task to completion, then calls
 * `onDone` so the page can refetch. Disabled with a spinner while running;
 * surfaces failures as inline error text (there is no toast system). Mirrors
 * the cost {@link RecalculateButton}. The caller only mounts this when the
 * security capability is enabled, so a 503 is not expected in normal use.
 */
export function ScanButton({ stateId, onDone, className }: ScanButtonProps) {
  const [running, setRunning] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const run = useCallback(async () => {
    setRunning(true);
    setError(null);
    try {
      const task = await triggerStateSecurityScan(stateId);
      const final = await pollTask(task.id);
      track("security_scan_finished", { result: final.state });
      if (final.state === "completed") {
        onDone?.();
      } else {
        setError(`Scan ${final.state}.`);
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to start scan.");
    } finally {
      setRunning(false);
    }
  }, [stateId, onDone]);

  return (
    <div className={`flex items-center gap-2 ${className ?? ""}`}>
      {error && (
        <span className="text-xs text-[var(--sg-error)] max-w-[260px]">
          {error}
        </span>
      )}
      <Button variant="outline" size="sm" onClick={run} disabled={running}>
        <RefreshCw className={`w-4 h-4 mr-2 ${running ? "animate-spin" : ""}`} />
        {running ? "Scanning…" : "Scan now"}
      </Button>
    </div>
  );
}
