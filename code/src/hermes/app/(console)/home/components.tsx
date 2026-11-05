// Infrastructure Overview Dashboard Components
// All sections for the Ultimate Infrastructure Overview

import { useState } from 'react';
import {
  Package,
  Cloud,
  GitBranch,
  Folder,
  Layers,
  FileQuestion,
  Info,
  AlertTriangle,
  TrendingUp,
  Target,
  Radio,
  CheckCircle2,
  XCircle,
  MinusCircle,
  BarChart3,
  Zap,
  PieChart,
  type LucideIcon,
} from 'lucide-react';
import { getProviderLabel } from '@/lib/instances/attributes';
import type { useDeepLinkRouter } from "@/hooks";
import type { HomeOverviewData, HomeScalarsData, HomeAnalyticsData } from './loader';
import type { ResourceTypeData, ProviderDistribution } from './loader';

// ============================================================================
// SHARED TOOLTIP COMPONENT
// ============================================================================

function Tooltip({ text }: { text: string }) {
  return (
    <div className="relative group/tooltip inline-flex flex-shrink-0">
      <Info className="h-3 w-3 text-[var(--sg-text-dim)] opacity-50 hover:opacity-100 cursor-help" />
      <div className="absolute left-0 top-6 hidden group-hover/tooltip:block z-50 w-64 p-2 text-xs font-normal normal-case bg-[var(--sg-bg-2)] border border-[var(--sg-border)] rounded shadow-lg text-[var(--sg-text)]">
        {text}
      </div>
    </div>
  );
}

// ============================================================================
// SECTION 0: CONTROL PLANE STATUS (Transaction-aware operational signals)
// ============================================================================

interface ControlPlaneStatusProps {
  data: HomeScalarsData;
}

export function ControlPlaneStatus({ data }: ControlPlaneStatusProps) {
  return (
    <div className="space-y-2">
      <div className="flex items-center gap-2 mb-3">
        <h2 className="text-base font-semibold text-[var(--sg-text)] uppercase tracking-wide">
          Control Plane Status
        </h2>
      </div>
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <ActiveTransactionsCard data={data.activeTransactions} />
        <LastTransactionOutcomeCard data={data.lastTransactionOutcome} />
        <RecentChangesCard data={data.recentStability} />
        <LastChangeImpactCard data={data.lastChangeImpact} />
      </div>
    </div>
  );
}

interface ActiveTransactionsCardProps {
  data: HomeScalarsData['activeTransactions'];
}

function ActiveTransactionsCard({ data }: ActiveTransactionsCardProps) {
  const isActive = data.count > 0;
  const bgColor = isActive ? 'rgba(96, 165, 250, 0.1)' : 'var(--sg-bg-1)';
  const iconColor = isActive ? 'var(--sg-accent)' : 'var(--sg-text-dim)';

  return (
    <div
      className="relative rounded-lg border border-[var(--sg-border)] p-4"
      style={{ background: bgColor }}
    >
      <div className="flex items-start gap-3 mb-3">
        <div className="p-2 rounded bg-[var(--sg-bg-0)]">
          <Radio className="h-4 w-4" style={{ color: iconColor }} />
        </div>
        <div className="flex-1 min-w-0">
          <div className="text-xs font-semibold uppercase tracking-wider text-[var(--sg-text-muted)] flex items-center gap-1">
            Active Transactions
            <Tooltip text="Terraform transactions currently in progress. An active transaction means a plan or apply is running." />
          </div>
        </div>
      </div>
      <div className="text-3xl font-bold tabular-nums font-mono text-[var(--sg-text)] mb-1">
        {data.count}
      </div>
      <div className="text-xs text-[var(--sg-text-dim)]">
        {data.sublabel || (data.count === 0 ? 'System idle' : 'In progress')}
      </div>
    </div>
  );
}

interface LastTransactionOutcomeCardProps {
  data: HomeScalarsData['lastTransactionOutcome'];
}

