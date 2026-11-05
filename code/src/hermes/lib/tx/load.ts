/**
 * Whole-run loaders over the paginated tx companions: walk every page by the
 * Link header, then hand back what a view needs.
 */

import {
  getTxOutput,
  getTxPlanOperations,
  type TxOutputChunk,
  type TxOutputPayloadKind,
  type TxPlanOperation,
} from "@/lib/api/client";
import { parseLinkHeader } from "@/lib/api/pagination";
import { decodeTxOutput, type TxOutput } from "./output";

async function eachPage<T>(
  fetchPage: (page: string[] | undefined) => Promise<{ data: T; linkHeader: string | null }>,
  onPage: (data: T) => void
): Promise<void> {
  let page: string[] | undefined;
  for (;;) {
    const { data, linkHeader } = await fetchPage(page);
    onPage(data);
    const next = parseLinkHeader(linkHeader).next;
    if (!next || next.length === 0) return;
    page = next;
  }
}

/** Every plan operation of the transaction, in address order. */
export async function loadTxPlanOperations(txId: string): Promise<TxPlanOperation[]> {
  const ops: TxPlanOperation[] = [];
  await eachPage(
    (page) => getTxPlanOperations(txId, { page }),
    (d) => ops.push(...d.results)
  );
  return ops;
}

/** The apply's output, reassembled; null when nothing has been stored yet. */
export async function loadTxOutput(txId: string): Promise<TxOutput | null> {
  const chunks: TxOutputChunk[] = [];
  let kind: TxOutputPayloadKind | undefined;
  await eachPage(
    (page) => getTxOutput(txId, { page }),
    (d) => {
      kind ??= d.payload;
      chunks.push(...d.results);
    }
  );
  return chunks.length === 0 || !kind ? null : decodeTxOutput(kind, chunks);
}
