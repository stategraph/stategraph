"use client";

import { useState } from 'react';
import { X, BarChart3 } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { useSavedVisualizations } from './useSavedVisualizations';

interface AddVisualizationDialogProps {
  isOpen: boolean;
  onClose: () => void;
  onAdd: (visualizationIds: string[]) => void;
  excludeIds?: string[]; // Already added visualizations
}

export function AddVisualizationDialog({
  isOpen,
  onClose,
  onAdd,
  excludeIds = [],
}: AddVisualizationDialogProps) {
  const { visualizations } = useSavedVisualizations();
  const [selectedIds, setSelectedIds] = useState<string[]>([]);

  if (!isOpen) return null;

  const availableVisualizations = visualizations.filter(
    (viz) => !excludeIds.includes(viz.id)
  );

  const toggleSelection = (id: string) => {
    setSelectedIds((prev) =>
      prev.includes(id) ? prev.filter((vizId) => vizId !== id) : [...prev, id]
    );
  };

  const handleAdd = () => {
    if (selectedIds.length > 0) {
      onAdd(selectedIds);
      setSelectedIds([]);
      onClose();
    }
  };

  const handleCancel = () => {
    setSelectedIds([]);
    onClose();
  };

  const formatDate = (isoString: string) => {
    const date = new Date(isoString);
    return date.toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
    });
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
      <div className="bg-[var(--sg-bg-0)] border border-[var(--sg-border)] rounded-lg shadow-2xl max-w-2xl w-full max-h-[80vh] flex flex-col">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-[var(--sg-border)]">
          <div>
            <h2 className="text-lg font-semibold text-[var(--sg-text)]">Add Visualizations</h2>
            <p className="text-sm text-[var(--sg-text-muted)] mt-1">
              Select one or more visualizations to add to this dashboard
            </p>
          </div>
          <button
            onClick={handleCancel}
            className="text-[var(--sg-text-muted)] hover:text-[var(--sg-text)] transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Content */}
        <div className="flex-1 overflow-y-auto px-6 py-4">
          {availableVisualizations.length === 0 ? (
            <div className="text-center py-12">
              <BarChart3 className="w-12 h-12 mx-auto mb-3 text-[var(--sg-text-muted)] opacity-50" />
              <p className="text-sm text-[var(--sg-text-muted)]">
                {visualizations.length === 0
                  ? 'No saved visualizations available. Create some visualizations first in the Query page.'
                  : 'All available visualizations have already been added to this dashboard.'}
              </p>
            </div>
          ) : (
            <div className="space-y-2">
              {availableVisualizations.map((viz) => {
                const isSelected = selectedIds.includes(viz.id);
                return (
                  <button
                    key={viz.id}
                    onClick={() => toggleSelection(viz.id)}
                    className={`w-full text-left p-4 rounded-lg border-2 transition-colors ${
                      isSelected
                        ? 'border-[var(--sg-accent)] bg-[var(--sg-accent)]/5'
                        : 'border-[var(--sg-border)] bg-[var(--sg-bg-1)] hover:border-[var(--sg-accent)]/50'
                    }`}
                  >
                    <div className="flex items-start gap-3">
                      {/* Checkbox */}
                      <div
                        className={`flex-shrink-0 w-5 h-5 rounded border-2 flex items-center justify-center transition-colors ${
                          isSelected
                            ? 'border-[var(--sg-accent)] bg-[var(--sg-accent)]'
                            : 'border-[var(--sg-border)]'
                        }`}
                      >
                        {isSelected && (
                          <svg
                            className="w-3 h-3 text-white"
                            fill="none"
                            viewBox="0 0 24 24"
                            stroke="currentColor"
                          >
                            <path
                              strokeLinecap="round"
                              strokeLinejoin="round"
                              strokeWidth={3}
                              d="M5 13l4 4L19 7"
                            />
                          </svg>
                        )}
                      </div>

                      {/* Visualization Info */}
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-2 mb-1">
                          <span className="text-sm font-medium text-[var(--sg-text)]">
                            {viz.name}
                          </span>
                          <span className="px-1.5 py-0.5 text-[9px] rounded bg-[var(--sg-accent)]/20 text-[var(--sg-accent)] uppercase tracking-wide">
                            {viz.chartType}
                          </span>
                        </div>
                        {viz.description && (
                          <p className="text-xs text-[var(--sg-text-muted)] mb-2 line-clamp-2">
                            {viz.description}
                          </p>
                        )}
                        <div className="flex items-center gap-3 text-[10px] text-[var(--sg-text-dim)]">
                          <span>{formatDate(viz.createdAt)}</span>
                          <span>•</span>
                          <span>by {viz.dimensionField}</span>
                        </div>
                      </div>
                    </div>
                  </button>
                );
              })}
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="flex items-center justify-between px-6 py-4 border-t border-[var(--sg-border)]">
          <div className="text-sm text-[var(--sg-text-muted)]">
            {selectedIds.length > 0 && (
              <span>
                {selectedIds.length} {selectedIds.length === 1 ? 'visualization' : 'visualizations'}{' '}
                selected
              </span>
            )}
          </div>
          <div className="flex items-center gap-3">
            <Button variant="outline" onClick={handleCancel}>
              Cancel
            </Button>
            <Button onClick={handleAdd} disabled={selectedIds.length === 0}>
              Add {selectedIds.length > 0 && `(${selectedIds.length})`}
            </Button>
          </div>
        </div>
      </div>
    </div>
  );
}