function LastTransactionOutcomeCard({ data }: LastTransactionOutcomeCardProps) {
  const stateConfig: Record<string, { icon: LucideIcon; color: string; label: string }> = {
    committed: {
      icon: CheckCircle2,
      color: 'var(--sg-success)',
      label: 'Committed',
    },
    aborted: {
      icon: MinusCircle,
      color: 'var(--sg-warning)',
      label: 'Aborted',
    },
    failed: {
      icon: XCircle,
      color: 'var(--sg-error)',
      label: 'Failed',
    },
    'failed-committed': {
      icon: XCircle,
      color: 'var(--sg-error)',
      label: 'Apply failed',
    },
    none: {
      icon: MinusCircle,
      color: 'var(--sg-text-dim)',
      label: 'No transactions',
    },
  };

  const config = stateConfig[data.state] || stateConfig.none;
  const Icon = config.icon;

  return (
    <div className="relative rounded-lg border border-[var(--sg-border)] p-4 bg-[var(--sg-bg-1)]">
      <div className="flex items-start gap-3 mb-3">
        <div className="p-2 rounded" style={{ background: `${config.color}15` }}>
          <Icon className="h-4 w-4" style={{ color: config.color }} />
        </div>
        <div className="flex-1 min-w-0">
          <div className="text-xs font-semibold uppercase tracking-wider text-[var(--sg-text-muted)] flex items-center gap-1">
            Last Transaction
            <Tooltip text="Outcome of the most recent completed transaction — committed (applied successfully), aborted (cancelled), or failed." />
          </div>
        </div>
      </div>
      <div className="text-xl font-bold text-[var(--sg-text)] mb-1" style={{ color: config.color }}>
        {config.label}
      </div>
      <div className="text-xs text-[var(--sg-text-dim)]">{data.relativeTime}</div>
    </div>
  );
}

interface RecentChangesCardProps {
  data: HomeScalarsData['recentStability'];
}

function RecentChangesCard({ data }: RecentChangesCardProps) {
  const hasFailures = data.failedCount > 0 || data.abortedCount > 0;
  const iconColor = hasFailures ? 'var(--sg-warning)' : 'var(--sg-accent)';

  return (
    <div className="relative rounded-lg border border-[var(--sg-border)] p-4 bg-[var(--sg-bg-1)]">
      <div className="flex items-start gap-3 mb-3">
        <div className="p-2 rounded bg-[var(--sg-bg-0)]">
          <BarChart3 className="h-4 w-4" style={{ color: iconColor }} />
        </div>
        <div className="flex-1 min-w-0">
          <div className="text-xs font-semibold uppercase tracking-wider text-[var(--sg-text-muted)] flex items-center gap-1">
            Recent Changes
            <Tooltip text="Summary of transaction activity over the recent time window, including committed, aborted, and failed operations." />
          </div>
        </div>
      </div>
      <div className="text-lg font-bold text-[var(--sg-text)] mb-1 truncate">
        {data.summary}
      </div>
      <div className="text-xs text-[var(--sg-text-dim)]">Last {data.windowHours} hours</div>
    </div>
  );
}

interface LastChangeImpactCardProps {
  data: HomeScalarsData['lastChangeImpact'];
}

function LastChangeImpactCard({ data }: LastChangeImpactCardProps) {
  const hasImpact = data.blastRadius > 0;

  return (
    <div className="relative rounded-lg border border-[var(--sg-border)] p-4 bg-[var(--sg-bg-1)]">
      <div className="flex items-start gap-3 mb-3">
        <div className="p-2 rounded bg-[var(--sg-bg-0)]">
          <Zap className="h-4 w-4 text-[var(--sg-accent)]" />
        </div>
        <div className="flex-1 min-w-0">
          <div className="text-xs font-semibold uppercase tracking-wider text-[var(--sg-text-muted)] flex items-center gap-1">
            Last Change Impact
            <Tooltip text="Blast radius of the most recent committed transaction — the number of resources directly or transitively affected by the change." />
          </div>
        </div>
      </div>
      <div className="text-3xl font-bold tabular-nums font-mono text-[var(--sg-text)] mb-1">
        {hasImpact ? data.blastRadius : '—'}
      </div>
      <div className="text-xs text-[var(--sg-text-dim)]">
        {hasImpact ? 'Nodes affected' : 'No recent changes'}
      </div>
    </div>
  );
}

// ============================================================================
// SECTION 1: HERO METRICS STRIP (Infrastructure Overview)
// ============================================================================

interface HeroMetricsStripProps {
  data: HomeScalarsData;
}

export function HeroMetricsStrip({ data }: HeroMetricsStripProps) {
  return (
    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
      <HeroMetricCard
        icon={Package}
        label="Resources"
        value={data.stateSummary.instances}
        subtitle="Resources tracked"
        tooltip="Total resources tracked. Each resource maps to one real infrastructure object."
      />
      <HeroMetricCard
        icon={Folder}
        label="Modules"
        value={data.stateSummary.modules}
        subtitle="Terraform modules detected"
        tooltip="Distinct Terraform modules detected. Modules group related resources into reusable units."
      />
      <HeroMetricCard
        icon={Cloud}
        label="Providers"
        value={data.stateSummary.providers}
        subtitle="Cloud and service providers in use"
        tooltip="Number of different cloud or service providers (e.g., AWS, GCP, Azure) referenced by resources."
      />
      <HeroMetricCard
        icon={GitBranch}
        label="Graph Density"
        value={data.graphDensity.value}
        suffix="edges/res"
        subtitle="Overall connectivity"
        tooltip="Dependency edges divided by resource count. A value of 1.0 means each resource has one dependency on average. Values above 2.0 indicate heavily interconnected infrastructure where changes are more likely to cascade."
        decimals={2}
      />
    </div>
  );
}

