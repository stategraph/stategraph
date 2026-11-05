import {
  Home,
  Network,
  Search,
  Shield,
  ShieldAlert,
  GitCompare,
  Radar,
  DollarSign,
  Workflow,
  Box,
  Layers,
  Folder,
  Target,
  Code,
  LayoutGrid,
  Settings as SettingsIcon,
  Clock,
  Database,
  Plug,
  LifeBuoy,
  Wallet,
  Table2,
  PiggyBank,
  Gavel,
  Sparkles,
  Boxes,
  Compass,
  BarChart3,
  GitPullRequest,
  FolderGit2,
  History,
  Play,
  FolderOpen,
  Blocks,
  GitCommitHorizontal,
  type LucideIcon,
} from "lucide-react";

// ============================================================================
// Product Types
// ============================================================================

export type ProductId =
  | "home"
  | "getting-started"
  | "states"
  | "types"
  | "instances"
  | "modules"
  | "graph-explorer"
  | "blast-radius"
  | "search"
  | "query"
  | "dashboards"
  | "gap-analysis"
  | "timeline"
  | "security"
  | "security-overview"
  | "security-findings"
  | "orchestration"
  | "pull-requests"
  | "repositories"
  | "workspaces"
  | "stacks"
  | "audit"
  | "runs"
  | "drift"
  | "state-changes"
  | "inventory"
  | "insights"
  | "analyze"
  | "costs"
  | "cost-analysis"
  | "cost-overview"
  | "cost-explorer"
  | "cost-budgets"
  | "cost-policies"
  | "cost-optimization"
  | "billing-connections"
  | "support"
  | "settings";

export type ProductStatus = "available" | "coming_soon";

export interface Product {
  id: ProductId;
  label: string;
  status: ProductStatus;
  href: string;
  description: string;
  /** Short product tagline shown under the label in the sidebar. */
  navTagline?: string;
  icon: LucideIcon;
  features?: string[];
}

