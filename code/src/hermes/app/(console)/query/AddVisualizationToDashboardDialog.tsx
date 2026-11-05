"use client";

import { useState } from 'react';
import { X, LayoutGrid, Plus } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { useDashboards } from './useDashboards';

interface AddVisualizationToDashboardDialogProps {
  isOpen: boolean;
  onClose: () => void;
  onAdd: (dashboardIds: string[]) => void;
  visualizationId: string;
}

export function AddVisualizationToDashboardDialog({
  isOpen,
  onClose,
  onAdd,
  visualizationId,
}: AddVisualizationToDashboardDialogProps) {
  const { dashboards } = useDashboards();
  const [selectedIds, setSelectedIds] = useState<string[]>([]);

  if (!isOpen) return null;

  // Filter out dashboards that already contain this visualization
  const availableDashboards = dashboards.filter(
    (dash) => !dash.visualizationIds.includes(visualizationId)
  );

  const toggleSelection = (id: string) => {
    setSelectedIds((prev) =>
      prev.includes(id) ? prev.filter((dashId) => dashId !== id) : [...prev, id]
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
            <h2 className="text-lg font-semibold text-[var(--sg-text)]">Add to Dashboard</h2>
            <p className="text-sm text-[var(--sg-text-muted)] mt-1">
              Select one or more dashboards to add this visualization to
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
          {availableDashboards.length === 0 ? (
            <div className="text-center py-12">
              <LayoutGrid className="w-12 h-12 mx-auto mb-3 text-[var(--sg-text-muted)] opacity-50" />
              <p className="text-sm text-[var(--sg-text-muted)]">
                {dashboards.length === 0
                  ? 'No dashboards available. Create a dashboard first in the Dashboards page.'
                  : 'This visualization has already been added to all available dashboards.'}
              </p>
            </div>
          ) : (
            <div className="space-y-2">
              {availableDashboards.map((dash) => {
                const isSelected = selectedIds.includes(dash.id);
                return (
                  <button
                    key={dash.id}
                    onClick={() => toggleSelection(dash.id)}
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

                      {/* Dashboard Info */}
                      <div className="flex-1 min-w-0">
                        <div className="text-sm font-medium text-[var(--sg-text)] mb-1">
                          {dash.name}
                        </div>
                        {dash.description && (
                          <p className="text-xs text-[var(--sg-text-muted)] mb-2 line-clamp-2">
                            {dash.description}
                          </p>
                        )}
                        <div className="flex items-center gap-3 text-[10px] text-[var(--sg-text-dim)]">
                          <span>{formatDate(dash.createdAt)}</span>
                          <span>•</span>
                          <span>
                            {dash.visualizationIds.length}{' '}
                            {dash.visualizationIds.length === 1 ? 'chart' : 'charts'}
                          </span>
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
                {selectedIds.length} {selectedIds.length === 1 ? 'dashboard' : 'dashboards'}{' '}
                selected
              </span>
            )}
          </div>
          <div className="flex items-center gap-3">
            <Button variant="outline" onClick={handleCancel}>
              Cancel
            </Button>
            <Button onClick={handleAdd} disabled={selectedIds.length === 0}>
              <Plus className="w-4 h-4 mr-2" />
              Add {selectedIds.length > 0 && `to ${selectedIds.length}`}
            </Button>
          </div>
        </div>
      </div>
    </div>
  );
}
