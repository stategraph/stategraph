"use client";

import React, { useState, useEffect, useRef } from "react";
import { Search, X } from "lucide-react";
import { Button } from "@/components/ui/button";

interface QueryBarProps {
  q: string;
  onChange: (q: string) => void;
  placeholder?: string;
  autoFocus?: boolean;
}

export function QueryBar({
  q,
  onChange,
  placeholder = "Search resources... (e.g., type:aws_s3_bucket)",
  autoFocus = false,
}: QueryBarProps) {
  const [localValue, setLocalValue] = useState(q);
  const inputRef = useRef<HTMLInputElement>(null);

  // Sync external changes
  useEffect(() => {
    setLocalValue(q);
  }, [q]);

  // Auto-focus if requested
  useEffect(() => {
    if (autoFocus && inputRef.current) {
      inputRef.current.focus();
    }
  }, [autoFocus]);

  // Debounced onChange (300ms)
  useEffect(() => {
    const timer = setTimeout(() => {
      if (localValue !== q) {
        onChange(localValue);
      }
    }, 300);

    return () => clearTimeout(timer);
  }, [localValue, q, onChange]);

  const handleClear = () => {
    setLocalValue("");
    onChange("");
    inputRef.current?.focus();
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === "Escape") {
      handleClear();
    }
  };

  return (
    <div className="relative">
      <div className="relative">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-[var(--sg-text-dim)]" />
        <input
          ref={inputRef}
          type="text"
          value={localValue}
          onChange={(e) => setLocalValue(e.target.value)}
          onKeyDown={handleKeyDown}
          placeholder={placeholder}
          className="w-full pl-10 pr-10 py-2.5 bg-[var(--sg-bg-2)] border border-[var(--sg-border)] rounded-lg text-sm text-[var(--sg-text)] placeholder:text-[var(--sg-text-dim)] focus:outline-none focus:ring-2 focus:ring-[var(--sg-accent)] focus:border-transparent transition-colors"
        />
        {localValue && (
          <Button
            variant="ghost"
            size="sm"
            onClick={handleClear}
            className="absolute right-1 top-1/2 -translate-y-1/2 h-7 w-7 p-0 hover:bg-[var(--sg-bg-1)]"
          >
            <X className="h-3.5 w-3.5" />
          </Button>
        )}
      </div>

      {/* Query syntax hint */}
      {!localValue && (
        <div className="mt-2 flex flex-wrap gap-2">
          <span className="text-xs text-[var(--sg-text-dim)]">Examples:</span>
          {["type:aws_s3_bucket", "module:networking"].map(
            (example) => (
              <button
                key={example}
                onClick={() => {
                  setLocalValue(example);
                  onChange(example);
                }}
                className="text-xs font-mono text-[var(--sg-text-muted)] hover:text-[var(--sg-accent)] transition-colors"
              >
                {example}
              </button>
            )
          )}
        </div>
      )}
    </div>
  );
}
