"use client";

import { useDeepLinkRouter } from "@/hooks";
import { StatusPill } from "@/components/status/StatusPill";
import type { Tone } from "@/components/status/tones";
import { prSigil, providerName, type VcsProvider } from "@/lib/vcs/links";
import { formatRelativeTime } from "@/lib/utils/time";
import { SETUP_COPY } from "@/lib/getting-started/setup-progress";
import {
  ATTENTION_LIST_HREF,
  ATTENTION_ORDER,
  attentionHref,
  type AttentionItem,
  type NeedsAttention as NeedsAttentionData,
} from "@/app/(console)/home/dashboard";

const COPY = SETUP_COPY.attention;

const NOTE =
  "p-2 rounded-md border border-[var(--sg-warning)]/40 bg-[var(--sg-warning)]/10 text-xs text-[var(--sg-text-muted)]";

function repoOf(owner: string, name: string): string {
  return owner && name ? `${owner}/${name}` : "—";
}

function pullOf(provider: VcsProvider, pullNumber: string): string {
  return pullNumber ? `${prSigil(provider)}${pullNumber}` : "";
}

function describe(item: AttentionItem): { tone: Tone; chip: string; title: string; detail: string } {
  switch (item.kind) {
    case "failed-run": {
      const r = item.run;
      const where = pullOf(r.provider, r.pullNumber) || r.branch;
      return {
        tone: "error",
        chip: COPY.chip.failed,
        title: repoOf(r.repoOwner, r.repoName),
        detail: [r.runType, r.runKind === "drift" ? "drift" : "", where].filter(Boolean).join(" · "),
      };
    }
    case "failed-transaction":
      return {
        tone: "error",
        chip: item.transaction.state === "failed-committed" ? COPY.chip.applyFailed : COPY.chip.failed,
        title: COPY.transaction(item.transaction.id.slice(0, 8)),
        detail: "",
      };
    case "open-transaction":
      return {
        tone: "warning",
        chip: COPY.chip.openOverHour,
        title: COPY.transaction(item.transaction.id.slice(0, 8)),
        detail: "",
      };
    case "drift": {
      const d = item.drift;
      return {
        tone: "warning",
        chip: COPY.chip.drifted,
        title: repoOf(d.repoOwner, d.repoName),
        detail: `${d.dir || "."} · ${d.workspace}`,
      };
    }
    case "waiting-for-apply": {
      const pr = item.pullRequest;
      return {
        tone: "accent",
        chip: COPY.chip.waiting,
        title: repoOf(pr.repoOwner, pr.repoName),
        detail: [`${pullOf(pr.provider, pr.pullNumber)} ${pr.title}`.trim(), COPY.workspaces(pr.workspaces)].join(
          " · ",
        ),
      };
    }
  }
}

/**
 * What needs action now, each item linking to its detail page. `attention` is `null` when nothing
 * loaded. Says that nothing needs attention only when every source loaded.
 */
export function NeedsAttention({
  attention,
  failedProviders,
  transactionsFailed,
}: {
  attention: NeedsAttentionData | null;
  failedProviders: readonly VcsProvider[];
  transactionsFailed: boolean;
}) {
  const router = useDeepLinkRouter();
  const items = attention?.items ?? [];
  const complete = failedProviders.length === 0 && !transactionsFailed;
  const counts = attention
    ? ATTENTION_ORDER.filter((kind) => attention.counts[kind] > 0).map((kind) => ({
        kind,
        label: COPY.count[kind](attention.counts[kind]),
      }))
    : [];

  return (
    <section aria-labelledby="home-needs-attention" className="space-y-3">
      <div className="flex flex-wrap items-baseline justify-between gap-x-4 gap-y-1">
        <h2
          id="home-needs-attention"
          className="text-base font-semibold text-[var(--sg-text)] uppercase tracking-wide"
        >
          {COPY.title}
        </h2>
        {counts.length > 0 ? (
          <div className="flex flex-wrap items-center gap-x-3 gap-y-1 text-sm">
            {counts.map((c) => (
              <button
                key={c.kind}
                {...router.nav(ATTENTION_LIST_HREF[c.kind])}
                className="cursor-pointer text-[var(--sg-accent)] hover:underline"
              >
                {c.label}
              </button>
            ))}
          </div>
        ) : null}
      </div>

      {failedProviders.length > 0 ? (
        <div className={NOTE}>{COPY.partial([...failedProviders].map(providerName).join(", "))}</div>
      ) : null}
      {transactionsFailed ? <div className={NOTE}>{COPY.transactionsPartial}</div> : null}

      {items.length > 0 ? (
        <div className="rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-1)] overflow-hidden divide-y divide-[var(--sg-border)]">
          {items.map((item) => {
            const d = describe(item);
            return (
              <button
                key={`${item.kind}:${attentionHref(item)}`}
                {...router.nav(attentionHref(item))}
                className="flex w-full cursor-pointer items-start gap-3 px-4 py-2.5 text-left hover:bg-[var(--sg-bg-2)] sm:items-center"
              >
                <span className="shrink-0 sm:w-[8.5rem]">
                  <StatusPill tone={d.tone} label={d.chip} ariaPrefix={COPY.title} />
                </span>
                <span className="flex min-w-0 flex-1 flex-col gap-1 sm:flex-row sm:items-center sm:gap-3">
                  <span className="min-w-0 break-all font-mono text-xs text-[var(--sg-text)] sm:max-w-[40%] sm:truncate">
                    {d.title}
                  </span>
                  {d.detail ? (
                    <span className="min-w-0 text-xs text-[var(--sg-text-muted)] sm:truncate">{d.detail}</span>
                  ) : null}
                  <span className="text-xs text-[var(--sg-text-muted)] sm:ml-auto sm:shrink-0">
                    {formatRelativeTime(item.at)}
                  </span>
                </span>
              </button>
            );
          })}
        </div>
      ) : complete ? (
        <p className="text-sm text-[var(--sg-text-muted)]">{COPY.empty}</p>
      ) : null}
    </section>
  );
}
