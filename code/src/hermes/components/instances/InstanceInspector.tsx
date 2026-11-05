"use client";

import React, { useEffect, useState } from 'react';
import { Instance, type InstanceCost } from '@/lib/api/client';
import { X } from 'lucide-react';
import { JSONViewer } from './JSONViewer';
import { BlastRadiusCard } from './BlastRadiusCard';
import { Badge } from '@/components/ui/badge';
import { useCostAvailability, useStateCosts } from '@/hooks';
import { formatCurrency, parseCost } from '@/lib/cost/format';

interface InstanceInspectorProps {
  instance: Instance;
  stateId: string;
  onClose: () => void;
  onDependencyClick?: (address: string) => void;
}

/**
 * InstanceInspector - Right-side panel showing instance details
 */
export function InstanceInspector({
  instance,
  stateId,
  onClose,
  onDependencyClick,
}: InstanceInspectorProps) {
  // Close on Escape key
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        onClose();
      }
    };

    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [onClose]);

  return (
    <div className="w-[480px] h-full bg-[var(--sg-bg-2)] border-l border-[var(--sg-border)] flex flex-col sg-fade-in">
      {/* Header */}
      <div className="flex-shrink-0 flex items-start justify-between p-4 border-b border-[var(--sg-border)] bg-[var(--sg-bg-1)]">
        <div className="flex-1 min-w-0 mr-4">
          <h3 className="sg-secondary-header text-[var(--sg-text)] mb-2 break-words">
            {instance.address}
          </h3>
          <div className="flex flex-wrap items-center gap-2">
            <Badge variant="default">{instance.type}</Badge>
            <Badge variant="secondary">{instance.provider.toUpperCase()}</Badge>
            {instance.module && (
              <Badge variant="outline" className="font-mono">
                {instance.module}
              </Badge>
            )}
          </div>
        </div>
        <button
          onClick={onClose}
          className="flex-shrink-0 text-[var(--sg-text-muted)] hover:text-[var(--sg-text)] transition-colors"
        >
          <X className="h-5 w-5" />
        </button>
      </div>

      {/* Content */}
      <div className="flex-1 overflow-y-auto">
        {/* Metadata Section */}
        <InspectorSection title="Metadata">
          <InfoRow label="Address" value={instance.address} mono />
          <InfoRow label="Type" value={instance.type} />
          <InfoRow label="Provider" value={instance.provider} />
          {instance.module && <InfoRow label="Module" value={instance.module} mono />}
        </InspectorSection>

        {/* Cost Section — only renders when the server can price */}
        <CostSection stateId={stateId} address={instance.address} />

        {/* Attributes Section */}
        {instance.attributes && (
          <>
            <InspectorSection title="Attributes" collapsible defaultCollapsed>
              <div className="bg-[var(--sg-bg-0)] p-3 rounded border border-[var(--sg-border)] overflow-x-auto">
                <JSONViewer data={instance.attributes} defaultExpanded={false} />
              </div>
            </InspectorSection>
          </>
        )}

        {/* Blast Radius Section */}
        <InspectorSection title="Blast Radius" collapsible>
          <div className="bg-[var(--sg-bg-0)] rounded border border-[var(--sg-border)]">
            <BlastRadiusCard
              stateId={stateId}
              instanceAddress={instance.address}
              onDependeeClick={onDependencyClick}
            />
          </div>
        </InspectorSection>
      </div>
    </div>
  );
}

// ============================================================================
// HELPER COMPONENTS
// ============================================================================

interface InspectorSectionProps {
  title: string;
  children: React.ReactNode;
  collapsible?: boolean;
  defaultCollapsed?: boolean;
}

