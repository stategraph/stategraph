"use client";

import { Instance } from '@/lib/api/client';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';
import { getInstanceDisplayName } from '@/lib/instances/displayName';
import { InstanceTags } from './InstanceTags';
import { InstanceRowDetails } from './InstanceRowDetails';
import { useState } from 'react';

interface InstanceTableProps {
  instances: Instance[];
  onInstanceClick: (instance: Instance) => void;
  selectedInstance?: Instance | null;
  isLoading?: boolean;
}

/**
 * InstanceTable - Display instances with human-friendly names and expandable details
 */
export function InstanceTable({
  instances,
  onInstanceClick,
  selectedInstance,
  isLoading = false,
}: InstanceTableProps) {
  const [expandedRows, setExpandedRows] = useState<Set<string>>(new Set());

  if (isLoading) {
    return <InstanceTableSkeleton />;
  }

  if (instances.length === 0) {
    return <InstanceTableEmpty />;
  }

  const toggleRowExpansion = (address: string, event: React.MouseEvent) => {
    event.stopPropagation(); // Don't trigger row click
    setExpandedRows(prev => {
      const next = new Set(prev);
      if (next.has(address)) {
        next.delete(address);
      } else {
        next.add(address);
      }
      return next;
    });
  };

  return (
    <div className="border border-[var(--sg-border)] rounded-lg overflow-hidden">
      <Table>
        {/* Header hidden on mobile — rows become labeled cards below lg */}
        <TableHeader className="hidden lg:table-header-group">
          <TableRow className="bg-[var(--sg-bg-1)] border-b border-[var(--sg-border)] hover:bg-[var(--sg-bg-1)]">
            <TableHead className="text-[var(--sg-text-muted)] font-medium w-[50%]">
              Resource
            </TableHead>
            <TableHead className="text-[var(--sg-text-muted)] font-medium w-[20%]">
              Type
            </TableHead>
            <TableHead className="text-[var(--sg-text-muted)] font-medium w-[15%]">
              Provider
            </TableHead>
            <TableHead className="text-[var(--sg-text-muted)] font-medium text-right w-[15%]">
              Dependencies
            </TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {instances.map((instance) => {
            const isSelected = selectedInstance?.address === instance.address;
            const _isExpanded = expandedRows.has(instance.address);
            const displayName = getInstanceDisplayName(instance);
            const isCustomName = displayName !== instance.address;

            return (
              <TableRow
                key={instance.address}
                className={`
                  border-b transition-colors duration-200
                  ${isSelected
                    ? 'bg-[var(--sg-accent-bg)] border-[var(--sg-accent)]'
                    : 'border-[var(--sg-border)]'}
                `}
              >
                <TableCell colSpan={4} className="p-0">
                  {/* Main row content */}
                  <div
                    className={`
                      grid grid-cols-1 gap-2 p-3
                      lg:grid-cols-[50%_20%_15%_15%] lg:items-start lg:gap-0
                      cursor-pointer hover:bg-[var(--sg-bg-2)] transition-colors
                    `}
                    onClick={() => onInstanceClick(instance)}
                  >
                    {/* Resource column: Display name + address + tags */}
                    <div className="flex flex-col gap-1.5 min-w-0">
                      {/* Primary: Display Name */}
                      <div className="flex items-baseline gap-2">
                        <span className="text-[var(--sg-text)] font-medium text-base">
                          {displayName}
                        </span>
                      </div>

                      {/* Secondary: Terraform address (if different from display name) */}
                      {isCustomName && (
                        <div className="font-mono text-xs text-[var(--sg-text-muted)] break-all">
                          {instance.address}
                        </div>
                      )}

                      {/* Tags */}
                      <InstanceTags instance={instance} maxTags={4} showPriorityOnly />

                      {/* Module path (if present) */}
                      {instance.module && (
                        <div className="font-mono text-xs text-[var(--sg-text-dim)]">
                          module: {instance.module}
                        </div>
                      )}
                    </div>

                    {/* Type column */}
                    <div className="flex items-center gap-2 lg:items-start lg:pt-1">
                      <span className="text-xs text-[var(--sg-text-dim)] lg:hidden">Type</span>
                      <Badge variant="outline" className="sg-data-meta">
                        {instance.type}
                      </Badge>
                    </div>

                    {/* Provider column */}
                    <div className="flex items-center gap-2 lg:items-start lg:pt-1">
                      <span className="text-xs text-[var(--sg-text-dim)] lg:hidden">Provider</span>
                      <span className="sg-metadata text-[var(--sg-text-muted)] uppercase">
                        {getProviderDisplay(instance.provider)}
                      </span>
                    </div>

                    {/* Dependencies column */}
                    <div className="flex items-center gap-2 lg:items-start lg:justify-end lg:pt-1">
                      <span className="text-xs text-[var(--sg-text-dim)] lg:hidden">Dependencies</span>
                      <span className="sg-numeric-value text-sm text-[var(--sg-text-muted)]">
                        {instance.dependencies?.length || 0}
                      </span>
                    </div>
                  </div>

                  {/* Expandable details */}
                  <div onClick={(e) => toggleRowExpansion(instance.address, e)}>
                    <InstanceRowDetails instance={instance} />
                  </div>
                </TableCell>
              </TableRow>
            );
          })}
        </TableBody>
      </Table>
    </div>
  );
}