interface HeroMetricCardProps {
  icon: React.ComponentType<{ className?: string }>;
  label: string;
  value: number;
  suffix?: string;
  subtitle: string;
  tooltip?: string;
  decimals?: number;
}

function HeroMetricCard({ icon: Icon, label, value, suffix, subtitle, tooltip, decimals = 0 }: HeroMetricCardProps) {
  return (
    <div className="group relative bg-[var(--sg-bg-1)] rounded-lg border border-[var(--sg-border)] p-4">
      <div className="flex items-start gap-3 mb-3">
        <div className="p-2 rounded bg-[var(--sg-bg-0)]">
          <Icon className="h-4 w-4 text-[var(--sg-accent)]" />
        </div>
        <div className="flex-1 min-w-0">
          <div className="text-xs font-semibold uppercase tracking-wider text-[var(--sg-text-muted)] flex items-center gap-1">
            {label}
            {tooltip && <Tooltip text={tooltip} />}
          </div>
        </div>
      </div>
      <div className="text-3xl font-bold tabular-nums font-mono text-[var(--sg-text)] mb-1">
        {decimals > 0 ? value.toFixed(decimals) : value.toLocaleString()}
        {suffix && <span className="text-sm font-medium text-[var(--sg-text-muted)] ml-2">{suffix}</span>}
      </div>
      <div className="text-xs text-[var(--sg-text-dim)]">{subtitle}</div>
    </div>
  );
}

// ============================================================================
// SECTION 2: RISK ROW
// ============================================================================

interface RiskRowProps {
  data: HomeAnalyticsData;
  router: ReturnType<typeof useDeepLinkRouter>;
}

export function RiskRow({ data, router }: RiskRowProps) {
  return (
    <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
      <RiskCard
        title="Largest Dependency Blast Radius"
        icon={AlertTriangle}
        color="warning"
        primaryValue={data.largestBlastRadius?.references || 0}
        secondaryLabel={data.largestBlastRadius?.address}
        caption="Downstream nodes potentially impacted by changes to this resource."
        tooltip="The single resource whose change would affect the most other resources, found by traversing all transitive dependencies in the graph."
        onClick={
          data.largestBlastRadius
            ? () => router.push(`/blast-radius?instance=${encodeURIComponent(data.largestBlastRadius!.address)}`)
            : undefined
        }
      />

      <RiskCard
        title="Top Dependency Hotspot"
        icon={TrendingUp}
        color="accent"
        primaryValue={data.dependencyHotspot?.inboundReferences || 0}
        primarySuffix="references"
        secondaryLabel={data.dependencyHotspot?.address}
        caption="Most depended-on resource across your infrastructure."
        tooltip="The resource that the most other resources depend on. A high count means changes here could cascade widely."
        onClick={
          data.dependencyHotspot
            ? () => router.push(`/instances?q=${encodeURIComponent(data.dependencyHotspot!.address)}`)
            : undefined
        }
      />

      <RiskCard
        title="Graph Structure"
        icon={Target}
        color="neutral"
        primaryValue={`${data.graphStructure.roots} roots · ${data.graphStructure.leaves} leaves`}
        caption="Execution entry points and terminal nodes."
        tooltip="Roots are resources with no dependencies (entry points). Leaves are resources nothing else depends on (terminal nodes). Together they describe the shape of your dependency graph."
      />
    </div>
  );
}

interface RiskCardProps {
  title: string;
  icon: React.ComponentType<{ className?: string }>;
  color: 'warning' | 'accent' | 'neutral';
  primaryValue: number | string;
  primarySuffix?: string;
  secondaryLabel?: string;
  caption: string;
  tooltip?: string;
  onClick?: () => void;
}

