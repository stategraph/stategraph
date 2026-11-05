import { StateChip } from "@/components/plans";
import type { StackState } from "@/app/(console)/stacks/mqlQueries";

/**
 * The stack vocabulary of the shared run-state chip. Stack state names are
 * disjoint from the transaction and run names, so they live in the same maps;
 * only the screen-reader prefix differs.
 */
export function StackStateChip({ state }: { state: StackState }) {
  return (
    <span className="shrink-0 whitespace-nowrap">
      <StateChip state={state} ariaPrefix="Stack state" />
    </span>
  );
}
