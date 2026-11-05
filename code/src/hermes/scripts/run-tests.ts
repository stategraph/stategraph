/**
 * `npm test`: runs every `*.test.ts` / `*.test.tsx` file of this package, each
 * in its own `npx tsx` process -- the tests are plain scripts that exit
 * non-zero on failure.
 *
 * Every file runs even after a failure, so one CI run reports all of them.
 */
import { spawnSync } from "node:child_process";
import { readdirSync } from "node:fs";
import { join, relative } from "node:path";

const ROOT = join(__dirname, "..");
const SKIPPED_DIRS = new Set(["node_modules", "out"]);
const TEST_FILE = /\.test\.tsx?$/;

function findTests(dir: string): string[] {
  return readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const path = join(dir, entry.name);
    if (entry.isDirectory()) {
      return entry.name.startsWith(".") || SKIPPED_DIRS.has(entry.name) ? [] : findTests(path);
    }
    return entry.isFile() && TEST_FILE.test(entry.name) ? [path] : [];
  });
}

const tests = findTests(ROOT)
  .map((path) => relative(ROOT, path))
  .sort();

// Finding nothing means discovery broke, not that there is nothing to test.
if (tests.length === 0) {
  console.error(`No *.test.ts files found under ${ROOT}`);
  process.exit(1);
}

console.log(`Running ${tests.length} test files with tsx...`);
const failed: string[] = [];
for (const test of tests) {
  console.log(`\n▶ ${test}`);
  const { status, error } = spawnSync("npx", ["tsx", test], { cwd: ROOT, stdio: "inherit" });
  if (error) console.error(error);
  if (status !== 0) failed.push(test);
}

if (failed.length > 0) {
  console.error(`\n${failed.length} of ${tests.length} test files failed:`);
  for (const test of failed) console.error(`  ${test}`);
  process.exit(1);
}
console.log(`\nAll ${tests.length} test files passed.`);