function RiskCard({ title, icon: Icon, color, primaryValue, primarySuffix, secondaryLabel, caption, tooltip, onClick }: RiskCardProps) {
  const Component = onClick ? 'button' : 'div';

  const colorMap = {
    warning: { border: 'var(--sg-warning)', bg: 'rgba(255, 170, 0, 0.1)', text: 'var(--sg-warning)' },
    accent: { border: 'var(--sg-accent)', bg: 'var(--sg-accent-bg)', text: 'var(--sg-accent)' },
    neutral: { border: 'var(--sg-border)', bg: 'var(--sg-accent-bg)', text: 'var(--sg-accent)' },
  };

  const colors = colorMap[color];
  const hasValue = typeof primaryValue === 'number' ? primaryValue > 0 : true;

  return (
    <Component
      onClick={onClick}
      className={`p-5 rounded-lg border-l-4 bg-[var(--sg-bg-2)] transition-colors duration-150 ${
        onClick ? 'cursor-pointer hover:bg-[var(--sg-bg-1)]' : ''
      }`}
      style={{
        borderLeft: `4px solid ${hasValue ? colors.border : 'var(--sg-border)'}`,
      }}
    >
      <div className="flex items-start gap-3 mb-4">
        <div className="p-2 rounded" style={{ background: colors.bg, color: colors.text }}>
          <Icon className="h-5 w-5" />
        </div>
        <div className="flex-1 min-w-0">
          <div className="text-xs font-semibold uppercase tracking-wider text-[var(--sg-text-muted)] flex items-center gap-1">
            {title}
            {tooltip && <Tooltip text={tooltip} />}
          </div>
        </div>
      </div>
      <div className="mb-2">
        <div className="flex items-baseline gap-2">
          <div className="text-2xl font-bold tabular-nums font-mono text-[var(--sg-text)]">
            {typeof primaryValue === 'number' ? primaryValue.toLocaleString() : primaryValue}
          </div>
          {primarySuffix && (
            <div className="text-sm font-medium text-[var(--sg-text-muted)]">{primarySuffix}</div>
          )}
        </div>
        {secondaryLabel && (
          <div className="text-xs font-mono truncate mt-1" style={{ color: colors.text }}>
            {secondaryLabel}
          </div>
        )}
      </div>
      <div className="text-xs text-[var(--sg-text-dim)] leading-relaxed">{caption}</div>
    </Component>
  );
}

// ============================================================================
// SECTION 3: COMPOSITION ROW
// ============================================================================

interface CompositionRowProps {
  data: HomeOverviewData;
  router: ReturnType<typeof useDeepLinkRouter>;
}

export function CompositionRow({ data, router }: CompositionRowProps) {
  return (
    <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
      <ResourceTypeDistribution data={data.resourcesSummary} router={router} />
      <ProviderDistribution data={data.providerDistribution} router={router} />
    </div>
  );
}

interface ResourceTypeDistributionProps {
  data: ResourceTypeData[];
  router: ReturnType<typeof useDeepLinkRouter>;
}

function ResourceTypeDistribution({ data, router }: ResourceTypeDistributionProps) {
  const topFive = data.slice(0, 5);
  const remaining = data.length - 5;
  const maxInstances = Math.max(...topFive.map(d => d.instances));

  return (
    <div className="h-[360px] p-5 rounded-lg border bg-[var(--sg-bg-2)] border-[var(--sg-border)] flex flex-col">
      <div className="text-sm font-semibold text-[var(--sg-text)] mb-1 flex items-center gap-1">
        Resource Type Distribution
        <Tooltip text="Breakdown of resource instances by Terraform type. Click a row to view all resources of that type." />
      </div>
      <div className="text-xs text-[var(--sg-text-dim)] mb-5">
        Breakdown of resources by Terraform type.
      </div>
      <div className="space-y-3 flex-1">
        {topFive.map((item, i) => {
          const percentage = (item.instances / maxInstances) * 100;
          return (
            <button
              key={i}
              {...router.nav(`/types?filter=${encodeURIComponent(item.type)}`)}
              className="w-full text-left hover:bg-[var(--sg-bg-1)] p-2 rounded transition-colors cursor-pointer"
            >
              <div className="flex items-center justify-between mb-1.5">
                <div className="text-xs font-mono truncate flex-1 text-[var(--sg-text)]">
                  {item.type}
                </div>
                <div className="text-xs font-bold tabular-nums ml-2 text-[var(--sg-text-muted)]">
                  {item.instances.toLocaleString()}
                </div>
              </div>
              <div className="w-full h-2.5 rounded-full overflow-hidden bg-[var(--sg-bg-1)]">
                <div
                  className="h-full rounded-full transition-all duration-500"
                  style={{
                    width: `${percentage}%`,
                    background: 'var(--sg-accent)',
                  }}
                />
              </div>
            </button>
          );
        })}
        {remaining > 0 && (
          <div className="text-xs font-medium pt-2 text-[var(--sg-text-dim)]">
            + {remaining} more type{remaining !== 1 ? 's' : ''}
          </div>
        )}
      </div>
    </div>
  );
}

interface ProviderDistributionProps {
  data: ProviderDistribution[];
  router: ReturnType<typeof useDeepLinkRouter>;
}

