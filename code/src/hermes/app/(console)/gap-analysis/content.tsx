"use client";

import { useState, useCallback, useMemo, useEffect, useRef } from "react";
import { usePathname, useSearchParams } from "next/navigation";
import { useDeepLinkRouter } from "@/hooks";
import { PageHeader } from "@/components/page";
import { SelfHostedOnlyNotice } from "@/components/product";
import { useTenant } from "@/contexts/TenantContext";
import { useLicense } from "@/contexts";
import {
  getGapAnalysis,
  getGapAnalysisConfig,
  GapAnalysisResponse,
  GapAnalysisProvider,
  GapAnalysisConfigResponse,
} from "@/lib/api/client";
import { RefreshCw, ChevronLeft, Settings, Play, Clock } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  GapSummaryCards,
  ServiceBreakdownChart,
  UnmanagedResourcesTable,
  GapAnalysisSkeleton,
  NoGapsEmptyState,
} from "./components";
import { GenerateConfigDialog } from "./GenerateConfigDialog";
import { track } from "@/lib/analytics";

// Cache TTL in seconds (must match backend CACHE_TTL_SECONDS)
const CACHE_TTL_SECONDS = 10800; // 3 hours

// Format relative time (e.g., "5 minutes ago", "2 hours ago")
function formatTimeAgo(timestamp: number): string {
  const seconds = Math.floor(Date.now() / 1000 - timestamp);
  if (seconds < 60) return "just now";
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  return `${days}d ago`;
}

// Format time until cache expires
function formatExpiresIn(fetchedAt: number): string {
  const expiresAt = fetchedAt + CACHE_TTL_SECONDS;
  const secondsRemaining = Math.floor(expiresAt - Date.now() / 1000);
  if (secondsRemaining <= 0) return "expired";
  const minutes = Math.floor(secondsRemaining / 60);
  if (minutes < 60) return `${minutes}m`;
  const hours = Math.floor(minutes / 60);
  const remainingMinutes = minutes % 60;
  if (remainingMinutes === 0) return `${hours}h`;
  return `${hours}h ${remainingMinutes}m`;
}

// Provider card icons (using simple text for now)
const PROVIDERS: { id: GapAnalysisProvider; name: string; description: string }[] = [
  {
    id: "aws",
    name: "Amazon Web Services",
    description: "Compare with AWS Resource Explorer",
  },
  {
    id: "gcp",
    name: "Google Cloud Platform",
    description: "Compare with GCP Cloud Asset Inventory",
  },
  {
    id: "azure",
    name: "Microsoft Azure",
    description: "Compare with Azure Resource Graph",
  },
];

