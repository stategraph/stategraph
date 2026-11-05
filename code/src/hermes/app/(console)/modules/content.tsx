"use client";

import { useEffect, useMemo, useState } from "react";
import { useSearchParams, usePathname } from "next/navigation";
import { Module, type InstanceCost } from "@/lib/api/client";
import { loadModules, loadAllModules } from "./loader";
import { useAuth } from "@/components/auth";
import { useStates } from "@/contexts";
import {
  useCostAvailability,
  useDeepLinkRouter,
  useStateCosts,
  useStateSelection,
} from "@/hooks";
import { parseCost } from "@/lib/cost/format";
import { matchesSearch } from "@/lib/ui/search";
import { PageHeader } from "@/components/page/PageHeader";
import { Button } from "@/components/ui/button";
import { RefreshCw, Grid3x3, List, X } from "lucide-react";
import {
  ModuleGrid,
  ModuleTable,
  ModuleInspector,
  EmptyModuleState,
} from "@/components/modules";
import { PaginationControls } from "@/components/instances";
import { StateFilter } from "@/components/filters";

/**
 * The module a Terraform address belongs to (its own module, not a subtree):
 * "module.vpc.aws_instance.web" -> "module.vpc"; top-level -> "root". Any
 * for_each/count index on a module segment is stripped so instances roll up
 * under their logical module path.
 */
function moduleOfAddress(address: string): string {
  const parts = address.split(".");
  const segs: string[] = [];
  let i = 0;
  while (i + 1 < parts.length && parts[i] === "module") {
    segs.push("module", parts[i + 1].replace(/\[.*\]$/, ""));
    i += 2;
  }
  return segs.length > 0 ? segs.join(".") : "root";
}

