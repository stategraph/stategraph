import { classifyLine } from "./PlanOutput";

interface TestCase {
  name: string;
  fn: () => boolean;
}

const tests: TestCase[] = [
  {
    name: "create line is classified create",
    fn: () => classifyLine("  + resource \"aws_instance\" \"web\" {").kind === "create",
  },
  {
    name: "destroy line is classified destroy",
    fn: () => classifyLine("  - id = \"abc\"").kind === "destroy",
  },
  {
    name: "update line is classified update",
    fn: () => classifyLine("  ~ triggers = {").kind === "update",
  },
  {
    name: "comment line is classified comment",
    fn: () =>
      classifyLine("  # module.foo.aws_instance.web will be created").kind === "comment",
  },
  {
    name: "-/+ replace line is classified replace",
    fn: () => classifyLine("-/+ resource \"null_resource\" \"x\" {").kind === "replace",
  },
  {
    name: "+/- replace line is classified replace",
    fn: () => classifyLine("+/- resource \"null_resource\" \"x\" {").kind === "replace",
  },
  {
    name: "intro paragraph has no kind",
    fn: () => classifyLine("OpenTofu used the selected providers…").kind === null,
  },
  {
    name: "summary line has no kind",
    fn: () => classifyLine("Plan: 2 to add, 0 to change, 0 to destroy.").kind === null,
  },
  {
    name: "deeply indented attr still picks up symbol",
    fn: () => classifyLine("          + version = \"1\"").kind === "create",
  },
  {
    name: "empty line yields no kind",
    fn: () => classifyLine("").kind === null,
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
