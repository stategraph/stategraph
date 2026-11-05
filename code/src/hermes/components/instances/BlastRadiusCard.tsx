"use client";

import { useState, useEffect } from 'react';
import { InstanceBlastRadiusResponse } from '@/lib/api/client';
import { loadBlastRadius } from '@/app/(console)/instances/loader';
import { AlertCircle, Network } from 'lucide-react';

interface BlastRadiusCardProps {
  stateId: string;
  instanceAddress: string;
  onDependeeClick?: (address: string) => void;
}

/**
 * BlastRadiusCard - Display blast radius (downstream dependencies) for an instance
 */
export function BlastRadiusCard({
  stateId,
  instanceAddress,
  onDependeeClick,
}: BlastRadiusCardProps) {
  const [data, setData] = useState<InstanceBlastRadiusResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let mounted = true;

    async function fetchData() {
      setLoading(true);
      setError(null);

      try {
        const result = await loadBlastRadius(stateId, instanceAddress);
        if (mounted) {
          setData(result);
        }
      } catch (e: unknown) {
        if (mounted) {
          setError(e instanceof Error ? e.message : 'Failed to load blast radius');
        }
      } finally {
        if (mounted) {
          setLoading(false);
        }
      }
    }

    fetchData();

    return () => {
      mounted = false;
    };
  }, [stateId, instanceAddress]);

  if (loading) {
    return (
      <div className="p-4">
        <div className="flex items-center gap-2 mb-3">
          <Network className="h-4 w-4 text-[var(--sg-text-muted)]" />
          <h4 className="sg-secondary-header">Blast Radius</h4>
        </div>
        <div className="space-y-2">
          {Array.from({ length: 3 }).map((_, i) => (
            <div key={i} className="h-10 w-full sg-skeleton-shimmer"></div>
          ))}
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="p-4">
        <div className="flex items-center gap-2 mb-3">
          <AlertCircle className="h-4 w-4 text-[var(--sg-error)]" />
          <h4 className="sg-secondary-header text-[var(--sg-error)]">
            Failed to load blast radius
          </h4>
        </div>
        <p className="sg-metadata text-[var(--sg-error)]">{error}</p>
      </div>
    );
  }

  // The response carries the queried block itself as the seed node; this card shows what a change
  // to it would reach, so the seed is dropped.  Only a block that holds infrastructure is listed:
  // a locals entry on the path is part of the graph but it is not a resource anyone applies.
  const dependees = (data?.nodes || []).filter(
    (n) => !n.is_seed && (n.kind === "resource" || n.kind === "data")
  );

  if (dependees.length === 0) {
    return (
      <div className="p-4">
        <div className="flex items-center gap-2 mb-3">
          <Network className="h-4 w-4 text-[var(--sg-text-muted)]" />
          <h4 className="sg-secondary-header">Blast Radius</h4>
        </div>
        <p className="sg-metadata text-[var(--sg-text-dim)]">
          No downstream dependencies found
        </p>
      </div>
    );
  }

  return (
    <div className="p-4">
      <div className="flex items-center gap-2 mb-3">
        <Network className="h-4 w-4 text-[var(--sg-text-muted)]" />
        <h4 className="sg-secondary-header">Blast Radius</h4>
        <span className="sg-metadata text-[var(--sg-text-dim)]">
          ({dependees.length} {dependees.length === 1 ? 'resource' : 'resources'})
        </span>
      </div>

      <div className="space-y-2 max-h-96 overflow-y-auto">
        {dependees.map((dep) => (
          <button
            key={dep.id}
            onClick={() => onDependeeClick?.(dep.address)}
            className="w-full text-left p-3 rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-1)] hover:bg-[var(--sg-bg-2)] hover:border-[var(--sg-accent)] transition-colors duration-200 group"
          >
            <div className="flex items-start justify-between gap-2">
              <div className="flex-1 min-w-0">
                <div className="font-mono text-sm text-[var(--sg-text)] truncate group-hover:text-[var(--sg-accent)]">
                  {dep.address}
                </div>
                <div className="sg-metadata text-[var(--sg-text-dim)] mt-1">
                  {dep.resource_type ?? dep.kind}
                  {dep.instance_count > 1 ? ` · ${dep.instance_count} instances` : ''}
                </div>
              </div>
            </div>
          </button>
        ))}
      </div>
      {/* THE CAP IS NAMED WITH ITS NUMBERS AND THE DEPTH CUT IS NOT, because only the cap has one
          the viewer can act on: total_nodes counts what the depth left, so the difference against
          the returned nodes is exactly what the cap removed. */}
      {data && data.total_nodes > data.nodes.length && (
        <p className="sg-metadata text-[var(--sg-text-dim)] mt-2">
          Showing {data.nodes.length} of {data.total_nodes} affected blocks &mdash; the rest were
          cut to keep the response bounded.
        </p>
      )}
      {data?.truncated && data.total_nodes <= data.nodes.length && (
        <p className="sg-metadata text-[var(--sg-text-dim)] mt-2">
          The walk was cut short, so more may be affected than is listed here.
        </p>
      )}
    </div>
  );
}
