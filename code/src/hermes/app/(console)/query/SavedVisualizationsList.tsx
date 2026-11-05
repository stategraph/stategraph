"use client";

import { useState } from 'react';
import { useDeepLinkRouter } from '@/hooks';
import { BarChart3, Edit, Trash2, ExternalLink } from 'lucide-react';
import type { SavedVisualization } from './savedVisualizationRepository';

interface SavedVisualizationsListProps {
  visualizations: SavedVisualization[];
  onLoad: (visualization: SavedVisualization) => void;
  onRename: (id: string, name: string, description?: string) => void;
  onDelete: (id: string) => void;
}

interface RenameState {
  id: string;
  name: string;
  description: string;
}

export function SavedVisualizationsList({
  visualizations,
  onLoad: _onLoad,
  onRename,
  onDelete,
}: SavedVisualizationsListProps) {
  const router = useDeepLinkRouter();
  const [renaming, setRenaming] = useState<RenameState | null>(null);

  const handleStartRename = (viz: SavedVisualization) => {
    setRenaming({
      id: viz.id,
      name: viz.name,
      description: viz.description || '',
    });
  };

  const handleSaveRename = () => {
    if (renaming) {
      onRename(renaming.id, renaming.name, renaming.description || undefined);
      setRenaming(null);
    }
  };

  const handleCancelRename = () => {
    setRenaming(null);
  };

  const formatDate = (isoString: string) => {
    const date = new Date(isoString);
    return date.toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
    });
  };

  const getChartIcon = (_chartType: string) => {
    return BarChart3; // Could customize per chart type
  };

  if (visualizations.length === 0) {
    return (
      <div className="text-center py-8">
        <BarChart3 className="w-8 h-8 mx-auto mb-2 opacity-30" style={{ color: 'var(--sg-text-muted)' }} />
        <div className="text-xs text-[var(--sg-text-dim)]">
          No saved visualizations yet
        </div>
        <div className="text-[10px] text-[var(--sg-text-dim)] mt-1">
          Click &ldquo;Save&rdquo; in the visualization modal to save your first chart
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-2">
      {visualizations.map((viz) => {
        const Icon = getChartIcon(viz.chartType);
        const isRenaming = renaming?.id === viz.id;

        return (
          <div
            key={viz.id}
            className="group relative p-3 rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-0)] hover:bg-[var(--sg-bg-2)] hover:border-[var(--sg-accent)] transition-colors duration-200"
          >
            {isRenaming ? (
              // Rename mode
              <div className="space-y-2">
                <input
                  type="text"
                  value={renaming.name}
                  onChange={(e) => setRenaming({ ...renaming, name: e.target.value })}
                  className="w-full px-2 py-1 text-xs font-medium bg-[var(--sg-bg-1)] border border-[var(--sg-border)] rounded text-[var(--sg-text)] focus:outline-none focus:ring-1 focus:ring-[var(--sg-accent)]"
                  autoFocus
                />
                <textarea
                  value={renaming.description}
                  onChange={(e) => setRenaming({ ...renaming, description: e.target.value })}
                  placeholder="Description (optional)"
                  rows={2}
                  className="w-full px-2 py-1 text-[10px] bg-[var(--sg-bg-1)] border border-[var(--sg-border)] rounded text-[var(--sg-text-muted)] resize-none focus:outline-none focus:ring-1 focus:ring-[var(--sg-accent)]"
                />
                <div className="flex gap-2">
                  <button
                    onClick={handleSaveRename}
                    className="flex-1 px-2 py-1 text-xs bg-[var(--sg-accent-button)] text-white rounded hover:bg-[var(--sg-accent-button-hover)] transition-colors"
                  >
                    Save
                  </button>
                  <button
                    onClick={handleCancelRename}
                    className="flex-1 px-2 py-1 text-xs bg-[var(--sg-bg-1)] border border-[var(--sg-border)] text-[var(--sg-text)] rounded hover:bg-[var(--sg-bg-2)] transition-colors"
                  >
                    Cancel
                  </button>
                </div>
              </div>
            ) : (
              // Normal mode
              <>
                <button
                  {...router.nav(`/visualization?id=${viz.id}`)}
                  className="w-full text-left"
                >
                  <div className="flex items-start gap-2">
                    <Icon className="w-4 h-4 text-[var(--sg-accent)] mt-0.5 flex-shrink-0" />
                    <div className="flex-1 min-w-0">
                      <div className="text-xs font-medium text-[var(--sg-text)] mb-1 flex items-center gap-2">
                        <span className="truncate">{viz.name}</span>
                        <span className="px-1.5 py-0.5 text-[9px] rounded bg-[var(--sg-accent)]/20 text-[var(--sg-accent)] uppercase tracking-wide flex-shrink-0">
                          {viz.chartType}
                        </span>
                      </div>
                      {viz.description && (
                        <div className="text-[10px] text-[var(--sg-text-dim)] mb-2 line-clamp-2">
                          {viz.description}
                        </div>
                      )}
                      <div className="flex items-center gap-2 text-[10px] text-[var(--sg-text-dim)]">
                        <span>{formatDate(viz.createdAt)}</span>
                        <span>•</span>
                        <span className="truncate">by {viz.dimensionField}</span>
                      </div>
                    </div>
                  </div>
                </button>

                {/* Action buttons */}
                <div className="absolute top-2 right-2 flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      router.push(`/visualization?id=${viz.id}`);
                    }}
                    className="p-1 rounded hover:bg-[var(--sg-accent)]/10 transition-colors"
                    title="Open visualization viewer"
                  >
                    <ExternalLink className="w-3 h-3 text-[var(--sg-accent)]" />
                  </button>
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      handleStartRename(viz);
                    }}
                    className="p-1 rounded hover:bg-[var(--sg-accent)]/10 transition-colors"
                    title="Rename this visualization"
                  >
                    <Edit className="w-3 h-3 text-[var(--sg-accent)]" />
                  </button>
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      if (confirm(`Delete "${viz.name}"?`)) {
                        onDelete(viz.id);
                      }
                    }}
                    className="p-1 rounded hover:bg-[var(--sg-error)]/10 transition-colors"
                    title="Delete this visualization"
                  >
                    <Trash2 className="w-3 h-3 text-[var(--sg-error)]" />
                  </button>
                </div>
              </>
            )}
          </div>
        );
      })}
    </div>
  );
}
