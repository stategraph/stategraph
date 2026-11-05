/**
 * The Owners facet shared by the orchestration list screens.
 *
 * A tenant may link many installations across BOTH providers, and a GitHub
 * installation targets exactly one account — so the repo `owner` column is the
 * organization name. Facet values carry the provider (`github:acme`) because
 * the same slug can exist on both providers; labels disambiguate only the
 * provider since two providers' owners can collide while one provider's
 * owners cannot.
 */

import { providerName, type VcsProvider } from "@/lib/vcs/links";
import { VCS_PROVIDERS } from "@/lib/mql/providers";

export interface ProviderOwner {
  provider: VcsProvider;
  owner: string;
}

export function ownerKey(provider: string, owner: string): string {
  return `${provider}:${owner}`;
}

/** The provider and owner a facet value names; null for "" (all owners) and
 *  for a value naming no known provider, such as a hand-edited `?owner=acme`. */
export function parseOwnerKey(value: string): ProviderOwner | null {
  const sep = value.indexOf(":");
  if (sep <= 0) return null;
  const provider = VCS_PROVIDERS.find((p) => p === value.slice(0, sep));
  const owner = value.slice(sep + 1);
  return provider && owner ? { provider, owner } : null;
}

/** Distinct (provider, owner) pairs as facet options, sorted by owner then
 *  provider. Empty owners are dropped. */
export function ownerFacetOptions(rows: ProviderOwner[]): { label: string; value: string }[] {
  const seen = new Map<string, ProviderOwner>();
  for (const r of rows) {
    if (!r.owner) continue;
    seen.set(ownerKey(r.provider, r.owner), r);
  }
  return [...seen.values()]
    .sort((a, b) => a.owner.localeCompare(b.owner) || a.provider.localeCompare(b.provider))
    .map((r) => ({ label: `${r.owner} (${providerName(r.provider)})`, value: ownerKey(r.provider, r.owner) }));
}

/** True when the row matches the selected facet value ("" selects all). */
export function matchesOwner(selected: string, provider: string, owner: string): boolean {
  return selected === "" || selected === ownerKey(provider, owner);
}

/** Group composite `owner/name` repo options by owner for a two-org tenant's
 *  repo dropdown; with one group the flat list is kept. */
export function groupRepoOptions(
  repos: { provider: VcsProvider; owner: string; name: string }[],
): { label: string; options: { label: string; value: string }[] }[] {
  const byOwner = new Map<string, { label: string; value: string }[]>();
  for (const r of repos) {
    if (!r.owner || !r.name) continue;
    const g = `${r.owner} (${providerName(r.provider)})`;
    const opts = byOwner.get(g) ?? [];
    const value = `${r.owner}/${r.name}`;
    if (!opts.some((o) => o.value === value)) opts.push({ label: r.name, value });
    byOwner.set(g, opts);
  }
  return [...byOwner.entries()]
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([label, options]) => ({ label, options: options.sort((a, b) => a.label.localeCompare(b.label)) }));
}