function ProviderDistribution({ data, router }: ProviderDistributionProps) {
  const isSingleProvider = data.length === 1;

  return (
    <div className="h-[360px] p-5 rounded-lg border bg-[var(--sg-bg-2)] border-[var(--sg-border)]">
      <div className="text-sm font-semibold text-[var(--sg-text)] mb-1 flex items-center gap-1">
        Provider Distribution
        <Tooltip text="Cloud and service providers referenced by your resources. Click a provider to filter the inventory." />
      </div>
      <div className="text-xs text-[var(--sg-text-dim)] mb-5">
        Cloud and service providers in use.
      </div>

      {isSingleProvider ? (
        <div className="flex flex-col items-start gap-3 pt-4">
          <div className="px-4 py-2.5 rounded-lg text-lg font-medium bg-[var(--sg-accent-bg)] text-[var(--sg-accent)]">
            {data[0].provider}
          </div>
          <div className="text-sm font-semibold text-[var(--sg-text-muted)]">
            100% — Single provider
          </div>
        </div>
      ) : (
        <div className="space-y-5 pt-2">
          {/* Stacked bar */}
          <div className="w-full h-14 rounded-lg overflow-hidden flex bg-[var(--sg-bg-1)]">
            {data.slice(0, 5).map((item, i) => {
              const colors = ['var(--sg-accent)', '#60a5fa', '#3b82f6', '#2563eb', '#1d4ed8'];
              return (
                <button
                  key={i}
                  {...router.nav(`/instances?provider=${encodeURIComponent(item.provider)}`)}
                  className="h-full transition-opacity hover:opacity-80 cursor-pointer"
                  style={{
                    width: `${item.percentage}%`,
                    background: colors[i % colors.length],
                  }}
                  title={`${item.provider}: ${item.percentage.toFixed(1)}%`}
                />
              );
            })}
          </div>
          {/* Provider list */}
          <div className="space-y-2">
            {data.map((item, i) => {
              const colors = ['var(--sg-accent)', '#60a5fa', '#3b82f6', '#2563eb', '#1d4ed8'];
              return (
                <button
                  key={i}
                  {...router.nav(`/instances?provider=${encodeURIComponent(item.provider)}`)}
                  className="w-full flex items-center gap-3 p-2 rounded transition-colors hover:bg-[var(--sg-bg-1)] cursor-pointer text-left"
                >
                  <div className="w-3 h-3 rounded-full flex-shrink-0" style={{ background: colors[i % colors.length] }} />
                  <div className="flex-1 min-w-0">
                    <div className="text-sm font-medium truncate text-[var(--sg-text)]">
                      {item.provider}
                    </div>
                  </div>
                  <div className="text-sm font-semibold tabular-nums text-[var(--sg-text-muted)]">
                    {item.percentage.toFixed(0)}%
                  </div>
                </button>
              );
            })}
          </div>
        </div>
      )}
    </div>
  );
}

// ============================================================================
// SECTION 4: CONTROL PLANE INSIGHTS GRID
// ============================================================================

interface ControlPlaneInsightsGridProps {
  data: HomeOverviewData;
}

export function ControlPlaneInsightsGrid({ data }: ControlPlaneInsightsGridProps) {
  return (
    <div>
      <div className="flex items-center gap-2 mb-4">
        <h2 className="text-lg font-semibold text-[var(--sg-text)]">Control Plane Insights</h2>
        <div className="relative group">
          <Info className="h-4 w-4 text-[var(--sg-text-dim)] opacity-50 hover:opacity-100 cursor-help" />
          <div className="absolute left-0 top-6 hidden group-hover:block z-50 w-80 p-3 text-xs bg-[var(--sg-bg-2)] border border-[var(--sg-border)] rounded shadow-lg text-[var(--sg-text)]">
            These metrics are computed from the graph and state metadata. They provide intelligence that the Terraform CLI does not show.
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        <InsightCard
          icon={Folder}
          title="Largest Module"
          primaryValue={data.largestModule?.name || 'N/A'}
          secondaryValue={data.largestModule ? `${data.largestModule.resource_count} resources` : undefined}
          caption="Biggest concentration of resources."
          tooltip="The Terraform module containing the most resources. Large modules may benefit from decomposition into smaller, focused units."
        />

        <InsightCard
          icon={Layers}
          title="Most Deployed Module"
          primaryValue={data.mostDeployedModule?.name || 'N/A'}
          secondaryValue={data.mostDeployedModule ? `${data.mostDeployedModule.instance_count} resources` : undefined}
          caption="Module instantiated the most times."
          tooltip="The module that appears the most times across different resource instances. High reuse indicates a well-designed shared module."
        />

        <InsightCard
          icon={Package}
          title="Top Resource Type"
          primaryValue={data.topResourceType?.type || 'N/A'}
          secondaryValue={data.topResourceType ? `${data.topResourceType.instances} resources` : undefined}
          caption="Where most of your resources live."
          tooltip="The Terraform resource type (e.g., aws_security_group_rule) with the most instances."
        />

        <OrphanedCandidatesCard data={data.orphanedCandidates} />

        <ProviderDistributionCard data={data.providerDistribution} />

        <ResourceTypeDistributionCard data={data.resourcesSummary} />
      </div>
    </div>
  );
}

interface InsightCardProps {
  icon: React.ComponentType<{ className?: string }>;
  title: string;
  primaryValue: string;
  secondaryValue?: string;
  caption: string;
  tooltip?: string;
}

