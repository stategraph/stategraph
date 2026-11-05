import { parsePlanStdoutByAddress } from "./snippets";

const sample = `OpenTofu used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
  + create
  - destroy

OpenTofu will perform the following actions:

  # module.state_97e0a.null_resource.alpha will be destroyed
  # (because null_resource.alpha is not in configuration)
  - resource "null_resource" "alpha" {
      - id       = "7940..." -> null
      - triggers = {
          - "version" = "5"
        } -> null
    }

  # module.state_97e0a.module.network.null_resource.beta will be created
  + resource "null_resource" "beta" {
      + id       = (known after apply)
      + triggers = {
          + version = "1"
        }
    }

Plan: 1 to add, 0 to change, 1 to destroy.
`;

const out = parsePlanStdoutByAddress(sample);

interface TestCase {
  name: string;
  fn: () => boolean;
}

const tests: TestCase[] = [
  {
    name: "extracts two blocks",
    fn: () => out.size === 2,
  },
  {
    name: "address keys are wrapper-stripped",
    fn: () =>
      out.has("null_resource.alpha") &&
      out.has("module.network.null_resource.beta"),
  },
  {
    name: "destroy block contains header and body",
    fn: () => {
      const s = out.get("null_resource.alpha") ?? "";
      return (
        s.includes("will be destroyed") &&
        s.includes("(because null_resource.alpha is not in configuration)") &&
        s.includes('- resource "null_resource" "alpha"')
      );
    },
  },
  {
    name: "create block stops before the summary",
    fn: () => {
      const s = out.get("module.network.null_resource.beta") ?? "";
      return s.includes("will be created") && !s.includes("Plan:");
    },
  },
  {
    name: "empty input yields empty map",
    fn: () => parsePlanStdoutByAddress("").size === 0,
  },
  {
    name: "ignores the (because ...) follow-up as a block header",
    fn: () => !out.has("(because"),
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
