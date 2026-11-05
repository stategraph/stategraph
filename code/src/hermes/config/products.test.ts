import assert from "node:assert";
import { readdirSync, readFileSync, existsSync } from "node:fs";
import { join } from "node:path";
import {
  accountNav,
  getProductByHref,
  getProductById,
  mainNav,
  navEntryActive,
  type NavEntry,
  type ProductId,
} from "./products";

let failures = 0;
function test(name: string, fn: () => void) {
  try {
    fn();
    console.log(`ok - ${name}`);
  } catch (e) {
    failures++;
    console.error(`FAIL - ${name}\n  ${e instanceof Error ? e.message : e}`);
  }
}

const allNav: NavEntry[] = [...mainNav, ...accountNav];

/** Assert a pathname lights exactly one nav entry, the expected one. */
function litBy(pathname: string, expectedId: string) {
  const lit = allNav.filter((e) => navEntryActive(e, pathname)).map((e) => e.product.id);
  assert.deepEqual(lit, [expectedId], `${pathname} lit ${JSON.stringify(lit)}`);
}

test("every route lights exactly one nav entry", () => {
  litBy("/", "home");
  litBy("/orchestration", "orchestration");
  // Orchestration screens are its nav children
  litBy("/pull-requests", "orchestration");
  litBy("/repositories", "orchestration");
  litBy("/repositories/detail", "orchestration");
  litBy("/workspaces", "orchestration");
  litBy("/workspaces/detail", "orchestration");
  litBy("/audit", "orchestration");
  litBy("/drift", "orchestration");
  // Orchestration hosts the runs routes as standalone pages
  litBy("/runs", "orchestration");
  litBy("/runs/wm", "orchestration");
  litBy("/runs/detail", "orchestration");
  // ...and the Stacks screen with its per-stack page
  litBy("/stacks", "orchestration");
  litBy("/stacks/detail", "orchestration");
  // Inventory screens are its nav children
  litBy("/instances", "inventory");
  litBy("/states", "inventory");
  litBy("/states/detail", "inventory");
  litBy("/modules", "inventory");
  litBy("/types", "inventory");
  litBy("/gap-analysis", "inventory");
  litBy("/inventory", "inventory");
  // Insights
  litBy("/timeline", "insights");
  litBy("/state-changes", "insights");
  litBy("/timeline/detail", "insights");
  litBy("/search", "insights");
  litBy("/blast-radius", "insights");
  litBy("/graph-explorer", "insights");
  litBy("/insights", "insights");
  // Analyze — /dashboard (viewer) and /dashboards (index) are distinct routes
  litBy("/query", "analyze");
  litBy("/dashboards", "analyze");
  litBy("/dashboard", "analyze");
  litBy("/visualization", "analyze");
  litBy("/analyze", "analyze");
  // Security
  litBy("/security", "security");
  litBy("/security/findings", "security");
  litBy("/security/findings/detail", "security");
  // Costs
  litBy("/costs", "costs");
  litBy("/cost-overview", "costs");
  litBy("/cost-explorer", "costs");
  litBy("/cost-analysis", "costs");
  litBy("/cost-budgets", "costs");
  litBy("/cost-policies", "costs");
  litBy("/cost-optimization", "costs");
  litBy("/billing-connections", "costs");
  // Footer
  litBy("/getting-started", "getting-started");
  litBy("/support", "support");
  litBy("/settings", "settings");
  litBy("/migrate-stategraph", "getting-started");
});

test("every main nav product has a sidebar tagline", () => {
  // The sidebar renders a second line under each main nav label; a product
  // added to mainNav without one shows up as a bare single-line row.
  const missing = mainNav.filter((e) => !e.product.navTagline).map((e) => e.product.id);
  assert.deepEqual(missing, [], `mainNav entries without navTagline: ${missing.join(", ")}`);
});

test("prefix matching respects segment boundaries", () => {
  // A hypothetical /insight route must not light Insights, and /statesman
  // must not light States.
  const insights = mainNav.find((e) => e.product.id === "insights")!;
  const inventory = mainNav.find((e) => e.product.id === "inventory")!;
  assert.equal(navEntryActive(insights, "/insight"), false);
  // /statesman must not light Inventory via its States child.
  assert.equal(navEntryActive(inventory, "/statesman"), false);
  assert.equal(navEntryActive(inventory, "/states/inspect"), true);
});

test("every console route directory is lit or explicitly exempt", () => {
  // Routes that deliberately light no nav entry. Adding a route directory
  // without either wiring it into mainNav/accountNav or listing it here
  // fails this test.
  const exempt = new Set([
    "/home", // pure redirect to "/"; the sidebar links to "/" only
    "/provision", // reached from the migrate flow, not the sidebar
  ]);
  const consoleDir = join(__dirname, "..", "app", "(console)");
  const routes = readdirSync(consoleDir, { withFileTypes: true })
    .filter((d) => d.isDirectory() && existsSync(join(consoleDir, d.name, "page.tsx")))
    .map((d) => `/${d.name}`);
  assert.ok(routes.length > 20, `suspiciously few routes found: ${routes.length}`);
  for (const route of routes) {
    const lit = allNav.filter((e) => navEntryActive(e, route)).map((e) => e.product.id);
    if (exempt.has(route)) {
      assert.deepEqual(lit, [], `${route} is exempt but lights ${JSON.stringify(lit)} — remove it from the list`);
    } else {
      assert.equal(lit.length, 1, `${route} lights ${JSON.stringify(lit)} (want exactly one; add nav wiring or an exemption)`);
    }
  }
});