function InsightCard({ icon: Icon, title, primaryValue, secondaryValue, caption, tooltip }: InsightCardProps) {
  return (
    <div className="p-4 rounded-lg border bg-[var(--sg-bg-2)] border-[var(--sg-border)]">
      <div className="flex items-start gap-3 mb-3">
        <div className="p-2 rounded bg-[var(--sg-bg-0)]">
          <Icon className="h-4 w-4 text-[var(--sg-accent)]" />
        </div>
        <div className="flex-1 min-w-0">
          <div className="text-xs font-semibold uppercase tracking-wider text-[var(--sg-text-muted)] flex items-center gap-1">
            {title}
            {tooltip && <Tooltip text={tooltip} />}
          </div>
        </div>
      </div>
      <div className="mb-2">
        <div className="text-lg font-bold text-[var(--sg-text)] truncate">
          {primaryValue}
        </div>
        {secondaryValue && (
          <div className="text-xs font-medium text-[var(--sg-text-muted)]">
            {secondaryValue}
          </div>
        )}
      </div>
      <div className="text-xs text-[var(--sg-text-dim)] leading-relaxed">{caption}</div>
    </div>
  );
}

// ============================================================================
// DISTRIBUTION CARDS WITH DOUGHNUT CHARTS
// ============================================================================

// Provider Distribution Card with Doughnut Chart
interface ProviderDistributionCardProps {
  data: ProviderDistribution[];
}

function ProviderDistributionCard({ data }: ProviderDistributionCardProps) {
  // Take top 4 providers, group rest as "Other"
  const maxProviders = 4;
  const topProviders = data.slice(0, maxProviders);
  const otherProviders = data.slice(maxProviders);
  const otherTotal = otherProviders.reduce((sum, p) => sum + p.instances, 0);

  const chartData = [...topProviders];
  if (otherTotal > 0) {
    chartData.push({ provider: 'Other', instances: otherTotal, percentage: 0 });
  }

  // Recalculate percentages for chart data
  const total = chartData.reduce((sum, p) => sum + p.instances, 0);
  chartData.forEach(p => {
    p.percentage = total > 0 ? (p.instances / total) * 100 : 0;
  });

  // Color palette for providers
  const colors = [
    '#60a5fa', // blue (accent)
    '#34d399', // green
    '#fbbf24', // yellow
    '#f87171', // red
    '#a78bfa', // purple
  ];

  // Calculate donut segments using stroke-dasharray (much simpler and more reliable)
  const size = 100;
  const strokeWidth = 12;
  const radius = (size - strokeWidth) / 2;
  const circumference = 2 * Math.PI * radius;

  let cumulativePercent = 0;

  return (
    <div className="relative rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-1)] p-4">
      <div className="flex items-start gap-3 mb-3">
        <div className="p-2 rounded bg-[var(--sg-bg-0)]">
          <PieChart className="h-4 w-4 text-[var(--sg-accent)]" />
        </div>
        <div className="flex-1 min-w-0">
          <div className="text-sm font-semibold text-[var(--sg-text)] mb-1 flex items-center gap-1">
            Provider Distribution
            <Tooltip text="Breakdown of resource instances by cloud or service provider. Shows how your infrastructure is distributed across providers." />
          </div>
        </div>
      </div>

      <div className="flex items-center gap-4">
        {/* Doughnut Chart */}
        <div className="flex-shrink-0">
          <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
            {chartData.map((item, index) => {
              const percent = item.percentage / 100;
              const strokeDasharray = `${percent * circumference} ${circumference}`;
              const strokeDashoffset = -cumulativePercent * circumference;
              cumulativePercent += percent;

              return (
                <circle
                  key={index}
                  cx={size / 2}
                  cy={size / 2}
                  r={radius}
                  fill="none"
                  stroke={colors[index % colors.length]}
                  strokeWidth={strokeWidth}
                  strokeDasharray={strokeDasharray}
                  strokeDashoffset={strokeDashoffset}
                  transform={`rotate(-90 ${size / 2} ${size / 2})`}
                  className="transition-opacity hover:opacity-80"
                  style={{ opacity: 0.9 }}
                />
              );
            })}
          </svg>
        </div>

        {/* Legend */}
        <div className="flex-1 min-w-0 space-y-1.5">
          {chartData.map((item, index) => (
            <div key={index} className="flex items-center gap-2 text-xs min-w-0">
              <div
                className="w-2 h-2 rounded-full flex-shrink-0"
                style={{ backgroundColor: colors[index % colors.length] }}
              />
              <span
                className="text-[var(--sg-text)] truncate flex-1 min-w-0"
                title={item.provider}
              >
                {getProviderLabel(item.provider)}
              </span>
              <span className="text-[var(--sg-text-muted)] tabular-nums flex-shrink-0">
                {item.percentage.toFixed(0)}%
              </span>
            </div>
          ))}
        </div>
      </div>

      <div className="mt-3 text-xs text-[var(--sg-text-dim)] leading-relaxed">
        Infrastructure provider breakdown across {total} resources.
      </div>
    </div>
  );
}