function ProviderSelectionView({
  onSelectProvider,
  onCheckConfig,
  isCheckingConfig,
  configResults,
  selectedConfigProvider,
}: {
  onSelectProvider: (provider: GapAnalysisProvider) => void;
  onCheckConfig: (provider: GapAnalysisProvider) => void;
  isCheckingConfig: GapAnalysisProvider | null;
  configResults: Record<GapAnalysisProvider, GapAnalysisConfigResponse | null>;
  selectedConfigProvider: GapAnalysisProvider | null;
}) {
  const selectedConfig = selectedConfigProvider ? configResults[selectedConfigProvider] : null;
  const selectedProviderInfo = PROVIDERS.find(p => p.id === selectedConfigProvider);

  // Track elapsed time during config check (cloud API calls can be slow)
  const [configCheckStartTime, setConfigCheckStartTime] = useState<number | null>(null);
  const [elapsedSeconds, setElapsedSeconds] = useState(0);

  // Update start time when config check begins/ends
  useEffect(() => {
    if (isCheckingConfig) {
      // eslint-disable-next-line react-hooks/set-state-in-effect -- Timer initialization is valid
      setConfigCheckStartTime(Date.now());
    } else {
      setConfigCheckStartTime(null);
    }
  }, [isCheckingConfig]);

  // Timer that updates elapsed seconds
  useEffect(() => {
    if (configCheckStartTime === null) return;
    const interval = setInterval(() => {
      setElapsedSeconds(Math.floor((Date.now() - configCheckStartTime) / 1000));
    }, 1000);
    return () => clearInterval(interval);
  }, [configCheckStartTime]);

  return (
    <div className="flex flex-col w-full h-full">
      <PageHeader
        title="Gap Analysis"
        subtitle="Identify unmanaged cloud resources"
      />
      <div className="flex-1 overflow-auto">
        <div className="p-6">
          <div className="max-w-4xl mx-auto">
            <h2 className="text-lg font-semibold text-[var(--sg-text)] mb-2">
              Select a Cloud Provider
            </h2>
            <p className="text-sm text-[var(--sg-text-muted)] mb-6">
              Choose a cloud provider to compare your Stategraph inventory against.
              You can check the provider configuration before running the analysis.
            </p>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              {PROVIDERS.map((provider) => {
                const config = configResults[provider.id];
                const isChecking = isCheckingConfig === provider.id;
                const isSelected = selectedConfigProvider === provider.id;

                return (
                  <div
                    key={provider.id}
                    className={`border rounded-lg p-4 bg-[var(--sg-panel)] ${
                      isSelected ? "border-[var(--sg-accent)] ring-1 ring-[var(--sg-accent)]" : "border-[var(--sg-border)]"
                    }`}
                  >
                    <div className="mb-3 flex items-start justify-between">
                      <div>
                        <h3 className="font-semibold text-[var(--sg-text)] uppercase text-sm">
                          {provider.id}
                        </h3>
                        <p className="text-xs text-[var(--sg-text-muted)] mt-1">
                          {provider.name}
                        </p>
                      </div>
                      {config && (
                        <span
                          className={`text-[10px] px-1.5 py-0.5 rounded ${
                            config.ready_for_gap_analysis
                              ? "bg-[var(--sg-success)]/10 text-[var(--sg-success)]"
                              : "bg-[var(--sg-warning)]/10 text-[var(--sg-warning)]"
                          }`}
                        >
                          {config.ready_for_gap_analysis ? "Ready" : "Setup needed"}
                        </span>
                      )}
                    </div>
                    <p className="text-xs text-[var(--sg-text-muted)] mb-4">
                      {provider.description}
                    </p>

                    <div className="flex flex-wrap gap-2">
                      <Button
                        variant="outline"
                        size="sm"
                        className="flex-1"
                        onClick={() => onCheckConfig(provider.id)}
                        disabled={isChecking}
                      >
                        <Settings
                          className={`h-3 w-3 mr-1 ${isChecking ? "animate-spin" : ""}`}
                        />
                        {isChecking
                          ? elapsedSeconds >= 5
                            ? `${elapsedSeconds}s / ~60s`
                            : "Checking..."
                          : "Check Config"}
                      </Button>
                      <Button
                        size="sm"
                        className="flex-1"
                        onClick={() => onSelectProvider(provider.id)}
                      >
                        <Play className="h-3 w-3 mr-1" />
                        Analyze
                      </Button>
                    </div>
                  </div>
                );
              })}
            </div>

            {/* Config Details Panel */}
            {selectedConfig && selectedProviderInfo && (
              <div className="mt-6 border border-[var(--sg-border)] rounded-lg bg-[var(--sg-panel)]">
                <div className="p-4 border-b border-[var(--sg-border)] flex items-center justify-between">
                  <div>
                    <h3 className="font-semibold text-[var(--sg-text)]">
                      {selectedProviderInfo.name} Configuration
                    </h3>
                    <p className={`text-sm mt-1 ${
                      selectedConfig.ready_for_gap_analysis
                        ? "text-[var(--sg-success)]"
                        : "text-[var(--sg-warning)]"
                    }`}>
                      {selectedConfig.ready_for_gap_analysis
                        ? "✓ Ready for gap analysis"
                        : "⚠ Configuration required"}
                    </p>
                  </div>
                </div>
                {selectedConfig.warnings && selectedConfig.warnings.length > 0 && (
                  <div className="p-4 space-y-4">
                    {selectedConfig.warnings.map((w, i) => {
                      const warning = typeof w === "string" ? { message: w } : (w as { message?: string; fix?: string; docs_url?: string });
                      return (
                        <div key={i}>
                          <p className="text-sm text-[var(--sg-text)] mb-2">{warning.message}</p>
                          {warning.fix && (
                            <div className="relative">
                              <pre className="p-4 bg-[var(--sg-bg)] rounded text-[var(--sg-text-muted)] font-mono text-xs whitespace-pre-wrap overflow-x-auto">
                                {warning.fix}
                              </pre>
                              <button
                                className="absolute top-2 right-2 px-2 py-1 text-xs bg-[var(--sg-border)] hover:bg-[var(--sg-text-muted)] text-[var(--sg-text)] rounded"
                                onClick={() => navigator.clipboard.writeText(warning.fix || "")}
                              >
                                Copy
                              </button>
                            </div>
                          )}
                          {warning.docs_url && (
                            <a
                              href={warning.docs_url}
                              target="_blank"
                              rel="noopener noreferrer"
                              className="inline-flex items-center gap-1 mt-2 text-xs text-[var(--sg-accent)] hover:underline"
                            >
                              View documentation →
                            </a>
                          )}
                        </div>
                      );
                    })}
                  </div>
                )}
                {selectedConfig.ready_for_gap_analysis && (
                  <div className="p-4">
                    <p className="text-sm text-[var(--sg-text-muted)]">
                      Click &quot;Analyze&quot; on the {selectedProviderInfo.id.toUpperCase()} card above to run gap analysis.
                    </p>
                  </div>
                )}
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

function GapAnalysisResultsView({
  provider,
  data,
  isLoading,
  isRefreshing,
  error,
  onRefresh,
  onBack,
}: {
  provider: GapAnalysisProvider;
  data: GapAnalysisResponse | null;
  isLoading: boolean;
  isRefreshing: boolean;
  error: string | null;
  onRefresh: () => void;
  onBack: () => void;
}) {
  const providerName = PROVIDERS.find((p) => p.id === provider)?.name || provider.toUpperCase();

  // Selection state for generating config
  const [selectedArns, setSelectedArns] = useState<Set<string>>(new Set());
  const [showGenerateDialog, setShowGenerateDialog] = useState(false);

  // Get selected resources for the dialog
  const selectedResources = useMemo(() => {
    if (!data || !data.unmanaged_resources) return [];
    return data.unmanaged_resources.filter((r) => {
      const resourceId = r.id || r.arn || r.asset_name || "";
      return selectedArns.has(resourceId);
    });
  }, [data, selectedArns]);

  const handleGenerateConfig = useCallback(() => {
    if (selectedArns.size > 0) {
      setShowGenerateDialog(true);
    }
  }, [selectedArns]);

  // Track elapsed time during loading (GCP API calls can be slow)
  const [loadingStartTime, setLoadingStartTime] = useState<number | null>(null);
  const [loadingElapsed, setLoadingElapsed] = useState(0);

  // Update start time when loading begins/ends
  useEffect(() => {
    if (isLoading) {
      // eslint-disable-next-line react-hooks/set-state-in-effect -- Timer initialization is valid
      setLoadingStartTime(Date.now());
    } else {
      setLoadingStartTime(null);
    }
  }, [isLoading]);

  // Timer that updates elapsed seconds
  useEffect(() => {
    if (loadingStartTime === null) return;
    const interval = setInterval(() => {
      setLoadingElapsed(Math.floor((Date.now() - loadingStartTime) / 1000));
    }, 1000);
    return () => clearInterval(interval);
  }, [loadingStartTime]);

  if (error) {
    return (
      <div className="flex flex-col w-full h-full">
        <PageHeader
          title="Gap Analysis"
          subtitle={`Analyzing ${providerName}`}
        >
          <div className="flex items-center gap-2">
            <Button variant="outline" size="sm" onClick={onBack}>
              <ChevronLeft className="h-4 w-4 mr-1" />
              Back
            </Button>
            <Button
              variant="outline"
              size="sm"
              onClick={onRefresh}
              disabled={isRefreshing}
            >
              <RefreshCw
                className={`h-4 w-4 mr-2 ${isRefreshing ? "animate-spin" : ""}`}
              />
              Retry
            </Button>
          </div>
        </PageHeader>
        <div className="flex items-center justify-center flex-1">
          <div className="max-w-lg w-full px-6">
            <div className="rounded-lg border border-[var(--sg-border)] bg-[var(--sg-surface)] p-6">
              <div className="flex items-start gap-3">
                <div className="mt-0.5 rounded-full bg-[var(--sg-error)]/10 p-2">
                  <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--sg-error)" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="10"/><line x1="12" x2="12" y1="8" y2="12"/><line x1="12" x2="12.01" y1="16" y2="16"/></svg>
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium text-[var(--sg-text)] mb-1">Gap analysis failed</p>
                  <p className="text-sm text-[var(--sg-text-muted)] font-mono break-words">{error}</p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    );
  }

  if (isLoading) {
    return (
      <div className="flex flex-col w-full h-full">
        <PageHeader
          title="Gap Analysis"
          subtitle={`Analyzing ${providerName}`}
        >
          <Button variant="outline" size="sm" onClick={onBack}>
            <ChevronLeft className="h-4 w-4 mr-1" />
            Back
          </Button>
        </PageHeader>
        <div className="flex-1 overflow-auto">
          <div className="p-6">
            <div className="mb-4 p-4 rounded-lg border border-[var(--sg-border)] bg-[var(--sg-panel)]">
              <div className="flex items-center gap-3">
                <RefreshCw className="h-5 w-5 animate-spin text-[var(--sg-accent)]" />
                <div>
                  <p className="text-sm font-medium text-[var(--sg-text)]">
                    Querying {providerName} resources...
                    {loadingElapsed >= 5 && (
                      <span className="ml-2 text-[var(--sg-text-muted)]">
                        {loadingElapsed}s / ~90s
                      </span>
                    )}
                  </p>
                  <p className="text-xs text-[var(--sg-text-muted)] mt-1">
                    Comparing cloud inventory with Stategraph state. This may take a minute.
                  </p>
                </div>
              </div>
            </div>
            <GapAnalysisSkeleton />
          </div>
        </div>
      </div>
    );
  }

  if (!data) {
    return (
      <div className="flex flex-col w-full h-full">
        <PageHeader
          title="Gap Analysis"
          subtitle={`Analyzing ${providerName}`}
        >
          <Button variant="outline" size="sm" onClick={onBack}>
            <ChevronLeft className="h-4 w-4 mr-1" />
            Back
          </Button>
        </PageHeader>
        <div className="flex items-center justify-center flex-1">
          <div className="text-center max-w-md px-6">
            <p className="text-sm text-[var(--sg-text-muted)]">
              No data available
            </p>
          </div>
        </div>
      </div>
    );
  }

  // Check if there are no unmanaged resources
  if (data.summary.unmanaged === 0) {
    return (
      <div className="flex flex-col w-full h-full">
        <PageHeader
          title="Gap Analysis"
          subtitle={`Analyzing ${providerName}`}
        >
          <div className="flex items-center gap-3">
            {data.fetched_at && (
              <span className="text-xs text-[var(--sg-text-muted)] flex items-center gap-1">
                <Clock className="h-3 w-3" />
                {formatTimeAgo(data.fetched_at)} · expires in {formatExpiresIn(data.fetched_at)}
              </span>
            )}
            <Button variant="outline" size="sm" onClick={onBack}>
              <ChevronLeft className="h-4 w-4 mr-1" />
              Back
            </Button>
            <Button
              variant="outline"
              size="sm"
              onClick={onRefresh}
              disabled={isRefreshing}
            >
              <RefreshCw
                className={`h-4 w-4 mr-2 ${isRefreshing ? "animate-spin" : ""}`}
              />
              Refresh
            </Button>
          </div>
        </PageHeader>
        <div className="flex-1 overflow-auto">
          <div className="p-6 space-y-6">
            <GapSummaryCards summary={data.summary} provider={provider} />
            <NoGapsEmptyState provider={provider} />
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="flex flex-col w-full h-full">
      <PageHeader
        title="Gap Analysis"
        subtitle={`Analyzing ${providerName}`}
      >
        <div className="flex items-center gap-3">
          {data.fetched_at && (
            <span className="text-xs text-[var(--sg-text-muted)] flex items-center gap-1">
              <Clock className="h-3 w-3" />
              {formatTimeAgo(data.fetched_at)} · expires in {formatExpiresIn(data.fetched_at)}
            </span>
          )}
          <Button variant="outline" size="sm" onClick={onBack}>
            <ChevronLeft className="h-4 w-4 mr-1" />
            Back
          </Button>
          <Button
            variant="outline"
            size="sm"
            onClick={onRefresh}
            disabled={isRefreshing}
          >
            <RefreshCw
              className={`h-4 w-4 mr-2 ${isRefreshing ? "animate-spin" : ""}`}
            />
            Refresh
          </Button>
        </div>
      </PageHeader>
      <div className="flex-1 overflow-auto">
        <div className="p-6 space-y-6">
          {/* Summary Cards */}
          <div className="space-y-2">
            <h2 className="text-sm font-semibold text-[var(--sg-text)] uppercase tracking-wide">
              Coverage Summary
            </h2>
            <GapSummaryCards summary={data.summary} provider={provider} />
          </div>

          {/* Service Breakdown Chart */}
          <ServiceBreakdownChart resources={data.unmanaged_resources} provider={provider} />

          {/* Unmanaged Resources Table */}
          <div className="space-y-2">
            <h2 className="text-sm font-semibold text-[var(--sg-text)] uppercase tracking-wide">
              Unmanaged Resources
            </h2>
            <UnmanagedResourcesTable
              resources={data.unmanaged_resources}
              selectedArns={selectedArns}
              onSelectionChange={setSelectedArns}
              onGenerateConfig={handleGenerateConfig}
              provider={provider}
            />
          </div>
        </div>
      </div>

      {/* Generate Config Dialog */}
      <GenerateConfigDialog
        open={showGenerateDialog}
        onOpenChange={setShowGenerateDialog}
        resources={selectedResources}
        provider={provider}
      />
    </div>
  );
}

export function GapAnalysisContent() {
  const searchParams = useSearchParams();
  const pathname = usePathname();
  const router = useDeepLinkRouter();
  const { currentTenant } = useTenant();
  const { mode } = useLicense();

  // Derive provider from URL — reacts to sidebar navigation changes. The param
  // is ?cloud= (not ?provider=) because this screen shares a URL with the
  // Resources tab inside /inventory, whose facet filter owns ?provider= with
  // different values (hashicorp/aws vs aws). ?provider= is still read as a
  // fallback so pre-rename deep links keep working.
  const urlProvider = searchParams.get("cloud") ?? searchParams.get("provider");
  const selectedProvider: GapAnalysisProvider | null =
    urlProvider === "aws" || urlProvider === "gcp" || urlProvider === "azure"
      ? urlProvider
      : null;
  const [data, setData] = useState<GapAnalysisResponse | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [isRefreshing, setIsRefreshing] = useState(false);

  // Config checking state
  const [isCheckingConfig, setIsCheckingConfig] = useState<GapAnalysisProvider | null>(null);
  const [selectedConfigProvider, setSelectedConfigProvider] = useState<GapAnalysisProvider | null>(null);
  const [configResults, setConfigResults] = useState<
    Record<GapAnalysisProvider, GapAnalysisConfigResponse | null>
  >({
    aws: null,
    gcp: null,
    azure: null,
  });

  const fetchData = useCallback(
    async (provider: GapAnalysisProvider, isRefresh = false) => {
      console.log("[gap-analysis] fetchData called", { provider, isRefresh, currentTenant });
      if (!currentTenant) {
        console.log("[gap-analysis] no currentTenant, returning early");
        return;
      }

      try {
        if (isRefresh) {
          setIsRefreshing(true);
        } else {
          setIsLoading(true);
        }
        setError(null);

        const source = isRefresh ? 'no-cache' as const : 'cache' as const;
        console.log("[gap-analysis] calling getGapAnalysis...");
        let result = await getGapAnalysis(currentTenant.id, provider, { source });
        console.log("[gap-analysis] got result:", result);

        // Poll while the job is running
        while (result.status === 'running') {
          console.log("[gap-analysis] job running, polling in 3s...");
          await new Promise(resolve => setTimeout(resolve, 3000));
          result = await getGapAnalysis(currentTenant.id, provider, { source: 'cache' });
          console.log("[gap-analysis] poll result:", result);
        }

        if (result.status === 'ready') {
          // Guard against malformed data (e.g. error response stored as completed result)
          if (!result.data.unmanaged_resources) {
            const errorData = result.data as Record<string, unknown>;
            setError(typeof errorData.error === 'string' ? errorData.error : "Gap analysis returned invalid data");
          } else {
            setData(result.data);
            track('gap_analysis_completed', {
              provider,
              refresh: isRefresh,
              unmanaged: result.data.summary.unmanaged,
              total_cloud_resources: result.data.summary.total_cloud_resources,
            });
          }
        } else {
          // status === 'failed'
          setError(result.job.error || "Gap analysis job failed");
        }
      } catch (err) {
        console.error("[gap-analysis] error:", err);
        setError(
          err instanceof Error ? err.message : "Failed to load gap analysis"
        );
      } finally {
        console.log("[gap-analysis] fetchData complete");
        setIsLoading(false);
        setIsRefreshing(false);
      }
    },
    [currentTenant]
  );

  const handleCheckConfig = useCallback(
    async (provider: GapAnalysisProvider) => {
      if (!currentTenant) return;

      console.log("[gap-analysis] handleCheckConfig called for", provider);
      setIsCheckingConfig(provider);
      setSelectedConfigProvider(provider);
      try {
        const config = await getGapAnalysisConfig(currentTenant.id, provider);
        console.log("[gap-analysis] config response:", config);
        setConfigResults((prev) => ({
          ...prev,
          [provider]: config,
        }));
      } catch (err) {
        // Show error in config results
        setConfigResults((prev) => ({
          ...prev,
          [provider]: {
            status: "error",
            ready_for_gap_analysis: false,
            warnings: [err instanceof Error ? err.message : "Failed to check configuration"],
          },
        }));
      } finally {
        setIsCheckingConfig(null);
      }
    },
    [currentTenant]
  );

  // URL writes stay on the current pathname and preserve existing params.
  const handleSelectProvider = useCallback(
    (provider: GapAnalysisProvider) => {
      setData(null);
      setError(null);
      const params = new URLSearchParams(searchParams);
      params.set("cloud", provider);
      params.delete("provider");
      router.replace(`${pathname}?${params.toString()}`);
      fetchData(provider);
    },
    [fetchData, router, pathname, searchParams]
  );

  const handleBack = useCallback(() => {
    setData(null);
    setError(null);
    const params = new URLSearchParams(searchParams);
    params.delete("cloud");
    params.delete("provider");
    const qs = params.toString();
    router.replace(qs ? `${pathname}?${qs}` : pathname);
  }, [router, pathname, searchParams]);

  // Auto-run analysis if provider came from URL param
  const hasAutoRun = useRef(false);
  useEffect(() => {
    if (!hasAutoRun.current && selectedProvider && currentTenant) {
      hasAutoRun.current = true;
      fetchData(selectedProvider);
    }
  }, [selectedProvider, currentTenant, fetchData]);

  const handleRefresh = useCallback(() => {
    if (selectedProvider) {
      fetchData(selectedProvider, true);
    }
  }, [selectedProvider, fetchData]);

  // In COMMUNISM mode (shared hosted substrate) gap analysis isn't available
  // yet; it requires cloud credentials that only self-hosted deployments have.
  if (mode === "COMMUNISM") {
    return (
      <div className="flex flex-col w-full h-full">
        <PageHeader
          title="Gap Analysis"
          subtitle="Identify unmanaged cloud resources"
        />
        <SelfHostedOnlyNotice feature="Gap Analysis" />
      </div>
    );
  }

  if (!currentTenant) {
    return (
      <div className="flex flex-col w-full h-full">
        <PageHeader
          title="Gap Analysis"
          subtitle="Identify unmanaged cloud resources"
        />
        <div className="flex items-center justify-center flex-1">
          <div className="text-center max-w-md px-6">
            <p className="text-sm text-[var(--sg-text-muted)]">
              Please select a tenant to view gap analysis
            </p>
          </div>
        </div>
      </div>
    );
  }

  if (!selectedProvider) {
    return (
      <ProviderSelectionView
        onSelectProvider={handleSelectProvider}
        onCheckConfig={handleCheckConfig}
        isCheckingConfig={isCheckingConfig}
        configResults={configResults}
        selectedConfigProvider={selectedConfigProvider}
      />
    );
  }

  return (
    <GapAnalysisResultsView
      provider={selectedProvider}
      data={data}
      isLoading={isLoading}
      isRefreshing={isRefreshing}
      error={error}
      onRefresh={handleRefresh}
      onBack={handleBack}
    />
  );
}
