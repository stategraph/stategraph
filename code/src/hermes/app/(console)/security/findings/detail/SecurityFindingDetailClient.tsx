"use client";

import { useEffect, useMemo, useState, type ReactNode } from "react";
import { useSearchParams } from "next/navigation";
import { ArrowLeft, ExternalLink, Globe } from "lucide-react";

import { DeepLink } from "@/components/navigation";
import { Button } from "@/components/ui/button";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card";
import { SecurityDisabledNotice, SeverityBadge } from "@/components/security";
import { useStates } from "@/contexts";
import { useDeepLinkRouter, useSecurityAvailability } from "@/hooks";
import {
  getStateSecurityFindings,
  type SecurityFinding,
  type SecurityScan,
} from "@/lib/api/client";
import { capitalize } from "@/lib/utils";

// The findings list isn't paginated in the UI; fetch enough to locate any
// finding the user clicked through from it.
const FETCH_LIMIT = 1000;

function formatTimestamp(timestamp?: string): string {
  if (!timestamp) return "—";
  return new Date(timestamp).toLocaleString("en-US", {
    year: "numeric",
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

function Field({
  label,
  children,
  wide = false,
}: {
  label: string;
  children: ReactNode;
  wide?: boolean;
}) {
  return (
    <div className={wide ? "col-span-2" : undefined}>
      <div className="text-sm text-[var(--sg-text-dim)] mb-1">{label}</div>
      <div className="text-sm font-medium break-words">{children}</div>
    </div>
  );
}

export function SecurityFindingDetailClient() {
  const router = useDeepLinkRouter();
  const searchParams = useSearchParams();
  const stateId = searchParams.get("state") || "";
  const fingerprint = searchParams.get("fingerprint") || "";

  const { states } = useStates();
  const { capability, isLoading: securityLoading } = useSecurityAvailability();

  const [finding, setFinding] = useState<SecurityFinding | null>(null);
  const [scan, setScan] = useState<SecurityScan | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Missing params -> back to the list.
  useEffect(() => {
    if (!stateId || !fingerprint) router.push("/security/findings");
  }, [stateId, fingerprint, router]);

  useEffect(() => {
    if (!stateId || !fingerprint) return;
    let cancelled = false;
    async function load(id: string) {
      setLoading(true);
      setError(null);
      try {
        const res = await getStateSecurityFindings(id, { limit: FETCH_LIMIT });
        if (cancelled) return;
        setFinding(res.findings.find((f) => f.fingerprint === fingerprint) ?? null);
        setScan(res.scan ?? null);
      } catch (e: unknown) {
        if (cancelled) return;
        setError(e instanceof Error ? e.message : "Failed to load finding");
      } finally {
        if (!cancelled) setLoading(false);
      }
    }
    load(stateId);
    return () => {
      cancelled = true;
    };
  }, [stateId, fingerprint]);

  const stateName = useMemo(
    () => states.find((s) => s.id === stateId)?.name ?? stateId,
    [states, stateId]
  );

  const securitySupported = !securityLoading && capability?.enabled === true;
  if (!securityLoading && !securitySupported) {
    return <SecurityDisabledNotice />;
  }

  const modules = (finding?.blast_radius_modules ?? []).map((m) => (m === "" ? "(root)" : m));
  const evidence = finding?.internet_reachability_evidence;
  const hasEvidence = evidence !== undefined && evidence !== null;
  const sourceLocation =
    finding?.source_file != null
      ? `${finding.source_file}${
          finding.source_start_line != null
            ? `:${finding.source_start_line}${
                finding.source_end_line != null ? `-${finding.source_end_line}` : ""
              }`
            : ""
        }`
      : null;

  return (
    <div className="flex flex-col h-full">
      {/* Header */}
      <div className="flex items-center justify-between w-full px-6 py-4 bg-[var(--sg-bg-0)] border-b border-[var(--sg-border)]">
        <div className="flex items-center gap-3">
          <Button
            variant="ghost"
            size="sm"
            {...router.nav("/security/findings")}
            className="h-8 w-8 p-0"
            aria-label="Back to findings"
          >
            <ArrowLeft className="h-4 w-4" />
          </Button>
          <div className="flex flex-col gap-1">
            <div className="flex items-center gap-3">
              <h1 className="text-2xl font-semibold text-[var(--sg-text)] font-mono">
                {finding?.check_id ?? (loading ? "Loading…" : "Finding")}
              </h1>
              {finding && <SeverityBadge severity={finding.severity_effective} />}
            </div>
            <p className="text-sm text-[var(--sg-text-muted)] break-all">
              {finding?.resource_fq_address ?? "Security finding detail"}
            </p>
          </div>
        </div>
      </div>

      {/* Error */}
      {error && (
        <div className="mx-6 mt-4 p-4 bg-[var(--sg-error)]/10 border border-[var(--sg-error)] rounded-lg">
          <div className="sg-secondary-header text-[var(--sg-error)] mb-1">
            Failed to load finding
          </div>
          <div className="sg-metadata text-[var(--sg-error)]">{error}</div>
        </div>
      )}

      {/* Content */}
      <div className="flex-1 overflow-y-auto px-6 py-4">
        {loading ? (
          <div className="flex items-center justify-center py-12">
            <div className="text-[var(--sg-text-muted)]">Loading finding…</div>
          </div>
        ) : !error && !finding ? (
          <div className="flex flex-col items-center justify-center py-12 gap-2 text-center px-4">
            <div className="text-[var(--sg-text)] font-medium">Finding not found</div>
            <div className="text-sm text-[var(--sg-text-muted)] max-w-md">
              It may have been resolved by a newer scan, or the link is stale.
            </div>
            <button
              {...router.nav("/security/findings")}
              className="mt-2 text-sm text-[var(--sg-accent)] hover:underline"
            >
              Back to findings
            </button>
          </div>
        ) : finding ? (
          <div className="space-y-6 max-w-5xl">
            {/* Severity */}
            <Card>
              <CardHeader>
                <CardTitle>Severity</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="grid grid-cols-2 gap-6">
                  <Field label="Effective">
                    <SeverityBadge severity={finding.severity_effective} />
                  </Field>
                  <Field label="Reported by scanner">{capitalize(finding.severity_base)}</Field>
                  <Field label="Adjustment reason" wide>
                    {finding.severity_reason ?? "—"}
                  </Field>
                </div>
              </CardContent>
            </Card>

            {/* Resource */}
            <Card>
              <CardHeader>
                <CardTitle>Resource</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="grid grid-cols-2 gap-6">
                  <Field label="Address" wide>
                    <span className="font-mono">{finding.resource_fq_address}</span>
                  </Field>
                  <Field label="Workspace">
                    <span className="font-mono">{finding.workspace ?? "—"}</span>
                  </Field>
                  <Field label="Source location">
                    {sourceLocation ? <span className="font-mono">{sourceLocation}</span> : "—"}
                  </Field>
                </div>
              </CardContent>
            </Card>

            {/* Blast radius */}
            <Card>
              <CardHeader>
                <CardTitle>Blast radius</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="grid grid-cols-2 gap-6">
                  <Field label="Modules affected">{modules.length.toLocaleString()}</Field>
                  <Field label="Resources reachable">
                    {typeof finding.blast_radius_resource_count === "number"
                      ? finding.blast_radius_resource_count.toLocaleString()
                      : "—"}
                  </Field>
                  <Field label="Modules" wide>
                    {modules.length > 0 ? (
                      <ul className="flex flex-col gap-1">
                        {modules.map((m) => (
                          <li key={m} className="font-mono text-sm break-all">
                            {m}
                          </li>
                        ))}
                      </ul>
                    ) : (
                      "—"
                    )}
                  </Field>
                </div>
                <DeepLink
                  href={`/blast-radius?state=${encodeURIComponent(stateId)}&resource=${encodeURIComponent(finding.resource_fq_address)}`}
                  className="mt-4 flex items-center justify-between p-3 rounded-lg border border-[var(--sg-border)] hover:bg-[var(--sg-bg-2)] transition-colors"
                >
                  <span className="text-sm font-medium text-[var(--sg-text-dim)]">
                    Open blast radius
                  </span>
                  <ExternalLink className="h-4 w-4 text-[var(--sg-text-dim)]" />
                </DeepLink>
              </CardContent>
            </Card>

            {/* Exposure */}
            <Card>
              <CardHeader>
                <CardTitle>Exposure</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="grid grid-cols-2 gap-6">
                  <Field label="Internet-reachable">
                    {finding.is_internet_reachable ? (
                      <span
                        className="inline-flex items-center gap-1 font-medium"
                        style={{ color: "var(--sg-error)" }}
                      >
                        <Globe className="h-4 w-4" />
                        Reachable
                      </span>
                    ) : (
                      "No"
                    )}
                  </Field>
                  <Field label="Cross-state references">
                    {finding.cross_state_refs && finding.cross_state_refs.length > 0 ? (
                      <span className="font-mono">{finding.cross_state_refs.join(", ")}</span>
                    ) : (
                      "—"
                    )}
                  </Field>
                  {hasEvidence && (
                    <Field label="Reachability evidence" wide>
                      <pre className="text-xs font-mono bg-[var(--sg-bg-2)] border border-[var(--sg-border-light)] rounded-md p-3 overflow-x-auto text-[var(--sg-text)]">
                        {JSON.stringify(evidence, null, 2)}
                      </pre>
                    </Field>
                  )}
                </div>
              </CardContent>
            </Card>

            {/* Lifecycle */}
            <Card>
              <CardHeader>
                <CardTitle>Lifecycle</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="grid grid-cols-2 gap-6">
                  <Field label="Status">{finding.resolved_scan_id ? "Resolved" : "Open"}</Field>
                  <Field label="First seen (scan)">
                    {finding.first_seen_scan_id ? (
                      <span className="font-mono">{finding.first_seen_scan_id}</span>
                    ) : (
                      "—"
                    )}
                  </Field>
                  <Field label="Resolved (scan)">
                    {finding.resolved_scan_id ? (
                      <span className="font-mono">{finding.resolved_scan_id}</span>
                    ) : (
                      "—"
                    )}
                  </Field>
                </div>
              </CardContent>
            </Card>

            {/* Scan & identity */}
            <Card>
              <CardHeader>
                <CardTitle>Scan &amp; identity</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="grid grid-cols-2 gap-6">
                  <Field label="Scanner">
                    {scan
                      ? `${scan.scanner}${scan.scanner_version ? ` ${scan.scanner_version}` : ""}`
                      : "—"}
                  </Field>
                  <Field label="Scanned at">{formatTimestamp(scan?.scanned_at)}</Field>
                  <Field label="State">{stateName}</Field>
                  <Field label="Fingerprint">
                    <span className="font-mono">{finding.fingerprint}</span>
                  </Field>
                </div>
              </CardContent>
            </Card>

            {/* Explore */}
            <Card>
              <CardHeader>
                <CardTitle>Explore</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="space-y-2">
                  <DeepLink
                    href={`/states/detail?id=${encodeURIComponent(stateId)}`}
                    className="flex items-center justify-between p-3 rounded-lg border border-[var(--sg-border)] hover:bg-[var(--sg-bg-2)] transition-colors"
                  >
                    <span className="text-sm font-medium text-[var(--sg-text-dim)]">
                      View state
                    </span>
                    <ExternalLink className="h-4 w-4 text-[var(--sg-text-dim)]" />
                  </DeepLink>
                </div>
              </CardContent>
            </Card>
          </div>
        ) : null}
      </div>
    </div>
  );
}