export const products: Product[] = [
  // ========== Core Products ==========
  {
    id: "home",
    label: "Home",
    navTagline: "Overview & activity",
    status: "available",
    href: "/",
    description: "Landing page with infrastructure state, orchestration activity and quick navigation",
    icon: Home,
    features: [
      "Infrastructure state at-a-glance metrics",
      "Recent runs, open pull requests and drift when orchestration is on",
      "Quick navigation to all console products",
      "Resource count and distribution overview",
      "State composition and provider breakdown",
    ],
  },
  {
    id: "getting-started",
    label: "Get Started",
    navTagline: "Orchestration and state",
    status: "available",
    href: "/getting-started",
    description: "Set up Stategraph Orchestration and Infrastructure as a Database",
    icon: Plug,
    features: [
      "Connect a GitHub organization for orchestration",
      "Connect a GitLab group with an access token",
      "Import your Terraform state via the Stategraph CLI",
      "Step-by-step guided setup",
    ],
  },
  {
    id: "states",
    label: "States",
    status: "available",
    href: "/states",
    description: "Browse Terraform state files",
    icon: Database,
    features: [
      "View all state files in a sortable table",
      "Monitor state health and status",
      "Track resource counts and blast radius",
      "Review recent transaction activity",
    ],
  },
  // ========== Inventory Products ==========
  {
    id: "instances",
    label: "Resources",
    status: "available",
    href: "/instances",
    description: "Explore and inspect individual resources",
    icon: Box,
    features: [
      "Browse all resources with pagination",
      "Advanced query and filtering capabilities",
      "Inspect resource attributes and dependencies",
      "Blast radius analysis for impact assessment",
    ],
  },
  {
    id: "modules",
    label: "Modules",
    status: "available",
    href: "/modules",
    description: "Browse and explore Terraform module hierarchy",
    icon: Folder,
    features: [
      "Navigate module tree and hierarchy",
      "View resource counts per module",
      "Drill down to module-scoped resource listings",
      "Entry point for graph, drift, and cost analysis",
    ],
  },
  {
    id: "types",
    label: "Resource Types",
    status: "available",
    href: "/types",
    description: "Browse all resource types across your infrastructure",
    icon: Layers,
    features: [
      "High-level overview of all resource types",
      "Resource counts per type",
      "Provider-based grouping and filtering",
      "Quick drill-down to resource-level details",
    ],
  },
  {
    id: "query",
    label: "Query",
    status: "available",
    href: "/query",
    description: "SQL engine for Terraform inventory introspection",
    icon: Code,
    features: [
      "SQL interface to query Stategraph inventory tables",
      "Advanced joins and aggregations across resources",
      "Save and share SQL query templates",
      "Export query results in multiple formats",
    ],
  },
  {
    id: "dashboards",
    label: "Dashboards",
    status: "available",
    href: "/dashboards",
    description: "Organize visualizations into custom dashboard layouts",
    icon: LayoutGrid,
    features: [
      "Create custom dashboards with multiple charts",
      "Organize visualizations in vertical layouts",
      "Independent chart loading and error handling",
      "Rename and manage dashboard collections",
    ],
  },
  {
    id: "gap-analysis",
    label: "Gap Analysis",
    status: "available",
    href: "/gap-analysis",
    description: "Identify unmanaged cloud resources not tracked by Terraform",
    icon: GitCompare,
    features: [
      "Compare Stategraph inventory with AWS Resource Explorer",
      "Identify unmanaged cloud resources",
      "Service and region breakdown of gaps",
      "AWS configuration status and recommendations",
    ],
  },

  // ========== Insights Products ==========
  {
    id: "timeline",
    label: "Timeline",
    status: "available",
    href: "/timeline",
    description: "Chronological view of infrastructure activity",
    icon: Clock,
    features: [
      "View infrastructure transactions over time",
      "Track state changes and updates",
      "Monitor resource lifecycle events",
      "Filter activity by date range and type",
    ],
  },
  {
    id: "search",
    label: "Search",
    status: "available",
    href: "/search",
    description: "Fast search across all infrastructure resources",
    icon: Search,
    features: [
      "Full-text search across all resources",
      "Quick filtering and result navigation",
      "Recent search history",
      "Export search results",
    ],
  },
  {
    id: "blast-radius",
    label: "Blast Radius",
    status: "available",
    href: "/blast-radius",
    description: "Analyze the impact radius of infrastructure changes",
    icon: Target,
    features: [
      "Visualize upstream and downstream dependencies",
      "Calculate change impact distance metrics",
      "Identify critical infrastructure paths",
      "Export blast radius reports",
    ],
  },
  {
    id: "graph-explorer",
    label: "Graph Explorer",
    status: "available",
    href: "/graph-explorer",
    description: "Explore focused dependency relationships for individual resources",
    icon: Network,
    features: [
      "Scoped dependency visualization",
      "Immediate relationships only (depth 1)",
      "Hover-first interaction model",
      "Intentionally limited for clarity",
    ],
  },

  // ========== Orchestration Products ==========
  {
    id: "orchestration",
    label: "Orchestration",
    navTagline: "Plans, applies & drift",
    status: "available",
    href: "/orchestration",
    description: "Infrastructure change control powered by graph-based state",
    icon: Workflow,
  },
  {
    id: "pull-requests",
    label: "Pull Requests",
    status: "available",
    href: "/pull-requests",
    description: "Pull requests with their plan and apply status",
    icon: GitPullRequest,
  },
  {
    id: "repositories",
    label: "Repositories",
    status: "available",
    href: "/repositories",
    description: "Repositories under infrastructure automation",
    icon: FolderGit2,
  },
  {
    id: "workspaces",
    label: "Workspaces",
    status: "available",
    href: "/workspaces",
    description: "Workspaces discovered from runs, with their latest state",
    icon: FolderOpen,
  },
  {
    id: "stacks",
    label: "Stacks",
    status: "available",
    href: "/stacks",
    description: "Each open pull request's stacks in apply order",
    icon: Blocks,
  },
  {
    id: "audit",
    label: "Audit",
    status: "available",
    href: "/audit",
    description: "Every run — who ran what, when, and how it ended",
    icon: History,
  },
  {
    id: "runs",
    label: "Runs",
    status: "available",
    href: "/runs",
    description: "Orchestration runs and state changes for this tenant",
    icon: Play,
  },
  {
    id: "state-changes",
    label: "State Changes",
    status: "available",
    href: "/state-changes",
    description: "Stategraph engine transactions: every plan and apply committed to state",
    icon: GitCommitHorizontal,
  },
  {
    id: "drift",
    label: "Drift",
    status: "available",
    href: "/drift",
    description: "What has drifted, how, and the schedules that keep watch",
    icon: Radar,
  },

  // ========== Product Areas (sidebar areas; their screens are child rows) ==========
  {
    id: "inventory",
    label: "Inventory",
    navTagline: "States & their resources",
    status: "available",
    href: "/inventory",
    description: "States, resources, modules, and types across your infrastructure",
    icon: Boxes,
  },
  {
    id: "insights",
    label: "Insights",
    navTagline: "Timeline, search & graphs",
    status: "available",
    href: "/insights",
    description: "Activity over time and dependency exploration",
    icon: Compass,
  },
  {
    id: "analyze",
    label: "Analyze",
    navTagline: "Query & dashboards",
    status: "available",
    href: "/analyze",
    description: "Query the inventory and build dashboards",
    icon: BarChart3,
  },
  {
    id: "costs",
    label: "Costs",
    navTagline: "Spend & estimates",
    status: "available",
    href: "/costs",
    description: "Spend visibility for the infrastructure you actually have in state",
    icon: DollarSign,
  },

  // ========== Security Products ==========
  {
    id: "security",
    label: "Security",
    navTagline: "Scans & findings",
    status: "available",
    href: "/security",
    description: "Cloud security posture management",
    icon: Shield,
    features: [
      "Infrastructure security scanning",
      "Vulnerability detection and reporting",
      "Security best practices recommendations",
      "Compliance monitoring and remediation",
    ],
  },
  {
    id: "security-overview",
    label: "Overview",
    status: "available",
    href: "/security/overview",
    description: "Security posture rollup across your states",
    icon: Shield,
  },
  {
    id: "security-findings",
    label: "Findings",
    status: "available",
    href: "/security/findings",
    description: "Security findings for a state, with graph-derived context",
    icon: ShieldAlert,
    features: [
      "Per-state misconfiguration findings from the latest scan",
      "Severity, blast radius, and internet-reachability context",
      "Filter by severity and drill into the offending resource",
    ],
  },

  // ========== Costs Products ==========
  {
    id: "cost-overview",
    label: "Overview",
    status: "available",
    href: "/cost-overview",
    description: "Tenant-wide cost rollup across every state",
    icon: Wallet,
    features: [
      "Tenant-level total cost and coverage",
      "Cost trend over time with provider / type / tag grouping",
      "Per-state contribution table with drill-down",
    ],
  },
  {
    id: "cost-explorer",
    label: "Explorer",
    status: "available",
    href: "/cost-explorer",
    description: "Slice and dice tenant cost by provider, type, tag, or state",
    icon: Table2,
    features: [
      "Pivot cost by provider, resource type, tag, or state",
      "Share-of-total and change-over-range per row",
      "Min-cost threshold, sorting, and CSV export",
    ],
  },
  {
    id: "cost-analysis",
    label: "Analysis",
    status: "available",
    href: "/cost-analysis",
    description: "Per-state cost history and resource breakdown",
    icon: DollarSign,
    features: [
      "Resource cost attribution and tracking",
      "Cost trends and forecasting",
      "Budget alerts and notifications",
      "Cost optimization recommendations",
    ],
  },
  {
    id: "cost-budgets",
    label: "Budgets",
    status: "coming_soon",
    href: "/cost-budgets",
    description: "Set monthly cost targets scoped by tag, across every cloud",
    icon: PiggyBank,
    features: [
      "Cross-cloud budgets from stored state",
      "Projected overruns before they land",
      "Scope by tag, provider, or state",
    ],
  },
  {
    id: "cost-policies",
    label: "Policies",
    status: "coming_soon",
    href: "/cost-policies",
    description: "Flag or block changes that blow past a cost threshold",
    icon: Gavel,
    features: [
      "Cost guardrails in your orchestration PR flow",
      "Threshold and rate-of-change rules",
      "Plan-time preview pricing (coming with Phase 3)",
    ],
  },
  {
    id: "cost-optimization",
    label: "Optimization",
    status: "coming_soon",
    href: "/cost-optimization",
    description: "Rightsizing and idle-resource recommendations across your estate",
    icon: Sparkles,
    features: [
      "Rightsizing and idle-resource detection",
      "Modernization recommendations",
      "Estate-wide savings opportunities",
    ],
  },
  {
    id: "billing-connections",
    label: "Connections",
    status: "available",
    href: "/billing-connections",
    description: "Configure FOCUS billing sources and sync actual cloud spend",
    icon: Database,
  },

  // ========== Account Products ==========
  {
    id: "support",
    label: "Support",
    status: "available",
    href: "/support",
    description: "Get help, report issues, or join the conversation",
    icon: LifeBuoy,
  },
  {
    id: "settings",
    label: "Settings",
    status: "available",
    href: "/settings",
    description: "User preferences and account settings",
    icon: SettingsIcon,
    features: [
      "User profile and preferences",
      "Notification settings",
      "API keys and integrations",
      "Account security",
    ],
  },
];