/**
 * Loading skeleton for the table
 */
function InstanceTableSkeleton() {
  return (
    <div className="border border-[var(--sg-border)] rounded-lg overflow-hidden">
      <Table>
        <TableHeader>
          <TableRow className="bg-[var(--sg-bg-1)] border-b border-[var(--sg-border)] hover:bg-[var(--sg-bg-1)]">
            <TableHead className="text-[var(--sg-text-muted)] font-medium w-[40%]">
              Address
            </TableHead>
            <TableHead className="text-[var(--sg-text-muted)] font-medium w-[20%]">
              Type
            </TableHead>
            <TableHead className="text-[var(--sg-text-muted)] font-medium w-[15%]">
              Provider
            </TableHead>
            <TableHead className="text-[var(--sg-text-muted)] font-medium w-[15%]">
              Module
            </TableHead>
            <TableHead className="text-[var(--sg-text-muted)] font-medium text-right w-[10%]">
              Dependencies
            </TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {Array.from({ length: 10 }).map((_, i) => (
            <TableRow key={i} className="border-b border-[var(--sg-border)]">
              <TableCell>
                <div className="h-4 w-64 sg-skeleton-shimmer"></div>
              </TableCell>
              <TableCell>
                <div className="h-4 w-32 sg-skeleton-shimmer"></div>
              </TableCell>
              <TableCell>
                <div className="h-4 w-16 sg-skeleton-shimmer"></div>
              </TableCell>
              <TableCell>
                <div className="h-4 w-24 sg-skeleton-shimmer"></div>
              </TableCell>
              <TableCell className="text-right">
                <div className="h-4 w-8 ml-auto sg-skeleton-shimmer"></div>
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  );
}

/**
 * Empty state for the table
 */
function InstanceTableEmpty() {
  return (
    <div className="border border-[var(--sg-border)] rounded-lg overflow-hidden bg-[var(--sg-bg-1)] p-12">
      <div className="text-center space-y-3">
        <div className="sg-secondary-header text-[var(--sg-text-muted)]">
          No resources found
        </div>
        <div className="sg-metadata space-y-1">
          <p>Try adjusting your filters or query.</p>
          <p className="mt-2">Example queries:</p>
          <ul className="inline-block text-left space-y-1 font-mono text-xs">
            <li>provider:aws</li>
            <li>type:aws_s3_bucket</li>
            <li>module:networking</li>
          </ul>
        </div>
      </div>
    </div>
  );
}

/**
 * Format provider name for display
 */
function getProviderDisplay(provider: string | undefined | null): string {
  if (!provider) {
    return 'Unknown';
  }

  const providerMap: Record<string, string> = {
    'aws': 'AWS',
    'google': 'GCP',
    'azurerm': 'Azure',
    'kubernetes': 'K8s',
    'datadog': 'Datadog',
    'github': 'GitHub',
    'gitlab': 'GitLab',
    'cloudflare': 'Cloudflare',
  };

  return providerMap[provider.toLowerCase()] || provider.toUpperCase();
}