export function ModulesContent() {
  const searchParams = useSearchParams();
  const router = useDeepLinkRouter();
  const pathname = usePathname();
  const { isAuthenticated } = useAuth();
  const { states } = useStates();

  const [selectedStateId, setSelectedStateId] = useStateSelection();

  const isAllStates = selectedStateId === "all";
  const currentState = isAllStates ? null : (states.find(s => s.id === selectedStateId) || null);

  // Extract params
  const urlQuery = searchParams.get("q") || "";
  const urlModule = searchParams.get("module");
  const urlView = searchParams.get("view") || "grid";

  // State
  const [modules, setModules] = useState<Module[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [selectedModule, setSelectedModule] = useState<Module | null>(null);
  const [query, setQuery] = useState(urlQuery);
  const [viewMode, setViewMode] = useState<"grid" | "list">(urlView === "list" ? "list" : "grid");

  // Pagination
  const [currentPage, setCurrentPage] = useState(1);
  const [hasMore, setHasMore] = useState(false);
  const [pageHistory, setPageHistory] = useState<string[][]>([]);
  const [refreshTrigger, setRefreshTrigger] = useState(0);
  const limit = 50;

  // Per-module cost rollup, derived client-side from the state's latest cost
  // snapshot (no per-module endpoint). Capability-gated and single-state only.
  //
  // DECISION NEEDED: should the modules view show cost when the user is in
  // the cross-state ("All states") view? Today we bail (`isAllStates` ->
  // empty), which means the cost column simply disappears. Two reasonable
  // resolutions exist and we should pick one before this ships broadly:
  //
  //   a) Keep the current behaviour and document it as a non-goal: per-module
  //      cost is a single-state surface; cross-state cost lives on Cost
  //      Overview / Cost Explorer.
  //   b) Aggregate `getStateCosts` across every state in the tenant client-
  //      side. Straightforward but issues N fetches and conflates "module of
  //      address X in state A" with "module of address X in state B" when
  //      address names collide. Probably needs a real backend endpoint to do
  //      well.
  const { capability: costCapability } = useCostAvailability();
  const costSupported = costCapability?.enabled === true;
  const stateCostsId =
    costSupported && !isAllStates && currentState ? currentState.id : null;
  const { costs: stateCosts } = useStateCosts(stateCostsId);
  const instanceCosts: InstanceCost[] = stateCosts?.instance_costs ?? [];
  const costCurrency = stateCosts?.currency ?? "";

  const costByModule = useMemo(() => {
    const map = new Map<string, number>();
    for (const ic of instanceCosts) {
      const m = parseCost(ic.monthly_cost);
      if (m === null) continue;
      const mod = moduleOfAddress(ic.address);
      map.set(mod, (map.get(mod) ?? 0) + m);
    }
    return map;
  }, [instanceCosts]);
  const moduleCosts = !isAllStates && costSupported ? costByModule : undefined;

  // All-states search runs client-side over the COMPLETE aggregate set (single-
  // state search is handled by the loader against the paginated REST endpoint).
  // This keeps cross-state search + footer total accurate over the full set (#1062).
  const displayModules = useMemo(() => {
    if (!isAllStates) return modules;
    return modules.filter((m) => matchesSearch(query, m.name));
  }, [modules, query, isAllStates]);

  // Update local query when URL changes
  useEffect(() => {
    setQuery(urlQuery);
  }, [urlQuery]);

  // Load modules
  useEffect(() => {
    if (!isAuthenticated) return;
    if (!isAllStates && !currentState) return;

    let cancelled = false;

    async function fetchData() {
      setLoading(true);
      setError(null);

      try {
        let fetchedModules: Module[] = [];
        if (isAllStates) {
          // One aggregate MQL query for the whole tenant — no per-state
          // fan-out (#1073). Returns the complete tenant-wide set; search runs
          // client-side over it (see `displayModules`), so it's not limited to
          // a loaded page and the footer total is correct (#1062).
          const mods = await loadAllModules();
          if (cancelled) return;
          setModules(mods);
          setHasMore(false);
          fetchedModules = mods;
        } else {
          const stateId = currentState!.id;
          const page =
            currentPage > 1 && pageHistory[currentPage - 2]
              ? pageHistory[currentPage - 2]
              : undefined;

          const data = await loadModules(stateId, {
            q: query || undefined,
            limit,
            page,
          });

          if (cancelled) return;

          setModules(data.modules);
          setHasMore(data.hasMore);
          fetchedModules = data.modules;
        }

        // Auto-select module from URL
        if (urlModule && !selectedModule) {
          const found = fetchedModules.find((m) => m.name === urlModule);
          if (found) {
            setSelectedModule(found);
          }
        }
      } catch (e: unknown) {
        if (cancelled) return;
        const message = e instanceof Error ? e.message : "Failed to load modules";
        setError(message);
        console.error("[ModulesPage] Error:", e);
      } finally {
        if (!cancelled) {
          setLoading(false);
        }
      }
    }

    fetchData();

    return () => {
      cancelled = true;
    };
  }, [query, currentPage, isAuthenticated, isAllStates, currentState, states, refreshTrigger, pageHistory, selectedModule, urlModule]);

  // Handlers
  const handleQueryChange = (newQ: string) => {
    // Seed from the current params so unrelated ones (?state=) survive the
    // rewrite.
    const params = new URLSearchParams(searchParams);
    if (newQ) {
      params.set("q", newQ);
    } else {
      params.delete("q");
    }
    if (viewMode !== "grid") {
      params.set("view", viewMode);
    } else {
      params.delete("view");
    }
    router.replace(`${pathname}?${params.toString()}`, { scroll: false });
    setQuery(newQ);
    setCurrentPage(1);
    setPageHistory([]);
  };

  const handleModuleClick = (module: Module) => {
    setSelectedModule(module);
    // Update URL
    const params = new URLSearchParams(searchParams);
    params.set("module", module.name);
    router.replace(`${pathname}?${params.toString()}`, { scroll: false });
  };

  const handleCloseInspector = () => {
    setSelectedModule(null);
    const params = new URLSearchParams(searchParams);
    params.delete("module");
    router.replace(`${pathname}?${params.toString()}`, { scroll: false });
  };

  const handleViewInstances = (moduleName: string) => {
    router.push(`/instances?module=${encodeURIComponent(moduleName)}`);
  };

  const handleNavigateToModule = (modulePath: string) => {
    // Filter to show this module and its children
    const filterQuery = modulePath === "root" ? "" : modulePath;
    handleQueryChange(filterQuery);
  };

  const handleToggleView = (mode: "grid" | "list") => {
    setViewMode(mode);
    const params = new URLSearchParams(searchParams);
    if (mode !== "grid") {
      params.set("view", mode);
    } else {
      params.delete("view");
    }
    router.replace(`${pathname}?${params.toString()}`, { scroll: false });
  };

  const handleNextPage = () => {
    if (modules.length > 0) {
      const lastModule = modules[modules.length - 1];
      const newPageHistory = [...pageHistory];
      newPageHistory[currentPage - 1] = [lastModule.name];
      setPageHistory(newPageHistory);
    }
    setCurrentPage(currentPage + 1);
  };

  const handlePreviousPage = () => {
    if (currentPage > 1) {
      setCurrentPage(currentPage - 1);
    }
  };

  const hasQuery = query.trim().length > 0;

  return (
    <div className="flex h-full min-h-0 overflow-hidden">
      {/* Main Content */}
      <div className="flex-1 flex flex-col overflow-hidden min-w-0">
        {/* Header */}
        <PageHeader
          title="Modules"
          subtitle="Browse and inspect Terraform modules in your infrastructure"
        >
          <div className="flex flex-wrap gap-2">
            <StateFilter
              value={selectedStateId}
              onChange={setSelectedStateId}
              showAllOption
              className="min-w-[200px]"
            />
            {/* View Toggle */}
            <div className="flex gap-1 border border-[var(--sg-border)] rounded-lg p-1">
              <Button
                variant={viewMode === "grid" ? "default" : "ghost"}
                size="sm"
                onClick={() => handleToggleView("grid")}
                className="px-2"
              >
                <Grid3x3 className="h-4 w-4" />
              </Button>
              <Button
                variant={viewMode === "list" ? "default" : "ghost"}
                size="sm"
                onClick={() => handleToggleView("list")}
                className="px-2"
              >
                <List className="h-4 w-4" />
              </Button>
            </div>
            {/* Refresh */}
            <Button
              variant="outline"
              size="sm"
              onClick={() => {
                setRefreshTrigger(prev => prev + 1);
              }}
              disabled={loading}
            >
              <RefreshCw className={`h-4 w-4 mr-2 ${loading ? "animate-spin" : ""}`} />
              Refresh
            </Button>
          </div>
        </PageHeader>

        {/* Query Bar */}
        <div className="flex-shrink-0 p-4 border-b border-[var(--sg-border)] bg-[var(--sg-bg-0)]">
          <div className="relative">
            <input
              type="text"
              value={query}
              onChange={(e) => handleQueryChange(e.target.value)}
              placeholder="Search modules by name..."
              className="w-full px-4 py-2.5 bg-[var(--sg-bg-2)] border border-[var(--sg-border)] rounded-lg text-sm text-[var(--sg-text)] placeholder:text-[var(--sg-text-dim)] focus:outline-none focus:ring-2 focus:ring-[var(--sg-accent)] focus:border-transparent transition-colors"
            />
            {query && (
              <button
                onClick={() => handleQueryChange('')}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-[var(--sg-text-dim)] hover:text-[var(--sg-text)] transition-colors"
              >
                <X className="h-4 w-4" />
              </button>
            )}
          </div>
        </div>

        {/* Error */}
        {error && (
          <div className="mx-6 mt-4 p-4 bg-[var(--sg-error)]/10 border border-[var(--sg-error)] rounded-lg">
            <div className="sg-secondary-header text-[var(--sg-error)] mb-1">
              Failed to load modules
            </div>
            <div className="sg-metadata text-[var(--sg-error)]">{error}</div>
          </div>
        )}

        {/* Content */}
        <div className="flex-1 overflow-hidden flex flex-col">
          <div className="flex-1 overflow-y-auto px-6 py-4">
            {displayModules.length === 0 && !loading ? (
              <EmptyModuleState hasQuery={hasQuery} />
            ) : viewMode === "grid" ? (
              <ModuleGrid
                modules={displayModules}
                onViewInstances={handleViewInstances}
                onOpenInspector={handleModuleClick}
                selectedModule={selectedModule}
                isLoading={loading}
                costByModule={moduleCosts}
                costCurrency={costCurrency}
              />
            ) : (
              <ModuleTable
                modules={displayModules}
                onViewInstances={handleViewInstances}
                onOpenInspector={handleModuleClick}
                selectedModule={selectedModule}
                isLoading={loading}
                costByModule={moduleCosts}
                costCurrency={costCurrency}
              />
            )}
          </div>

          {/* Pagination */}
          {!loading && displayModules.length > 0 && (
            <PaginationControls
              currentPage={currentPage}
              hasNext={hasMore}
              hasPrevious={currentPage > 1}
              onNext={handleNextPage}
              onPrevious={handlePreviousPage}
              totalResults={displayModules.length}
              isLoading={loading}
            />
          )}
        </div>
      </div>

      {/* Inspector Panel */}
      {selectedModule && (
        <ModuleInspector
          module={selectedModule}
          onClose={handleCloseInspector}
          onViewInstances={handleViewInstances}
          onNavigateToModule={handleNavigateToModule}
        />
      )}
    </div>
  );
}