// ============================================================================
// Helper Functions
// ============================================================================

export function getProductById(id: ProductId): Product | undefined {
  return products.find((product) => product.id === id);
}

/** Segment-boundary prefix match: `/insights` matches `/insights/x` but a
 *  future `/insight` can never hijack it. */
function matchesRoute(pathname: string, prefix: string): boolean {
  return pathname === prefix || pathname.startsWith(prefix + "/");
}

export function getProductByHref(href: string): Product | undefined {
  // Longest matching href wins so nested routes resolve to the most specific
  // product (e.g. /security/findings -> Findings, not the Security area).
  let best: Product | undefined;
  for (const product of products) {
    const matches = product.href !== "/" && matchesRoute(href, product.href);
    if (matches && (!best || product.href.length > best.href.length)) {
      best = product;
    }
  }
  if (best) return best;
  if (href === "/") return getProductById("home");
  // Fall back to a nav entry that HOSTS this route (its activeFor), so a
  // standalone route like /migrate-stategraph still shows its area's breadcrumb.
  const owner = [...mainNav, ...accountNav].find((e) =>
    e.activeFor.some((prefix) => matchesRoute(href, prefix))
  );
  return owner?.product;
}

export const availableProducts = products.filter(
  (p) => p.status === "available"
);

export const comingSoonProducts = products.filter(
  (p) => p.status === "coming_soon"
);

