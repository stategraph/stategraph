"use client";

import { X, ChevronDown, ChevronRight, Info } from "lucide-react";
import { Button } from "@/components/ui/button";
import { useState } from "react";
import type { ParsedQuery } from "./compiler";

interface ExplainPanelProps {
  query: string;
  parsedQuery: ParsedQuery | null;
  compilationError: string | null;
  stateId: string | null;
  onClose: () => void;
}

interface SectionProps {
  title: string;
  children: React.ReactNode;
  defaultOpen?: boolean;
}

function CollapsibleSection({ title, children, defaultOpen = true }: SectionProps) {
  const [isOpen, setIsOpen] = useState(defaultOpen);

  return (
    <div className="border border-[var(--sg-border)] rounded-lg overflow-hidden bg-[var(--sg-bg-1)]">
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="w-full flex items-center justify-between px-4 py-3 bg-[var(--sg-bg-2)] hover:bg-[var(--sg-bg-1)] transition-colors"
      >
        <span className="text-sm font-semibold text-[var(--sg-text)]">{title}</span>
        {isOpen ? (
          <ChevronDown className="w-4 h-4 text-[var(--sg-text-muted)]" />
        ) : (
          <ChevronRight className="w-4 h-4 text-[var(--sg-text-muted)]" />
        )}
      </button>
      {isOpen && <div className="p-4">{children}</div>}
    </div>
  );
}

