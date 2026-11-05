"use client";

import { useDeepLinkRouter } from '@/hooks';
import { ResourceTypeData } from '@/app/(console)/types/loader';
import { ProviderBadge } from './ProviderBadge';
import { ArrowRight } from 'lucide-react';

interface TypeCardProps {
  resourceType: ResourceTypeData;
}

/**
 * TypeCard - Card displaying a single resource type with instance count
 */
export function TypeCard({ resourceType }: TypeCardProps) {
  const router = useDeepLinkRouter();

  const handleClick = () => {
    router.push(`/instances?type=${encodeURIComponent(resourceType.type)}`);
  };

  return (
    <button
      onClick={handleClick}
      className="w-full text-left p-4 rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-1)] hover:bg-[var(--sg-bg-2)] hover:border-[var(--sg-accent)] transition-colors duration-150 group"
    >
      <div className="flex items-start justify-between gap-3 mb-3">
        <div className="flex-1 min-w-0">
          <div className="font-mono text-sm text-[var(--sg-text)] truncate group-hover:text-[var(--sg-accent)] transition-colors">
            {resourceType.type}
          </div>
        </div>
        <ProviderBadge provider={resourceType.provider} />
      </div>

      <div className="flex items-center justify-between">
        <div className="sg-numeric-value text-2xl text-[var(--sg-text)]">
          {resourceType.instances.toLocaleString()}
        </div>
        <div className="flex items-center gap-1 sg-metadata text-[var(--sg-text-dim)] group-hover:text-[var(--sg-accent)] transition-colors">
          <span>View</span>
          <ArrowRight className="h-3 w-3" />
        </div>
      </div>

      <div className="sg-metadata text-[var(--sg-text-dim)] mt-1">
        {resourceType.instances === 1 ? 'instance' : 'instances'}
      </div>
    </button>
  );
}

/**
 * TypeCard Skeleton for loading states
 */
export function TypeCardSkeleton() {
  return (
    <div className="w-full p-4 rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-1)]">
      <div className="flex items-start justify-between gap-3 mb-3">
        <div className="h-4 w-48 sg-skeleton-shimmer"></div>
        <div className="h-4 w-12 sg-skeleton-shimmer"></div>
      </div>
      <div className="flex items-center justify-between">
        <div className="h-8 w-16 sg-skeleton-shimmer"></div>
        <div className="h-4 w-12 sg-skeleton-shimmer"></div>
      </div>
      <div className="h-3 w-20 sg-skeleton-shimmer mt-1"></div>
    </div>
  );
}
