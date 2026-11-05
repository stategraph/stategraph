import assert from "node:assert/strict";
import type { Capabilities } from "@/lib/api/client";
import { probeOrchestrationAvailability } from "./useOrchestrationAvailability";

function capabilities(orchestration: boolean): Capabilities {
  return {
    costs: { enabled: false },
    dedicated: { enabled: false },
    github_app: { configured: false, creatable: false, ready: false },
    orchestration: { enabled: orchestration },
    security: { enabled: false },
  };
}

const tests: Array<{ name: string; run: () => Promise<void> }> = [
  {
    name: "reports available when the server serves orchestration",
    run: async () => {
      const result = await probeOrchestrationAvailability(async () =>
        capabilities(true),
      );
      assert.deepEqual(result, { status: "available" });
    },
  },
  {
    name: "reports unavailable when the capability is off",
    run: async () => {
      const result = await probeOrchestrationAvailability(async () =>
        capabilities(false),
      );
      assert.deepEqual(result, { status: "unavailable" });
    },
  },
  {
    name: "keeps a failed capabilities load retryable",
    run: async () => {
      const result = await probeOrchestrationAvailability(async () => {
        throw new Error("network unavailable");
      });
      assert.deepEqual(result, {
        status: "error",
        message: "network unavailable",
      });
    },
  },
];

async function main(): Promise<void> {
  let failed = 0;
  for (const test of tests) {
    try {
      await test.run();
      console.log(`PASS: ${test.name}`);
    } catch (error) {
      failed += 1;
      console.error(`FAIL: ${test.name}`);
      console.error(error);
    }
  }
  process.exit(failed === 0 ? 0 : 1);
}

void main();
