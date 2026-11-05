"use client";

import { useState } from 'react';
import { X } from 'lucide-react';
import { Button } from '@/components/ui/button';
import type { DashboardInput } from './dashboardRepository';

interface DashboardCreateDialogProps {
  isOpen: boolean;
  onClose: () => void;
  onCreate: (input: DashboardInput) => void;
}

export function DashboardCreateDialog({ isOpen, onClose, onCreate }: DashboardCreateDialogProps) {
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');

  if (!isOpen) return null;

  const handleSubmit = () => {
    if (!name.trim()) {
      return;
    }

    onCreate({
      name: name.trim(),
      description: description.trim() || undefined,
    });

    // Reset form
    setName('');
    setDescription('');
    onClose();
  };

  const handleCancel = () => {
    setName('');
    setDescription('');
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
      <div className="bg-[var(--sg-bg-0)] border border-[var(--sg-border)] rounded-lg shadow-2xl max-w-lg w-full">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-[var(--sg-border)]">
          <h2 className="text-lg font-semibold text-[var(--sg-text)]">Create Dashboard</h2>
          <button
            onClick={handleCancel}
            className="text-[var(--sg-text-muted)] hover:text-[var(--sg-text)] transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Content */}
        <div className="px-6 py-4 space-y-4">
          <div>
            <label className="block text-sm font-semibold text-[var(--sg-text)] mb-2">
              Dashboard Name <span className="text-[var(--sg-error)]">*</span>
            </label>
            <input
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="e.g., Infrastructure Overview"
              className="w-full px-3 py-2 bg-[var(--sg-bg-1)] border border-[var(--sg-border)] rounded-lg text-[var(--sg-text)] placeholder-[var(--sg-text-dim)] focus:outline-none focus:ring-2 focus:ring-[var(--sg-accent)]"
              autoFocus
            />
          </div>

          <div>
            <label className="block text-sm font-semibold text-[var(--sg-text)] mb-2">
              Description <span className="text-xs text-[var(--sg-text-dim)] font-normal">(optional)</span>
            </label>
            <textarea
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              placeholder="Describe what this dashboard shows..."
              rows={3}
              className="w-full px-3 py-2 bg-[var(--sg-bg-1)] border border-[var(--sg-border)] rounded-lg text-[var(--sg-text)] placeholder-[var(--sg-text-dim)] resize-none focus:outline-none focus:ring-2 focus:ring-[var(--sg-accent)]"
            />
          </div>
        </div>

        {/* Footer */}
        <div className="flex items-center justify-end gap-3 px-6 py-4 border-t border-[var(--sg-border)]">
          <Button variant="outline" onClick={handleCancel}>
            Cancel
          </Button>
          <Button onClick={handleSubmit} disabled={!name.trim()}>
            Create Dashboard
          </Button>
        </div>
      </div>
    </div>
  );
}
