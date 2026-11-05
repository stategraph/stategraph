export const RANGE_PRESET_IDS = [
  "anytime",
  "last_hour",
  "last_24h",
  "last_7d",
  "last_30d",
  "custom",
] as const;
export type RangePreset = (typeof RANGE_PRESET_IDS)[number];

export interface RangePresetSpec {
  id: RangePreset;
  label: string;
  hoursAgo?: number;
}

export const RANGE_PRESETS: RangePresetSpec[] = [
  { id: "anytime", label: "Anytime" },
  { id: "last_hour", label: "Last hour", hoursAgo: 1 },
  { id: "last_24h", label: "Last 24 hours", hoursAgo: 24 },
  { id: "last_7d", label: "Last 7 days", hoursAgo: 24 * 7 },
  { id: "last_30d", label: "Last 30 days", hoursAgo: 24 * 30 },
  { id: "custom", label: "Custom range" },
];

export interface ResolvedRange {
  fromIso: string | undefined;
  toIso: string | undefined;
}

export function resolveRange(
  preset: RangePreset,
  customFrom: string,
  customTo: string,
): ResolvedRange {
  if (preset === "anytime") return { fromIso: undefined, toIso: undefined };
  if (preset === "custom") {
    return {
      fromIso: customFrom ? new Date(customFrom).toISOString() : undefined,
      toIso: customTo ? new Date(customTo).toISOString() : undefined,
    };
  }
  const spec = RANGE_PRESETS.find((p) => p.id === preset);
  if (!spec?.hoursAgo) return { fromIso: undefined, toIso: undefined };
  const fromIso = new Date(Date.now() - spec.hoursAgo * 3600 * 1000).toISOString();
  return { fromIso, toIso: undefined };
}
