"use client";

import { useState, useMemo } from "react";
import {
  GapAnalysisSummary,
  UnmanagedResource,
  AWSConfigWarning,
} from "@/lib/api/client";
import {
  Cloud,
  Shield,
  AlertTriangle,
  CheckCircle2,
  Copy,
  ChevronDown,
  ChevronUp,
  Search,
  PieChart,
  Server,
  MapPin,
  X,
  FileCode,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";

// ============================================================================
// SUMMARY CARD (reusable component)
// ============================================================================

interface SummaryCardProps {
  icon: React.ReactNode;
  iconBgClass: string;
  label: string;
  value: number;
  subtitle: string;
  valueColorClass?: string;
}

function SummaryCard({
  icon,
  iconBgClass,
  label,
  value,
  subtitle,
  valueColorClass = "text-[var(--sg-text)]",
}: SummaryCardProps) {
  return (
    <div className="bg-[var(--sg-bg-1)] rounded-lg border border-[var(--sg-border)] p-4">
      <div className="flex items-start gap-3 mb-3">
        <div className={`p-2 rounded ${iconBgClass}`}>
          {icon}
        </div>
        <div className="flex-1 min-w-0">
          <div className="text-xs font-semibold uppercase tracking-wider text-[var(--sg-text-dim)]">
            {label}
          </div>
        </div>
      </div>
      <div className={`text-3xl font-bold tabular-nums ${valueColorClass}`}>
        {value.toLocaleString()}
      </div>
      <div className="text-xs text-[var(--sg-text-dim)]">
        {subtitle}
      </div>
    </div>
  );
}

// ============================================================================
// GAP SUMMARY CARDS
// ============================================================================

interface GapSummaryCardsProps {
  summary: GapAnalysisSummary;
  provider?: string;
}

export function GapSummaryCards({ summary, provider = "aws" }: GapSummaryCardsProps) {
  const phantomFiltered = summary.phantom_filtered ?? 0;

  // Use total_cloud_resources if available, fall back to total_aws_resources for backward compat
  const totalResources = summary.total_cloud_resources ?? summary.total_aws_resources ?? 0;

  // Coverage = managed / (managed + unmanaged) - excludes provider defaults since they can't be imported
  const importableResources = summary.managed_by_stategraph + summary.unmanaged;
  const coveragePercentage = importableResources > 0
    ? (summary.managed_by_stategraph / importableResources) * 100
    : 0;

  // Provider-specific labels
  const isGcp = provider === "gcp";
  const totalLabel = isGcp ? "Total GCP Resources" : "Total AWS Resources";
  const discoveryMethod = isGcp ? "Discovered by Cloud Asset Inventory" : "Discovered by Resource Explorer";
  const defaultsLabel = isGcp ? "GCP Defaults" : "AWS Defaults";

  return (
    <div className="space-y-4">
      {/* Coverage Bar */}
      <div className="bg-[var(--sg-bg-1)] rounded-lg border border-[var(--sg-border)] p-4">
        <div className="flex items-center justify-between mb-2">
          <div className="flex items-center gap-2">
            <Shield className="h-4 w-4 text-[var(--sg-success)]" />
            <span className="text-sm font-semibold text-[var(--sg-text)]">
              Terraform Coverage
            </span>
          </div>
          <span className="text-2xl font-bold tabular-nums text-[var(--sg-text)]">
            {coveragePercentage.toFixed(1)}%
          </span>
        </div>
        <div className="h-2 bg-[var(--sg-bg-2)] rounded-full overflow-hidden">
          <div
            className="h-full bg-[var(--sg-success)] rounded-full transition-all duration-500"
            style={{ width: `${coveragePercentage}%` }}
          />
        </div>
        <div className="flex justify-between mt-2 text-xs text-[var(--sg-text-dim)]">
          <span>{summary.managed_by_stategraph.toLocaleString()} managed</span>
          <span>{summary.unmanaged.toLocaleString()} unmanaged</span>
        </div>
      </div>

      {/* Summary Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <SummaryCard
          icon={<Cloud className="h-4 w-4 text-[var(--sg-accent)]" />}
          iconBgClass="bg-[var(--sg-accent-bg)]"
          label={totalLabel}
          value={totalResources}
          subtitle={discoveryMethod}
        />
        <SummaryCard
          icon={<Shield className="h-4 w-4 text-[var(--sg-success)]" />}
          iconBgClass="bg-[rgba(34,197,94,0.1)]"
          label="Managed"
          value={summary.managed_by_stategraph}
          subtitle="Tracked by Stategraph"
          valueColorClass="text-[var(--sg-success)]"
        />
        <SummaryCard
          icon={<AlertTriangle className="h-4 w-4 text-[var(--sg-warning)]" />}
          iconBgClass="bg-[rgba(245,158,11,0.1)]"
          label="Unmanaged"
          value={summary.unmanaged}
          subtitle="Not in Terraform"
          valueColorClass="text-[var(--sg-warning)]"
        />
        <SummaryCard
          icon={<Cloud className="h-4 w-4 text-[var(--sg-text-dim)]" />}
          iconBgClass="bg-[rgba(148,163,184,0.1)]"
          label={defaultsLabel}
          value={phantomFiltered}
          subtitle="Cannot be imported"
          valueColorClass="text-[var(--sg-text-dim)]"
        />
      </div>
    </div>
  );
}

// ============================================================================
// CONFIG WARNING BANNER
// ============================================================================

interface ConfigWarningBannerProps {
  warnings: AWSConfigWarning[];
}

export function ConfigWarningBanner({ warnings }: ConfigWarningBannerProps) {
  const [isExpanded, setIsExpanded] = useState(false);

  return (
    <div className="bg-[rgba(245,158,11,0.1)] border border-[var(--sg-warning)] rounded-lg p-4">
      <div className="flex items-start gap-3">
        <AlertTriangle className="h-5 w-5 text-[var(--sg-warning)] flex-shrink-0 mt-0.5" />
        <div className="flex-1 min-w-0">
          <div className="flex items-center justify-between">
            <h3 className="text-sm font-semibold text-[var(--sg-warning)]">
              AWS Configuration Warning
              {warnings.length > 1 && `s (${warnings.length})`}
            </h3>
            {warnings.length > 1 && (
              <Button
                variant="ghost"
                size="sm"
                onClick={() => setIsExpanded(!isExpanded)}
                className="h-7 px-2"
              >
                {isExpanded ? (
                  <ChevronUp className="h-4 w-4" />
                ) : (
                  <ChevronDown className="h-4 w-4" />
                )}
              </Button>
            )}
          </div>

          {/* First warning always visible */}
          <div className="mt-2 space-y-2">
            <WarningItem warning={warnings[0]} />
          </div>

          {/* Additional warnings when expanded */}
          {isExpanded && warnings.length > 1 && (
            <div className="mt-4 space-y-4 pt-4 border-t border-[var(--sg-warning)]/30">
              {warnings.slice(1).map((warning, index) => (
                <WarningItem key={index} warning={warning} />
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

function WarningItem({ warning }: { warning: AWSConfigWarning }) {
  return (
    <div className="space-y-1">
      <div className="flex items-center gap-2">
        <Badge variant="secondary" className="text-xs bg-[var(--sg-warning)]/20 text-[var(--sg-warning)]">
          {warning.code}
        </Badge>
      </div>
      <p className="text-sm text-[var(--sg-text)]">{warning.message}</p>
      <p className="text-xs text-[var(--sg-text-muted)]">
        <span className="font-medium">Fix:</span> {warning.fix}
      </p>
    </div>
  );
}

// ============================================================================
// SERVICE BREAKDOWN CHART
// ============================================================================

interface ServiceBreakdownChartProps {
  resources: UnmanagedResource[];
  provider?: string;
}

export function ServiceBreakdownChart({ resources, provider = "aws" }: ServiceBreakdownChartProps) {
  const serviceData = useMemo(() => {
    const counts: Record<string, number> = {};
    resources.forEach((r) => {
      counts[r.service] = (counts[r.service] || 0) + 1;
    });

    const sorted = Object.entries(counts)
      .sort(([, a], [, b]) => b - a);

    // Take top 5 and group rest as "Other"
    const top5 = sorted.slice(0, 5);
    const other = sorted.slice(5).reduce((sum, [, count]) => sum + count, 0);

    const result = top5.map(([service, count]) => ({ service, count }));
    if (other > 0) {
      result.push({ service: "Other", count: other });
    }

    return result;
  }, [resources]);

  const total = resources.length;

  // Color palette for services
  const colors = [
    "#60a5fa", // blue
    "#34d399", // green
    "#fbbf24", // yellow
    "#f87171", // red
    "#a78bfa", // purple
    "#94a3b8", // gray (for Other)
  ];

  // Calculate donut segments
  const size = 120;
  const strokeWidth = 16;
  const radius = (size - strokeWidth) / 2;
  const circumference = 2 * Math.PI * radius;

  // Precompute cumulative percentages to avoid mutation during render
  const cumulativePercents = serviceData.reduce<number[]>((acc, item, index) => {
    const prevCumulative = index === 0 ? 0 : acc[index - 1] + (total > 0 ? serviceData[index - 1].count / total : 0);
    acc.push(prevCumulative);
    return acc;
  }, []);

  const isGcp = provider === "gcp";
  const serviceLabel = isGcp ? "Unmanaged resources by GCP service" : "Unmanaged resources by AWS service";

  return (
    <div className="bg-[var(--sg-bg-1)] rounded-lg border border-[var(--sg-border)] p-5">
      <div className="flex items-start gap-3 mb-4">
        <div className="p-2 rounded bg-[var(--sg-accent-bg)]">
          <PieChart className="h-4 w-4 text-[var(--sg-accent)]" />
        </div>
        <div className="flex-1 min-w-0">
          <div className="text-sm font-semibold text-[var(--sg-text)]">
            Service Breakdown
          </div>
          <div className="text-xs text-[var(--sg-text-dim)]">
            {serviceLabel}
          </div>
        </div>
      </div>

      <div className="flex items-center gap-6">
        {/* Doughnut Chart */}
        <div className="flex-shrink-0">
          <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
            {serviceData.map((item, index) => {
              const percent = total > 0 ? item.count / total : 0;
              const strokeDasharray = `${percent * circumference} ${circumference}`;
              const strokeDashoffset = -cumulativePercents[index] * circumference;

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
            {/* Center text */}
            <text
              x={size / 2}
              y={size / 2}
              textAnchor="middle"
              dominantBaseline="middle"
              className="text-2xl font-bold"
              fill="var(--sg-text)"
            >
              {total}
            </text>
          </svg>
        </div>

        {/* Legend */}
        <div className="flex-1 space-y-2">
          {serviceData.map((item, index) => {
            const percentage = total > 0 ? ((item.count / total) * 100).toFixed(0) : 0;
            return (
              <div key={index} className="flex items-center gap-2 text-xs">
                <div
                  className="w-3 h-3 rounded-full flex-shrink-0"
                  style={{ backgroundColor: colors[index % colors.length] }}
                />
                <span className="text-[var(--sg-text)] truncate flex-1 font-medium">
                  {item.service}
                </span>
                <span className="text-[var(--sg-text-muted)] tabular-nums">
                  {item.count}
                </span>
                <span className="text-[var(--sg-text-dim)] tabular-nums w-10 text-right">
                  {percentage}%
                </span>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}

// ============================================================================
// AWS CONFIG STATUS CARD
// ============================================================================

interface AWSConfigStatusCardProps {
  config: {
    has_aggregator: boolean;
    indexed_regions: string[];
  };
}

export function AWSConfigStatusCard({ config }: AWSConfigStatusCardProps) {
  return (
    <div className="bg-[var(--sg-bg-1)] rounded-lg border border-[var(--sg-border)] p-5">
      <div className="flex items-start gap-3 mb-4">
        <div className="p-2 rounded bg-[var(--sg-accent-bg)]">
          <Server className="h-4 w-4 text-[var(--sg-accent)]" />
        </div>
        <div className="flex-1 min-w-0">
          <div className="text-sm font-semibold text-[var(--sg-text)]">
            AWS Config Status
          </div>
          <div className="text-xs text-[var(--sg-text-dim)]">
            Resource Explorer configuration
          </div>
        </div>
      </div>

      <div className="space-y-4">
        {/* Aggregator Status */}
        <div className="flex items-center justify-between">
          <span className="text-sm text-[var(--sg-text-muted)]">Aggregator Index</span>
          {config.has_aggregator ? (
            <Badge variant="secondary" className="bg-[var(--sg-success)]/10 text-[var(--sg-success)]">
              <CheckCircle2 className="h-3 w-3 mr-1" />
              Configured
            </Badge>
          ) : (
            <Badge variant="secondary" className="bg-[var(--sg-warning)]/10 text-[var(--sg-warning)]">
              <AlertTriangle className="h-3 w-3 mr-1" />
              Not configured
            </Badge>
          )}
        </div>

        {/* Indexed Regions */}
        <div>
          <div className="flex items-center gap-2 mb-2">
            <MapPin className="h-3.5 w-3.5 text-[var(--sg-text-dim)]" />
            <span className="text-sm text-[var(--sg-text-muted)]">
              Indexed Regions ({config.indexed_regions.length})
            </span>
          </div>
          <div className="flex flex-wrap gap-1.5">
            {config.indexed_regions.length > 0 ? (
              config.indexed_regions.map((region) => (
                <Badge
                  key={region}
                  variant="secondary"
                  className="text-xs bg-[var(--sg-bg-2)] text-[var(--sg-text-muted)]"
                >
                  {region}
                </Badge>
              ))
            ) : (
              <span className="text-xs text-[var(--sg-text-dim)]">
                No regions indexed
              </span>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

// ============================================================================
// UNMANAGED RESOURCES TABLE
// ============================================================================

interface UnmanagedResourcesTableProps {
  resources: UnmanagedResource[];
  selectedArns: Set<string>;
  onSelectionChange: (selected: Set<string>) => void;
  onGenerateConfig: () => void;
  provider?: string;
}

// Helper to get the resource ID (works for both AWS and GCP)
function getResourceId(resource: UnmanagedResource): string {
  return resource.id || resource.arn || resource.asset_name || "";
}

export function UnmanagedResourcesTable({
  resources,
  selectedArns,
  onSelectionChange,
  onGenerateConfig,
  provider = "aws",
}: UnmanagedResourcesTableProps) {
  const [search, setSearch] = useState("");
  const [serviceFilter, setServiceFilter] = useState<string | null>(null);
  const [regionFilter, setRegionFilter] = useState<string | null>(null);
  const [sortColumn, setSortColumn] = useState<"id" | "service" | "resource_type" | "region">("service");
  const [sortDirection, setSortDirection] = useState<"asc" | "desc">("asc");
  const [currentPage, setCurrentPage] = useState(1);
  const [copiedId, setCopiedId] = useState<string | null>(null);

  const pageSize = 20;
  const isGcp = provider === "gcp";

  // Get unique services and regions for filters
  const services = useMemo(() => {
    const unique = [...new Set(resources.map((r) => r.service))].sort();
    return unique;
  }, [resources]);

  const regions = useMemo(() => {
    const unique = [...new Set(resources.map((r) => r.region).filter(Boolean))].sort();
    return unique as string[];
  }, [resources]);

  // Filter and sort resources
  const filteredResources = useMemo(() => {
    let result = [...resources];

    // Apply search filter
    if (search) {
      const searchLower = search.toLowerCase();
      result = result.filter(
        (r) =>
          getResourceId(r).toLowerCase().includes(searchLower) ||
          r.resource_type.toLowerCase().includes(searchLower) ||
          r.service.toLowerCase().includes(searchLower)
      );
    }

    // Apply service filter
    if (serviceFilter) {
      result = result.filter((r) => r.service === serviceFilter);
    }

    // Apply region filter
    if (regionFilter) {
      result = result.filter((r) => r.region === regionFilter);
    }

    // Apply sorting
    result.sort((a, b) => {
      let aVal: string;
      let bVal: string;
      if (sortColumn === "id") {
        aVal = getResourceId(a);
        bVal = getResourceId(b);
      } else {
        aVal = (a[sortColumn] as string) || "";
        bVal = (b[sortColumn] as string) || "";
      }
      const comparison = aVal.localeCompare(bVal);
      return sortDirection === "asc" ? comparison : -comparison;
    });

    return result;
  }, [resources, search, serviceFilter, regionFilter, sortColumn, sortDirection]);

  // Pagination - clamp page to valid range when filters reduce results
  const totalPages = Math.max(1, Math.ceil(filteredResources.length / pageSize));
  const effectivePage = Math.min(currentPage, totalPages);
  const paginatedResources = filteredResources.slice(
    (effectivePage - 1) * pageSize,
    effectivePage * pageSize
  );

  const handleSort = (column: "id" | "service" | "resource_type" | "region") => {
    if (sortColumn === column) {
      setSortDirection((d) => (d === "asc" ? "desc" : "asc"));
    } else {
      setSortColumn(column);
      setSortDirection("asc");
    }
  };

  const copyId = async (id: string) => {
    try {
      await navigator.clipboard.writeText(id);
      setCopiedId(id);
      setTimeout(() => setCopiedId(null), 2000);
    } catch (error) {
      console.error("Failed to copy resource ID:", error);
    }
  };

  const clearFilters = () => {
    setSearch("");
    setServiceFilter(null);
    setRegionFilter(null);
  };

  const hasActiveFilters = search || serviceFilter || regionFilter;

  // Selection helpers (using id field which works for both AWS ARN and GCP asset_name)
  const allFilteredSelected =
    filteredResources.length > 0 &&
    filteredResources.every((r) => selectedArns.has(getResourceId(r)));

  const someFilteredSelected = filteredResources.some((r) => selectedArns.has(getResourceId(r)));

  const handleSelectAll = () => {
    const newSelected = new Set(selectedArns);
    if (allFilteredSelected) {
      // Deselect all filtered
      filteredResources.forEach((r) => newSelected.delete(getResourceId(r)));
    } else {
      // Select all filtered
      filteredResources.forEach((r) => newSelected.add(getResourceId(r)));
    }
    onSelectionChange(newSelected);
  };

  const handleSelectOne = (resourceId: string) => {
    const newSelected = new Set(selectedArns);
    if (newSelected.has(resourceId)) {
      newSelected.delete(resourceId);
    } else {
      newSelected.add(resourceId);
    }
    onSelectionChange(newSelected);
  };

  // Column header for resource ID
  const idColumnLabel = isGcp ? "Asset Name" : "ARN";

  return (
    <div className="border border-[var(--sg-border)] rounded-lg overflow-hidden bg-[var(--sg-bg-0)]">
      {/* Filters */}
      <div className="p-4 border-b border-[var(--sg-border)] bg-[var(--sg-bg-1)]">
        <div className="flex flex-wrap items-center gap-3">
          {/* Search */}
          <div className="relative flex-1 min-w-[200px] max-w-md">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-[var(--sg-text-dim)]" />
            <input
              type="text"
              placeholder={isGcp ? "Search asset name or type..." : "Search ARN or type..."}
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="w-full pl-9 pr-3 py-2 text-sm bg-[var(--sg-bg-0)] border border-[var(--sg-border)] rounded-md focus:outline-none focus:ring-1 focus:ring-[var(--sg-accent)] focus:border-[var(--sg-accent)] text-[var(--sg-text)] placeholder:text-[var(--sg-text-dim)]"
            />
          </div>

          {/* Service Filter */}
          <select
            value={serviceFilter || ""}
            onChange={(e) => setServiceFilter(e.target.value || null)}
            className="px-3 py-2 text-sm bg-[var(--sg-bg-0)] border border-[var(--sg-border)] rounded-md focus:outline-none focus:ring-1 focus:ring-[var(--sg-accent)] focus:border-[var(--sg-accent)] text-[var(--sg-text)]"
          >
            <option value="">All Services</option>
            {services.map((service) => (
              <option key={service} value={service}>
                {service}
              </option>
            ))}
          </select>

          {/* Region Filter */}
          <select
            value={regionFilter || ""}
            onChange={(e) => setRegionFilter(e.target.value || null)}
            className="px-3 py-2 text-sm bg-[var(--sg-bg-0)] border border-[var(--sg-border)] rounded-md focus:outline-none focus:ring-1 focus:ring-[var(--sg-accent)] focus:border-[var(--sg-accent)] text-[var(--sg-text)]"
          >
            <option value="">All Regions</option>
            {regions.map((region) => (
              <option key={region} value={region}>
                {region}
              </option>
            ))}
          </select>

          {/* Clear Filters */}
          {hasActiveFilters && (
            <Button variant="ghost" size="sm" onClick={clearFilters} className="h-9">
              <X className="h-4 w-4 mr-1" />
              Clear
            </Button>
          )}

          {/* Generate Config Button */}
          {selectedArns.size > 0 && (
            <Button size="sm" onClick={onGenerateConfig} className="h-9">
              <FileCode className="h-4 w-4 mr-1.5" />
              Generate Config ({selectedArns.size})
            </Button>
          )}

          {/* Results count */}
          <span className="text-xs text-[var(--sg-text-dim)] ml-auto">
            {selectedArns.size > 0 && (
              <span className="text-[var(--sg-accent)] mr-2">
                {selectedArns.size} selected
              </span>
            )}
            {filteredResources.length} of {resources.length} resources
          </span>
        </div>
      </div>

      {/* Table */}
      <div className="overflow-x-auto">
        <table className="w-full">
          <thead className="bg-[var(--sg-bg-1)] border-b border-[var(--sg-border)]">
            <tr>
              {/* Select All Checkbox */}
              <th scope="col" className="w-12 px-4 py-3">
                <input
                  type="checkbox"
                  checked={allFilteredSelected}
                  ref={(el) => {
                    if (el) el.indeterminate = someFilteredSelected && !allFilteredSelected;
                  }}
                  onChange={handleSelectAll}
                  className="h-4 w-4 rounded border-[var(--sg-border)] text-[var(--sg-accent)] focus:ring-[var(--sg-accent)] bg-[var(--sg-bg-0)]"
                  aria-label="Select all"
                />
              </th>
              <th
                scope="col"
                className="text-left px-4 py-3 text-xs font-medium text-[var(--sg-text-muted)] uppercase tracking-wide cursor-pointer hover:text-[var(--sg-text)]"
                onClick={() => handleSort("id")}
              >
                <div className="flex items-center gap-1">
                  {idColumnLabel}
                  {sortColumn === "id" && (
                    sortDirection === "asc" ? <ChevronUp className="h-3 w-3" /> : <ChevronDown className="h-3 w-3" />
                  )}
                </div>
              </th>
              <th
                scope="col"
                className="text-left px-4 py-3 text-xs font-medium text-[var(--sg-text-muted)] uppercase tracking-wide cursor-pointer hover:text-[var(--sg-text)]"
                onClick={() => handleSort("service")}
              >
                <div className="flex items-center gap-1">
                  Service
                  {sortColumn === "service" && (
                    sortDirection === "asc" ? <ChevronUp className="h-3 w-3" /> : <ChevronDown className="h-3 w-3" />
                  )}
                </div>
              </th>
              <th
                scope="col"
                className="text-left px-4 py-3 text-xs font-medium text-[var(--sg-text-muted)] uppercase tracking-wide cursor-pointer hover:text-[var(--sg-text)]"
                onClick={() => handleSort("resource_type")}
              >
                <div className="flex items-center gap-1">
                  Resource Type
                  {sortColumn === "resource_type" && (
                    sortDirection === "asc" ? <ChevronUp className="h-3 w-3" /> : <ChevronDown className="h-3 w-3" />
                  )}
                </div>
              </th>
              <th
                scope="col"
                className="text-left px-4 py-3 text-xs font-medium text-[var(--sg-text-muted)] uppercase tracking-wide cursor-pointer hover:text-[var(--sg-text)]"
                onClick={() => handleSort("region")}
              >
                <div className="flex items-center gap-1">
                  Region
                  {sortColumn === "region" && (
                    sortDirection === "asc" ? <ChevronUp className="h-3 w-3" /> : <ChevronDown className="h-3 w-3" />
                  )}
                </div>
              </th>
              <th
                scope="col"
                className="text-left px-4 py-3 text-xs font-medium text-[var(--sg-text-muted)] uppercase tracking-wide"
              >
                <div className="flex items-center gap-1">
                  {isGcp ? "Project ID" : "Account ID"}
                </div>
              </th>
              <th scope="col" className="w-12 px-4 py-3"></th>
            </tr>
          </thead>
          <tbody>
            {paginatedResources.length === 0 ? (
              <tr>
                <td colSpan={7} className="px-4 py-8 text-center text-sm text-[var(--sg-text-muted)]">
                  No resources match your filters
                </td>
              </tr>
            ) : (
              paginatedResources.map((resource, index) => {
                const resourceId = getResourceId(resource);
                return (
                <tr
                  key={`${resourceId}-${index}`}
                  className={`border-b border-[var(--sg-border)] hover:bg-[var(--sg-bg-1)] transition-colors ${
                    selectedArns.has(resourceId) ? "bg-[var(--sg-accent)]/5" : ""
                  }`}
                >
                  {/* Row Checkbox */}
                  <td className="px-4 py-3">
                    <input
                      type="checkbox"
                      checked={selectedArns.has(resourceId)}
                      onChange={() => handleSelectOne(resourceId)}
                      className="h-4 w-4 rounded border-[var(--sg-border)] text-[var(--sg-accent)] focus:ring-[var(--sg-accent)] bg-[var(--sg-bg-0)]"
                      aria-label={`Select ${resourceId}`}
                    />
                  </td>
                  <td className="px-4 py-3">
                    <span
                      className="text-xs font-mono text-[var(--sg-text)] truncate block max-w-[400px]"
                      title={resourceId}
                    >
                      {resourceId}
                    </span>
                  </td>
                  <td className="px-4 py-3">
                    <Badge variant="secondary" className="text-xs">
                      {resource.service}
                    </Badge>
                  </td>
                  <td className="px-4 py-3">
                    <span className="text-xs text-[var(--sg-text-muted)]">
                      {resource.resource_type}
                    </span>
                  </td>
                  <td className="px-4 py-3">
                    <span className="text-xs text-[var(--sg-text-muted)]">
                      {resource.region || "-"}
                    </span>
                  </td>
                  <td className="px-4 py-3">
                    <span className="text-xs font-mono text-[var(--sg-text-muted)]">
                      {resource.owning_account_id || resource.project_id || "-"}
                    </span>
                  </td>
                  <td className="px-4 py-3">
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={() => copyId(resourceId)}
                      className="h-7 w-7 p-0"
                      title={isGcp ? "Copy Asset Name" : "Copy ARN"}
                    >
                      {copiedId === resourceId ? (
                        <CheckCircle2 className="h-3.5 w-3.5 text-[var(--sg-success)]" />
                      ) : (
                        <Copy className="h-3.5 w-3.5 text-[var(--sg-text-dim)]" />
                      )}
                    </Button>
                  </td>
                </tr>
              )})
            )}
          </tbody>
        </table>
      </div>

      {/* Pagination */}
      {totalPages > 1 && (
        <div className="px-4 py-3 border-t border-[var(--sg-border)] bg-[var(--sg-bg-1)] flex items-center justify-between">
          <span className="text-xs text-[var(--sg-text-dim)]">
            Page {effectivePage} of {totalPages}
          </span>
          <div className="flex items-center gap-2">
            <Button
              variant="outline"
              size="sm"
              onClick={() => setCurrentPage((p) => Math.max(1, p - 1))}
              disabled={effectivePage === 1}
            >
              Previous
            </Button>
            <Button
              variant="outline"
              size="sm"
              onClick={() => setCurrentPage((p) => Math.min(totalPages, p + 1))}
              disabled={effectivePage === totalPages}
            >
              Next
            </Button>
          </div>
        </div>
      )}
    </div>
  );
}

// ============================================================================
// LOADING SKELETON
// ============================================================================

export function GapAnalysisSkeleton() {
  return (
    <div className="space-y-6 animate-pulse">
      {/* Summary Cards */}
      <div className="space-y-2">
        <div className="h-5 w-40 rounded bg-[var(--sg-bg-2)]" />
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          {[...Array(4)].map((_, i) => (
            <div key={i} className="h-[120px] rounded-lg bg-[var(--sg-bg-2)]" />
          ))}
        </div>
      </div>

      {/* Charts Row */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="h-[240px] rounded-lg bg-[var(--sg-bg-2)]" />
        <div className="h-[240px] rounded-lg bg-[var(--sg-bg-2)]" />
      </div>

      {/* Table */}
      <div className="space-y-2">
        <div className="h-5 w-48 rounded bg-[var(--sg-bg-2)]" />
        <div className="h-[400px] rounded-lg bg-[var(--sg-bg-2)]" />
      </div>
    </div>
  );
}

// ============================================================================
// NO GAPS EMPTY STATE
// ============================================================================

interface NoGapsEmptyStateProps {
  provider?: string;
}

export function NoGapsEmptyState({ provider = "aws" }: NoGapsEmptyStateProps) {
  const isGcp = provider === "gcp";
  const providerLabel = isGcp ? "GCP" : "AWS";

  return (
    <div className="border border-[var(--sg-border)] rounded-lg bg-[var(--sg-bg-0)] overflow-hidden">
      <div className="px-12 py-16 text-center space-y-4">
        {/* Icon */}
        <div className="flex justify-center">
          <div
            className="w-20 h-20 rounded-full flex items-center justify-center"
            style={{ background: "rgba(34, 197, 94, 0.1)" }}
          >
            <CheckCircle2 className="h-10 w-10 text-[var(--sg-success)]" />
          </div>
        </div>

        {/* Message */}
        <div className="space-y-2">
          <h3 className="text-xl font-semibold text-[var(--sg-success)]">
            Full Coverage Achieved
          </h3>
          <p className="text-sm text-[var(--sg-text-muted)] max-w-md mx-auto">
            All discovered {providerLabel} resources are tracked by Stategraph.
            Your infrastructure is fully managed by Terraform.
          </p>
        </div>
      </div>
    </div>
  );
}
