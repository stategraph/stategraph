import { resolveRange, RANGE_PRESETS } from "./date-range";

interface TestCase {
  name: string;
  fn: () => boolean;
}

const tests: TestCase[] = [
  {
    name: "anytime returns no bounds",
    fn: () => {
      const r = resolveRange("anytime", "", "");
      return r.fromIso === undefined && r.toIso === undefined;
    },
  },
  {
    name: "anytime ignores stale custom inputs",
    fn: () => {
      const r = resolveRange("anytime", "2025-01-01T00:00", "2025-12-31T23:59");
      return r.fromIso === undefined && r.toIso === undefined;
    },
  },
  {
    name: "custom emits ISO timestamps when both bounds set",
    fn: () => {
      const r = resolveRange("custom", "2025-06-01T10:00", "2025-06-02T18:30");
      // The input is interpreted as local time and converted to UTC ISO.
      // Just check the round-trip is well-formed and from < to.
      return (
        typeof r.fromIso === "string" &&
        typeof r.toIso === "string" &&
        new Date(r.fromIso).getTime() < new Date(r.toIso).getTime()
      );
    },
  },
  {
    name: "custom with only from set leaves to undefined",
    fn: () => {
      const r = resolveRange("custom", "2025-06-01T10:00", "");
      return typeof r.fromIso === "string" && r.toIso === undefined;
    },
  },
  {
    name: "custom with both bounds empty returns no filter",
    fn: () => {
      const r = resolveRange("custom", "", "");
      return r.fromIso === undefined && r.toIso === undefined;
    },
  },
  {
    name: "last_hour sets fromIso ~1 hour ago, leaves to open",
    fn: () => {
      const r = resolveRange("last_hour", "", "");
      if (!r.fromIso || r.toIso !== undefined) return false;
      const deltaMs = Date.now() - new Date(r.fromIso).getTime();
      // Allow 0–10s of clock drift between Date.now() inside resolveRange and here.
      return deltaMs >= 3600 * 1000 - 10_000 && deltaMs <= 3600 * 1000 + 10_000;
    },
  },
  {
    name: "last_24h sets fromIso ~24 hours ago",
    fn: () => {
      const r = resolveRange("last_24h", "", "");
      if (!r.fromIso) return false;
      const deltaMs = Date.now() - new Date(r.fromIso).getTime();
      return Math.abs(deltaMs - 24 * 3600 * 1000) < 10_000;
    },
  },
  {
    name: "last_7d sets fromIso ~7 days ago",
    fn: () => {
      const r = resolveRange("last_7d", "", "");
      if (!r.fromIso) return false;
      const deltaMs = Date.now() - new Date(r.fromIso).getTime();
      return Math.abs(deltaMs - 7 * 24 * 3600 * 1000) < 10_000;
    },
  },
  {
    name: "last_30d sets fromIso ~30 days ago",
    fn: () => {
      const r = resolveRange("last_30d", "", "");
      if (!r.fromIso) return false;
      const deltaMs = Date.now() - new Date(r.fromIso).getTime();
      return Math.abs(deltaMs - 30 * 24 * 3600 * 1000) < 10_000;
    },
  },
  {
    name: "RANGE_PRESETS includes all preset ids",
    fn: () => {
      const ids = RANGE_PRESETS.map((p) => p.id);
      return (
        ids.includes("anytime") &&
        ids.includes("last_hour") &&
        ids.includes("last_24h") &&
        ids.includes("last_7d") &&
        ids.includes("last_30d") &&
        ids.includes("custom")
      );
    },
  },
];

let passed = 0;
let failed = 0;
for (const t of tests) {
  let ok = false;
  try {
    ok = t.fn();
  } catch (e) {
    console.error(`THREW: ${t.name}`, e);
  }
  if (ok) {
    passed++;
    console.log(`  ✓ ${t.name}`);
  } else {
    failed++;
    console.error(`  ✗ ${t.name}`);
  }
}
console.log(`\n${passed}/${tests.length} passed`);
process.exit(failed === 0 ? 0 : 1);
