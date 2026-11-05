"use client";

import { useCallback, useEffect, useState, type FormEvent } from "react";
import { PageHeader, PageSection, PageSurface } from "@/components/page";
import { SelfHostedOnlyNotice } from "@/components/product";
import { useAuth } from "@/components/auth";
import { isTenantAdmin } from "@/lib/api/capabilities";
import { useTenant } from "@/contexts/TenantContext";
import { useLicense } from "@/contexts";
import {
  executeMQL,
  createBillingSource,
  updateBillingSource,
  deleteBillingSource,
  syncBillingSource,
  type BillingSource,
} from "@/lib/api/client";
import {
  billingSourcesQuery,
  billingSourceRowToBillingSource,
  type BillingSourceRow,
} from "./mqlQueries";
import { track } from "@/lib/analytics";

interface ProviderInfo {
  label: string;
  uriPlaceholder: string;
  needsRegion: boolean;
  regionPlaceholder: string;
  blurb: string;
  docs: { label: string; url: string }[];
}

// Per-provider hints + links to the official FOCUS-export setup docs. The schema
// is identical across clouds; only the URI scheme, whether a region applies, and
// the export setup differ.
const PROVIDER_INFO: Record<string, ProviderInfo> = {
  aws: {
    label: "AWS",
    uriPlaceholder: "s3://bucket/prefix/<export>/data/**/*.parquet",
    needsRegion: true,
    regionPlaceholder: "us-east-1",
    blurb:
      "Billing and Cost Management → Data Exports → create a “FOCUS 1.0” standard export (Parquet) to an S3 bucket. First files arrive within ~24h, then refresh daily.",
    docs: [
      {
        label: "Create a FOCUS 1.0 Data Export",
        url: "https://docs.aws.amazon.com/cur/latest/userguide/dataexports-create-standard.html",
      },
      {
        label: "FOCUS 1.0 table reference",
        url: "https://docs.aws.amazon.com/cur/latest/userguide/table-dictionary-focus-1-0-aws.html",
      },
    ],
  },
  gcp: {
    label: "Google Cloud",
    uriPlaceholder: "gs://bucket/prefix/**/*.parquet",
    needsRegion: true,
    regionPlaceholder: "us  (bucket region)",
    blurb:
      "Enable Detailed billing export to BigQuery, then export the FOCUS view to a GCS bucket (Parquet or CSV) and point this source at that bucket.",
    docs: [
      {
        label: "Set up billing export to BigQuery",
        url: "https://cloud.google.com/billing/docs/how-to/export-data-bigquery-setup",
      },
      {
        label: "FOCUS BigQuery view",
        url: "https://cloud.google.com/blog/topics/cost-management/new-bigquery-cloud-billing-view-based-on-focus",
      },
    ],
  },
  azure: {
    label: "Azure",
    uriPlaceholder: "abfss://container@account.dfs.core.windows.net/path/**/*.parquet",
    needsRegion: false,
    regionPlaceholder: "",
    blurb:
      "Cost Management → Exports → create an export with the “Cost and usage details (FOCUS)” dataset (Parquet) to a storage account, then use the abfss:// path to the container.",
    docs: [
      {
        label: "Create a Cost Management FOCUS export",
        url: "https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/tutorial-improved-exports",
      },
      {
        label: "FOCUS export schema",
        url: "https://learn.microsoft.com/en-us/azure/cost-management-billing/dataset-schema/cost-usage-details-focus",
      },
    ],
  },
};

const PROVIDERS = Object.keys(PROVIDER_INFO);

function statusColor(status: string | undefined): string {
  switch (status) {
    case "ok":
      return "var(--sg-success)";
    case "error":
      return "var(--sg-error)";
    case "running":
      return "var(--sg-warning)";
    default:
      return "var(--sg-text-dim)";
  }
}