export function ExplainPanel({
  query,
  parsedQuery,
  compilationError,
  stateId,
  onClose,
}: ExplainPanelProps) {
  // Build API URL preview
  const apiUrl = stateId && parsedQuery
    ? `/api/v1/states/${stateId}/instances${parsedQuery.qString ? `?q=${encodeURIComponent(parsedQuery.qString)}` : ''}&limit=1000`
    : null;

  return (
    <div className="fixed bottom-0 left-0 right-0 z-40 border-t border-[var(--sg-border)] bg-[var(--sg-bg-0)] shadow-lg">
      <div className="max-h-[60vh] overflow-y-auto">
        {/* Header */}
        <div className="sticky top-0 bg-[var(--sg-bg-0)] border-b border-[var(--sg-border)] px-6 py-3 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Info className="w-5 h-5 text-[var(--sg-accent)]" />
            <h3 className="text-base font-semibold text-[var(--sg-text)]">Query Explanation</h3>
          </div>
          <Button variant="ghost" size="sm" onClick={onClose}>
            <X className="w-4 h-4" />
          </Button>
        </div>

        {/* Content */}
        <div className="px-6 py-4 space-y-4">
          {/* Original Query */}
          <CollapsibleSection title="Original SQL Query">
            <pre className="text-xs font-mono text-[var(--sg-text)] bg-[var(--sg-bg-2)] p-3 rounded border border-[var(--sg-border)] overflow-x-auto">
              {query || '(empty)'}
            </pre>
          </CollapsibleSection>

          {/* Compilation Error */}
          {compilationError && (
            <CollapsibleSection title="Compilation Error" defaultOpen={true}>
              <div className="bg-[var(--sg-error)]/10 border border-[var(--sg-error)]/30 rounded p-3">
                <div className="text-sm text-[var(--sg-error)]">{compilationError}</div>
              </div>
            </CollapsibleSection>
          )}

          {/* Parsed Structure */}
          {parsedQuery && (
            <>
              {/* SELECT Clause */}
              <CollapsibleSection title="SELECT Clause">
                {parsedQuery.aggregation ? (
                  <div className="space-y-2">
                    <div className="text-sm text-[var(--sg-text-muted)]">
                      <span className="font-semibold text-[var(--sg-text)]">Type:</span> Aggregation
                    </div>
                    <div className="bg-[var(--sg-bg-2)] p-3 rounded border border-[var(--sg-border)]">
                      <div className="text-xs font-mono text-[var(--sg-accent)]">
                        {parsedQuery.aggregation.type}({parsedQuery.aggregation.field})
                      </div>
                    </div>
                    <div className="text-xs text-[var(--sg-text-dim)] mt-2">
                      <Info className="w-3 h-3 inline mr-1" />
                      Aggregation computed client-side after fetching filtered instances.
                    </div>
                  </div>
                ) : (
                  <div className="space-y-2">
                    <div className="text-sm text-[var(--sg-text-muted)]">
                      <span className="font-semibold text-[var(--sg-text)]">Fields:</span>
                    </div>
                    <div className="flex flex-wrap gap-2">
                      {parsedQuery.select.map((field, idx) => (
                        <span
                          key={idx}
                          className="px-2 py-1 text-xs font-mono bg-[var(--sg-accent-bg)] text-[var(--sg-accent)] border border-[var(--sg-accent)]/20 rounded"
                        >
                          {field}
                        </span>
                      ))}
                    </div>
                    {parsedQuery.select.includes('*') && (
                      <div className="text-xs text-[var(--sg-text-dim)] mt-2">
                        <Info className="w-3 h-3 inline mr-1" />
                        All fields will be returned from the API.
                      </div>
                    )}
                  </div>
                )}
              </CollapsibleSection>

              {/* FROM Clause */}
              <CollapsibleSection title="FROM Clause">
                <div className="bg-[var(--sg-bg-2)] p-3 rounded border border-[var(--sg-border)]">
                  <div className="text-xs font-mono text-[var(--sg-accent)]">{parsedQuery.from}</div>
                </div>
              </CollapsibleSection>

              {/* WHERE Clause */}
              <CollapsibleSection title="WHERE Clause">
                {parsedQuery.where.length > 0 ? (
                  <div className="space-y-3">
                    {parsedQuery.where.map((condition, idx) => (
                      <div
                        key={idx}
                        className="bg-[var(--sg-bg-2)] p-3 rounded border border-[var(--sg-border)]"
                      >
                        <div className="flex items-center gap-2 text-xs">
                          <span className="font-mono text-[var(--sg-accent)]">{condition.field}</span>
                          <span className="text-[var(--sg-text-muted)]">{condition.operator}</span>
                          <span className="font-mono text-[var(--sg-text)]">
                            {Array.isArray(condition.value)
                              ? `(${condition.value.join(', ')})`
                              : `'${condition.value}'`}
                          </span>
                        </div>
                      </div>
                    ))}
                    <div className="text-xs text-[var(--sg-text-dim)]">
                      <Info className="w-3 h-3 inline mr-1" />
                      Conditions combined with logical AND.
                    </div>
                  </div>
                ) : (
                  <div className="text-sm text-[var(--sg-text-muted)] italic">No filters applied</div>
                )}
              </CollapsibleSection>

              {/* Q-String Translation */}
              <CollapsibleSection title="Q-String Translation">
                {parsedQuery.qString ? (
                  <div className="space-y-2">
                    <div className="bg-[var(--sg-bg-2)] p-3 rounded border border-[var(--sg-border)]">
                      <div className="text-xs font-mono text-[var(--sg-text)]">{parsedQuery.qString}</div>
                    </div>
                    <div className="text-xs text-[var(--sg-text-dim)]">
                      <Info className="w-3 h-3 inline mr-1" />
                      This q-string is sent to the Instances API as a query parameter.
                    </div>
                  </div>
                ) : (
                  <div className="text-sm text-[var(--sg-text-muted)] italic">
                    No q-string (fetching all instances)
                  </div>
                )}
              </CollapsibleSection>

              {/* API Request Preview */}
              <CollapsibleSection title="API Request Preview">
                {apiUrl ? (
                  <div className="space-y-3">
                    <div>
                      <div className="text-xs text-[var(--sg-text-muted)] mb-1">Method:</div>
                      <div className="bg-[var(--sg-bg-2)] px-3 py-2 rounded border border-[var(--sg-border)]">
                        <span className="text-xs font-mono text-green-400">GET</span>
                      </div>
                    </div>
                    <div>
                      <div className="text-xs text-[var(--sg-text-muted)] mb-1">Endpoint:</div>
                      <div className="bg-[var(--sg-bg-2)] p-3 rounded border border-[var(--sg-border)]">
                        <code className="text-xs font-mono text-[var(--sg-text)] break-all">
                          {apiUrl}
                        </code>
                      </div>
                    </div>
                    <div className="text-xs text-[var(--sg-text-dim)]">
                      <Info className="w-3 h-3 inline mr-1" />
                      This API call will fetch up to 1000 instances matching the filters.
                    </div>
                  </div>
                ) : (
                  <div className="text-sm text-[var(--sg-text-muted)] italic">
                    No state selected - select a state to see API preview
                  </div>
                )}
              </CollapsibleSection>

              {/* Execution Flow */}
              <CollapsibleSection title="Execution Flow" defaultOpen={false}>
                <div className="space-y-2">
                  <div className="flex items-start gap-3">
                    <div className="flex-shrink-0 w-6 h-6 rounded-full bg-[var(--sg-accent)]/20 text-[var(--sg-accent)] flex items-center justify-center text-xs font-semibold">
                      1
                    </div>
                    <div className="text-sm text-[var(--sg-text)]">
                      Parse SQL query into structured format
                    </div>
                  </div>
                  <div className="flex items-start gap-3">
                    <div className="flex-shrink-0 w-6 h-6 rounded-full bg-[var(--sg-accent)]/20 text-[var(--sg-accent)] flex items-center justify-center text-xs font-semibold">
                      2
                    </div>
                    <div className="text-sm text-[var(--sg-text)]">
                      Translate WHERE clause to q-string format
                    </div>
                  </div>
                  <div className="flex items-start gap-3">
                    <div className="flex-shrink-0 w-6 h-6 rounded-full bg-[var(--sg-accent)]/20 text-[var(--sg-accent)] flex items-center justify-center text-xs font-semibold">
                      3
                    </div>
                    <div className="text-sm text-[var(--sg-text)]">
                      Fetch filtered instances from API
                    </div>
                  </div>
                  <div className="flex items-start gap-3">
                    <div className="flex-shrink-0 w-6 h-6 rounded-full bg-[var(--sg-accent)]/20 text-[var(--sg-accent)] flex items-center justify-center text-xs font-semibold">
                      4
                    </div>
                    <div className="text-sm text-[var(--sg-text)]">
                      {parsedQuery.aggregation
                        ? 'Compute aggregation client-side'
                        : 'Apply field projection client-side'}
                    </div>
                  </div>
                  <div className="flex items-start gap-3">
                    <div className="flex-shrink-0 w-6 h-6 rounded-full bg-[var(--sg-accent)]/20 text-[var(--sg-accent)] flex items-center justify-center text-xs font-semibold">
                      5
                    </div>
                    <div className="text-sm text-[var(--sg-text)]">Display results in table</div>
                  </div>
                </div>
              </CollapsibleSection>
            </>
          )}

          {/* Help Text */}
          {!parsedQuery && !compilationError && (
            <div className="text-center py-8 text-sm text-[var(--sg-text-muted)]">
              Write a query above and click &ldquo;Explain Query&rdquo; to see how it will be executed.
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
