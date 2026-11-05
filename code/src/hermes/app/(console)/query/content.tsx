"use client";

import { useState, useEffect, useRef } from "react";
import { useSearchParams } from "next/navigation";
import { useStates, useTenant } from "@/contexts";
import { useIsMobile } from "@/hooks";
import { useAuth } from "@/components/auth";
import { PageHeader } from "@/components/page/PageHeader";
import { Button } from "@/components/ui/button";
import { Play, Copy, Trash2, ChevronRight, ChevronLeft, Clock, X, Save, Edit, Bookmark, AlertCircle, FileJson, FileText, BarChart3, Share2, Download } from "lucide-react";
import { EXAMPLE_QUERY_GROUPS } from "./compiler";
import { executeMQL } from "@/lib/api/client";
import { resourceTypesQuery, type ResourceTypeRow } from "./mqlQueries";
import { parseLinkHeader, hasNextPage } from "@/lib/api/pagination";
import { getAutocompleteSuggestions, applySuggestion, type Suggestion } from "./autocomplete";
import { describeMqlError, describePaginationError, type MqlErrorInfo } from "./mqlErrors";
import { fetchMQLSchema, type MQLTable } from "@/lib/query/mqlSchema";
import { useQueryHistory } from "./useQueryHistory";
import { useSavedQueries } from "./useSavedQueries";
import { SaveQueryDialog } from "./SaveQueryDialog";
import { validateSQL, type ValidationResult, type ValidationError } from "./validator";
import { exportAsCSV, exportAsJSON } from "./exportUtils";
import { VisualizationModal } from "./VisualizationModal";
import { useSavedVisualizations } from "./useSavedVisualizations";
import { SavedVisualizationsList } from "./SavedVisualizationsList";
import { QueryResultsViewer } from "@/components/query/QueryResultsViewer";
import { SchemaBrowser } from "@/components/query/SchemaBrowser";
import type { SavedVisualizationInput, SavedVisualization } from "./savedVisualizationRepository";
import { track } from "@/lib/analytics";