test("area child routes light exactly one child", () => {
  const childLit = (areaId: string, pathname: string): string[] => {
    const area = mainNav.find((e) => e.product.id === areaId)!;
    return area.children!.filter((c) => navEntryActive(c, pathname)).map((c) => c.product.id);
  };
  const cases: Array<[string, string, string]> = [
    ["orchestration", "/runs", "runs"],
    ["orchestration", "/runs/wm", "runs"],
    ["orchestration", "/pull-requests/detail", "pull-requests"],
    ["orchestration", "/stacks", "stacks"],
    ["orchestration", "/stacks/detail", "stacks"],
    ["orchestration", "/repositories", "repositories"],
    ["orchestration", "/workspaces/detail", "workspaces"],
    ["orchestration", "/drift", "drift"],
    ["orchestration", "/audit", "audit"],
    ["inventory", "/instances", "instances"],
    ["inventory", "/states", "states"],
    ["inventory", "/states/detail", "states"],
    ["inventory", "/modules", "modules"],
    ["inventory", "/types", "types"],
    ["inventory", "/gap-analysis", "gap-analysis"],
    ["insights", "/timeline", "timeline"],
    ["insights", "/timeline/detail", "timeline"],
    ["insights", "/state-changes", "state-changes"],
    ["insights", "/search", "search"],
    ["insights", "/blast-radius", "blast-radius"],
    ["insights", "/graph-explorer", "graph-explorer"],
    ["analyze", "/query", "query"],
    ["analyze", "/dashboards", "dashboards"],
    // The dashboard viewer and the chart builder highlight the Dashboards child.
    ["analyze", "/dashboard", "dashboards"],
    ["analyze", "/visualization", "dashboards"],
    ["security", "/security/overview", "security-overview"],
    ["security", "/security/findings", "security-findings"],
    ["security", "/security/findings/detail", "security-findings"],
    ["costs", "/cost-overview", "cost-overview"],
    ["costs", "/cost-explorer", "cost-explorer"],
    ["costs", "/cost-analysis", "cost-analysis"],
    ["costs", "/cost-budgets", "cost-budgets"],
    ["costs", "/cost-policies", "cost-policies"],
    ["costs", "/cost-optimization", "cost-optimization"],
    ["costs", "/billing-connections", "billing-connections"],
  ];
  for (const [areaId, pathname, expectedId] of cases) {
    assert.deepEqual(
      childLit(areaId, pathname),
      [expectedId],
      `${pathname} lit ${JSON.stringify(childLit(areaId, pathname))}`
    );
  }
  // A hub redirect URL lights the area, never a child.
  for (const [areaId, hub] of [
    ["orchestration", "/orchestration"],
    ["inventory", "/inventory"],
    ["insights", "/insights"],
    ["analyze", "/analyze"],
    ["costs", "/costs"],
  ] as Array<[string, string]>) {
    assert.equal(childLit(areaId, hub).length, 0, `${hub} lit a child`);
  }
});

test("getProductByHref resolves nested routes to the most specific product", () => {
  assert.equal(getProductByHref("/security")?.id, "security");
  assert.equal(getProductByHref("/security/overview")?.id, "security-overview");
  assert.equal(getProductByHref("/security/findings")?.id, "security-findings");
  assert.equal(getProductByHref("/security/findings/detail")?.id, "security-findings");
  assert.equal(getProductByHref("/dashboards")?.id, "dashboards");
  assert.equal(getProductByHref("/")?.id, "home");
  assert.equal(getProductByHref("/insights")?.id, "insights");
  // Orchestration screens resolve to their own product, so the breadcrumb
  // names the screen instead of the area.
  assert.equal(getProductByHref("/runs/wm")?.id, "runs");
  assert.equal(getProductByHref("/workspaces/detail")?.id, "workspaces");
  assert.equal(getProductByHref("/stacks/detail")?.id, "stacks");
  assert.equal(getProductByHref("/state-changes")?.id, "state-changes");
});

test("getProductByHref falls back to the nav entry hosting a standalone route", () => {
  // No product has these hrefs; the owning area's activeFor claims them.
  assert.equal(getProductByHref("/migrate-stategraph")?.id, "getting-started");
  assert.equal(getProductByHref("/no-such-route"), undefined);
});

test("every painted-door page belongs to a coming_soon product", () => {
  // A painted door renders an unbuilt product; an "available" status drops
  // its Coming Soon badge and presents it as shipped (#1683).
  const consoleDir = join(__dirname, "..", "app", "(console)");
  const files = readdirSync(consoleDir, { withFileTypes: true })
    .filter((d) => d.isDirectory())
    .flatMap((d) => ["content.tsx", "page.tsx"].map((f) => join(consoleDir, d.name, f)))
    .filter((f) => existsSync(f) && readFileSync(f, "utf8").includes("<PaintedDoorPage"));
  assert.ok(files.length >= 3, `suspiciously few painted doors: ${files.length}`);
  for (const f of files) {
    const id = readFileSync(f, "utf8").match(/getProductById\("([^"]+)"\)/)?.[1];
    assert.ok(id, `${f} renders PaintedDoorPage without getProductById`);
    assert.equal(getProductById(id as ProductId)?.status, "coming_soon", `${id} renders a painted door but is not coming_soon`);
  }
});

if (failures > 0) process.exit(1);
