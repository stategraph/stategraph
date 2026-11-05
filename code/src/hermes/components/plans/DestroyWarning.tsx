"use client";

import { AlertTriangle } from "lucide-react";

interface DestroyWarningProps {
  destroys: number;
}

export function DestroyWarning({ destroys }: DestroyWarningProps) {
  if (destroys < 1) return null;
  return (
    <div className="mt-3 flex items-center gap-2 px-3 py-2 rounded border border-[var(--sg-warning)] bg-[var(--sg-warning-bg)] text-[var(--sg-warning)] text-xs">
      <AlertTriangle className="w-3.5 h-3.5 shrink-0" />
      <span>
        This run will destroy <strong>{destroys}</strong>{" "}
        resource{destroys === 1 ? "" : "s"}.
      </span>
    </div>
  );
}
