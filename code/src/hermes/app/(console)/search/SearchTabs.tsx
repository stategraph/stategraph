"use client";

import React from "react";
import { Search, SlidersHorizontal } from "lucide-react";

interface SearchTabsProps {
  activeTab: "quick" | "filter";
  onTabChange: (tab: "quick" | "filter") => void;
}

export function SearchTabs({ activeTab, onTabChange }: SearchTabsProps) {
  return (
    <div className="flex items-center gap-1 border-b border-[var(--sg-border)]">
      <button
        onClick={() => onTabChange("quick")}
        className={`
          flex items-center gap-2 px-4 py-3 text-sm font-medium
          border-b-2 transition-colors
          ${
            activeTab === "quick"
              ? "border-[var(--sg-accent)] text-[var(--sg-text)]"
              : "border-transparent text-[var(--sg-text-muted)] hover:text-[var(--sg-text)]"
          }
        `}
      >
        <Search className="w-4 h-4" />
        Quick Search
      </button>
      <button
        onClick={() => onTabChange("filter")}
        className={`
          flex items-center gap-2 px-4 py-3 text-sm font-medium
          border-b-2 transition-colors
          ${
            activeTab === "filter"
              ? "border-[var(--sg-accent)] text-[var(--sg-text)]"
              : "border-transparent text-[var(--sg-text-muted)] hover:text-[var(--sg-text)]"
          }
        `}
      >
        <SlidersHorizontal className="w-4 h-4" />
        Filter Builder
      </button>
    </div>
  );
}
