"use client";

import { createElement, useEffect, useState } from "react";
import Script from "next/script";
import { ExternalLink, GitlabIcon, Loader2 } from "lucide-react";
import { PageSection, PageSurface } from "@/components/page";
import { GithubIcon } from "@/components/ui/brand-icons";
import { asText, loadAcrossProviders, orchestrationUnavailable } from "@/lib/mql/providers";
import { providerName, type VcsProvider } from "@/lib/vcs/links";
import { track } from "@/lib/analytics";

const INSTALLATIONS_CAP = 50;

const BILLING_PORTAL_URL = "https://billing.stripe.com/p/login/00geXngL2cQR0YofYY";

export interface StripePricingTable {
  publishableKey: string;
  pricingTableId: string;
}

/** The pricing table that nginx names in the document head of the hosted service; null unless
 *  both values are set. */
export function stripePricingTable(doc: Pick<Document, "querySelector">): StripePricingTable | null {
  const meta = (name: string) =>
    doc.querySelector<HTMLMetaElement>(`meta[name="${name}"]`)?.content.trim() ?? "";
  const publishableKey = meta("stategraph-stripe-publishable-key");
  const pricingTableId = meta("stategraph-stripe-pricing-table-id");
  return publishableKey && pricingTableId ? { publishableKey, pricingTableId } : null;
}

export interface PlanRow {
  provider: VcsProvider;
  name: string;
  tier: string;
  status: string;
  trialEndsAt: string | null;
}

export function planQuery(provider: VcsProvider): string {
  const name = provider === "github" ? "login as name" : "name";
  return `select ${name}, tier, account_status, trial_ends_at from ${provider}_installations limit ${INSTALLATIONS_CAP}`;
}

export function mapPlanRow(provider: VcsProvider, raw: unknown): PlanRow {
  const row = (raw ?? {}) as Record<string, unknown>;
  const trial = asText(row.trial_ends_at);
  return {
    provider,
    name: asText(row.name),
    tier: asText(row.tier),
    status: asText(row.account_status),
    trialEndsAt: trial === "" ? null : trial,
  };
}

/** "free-2026-07-10" reads as "Free"; "trial_ending" as "Trial ending". */
export function humanize(value: string): string {
  const base = value.replace(/-\d{4}-\d{2}-\d{2}$/, "").replace(/[_-]+/g, " ").trim();
  return base ? base.charAt(0).toUpperCase() + base.slice(1) : "";
}

export function trialText(trialEndsAt: string | null, now = Date.now()): string | null {
  if (!trialEndsAt) return null;
  const end = Date.parse(trialEndsAt);
  if (Number.isNaN(end)) return null;
  const days = Math.ceil((end - now) / 86_400_000);
  const date = new Date(end).toLocaleDateString(undefined, { year: "numeric", month: "short", day: "numeric" });
  if (days > 1) return `Trial ends in ${days} days, on ${date}.`;
  if (days === 1) return `Trial ends tomorrow, ${date}.`;
  if (days === 0) return `Trial ends today, ${date}.`;
  return `Trial ended on ${date}.`;
}

type Load = { status: "loading" } | { status: "ready"; rows: PlanRow[] } | { status: "unavailable" };

const LINK = "inline-flex items-center gap-1 text-sm text-[var(--sg-accent)] hover:underline";

/** Settings section for the hosted service: the tier and trial of each linked
 *  installation, its billing, and how to continue with Infrastructure as a Database. */
export function PlanSection() {
  const [load, setLoad] = useState<Load>({ status: "loading" });
  const [pricingTable, setPricingTable] = useState<StripePricingTable | null>(null);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- the document head is readable only after hydration
    setPricingTable(stripePricingTable(document));
  }, []);

  useEffect(() => {
    let cancelled = false;
    loadAcrossProviders(planQuery, mapPlanRow, INSTALLATIONS_CAP)
      .then((result) => {
        if (!cancelled) setLoad({ status: "ready", rows: result.rows });
      })
      .catch((error: unknown) => {
        if (cancelled) return;
        if (!orchestrationUnavailable(error)) {
          console.warn("[PlanSection] Failed to load installation plans:", error);
        }
        setLoad({ status: "unavailable" });
      });
    return () => {
      cancelled = true;
    };
  }, []);

  return (
    <PageSection title="Plan">
      <PageSurface>
        <div className="space-y-5">
          <div className="space-y-3">
            <div className="text-sm font-semibold text-[var(--sg-text)]">Stategraph Orchestration</div>
            {load.status === "loading" ? (
              <div className="flex items-center gap-2 text-sm text-[var(--sg-text-muted)]">
                <Loader2 className="h-4 w-4 animate-spin" /> Loading plan details.
              </div>
            ) : load.status === "unavailable" ? (
              <p className="text-sm text-[var(--sg-text-muted)]">Plan details are not available right now.</p>
            ) : load.rows.length === 0 ? (
              <p className="text-sm text-[var(--sg-text-muted)]">
                No installation is linked to this tenant yet. The plan appears here once GitHub or GitLab is
                connected.
              </p>
            ) : (
              <ul className="divide-y divide-[var(--sg-border)] rounded-md border border-[var(--sg-border)]">
                {load.rows.map((row) => {
                  const Icon = row.provider === "github" ? GithubIcon : GitlabIcon;
                  const trial = trialText(row.trialEndsAt);
                  return (
                    <li key={`${row.provider}:${row.name}`} className="flex flex-wrap items-center gap-x-4 gap-y-1 px-4 py-3">
                      <span className="flex items-center gap-2 text-sm font-medium text-[var(--sg-text)]">
                        <Icon className="h-4 w-4 text-[var(--sg-text-muted)]" />
                        {row.name || providerName(row.provider)}
                      </span>
                      <span className="text-sm text-[var(--sg-text-muted)]">
                        {humanize(row.tier) || "Default"} tier
                        {row.status ? ` · ${humanize(row.status)}` : ""}
                      </span>
                      {trial ? <span className="text-sm text-[var(--sg-text-muted)]">{trial}</span> : null}
                    </li>
                  );
                })}
              </ul>
            )}
            <a
              href={BILLING_PORTAL_URL}
              target="_blank"
              rel="noopener noreferrer"
              className={LINK}
              onClick={() => track("manage_billing_clicked")}
            >
              Manage billing <ExternalLink className="h-3 w-3" />
            </a>
            {pricingTable ? (
              <div className="space-y-3">
                <Script src="https://js.stripe.com/v3/pricing-table.js" strategy="afterInteractive" />
                <p className="text-sm text-[var(--sg-text-muted)]">Pick a plan for your installations.</p>
                {createElement("stripe-pricing-table", {
                  "pricing-table-id": pricingTable.pricingTableId,
                  "publishable-key": pricingTable.publishableKey,
                })}
              </div>
            ) : null}
          </div>
          <div className="space-y-2">
            <div className="text-sm font-semibold text-[var(--sg-text)]">Infrastructure as a Database</div>
            <p className="text-sm text-[var(--sg-text-muted)]">
              A 30-day trial is included. To continue after the trial, talk to sales.
            </p>
            <div className="flex flex-wrap gap-4">
              <a href="https://stategraph.com/pricing" target="_blank" rel="noopener noreferrer" className={LINK}>
                See pricing <ExternalLink className="h-3 w-3" />
              </a>
              <a href="https://stategraph.com/contact" target="_blank" rel="noopener noreferrer" className={LINK}>
                Contact sales <ExternalLink className="h-3 w-3" />
              </a>
            </div>
          </div>
        </div>
      </PageSurface>
    </PageSection>
  );
}
