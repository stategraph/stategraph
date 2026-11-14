"use client";

import { Suspense, useCallback, useEffect, useState } from 'react';
import { useSearchParams } from 'next/navigation';
import {
  loadHomeScalars,
  loadHomeAnalytics,
  type HomeScalarsData,
  type HomeAnalyticsData,
} from './home/loader';
import {
  resolveHostedHomeDestination,
  type HostedHomeDestination,
} from './home/mqlQueries';
import { WelcomePanel } from './home/WelcomePanel';
import { HomeSetupCard } from './home/HomeSetupCard';
import { useDeepLinkRouter, useFirstRunSetup, useStateSelection } from '@/hooks';
import { PageHeader } from '@/components/page/PageHeader';
import { BootstrapLoader } from '@/components/layout/bootstrap-loader';
import {
  RefreshCw,
  Network,
  Search,
  Box,
  AlertCircle,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { useAuth } from '@/components/auth';
import { useTenant } from '@/contexts/TenantContext';
import { useStates } from '@/contexts/StateContext';
import { useSetupProgress } from '@/contexts';
import { homeLayout } from '@/lib/getting-started/setup-progress';
import {
  START_INTENT_PARAM,
  clearStartIntent,
  readStartIntent,
  setupDestination,
  stashStartIntent,
} from '@/lib/getting-started/start-intent';
import { hasSeenFirstRun, markFirstRunSeen } from '@/lib/getting-started/first-run';
import { StateFilter } from '@/components/filters';
import {
  ControlPlaneStatus,
  HeroMetricsStrip,
  RiskRow,
  ControlPlaneInsightsGrid,
  LoadingSkeleton,
  AnalyticsSkeleton,
  StateOverviewSkeleton,
} from './home/components';
import { HomeOrchestrationBand } from '@/components/home/HomeOrchestrationBand';
import { HomeHelpFooter } from '@/components/home/HomeHelpFooter';
import { NeedsAttention } from '@/components/home/NeedsAttention';
import { NextSteps } from '@/components/home/NextSteps';
import { useHomeOrchestration } from '@/components/home/useHomeOrchestration';

function HomePageContent() {
  const router = useDeepLinkRouter();
  const searchParams = useSearchParams();
  const { isLoading: authLoading, isAuthenticated } = useAuth();
  const { currentTenant, tenants, isLoading: tenantLoading } = useTenant();
  const { states, isLoading: statesLoading } = useStates();
  const progress = useSetupProgress();
  const firstRunSetup = useFirstRunSetup();
  const layout = homeLayout(firstRunSetup, progress.shape);
  const stateSections = layout.stateSections;

  // The website's Start buttons name the product on the landing URL. Keep it
  // for the redirect below, which happens after the facts load.
  const startIntent = searchParams.get(START_INTENT_PARAM);
  useEffect(() => {
    stashStartIntent(startIntent);
  }, [startIntent]);

  // Per-page state selection (synced to URL ?state= param)
  const [selectedStateId, setSelectedStateId] = useStateSelection();

  const isAllStates = selectedStateId === "all";

  // Get the currently selected state object (null when "all")
  const currentState = isAllStates ? null : (states.find(s => s.id === selectedStateId) || null);

  // The dashboard loads in two independent phases (#1072): the cheap scalar
  // widgets (`scalars`) paint first, and the expensive graph analytics
  // (`analytics`) stream in without blocking first paint.
  const [scalars, setScalars] = useState<HomeScalarsData | null>(null);
  const [analytics, setAnalytics] = useState<HomeAnalyticsData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [analyticsError, setAnalyticsError] = useState<string | null>(null);
  // Bumped by the Refresh button to force a reload without changing selection.
  const [reloadKey, setReloadKey] = useState(0);

  // Preserve the existing first-run guards. Only an authenticated user on a
  // server with first-run setup, with one tenant and a fully loaded empty state
  // list, needs the orchestration-aware routing decision below.
  const shouldResolveHomeOnboarding =
    isAuthenticated &&
    !!currentTenant &&
    !tenantLoading &&
    !statesLoading &&
    states.length === 0 &&
    firstRunSetup !== false &&
    tenants.length <= 1;

  let homeOnboardingDestination: HostedHomeDestination | "checking" = "home";
  if (shouldResolveHomeOnboarding) {
    if (progress.isLoading || firstRunSetup === null) {
      homeOnboardingDestination = "checking";
    } else {
      // A partial provider failure cannot prove the tenant has no run history,
      // so the installation list is not consulted either.
      const unknownHistory = progress.hasWorkManifest === null;
      const linkedInstallation = unknownHistory ? null : progress.linkedInstallation;
      homeOnboardingDestination = resolveHostedHomeDestination({
        stateCount: 0,
        hasWorkManifest: progress.hasWorkManifest === true,
        linkedInstallation,
      });
      // Setup is entered by itself once per tenant and browser. After that Home
      // is Home, with the welcome panel, and leaving the wizard sticks.
      if (homeOnboardingDestination === "setup" && hasSeenFirstRun(currentTenant.id)) {
        homeOnboardingDestination = "home";
      }
    }
  }

  // Load data for both "all states" and specific state views via MQL.
  useEffect(() => {
    if (!isAuthenticated || !currentTenant) return;
    // For a specific state, wait until the state object is resolved
    if (!isAllStates && !currentState) return;
    // Skip the MQL barrage while the orchestration-aware first-run route is
    // resolving or about to redirect. A tenant with run history resolves to
    // Home and loads the dashboard normally.
    if (homeOnboardingDestination !== "home") return;
    if (!stateSections) return;

    const tenantId = currentTenant.id;
    const stateId = isAllStates ? undefined : currentState?.id;
    let cancelled = false;

    function fetchData() {
      setLoading(true);
      setError(null);
      setAnalyticsError(null);
      setScalars(null);
      setAnalytics(null);

      // Phase 1: cheap scalars + transaction metrics — unblocks first paint.
      loadHomeScalars(tenantId, stateId)
        .then((result) => { if (!cancelled) setScalars(result); })
        .catch((e: unknown) => {
          if (cancelled) return;
          setError(e instanceof Error ? e.message : 'Failed to load infrastructure data');
        })
        .finally(() => { if (!cancelled) setLoading(false); });

      // Phase 2: whole-estate graph analytics — streams in independently.
      loadHomeAnalytics(stateId)
        .then((result) => { if (!cancelled) setAnalytics(result); })
        .catch((e: unknown) => {
          if (cancelled) return;
          setAnalyticsError(e instanceof Error ? e.message : 'Failed to load analytics');
        });
    }

    fetchData();
    return () => { cancelled = true; };
  }, [isAuthenticated, currentTenant, isAllStates, currentState, homeOnboardingDestination, stateSections, reloadKey]);

  // Retry just the analytics phase (the scalars above it stay put).
  const retryAnalytics = useCallback(() => {
    if (!currentTenant) return;
    const stateId = isAllStates ? undefined : currentState?.id;
    if (!isAllStates && !stateId) return;
    setAnalyticsError(null);
    setAnalytics(null);
    loadHomeAnalytics(stateId)
      .then(setAnalytics)
      .catch((e: unknown) => {
        setAnalyticsError(e instanceof Error ? e.message : 'Failed to load analytics');
      });
  }, [currentTenant, isAllStates, currentState]);

  // Redirect to login if not authenticated
  useEffect(() => {
    if (!authLoading && !isAuthenticated) {
      router.replace("/login");
    }
  }, [authLoading, isAuthenticated, router]);

  // A fresh user with nothing started goes into setup: orchestration
  // first, or the state wizard when the site's Start button said so. Once an
  // installation is linked, Home renders with a next-step card instead.
  // tenants.length > 1 signals a dedicated tenant is already in play.
  const homeRedirectHref =
    homeOnboardingDestination === "setup" ? setupDestination(readStartIntent()) : null;

  useEffect(() => {
    if (!homeRedirectHref) return;
    if (currentTenant) markFirstRunSeen(currentTenant.id);
    clearStartIntent();
    router.replace(homeRedirectHref);
  }, [currentTenant, homeRedirectHref, router]);

  // The page chrome renders immediately and only the content area swaps
  // skeleton → (empty | data). `bootstrapping` covers every pre-content state
  // (tenant resolving, states loading, or a pending migrate redirect) so we show
  // the in-place skeleton instead of a full-screen swap, and the empty state can
  // only appear once tenant + states have truly settled.
  const bootstrapping =
    tenantLoading ||
    statesLoading ||
    homeOnboardingDestination !== "home" ||
    (!currentTenant && tenants.length > 0);

  const orchestration = useHomeOrchestration({
    tenantId: currentTenant?.id ?? "",
    enabled:
      isAuthenticated && !bootstrapping && !!currentTenant && (layout.orchestration || layout.attention),
    includeTransactions: layout.attention && stateSections,
    reloadKey,
  });

  // Until auth resolves (or while we bounce an unauthenticated user to login)
  // show ONE calm loader and no console chrome — never a flash of protected UI.
  if (authLoading || !isAuthenticated) {
    return <BootstrapLoader />;
  }

  const refreshing = stateSections && loading;

  const band =
    layout.orchestration && orchestration ? (
      <HomeOrchestrationBand data={orchestration} wide={!layout.columns} />
    ) : null;

  const stateOverview = !stateSections ? null : scalars ? (
    <div className="space-y-8">
      {/* CONTROL PLANE STATUS (scalar phase) */}
      <ControlPlaneStatus data={scalars} />

      {/* STATE STRUCTURE — infra-as-a-db, demoted below orchestration */}
      <div className="space-y-4">
        <div className="flex items-center gap-2">
          <h2 className="text-base font-semibold text-[var(--sg-text)] uppercase tracking-wide">
            State Structure
          </h2>
        </div>
        <HeroMetricsStrip data={scalars} />
      </div>
    </div>
  ) : (
    <StateOverviewSkeleton />
  );

  // Graph analytics stream in after the scalars.
  const stateAnalytics = !stateSections ? null : !scalars ? (
    <AnalyticsSkeleton />
  ) : analytics ? (
    <>
      <RiskRow data={analytics} router={router} />
      <ControlPlaneInsightsGrid data={{ ...scalars, ...analytics }} />
    </>
  ) : analyticsError ? (
    <div className="flex items-center gap-3 px-4 py-3 rounded-lg border bg-[var(--sg-bg-1)] border-[var(--sg-border)]">
      <AlertCircle className="h-5 w-5 text-[var(--sg-error)]" />
      <div className="flex-1">
        <div className="font-medium text-[var(--sg-text)]">Analytics unavailable</div>
        <div className="text-sm text-[var(--sg-text-muted)]">{analyticsError}</div>
      </div>
      <Button variant="outline" size="sm" onClick={retryAnalytics}>
        Retry
      </Button>
    </div>
  ) : (
    <AnalyticsSkeleton />
  );

  // Render main content (chrome always present, content area swaps in place)
  return (
    <div className="flex flex-col w-full min-h-screen bg-[var(--sg-bg-0)]">
      {/* HEADER */}
      <PageHeader
        title="Home"
        subtitle="Infrastructure state and orchestration activity at a glance"
      >
        <div className="flex flex-wrap items-center gap-2">
          {stateSections ? (
            <>
              <StateFilter
                value={selectedStateId}
                onChange={setSelectedStateId}
                showAllOption
                className="w-full sm:w-auto sm:min-w-[200px]"
              />
              <div className="hidden lg:block h-6 w-px bg-[var(--sg-border)] mx-1" />
              <Button
                variant="default"
                size="sm"
                {...router.nav('/graph-explorer')}
                aria-label="Graph Explorer"
                title="Graph Explorer"
              >
                <Network className="w-4 h-4 lg:mr-2" />
                <span className="hidden lg:inline">Graph Explorer</span>
              </Button>
              <Button
                variant="outline"
                size="sm"
                {...router.nav('/search')}
                aria-label="Search Resources"
                title="Search Resources"
              >
                <Search className="w-4 h-4 lg:mr-2" />
                <span className="hidden lg:inline">Search Resources</span>
              </Button>
              <Button
                variant="outline"
                size="sm"
                {...router.nav('/instances')}
                aria-label="Inventory"
                title="Inventory"
              >
                <Box className="w-4 h-4 lg:mr-2" />
                <span className="hidden lg:inline">Inventory</span>
              </Button>
              <div className="hidden lg:block h-6 w-px bg-[var(--sg-border)] mx-1" />
            </>
          ) : null}
          <Button
            variant="outline"
            size="sm"
            onClick={() => {
              // Force a reload without changing the state selection.
              setError(null);
              setAnalyticsError(null);
              setReloadKey((k) => k + 1);
              progress.revalidate();
            }}
            disabled={refreshing}
            aria-label="Refresh"
            title="Refresh"
          >
            <RefreshCw className={`w-4 h-4 lg:mr-2 ${refreshing ? 'animate-spin' : ''}`} />
            <span className="hidden lg:inline">Refresh</span>
          </Button>
        </div>
      </PageHeader>

      {/* MAIN CONTENT */}
      <div className="@container flex-1 max-w-[1600px] w-full mx-auto px-6 py-6 pb-12">
        {/* Error Alert */}
        {stateSections && error && (
          <div className="mb-6">
            <div className="flex items-center gap-3 px-4 py-3 rounded-lg border bg-[var(--sg-bg-1)] border-[var(--sg-error)]">
              <AlertCircle className="h-5 w-5 text-[var(--sg-error)]" />
              <div className="flex-1">
                <div className="font-medium text-[var(--sg-error)]">Failed to load</div>
                <div className="text-sm text-[var(--sg-text-muted)]">{error}</div>
              </div>
              <Button
                variant="outline"
                size="sm"
                onClick={() => {
                  setError(null);
                  setAnalyticsError(null);
                  setReloadKey((k) => k + 1);
                }}
              >
                Retry
              </Button>
            </div>
          </div>
        )}

        {bootstrapping ? (
          <LoadingSkeleton />
        ) : (
          <div className="space-y-8">
            {layout.welcome ? <WelcomePanel /> : null}

            {layout.card === "orchestration" ? <HomeSetupCard kind="orchestration" /> : null}

            {layout.attention && orchestration ? (
              <NeedsAttention
                attention={orchestration.attention}
                failedProviders={orchestration.attentionFailed}
                transactionsFailed={orchestration.transactionsFailed}
              />
            ) : null}

            {/* The Orchestration activity renders apart from the state sections: a
                tenant with runs and no imported state still sees its activity. */}
            {layout.columns ? (
              <div className="grid gap-8 xl:grid-cols-2 xl:items-start">
                <div className="min-w-0">{band}</div>
                <div className="@container min-w-0">{stateOverview}</div>
              </div>
            ) : (
              <>
                {band}
                {stateOverview}
              </>
            )}

            {layout.nextSteps && currentTenant ? <NextSteps tenantId={currentTenant.id} /> : null}

            {stateAnalytics}

            {layout.card === "state" ? <HomeSetupCard kind="state" /> : null}

            {layout.helpFooter ? <HomeHelpFooter /> : null}
          </div>
        )}
      </div>

    </div>
  );
}

export default function HomePage() {
  return (
    <Suspense fallback={<BootstrapLoader />}>
      <HomePageContent />
    </Suspense>
  );
}