export function QueryContent() {
  const searchParams = useSearchParams();
  const { isLoading: authLoading, isAuthenticated } = useAuth();
  const { states } = useStates();
  const { currentTenant } = useTenant();
  const isMobile = useIsMobile();
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  // Use first available state for autocomplete metadata and instance inspector
  const currentState = states.length > 0 ? states[0] : null;
  const { history, addToHistory, removeFromHistory, clearHistory } = useQueryHistory();
  const { savedQueries, saveQuery, deleteQuery } = useSavedQueries();
  const {
    visualizations,
    saveVisualization,
    updateVisualization,
    deleteVisualization,
  } = useSavedVisualizations();

  // Query state — initialize from ?q= URL param if present
  const [query, setQuery] = useState(() => searchParams.get("q") || "select * from instances limit 10");
  const [results, setResults] = useState<unknown[]>([]);
  const [loading, setLoading] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);
  const [error, setError] = useState<MqlErrorInfo | null>(null);
  const [executionTime, setExecutionTime] = useState<number | null>(null);

  const [nextPageCursor, setNextPageCursor] = useState<string[] | undefined>(undefined);
  const [paginationHint, setPaginationHint] = useState<string | null>(null);

  // UI state. Below lg the sidebar becomes an overlay sheet, so default it
  // collapsed there (useIsMobile is correct on first render — no open→closed flash).
  const [showExamples, setShowExamples] = useState(!isMobile);
  const [sidebarTab, setSidebarTab] = useState<'examples' | 'history' | 'saved' | 'visualizations' | 'schema'>('examples');
  const [saveDialogOpen, setSaveDialogOpen] = useState(false);
  const [editingQuery, setEditingQuery] = useState<{ id: string; name: string; description?: string } | undefined>();

  // Autocomplete state
  const [suggestions, setSuggestions] = useState<Suggestion[]>([]);
  const [selectedSuggestionIndex, setSelectedSuggestionIndex] = useState(0);
  const [cursorPosition, setCursorPosition] = useState(0);
  const [providers, setProviders] = useState<string[]>([]);
  const [types, setTypes] = useState<string[]>([]);
  const [schema, setSchema] = useState<MQLTable[]>([]);

  // Validation state
  const [validationResult, setValidationResult] = useState<ValidationResult>({
    isValid: true,
    errors: [],
    hasFatalErrors: false,
  });

  // Visualization modal state
  const [showVisualization, setShowVisualization] = useState(false);

  // Share button feedback
  const [shareCopied, setShareCopied] = useState(false);

  // Export menu
  const [showExportMenu, setShowExportMenu] = useState(false);
  const exportMenuRef = useRef<HTMLDivElement>(null);

  // Auto-run query from URL param on mount
  const hasAutoRun = useRef(false);
  useEffect(() => {
    if (!hasAutoRun.current && searchParams.get("q") && isAuthenticated && !authLoading) {
      hasAutoRun.current = true;
      executeQuery();
    }
  }, [isAuthenticated, authLoading]); // eslint-disable-line react-hooks/exhaustive-deps

  // Execute query
  const executeQuery = async () => {
    setLoading(true);
    setError(null);
    const startTime = performance.now();

    try {
      // Execute MQL query directly on the backend
      const response = await executeMQL(query);

      const endTime = performance.now();
      const execTime = endTime - startTime;
      setExecutionTime(execTime);
      setResults(response.data);

      // Check for pagination
      const links = parseLinkHeader(response.linkHeader);
      setNextPageCursor(hasNextPage(links) ? links.next : undefined);

      // Surface a hint when results were truncated but can't be paginated.
      setPaginationHint(describePaginationError(response.paginationError));

      // Add to history on successful execution
      addToHistory(query, execTime, response.data.length);
      track('mql_query_run', {
        row_count: response.data.length,
        duration_ms: Math.round(execTime),
        has_more: hasNextPage(links),
      });
    } catch (err: unknown) {
      console.error('[MQL Query Error]', err);
      setError(describeMqlError(err));
      track('mql_query_failed');
    } finally {
      setLoading(false);
    }
  };

  // Load more results (next page)
  const loadMoreResults = async () => {
    if (!nextPageCursor) return;

    setLoadingMore(true);
    try {
      const response = await executeMQL(query, { page: nextPageCursor });
      setResults((prev) => [...prev, ...response.data]);

      const links = parseLinkHeader(response.linkHeader);
      setNextPageCursor(hasNextPage(links) ? links.next : undefined);
    } catch (err: unknown) {
      console.error('[MQL Load More Error]', err);
      setError(describeMqlError(err));
    } finally {
      setLoadingMore(false);
    }
  };

  // Handle example query click
  const loadExample = (sql: string) => {
    setQuery(sql);
    setSuggestions([]);
  };

  // Handle save query
  const handleSaveQuery = async (name: string, description?: string) => {
    await saveQuery(name, query, description, editingQuery?.id);
    setEditingQuery(undefined);
  };

  // Handle load saved query
  const handleLoadSavedQuery = (savedQuery: string) => {
    setQuery(savedQuery);
    setSuggestions([]);
  };

  // Handle CSV export
  const handleExportCSV = () => {
    if (results.length === 0) return;
    exportAsCSV(results as Record<string, unknown>[], 'stategraph-query-results');
  };

  // Handle JSON export
  const handleExportJSON = () => {
    if (results.length === 0) return;
    exportAsJSON(results as Record<string, unknown>[], query, executionTime, 'stategraph-query-results');
  };

  // Handle save visualization
  const handleSaveVisualization = (input: SavedVisualizationInput) => {
    saveVisualization(input);
    track('visualization_saved', { chart_type: input.chartType });
    // Optionally show a success message
  };

  // Handle load visualization
  const handleLoadVisualization = (viz: SavedVisualization) => {
    // Load the SQL query into the editor
    setQuery(viz.query);
    setSuggestions([]);

    // Auto-run the query
    // Note: We'll need to trigger query execution after the state updates
    setTimeout(() => {
      executeQuery();
    }, 100);
  };

  // Handle rename visualization
  const handleRenameVisualization = (id: string, name: string, description?: string) => {
    updateVisualization(id, { name, description });
  };

  // Handle delete visualization
  const handleDeleteVisualization = (id: string) => {
    deleteVisualization(id);
  };

  // Load MQL schema for autocomplete
  useEffect(() => {
    let cancelled = false;

    async function loadSchema() {
      try {
        const data = await fetchMQLSchema();
        if (!cancelled) {
          setSchema(data);
        }
      } catch (err) {
        console.error('Failed to load MQL schema:', err);
      }
    }

    loadSchema();

    return () => {
      cancelled = true;
    };
  }, []);

  // Load providers and types for autocomplete
  useEffect(() => {
    if (!currentState) return;

    const stateId = currentState.id; // Capture for closure

    async function loadMetadata() {
      try {
        const { data } = await executeMQL(resourceTypesQuery(stateId));
        const typesList = (data as ResourceTypeRow[]).map((r) => r.type);

        // Providers are derived client-side from the type prefix (e.g. "aws"
        // from "aws_instance") — same heuristic as before.
        const providersList = Array.from(
          new Set(typesList.map(t => t.split('_')[0]))
        ).filter(Boolean);

        setTypes(typesList);
        setProviders(providersList);
      } catch (err) {
        console.error('Failed to load autocomplete metadata:', err);
      }
    }

    loadMetadata();
  }, [currentState]);

  // Handle query input change with autocomplete
  const handleQueryChange = (e: React.ChangeEvent<HTMLTextAreaElement>) => {
    const newQuery = e.target.value;
    const newCursorPos = e.target.selectionStart || 0;

    setQuery(newQuery);
    setCursorPosition(newCursorPos);

    // Run real-time validation
    const validation = validateSQL(newQuery);
    setValidationResult(validation);

    // Get autocomplete suggestions
    const newSuggestions = getAutocompleteSuggestions({
      query: newQuery,
      cursorPosition: newCursorPos,
      providers,
      types,
      schema,
    });

    setSuggestions(newSuggestions);
    setSelectedSuggestionIndex(0);
  };

  // Handle cursor position changes (clicking in textarea)
  const handleCursorChange = () => {
    if (!textareaRef.current) return;

    const newCursorPos = textareaRef.current.selectionStart || 0;
    setCursorPosition(newCursorPos);

    // Update suggestions for new position
    const newSuggestions = getAutocompleteSuggestions({
      query,
      cursorPosition: newCursorPos,
      providers,
      types,
      schema,
    });

    setSuggestions(newSuggestions);
    setSelectedSuggestionIndex(0);
  };

  // Accept selected suggestion
  const acceptSuggestion = (suggestion: Suggestion) => {
    const { newQuery, newCursorPos } = applySuggestion(
      query,
      cursorPosition,
      suggestion.text
    );

    setQuery(newQuery);
    setCursorPosition(newCursorPos);
    setSuggestions([]);

    // Move cursor to new position
    setTimeout(() => {
      if (textareaRef.current) {
        textareaRef.current.selectionStart = newCursorPos;
        textareaRef.current.selectionEnd = newCursorPos;
        textareaRef.current.focus();
      }
    }, 0);
  };

  // Handle keyboard events for autocomplete navigation
  const handleKeyDown = (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
    // Handle autocomplete navigation
    if (suggestions.length > 0) {
      switch (e.key) {
        case 'ArrowDown':
          e.preventDefault();
          setSelectedSuggestionIndex((prev) =>
            prev < suggestions.length - 1 ? prev + 1 : 0
          );
          return;

        case 'ArrowUp':
          e.preventDefault();
          setSelectedSuggestionIndex((prev) =>
            prev > 0 ? prev - 1 : suggestions.length - 1
          );
          return;

        case 'Enter':
        case 'Tab':
          e.preventDefault();
          acceptSuggestion(suggestions[selectedSuggestionIndex]);
          return;

        case 'Escape':
          e.preventDefault();
          setSuggestions([]);
          return;
      }
    }

    // Handle global shortcuts
    if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') {
      e.preventDefault();
      executeQuery();
    }
  };

  // Close autocomplete and export menu when clicking outside
  useEffect(() => {
    const handleClickOutside = (e: MouseEvent) => {
      setSuggestions([]);
      if (exportMenuRef.current && !exportMenuRef.current.contains(e.target as Node)) {
        setShowExportMenu(false);
      }
    };

    document.addEventListener('click', handleClickOutside);
    return () => document.removeEventListener('click', handleClickOutside);
  }, []);

  // Render text with error highlighting
  const renderHighlightedText = (text: string, errors: ValidationError[]) => {
    if (errors.length === 0) {
      return <span className="text-transparent">{text}</span>;
    }

    // Create an array of segments with their error status
    const segments: { text: string; hasError: boolean }[] = [];
    let lastIndex = 0;

    // Sort errors by startIndex
    const sortedErrors = [...errors].sort((a, b) => a.startIndex - b.startIndex);

    for (const error of sortedErrors) {
      // Add text before error
      if (error.startIndex > lastIndex) {
        segments.push({
          text: text.substring(lastIndex, error.startIndex),
          hasError: false,
        });
      }

      // Add error text
      segments.push({
        text: text.substring(error.startIndex, error.endIndex),
        hasError: true,
      });

      lastIndex = error.endIndex;
    }

    // Add remaining text
    if (lastIndex < text.length) {
      segments.push({
        text: text.substring(lastIndex),
        hasError: false,
      });
    }

    return (
      <>
        {segments.map((segment, index) => (
          <span
            key={index}
            className="text-transparent"
            style={
              segment.hasError
                ? {
                    textDecoration: 'underline wavy',
                    textDecorationColor: 'var(--sg-error)',
                    textDecorationThickness: '2px',
                    textUnderlineOffset: '2px',
                  }
                : undefined
            }
          >
            {segment.text}
          </span>
        ))}
      </>
    );
  };

  return (
    <div className="flex h-full min-h-0 overflow-hidden">
      {/* Main Content */}
      <div className="flex-1 flex flex-col overflow-hidden min-w-0">
        {/* Header */}
        <PageHeader
          title="SQL Query Engine"
          subtitle="Query your Terraform state with SQL"
        >
          <div className="flex gap-2">
            <Button
              variant="default"
              size="sm"
              onClick={() => {
                setEditingQuery(undefined);
                setSaveDialogOpen(true);
              }}
              disabled={!query.trim()}
            >
              <Save className="h-4 w-4 mr-2" />
              Save Query
            </Button>
            <Button
              variant="outline"
              size="sm"
              onClick={() => setShowExamples(!showExamples)}
            >
              {showExamples ? <ChevronLeft className="h-4 w-4 mr-2" /> : <ChevronRight className="h-4 w-4 mr-2" />}
              {showExamples ? "Hide" : "Show"} Sidebar
            </Button>
          </div>
        </PageHeader>

        {/* Query Editor Section */}
        <div className="flex-shrink-0 px-4 py-3 border-b border-[var(--sg-border)] bg-[var(--sg-bg-0)]">
          <div className="space-y-2">
            {/* Textarea with Autocomplete and Error Highlighting */}
            <div className="relative">
              {/* Background layer */}
              <div className="absolute inset-0 bg-[var(--sg-bg-1)] rounded-lg pointer-events-none" />

              {/* Error highlighting overlay */}
              <div
                className="absolute inset-0 px-4 py-2 font-mono text-sm pointer-events-none overflow-hidden rounded-lg"
                style={{
                  whiteSpace: 'pre-wrap',
                  wordWrap: 'break-word',
                  lineHeight: '1.5',
                  color: 'transparent',
                }}
              >
                {renderHighlightedText(query, validationResult.errors)}
              </div>

              {/* Actual textarea */}
              <textarea
                ref={textareaRef}
                value={query}
                onChange={handleQueryChange}
                onKeyDown={handleKeyDown}
                onClick={handleCursorChange}
                onSelect={handleCursorChange}
                placeholder="select * from instances limit 10"
                className={`relative w-full h-20 px-4 py-2 font-mono text-sm bg-transparent border rounded-lg text-[var(--sg-text)] resize-y focus:outline-none focus:ring-2 transition-colors ${
                  validationResult.hasFatalErrors
                    ? 'border-[var(--sg-error)] focus:ring-[var(--sg-error)]'
                    : 'border-[var(--sg-border)] focus:ring-[var(--sg-accent)] focus:border-transparent'
                }`}
                style={{
                  lineHeight: '1.5',
                  minHeight: '52px',
                }}
              />

              {/* Autocomplete Dropdown */}
              {suggestions.length > 0 && (
                <div
                  className="absolute z-50 mt-1 max-h-60 overflow-y-auto bg-[var(--sg-bg-2)] border border-[var(--sg-border)] rounded-lg shadow-lg"
                  style={{
                    top: '100%',
                    left: '16px',
                    minWidth: '200px',
                    maxWidth: '400px',
                  }}
                  onClick={(e) => e.stopPropagation()}
                >
                  {suggestions.map((suggestion, index) => (
                    <button
                      key={index}
                      onClick={() => acceptSuggestion(suggestion)}
                      className={`w-full px-3 py-2 text-left text-sm font-mono hover:bg-[var(--sg-bg-1)] transition-colors ${
                        index === selectedSuggestionIndex
                          ? 'bg-[var(--sg-accent-bg)] text-[var(--sg-accent)]'
                          : 'text-[var(--sg-text)]'
                      }`}
                    >
                      <div className="flex items-center justify-between gap-2">
                        <span className="truncate">{suggestion.text}</span>
                        {suggestion.type && (
                          <span
                            className={`text-xs px-1.5 py-0.5 rounded ${
                              suggestion.type === 'keyword'
                                ? 'bg-blue-500/20 text-blue-400'
                                : suggestion.type === 'field'
                                ? 'bg-green-500/20 text-green-400'
                                : suggestion.type === 'value'
                                ? 'bg-purple-500/20 text-purple-400'
                                : 'bg-orange-500/20 text-orange-400'
                            }`}
                          >
                            {suggestion.type}
                          </span>
                        )}
                      </div>
                      {suggestion.description && (
                        <div className="text-xs text-[var(--sg-text-dim)] mt-1 truncate">
                          {suggestion.description}
                        </div>
                      )}
                    </button>
                  ))}
                </div>
              )}
            </div>

            {/* Validation Errors */}
            {validationResult.errors.length > 0 && (
              <div className="space-y-2">
                {validationResult.errors.map((error, index) => (
                  <div
                    key={index}
                    className={`flex items-start gap-2 px-3 py-2 rounded-lg text-sm ${
                      error.severity === 'error'
                        ? 'bg-[var(--sg-error)]/10 border border-[var(--sg-error)]/30'
                        : 'bg-[var(--sg-warning)]/10 border border-[var(--sg-warning)]/30'
                    }`}
                  >
                    <AlertCircle
                      className={`w-4 h-4 mt-0.5 flex-shrink-0 ${
                        error.severity === 'error' ? 'text-[var(--sg-error)]' : 'text-[var(--sg-warning)]'
                      }`}
                    />
                    <div className="flex-1">
                      <div
                        className={`font-medium ${
                          error.severity === 'error' ? 'text-[var(--sg-error)]' : 'text-[var(--sg-warning)]'
                        }`}
                      >
                        {error.message}
                      </div>
                      {error.startIndex !== undefined && (
                        <div className="text-xs text-[var(--sg-text-dim)] mt-0.5">
                          Position: {error.startIndex}-{error.endIndex}
                        </div>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            )}

            {/* Actions */}
            <div className="flex flex-wrap items-center justify-between gap-2">
              <div className="flex flex-wrap items-center gap-2">
                <Button
                  size="sm"
                  onClick={executeQuery}
                  disabled={loading || validationResult.hasFatalErrors}
                  title={validationResult.hasFatalErrors ? "Fix errors before running" : "Ctrl+Enter"}
                >
                  <Play className="h-4 w-4 mr-1" />
                  {loading ? "Running..." : "Run"}
                </Button>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => {
                    navigator.clipboard.writeText(query);
                  }}
                  title="Copy query to clipboard"
                >
                  <Copy className="h-4 w-4" />
                </Button>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => {
                    const url = new URL(window.location.origin + "/query");
                    url.searchParams.set("q", query);
                    if (currentTenant) {
                      url.searchParams.set("tenant", currentTenant.id);
                    }
                    navigator.clipboard.writeText(url.toString());
                    setShareCopied(true);
                    setTimeout(() => setShareCopied(false), 2000);
                  }}
                  title="Copy shareable link to clipboard"
                  disabled={!query.trim()}
                >
                  <Share2 className="h-4 w-4" />
                  {shareCopied && <span className="ml-1 text-xs">Copied!</span>}
                </Button>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => {
                    setQuery("");
                  }}
                  title="Clear query"
                >
                  <Trash2 className="h-4 w-4" />
                </Button>

                {/* Stats inline */}
                {executionTime !== null && !loading && (
                  <span className="text-xs text-[var(--sg-text-dim)] ml-2">
                    {results.length} rows in {executionTime.toFixed(0)}ms
                  </span>
                )}
              </div>

              <span className="hidden text-xs text-[var(--sg-text-dim)] sm:inline">
                <kbd className="px-1 py-0.5 bg-[var(--sg-bg-2)] border border-[var(--sg-border)] rounded text-[10px]">Ctrl+Enter</kbd> to run
              </span>
            </div>
          </div>
        </div>

        {/* Error Display */}
        {error && (
          <div className="mx-6 mt-4 p-4 bg-[var(--sg-error)]/10 border border-[var(--sg-error)] rounded-lg">
            <div className="sg-secondary-header text-[var(--sg-error)] mb-1">Query Error</div>
            <div className="sg-metadata text-[var(--sg-error)]">{error.message}</div>
            {(error.errorId || error.detail) && (
              <details className="mt-2 pt-2 border-t border-[var(--sg-error)]/20">
                <summary className="text-xs font-medium text-[var(--sg-error)]/70 cursor-pointer select-none">
                  Show details
                </summary>
                <div className="mt-2">
                  {error.errorId && (
                    <div className="flex items-center gap-2">
                      <span className="text-xs font-medium text-[var(--sg-error)]/70">Error ID:</span>
                      <code className="text-xs font-mono bg-[var(--sg-error)]/10 px-1.5 py-0.5 rounded text-[var(--sg-error)]">
                        {error.errorId}
                      </code>
                    </div>
                  )}
                  {error.detail && (
                    <pre className="mt-1.5 text-xs font-mono bg-[var(--sg-bg-1)] p-2 rounded border border-[var(--sg-border)] text-[var(--sg-text-muted)] whitespace-pre-wrap break-all">
                      {error.detail}
                    </pre>
                  )}
                </div>
              </details>
            )}
          </div>
        )}

        {/* Results */}
        {results.length > 0 && (
          <div className="flex-1 flex flex-col overflow-hidden">
            {/* Results Toolbar */}
            <div className="flex-shrink-0 px-4 py-2 border-b border-[var(--sg-border)] bg-[var(--sg-bg-0)]">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2 text-xs text-[var(--sg-text-muted)]">
                  <span className="font-semibold text-[var(--sg-text)]">{results.length}</span> {results.length === 1 ? 'row' : 'rows'}
                </div>
                <div className="flex gap-1">
                  {results.length > 0 && (
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={() => setShowVisualization(true)}
                      title="Visualize results as a chart"
                      className="h-7 text-xs"
                    >
                      <BarChart3 className="h-3.5 w-3.5 mr-1" />
                      Visualize
                    </Button>
                  )}
                  <div className="relative" ref={exportMenuRef}>
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={() => setShowExportMenu(!showExportMenu)}
                      title="Export results"
                      className="h-7 text-xs"
                    >
                      <Download className="h-3.5 w-3.5 mr-1" />
                      Export
                    </Button>
                    {showExportMenu && (
                      <div className="absolute right-0 top-full mt-1 z-50 bg-[var(--sg-bg-2)] border border-[var(--sg-border)] rounded-lg shadow-lg overflow-hidden">
                        <button
                          onClick={() => { handleExportCSV(); setShowExportMenu(false); }}
                          className="flex items-center gap-2 w-full px-3 py-2 text-xs text-[var(--sg-text)] hover:bg-[var(--sg-bg-1)] transition-colors"
                        >
                          <FileText className="h-3.5 w-3.5 text-[var(--sg-text-muted)]" />
                          CSV
                        </button>
                        <button
                          onClick={() => { handleExportJSON(); setShowExportMenu(false); }}
                          className="flex items-center gap-2 w-full px-3 py-2 text-xs text-[var(--sg-text)] hover:bg-[var(--sg-bg-1)] transition-colors"
                        >
                          <FileJson className="h-3.5 w-3.5 text-[var(--sg-text-muted)]" />
                          JSON
                        </button>
                      </div>
                    )}
                  </div>
                </div>
              </div>
            </div>

            {/* Results Content */}
            <QueryResultsViewer
              results={results as Record<string, unknown>[]}
              query={query}
              onLoadMore={nextPageCursor ? loadMoreResults : undefined}
              isLoadingMore={loadingMore}
              hasMore={!!nextPageCursor}
              paginationHint={paginationHint}
            />
          </div>
        )}

        {/* Empty State */}
        {!loading && results.length === 0 && !error && executionTime !== null && (
          <div className="flex-1 flex items-center justify-center">
            <div className="text-center max-w-md">
              <div className="text-lg font-semibold mb-2 text-[var(--sg-text)]">No Results</div>
              <div className="text-sm text-[var(--sg-text-muted)]">
                Your query returned no resources. Try adjusting your WHERE conditions.
              </div>
            </div>
          </div>
        )}

        {/* Initial State */}
        {results.length === 0 && executionTime === null && !error && (
          <div className="flex-1 flex items-center justify-center">
            <div className="text-center max-w-md">
              <div className="text-lg font-semibold mb-2 text-[var(--sg-text)]">Ready to Query</div>
              <div className="text-sm text-[var(--sg-text-muted)] mb-4">
                Write a SQL query above and click &ldquo;Run Query&rdquo; to explore your infrastructure.
              </div>
              <div className="text-xs text-[var(--sg-text-dim)]">
                SQL supports: SELECT, JOIN, WHERE, GROUP BY, ORDER BY, LIMIT, and more
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Sidebar with Examples and History */}
      {showExamples && (
        <>
          {/* Mobile backdrop — tap to dismiss the sidebar sheet */}
          <div
            className="fixed inset-0 z-30 bg-black/50 lg:hidden"
            onClick={() => setShowExamples(false)}
          />
          <div
            className="fixed inset-y-0 right-0 z-40 w-[85%] max-w-[380px] flex-shrink-0 border-l border-[var(--sg-border)] bg-[var(--sg-bg-1)] overflow-hidden flex flex-col lg:static lg:z-auto lg:w-[380px] lg:max-w-none"
          >
          {/* Tab Headers */}
          <div className="flex border-b border-[var(--sg-border)] bg-[var(--sg-bg-0)]">
            <button
              onClick={() => setSidebarTab('examples')}
              className={`flex-1 px-2 py-3 text-xs font-medium transition-colors ${
                sidebarTab === 'examples'
                  ? 'text-[var(--sg-accent)] border-b-2 border-[var(--sg-accent)]'
                  : 'text-[var(--sg-text-muted)] hover:text-[var(--sg-text)]'
              }`}
              title="Example queries"
            >
              Examples
            </button>
            <button
              onClick={() => setSidebarTab('saved')}
              className={`flex-1 px-2 py-3 text-xs font-medium transition-colors relative ${
                sidebarTab === 'saved'
                  ? 'text-[var(--sg-accent)] border-b-2 border-[var(--sg-accent)]'
                  : 'text-[var(--sg-text-muted)} hover:text-[var(--sg-text)]'
              }`}
              title="Saved queries"
            >
              Saved
              {savedQueries.length > 0 && (
                <span className="ml-1 px-1 py-0.5 text-[9px] rounded-full bg-[var(--sg-accent)]/20 text-[var(--sg-accent)]">
                  {savedQueries.length}
                </span>
              )}
            </button>
            <button
              onClick={() => setSidebarTab('history')}
              className={`flex-1 px-2 py-3 text-xs font-medium transition-colors relative ${
                sidebarTab === 'history'
                  ? 'text-[var(--sg-accent)] border-b-2 border-[var(--sg-accent)]'
                  : 'text-[var(--sg-text-muted)] hover:text-[var(--sg-text)]'
              }`}
              title="Query history"
            >
              History
              {history.length > 0 && (
                <span className="ml-1 px-1 py-0.5 text-[9px] rounded-full bg-[var(--sg-accent)]/20 text-[var(--sg-accent)]">
                  {history.length}
                </span>
              )}
            </button>
            <button
              onClick={() => setSidebarTab('visualizations')}
              className={`flex-1 px-2 py-3 text-xs font-medium transition-colors relative ${
                sidebarTab === 'visualizations'
                  ? 'text-[var(--sg-accent)] border-b-2 border-[var(--sg-accent)]'
                  : 'text-[var(--sg-text-muted)] hover:text-[var(--sg-text)]'
              }`}
              title="Saved charts"
            >
              Charts
              {visualizations.length > 0 && (
                <span className="ml-1 px-1 py-0.5 text-[9px] rounded-full bg-[var(--sg-accent)]/20 text-[var(--sg-accent)]">
                  {visualizations.length}
                </span>
              )}
            </button>
            <button
              onClick={() => setSidebarTab('schema')}
              className={`flex-1 px-2 py-3 text-xs font-medium transition-colors ${
                sidebarTab === 'schema'
                  ? 'text-[var(--sg-accent)] border-b-2 border-[var(--sg-accent)]'
                  : 'text-[var(--sg-text-muted)] hover:text-[var(--sg-text)]'
              }`}
              title="SQL schema reference"
            >
              Schema
            </button>
          </div>

          {/* Tab Content */}
          <div className="flex-1 overflow-y-auto p-4">
            {sidebarTab === 'examples' ? (
              <>
                <p className="text-xs text-[var(--sg-text-dim)] mb-4">
                  Click any snippet to load it into the editor
                </p>

                <div className="space-y-5">
                  {EXAMPLE_QUERY_GROUPS.map((group) => (
                    <div key={group.category}>
                      <div className="text-[10px] font-semibold uppercase tracking-wider text-[var(--sg-text-muted)] mb-2">
                        {group.category}
                      </div>
                      <div className="space-y-1.5">
                        {group.queries.map((example, index) => (
                          <button
                            key={index}
                            onClick={() => loadExample(example.sql)}
                            className="w-full text-left p-2.5 rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-0)] hover:bg-[var(--sg-bg-2)] hover:border-[var(--sg-accent)] transition-colors duration-200"
                          >
                            <div className="text-xs font-medium text-[var(--sg-text)] mb-1.5">
                              {example.label}
                            </div>
                            <pre className="text-[10px] font-mono text-[var(--sg-text-dim)] whitespace-pre-wrap break-all">
                              {example.sql}
                            </pre>
                          </button>
                        ))}
                      </div>
                    </div>
                  ))}
                </div>

                {/* Syntax Help */}
                <div className="mt-6 p-3 rounded-lg bg-[var(--sg-bg-0)] border border-[var(--sg-border)]">
                  <h4 className="text-xs font-semibold text-[var(--sg-text)] mb-2">SQL Syntax</h4>
                  <ul className="text-[10px] text-[var(--sg-text-dim)] space-y-1">
                    <li>• SELECT with projections</li>
                    <li>• JOIN operations</li>
                    <li>• WHERE with comparisons, IN, LIKE</li>
                    <li>• GROUP BY for aggregations</li>
                    <li>• ORDER BY for sorting</li>
                    <li>• LIMIT for pagination</li>
                    <li>• JSON operators (-&gt;, -&gt;&gt;)</li>
                    <li>• Type casts with ::</li>
                  </ul>
                </div>
              </>
            ) : sidebarTab === 'saved' ? (
              <>
                {/* Saved Queries */}
                <p className="text-xs text-[var(--sg-text-dim)] mb-4">
                  Click to load, edit or delete saved queries
                </p>

                {savedQueries.length === 0 ? (
                  <div className="text-center py-8">
                    <Bookmark className="w-8 h-8 mx-auto mb-2 opacity-30" style={{ color: 'var(--sg-text-muted)' }} />
                    <div className="text-xs text-[var(--sg-text-dim)]">
                      No saved queries yet
                    </div>
                    <div className="text-[10px] text-[var(--sg-text-dim)] mt-1">
                      Click &ldquo;Save Query&rdquo; to save your first query
                    </div>
                  </div>
                ) : (
                  <div className="space-y-2">
                    {savedQueries.map((saved) => (
                      <div
                        key={saved.id}
                        className="group relative p-3 rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-0)] hover:bg-[var(--sg-bg-2)] hover:border-[var(--sg-accent)] transition-colors duration-200"
                      >
                        <button
                          onClick={() => handleLoadSavedQuery(saved.query)}
                          className="w-full text-left"
                        >
                          <div className="text-xs font-medium text-[var(--sg-text)] mb-1">
                            {saved.name}
                          </div>
                          {saved.description && (
                            <div className="text-[10px] text-[var(--sg-text-dim)] mb-2">
                              {saved.description}
                            </div>
                          )}
                          <pre className="text-[10px] font-mono text-[var(--sg-text-muted)] whitespace-pre-wrap break-all">
                            {saved.query}
                          </pre>
                        </button>
                        <div className="absolute top-2 right-2 flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                          <button
                            onClick={(e) => {
                              e.stopPropagation();
                              setEditingQuery({
                                id: saved.id,
                                name: saved.name,
                                description: saved.description,
                              });
                              setQuery(saved.query);
                              setSaveDialogOpen(true);
                            }}
                            className="p-1 rounded hover:bg-[var(--sg-accent)]/10 transition-colors"
                            title="Edit this query"
                          >
                            <Edit className="w-3 h-3 text-[var(--sg-accent)]" />
                          </button>
                          <button
                            onClick={(e) => {
                              e.stopPropagation();
                              if (confirm(`Delete "${saved.name}"?`)) {
                                deleteQuery(saved.id);
                              }
                            }}
                            className="p-1 rounded hover:bg-[var(--sg-error)]/10 transition-colors"
                            title="Delete this query"
                          >
                            <X className="w-3 h-3 text-[var(--sg-error)]" />
                          </button>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </>
            ) : sidebarTab === 'history' ? (
              <>
                {/* Recent Queries */}
                <div className="flex items-center justify-between mb-4">
                  <p className="text-xs text-[var(--sg-text-dim)]">
                    Click to load, or delete individual queries
                  </p>
                  {history.length > 0 && (
                    <button
                      onClick={clearHistory}
                      className="text-xs text-[var(--sg-text-dim)] hover:text-[var(--sg-error)] transition-colors"
                    >
                      Clear All
                    </button>
                  )}
                </div>

                {history.length === 0 ? (
                  <div className="text-center py-8">
                    <Clock className="w-8 h-8 mx-auto mb-2 opacity-30" style={{ color: 'var(--sg-text-muted)' }} />
                    <div className="text-xs text-[var(--sg-text-dim)]">
                      No query history yet
                    </div>
                    <div className="text-[10px] text-[var(--sg-text-dim)] mt-1">
                      Run a query to see it here
                    </div>
                  </div>
                ) : (
                  <div className="space-y-2">
                    {history.map((entry) => (
                      <div
                        key={entry.id}
                        className="group relative p-3 rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-0)] hover:bg-[var(--sg-bg-2)] hover:border-[var(--sg-accent)] transition-colors duration-200"
                      >
                        <button
                          onClick={() => loadExample(entry.query)}
                          className="w-full text-left"
                        >
                          <pre className="text-[10px] font-mono text-[var(--sg-text)] whitespace-pre-wrap break-all mb-2">
                            {entry.query}
                          </pre>
                          <div className="flex items-center gap-2 text-[10px] text-[var(--sg-text-dim)]">
                            <Clock className="w-3 h-3" />
                            <span>
                              {new Date(entry.timestamp).toLocaleTimeString()}
                            </span>
                            {entry.executionTime !== undefined && (
                              <>
                                <span>•</span>
                                <span>{entry.executionTime.toFixed(0)}ms</span>
                              </>
                            )}
                            {entry.resultCount !== undefined && (
                              <>
                                <span>•</span>
                                <span>{entry.resultCount} rows</span>
                              </>
                            )}
                          </div>
                        </button>
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            removeFromHistory(entry.id);
                          }}
                          className="absolute top-2 right-2 p-1 rounded opacity-0 group-hover:opacity-100 hover:bg-[var(--sg-error)]/10 transition-opacity"
                          title="Delete this query"
                        >
                          <X className="w-3 h-3 text-[var(--sg-error)]" />
                        </button>
                      </div>
                    ))}
                  </div>
                )}
              </>
            ) : sidebarTab === 'visualizations' ? (
              <>
                {/* Saved Visualizations */}
                <p className="text-xs text-[var(--sg-text-dim)] mb-4">
                  Saved charts and visualizations
                </p>

                <SavedVisualizationsList
                  visualizations={visualizations}
                  onLoad={handleLoadVisualization}
                  onRename={handleRenameVisualization}
                  onDelete={handleDeleteVisualization}
                />
              </>
            ) : sidebarTab === 'schema' ? (
              <div className="h-full -m-4">
                <SchemaBrowser
                  onTableClick={(tableName) => {
                    // Insert table name at cursor
                    const textarea = document.querySelector('textarea');
                    if (textarea) {
                      const start = textarea.selectionStart;
                      const end = textarea.selectionEnd;
                      const newQuery = query.substring(0, start) + tableName + query.substring(end);
                      setQuery(newQuery);
                      // Focus and set cursor after inserted text
                      setTimeout(() => {
                        textarea.focus();
                        textarea.setSelectionRange(start + tableName.length, start + tableName.length);
                      }, 0);
                    }
                  }}
                  onColumnClick={(tableName, columnName) => {
                    // Insert column name at cursor
                    const textarea = document.querySelector('textarea');
                    if (textarea) {
                      const start = textarea.selectionStart;
                      const end = textarea.selectionEnd;
                      const newQuery = query.substring(0, start) + columnName + query.substring(end);
                      setQuery(newQuery);
                      // Focus and set cursor after inserted text
                      setTimeout(() => {
                        textarea.focus();
                        textarea.setSelectionRange(start + columnName.length, start + columnName.length);
                      }, 0);
                    }
                  }}
                />
              </div>
            ) : null}
          </div>
          </div>
        </>
      )}

      {/* Save Query Dialog */}
      <SaveQueryDialog
        open={saveDialogOpen}
        onOpenChange={setSaveDialogOpen}
        currentQuery={query}
        onSave={handleSaveQuery}
        editingQuery={editingQuery}
      />

      {/* Visualization Modal */}
      {showVisualization && (
        <VisualizationModal
          results={results as Record<string, unknown>[]}
          query={query}
          onClose={() => setShowVisualization(false)}
          onSave={handleSaveVisualization}
        />
      )}
    </div>
  );
}
