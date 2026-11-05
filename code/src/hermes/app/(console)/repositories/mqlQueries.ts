import { asText, MQL_MAX_LIMIT } from "@/lib/mql/providers";
import type { VcsProvider } from "@/lib/vcs/links";

export const REPOS_CAP = Math.min(1000, MQL_MAX_LIMIT);

/** github_installation_repositories has no created_at (gitlab's does), so the
 *  provider-neutral projection uses updated_at, present on both. */
export function repositoriesQuery(provider: VcsProvider): string {
  return `select id, installation_id, name, owner, updated_at from ${provider}_installation_repositories order by name limit ${REPOS_CAP}`;
}

export interface RepoRow {
  provider: VcsProvider;
  id: string;
  name: string;
  owner: string;
  installation: string;
  updatedAt: string;
}

export function mapRepoRow(provider: VcsProvider, raw: unknown): RepoRow {
  const o = raw as Record<string, unknown>;
  return {
    provider,
    id: asText(o.id),
    name: asText(o.name),
    owner: asText(o.owner),
    installation: asText(o.installation_id),
    updatedAt: asText(o.updated_at),
  };
}
