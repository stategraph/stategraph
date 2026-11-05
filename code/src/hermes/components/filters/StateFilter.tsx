"use client";

import { useRef, useState } from "react";
import { useStates } from "@/contexts";
import { Button } from "@/components/ui/button";
import { SearchInput } from "@/components/ui/search-input";
import { Check, Database } from "lucide-react";
import { stateFilterOptions } from "./stateFilterOptions";

// The count footer says how much of the list lies below the fold. About 8 rows
// fit in the list's `max-h-[300px]`, so a shorter list shows every state and
// the footer is kept only for screen readers, which still hear filter results.
const MIN_STATES_FOR_COUNT = 8;

interface StateFilterProps {
  value: string | null;
  onChange: (stateId: string | null) => void;
  showAllOption?: boolean;
  className?: string;
  /**
   * Optional set of state IDs to render visually de-emphasised, e.g. when a
   * page has no useful data for them. Entries remain clickable so the user
   * can still navigate to them and see an inline empty state.
   */
  disabledStateIds?: string[];
  /** Tooltip shown on hover for entries in `disabledStateIds`. */
  disabledLabel?: string;
}

export function StateFilter({
  value,
  onChange,
  showAllOption,
  className,
  disabledStateIds,
  disabledLabel,
}: StateFilterProps) {
  const { states, isLoading } = useStates();
  const [isOpen, setIsOpen] = useState(false);
  const [searchQuery, setSearchQuery] = useState("");
  const triggerRef = useRef<HTMLButtonElement>(null);

  const disabledSet = disabledStateIds ? new Set(disabledStateIds) : null;
  const filteredStates = stateFilterOptions(states, searchQuery, disabledStateIds);
  const isFiltering = searchQuery.trim() !== "";

  const currentLabel = value === "all"
    ? "All States"
    : states.find((s) => s.id === value)?.name || "Select State";

  const closePicker = () => {
    setIsOpen(false);
    setSearchQuery("");
  };

  const handleSelect = (id: string) => {
    onChange(id);
    closePicker();
    triggerRef.current?.focus();
  };

  if (isLoading) {
    return (
      <Button variant="outline" size="sm" disabled className={`gap-2 ${className}`}>
        <Database className="h-4 w-4" />
        <span>Loading...</span>
      </Button>
    );
  }

  return (
    <div className="relative inline-block">
      <Button
        ref={triggerRef}
        variant="outline"
        size="sm"
        onClick={() => {
          if (isOpen) {
            closePicker();
          } else {
            setIsOpen(true);
          }
        }}
        aria-expanded={isOpen}
        aria-label={`Select state. Current selection: ${currentLabel}`}
        title={currentLabel}
        // Width comes from the caller's className. Pages pass a `min-w-[…]`
        // (which holds a sensible base width for short names but grows for
        // long ones) rather than a fixed `w-[…]`, which truncates long labels
        // with an ellipsis.
        className={`gap-2 justify-between ${className || ""}`}
      >
        {/* The label's `minmax(0, max-content)` column lets the trigger grow to
            fit the full name when there is room, but adds nothing to its
            min-content width: in a crowded header the trigger shrinks and
            truncates the label instead of overflowing. */}
        <div className="grid grid-cols-[auto_minmax(0,max-content)] items-center gap-2">
          <Database className="h-4 w-4" />
          <span className="truncate">{currentLabel}</span>
        </div>
        <span className="text-[var(--sg-text-dim)]">▼</span>
      </Button>

      {isOpen && (
        <>
          <div
            className="fixed inset-0 z-30"
            onClick={closePicker}
          />
          {/* Callers put the trigger at the right end of their header from `lg`
              up, and at its left below, where the header stacks: the menu is
              anchored on that side so it opens toward the page, not past its
              edge. */}
          <div
            className="absolute left-0 top-full z-40 mt-2 w-64 min-w-full overflow-hidden rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-1)] shadow-lg lg:left-auto lg:right-0"
            onKeyDown={(event) => {
              if (event.key !== "Escape") return;
              // The inspector and drawer panels close on Escape from their own
              // `document` listeners, which run after React's (also on
              // `document`, and registered first): stop them so that Escape
              // only closes the picker.
              event.stopPropagation();
              event.nativeEvent.stopImmediatePropagation();
              closePicker();
              triggerRef.current?.focus();
            }}
          >
            <div className="border-b border-[var(--sg-border)] p-2">
              <SearchInput
                type="search"
                value={searchQuery}
                onChange={(event) => setSearchQuery(event.target.value)}
                placeholder="Search states..."
                aria-label="Search states"
                autoFocus
                className="h-9 text-sm"
              />
            </div>
            <div className="max-h-[300px] overflow-y-auto py-1 scrollable">
              {/* The reset option, not a search result: listed whatever the query. */}
              {showAllOption && (
                <button
                  onClick={() => handleSelect("all")}
                  aria-current={value === "all"}
                  className="flex w-full items-center gap-2 px-3 py-2 text-left text-sm transition-colors hover:bg-[var(--sg-bg-2)] focus-visible:outline-none focus-visible:bg-[var(--sg-bg-2)]"
                >
                  <Check className={`h-3.5 w-3.5 flex-shrink-0 ${value === "all" ? "opacity-100" : "opacity-0"}`} />
                  <span className="text-[var(--sg-text)]">All States</span>
                </button>
              )}
              {filteredStates.map((state) => {
                const isDisabled = disabledSet?.has(state.id) ?? false;
                return (
                  <button
                    key={state.id}
                    onClick={() => handleSelect(state.id)}
                    aria-current={value === state.id}
                    title={isDisabled ? disabledLabel : undefined}
                    className={`flex w-full items-center gap-2 px-3 py-2 text-left text-sm transition-colors hover:bg-[var(--sg-bg-2)] focus-visible:outline-none focus-visible:bg-[var(--sg-bg-2)] ${isDisabled ? "opacity-50" : ""}`}
                  >
                    <Check className={`h-3.5 w-3.5 flex-shrink-0 ${value === state.id ? "opacity-100" : "opacity-0"}`} />
                    <span className="text-[var(--sg-text)] truncate">{state.name}</span>
                  </button>
                );
              })}
            </div>
            {filteredStates.length === 0 && (
              <p className="px-3 py-4 text-center text-sm text-[var(--sg-text-dim)]">
                No states found.
              </p>
            )}
            <p
              role="status"
              className={
                states.length < MIN_STATES_FOR_COUNT
                  ? "sr-only"
                  : "border-t border-[var(--sg-border)] px-3 py-2 text-center text-xs text-[var(--sg-text-dim)]"
              }
            >
              {isFiltering
                ? `${filteredStates.length} of ${states.length}`
                : states.length}{" "}
              {states.length === 1 ? "state" : "states"}
              {isFiltering ? "" : " total"}
            </p>
          </div>
        </>
      )}
    </div>
  );
}