export function BillingConnectionsContent() {
  const { user } = useAuth();
  const { currentTenant } = useTenant();
  const { mode } = useLicense();
  const tenantId = currentTenant?.id ?? "";

  const [sources, setSources] = useState<BillingSource[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);

  const [provider, setProvider] = useState("aws");
  const [sourceUri, setSourceUri] = useState("");
  const [region, setRegion] = useState("");
  const [windowMonths, setWindowMonths] = useState(2);
  const [adding, setAdding] = useState(false);

  const refresh = useCallback(async () => {
    if (!tenantId) return;
    setLoading(true);
    try {
      // Read via MQL over the tenant-scoped focus_billing_sources table (#1080).
      const { data } = await executeMQL(billingSourcesQuery(tenantId));
      setSources((data as BillingSourceRow[]).map(billingSourceRowToBillingSource));
      setError(null);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to load billing sources");
    } finally {
      setLoading(false);
    }
  }, [tenantId]);

  useEffect(() => {
    void refresh();
  }, [refresh]);

  // In COMMUNISM mode (shared hosted substrate) billing connections aren't
  // available yet; they require cloud storage credentials that only self-hosted
  // deployments have.
  if (mode === "COMMUNISM") {
    return (
      <div className="flex flex-col w-full">
        <PageHeader
          title="Billing connections"
          subtitle="Configure FOCUS billing exports; Stategraph syncs actual cloud spend from them."
        />
        <SelfHostedOnlyNotice feature="Billing connections" />
      </div>
    );
  }

  // The billing-source endpoints gate on Caps.admin_tenant, so administering the selected
  // tenant is the right requirement -- requiring installation-wide admin denied a tenant
  // admin a screen they are authorized for.
  if (!isTenantAdmin(user?.capabilities, currentTenant?.id)) {
    return (
      <div className="flex flex-col items-center justify-center h-full p-12">
        <h1 className="text-2xl font-bold mb-2" style={{ color: "var(--sg-text)" }}>
          Access Denied
        </h1>
        <p style={{ color: "var(--sg-text-muted)" }}>
          Admin privileges are required to manage billing connections.
        </p>
      </div>
    );
  }

  const withBusy = async (id: string, fn: () => Promise<unknown>) => {
    setBusyId(id);
    setError(null);
    try {
      await fn();
      await refresh();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Action failed");
    } finally {
      setBusyId(null);
    }
  };

  const handleAdd = async (e: FormEvent) => {
    e.preventDefault();
    if (!tenantId || !sourceUri) return;
    setAdding(true);
    setError(null);
    try {
      await createBillingSource(tenantId, {
        provider,
        source_uri: sourceUri,
        region: PROVIDER_INFO[provider].needsRegion ? region || undefined : undefined,
        window_months: windowMonths,
        enabled: true,
      });
      track("billing_source_created", { provider, window_months: windowMonths });
      setSourceUri("");
      setRegion("");
      await refresh();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to add billing source");
    } finally {
      setAdding(false);
    }
  };

  const toggleEnabled = (s: BillingSource) =>
    withBusy(s.id, () => updateBillingSource(tenantId, s.id, { enabled: !s.enabled }));

  const sync = (s: BillingSource) => withBusy(s.id, () => syncBillingSource(tenantId, s.id));

  const remove = (s: BillingSource) => {
    if (
      !window.confirm(
        `Delete billing source "${s.source_uri}"? This also removes its loaded billing rows.`
      )
    )
      return;
    void withBusy(s.id, () => deleteBillingSource(tenantId, s.id));
  };

  // Shared by the lg+ table and the mobile card list so the action logic
  // lives in one place.
  const renderActions = (s: BillingSource) => (
    <div className="flex flex-wrap gap-2 text-xs">
      <button
        onClick={() => sync(s)}
        disabled={busyId === s.id}
        className="rounded px-2 py-1 disabled:opacity-50"
        style={{ border: "1px solid var(--sg-border)", color: "var(--sg-text)" }}
      >
        Sync
      </button>
      <button
        onClick={() => toggleEnabled(s)}
        disabled={busyId === s.id}
        className="rounded px-2 py-1 disabled:opacity-50"
        style={{ border: "1px solid var(--sg-border)", color: "var(--sg-text)" }}
      >
        {s.enabled ? "Disable" : "Enable"}
      </button>
      <button
        onClick={() => remove(s)}
        disabled={busyId === s.id}
        className="rounded px-2 py-1 disabled:opacity-50"
        style={{ border: "1px solid var(--sg-border)", color: "var(--sg-error)" }}
      >
        Delete
      </button>
    </div>
  );

  const inputStyle = {
    backgroundColor: "var(--sg-bg-0)",
    border: "1px solid var(--sg-border)",
    color: "var(--sg-text)",
  };
  const cellClass = "px-4 py-3 text-sm";
  const headClass = "px-4 py-3 text-left text-xs font-medium uppercase";

  return (
    <div className="flex flex-col w-full">
      <PageHeader
        title="Billing connections"
        subtitle="Configure FOCUS billing exports; Stategraph syncs actual cloud spend from them."
      />

      {error && (
        <div
          className="mx-6 mb-4 rounded-md px-4 py-2 text-sm"
          style={{ backgroundColor: "var(--sg-bg-1)", color: "var(--sg-error)", border: "1px solid var(--sg-border)" }}
        >
          {error}
        </div>
      )}

      <PageSection title="Add a source">
        <PageSurface>
          <form className="flex flex-col sm:flex-row sm:flex-wrap sm:items-end gap-3 p-4" onSubmit={handleAdd}>
            <label className="flex flex-col gap-1 text-xs w-full sm:w-auto" style={{ color: "var(--sg-text-muted)" }}>
              Provider
              <select
                className="rounded-md px-2 py-1.5 text-sm"
                style={inputStyle}
                value={provider}
                onChange={(e) => setProvider(e.target.value)}
              >
                {PROVIDERS.map((p) => (
                  <option key={p} value={p}>
                    {PROVIDER_INFO[p].label}
                  </option>
                ))}
              </select>
            </label>
            <label className="flex flex-col gap-1 text-xs w-full sm:flex-1 sm:min-w-[20rem]" style={{ color: "var(--sg-text-muted)" }}>
              Source URI
              <input
                className="rounded-md px-2 py-1.5 text-sm"
                style={inputStyle}
                placeholder={PROVIDER_INFO[provider].uriPlaceholder}
                value={sourceUri}
                onChange={(e) => setSourceUri(e.target.value)}
              />
            </label>
            {PROVIDER_INFO[provider].needsRegion && (
              <label className="flex flex-col gap-1 text-xs w-full sm:w-auto" style={{ color: "var(--sg-text-muted)" }}>
                Region
                <input
                  className="rounded-md px-2 py-1.5 text-sm w-full sm:w-32"
                  style={inputStyle}
                  placeholder={PROVIDER_INFO[provider].regionPlaceholder}
                  value={region}
                  onChange={(e) => setRegion(e.target.value)}
                />
              </label>
            )}
            <label className="flex flex-col gap-1 text-xs w-full sm:w-auto" style={{ color: "var(--sg-text-muted)" }}>
              Window (months)
              <input
                type="number"
                min={1}
                className="rounded-md px-2 py-1.5 text-sm w-full sm:w-24"
                style={inputStyle}
                value={windowMonths}
                onChange={(e) => setWindowMonths(Number(e.target.value) || 1)}
              />
            </label>
            <button
              type="submit"
              disabled={adding || !sourceUri}
              className="rounded-md px-3 py-1.5 text-sm font-medium disabled:opacity-50 w-full sm:w-auto"
              style={{ backgroundColor: "var(--sg-accent)", color: "var(--sg-bg-0)" }}
            >
              {adding ? "Adding…" : "Add source"}
            </button>
          </form>
          <div
            className="mx-4 mb-4 rounded-md p-3 text-xs"
            style={{
              backgroundColor: "var(--sg-bg-0)",
              border: "1px solid var(--sg-border)",
              color: "var(--sg-text-muted)",
            }}
          >
            <p className="mb-1">
              <span style={{ color: "var(--sg-text)" }}>
                Setting up a {PROVIDER_INFO[provider].label} FOCUS export:
              </span>{" "}
              {PROVIDER_INFO[provider].blurb}
            </p>
            <p className="flex flex-wrap gap-x-4 gap-y-1">
              {PROVIDER_INFO[provider].docs.map((d) => (
                <a
                  key={d.url}
                  href={d.url}
                  target="_blank"
                  rel="noopener noreferrer"
                  style={{ color: "var(--sg-accent)" }}
                >
                  {d.label} ↗
                </a>
              ))}
            </p>
          </div>
        </PageSurface>
      </PageSection>

      <PageSection title="Sources">
        <PageSurface>
          {!tenantId ? (
            <p className="p-4 text-sm" style={{ color: "var(--sg-text-muted)" }}>
              Select a tenant to manage its billing sources.
            </p>
          ) : loading ? (
            <p className="p-4 text-sm" style={{ color: "var(--sg-text-muted)" }}>
              Loading…
            </p>
          ) : sources.length === 0 ? (
            <p className="p-4 text-sm" style={{ color: "var(--sg-text-muted)" }}>
              No billing sources yet. Add one above.
            </p>
          ) : (
            <>
            <div className="hidden lg:block overflow-x-auto">
              <table className="w-full">
                <thead style={{ borderBottom: "1px solid var(--sg-border)" }}>
                  <tr style={{ color: "var(--sg-text-muted)" }}>
                    <th className={headClass}>Provider</th>
                    <th className={headClass}>Source URI</th>
                    <th className={headClass}>Region</th>
                    <th className={headClass}>Window</th>
                    <th className={headClass}>Enabled</th>
                    <th className={headClass}>Last sync</th>
                    <th className={headClass}>Rows</th>
                    <th className={headClass}>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {sources.map((s) => (
                    <tr key={s.id} style={{ borderTop: "1px solid var(--sg-border)" }}>
                      <td className={cellClass} style={{ color: "var(--sg-text)" }}>
                        {s.provider}
                      </td>
                      <td className={cellClass} style={{ color: "var(--sg-text)" }}>
                        <span className="font-mono text-xs">{s.source_uri}</span>
                      </td>
                      <td className={cellClass} style={{ color: "var(--sg-text-muted)" }}>
                        {s.region ?? "—"}
                      </td>
                      <td className={cellClass} style={{ color: "var(--sg-text-muted)" }}>
                        {s.window_months}mo
                      </td>
                      <td className={cellClass}>
                        <span style={{ color: s.enabled ? "var(--sg-success)" : "var(--sg-text-dim)" }}>
                          {s.enabled ? "yes" : "no"}
                        </span>
                      </td>
                      <td className={cellClass}>
                        <span style={{ color: statusColor(s.last_status) }} title={s.last_error ?? undefined}>
                          {s.last_status ?? "never"}
                        </span>
                        {s.last_synced_at && (
                          <span className="ml-1 text-xs" style={{ color: "var(--sg-text-dim)" }}>
                            {new Date(s.last_synced_at).toLocaleString()}
                          </span>
                        )}
                      </td>
                      <td className={cellClass} style={{ color: "var(--sg-text-muted)" }}>
                        {s.last_row_count ?? "—"}
                      </td>
                      <td className={cellClass}>{renderActions(s)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <div className="lg:hidden space-y-3 p-4">
              {sources.map((s) => (
                <div
                  key={s.id}
                  className="rounded-lg border p-3"
                  style={{
                    borderColor: "var(--sg-border)",
                    backgroundColor: "var(--sg-bg-0)",
                  }}
                >
                  <div className="flex items-center justify-between gap-2 mb-2">
                    <span
                      className="text-sm font-medium"
                      style={{ color: "var(--sg-text)" }}
                    >
                      {s.provider}
                    </span>
                    <span
                      className="text-xs"
                      style={{
                        color: s.enabled
                          ? "var(--sg-success)"
                          : "var(--sg-text-dim)",
                      }}
                    >
                      {s.enabled ? "enabled" : "disabled"}
                    </span>
                  </div>
                  <div
                    className="font-mono text-xs break-all mb-3"
                    style={{ color: "var(--sg-text)" }}
                  >
                    {s.source_uri}
                  </div>
                  <div className="grid grid-cols-2 gap-x-4 gap-y-2 text-xs mb-3">
                    <div>
                      <div
                        className="uppercase tracking-wide"
                        style={{ color: "var(--sg-text-dim)" }}
                      >
                        Region
                      </div>
                      <div style={{ color: "var(--sg-text-muted)" }}>
                        {s.region ?? "—"}
                      </div>
                    </div>
                    <div>
                      <div
                        className="uppercase tracking-wide"
                        style={{ color: "var(--sg-text-dim)" }}
                      >
                        Window
                      </div>
                      <div style={{ color: "var(--sg-text-muted)" }}>
                        {s.window_months}mo
                      </div>
                    </div>
                    <div>
                      <div
                        className="uppercase tracking-wide"
                        style={{ color: "var(--sg-text-dim)" }}
                      >
                        Rows
                      </div>
                      <div style={{ color: "var(--sg-text-muted)" }}>
                        {s.last_row_count ?? "—"}
                      </div>
                    </div>
                    <div>
                      <div
                        className="uppercase tracking-wide"
                        style={{ color: "var(--sg-text-dim)" }}
                      >
                        Last sync
                      </div>
                      <div
                        style={{ color: statusColor(s.last_status) }}
                        title={s.last_error ?? undefined}
                      >
                        {s.last_status ?? "never"}
                      </div>
                      {s.last_synced_at && (
                        <div style={{ color: "var(--sg-text-dim)" }}>
                          {new Date(s.last_synced_at).toLocaleString()}
                        </div>
                      )}
                    </div>
                  </div>
                  {renderActions(s)}
                </div>
              ))}
            </div>
            </>
          )}
        </PageSurface>
      </PageSection>
    </div>
  );
}
