import type { CostBreakdownEntry } from "@/lib/api/client";
import { formatCurrency, parseCost } from "@/lib/cost/format";

export interface BreakdownTableProps {
  title: string;
  entries: CostBreakdownEntry[];
  currency: string;
  /** When provided, rows become clickable (e.g. to focus the trend chart). */
  onRowClick?: (name: string) => void;
  /** Name of the currently-focused row, highlighted when set. */
  activeName?: string | null;
  /**
   * Optional display formatter for the row name (e.g. shorten raw provider
   * keys). The raw `name` is still used for keys, onRowClick, and the title
   * attribute — only the visible label changes.
   */
  formatName?: (name: string) => string;
}

/**
 * A small "name / monthly / resources" table used for the tenant cost
 * breakdowns (by provider / type / tag). Extracted from CostOverviewClient so
 * the Overview and Explorer pages share one implementation. Rows are clickable
 * only when `onRowClick` is supplied.
 *
 * Renders as a table on lg+ and as a stacked card list below lg so long names
 * (e.g. raw provider keys) never overflow a narrow card.
 */
export function BreakdownTable({
  title,
  entries,
  currency,
  onRowClick,
  activeName,
  formatName,
}: BreakdownTableProps) {
  const clickable = typeof onRowClick === "function";
  const label = (name: string) => (formatName ? formatName(name) : name);
  const monthlyText = (e: CostBreakdownEntry) => {
    const monthly = parseCost(e.monthly_cost);
    return monthly !== null ? formatCurrency(monthly, currency) : "—";
  };

  return (
    <div className="flex flex-col gap-2">
      <div className="text-xs text-[var(--sg-text-muted)] uppercase tracking-wide">{title}</div>
      <div className="bg-[var(--sg-bg-1)] border border-[var(--sg-border-light)] rounded-md overflow-hidden">
        {entries.length === 0 && (
          <div className="px-3 py-2 text-sm text-[var(--sg-text-muted)]">No data</div>
        )}

        {/* Desktop / tablet table (lg+) */}
        {entries.length > 0 && (
          <table className="hidden lg:table w-full text-sm">
            <thead>
              <tr className="text-[var(--sg-text-muted)] text-xs uppercase border-b border-[var(--sg-border-light)]">
                <th className="text-left px-3 py-2 font-medium">Name</th>
                <th className="text-right px-3 py-2 font-medium">Monthly</th>
                <th className="text-right px-3 py-2 font-medium">Resources</th>
              </tr>
            </thead>
            <tbody>
              {entries.map((e) => {
                const active = activeName != null && activeName === e.name;
                return (
                  <tr
                    key={e.name}
                    onClick={clickable ? () => onRowClick?.(e.name) : undefined}
                    className={`border-b last:border-b-0 border-[var(--sg-border-light)] ${
                      clickable ? "cursor-pointer hover:bg-[var(--sg-bg-2)]" : ""
                    } ${active ? "bg-[var(--sg-accent-bg)]" : ""}`}
                  >
                    <td className="px-3 py-2 text-[var(--sg-text)] truncate max-w-[1px]" title={e.name}>
                      {label(e.name)}
                    </td>
                    <td className="px-3 py-2 text-right font-mono whitespace-nowrap">
                      {monthlyText(e)}
                    </td>
                    <td className="px-3 py-2 text-right font-mono text-[var(--sg-text-muted)] whitespace-nowrap">
                      {e.resource_count}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}

        {/* Mobile card list (below lg) */}
        {entries.length > 0 && (
          <div className="lg:hidden divide-y divide-[var(--sg-border-light)]">
            {entries.map((e) => {
              const active = activeName != null && activeName === e.name;
              return (
                <div
                  key={e.name}
                  onClick={clickable ? () => onRowClick?.(e.name) : undefined}
                  className={`px-3 py-2 ${
                    clickable ? "cursor-pointer hover:bg-[var(--sg-bg-2)]" : ""
                  } ${active ? "bg-[var(--sg-accent-bg)]" : ""}`}
                >
                  <div className="text-sm text-[var(--sg-text)] truncate" title={e.name}>
                    {label(e.name)}
                  </div>
                  <div className="mt-1 flex items-center justify-between gap-3 text-xs font-mono text-[var(--sg-text-muted)]">
                    <span>{monthlyText(e)}</span>
                    <span>{e.resource_count} resources</span>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}
