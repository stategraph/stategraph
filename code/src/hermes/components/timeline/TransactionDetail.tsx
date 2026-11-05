"use client";

import type { TransactionRow } from "@/lib/timeline/types";
import { CopyButton } from "@/components/ui/copy-button";
import { TransactionLogs } from "./TransactionLogs";
import { SecurityDelta } from "./SecurityDelta";

interface TransactionDetailProps {
  transaction: TransactionRow;
  resourceFilter?: string;
}

// Section header with copy button
function SectionHeader({
  title,
  copyContent,
  copyLabel,
}: {
  title: string;
  copyContent?: string;
  copyLabel?: string;
}) {
  return (
    <div className="flex items-center justify-between mb-3 pb-2 border-b border-[var(--sg-border)]">
      <h3 className="text-sm font-semibold text-[var(--sg-text)]">{title}</h3>
      {copyContent && copyLabel && (
        <CopyButton text={copyContent} title={`Copy ${copyLabel}`} />
      )}
    </div>
  );
}

// Metadata field display - always shows all fields in deterministic order
function MetadataField({
  label,
  value,
  mono = false,
}: {
  label: string;
  value: string | undefined | null;
  mono?: boolean;
}) {
  const displayValue = value ?? "(not set)";

  return (
    <div className="grid grid-cols-1 sm:grid-cols-[140px,1fr] gap-1 sm:gap-3 py-2 border-b border-[var(--sg-border)] last:border-b-0">
      <dt className="text-xs font-medium text-[var(--sg-text-dim)] break-words">
        {label}
      </dt>
      <dd
        className={`text-xs text-[var(--sg-text)] break-all ${mono ? "font-mono" : ""}`}
      >
        {displayValue}
      </dd>
    </div>
  );
}

function MetadataSection({ transaction }: { transaction: TransactionRow }) {
  // Create deterministic JSON representation of all transaction fields
  const metadataJson = JSON.stringify(
    {
      id: transaction.id,
      created_at: transaction.created_at,
      completed_at: transaction.completed_at ?? null,
      state: transaction.state,
      user_id: transaction.created_by,
      tags: transaction.tags,
    },
    null,
    2
  );

  return (
    <div className="border-b border-[var(--sg-border)] pb-4 min-w-0">
      <SectionHeader
        title="Transaction Metadata"
        copyContent={metadataJson}
        copyLabel="metadata as JSON"
      />
      <dl className="min-w-0">
        <MetadataField label="id" value={transaction.id} mono />
        <MetadataField
          label="created_at"
          value={transaction.created_at}
          mono
        />
        <MetadataField
          label="completed_at"
          value={transaction.completed_at}
          mono
        />
        <MetadataField label="state" value={transaction.state} />
        <MetadataField label="user_id" value={transaction.created_by} mono />
      </dl>
    </div>
  );
}

function TagsSection({ tags }: { tags: unknown }) {
  // Deterministic JSON serialization
  const tagsJson = JSON.stringify(tags, null, 2);
  const isEmpty =
    tags === null ||
    tags === undefined ||
    (typeof tags === "object" && Object.keys(tags as object).length === 0);

  return (
    <div className="border-b border-[var(--sg-border)] pb-4 min-w-0">
      <SectionHeader
        title="Tags (Raw JSON)"
        copyContent={tagsJson}
        copyLabel="tags as JSON"
      />
      {isEmpty ? (
        <div className="text-xs text-[var(--sg-text-dim)] bg-[var(--sg-bg-2)] p-3 rounded font-mono">
          {tagsJson}
        </div>
      ) : (
        <pre className="text-xs font-mono text-[var(--sg-text)] bg-[var(--sg-bg-2)] p-3 rounded overflow-x-auto border border-[var(--sg-border)] max-h-96 overflow-y-auto min-w-0 w-full">
          {tagsJson}
        </pre>
      )}
      <div className="mt-2 text-xs text-[var(--sg-text-dim)]">
        Raw JSON serialization. No interpretation applied.
      </div>
    </div>
  );
}

export function TransactionDetail({ transaction, resourceFilter }: TransactionDetailProps) {
  return (
    <div className="flex flex-col h-full min-w-0 overflow-y-auto">
      <div className="space-y-4 p-4 min-w-0">
        <MetadataSection transaction={transaction} />
        <SecurityDelta txId={transaction.id} />
        <TagsSection tags={transaction.tags} />
        <TransactionLogs txId={transaction.id} resourceFilter={resourceFilter} />
      </div>
    </div>
  );
}
