"use client";

import { useState } from 'react';
import { ChevronRight, ChevronDown } from 'lucide-react';

interface JSONViewerProps {
  data: unknown;
  defaultExpanded?: boolean;
}

/**
 * JSONViewer - Collapsible tree view for JSON data
 */
export function JSONViewer({ data, defaultExpanded = false }: JSONViewerProps) {
  if (data === null || data === undefined) {
    return <span className="text-[var(--sg-text-dim)] italic">null</span>;
  }

  if (typeof data !== 'object') {
    return <PrimitiveValue value={data} />;
  }

  if (Array.isArray(data)) {
    return <ArrayView data={data} defaultExpanded={defaultExpanded} />;
  }

  return <ObjectView data={data as Record<string, unknown>} defaultExpanded={defaultExpanded} />;
}

function PrimitiveValue({ value }: { value: unknown }) {
  const type = typeof value;

  let colorClass = 'text-[var(--sg-text)]';
  let displayValue = String(value);

  if (type === 'string') {
    colorClass = 'text-[var(--sg-success)]';
    displayValue = `"${value}"`;
  } else if (type === 'number') {
    colorClass = 'text-[var(--sg-accent)]';
  } else if (type === 'boolean') {
    colorClass = 'text-[var(--sg-warning)]';
  }

  return (
    <span className={`font-mono text-sm ${colorClass}`}>
      {displayValue}
    </span>
  );
}

function ObjectView({ data, defaultExpanded }: { data: Record<string, unknown>; defaultExpanded: boolean }) {
  const [isExpanded, setIsExpanded] = useState(defaultExpanded);
  const keys = Object.keys(data);

  if (keys.length === 0) {
    return <span className="text-[var(--sg-text-dim)] font-mono text-sm">{'{}'}</span>;
  }

  return (
    <div>
      <button
        onClick={() => setIsExpanded(!isExpanded)}
        className="flex items-center gap-1 hover:text-[var(--sg-text)] text-[var(--sg-text-muted)] transition-colors"
      >
        {isExpanded ? (
          <ChevronDown className="h-3 w-3" />
        ) : (
          <ChevronRight className="h-3 w-3" />
        )}
        <span className="font-mono text-sm">
          {isExpanded ? '{' : `{ ${keys.length} keys }`}
        </span>
      </button>

      {isExpanded && (
        <div className="ml-4 mt-1 space-y-1 border-l border-[var(--sg-border)] pl-3">
          {keys.map((key) => (
            <div key={key} className="flex gap-2">
              <span className="text-[var(--sg-text-muted)] font-mono text-sm flex-shrink-0">
                {key}:
              </span>
              <JSONViewer data={data[key]} defaultExpanded={false} />
            </div>
          ))}
          <span className="text-[var(--sg-text-dim)] font-mono text-sm">{'}'}</span>
        </div>
      )}
    </div>
  );
}

function ArrayView({ data, defaultExpanded }: { data: unknown[]; defaultExpanded: boolean }) {
  const [isExpanded, setIsExpanded] = useState(defaultExpanded);

  if (data.length === 0) {
    return <span className="text-[var(--sg-text-dim)] font-mono text-sm">[]</span>;
  }

  return (
    <div>
      <button
        onClick={() => setIsExpanded(!isExpanded)}
        className="flex items-center gap-1 hover:text-[var(--sg-text)] text-[var(--sg-text-muted)] transition-colors"
      >
        {isExpanded ? (
          <ChevronDown className="h-3 w-3" />
        ) : (
          <ChevronRight className="h-3 w-3" />
        )}
        <span className="font-mono text-sm">
          {isExpanded ? '[' : `[ ${data.length} items ]`}
        </span>
      </button>

      {isExpanded && (
        <div className="ml-4 mt-1 space-y-1 border-l border-[var(--sg-border)] pl-3">
          {data.map((item, index) => (
            <div key={index} className="flex gap-2">
              <span className="text-[var(--sg-text-dim)] font-mono text-sm flex-shrink-0">
                {index}:
              </span>
              <JSONViewer data={item} defaultExpanded={false} />
            </div>
          ))}
          <span className="text-[var(--sg-text-dim)] font-mono text-sm">]</span>
        </div>
      )}
    </div>
  );
}
