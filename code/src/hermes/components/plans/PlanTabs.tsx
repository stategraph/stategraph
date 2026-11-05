"use client";

import React from "react";
import { DollarSign, FileText, FolderTree, Target, Terminal } from "lucide-react";

export const TAB_IDS = ["changes", "tree", "apply", "impact", "cost"] as const;
export type PlanTab = (typeof TAB_IDS)[number];
export const DEFAULT_TAB: PlanTab = "changes";

interface PlanTabsProps {
  activeTab: PlanTab;
  onTabChange: (tab: PlanTab) => void;
}

const TABS: { id: PlanTab; label: string; icon: React.ComponentType<{ className?: string }> }[] = [
  { id: "changes", label: "Changes", icon: FileText },
  { id: "tree", label: "Tree", icon: FolderTree },
  { id: "apply", label: "Apply", icon: Terminal },
  { id: "impact", label: "Impact", icon: Target },
  { id: "cost", label: "Cost", icon: DollarSign },
];

export function PlanTabs({ activeTab, onTabChange }: PlanTabsProps) {
  return (
    <div
      role="tablist"
      aria-label="Run views"
      className="flex items-center gap-1 border-b border-[var(--sg-border)]"
    >
      {TABS.map(({ id, label, icon: Icon }) => {
        const selected = activeTab === id;
        return (
          <button
            key={id}
            role="tab"
            aria-selected={selected}
            onClick={() => onTabChange(id)}
            className={`
            flex items-center gap-2 px-4 py-3 text-sm font-medium
            border-b-2 transition-colors
            ${
              selected
                ? "border-[var(--sg-accent)] text-[var(--sg-text)]"
                : "border-transparent text-[var(--sg-text-muted)] hover:text-[var(--sg-text)]"
            }
          `}
          >
            <Icon className="w-4 h-4" />
            {label}
          </button>
        );
      })}
    </div>
  );
}
