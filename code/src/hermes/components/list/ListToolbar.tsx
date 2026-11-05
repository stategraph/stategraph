"use client";

import { Search } from "lucide-react";

export interface ListFilterOption {
  label: string;
  value: string;
}

export interface ListFilter {
  label: string;
  value: string;
  onChange: (v: string) => void;
  options: ListFilterOption[];
  /** Grouped options (rendered as optgroups) take precedence over `options`. */
  groups?: { label: string; options: ListFilterOption[] }[];
}

interface ListToolbarProps {
  search: string;
  onSearch: (v: string) => void;
  placeholder?: string;
  filters?: ListFilter[];
  /** Right-aligned extras (export buttons, etc.). */
  children?: React.ReactNode;
}

const offers = (f: ListFilter, value: string): boolean =>
  [...f.options, ...(f.groups ?? []).flatMap((g) => g.options)].some((o) => o.value === value);

/**
 * Consistent search + filter bar for the console list pages. Free-text search
 * on the left, dropdown facet filters after it, and an optional right-aligned
 * slot for page-specific actions. Filtering itself lives in each page (the
 * fields differ); this is just the chrome.
 */
export function ListToolbar({ search, onSearch, placeholder, filters, children }: ListToolbarProps) {
  return (
    <div className="flex items-center gap-2 flex-wrap mb-4">
      <div className="relative flex-1 min-w-[200px]">
        <Search className="absolute left-2.5 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-[var(--sg-text-dim)]" />
        <input
          value={search}
          onChange={(e) => onSearch(e.target.value)}
          placeholder={placeholder ?? "Search…"}
          className="w-full rounded-md border border-[var(--sg-border)] bg-[var(--sg-bg-1)] pl-8 pr-3 py-1.5 text-sm text-[var(--sg-text)] placeholder:text-[var(--sg-text-dim)]"
        />
      </div>
      {filters?.map((f) => (
        <select
          key={f.label}
          value={f.value}
          onChange={(e) => f.onChange(e.target.value)}
          aria-label={f.label}
          className="rounded-md border border-[var(--sg-border)] bg-[var(--sg-bg-1)] px-2 py-1.5 text-sm text-[var(--sg-text)]"
        >
          <option value="">{`All ${f.label.toLowerCase()}`}</option>
          {/* A value from the URL that the loaded rows do not offer (an owner
              outside the loaded window) still shows as the active selection,
              instead of "All …" while it filters. */}
          {f.value !== "" && !offers(f, f.value) && <option value={f.value}>{f.value}</option>}
          {f.groups && f.groups.length > 1
            ? f.groups.map((g) => (
                <optgroup key={g.label} label={g.label}>
                  {g.options.map((o) => (
                    <option key={o.value} value={o.value}>{o.label}</option>
                  ))}
                </optgroup>
              ))
            : f.options.map((o) => (
                <option key={o.value} value={o.value}>{o.label}</option>
              ))}
        </select>
      ))}
      {children && <div className="ml-auto flex items-center gap-2">{children}</div>}
    </div>
  );
}
