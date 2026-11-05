"use client";

import { Instance } from '@/lib/api/client';
import { ChevronDown, ChevronRight } from 'lucide-react';
import { useState } from 'react';
import { JSONViewer } from './JSONViewer';

interface InstanceRowDetailsProps {
  instance: Instance;
}

/**
 * High-signal attributes to display first (allowlist).
 * These are commonly useful fields across providers.
 */
const HIGH_SIGNAL_ATTRIBUTES = [
  'name',
  'arn',
  'id',
  'environment',
  'env',
  'region',
  'availability_zone',
  'vpc_id',
  'subnet_id',
  'security_groups',
  'instance_type',
  'instance_class',
  'engine',
  'engine_version',
  'status',
  'state',
  'family',
  'bucket',
  'db_instance_identifier',
  'cluster_identifier',
  'function_name',
  'role_arn',
];

/**
 * Extract high-signal attributes from instance attributes.
 * Returns key-value pairs for the most useful fields.
 */
function getHighSignalAttributes(instance: Instance): Array<{ key: string; value: unknown }> {
  if (!instance.attributes) {
    return [];
  }

  const result: Array<{ key: string; value: unknown }> = [];

  // Check for each high-signal field
  for (const key of HIGH_SIGNAL_ATTRIBUTES) {
    const value = instance.attributes[key];
    if (value !== undefined && value !== null) {
      result.push({ key, value });
    }
  }

  return result;
}

/**
 * Format a value for display (handle strings, numbers, booleans, simple arrays).
 */
function formatValue(value: unknown): string {
  if (value === null || value === undefined) {
    return '—';
  }

  if (typeof value === 'boolean') {
    return value ? 'true' : 'false';
  }

  if (typeof value === 'string' || typeof value === 'number') {
    return String(value);
  }

  if (Array.isArray(value)) {
    // Simple arrays of strings/numbers
    if (value.length === 0) return '[]';
    if (value.every(v => typeof v === 'string' || typeof v === 'number')) {
      return value.join(', ');
    }
  }

  // Complex types: show as JSON
  return JSON.stringify(value);
}

/**
 * Expandable row details showing instance attributes.
 * Shows high-signal fields first, then raw JSON for remaining attributes.
 */
export function InstanceRowDetails({ instance }: InstanceRowDetailsProps) {
  const [isExpanded, setIsExpanded] = useState(false);

  const highSignalAttrs = getHighSignalAttributes(instance);

  // Don't show expand toggle if there are no attributes
  if (!instance.attributes || Object.keys(instance.attributes).length === 0) {
    return null;
  }

  return (
    <div className="border-t border-[var(--sg-border)]">
      <button
        onClick={() => setIsExpanded(!isExpanded)}
        className="w-full px-4 py-2 flex items-center gap-2 hover:bg-[var(--sg-bg-1)] transition-colors text-left"
      >
        {isExpanded ? (
          <ChevronDown className="h-4 w-4 text-[var(--sg-text-muted)]" />
        ) : (
          <ChevronRight className="h-4 w-4 text-[var(--sg-text-muted)]" />
        )}
        <span className="text-xs text-[var(--sg-text-muted)] uppercase tracking-wide">
          {isExpanded ? 'Hide' : 'Show'} Attributes
        </span>
      </button>

      {isExpanded && (
        <div className="px-4 pb-4 space-y-4">
          {/* High-signal attributes */}
          {highSignalAttrs.length > 0 && (
            <div className="space-y-2">
              <div className="text-xs font-medium text-[var(--sg-text-muted)] uppercase tracking-wide">
                Key Attributes
              </div>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-2">
                {highSignalAttrs.map(({ key, value }) => (
                  <div
                    key={key}
                    className="flex items-baseline gap-2 text-xs"
                  >
                    <span className="font-medium text-[var(--sg-text-dim)] min-w-[140px]">
                      {key}:
                    </span>
                    <span className="font-mono text-[var(--sg-text)] break-all">
                      {formatValue(value)}
                    </span>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Full attributes JSON */}
          <div className="space-y-2">
            <div className="text-xs font-medium text-[var(--sg-text-muted)] uppercase tracking-wide">
              All Attributes
            </div>
            <div className="bg-[var(--sg-bg-0)] border border-[var(--sg-border)] rounded p-3 max-h-[300px] overflow-y-auto">
              <JSONViewer data={instance.attributes} />
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