const InspectorSection = ({
  title,
  children,
  collapsible = false,
  defaultCollapsed = false,
}: InspectorSectionProps) => {
  const [isCollapsed, setIsCollapsed] = useState(defaultCollapsed);

  if (collapsible) {
    return (
      <div className="border-b border-[var(--sg-border)]">
        <button
          onClick={() => setIsCollapsed(!isCollapsed)}
          className="w-full flex items-center justify-between p-4 hover:bg-[var(--sg-bg-1)] transition-colors"
        >
          <h4 className="sg-secondary-header">{title}</h4>
          <span className="text-[var(--sg-text-dim)]">
            {isCollapsed ? '+' : '−'}
          </span>
        </button>
        {!isCollapsed && <div className="px-4 pb-4">{children}</div>}
      </div>
    );
  }

  return (
    <div className="border-b border-[var(--sg-border)] p-4">
      <h4 className="sg-secondary-header mb-3">{title}</h4>
      {children}
    </div>
  );
};

interface InfoRowProps {
  label: string;
  value: string;
  mono?: boolean;
}

function InfoRow({ label, value, mono = false }: InfoRowProps) {
  return (
    <div className="flex items-start justify-between gap-4 py-2">
      <span className="sg-metadata text-[var(--sg-text-dim)] flex-shrink-0">
        {label}
      </span>
      <span
        className={`sg-metadata text-[var(--sg-text)] text-right break-all ${
          mono ? 'font-mono' : ''
        }`}
      >
        {value}
      </span>
    </div>
  );
}

/**
 * Cost for this resource, pulled from the state's latest cost snapshot and
 * matched by Terraform address. Renders nothing when the server can't price,
 * and degrades to "not priced" when the state has no snapshot or the resource
 * isn't in it.
 */
function CostSection({ stateId, address }: { stateId: string; address: string }) {
  const { capability } = useCostAvailability();
  const costSupported = capability?.enabled === true;
  const { costs: stateCosts, isLoading: loading, error } = useStateCosts(
    costSupported ? stateId : null
  );
  const currency = stateCosts?.currency || 'USD';
  const cost = stateCosts?.instance_costs.find((ic) => ic.address === address) ?? null;
  // Match the previous "loaded" flag: it flipped true after the first
  // settled fetch (success or 404). With useStateCosts we know we've
  // settled when we're not loading and either have data or an error.
  const loaded = !loading && (stateCosts !== null || error !== null);

  if (!costSupported) return null;

  const monthly = parseCost(cost?.monthly_cost);
  const hourly = parseCost(cost?.hourly_cost);

  return (
    <InspectorSection title="Cost" collapsible>
      {loading && <div className="sg-metadata text-[var(--sg-text-dim)]">Loading…</div>}
      {!loading && loaded && !cost && (
        <div className="sg-metadata text-[var(--sg-text-dim)]">
          Not priced in the latest snapshot.
        </div>
      )}
      {cost && (
        <>
          <InfoRow
            label="Monthly"
            value={monthly !== null ? formatCurrency(monthly, currency) : '—'}
            mono
          />
          <InfoRow
            label="Hourly"
            value={hourly !== null ? formatCurrency(hourly, currency) : '—'}
            mono
          />
          {cost.region && <InfoRow label="Region" value={cost.region} />}
          {!cost.supported && <InfoRow label="Status" value="Unsupported type" />}
          {cost.supported && cost.no_price && (
            <InfoRow label="Status" value="No price (usage-based)" />
          )}
          {cost.components && cost.components.length > 0 && (
            <div className="mt-3 flex flex-col gap-1">
              <div className="sg-metadata text-[var(--sg-text-dim)] mb-1">Components</div>
              {cost.components.map((c, i) => {
                const m = parseCost(c.monthly_cost);
                return (
                  <div key={`${c.name}-${i}`} className="flex justify-between gap-2 text-xs">
                    <span className="text-[var(--sg-text-dim)] truncate">{c.name}</span>
                    <span className="font-mono text-[var(--sg-text)] flex-shrink-0">
                      {m !== null ? `${formatCurrency(m, currency)}/mo` : 'usage-based'}
                    </span>
                  </div>
                );
              })}
            </div>
          )}
        </>
      )}
    </InspectorSection>
  );
}
