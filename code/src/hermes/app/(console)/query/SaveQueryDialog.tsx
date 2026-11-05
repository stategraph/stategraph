"use client";

import { useState, useEffect } from "react";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";

interface SaveQueryDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  currentQuery: string;
  onSave: (name: string, description?: string) => Promise<void>;
  editingQuery?: {
    id: string;
    name: string;
    description?: string;
  };
}

export function SaveQueryDialog({
  open,
  onOpenChange,
  currentQuery,
  onSave,
  editingQuery,
}: SaveQueryDialogProps) {
  const [name, setName] = useState("");
  const [description, setDescription] = useState("");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Reset form when dialog opens/closes or editing changes
  useEffect(() => {
    if (open) {
      if (editingQuery) {
        setName(editingQuery.name);
        setDescription(editingQuery.description || "");
      } else {
        setName("");
        setDescription("");
      }
      setError(null);
    }
  }, [open, editingQuery]);

  const handleSave = async () => {
    // Validation
    if (!name.trim()) {
      setError("Please enter a name for this query");
      return;
    }

    if (!currentQuery.trim()) {
      setError("Cannot save an empty query");
      return;
    }

    setSaving(true);
    setError(null);

    try {
      await onSave(name.trim(), description.trim() || undefined);
      onOpenChange(false);
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : "Failed to save query";
      setError(message);
    } finally {
      setSaving(false);
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === "Enter" && (e.metaKey || e.ctrlKey)) {
      e.preventDefault();
      handleSave();
    }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent
        className="bg-[var(--sg-bg-1)] border-[var(--sg-border)]"
        onKeyDown={handleKeyDown}
      >
        <DialogHeader>
          <DialogTitle className="text-[var(--sg-text)]">
            {editingQuery ? "Edit Saved Query" : "Save Query"}
          </DialogTitle>
        </DialogHeader>

        <div className="space-y-4 py-4">
          {/* Name Input */}
          <div className="space-y-2">
            <label htmlFor="name" className="text-sm font-medium text-[var(--sg-text)]">
              Name <span className="text-[var(--sg-error)]">*</span>
            </label>
            <input
              type="text"
              id="name"
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="e.g., AWS Resources by Provider"
              className="w-full px-3 py-2 text-sm bg-[var(--sg-bg-2)] border border-[var(--sg-border)] rounded-md text-[var(--sg-text)] focus:outline-none focus:ring-2 focus:ring-[var(--sg-accent)] focus:border-transparent"
              autoFocus
            />
          </div>

          {/* Description Input */}
          <div className="space-y-2">
            <label htmlFor="description" className="text-sm font-medium text-[var(--sg-text)]">
              Description (optional)
            </label>
            <textarea
              id="description"
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              placeholder="Optional description of what this query does..."
              className="w-full h-20 px-3 py-2 text-sm bg-[var(--sg-bg-2)] border border-[var(--sg-border)] rounded-md text-[var(--sg-text)] resize-none focus:outline-none focus:ring-2 focus:ring-[var(--sg-accent)] focus:border-transparent"
            />
          </div>

          {/* Query Preview */}
          <div className="space-y-2">
            <div className="text-sm font-medium text-[var(--sg-text)]">Query</div>
            <pre className="p-3 text-xs font-mono bg-[var(--sg-bg-0)] border border-[var(--sg-border)] rounded-md text-[var(--sg-text-muted)] overflow-x-auto max-h-32 overflow-y-auto">
              {currentQuery}
            </pre>
          </div>

          {/* Error Message */}
          {error && (
            <div className="p-3 bg-[var(--sg-error)]/10 border border-[var(--sg-error)] rounded-md">
              <p className="text-sm text-[var(--sg-error)]">{error}</p>
            </div>
          )}
        </div>

        <DialogFooter>
          <Button
            variant="outline"
            onClick={() => onOpenChange(false)}
            disabled={saving}
          >
            Cancel
          </Button>
          <Button onClick={handleSave} disabled={saving}>
            {saving ? "Saving..." : editingQuery ? "Update" : "Save"}
          </Button>
        </DialogFooter>

        <div className="text-xs text-[var(--sg-text-dim)] mt-2">
          Tip: Press <kbd className="px-1 py-0.5 bg-[var(--sg-bg-2)] border border-[var(--sg-border)] rounded">Ctrl+Enter</kbd> to save
        </div>
      </DialogContent>
    </Dialog>
  );
}
