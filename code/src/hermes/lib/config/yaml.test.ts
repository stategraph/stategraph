import assert from "node:assert";
import { toYaml } from "./yaml";

let failures = 0;
function test(name: string, fn: () => void) {
  try { fn(); console.log(`ok - ${name}`); }
  catch (e) { failures++; console.error(`FAIL - ${name}\n  ${e instanceof Error ? e.message : e}`); }
}

test("scalars and nesting", () => {
  assert.equal(
    toYaml({ enabled: true, engine: { name: "tofu", version: "1.10.3" } }),
    "enabled: true\nengine:\n  name: tofu\n  version: \"1.10.3\"",
  );
});

test("string lists", () => {
  assert.equal(toYaml({ tags: ["app", "infra"] }), "tags:\n  - app\n  - infra");
});

test("list of objects uses one dash per entry", () => {
  assert.equal(
    toYaml({ workflows: [{ tag_query: "dir:a", engine: { name: "custom" } }] }),
    'workflows:\n  - tag_query: "dir:a"\n    engine:\n      name: custom',
  );
});

test("empty collections stay inline", () => {
  assert.equal(toYaml({ all_of: [], gate: {} }), "all_of: []\ngate: {}");
});

test("values needing quotes are quoted", () => {
  // A bare "true"/number-like/indicator-bearing string must not read as another type.
  assert.equal(toYaml({ a: "true", b: "1.5", c: "0 3 * * *", d: "" }),
    'a: "true"\nb: "1.5"\nc: "0 3 * * *"\nd: ""');
});

test("keys needing quotes are quoted", () => {
  // "*" would read as an alias, "a: b" as a nested mapping, "a #b" loses its comment tail.
  assert.equal(
    toYaml({ dirs: { "*": { tags: ["x"] }, "a: b": 1, "a #b": 2, "": 3, "01": 4 } }),
    'dirs:\n  "*":\n    tags:\n      - x\n  "a: b": 1\n  "a #b": 2\n  "": 3\n  "01": 4',
  );
});

test("indicator-led and single-letter boolean strings are quoted", () => {
  assert.equal(toYaml({ a: "- x", b: "{a,b}", c: "y", d: "N", y: 1 }),
    'a: "- x"\nb: "{a,b}"\nc: "y"\nd: "N"\n"y": 1');
});

test("newlines and control characters are escaped", () => {
  assert.equal(toYaml({ cmd: ["bash", "-c", "echo a\necho b"], bell: "\u0007" }),
    'cmd:\n  - bash\n  - "-c"\n  - "echo a\\necho b"\nbell: "\\u0007"');
});

test("an empty collection as a list item's first value stays inline", () => {
  assert.equal(toYaml([{ x: [], w: 1 }, { z: {} }]), "- x: []\n  w: 1\n- z: {}");
});

test("plain identifiers stay unquoted", () => {
  assert.equal(toYaml({ dir: "infra/app", count: 3, ok: false, none: null }),
    "dir: infra/app\ncount: 3\nok: false\nnone: null");
});

if (failures > 0) process.exit(1);
