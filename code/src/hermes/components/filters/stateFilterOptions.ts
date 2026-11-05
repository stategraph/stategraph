import type { State } from "@/lib/api/client";
import { matchesSearch } from "@/lib/ui/search";

/**
 * The states the state picker lists for `query`, in display order: those whose
 * name matches `query` (see `matchesSearch`), with the `disabledStateIds` ones
 * last.
 *
 * De-emphasised entries sink to the bottom. The list is name-ordered and the
 * menu scrolls after ~8 rows, so on a tenant where most states have no data
 * for the page (Findings, Analysis) every entry above the fold could be
 * greyed out, with the states actually worth picking hidden below it. Name
 * order is preserved within each group.
 */
export function stateFilterOptions<S extends Pick<State, "id" | "name">>(
  states: readonly S[],
  query: string,
  disabledStateIds: readonly string[] = [],
): S[] {
  const disabled = new Set(disabledStateIds);
  const matching = states.filter((state) => matchesSearch(query, state.name));
  return [
    ...matching.filter((state) => !disabled.has(state.id)),
    ...matching.filter((state) => disabled.has(state.id)),
  ];
}