// ============================================================================
// Sidebar Navigation (orchestration-first; areas with sub-screens list them
// as children so every screen is a visible, one-click destination)
// ============================================================================

export interface NavEntry {
  product: Product;
  /**
   * Route prefixes (beyond the product's own href) that should light this item
   * up without a nav entry of their own (e.g. /migrate-stategraph under Get
   * Started, the dashboard viewer under Dashboards).
   *
   * Every screen is a real route and in-app links point at it; a retired
   * hub's URL only redirects its old `?tab=` values onto those routes (#2091).
   */
  activeFor: string[];
  /**
   * Sub-screens rendered as indented rows under this entry while the entry is
   * active. Each child is a full NavEntry, so its own href prefix (and any
   * detail routes under it) drives its highlight.
   */
  children?: NavEntry[];
}

function nav(id: ProductId, activeFor: string[] = [], children?: NavEntry[]): NavEntry {
  return { product: getProductById(id)!, activeFor, children };
}

export const mainNav: NavEntry[] = [
  nav("home"),
  nav(
    "orchestration",
    [],
    [
      nav("runs"),
      nav("pull-requests"),
      nav("stacks"),
      nav("repositories"),
      nav("workspaces"),
      nav("drift"),
      nav("audit"),
    ]
  ),
  nav(
    "inventory",
    [],
    [nav("instances"), nav("modules"), nav("types"), nav("states"), nav("gap-analysis")]
  ),
  nav(
    "insights",
    [],
    [
      nav("timeline"),
      nav("state-changes"),
      nav("search"),
      nav("blast-radius"),
      nav("graph-explorer"),
    ]
  ),
  // Boundary matching means /dashboard and /dashboards are distinct prefixes:
  // the dashboard viewer and the chart builder highlight the Dashboards child.
  nav("analyze", [], [nav("query"), nav("dashboards", ["/dashboard", "/visualization"])]),
  nav("security", [], [nav("security-overview"), nav("security-findings")]),
  nav(
    "costs",
    [],
    [
      nav("cost-overview"),
      nav("cost-explorer"),
      nav("cost-analysis"),
      nav("cost-budgets"),
      nav("cost-policies"),
      nav("cost-optimization"),
      nav("billing-connections"),
    ]
  ),
  nav("getting-started", ["/migrate-stategraph"]),
];

export const accountNav: NavEntry[] = [nav("support"), nav("settings")];

/** Screens the hosted service does not offer. Their routes stay reachable and
 *  render a self-hosted notice; the sidebar just does not list them. */
const communismHiddenNav: ReadonlySet<ProductId> = new Set<ProductId>(["gap-analysis"]);

export function navForMode(entries: NavEntry[], mode: string | undefined): NavEntry[] {
  if (mode !== "COMMUNISM") return entries;
  return entries
    .filter((entry) => !communismHiddenNav.has(entry.product.id))
    .map((entry) =>
      entry.children ? { ...entry, children: navForMode(entry.children, mode) } : entry,
    );
}

/** Should this nav entry render as active for the current pathname? Covers
 *  the entry's own route, the standalone routes it hosts, and its children. */
export function navEntryActive(entry: NavEntry, pathname: string): boolean {
  const { product, activeFor, children } = entry;
  if (product.href === "/") return pathname === "/";
  return (
    matchesRoute(pathname, product.href) ||
    activeFor.some((prefix) => matchesRoute(pathname, prefix)) ||
    (children ?? []).some((child) => navEntryActive(child, pathname))
  );
}
