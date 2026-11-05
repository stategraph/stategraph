import {
  buildPlanTree,
  splitAddress,
  stripStateWrapper,
  type PlanTreeNode,
} from "./tree";
import type { TxPlanOperation } from "@/lib/api/client";

interface TestCase {
  name: string;
  fn: () => boolean;
}

function op(address: string, operation: TxPlanOperation["operation"]): TxPlanOperation {
  return { address, operation };
}

function findChild(node: PlanTreeNode, label: string): PlanTreeNode | undefined {
  return node.children.find((c) => c.label === label);
}

const tests: TestCase[] = [
  {
    name: "splitAddress — root resource",
    fn: () => {
      const { modules, leaf } = splitAddress("aws_instance.web");
      return modules.length === 0 && leaf === "aws_instance.web";
    },
  },
  {
    name: "splitAddress — single module",
    fn: () => {
      const { modules, leaf } = splitAddress("module.foo.aws_instance.web");
      return modules.length === 1 && modules[0] === "foo" && leaf === "aws_instance.web";
    },
  },
  {
    name: "splitAddress — nested module + index",
    fn: () => {
      const { modules, leaf } = splitAddress("module.foo.module.bar.aws_instance.web[0]");
      return (
        modules.length === 2 &&
        modules[0] === "foo" &&
        modules[1] === "bar" &&
        leaf === "aws_instance.web[0]"
      );
    },
  },
  {
    name: "splitAddress — data source under module",
    fn: () => {
      const { modules, leaf } = splitAddress("module.foo.data.aws_caller.current");
      return (
        modules.length === 1 &&
        modules[0] === "foo" &&
        leaf === "data.aws_caller.current"
      );
    },
  },
  {
    name: "stripStateWrapper strips synthetic state module",
    fn: () => {
      return (
        stripStateWrapper("module.state_97e0a.null_resource.alpha") ===
        "null_resource.alpha"
      );
    },
  },
  {
    name: "stripStateWrapper leaves unwrapped addresses alone",
    fn: () => {
      return (
        stripStateWrapper("module.foo.aws_instance.web") ===
        "module.foo.aws_instance.web"
      );
    },
  },
  {
    name: "buildPlanTree — counts bubble up",
    fn: () => {
      const root = buildPlanTree([
        op("module.state_x.null_resource.alpha", "create"),
        op("module.state_x.null_resource.beta", "update"),
        op("module.state_x.null_resource.gamma", "destroy"),
      ]);
      const c = root.counts;
      return c.create === 1 && c.update === 1 && c.destroy === 1 && c.replace === 0;
    },
  },
  {
    name: "buildPlanTree — modules sort above resources",
    fn: () => {
      const root = buildPlanTree([
        op("aws_instance.zeta", "create"),
        op("module.foo.aws_instance.alpha", "create"),
      ]);
      return (
        root.children.length === 2 &&
        root.children[0].kind === "module" &&
        root.children[1].kind === "resource"
      );
    },
  },
  {
    name: "buildPlanTree — nested module aggregates",
    fn: () => {
      const root = buildPlanTree([
        op("module.foo.module.bar.aws_instance.x", "create"),
        op("module.foo.module.bar.aws_instance.y", "destroy"),
        op("module.foo.aws_instance.z", "update"),
      ]);
      const foo = findChild(root, "module.foo");
      if (!foo) return false;
      if (foo.counts.create !== 1 || foo.counts.update !== 1 || foo.counts.destroy !== 1)
        return false;
      const bar = findChild(foo, "module.bar");
      if (!bar) return false;
      return bar.counts.create === 1 && bar.counts.destroy === 1;
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
