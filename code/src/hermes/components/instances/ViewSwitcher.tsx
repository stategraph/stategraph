"use client";

import { useState } from 'react';
import { Button } from '@/components/ui/button';
import { Layers, Check, Copy, Trash2 } from 'lucide-react';
import {
  getAllViews,
  duplicateView,
  deleteCustomView,
  type View,
} from '@/lib/instances';

interface ViewSwitcherProps {
  currentViewId: string;
  onViewChange: (viewId: string) => void;
  onViewsUpdated?: () => void; // Callback when views are modified (created/deleted)
}

/**
 * ViewSwitcher - Dropdown for switching between preset and custom views
 */
export function ViewSwitcher({
  currentViewId,
  onViewChange,
  onViewsUpdated,
}: ViewSwitcherProps) {
  const [isOpen, setIsOpen] = useState(false);
  const allViews = getAllViews();

  const defaultViews = allViews.filter((v) => v.isDefault);
  const customViews = allViews.filter((v) => !v.isDefault);

  const currentView = allViews.find((v) => v.id === currentViewId);

  const handleSelectView = (viewId: string) => {
    onViewChange(viewId);
    setIsOpen(false);
  };

  const handleDuplicateView = (viewId: string, e: React.MouseEvent) => {
    e.stopPropagation();
    const newView = duplicateView(viewId);
    if (newView) {
      onViewsUpdated?.();
      // Optionally switch to the new view
      onViewChange(newView.id);
    }
    setIsOpen(false);
  };

  const handleDeleteView = (viewId: string, e: React.MouseEvent) => {
    e.stopPropagation();
    const success = deleteCustomView(viewId);
    if (success) {
      onViewsUpdated?.();
      // If we deleted the current view, switch to default
      if (viewId === currentViewId) {
        onViewChange('all');
      }
    }
  };

  return (
    <div className="relative">
      {/* Trigger Button */}
      <Button
        variant="outline"
        size="sm"
        onClick={() => setIsOpen(!isOpen)}
        className="gap-2 min-w-[180px] justify-between"
      >
        <div className="flex items-center gap-2">
          <Layers className="h-4 w-4" />
          <span className="truncate">{currentView?.name || 'All Resources'}</span>
        </div>
        <span className="text-[var(--sg-text-dim)]">▼</span>
      </Button>

      {/* Dropdown */}
      {isOpen && (
        <>
          {/* Backdrop */}
          <div
            className="fixed inset-0 z-30"
            onClick={() => setIsOpen(false)}
          />

          {/* Dropdown Panel */}
          <div className="absolute left-0 top-full mt-2 w-80 bg-[var(--sg-bg-1)] border border-[var(--sg-border)] rounded-lg shadow-lg z-40 overflow-hidden">
            {/* Header */}
            <div className="px-4 py-3 border-b border-[var(--sg-border)] bg-[var(--sg-bg-0)]">
              <span className="text-sm font-medium text-[var(--sg-text)]">
                Switch View
              </span>
            </div>

            {/* Content */}
            <div className="max-h-[400px] overflow-y-auto">
              {/* Default Views Section */}
              <ViewSection title="Default Views">
                {defaultViews.map((view) => (
                  <ViewItem
                    key={view.id}
                    view={view}
                    isActive={view.id === currentViewId}
                    onSelect={() => handleSelectView(view.id)}
                    onDuplicate={(e) => handleDuplicateView(view.id, e)}
                  />
                ))}
              </ViewSection>

              {/* Custom Views Section */}
              {customViews.length > 0 && (
                <ViewSection title="Custom Views">
                  {customViews.map((view) => (
                    <ViewItem
                      key={view.id}
                      view={view}
                      isActive={view.id === currentViewId}
                      onSelect={() => handleSelectView(view.id)}
                      onDuplicate={(e) => handleDuplicateView(view.id, e)}
                      onDelete={(e) => handleDeleteView(view.id, e)}
                    />
                  ))}
                </ViewSection>
              )}

              {/* Empty State for Custom Views */}
              {customViews.length === 0 && (
                <div className="px-4 py-6 text-center text-sm text-[var(--sg-text-dim)] border-t border-[var(--sg-border)]">
                  No custom views yet. Duplicate a view to create one.
                </div>
              )}
            </div>

            {/* Footer */}
            <div className="px-4 py-3 border-t border-[var(--sg-border)] bg-[var(--sg-bg-0)]">
              <div className="text-xs text-[var(--sg-text-dim)]">
                {allViews.length} {allViews.length === 1 ? 'view' : 'views'} available
              </div>
            </div>
          </div>
        </>
      )}
    </div>
  );
}

/**
 * Section header within view switcher
 */
interface ViewSectionProps {
  title: string;
  children: React.ReactNode;
}

function ViewSection({ title, children }: ViewSectionProps) {
  return (
    <div className="border-b border-[var(--sg-border)] last:border-b-0">
      <div className="px-4 py-2 bg-[var(--sg-bg-0)]">
        <h4 className="text-xs font-medium text-[var(--sg-text-dim)] uppercase tracking-wide">
          {title}
        </h4>
      </div>
      <div className="py-1">
        {children}
      </div>
    </div>
  );
}

/**
 * Individual view item
 */
interface ViewItemProps {
  view: View;
  isActive: boolean;
  onSelect: () => void;
  onDuplicate: (e: React.MouseEvent) => void;
  onDelete?: (e: React.MouseEvent) => void;
}

function ViewItem({ view, isActive, onSelect, onDuplicate, onDelete }: ViewItemProps) {
  return (
    <div
      onClick={onSelect}
      className={`
        group
        px-4 py-2.5 cursor-pointer transition-colors
        hover:bg-[var(--sg-bg-2)]
        ${isActive ? 'bg-[var(--sg-accent-bg)]' : ''}
      `}
    >
      <div className="flex items-start justify-between gap-3">
        {/* View Info */}
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2">
            <span className={`text-sm font-medium ${isActive ? 'text-[var(--sg-accent)]' : 'text-[var(--sg-text)]'}`}>
              {view.name}
            </span>
            {isActive && <Check className="h-3.5 w-3.5 text-[var(--sg-accent)]" />}
            {view.isDefault && (
              <span className="text-[10px] px-1.5 py-0.5 rounded bg-[var(--sg-bg-2)] text-[var(--sg-text-dim)]">
                Default
              </span>
            )}
          </div>
          <p className="text-xs text-[var(--sg-text-dim)] mt-0.5 truncate">
            {view.description}
          </p>
        </div>

        {/* Actions */}
        <div className="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
          {/* Duplicate */}
          <button
            onClick={onDuplicate}
            className="p-1 hover:bg-[var(--sg-bg-1)] rounded transition-colors"
            title="Duplicate view"
          >
            <Copy className="h-3.5 w-3.5 text-[var(--sg-text-dim)] hover:text-[var(--sg-text)]" />
          </button>

          {/* Delete (only for custom views) */}
          {!view.isDefault && onDelete && (
            <button
              onClick={onDelete}
              className="p-1 hover:bg-[var(--sg-error)]/10 rounded transition-colors"
              title="Delete view"
            >
              <Trash2 className="h-3.5 w-3.5 text-[var(--sg-text-dim)] hover:text-[var(--sg-error)]" />
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
