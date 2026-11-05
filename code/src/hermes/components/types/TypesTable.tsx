"use client";

import { useDeepLinkRouter } from '@/hooks';
import { ResourceTypeData } from '@/app/(console)/types/loader';
import { ProviderBadge } from './ProviderBadge';
import { EmptyState } from './EmptyState';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import { ArrowRight } from 'lucide-react';

interface TypesTableProps {
  types: ResourceTypeData[];
  isLoading?: boolean;
  searchQuery?: string;
}

/**
 * TypesTable - Dense table layout for resource types
 */
export function TypesTable({ types, isLoading = false, searchQuery }: TypesTableProps) {
  const router = useDeepLinkRouter();

  if (isLoading) {
    return <TypesTableSkeleton />;
  }

  if (types.length === 0) {
    return <EmptyState searchQuery={searchQuery} />;
  }

  const handleRowClick = (type: string) => {
    router.push(`/instances?type=${encodeURIComponent(type)}`);
  };

  return (
    <>
    {/* Desktop / tablet table (lg+) */}
    <div className="hidden lg:block border border-[var(--sg-border)] rounded-lg overflow-hidden">
      <Table>
        <TableHeader>
          <TableRow className="bg-[var(--sg-bg-1)] border-b border-[var(--sg-border)] hover:bg-[var(--sg-bg-1)]">
            <TableHead className="text-[var(--sg-text-muted)] font-medium w-[50%]">
              Resource Type
            </TableHead>
            <TableHead className="text-[var(--sg-text-muted)] font-medium w-[20%]">
              Provider
            </TableHead>
            <TableHead className="text-[var(--sg-text-muted)] font-medium text-right w-[20%]">
              Instances
            </TableHead>
            <TableHead className="text-[var(--sg-text-muted)] font-medium text-right w-[10%]">
              Actions
            </TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {types.map((type) => (
            <TableRow
              key={type.type}
              className="border-b border-[var(--sg-border)] hover:bg-[var(--sg-bg-2)] transition-colors duration-150 cursor-pointer"
              onClick={() => handleRowClick(type.type)}
            >
              <TableCell>
                <span className="font-mono sg-secondary-header text-[var(--sg-text)]">
                  {type.type}
                </span>
              </TableCell>
              <TableCell>
                <ProviderBadge provider={type.provider} variant="outline" />
              </TableCell>
              <TableCell className="text-right">
                <span className="sg-numeric-value text-sm text-[var(--sg-text-muted)]">
                  {type.instances.toLocaleString()}
                </span>
              </TableCell>
              <TableCell className="text-right">
                <div className="inline-flex items-center gap-1 sg-metadata text-[var(--sg-text-dim)] hover:text-[var(--sg-accent)] transition-colors">
                  <span>View</span>
                  <ArrowRight className="h-3 w-3" />
                </div>
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>

    {/* Mobile / small-screen card list (below lg) */}
    <div className="lg:hidden space-y-3">
      {types.map((type) => (
        <button
          key={type.type}
          onClick={() => handleRowClick(type.type)}
          className="w-full text-left rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-1)] p-3 hover:bg-[var(--sg-bg-2)] transition-colors"
        >
          <div className="flex items-start justify-between gap-3">
            <span className="font-mono sg-secondary-header text-[var(--sg-text)] break-all min-w-0">
              {type.type}
            </span>
            <span className="flex-shrink-0">
              <ProviderBadge provider={type.provider} variant="outline" />
            </span>
          </div>
          <div className="mt-2 flex items-center justify-between gap-3">
            <div className="sg-metadata text-[var(--sg-text-dim)]">
              <span className="sg-numeric-value text-sm text-[var(--sg-text-muted)]">
                {type.instances.toLocaleString()}
              </span>{' '}
              {type.instances === 1 ? 'instance' : 'instances'}
            </div>
            <div className="inline-flex items-center gap-1 sg-metadata text-[var(--sg-text-dim)]">
              <span>View</span>
              <ArrowRight className="h-3 w-3" />
            </div>
          </div>
        </button>
      ))}
    </div>
    </>
  );
}

/**
 * TypesTable Skeleton for loading states
 */
function TypesTableSkeleton() {
  return (
    <>
    {/* Mobile skeleton (below lg) */}
    <div className="lg:hidden space-y-3">
      {Array.from({ length: 8 }).map((_, i) => (
        <div key={i} className="rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-1)] p-3 space-y-2">
          <div className="h-4 w-2/3 sg-skeleton-shimmer"></div>
          <div className="h-3 w-1/3 sg-skeleton-shimmer"></div>
        </div>
      ))}
    </div>

    {/* Desktop / tablet skeleton (lg+) */}
    <div className="hidden lg:block border border-[var(--sg-border)] rounded-lg overflow-hidden">
      <Table>
        <TableHeader>
          <TableRow className="bg-[var(--sg-bg-1)] border-b border-[var(--sg-border)] hover:bg-[var(--sg-bg-1)]">
            <TableHead className="text-[var(--sg-text-muted)] font-medium w-[50%]">
              Resource Type
            </TableHead>
            <TableHead className="text-[var(--sg-text-muted)] font-medium w-[20%]">
              Provider
            </TableHead>
            <TableHead className="text-[var(--sg-text-muted)] font-medium text-right w-[20%]">
              Instances
            </TableHead>
            <TableHead className="text-[var(--sg-text-muted)] font-medium text-right w-[10%]">
              Actions
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
                <div className="h-4 w-16 sg-skeleton-shimmer"></div>
              </TableCell>
              <TableCell className="text-right">
                <div className="h-4 w-12 ml-auto sg-skeleton-shimmer"></div>
              </TableCell>
              <TableCell className="text-right">
                <div className="h-4 w-12 ml-auto sg-skeleton-shimmer"></div>
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
    </>
  );
}