// Orphaned Candidates Card with Resource List
interface OrphanedCandidatesCardProps {
  data: {
    count: number;
    addresses: string[];
    orphanedTop?: { address: string; stateName: string }[];
    byState?: { stateName: string; count: number }[];
  };
}

function OrphanedCandidatesCard({ data }: OrphanedCandidatesCardProps) {
  const [expanded, setExpanded] = useState(false);
  const maxItems = 5;

  const orphanedTooltip =
    'Resources that no other resource depends on and are either outside any module or have at most one dependency. These are candidates for review — they may be unused or have been replaced.';

  // Determine which view to render:
  // - byState: show per-state breakdown (All States view)
  // - addresses: show top resource addresses (per-state view)
  const hasByState = data.byState && data.byState.length > 0;
  const hasAddresses = data.addresses.length > 0;

  if (data.count === 0) {
    return (
      <div className="relative rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-1)] p-4">
        <div className="flex items-start gap-3 mb-3">
          <div className="p-2 rounded bg-[var(--sg-bg-0)]">
            <FileQuestion className="h-4 w-4 text-[var(--sg-accent)]" />
          </div>
          <div className="flex-1 min-w-0">
            <div className="text-sm font-semibold text-[var(--sg-text)] mb-1 flex items-center gap-1">
              Orphaned Candidates
              <Tooltip text={orphanedTooltip} />
            </div>
          </div>
        </div>
        <div className="text-center py-6 text-[var(--sg-text-dim)]">
          <FileQuestion className="h-8 w-8 mx-auto mb-2 opacity-50" />
          <div className="text-sm">No orphaned resources found</div>
        </div>
        <div className="mt-3 text-xs text-[var(--sg-text-dim)] leading-relaxed">
          Detected by graph analysis.
        </div>
      </div>
    );
  }

  return (
    <div className="relative rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-1)] p-4">
      <div className="flex items-start gap-3 mb-3">
        <div className="p-2 rounded bg-[var(--sg-bg-0)]">
          <FileQuestion className="h-4 w-4 text-[var(--sg-accent)]" />
        </div>
        <div className="flex-1 min-w-0">
          <div className="text-sm font-semibold text-[var(--sg-text)] mb-1 flex items-center gap-1">
            Orphaned Candidates
            <Tooltip text={orphanedTooltip} />
          </div>
          <div className="text-xs text-[var(--sg-text-muted)]">
            {data.count} resource{data.count !== 1 ? 's' : ''}
          </div>
        </div>
      </div>

      <div className="space-y-2">
        {hasByState ? (
          /* Per-state breakdown (All States view) */
          <>
            {(expanded ? data.byState! : data.byState!.slice(0, maxItems)).map((item, index) => (
              <div
                key={index}
                className="flex items-center justify-between text-xs bg-[var(--sg-bg-0)] rounded px-2 py-1.5 border border-[var(--sg-border)]"
              >
                <span className="text-[var(--sg-text)] truncate">{item.stateName}</span>
                <span className="text-[var(--sg-text-muted)] tabular-nums font-medium ml-2 flex-shrink-0">
                  {item.count}
                </span>
              </div>
            ))}
            {data.byState!.length > maxItems && (
              <button
                onClick={() => setExpanded(!expanded)}
                className="w-full text-xs text-[var(--sg-accent)] hover:text-[var(--sg-text)] text-center pt-1 transition-colors cursor-pointer"
              >
                {expanded ? 'Show less' : `+${data.byState!.length - maxItems} more state${data.byState!.length - maxItems !== 1 ? 's' : ''}`}
              </button>
            )}
          </>
        ) : hasAddresses ? (
          /* Top addresses (per-state view) */
          <>
            {(expanded ? data.addresses : data.addresses.slice(0, maxItems)).map((address, index) => (
              <div
                key={index}
                className="text-xs font-mono text-[var(--sg-text)] truncate bg-[var(--sg-bg-0)] rounded px-2 py-1.5 border border-[var(--sg-border)]"
                title={address}
              >
                {address}
              </div>
            ))}
            {data.addresses.length > maxItems && (
              <button
                onClick={() => setExpanded(!expanded)}
                className="w-full text-xs text-[var(--sg-accent)] hover:text-[var(--sg-text)] text-center pt-1 transition-colors cursor-pointer"
              >
                {expanded ? 'Show less' : `+${data.addresses.length - maxItems} more`}
              </button>
            )}
          </>
        ) : (
          /* Fallback: count only */
          <div className="text-center py-4 text-[var(--sg-text-dim)]">
            <AlertTriangle className="h-6 w-6 mx-auto mb-2 opacity-60" />
            <div className="text-2xl font-bold tabular-nums font-mono text-[var(--sg-text)] mb-1">{data.count}</div>
            <div className="text-xs">orphaned candidates detected</div>
          </div>
        )}
      </div>

      <div className="mt-3 text-xs text-[var(--sg-text-dim)] leading-relaxed">
        Detected by graph analysis.
      </div>
    </div>
  );
}

