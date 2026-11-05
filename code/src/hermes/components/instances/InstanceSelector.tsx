"use client";

import { useState, useEffect, useRef, useCallback } from "react";
import { createPortal } from "react-dom";
import { Button } from "@/components/ui/button";
import { getStateInstances, Instance } from "@/lib/api/client";
import { ensureTagQuery } from "@/lib/query";
import { parseLinkHeader, hasNextPage } from "@/lib/api/pagination";
import { Loader2, ChevronDown, Search } from "lucide-react";

interface InstanceSelectorProps {
  stateId?: string;
  allStates?: { id: string; name: string }[];
  value: string;
  onChange: (value: string) => void;
  onSelect?: (instance: Instance) => void;
  placeholder?: string;
}

export function InstanceSelector({
  stateId,
  allStates,
  value,
  onChange,
  onSelect,
  placeholder = "Select a resource...",
}: InstanceSelectorProps) {
  const [instances, setInstances] = useState<Instance[]>([]);
  const [isOpen, setIsOpen] = useState(false);
  const [loading, setLoading] = useState(false);
  const [searchTerm, setSearchTerm] = useState("");
  const [hasMore, setHasMore] = useState(false);
  const [nextPageCursor, setNextPageCursor] = useState<string[] | undefined>(undefined);
  const [buttonRect, setButtonRect] = useState<DOMRect | null>(null);
  const dropdownRef = useRef<HTMLDivElement>(null);
  const buttonRef = useRef<HTMLButtonElement>(null);

  // Update button position when dropdown opens
  useEffect(() => {
    if (isOpen && buttonRef.current) {
      setButtonRect(buttonRef.current.getBoundingClientRect());
    }
  }, [isOpen]);

  // Load instances. With a search term, push it to the SERVER (ensureTagQuery,
  // same as /search) so matches beyond the loaded window surface — previously
  // the term only filtered the fetched page client-side, hiding resources in
  // large states. With no term, load the browse window (paginated via Load More
  // for a single state).
  const loadInstances = useCallback(async (search?: string) => {
    setLoading(true);
    const q = search?.trim() ? ensureTagQuery(search.trim()) : undefined;
    try {
      if (allStates && !stateId) {
        // Fetch from all states in parallel (server-filtered when searching).
        const allResults = await Promise.all(
          allStates.map(async (state) => {
            try {
              const response = await getStateInstances(state.id, { q, limit: q ? 50 : 500 });
              return response.data.results.map((inst) => ({
                ...inst,
                state_id: state.id,
                state_name: state.name,
              }));
            } catch {
              return [];
            }
          })
        );
        const merged = allResults.flat();
        merged.sort((a, b) => a.address.localeCompare(b.address));
        setInstances(merged);
        setHasMore(false);
        setNextPageCursor(undefined);
      } else if (stateId) {
        const response = await getStateInstances(stateId, { q, limit: q ? 50 : 100 });
        const links = parseLinkHeader(response.linkHeader);
        setInstances(response.data.results);
        // Load More is only for the unfiltered browse window; a search is one fetch.
        setHasMore(q ? false : hasNextPage(links));
        setNextPageCursor(q ? undefined : links.next);
      }
    } catch (error) {
      console.error("[InstanceSelector] Failed to load instances:", error);
    } finally {
      setLoading(false);
    }
  }, [stateId, allStates]);

  // Load on open (browse window), and re-query the server when the search term
  // changes (debounced).
  useEffect(() => {
    if (!isOpen) return;
    const term = searchTerm.trim();
    if (!term) {
      loadInstances();
      return;
    }
    const timer = setTimeout(() => loadInstances(term), 250);
    return () => clearTimeout(timer);
  }, [isOpen, searchTerm, loadInstances]);

  // Load more instances (append to existing)
  const handleLoadMore = useCallback(async () => {
    if (!nextPageCursor || !stateId) return;

    setLoading(true);
    try {
      const response = await getStateInstances(stateId, {
        limit: 100,
        page: nextPageCursor,
      });

      const links = parseLinkHeader(response.linkHeader);

      // Append new instances to existing ones
      setInstances(prev => [...prev, ...response.data.results]);
      setHasMore(hasNextPage(links));
      setNextPageCursor(links.next);
    } catch (error) {
      console.error("[InstanceSelector] Failed to load more instances:", error);
    } finally {
      setLoading(false);
    }
  }, [stateId, nextPageCursor]);

  // Handle selection
  const handleSelect = (instance: Instance) => {
    onChange(instance.address);
    setIsOpen(false);
    setSearchTerm("");
    if (onSelect) {
      onSelect(instance);
    }
  };

  // `instances` is already the result set — server-filtered when searching (by
  // address/type/provider/module/tags via ensureTagQuery), the browse window
  // otherwise. No client-side filtering.

  // Close dropdown when clicking outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (
        dropdownRef.current &&
        !dropdownRef.current.contains(event.target as Node) &&
        buttonRef.current &&
        !buttonRef.current.contains(event.target as Node)
      ) {
        setIsOpen(false);
        setSearchTerm("");
      }
    };

    if (isOpen) {
      document.addEventListener("mousedown", handleClickOutside);
      return () => document.removeEventListener("mousedown", handleClickOutside);
    }
  }, [isOpen]);

  // Find selected instance for display
  const selectedInstance = instances.find((i) => i.address === value);

  // Render dropdown content
  const dropdownContent = isOpen && buttonRect && (
    <div
      ref={dropdownRef}
      className="fixed flex flex-col bg-[var(--sg-bg-2)] border border-[var(--sg-border)] rounded-lg shadow-lg"
      style={{
        top: `${buttonRect.bottom + 4}px`,
        left: `${buttonRect.left}px`,
        width: `${buttonRect.width}px`,
        maxHeight: '384px',
        zIndex: 9999,
      }}
    >
          {/* Search box */}
          <div className="p-2 border-b border-[var(--sg-border)] sticky top-0 bg-[var(--sg-bg-2)]">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-[var(--sg-text-dim)]" />
              <input
                type="text"
                placeholder="Search resources..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-9 pr-3 py-2 text-sm bg-[var(--sg-bg-1)] border border-[var(--sg-border)] rounded-lg text-[var(--sg-text)] placeholder:text-[var(--sg-text-dim)] focus:outline-none focus:ring-2 focus:ring-[var(--sg-accent)] focus:border-transparent"
                autoFocus
              />
            </div>
          </div>

          {/* Results count */}
          <div className="px-3 py-2 text-xs text-[var(--sg-text-dim)] border-b border-[var(--sg-border)] bg-[var(--sg-bg-2)]">
            {loading ? (
              <span className="flex items-center gap-2">
                <Loader2 className="h-3 w-3 animate-spin" />
                Loading resources...
              </span>
            ) : (
              <span>
                {searchTerm ? (
                  // Server-side search results for the whole state.
                  <>{instances.length} result{instances.length === 1 ? "" : "s"}</>
                ) : (
                  // Browse window: "X loaded" + "more available" if paginated.
                  <>{instances.length} loaded{hasMore && <> • more available</>}</>
                )}
              </span>
            )}
          </div>

          {/* Instance list */}
          <div className="overflow-y-auto flex-1">
            {!loading && instances.length > 0 ? (
              <>
                {instances.map((instance, index) => (
                  <button
                    key={`${instance.address}-${index}`}
                    onClick={() => handleSelect(instance)}
                    className={`w-full px-3 py-2 text-left hover:bg-[var(--sg-bg-1)] transition-colors ${
                      instance.address === value ? "bg-[var(--sg-accent-bg)]" : ""
                    }`}
                  >
                    <div className="font-mono text-sm text-[var(--sg-text)]">
                      {instance.address}
                    </div>
                    <div className="text-xs text-[var(--sg-text-dim)] mt-0.5">
                      {instance.type}
                    </div>
                  </button>
                ))}

                {/* Load More button */}
                {!searchTerm && hasMore && (
                  <div className="p-2 border-t border-[var(--sg-border)]">
                    <Button
                      type="button"
                      variant="ghost"
                      size="sm"
                      onClick={handleLoadMore}
                      disabled={loading}
                      className="w-full"
                    >
                      {loading ? (
                        <Loader2 className="h-4 w-4 animate-spin mr-2" />
                      ) : null}
                      Load More
                    </Button>
                  </div>
                )}
              </>
            ) : !loading ? (
              <div className="px-3 py-8 text-center text-sm text-[var(--sg-text-dim)]">
                {searchTerm ? `No resources match "${searchTerm}"` : "No resources found"}
              </div>
            ) : null}
          </div>
        </div>
  );

  return (
    <div className="relative flex-1">
      <Button
        ref={buttonRef}
        type="button"
        variant="outline"
        onClick={() => setIsOpen(!isOpen)}
        className="w-full justify-between text-left font-normal"
      >
        <span className={!value ? "text-[var(--sg-text-dim)]" : "truncate"}>
          {selectedInstance ? (
            <span className="font-mono text-sm">{selectedInstance.address}</span>
          ) : (
            placeholder
          )}
        </span>
        <ChevronDown className="h-4 w-4 opacity-50 flex-shrink-0 ml-2" />
      </Button>

      {/* Render dropdown via portal to document.body */}
      {typeof document !== 'undefined' && dropdownContent && createPortal(dropdownContent, document.body)}
    </div>
  );
}
