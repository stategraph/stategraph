/**
 * Graph Refusal Component
 *
 * Displayed when a graph cannot be rendered due to excessive complexity.
 *
 * CRITICAL: This is NOT an error state.
 * This is intentional product design to maintain legibility.
 * There is no override, toggle, or escape hatch.
 *
 * Tone: Confident, intentional, educational (not apologetic)
 */

import { AlertTriangle } from 'lucide-react';
import type { RefusalReason } from '@/lib/graph';

interface GraphRefusalProps {
  refusal: RefusalReason;
}

/**
 * Displays a refusal state when a graph exceeds hard limits.
 *
 * This replaces the graph visualization entirely - not an error banner.
 * The decision to refuse rendering is intentional and non-negotiable.
 */
export function GraphRefusal({ refusal }: GraphRefusalProps) {
  return (
    <div className="flex items-center justify-center w-full h-full min-h-[500px] bg-[var(--sg-bg-0)] rounded-lg border border-[var(--sg-border)]">
      <div className="max-w-lg text-center px-8 py-12">
        {/* Icon */}
        <div className="flex justify-center mb-6">
          <div className="w-16 h-16 rounded-full bg-[var(--sg-bg-2)] flex items-center justify-center">
            <AlertTriangle className="w-8 h-8 text-[var(--sg-warning)]" />
          </div>
        </div>

        {/* Title */}
        <h3 className="text-lg font-semibold text-[var(--sg-text)] mb-3">
          Too Complex to Visualize
        </h3>

        {/* Primary message */}
        <p className="text-sm text-[var(--sg-text-muted)] leading-relaxed mb-6">
          This resource has <strong className="text-[var(--sg-text)]">{refusal.actualCount}</strong> {refusal.type === 'direct_relationships' ? 'direct relationships' : 'total nodes'}, exceeding the display limit of <strong className="text-[var(--sg-text)]">{refusal.limit}</strong>.
        </p>

        {/* Breakdown (if available) */}
        {refusal.details && (
          <div className="mb-6 p-4 bg-[var(--sg-bg-1)] border border-[var(--sg-border)] rounded-lg text-left">
            <div className="text-xs font-medium text-[var(--sg-text-muted)] uppercase tracking-wide mb-3">
              Relationship Breakdown
            </div>
            <div className="space-y-2 text-sm">
              {refusal.details.directDependents !== undefined && (
                <div className="flex justify-between">
                  <span className="text-[var(--sg-text-muted)]">Blocks directly referencing this:</span>
                  <span className="font-mono font-semibold text-[var(--sg-text)]">
                    {refusal.details.directDependents}
                  </span>
                </div>
              )}
              {refusal.details.totalNodes !== undefined && (
                <div className="flex justify-between">
                  <span className="text-[var(--sg-text-muted)]">Blocks reached in total:</span>
                  <span className="font-mono font-semibold text-[var(--sg-text)]">
                    {refusal.details.totalNodes}
                    {refusal.serverTruncated ? '+' : ''}
                  </span>
                </div>
              )}
              {refusal.serverTruncated && (
                <div className="text-xs text-[var(--sg-text-dim)] pt-1">
                  The dependency walk was also cut short, so these counts are a lower bound.
                </div>
              )}
              <div className="pt-2 border-t border-[var(--sg-border)]">
                <div className="flex justify-between">
                  <span className="text-[var(--sg-text)]">Total direct relationships:</span>
                  <span className="font-mono font-bold text-[var(--sg-text)]">
                    {refusal.actualCount}
                  </span>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* Explanation - confident and intentional */}
        <div className="text-xs p-4 bg-[var(--sg-bg-2)]/50 border border-[var(--sg-border)] rounded text-left space-y-3">
          <div>
            <div className="font-semibold text-[var(--sg-text)] mb-1.5">
              Why This Limit Exists
            </div>
            <p className="text-[var(--sg-text-dim)] leading-relaxed">
              Graph Explorer is intentionally scoped to focused dependency exploration.
              Graphs with too many connections become cluttered and lose their
              explanatory value. This limit ensures the visualization remains useful.
            </p>
          </div>

          <div className="pt-3 border-t border-[var(--sg-border)]">
            <div className="font-semibold text-[var(--sg-text)] mb-1.5">
              What to Do Instead
            </div>
            <p className="text-[var(--sg-text-dim)] leading-relaxed">
              Use the <strong className="text-[var(--sg-text)]">Blast Radius</strong> page
              to view all dependencies as a searchable list, or select a more specific
              resource with fewer direct relationships to visualize.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
