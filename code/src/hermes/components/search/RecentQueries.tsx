"use client";

import React from "react";
import { Clock } from "lucide-react";
import { Button } from "@/components/ui/button";

interface SavedQuery {
  q: string;
  timestamp: number;
}

interface RecentQueriesProps {
  queries: SavedQuery[];
  onSelectQuery: (q: string) => void;
  onClear: () => void;
}

export function RecentQueries({
  queries,
  onSelectQuery,
  onClear,
}: RecentQueriesProps) {
  if (queries.length === 0) {
    return null;
  }

  return (
    <div className="space-y-3">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <Clock className="h-4 w-4 text-[var(--sg-text-muted)]" />
          <h3 className="sg-secondary-header">Recent Queries</h3>
        </div>
        <Button
          variant="ghost"
          size="sm"
          onClick={onClear}
          className="text-xs text-[var(--sg-text-dim)] hover:text-[var(--sg-text)]"
        >
          Clear all
        </Button>
      </div>

      <div className="space-y-1">
        {queries.map((query, index) => (
          <button
            key={`${query.q}-${index}`}
            onClick={() => onSelectQuery(query.q)}
            className="w-full flex items-center justify-between gap-3 p-2 bg-[var(--sg-bg-2)] border border-[var(--sg-border)] rounded hover:border-[var(--sg-accent)] hover:bg-[var(--sg-bg-1)] transition-colors text-left group"
          >
            <code className="text-xs font-mono text-[var(--sg-text-muted)] group-hover:text-[var(--sg-accent)] truncate flex-1">
              {query.q}
            </code>
            <span className="sg-metadata text-[var(--sg-text-dim)]">
              {formatTimestamp(query.timestamp)}
            </span>
          </button>
        ))}
      </div>
    </div>
  );
}

function formatTimestamp(timestamp: number): string {
  const now = Date.now();
  const diff = now - timestamp;
  const seconds = Math.floor(diff / 1000);
  const minutes = Math.floor(seconds / 60);
  const hours = Math.floor(minutes / 60);
  const days = Math.floor(hours / 24);

  if (days > 0) return `${days}d ago`;
  if (hours > 0) return `${hours}h ago`;
  if (minutes > 0) return `${minutes}m ago`;
  return "Just now";
}
