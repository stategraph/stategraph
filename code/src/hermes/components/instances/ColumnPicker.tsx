"use client";

import { Instance } from '@/lib/api/client';
import { useState } from 'react';
import { Checkbox } from '@/components/ui/checkbox';
import { Button } from '@/components/ui/button';
import { Settings, RotateCcw } from 'lucide-react';
import {
  getAvailableColumns,
  DEFAULT_COLUMN_CONFIG,
  type ColumnConfig,
  type ColumnDefinition,
} from '@/lib/instances';

interface ColumnPickerProps {
  instances: Instance[];
  currentConfig: ColumnConfig;
  onConfigChange: (config: ColumnConfig) => void;
}

/**
 * Column picker dropdown for customizing table columns.
 * Allows users to show/hide core columns, attributes, and tag-based columns.
 */
export function ColumnPicker({
  instances,
  currentConfig,
  onConfigChange,
}: ColumnPickerProps) {
  const [isOpen, setIsOpen] = useState(false);
  const { core, attributes, tags } = getAvailableColumns(instances);

  const toggleColumn = (columnId: string) => {
    const visibleColumns = new Set(currentConfig.visibleColumns);

    if (visibleColumns.has(columnId)) {
      visibleColumns.delete(columnId);
    } else {
      visibleColumns.add(columnId);
    }

    onConfigChange({
      ...currentConfig,
      visibleColumns: Array.from(visibleColumns),
    });
  };

  const resetToDefault = () => {
    onConfigChange(DEFAULT_COLUMN_CONFIG);
  };

  const isColumnVisible = (columnId: string) => {
    return currentConfig.visibleColumns.includes(columnId);
  };

  const activeCount = currentConfig.visibleColumns.length;

  return (
    <div className="relative">
      {/* Trigger Button */}
      <Button
        variant="outline"
        size="sm"
        onClick={() => setIsOpen(!isOpen)}
        className="gap-2"
      >
        <Settings className="h-4 w-4" />
        Columns
        {activeCount > 0 && (
          <span className="ml-1 px-1.5 py-0.5 rounded text-[10px] bg-[var(--sg-accent-bg)] text-[var(--sg-accent)]">
            {activeCount}
          </span>
        )}
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
          <div className="absolute right-0 top-full mt-2 w-80 bg-[var(--sg-bg-1)] border border-[var(--sg-border)] rounded-lg shadow-lg z-40 overflow-hidden">
            {/* Header */}
            <div className="flex items-center justify-between px-4 py-3 border-b border-[var(--sg-border)] bg-[var(--sg-bg-0)]">
              <span className="text-sm font-medium text-[var(--sg-text)]">
                Customize Columns
              </span>
              <Button
                variant="ghost"
                size="sm"
                onClick={resetToDefault}
                className="h-7 text-xs gap-1.5"
              >
                <RotateCcw className="h-3 w-3" />
                Reset
              </Button>
            </div>

            {/* Content */}
            <div className="max-h-[400px] overflow-y-auto">
              {/* Core Columns Section */}
              <ColumnSection title="Core Fields">
                {core.map((column) => (
                  <ColumnCheckbox
                    key={column.id}
                    column={column}
                    isChecked={isColumnVisible(column.id)}
                    onChange={() => toggleColumn(column.id)}
                    isDisabled={column.id === 'resource'} // Resource column always visible
                  />
                ))}
              </ColumnSection>

              {/* Attributes Section */}
              {attributes.length > 0 && (
                <ColumnSection title="Attributes">
                  {attributes.map((column) => (
                    <ColumnCheckbox
                      key={column.id}
                      column={column}
                      isChecked={isColumnVisible(column.id)}
                      onChange={() => toggleColumn(column.id)}
                    />
                  ))}
                </ColumnSection>
              )}

              {/* Tags Section */}
              {tags.length > 0 && (
                <ColumnSection title="Tags">
                  {tags.map((column) => (
                    <ColumnCheckbox
                      key={column.id}
                      column={column}
                      isChecked={isColumnVisible(column.id)}
                      onChange={() => toggleColumn(column.id)}
                    />
                  ))}
                </ColumnSection>
              )}

              {/* Empty State */}
              {tags.length === 0 && attributes.length === 0 && (
                <div className="px-4 py-6 text-center text-sm text-[var(--sg-text-dim)]">
                  No additional columns available
                </div>
              )}
            </div>

            {/* Footer */}
            <div className="px-4 py-3 border-t border-[var(--sg-border)] bg-[var(--sg-bg-0)]">
              <div className="text-xs text-[var(--sg-text-dim)]">
                {activeCount} {activeCount === 1 ? 'column' : 'columns'} visible
              </div>
            </div>
          </div>
        </>
      )}
    </div>
  );
}

/**
 * Section header within column picker
 */
interface ColumnSectionProps {
  title: string;
  children: React.ReactNode;
}

function ColumnSection({ title, children }: ColumnSectionProps) {
  return (
    <div className="border-b border-[var(--sg-border)] last:border-b-0">
      <div className="px-4 py-2 bg-[var(--sg-bg-0)]">
        <h4 className="text-xs font-medium text-[var(--sg-text-dim)] uppercase tracking-wide">
          {title}
        </h4>
      </div>
      <div className="px-2 py-2 space-y-1">
        {children}
      </div>
    </div>
  );
}

/**
 * Checkbox for individual column
 */
interface ColumnCheckboxProps {
  column: ColumnDefinition;
  isChecked: boolean;
  onChange: () => void;
  isDisabled?: boolean;
}

function ColumnCheckbox({ column, isChecked, onChange, isDisabled = false }: ColumnCheckboxProps) {
  return (
    <label
      className={`
        flex items-center gap-3 px-2 py-2 rounded cursor-pointer
        hover:bg-[var(--sg-bg-2)] transition-colors
        ${isDisabled ? 'opacity-50 cursor-not-allowed' : ''}
      `}
    >
      <Checkbox
        checked={isChecked}
        onCheckedChange={onChange}
        disabled={isDisabled}
      />
      <div className="flex-1 min-w-0">
        <div className="text-sm text-[var(--sg-text)]">
          {column.label}
        </div>
        {column.type === 'tag' && (
          <div className="text-xs text-[var(--sg-text-dim)]">
            Tag column
          </div>
        )}
        {column.type === 'attribute' && (
          <div className="text-xs text-[var(--sg-text-dim)]">
            Derived attribute
          </div>
        )}
      </div>
      {column.isDefault && (
        <span className="text-[10px] px-1.5 py-0.5 rounded bg-[var(--sg-bg-2)] text-[var(--sg-text-dim)]">
          Default
        </span>
      )}
    </label>
  );
}
