"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { Calendar, X } from "lucide-react";
import { RANGE_PRESETS, type RangePreset } from "@/lib/plan/date-range";

interface Props {
  preset: RangePreset;
  customFrom: string;
  customTo: string;
  onPresetChange: (next: RangePreset) => void;
  onCustomFromChange: (next: string) => void;
  onCustomToChange: (next: string) => void;
}

export function RunsDateRangeFilter({
  preset,
  customFrom,
  customTo,
  onPresetChange,
  onCustomFromChange,
  onCustomToChange,
}: Props) {
  const active = preset !== "anytime";
  const showCustom = preset === "custom";

  // For presets, show a read-only "From" hint that resolves at render time so
  // the user can see what window they're actually looking at. Re-resolve every
  // minute so the displayed value doesn't drift while the page is open.
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    if (preset === "anytime" || preset === "custom") return;
    const id = window.setInterval(() => setNow(Date.now()), 60_000);
    return () => window.clearInterval(id);
  }, [preset]);

  const fromHint = useMemo(() => {
    if (preset === "anytime" || preset === "custom") return null;
    const spec = RANGE_PRESETS.find((p) => p.id === preset);
    if (!spec?.hoursAgo) return null;
    return new Date(now - spec.hoursAgo * 3600 * 1000);
  }, [preset, now]);

  const clear = useCallback(() => {
    onPresetChange("anytime");
    onCustomFromChange("");
    onCustomToChange("");
  }, [onPresetChange, onCustomFromChange, onCustomToChange]);

  return (
    <div className="flex items-center gap-2 text-xs">
      <Calendar className="w-3.5 h-3.5 text-[var(--sg-text-muted)]" />
      <select
        value={preset}
        onChange={(e) => onPresetChange(e.target.value as RangePreset)}
        aria-label="Filter by date range"
        className="px-2 py-1 text-xs bg-[var(--sg-bg-2)] border border-[var(--sg-border)] rounded text-[var(--sg-text)] cursor-pointer"
      >
        {RANGE_PRESETS.map((p) => (
          <option key={p.id} value={p.id}>
            {p.label}
          </option>
        ))}
      </select>
      {showCustom && (
        <>
          <label className="flex items-center gap-1 text-[var(--sg-text-muted)]">
            <span>from</span>
            <input
              type="datetime-local"
              value={customFrom}
              onChange={(e) => onCustomFromChange(e.target.value)}
              className="px-2 py-1 text-xs bg-[var(--sg-bg-2)] border border-[var(--sg-border)] rounded text-[var(--sg-text)]"
            />
          </label>
          <label className="flex items-center gap-1 text-[var(--sg-text-muted)]">
            <span>to</span>
            <input
              type="datetime-local"
              value={customTo}
              onChange={(e) => onCustomToChange(e.target.value)}
              className="px-2 py-1 text-xs bg-[var(--sg-bg-2)] border border-[var(--sg-border)] rounded text-[var(--sg-text)]"
            />
          </label>
        </>
      )}
      {!showCustom && fromHint && (
        <span
          className="text-[var(--sg-text-dim)]"
          title={`Since ${fromHint.toLocaleString()}`}
        >
          since {fromHint.toLocaleString()}
        </span>
      )}
      {active && (
        <button
          type="button"
          onClick={clear}
          title="Clear date filter"
          className="p-1 rounded text-[var(--sg-text-muted)] hover:text-[var(--sg-text)] hover:bg-[var(--sg-bg-2)] cursor-pointer"
        >
          <X className="w-3 h-3" />
        </button>
      )}
    </div>
  );
}
