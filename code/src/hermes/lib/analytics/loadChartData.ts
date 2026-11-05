// Shared loader for the Visualization + Dashboard viewers (#1055): aggregate a
// saved chart server-side via MQL instead of counting a capped client-side page.
//
// Throws ChartAggregationUnsupportedError when the saved query/dimension can't be
// expressed as a supported server-side aggregation, so the viewer can render an
// explicit error state (never a silently-undercounted chart).

import { compileSQL, type ParsedQuery } from "@/app/(console)/query/compiler";
import { executeMQL } from "@/lib/api/client";
import type { ChartDataPoint } from "@/app/(console)/query/analyticsUtils";
import { buildAggregationQuery, AGG_LIMIT } from "./aggregationQuery";

/** Thrown when a saved chart can't be aggregated server-side. */
export class ChartAggregationUnsupportedError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ChartAggregationUnsupportedError";
  }
}

const UNSUPPORTED_MESSAGE =
  "This visualization can't be aggregated server-side. Edit it to group by type, " +
  "provider, module, or address using a simple SELECT … FROM instances query.";

interface AggRow {
  dimension?: unknown;
  cnt?: unknown;
}

export interface ChartDataResult {
  data: ChartDataPoint[];
  /** True when distinct dimension values were capped at AGG_LIMIT. */
  truncated: boolean;
  /** The MQL query that was executed (for the viewer's "Explain" panel). */
  mql: string;
  /** The compiled saved query (drives the "Explain" breakdown). */
  parsed: ParsedQuery;
}

/**
 * Aggregate a saved chart server-side (`count(*) group by <dimension>`) over the
 * full state via MQL. Throws ChartAggregationUnsupportedError for shapes the
 * server-side path can't express.
 */
export async function loadChartData(params: {
  stateId: string;
  query: string;
  dimensionField: string;
}): Promise<ChartDataResult> {
  const { stateId, query, dimensionField } = params;

  const compiled = compileSQL(query);
  if (!compiled.success || !compiled.parsed) {
    throw new ChartAggregationUnsupportedError(UNSUPPORTED_MESSAGE);
  }

  const mql = buildAggregationQuery({
    stateId,
    dimensionField,
    where: compiled.parsed.where,
    aggregation: compiled.parsed.aggregation,
  });
  if (mql === null) {
    throw new ChartAggregationUnsupportedError(UNSUPPORTED_MESSAGE);
  }

  const { data, paginationError, defaultLimitApplied } = await executeMQL(mql);
  if (paginationError) {
    throw new Error(`Aggregation query failed: ${paginationError}`);
  }

  const rows = data as AggRow[];

  // Scalar COUNT(*): a single total data point.
  if (compiled.parsed.aggregation) {
    const count = rows.length > 0 ? Number(rows[0].cnt) : 0;
    return {
      data: [{ dimension: "Total", count, label: "Total" }],
      truncated: false,
      mql,
      parsed: compiled.parsed,
    };
  }

  const chartData: ChartDataPoint[] = rows.map((row) => {
    const dimension =
      row.dimension === null || row.dimension === undefined ? "(null)" : String(row.dimension);
    return { dimension, count: Number(row.cnt), label: dimension };
  });

  const truncated = defaultLimitApplied !== null || rows.length >= AGG_LIMIT;
  if (truncated) {
    console.warn(
      `[loadChartData] dimension "${dimensionField}" has >= ${AGG_LIMIT} distinct values; ` +
        `the chart shows only the top ${AGG_LIMIT}.`
    );
  }
  return { data: chartData, truncated, mql, parsed: compiled.parsed };
}
