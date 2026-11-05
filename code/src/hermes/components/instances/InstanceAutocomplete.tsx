"use client";

import { useState, useEffect, useRef, useCallback } from "react";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { getStateInstances, Instance } from "@/lib/api/client";
import { ensureTagQuery } from "@/lib/query";
import { Loader2, ChevronDown, Search } from "lucide-react";

interface InstanceAutocompleteProps {
  stateId: string;
  value: string;
  onChange: (value: string) => void;
  onSelect?: (instance: Instance) => void;
  placeholder?: string;
  className?: string;
  onKeyDown?: (e: React.KeyboardEvent<HTMLInputElement>) => void;
}

export function InstanceAutocomplete({
  stateId,
  value,
  onChange,
  onSelect,
  placeholder = "Enter resource address...",
  className,
  onKeyDown,
}: InstanceAutocompleteProps) {
  const [suggestions, setSuggestions] = useState<Instance[]>([]);
  const [isOpen, setIsOpen] = useState(false);
  const [loading, setLoading] = useState(false);
  const [selectedIndex, setSelectedIndex] = useState(-1);
  const [dropdownSearch, setDropdownSearch] = useState("");
  const [isDropdownMode, setIsDropdownMode] = useState(false);
  const debounceTimerRef = useRef<NodeJS.Timeout | null>(null);
  const dropdownRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);
  const dropdownSearchRef = useRef<HTMLInputElement>(null);

  // Fetch suggestions with debouncing
  const fetchSuggestions = useCallback(
    async (query: string) => {
      setLoading(true);
      try {
        // If query is empty or very short, fetch first 20 instances as suggestions
        if (!query.trim() || query.length < 2) {
          const response = await getStateInstances(stateId, {
            limit: 20,
          });
          setSuggestions(response.data.results);
          setIsOpen(response.data.results.length > 0);
          setSelectedIndex(-1);
          return;
        }

        // Convert bare search terms to proper tag queries
        // e.g., "aws_s3_bucket" becomes "address:aws_s3_bucket OR type:aws_s3_bucket OR ..."
        const normalizedQuery = ensureTagQuery(query);

        const response = await getStateInstances(stateId, {
          q: normalizedQuery,
          limit: 10,
        });
        setSuggestions(response.data.results);
        setIsOpen(response.data.results.length > 0);
        setSelectedIndex(-1);
      } catch (error) {
        console.error("[InstanceAutocomplete] Failed to fetch suggestions:", error);
        setSuggestions([]);
        setIsOpen(false);
      } finally {
        setLoading(false);
      }
    },
    [stateId]
  );

  // Handle input change with debouncing
  const handleInputChange = (newValue: string) => {
    onChange(newValue);

    // Clear existing timer
    if (debounceTimerRef.current) {
      clearTimeout(debounceTimerRef.current);
    }

    // Set new timer
    debounceTimerRef.current = setTimeout(() => {
      fetchSuggestions(newValue);
    }, 300);
  };

  // Handle suggestion selection
  const handleSelect = (instance: Instance) => {
    onChange(instance.address);
    setSuggestions([]);
    setIsOpen(false);
    setSelectedIndex(-1);
    setIsDropdownMode(false);
    setDropdownSearch("");
    if (onSelect) {
      onSelect(instance);
    }
  };

  // Open dropdown in browse mode. The fetch (browse window, or server-side
  // search when the user types below) is driven by the effect keyed on
  // `dropdownSearch`.
  const openBrowseMode = () => {
    setIsDropdownMode(true);
    setIsOpen(true);
  };

  // Browse-mode search: push the typed term to the SERVER (ensureTagQuery) so
  // matches beyond the loaded window surface — previously it filtered the
  // fetched page client-side, hiding resources in large states (#1056).
  useEffect(() => {
    if (!isDropdownMode) return;
    const term = dropdownSearch.trim();
    const timer = setTimeout(async () => {
      setLoading(true);
      try {
        const q = term ? ensureTagQuery(term) : undefined;
        const response = await getStateInstances(stateId, { q, limit: q ? 50 : 100 });
        setSuggestions(response.data.results);
      } catch (error) {
        console.error("[InstanceAutocomplete] Failed to search instances:", error);
      } finally {
        setLoading(false);
      }
    }, 250);
    return () => clearTimeout(timer);
  }, [isDropdownMode, dropdownSearch, stateId]);

  // Handle keyboard navigation
  const handleKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (!isOpen || suggestions.length === 0) {
      if (onKeyDown) {
        onKeyDown(e);
      }
      return;
    }

    switch (e.key) {
      case "ArrowDown":
        e.preventDefault();
        setSelectedIndex((prev) =>
          prev < suggestions.length - 1 ? prev + 1 : prev
        );
        break;
      case "ArrowUp":
        e.preventDefault();
        setSelectedIndex((prev) => (prev > 0 ? prev - 1 : -1));
        break;
      case "Enter":
        e.preventDefault();
        if (selectedIndex >= 0 && selectedIndex < suggestions.length) {
          handleSelect(suggestions[selectedIndex]);
        } else if (onKeyDown) {
          onKeyDown(e);
        }
        break;
      case "Escape":
        e.preventDefault();
        setIsOpen(false);
        setSelectedIndex(-1);
        setIsDropdownMode(false);
        setDropdownSearch("");
        break;
      default:
        if (onKeyDown) {
          onKeyDown(e);
        }
    }
  };

  // Close dropdown when clicking outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (
        dropdownRef.current &&
        !dropdownRef.current.contains(event.target as Node) &&
        inputRef.current &&
        !inputRef.current.contains(event.target as Node)
      ) {
        setIsOpen(false);
        setSelectedIndex(-1);
        setIsDropdownMode(false);
        setDropdownSearch("");
      }
    };

    if (isOpen) {
      document.addEventListener("mousedown", handleClickOutside);
      return () => document.removeEventListener("mousedown", handleClickOutside);
    }
  }, [isOpen]);

  // Cleanup debounce timer on unmount
  useEffect(() => {
    return () => {
      if (debounceTimerRef.current) {
        clearTimeout(debounceTimerRef.current);
      }
    };
  }, []);

  // `suggestions` is already the result set — server-filtered in both the main
  // input and browse mode — so no client-side filtering.
  const filteredSuggestions = suggestions;

  return (
    <div className="relative flex-1">
      <div className="relative flex gap-2">
        <div className="relative flex-1">
          <Input
            ref={inputRef}
            type="text"
            placeholder={placeholder}
            value={value}
            onChange={(e) => handleInputChange(e.target.value)}
            onKeyDown={handleKeyDown}
            onFocus={() => {
              // Fetch initial suggestions on focus if no query
              if (!value.trim() && suggestions.length === 0) {
                fetchSuggestions("");
              } else if (suggestions.length > 0) {
                setIsOpen(true);
              }
            }}
            className={className}
          />
          {loading && !isDropdownMode && (
            <div className="absolute right-3 top-1/2 -translate-y-1/2">
              <Loader2 className="h-4 w-4 animate-spin text-[var(--sg-text-dim)]" />
            </div>
          )}
        </div>
        <Button
          type="button"
          variant="outline"
          onClick={openBrowseMode}
          disabled={loading}
          className="flex-shrink-0"
        >
          {loading && isDropdownMode ? (
            <Loader2 className="h-4 w-4 animate-spin" />
          ) : (
            <ChevronDown className="h-4 w-4" />
          )}
        </Button>
      </div>

      {/* Dropdown */}
      {isOpen && suggestions.length > 0 && (
        <div
          ref={dropdownRef}
          className="absolute z-50 w-full mt-1 max-h-96 flex flex-col bg-[var(--sg-bg-2)] border border-[var(--sg-border)] rounded-lg shadow-lg"
        >
          {/* Search box in dropdown mode */}
          {isDropdownMode && (
            <div className="p-2 border-b border-[var(--sg-border)] sticky top-0 bg-[var(--sg-bg-2)]">
              <div className="relative">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-[var(--sg-text-dim)]" />
                <input
                  ref={dropdownSearchRef}
                  type="text"
                  placeholder="Filter resources..."
                  value={dropdownSearch}
                  onChange={(e) => setDropdownSearch(e.target.value)}
                  className="w-full pl-9 pr-3 py-2 text-sm bg-[var(--sg-bg-1)] border border-[var(--sg-border)] rounded-lg text-[var(--sg-text)] placeholder:text-[var(--sg-text-dim)] focus:outline-none focus:ring-2 focus:ring-[var(--sg-accent)] focus:border-transparent"
                  autoFocus
                />
              </div>
            </div>
          )}

          {/* Results count */}
          {isDropdownMode && (
            <div className="px-3 py-2 text-xs text-[var(--sg-text-dim)] border-b border-[var(--sg-border)] bg-[var(--sg-bg-2)]">
              {suggestions.length} resource{suggestions.length === 1 ? "" : "s"}
            </div>
          )}

          {/* Instance list */}
          <div className="overflow-y-auto flex-1">
            {filteredSuggestions.length > 0 ? (
              filteredSuggestions.map((instance, index) => (
                <button
                  key={instance.address}
                  onClick={() => handleSelect(instance)}
                  className={`w-full px-3 py-2 text-left hover:bg-[var(--sg-bg-1)] transition-colors ${
                    index === selectedIndex ? "bg-[var(--sg-bg-1)]" : ""
                  }`}
                >
                  <div className="font-mono text-sm text-[var(--sg-text)]">
                    {instance.address}
                  </div>
                  <div className="text-xs text-[var(--sg-text-dim)] mt-0.5">
                    {instance.type} · {instance.provider}
                  </div>
                </button>
              ))
            ) : (
              <div className="px-3 py-8 text-center text-sm text-[var(--sg-text-dim)]">
                No resources match &ldquo;{dropdownSearch}&rdquo;
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
