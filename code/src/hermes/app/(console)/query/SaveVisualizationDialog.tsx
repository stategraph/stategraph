"use client";

import { useState } from 'react';
import { X, Save } from 'lucide-react';
import { Button } from '@/components/ui/button';
import type { SavedVisualizationInput } from './savedVisualizationRepository';

interface SaveVisualizationDialogProps {
  isOpen: boolean;
  onClose: () => void;
  onSave: (input: SavedVisualizationInput) => void;
  initialName?: string;
  initialDescription?: string;
}

export function SaveVisualizationDialog({
  isOpen,
  onClose,
  onSave,
  initialName = '',
  initialDescription = '',
}: SaveVisualizationDialogProps) {
  const [name, setName] = useState(initialName);
  const [description, setDescription] = useState(initialDescription);
  const [error, setError] = useState<string | null>(null);

  if (!isOpen) return null;

  const handleSave = () => {
    // Validate
    if (!name.trim()) {
      setError('Please enter a name for the visualization');
      return;
    }

    // Clear error and call onSave
    setError(null);
    onSave({
      name: name.trim(),
      description: description.trim() || undefined,
      // Other fields will be filled by the parent component
    } as SavedVisualizationInput);

    // Reset form
    setName('');
    setDescription('');
  };

  const handleClose = () => {
    setError(null);
    setName('');
    setDescription('');
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
      <div className="bg-[var(--sg-bg-0)] border border-[var(--sg-border)] rounded-lg shadow-2xl w-full max-w-md">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-[var(--sg-border)]">
          <h3 className="text-lg font-semibold text-[var(--sg-text)]">Save Visualization</h3>
          <Button variant="ghost" size="sm" onClick={handleClose}>
            <X className="w-4 h-4" />
          </Button>
        </div>

        {/* Content */}
        <div className="p-6 space-y-4">
          {/* Name Field */}
          <div>
            <label className="text-sm font-semibold text-[var(--sg-text)] block mb-2">
              Name <span className="text-[var(--sg-error)]">*</span>
            </label>
            <input
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="e.g., Provider Distribution"
              className="w-full px-3 py-2 bg-[var(--sg-bg-1)] border border-[var(--sg-border)] rounded-lg text-[var(--sg-text)] text-sm focus:outline-none focus:ring-2 focus:ring-[var(--sg-accent)]"
              autoFocus
            />
          </div>

          {/* Description Field */}
          <div>
            <label className="text-sm font-semibold text-[var(--sg-text)] block mb-2">
              Description
              <span className="text-xs text-[var(--sg-text-dim)] font-normal ml-2">
                (Optional)
              </span>
            </label>
            <textarea
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              placeholder="e.g., Shows the distribution of resources across cloud providers"
              rows={3}
              className="w-full px-3 py-2 bg-[var(--sg-bg-1)] border border-[var(--sg-border)] rounded-lg text-[var(--sg-text)] text-sm resize-none focus:outline-none focus:ring-2 focus:ring-[var(--sg-accent)]"
            />
          </div>

          {/* Error Message */}
          {error && (
            <div className="px-3 py-2 bg-[var(--sg-error)]/10 border border-[var(--sg-error)]/30 rounded-lg">
              <div className="text-sm text-[var(--sg-error)]">{error}</div>
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="flex items-center justify-end gap-3 px-6 py-4 border-t border-[var(--sg-border)]">
          <Button variant="outline" onClick={handleClose}>
            Cancel
          </Button>
          <Button onClick={handleSave}>
            <Save className="w-4 h-4 mr-2" />
            Save Visualization
          </Button>
        </div>
      </div>
    </div>
  );
}