// Resource Type Distribution Card with Horizontal Bar Chart
interface ResourceTypeDistributionCardProps {
  data: ResourceTypeData[];
}

function ResourceTypeDistributionCard({ data }: ResourceTypeDistributionCardProps) {
  // Take top 5 resource types
  const maxTypes = 5;
  const topTypes = data.slice(0, maxTypes);

  // Calculate total for percentages
  const total = data.reduce((sum, t) => sum + t.instances, 0);
  const maxInstances = topTypes.length > 0 ? topTypes[0].instances : 0;

  return (
    <div className="relative rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-1)] p-4">
      <div className="flex items-start gap-3 mb-3">
        <div className="p-2 rounded bg-[var(--sg-bg-0)]">
          <Layers className="h-4 w-4 text-[var(--sg-accent)]" />
        </div>
        <div className="flex-1 min-w-0">
          <div className="text-sm font-semibold text-[var(--sg-text)] mb-1 flex items-center gap-1">
            Top Resource Types
            <Tooltip text="The most common Terraform resource types, ranked by instance count. Click a type to view its resources." />
          </div>
        </div>
      </div>

      <div className="space-y-2.5">
        {topTypes.map((item, index) => {
          const _percentage = total > 0 ? (item.instances / total) * 100 : 0;
          const barWidth = maxInstances > 0 ? (item.instances / maxInstances) * 100 : 0;

          return (
            <div key={index} className="space-y-1">
              <div className="flex items-baseline justify-between gap-2">
                <span className="text-xs font-mono text-[var(--sg-text)] truncate flex-1">
                  {item.type}
                </span>
                <span className="text-xs tabular-nums text-[var(--sg-text-muted)] flex-shrink-0">
                  {item.instances}
                </span>
              </div>
              <div className="h-1.5 bg-[var(--sg-bg-0)] rounded-full overflow-hidden">
                <div
                  className="h-full bg-[var(--sg-accent)] rounded-full transition-all duration-300"
                  style={{ width: `${barWidth}%` }}
                />
              </div>
            </div>
          );
        })}
      </div>

      <div className="mt-3 text-xs text-[var(--sg-text-dim)] leading-relaxed">
        Most common resource types across {total} resources.
      </div>
    </div>
  );
}

// ============================================================================
// LOADING SKELETON
// ============================================================================

/**
 * Skeleton for just the graph-analytics region (Risk row + Insights grid).
 * Rendered in place while `homeGraphAnalyticsQuery` streams in, after the
 * scalar widgets above it have already painted.
 */
export function AnalyticsSkeleton() {
  return (
    <div className="space-y-8 animate-pulse">
      {/* Risk row */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {[...Array(3)].map((_, i) => (
          <div key={`risk-${i}`} className="h-[160px] rounded-lg bg-[var(--sg-bg-2)]" />
        ))}
      </div>

      {/* Insights grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {[...Array(6)].map((_, i) => (
          <div key={`insight-${i}`} className="h-[160px] rounded-lg bg-[var(--sg-bg-2)]" />
        ))}
      </div>
    </div>
  );
}

export function LoadingSkeleton() {
  return (
    <div className="space-y-8 animate-pulse">
      {/* Control Plane Status */}
      <div className="space-y-3">
        <div className="h-6 w-48 rounded bg-[var(--sg-bg-2)]" />
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
          {[...Array(4)].map((_, i) => (
            <div key={`status-${i}`} className="h-[120px] rounded-lg bg-[var(--sg-bg-2)]" />
          ))}
        </div>
      </div>

      {/* State Structure */}
      <div className="space-y-3">
        <div className="h-6 w-56 rounded bg-[var(--sg-bg-2)]" />
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
          {[...Array(4)].map((_, i) => (
            <div key={`hero-${i}`} className="h-[120px] rounded-lg bg-[var(--sg-bg-2)]" />
          ))}
        </div>
      </div>

      {/* Risk row */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {[...Array(3)].map((_, i) => (
          <div key={`risk-${i}`} className="h-[160px] rounded-lg bg-[var(--sg-bg-2)]" />
        ))}
      </div>

      {/* Insights grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {[...Array(6)].map((_, i) => (
          <div key={`insight-${i}`} className="h-[160px] rounded-lg bg-[var(--sg-bg-2)]" />
        ))}
      </div>
    </div>
  );
}
