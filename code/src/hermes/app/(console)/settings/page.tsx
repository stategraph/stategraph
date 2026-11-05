"use client";

import { Suspense, useCallback, useEffect, useState } from "react";
import { useSearchParams } from "next/navigation";
import { PageHeader, PageSection, PageSurface } from "@/components/page";
import { useAuth, AuthGuard } from "@/components/auth";
import { canManageUsersInTenant, isInstanceAdmin, isTenantAdmin } from "@/lib/api/capabilities";
import { useDeepLinkRouter, useUrlSyncedParam } from "@/hooks";
import { useTheme, useTenant, useLicense } from "@/contexts";
import { useSettings } from "@/contexts";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { SearchInput } from "@/components/ui/search-input";
import { Avatar } from "@/components/ui/avatar";
import { Sun, Moon, Monitor, RotateCcw, Building2, Mail, Shield, LogOut, User as UserIcon, Key, Copy, Check, Bot, Trash2, ScrollText } from "lucide-react";
import { createApiKey, createApiUser, createTenant, listApiKeys, revokeApiKey, logout, type User, type AccessTokenSummary } from "@/lib/api/client";
import { filterApiKeys } from "@/components/settings/apiKeyFilter";
import { VersionInfo } from "@/components/settings/VersionInfo";
import { PermissionInfo } from "@/components/settings/PermissionInfo";
import { ResourceTypesPanel } from "@/components/settings/ResourceTypesPanel";
import { CreateUserDialog, UsersTable } from "@/components/users";
import { VcsIntegrations } from "@/components/settings/VcsIntegrations";
import { GithubAppPanel } from "@/components/settings/GithubAppPanel";
import { showGithubAppPanel } from "@/lib/getting-started/github-app-panel";
import { MembersPanel } from "@/components/members";
import { tenantCreatedButUnlistedMessage, tenantNameErrorMessage } from "@/lib/api/tenantNameErrors";
import { TenantRename } from "@/components/tenant";
import { PlanSection } from "./PlanSection";
import { track } from "@/lib/analytics";

const SETTINGS_TABS = ["account", "tenant", "api-keys", "preferences", "resource-types", "members", "integrations", "admin"] as const;
type SettingsTab = (typeof SETTINGS_TABS)[number];
const isSettingsTab = (t: string | null): t is SettingsTab =>
  SETTINGS_TABS.includes(t as SettingsTab);

function TokenCard({
  token,
  showOwner,
  revokingId,
  onRevoke,
}: {
  token: AccessTokenSummary;
  showOwner: boolean;
  revokingId: string | null;
  onRevoke: (tokenId: string) => void;
}) {
  return (
    <div className="rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-1)] p-3 space-y-2">
      <div className="flex items-start justify-between gap-2">
        <div className="min-w-0">
          <div className="text-sm font-medium text-[var(--sg-text)] break-all">{token.name}</div>
          {showOwner && (
            <div className="text-xs text-[var(--sg-text-muted)] break-all">{token.owner_name}</div>
          )}
        </div>
        <Button
          variant="outline"
          size="sm"
          onClick={() => onRevoke(token.id)}
          disabled={revokingId === token.id}
          className="gap-1 shrink-0 text-[var(--sg-error)] border-[var(--sg-error)]/30 hover:bg-[var(--sg-error)]/10 hover:border-[var(--sg-error)]"
        >
          <Trash2 className="h-3 w-3" />
          {revokingId === token.id ? "Revoking..." : "Revoke"}
        </Button>
      </div>
      <div className="flex items-center justify-between text-xs">
        <span className="text-[var(--sg-text-muted)]">Created</span>
        <span className="font-mono text-[var(--sg-text-muted)]">
          {new Date(token.created_at).toLocaleDateString()}
        </span>
      </div>
      <div className="flex items-center justify-between text-xs">
        <span className="text-[var(--sg-text-muted)]">Expires</span>
        <span className="font-mono text-[var(--sg-text-muted)]">
          {token.expiration ? new Date(token.expiration).toLocaleDateString() : "Never"}
        </span>
      </div>
    </div>
  );
}

function ApiKeysTab({
  user,
  apiKeys,
  apiKeysLoading,
  apiKey,
  apiKeyName,
  apiKeyLoading,
  apiKeyError,
  apiKeyCopied,
  serviceAccountName,
  serviceAccountToken,
  serviceAccountLoading,
  serviceAccountError,
  serviceAccountCopied,
  revokingId,
  currentTenant,
  setApiKeyName,
  setServiceAccountName,
  handleCreateApiKey,
  handleCopyApiKey,
  handleCreateServiceAccount,
  handleCopyServiceAccountToken,
  handleRevokeApiKey,
  handleDismissApiKey,
  handleDismissServiceAccountToken,
  apiKeysError,
  revokeError,
}: {
  user: User | null;
  apiKeys: AccessTokenSummary[];
  apiKeysLoading: boolean;
  apiKey: string | null;
  apiKeyName: string;
  apiKeyLoading: boolean;
  apiKeyError: string | null;
  apiKeyCopied: boolean;
  apiKeysError: string | null;
  revokeError: string | null;
  serviceAccountName: string;
  serviceAccountToken: string | null;
  serviceAccountLoading: boolean;
  serviceAccountError: string | null;
  serviceAccountCopied: boolean;
  revokingId: string | null;
  currentTenant: { id: string; name: string } | null;
  setApiKeyName: (name: string) => void;
  setServiceAccountName: (name: string) => void;
  handleCreateApiKey: () => void;
  handleCopyApiKey: () => void;
  handleCreateServiceAccount: () => void;
  handleCopyServiceAccountToken: () => void;
  handleRevokeApiKey: (tokenId: string) => void;
  handleDismissApiKey: () => void;
  handleDismissServiceAccountToken: () => void;
}) {
  // Instance admins list every user's keys ("All User API Keys") and get a
  // filter box over that list (#2667). It lives in the URL (`?key_search=`) so
  // a copied link reproduces the filtered view. Everyone else lists only their
  // own keys: no box, and a pasted `?key_search=` is ignored rather than
  // narrowing the list behind their back.
  const [keySearch, setKeySearch] = useUrlSyncedParam("key_search", "");
  const keyFilterShown = isInstanceAdmin(user?.capabilities);
  const userKeys = apiKeys.filter((k) => k.owner_type === "user");
  const serviceKeys = apiKeys.filter((k) => k.owner_type === "api");
  const filteredUserKeys = keyFilterShown ? filterApiKeys(userKeys, keySearch) : userKeys;

  return (
    <>
      {apiKeysError && (
        <PageSection title="">
          <div className="p-3 rounded-lg bg-[var(--sg-error)]/10 border border-[var(--sg-error)]/30">
            <div className="text-sm text-[var(--sg-error)]">{apiKeysError}</div>
          </div>
        </PageSection>
      )}

      {revokeError && (
        <PageSection title="">
          <div className="p-3 rounded-lg bg-[var(--sg-error)]/10 border border-[var(--sg-error)]/30">
            <div className="text-sm text-[var(--sg-error)]">{revokeError}</div>
          </div>
        </PageSection>
      )}

      {/* Create API Key */}
      <PageSection title="Create API Key">
        <PageSurface>
          <div className="space-y-4">
            <div>
              <div className="text-xs text-[var(--sg-text-muted)]">
                Generate an API key for CLI access or CI/CD pipelines. The key will be shown only once.
              </div>
            </div>

            {apiKeyError && (
              <div className="p-3 rounded-lg bg-[var(--sg-error)]/10 border border-[var(--sg-error)]/30">
                <div className="text-sm text-[var(--sg-error)]">{apiKeyError}</div>
              </div>
            )}

            {apiKey ? (
              <div className="space-y-3">
                <div className="p-3 rounded-lg bg-[var(--sg-success)]/10 border border-[var(--sg-success)]/30">
                  <div className="text-sm text-[var(--sg-success)] mb-2">API key created successfully!</div>
                  <div className="text-xs text-[var(--sg-text-muted)] mb-2">
                    Copy this key now. You won&apos;t be able to see it again.
                  </div>
                </div>
                <div className="flex items-center gap-2">
                  <code className="flex-1 min-w-0 p-3 rounded-lg bg-[var(--sg-bg-0)] border border-[var(--sg-border)] text-xs font-mono text-[var(--sg-text)] overflow-x-auto whitespace-nowrap">
                    {apiKey}
                  </code>
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={handleCopyApiKey}
                    className="shrink-0 gap-2"
                  >
                    {apiKeyCopied ? (
                      <>
                        <Check className="h-4 w-4 text-[var(--sg-success)]" />
                        Copied
                      </>
                    ) : (
                      <>
                        <Copy className="h-4 w-4" />
                        Copy
                      </>
                    )}
                  </Button>
                </div>
                <div className="flex items-center justify-between">
                  <div className="text-xs text-[var(--sg-text-muted)]">
                    Use with CLI: <code className="px-1 py-0.5 rounded bg-[var(--sg-bg-0)]">export STATEGRAPH_API_KEY=&quot;...&quot;</code>
                  </div>
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={handleDismissApiKey}
                    className="shrink-0"
                  >
                    Done
                  </Button>
                </div>
              </div>
            ) : (
              <div className="space-y-3">
                <div className="flex items-center gap-2">
                  <input
                    type="text"
                    value={apiKeyName}
                    onChange={(e) => setApiKeyName(e.target.value)}
                    placeholder="e.g., my-laptop, ci-deploy"
                    className="flex-1 min-w-0 px-3 py-2 rounded-lg bg-[var(--sg-bg-0)] border border-[var(--sg-border)] text-sm text-[var(--sg-text)] placeholder:text-[var(--sg-text-dim)] focus:outline-none focus:ring-2 focus:ring-[var(--sg-accent)]/50"
                  />
                  <Button
                    onClick={handleCreateApiKey}
                    disabled={apiKeyLoading || !apiKeyName.trim()}
                    className="gap-2 shrink-0"
                  >
                    <Key className="h-4 w-4" />
                    {apiKeyLoading ? "Creating..." : "Create"}
                  </Button>
                </div>
              </div>
            )}
          </div>
        </PageSurface>
      </PageSection>

      {/* Existing API Keys */}
      {!apiKeysLoading && userKeys.length > 0 && (
        <PageSection title={isInstanceAdmin(user?.capabilities) ? "All User API Keys" : "Your API Keys"}>
          <PageSurface>
            <div className="space-y-3">
              <div className="text-xs text-[var(--sg-text-muted)]">
                {isInstanceAdmin(user?.capabilities)
                  ? "Personal API keys across all users. Token values are never shown after creation."
                  : "API keys belonging to your account. Token values are never shown after creation."}
              </div>
              {keyFilterShown && (
                <SearchInput
                  placeholder="Filter keys by name or owner..."
                  aria-label="Filter API keys"
                  value={keySearch}
                  onChange={(e) => setKeySearch(e.target.value)}
                />
              )}
              <div className="lg:hidden space-y-3">
                {filteredUserKeys.map((token) => (
                  <TokenCard
                    key={token.id}
                    token={token}
                    showOwner
                    revokingId={revokingId}
                    onRevoke={handleRevokeApiKey}
                  />
                ))}
                {filteredUserKeys.length === 0 && (
                  <div className="text-sm text-[var(--sg-text-muted)]">No API keys match.</div>
                )}
              </div>
              <div className="hidden lg:block border border-[var(--sg-border)] rounded-lg overflow-hidden">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="bg-[var(--sg-bg-0)] border-b border-[var(--sg-border)]">
                      <th className="px-3 py-2 text-left text-xs font-medium text-[var(--sg-text-muted)]">Name</th>
                      <th className="px-3 py-2 text-left text-xs font-medium text-[var(--sg-text-muted)]">Owner</th>
                      <th className="px-3 py-2 text-left text-xs font-medium text-[var(--sg-text-muted)]">Created</th>
                      <th className="px-3 py-2 text-left text-xs font-medium text-[var(--sg-text-muted)]">Expires</th>
                      <th className="px-3 py-2 text-right text-xs font-medium text-[var(--sg-text-muted)]"></th>
                    </tr>
                  </thead>
                  <tbody>
                    {filteredUserKeys.map((token) => (
                      <tr key={token.id} className="border-b border-[var(--sg-border)] last:border-b-0">
                        <td className="px-3 py-2 text-[var(--sg-text)]">{token.name}</td>
                        <td className="px-3 py-2 text-[var(--sg-text-muted)]">{token.owner_name}</td>
                        <td className="px-3 py-2 text-[var(--sg-text-muted)] text-xs font-mono">
                          {new Date(token.created_at).toLocaleDateString()}
                        </td>
                        <td className="px-3 py-2 text-[var(--sg-text-muted)] text-xs font-mono">
                          {token.expiration
                            ? new Date(token.expiration).toLocaleDateString()
                            : "Never"}
                        </td>
                        <td className="px-3 py-2 text-right">
                          <Button
                            variant="outline"
                            size="sm"
                            onClick={() => handleRevokeApiKey(token.id)}
                            disabled={revokingId === token.id}
                            className="gap-1 text-[var(--sg-error)] border-[var(--sg-error)]/30 hover:bg-[var(--sg-error)]/10 hover:border-[var(--sg-error)]"
                          >
                            <Trash2 className="h-3 w-3" />
                            {revokingId === token.id ? "Revoking..." : "Revoke"}
                          </Button>
                        </td>
                      </tr>
                    ))}
                    {filteredUserKeys.length === 0 && (
                      <tr>
                        <td colSpan={5} className="px-3 py-6 text-center text-sm text-[var(--sg-text-muted)]">
                          No API keys match.
                        </td>
                      </tr>
                    )}
                  </tbody>
                </table>
              </div>
            </div>
          </PageSurface>
        </PageSection>
      )}

      {/* Service Accounts Section */}
      <PageSection title="Service Accounts">
        <PageSurface>
          <div className="space-y-4">
            <div>
              <div className="text-xs text-[var(--sg-text-muted)]">
                Create a dedicated API identity for CI/CD pipelines. Unlike personal API keys, service accounts
                are separate identities that survive employee turnover and provide clear audit trails.
              </div>
            </div>

            {serviceAccountError && (
              <div className="p-3 rounded-lg bg-[var(--sg-error)]/10 border border-[var(--sg-error)]/30">
                <div className="text-sm text-[var(--sg-error)]">{serviceAccountError}</div>
              </div>
            )}

            {serviceAccountToken ? (
              <div className="space-y-3">
                <div className="p-3 rounded-lg bg-[var(--sg-success)]/10 border border-[var(--sg-success)]/30">
                  <div className="text-sm text-[var(--sg-success)] mb-2">Service account created successfully!</div>
                  <div className="text-xs text-[var(--sg-text-muted)] mb-2">
                    Copy this token now. You won&apos;t be able to see it again.
                  </div>
                </div>
                <div className="flex items-center gap-2">
                  <code className="flex-1 min-w-0 p-3 rounded-lg bg-[var(--sg-bg-0)] border border-[var(--sg-border)] text-xs font-mono text-[var(--sg-text)] overflow-x-auto whitespace-nowrap">
                    {serviceAccountToken}
                  </code>
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={handleCopyServiceAccountToken}
                    className="shrink-0 gap-2"
                  >
                    {serviceAccountCopied ? (
                      <>
                        <Check className="h-4 w-4 text-[var(--sg-success)]" />
                        Copied
                      </>
                    ) : (
                      <>
                        <Copy className="h-4 w-4" />
                        Copy
                      </>
                    )}
                  </Button>
                </div>
                <div className="flex items-center justify-between">
                  <div className="text-xs text-[var(--sg-text-muted)]">
                    Use in CI: <code className="px-1 py-0.5 rounded bg-[var(--sg-bg-0)]">export STATEGRAPH_API_KEY=&quot;...&quot;</code>
                  </div>
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={handleDismissServiceAccountToken}
                    className="shrink-0"
                  >
                    Done
                  </Button>
                </div>
              </div>
            ) : (
              <div className="space-y-3">
                <div className="flex items-center gap-2">
                  <input
                    type="text"
                    value={serviceAccountName}
                    onChange={(e) => setServiceAccountName(e.target.value)}
                    placeholder="e.g., ci-production, github-actions"
                    className="flex-1 min-w-0 px-3 py-2 rounded-lg bg-[var(--sg-bg-0)] border border-[var(--sg-border)] text-sm text-[var(--sg-text)] placeholder:text-[var(--sg-text-dim)] focus:outline-none focus:ring-2 focus:ring-[var(--sg-accent)]/50"
                  />
                  <Button
                    onClick={handleCreateServiceAccount}
                    disabled={serviceAccountLoading || !serviceAccountName.trim() || !currentTenant}
                    className="gap-2 shrink-0"
                  >
                    <Bot className="h-4 w-4" />
                    {serviceAccountLoading ? "Creating..." : "Create"}
                  </Button>
                </div>
                {!currentTenant && (
                  <div className="text-xs text-[var(--sg-warning)]">
                    Select a tenant in Preferences &gt; Workspace to create a service account.
                  </div>
                )}
                {currentTenant && (
                  <div className="text-xs text-[var(--sg-text-dim)]">
                    Will be added to tenant: <span className="text-[var(--sg-text-muted)]">{currentTenant.name}</span>
                  </div>
                )}
              </div>
            )}

            {/* Existing Service Account Keys */}
            {!apiKeysLoading && serviceKeys.length > 0 && (
              <>
              <div className="lg:hidden space-y-3">
                {serviceKeys.map((token) => (
                  <TokenCard
                    key={token.id}
                    token={token}
                    showOwner={false}
                    revokingId={revokingId}
                    onRevoke={handleRevokeApiKey}
                  />
                ))}
              </div>
              <div className="hidden lg:block border border-[var(--sg-border)] rounded-lg overflow-hidden">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="bg-[var(--sg-bg-0)] border-b border-[var(--sg-border)]">
                      <th className="px-3 py-2 text-left text-xs font-medium text-[var(--sg-text-muted)]">Name</th>
                      <th className="px-3 py-2 text-left text-xs font-medium text-[var(--sg-text-muted)]">Created</th>
                      <th className="px-3 py-2 text-left text-xs font-medium text-[var(--sg-text-muted)]">Expires</th>
                      <th className="px-3 py-2 text-right text-xs font-medium text-[var(--sg-text-muted)]"></th>
                    </tr>
                  </thead>
                  <tbody>
                    {serviceKeys.map((token) => (
                      <tr key={token.id} className="border-b border-[var(--sg-border)] last:border-b-0">
                        <td className="px-3 py-2 text-[var(--sg-text)]">{token.name}</td>
                        <td className="px-3 py-2 text-[var(--sg-text-muted)] text-xs font-mono">
                          {new Date(token.created_at).toLocaleDateString()}
                        </td>
                        <td className="px-3 py-2 text-[var(--sg-text-muted)] text-xs font-mono">
                          {token.expiration
                            ? new Date(token.expiration).toLocaleDateString()
                            : "Never"}
                        </td>
                        <td className="px-3 py-2 text-right">
                          <Button
                            variant="outline"
                            size="sm"
                            onClick={() => handleRevokeApiKey(token.id)}
                            disabled={revokingId === token.id}
                            className="gap-1 text-[var(--sg-error)] border-[var(--sg-error)]/30 hover:bg-[var(--sg-error)]/10 hover:border-[var(--sg-error)]"
                          >
                            <Trash2 className="h-3 w-3" />
                            {revokingId === token.id ? "Revoking..." : "Revoke"}
                          </Button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              </>
            )}
          </div>
        </PageSurface>
      </PageSection>
    </>
  );
}

function SettingsPageContent() {
  const router = useDeepLinkRouter();
  // The user comes from AuthProvider rather than a second whoami() call: the sidebar and this
  // page both gate on capabilities, and two independently-fetched copies drift the moment a
  // capability changes -- one would update and the other would not.
  const { isLoading: authLoading, user } = useAuth();
  const { theme, setTheme } = useTheme();
  const { currentTenant, tenants, setCurrentTenant, refreshTenants, isLoading: tenantsLoading } = useTenant();
  const { settings, updateSetting, resetSettings } = useSettings();
  const { licensed, required: licenseRequired, mode } = useLicense();
  // URL-derived: useSearchParams (not a lazy
  // window.location read, which hydrates a different tab than the server
  // rendered) and no local state (which would go stale when the App Router
  // re-renders this page in place with a different ?tab=). Next syncs
  // replaceState back into useSearchParams — but only when the call does NOT
  // pass window.history.state (Next's __NA marker makes it skip the sync as
  // an internal call); hence the null below.
  const searchParams = useSearchParams();
  const urlTab = searchParams.get("tab");
  const activeTab: SettingsTab = isSettingsTab(urlTab) ? urlTab : "account";
  // Settings → Integrations shows a rotated webhook secret once; until it is
  // acknowledged, switching tabs (which unmounts it) is disabled. Switching
  // tenants and App Router navigation cannot be intercepted.
  const [integrationSecretAtRisk, setIntegrationSecretAtRisk] = useState(false);

  const [newTenantName, setNewTenantName] = useState("");
  const [creatingTenant, setCreatingTenant] = useState(false);
  const [createTenantError, setCreateTenantError] = useState<string | null>(null);
  const handleCreateTenant = async () => {
    const name = newTenantName.trim();
    if (!name) return;
    // The button is disabled while a create is in flight; Enter is not, so the guard lives here
    // rather than on one of the two ways in. A second create of the same name comes back 409 and
    // would tell the user their brand new tenant is taken.
    if (creatingTenant) return;
    setCreateTenantError(null);
    setCreatingTenant(true);
    try {
      const created = await createTenant(name);
      track("tenant_created", { new_tenant_id: created.id });
      setNewTenantName("");
      const refreshed = await refreshTenants().catch(() => null);
      if (refreshed?.some((t) => t.id === created.id)) {
        setCurrentTenant(created);
      } else {
        setCreateTenantError(tenantCreatedButUnlistedMessage(created.name));
      }
    } catch (err) {
      setCreateTenantError(tenantNameErrorMessage(err, "Failed to create tenant"));
    } finally {
      setCreatingTenant(false);
    }
  };

  const setActiveTab = (tab: SettingsTab) => {
    if (typeof window === 'undefined') return;
    const url = new URL(window.location.href);
    url.searchParams.set("tab", tab);
    // A picked user (`?user=`) belongs to the list on the tab being left; carry it
    // over and the next tab opens with a details box for an entry it never showed.
    // The API-key filter (`?key_search=`) is scoped the same way: it belongs to
    // the keys list on the tab being left.
    url.searchParams.delete("user");
    url.searchParams.delete("key_search");
    window.history.replaceState(null, '', url.pathname + url.search);
  };

  // API Key creation state (personal)
  const [apiKeyName, setApiKeyName] = useState("");
  const [apiKey, setApiKey] = useState<string | null>(null);
  const [apiKeyLoading, setApiKeyLoading] = useState(false);
  const [apiKeyError, setApiKeyError] = useState<string | null>(null);
  const [apiKeyCopied, setApiKeyCopied] = useState(false);

  // API Key list state
  const [apiKeys, setApiKeys] = useState<AccessTokenSummary[]>([]);
  const [apiKeysLoading, setApiKeysLoading] = useState(true);
  const [apiKeysError, setApiKeysError] = useState<string | null>(null);
  const [revokingId, setRevokingId] = useState<string | null>(null);
  const [revokeError, setRevokeError] = useState<string | null>(null);

  // Service Account creation state
  const [serviceAccountName, setServiceAccountName] = useState("");
  const [serviceAccountToken, setServiceAccountToken] = useState<string | null>(null);
  const [serviceAccountLoading, setServiceAccountLoading] = useState(false);
  const [serviceAccountError, setServiceAccountError] = useState<string | null>(null);
  const [serviceAccountCopied, setServiceAccountCopied] = useState(false);

  // Fetch API keys
  const fetchApiKeys = useCallback(async () => {
    try {
      const response = await listApiKeys();
      setApiKeys(response.tokens);
      setApiKeysError(null);
    } catch (error) {
      console.error("Failed to load API keys:", error);
      setApiKeysError(error instanceof Error ? error.message : "Failed to load API keys");
    } finally {
      setApiKeysLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchApiKeys();
  }, [fetchApiKeys]);

  // Handle revoking an API key
  const handleRevokeApiKey = async (tokenId: string) => {
    if (!window.confirm("Are you sure you want to revoke this API key? This cannot be undone.")) {
      return;
    }
    setRevokingId(tokenId);
    setRevokeError(null);
    try {
      await revokeApiKey(tokenId);
      track("api_key_revoked");
      setApiKeys((prev) => prev.filter((k) => k.id !== tokenId));
    } catch (error) {
      setRevokeError(error instanceof Error ? error.message : "Failed to revoke API key");
    } finally {
      setRevokingId(null);
    }
  };

  // Helper to get display name for user type and auth method
  const getUserTypeDisplay = (user: User) => {
    switch (user.type) {
      case "user":
        // Check if OAuth (has auth_origin) or local auth (no auth_origin)
        return user.auth_origin ? `OAuth User (${user.auth_origin})` : "Local User";
      case "api":
        return "API Key";
      case "system":
        return "System";
      default:
        return user.type;
    }
  };

  // Handle API key creation
  const handleCreateApiKey = async () => {
    setApiKeyLoading(true);
    setApiKeyError(null);
    setApiKey(null);
    setApiKeyCopied(false);

    try {
      const response = await createApiKey({ name: apiKeyName.trim() });
      track("api_key_created", { source: "settings" });
      setApiKey(response.token);
      setApiKeyName("");
      await fetchApiKeys();
    } catch (error) {
      setApiKeyError(error instanceof Error ? error.message : "Failed to create API key");
    } finally {
      setApiKeyLoading(false);
    }
  };

  // Handle copying API key to clipboard
  const handleCopyApiKey = async () => {
    if (!apiKey) return;

    try {
      await navigator.clipboard.writeText(apiKey);
      setApiKeyCopied(true);
      setTimeout(() => setApiKeyCopied(false), 2000);
    } catch {
      // clipboard API may fail if page is not focused
    }
  };

  // Handle service account creation
  const handleCreateServiceAccount = async () => {
    if (!serviceAccountName.trim() || !currentTenant) return;

    setServiceAccountLoading(true);
    setServiceAccountError(null);
    setServiceAccountToken(null);
    setServiceAccountCopied(false);

    try {
      const response = await createApiUser({
        name: serviceAccountName.trim(),
        tenant_id: currentTenant.id,
      });
      track("service_account_created", { source: "settings" });
      setServiceAccountToken(response.token);
      setServiceAccountName("");
      await fetchApiKeys();
    } catch (error) {
      setServiceAccountError(error instanceof Error ? error.message : "Failed to create service account");
    } finally {
      setServiceAccountLoading(false);
    }
  };

  // Handle copying service account token to clipboard
  const handleCopyServiceAccountToken = async () => {
    if (!serviceAccountToken) return;

    try {
      await navigator.clipboard.writeText(serviceAccountToken);
      setServiceAccountCopied(true);
      setTimeout(() => setServiceAccountCopied(false), 2000);
    } catch {
      // clipboard API may fail if page is not focused
    }
  };


  const tabs: { id: SettingsTab; label: string; show: boolean }[] = [
    { id: "account", label: "Account", show: true },
    { id: "tenant", label: "Tenant", show: !!currentTenant },
    { id: "api-keys", label: "API Keys", show: true },
    { id: "preferences", label: "Preferences", show: true },
    // What the tenant's states actually hold, by resource type. Every member can read it:
    // the endpoint enforces membership and nothing more.
    { id: "resource-types", label: "Resource Types", show: !!currentTenant },
    // Tenant membership management: shown to anyone the backend's
    // Sgs_user_session.Caps.manages_tenant_member authorizes for the current tenant --
    // its admin, or a users-manage holder. Distinct
    // from the installation-wide Admin tab below (#1407).
    {
      id: "members",
      label: "Members",
      show:
        !!currentTenant &&
        (isTenantAdmin(user?.capabilities, currentTenant.id) ||
          canManageUsersInTenant(user?.capabilities, currentTenant.id)),
    },
    // The tenant's VCS installations and GitLab credential rotation gate on the current tenant's
    // admin capability; the GitHub App panel on the tab gates on the installation's, so an
    // instance admin reaches the tab with no tenant selected.
    {
      id: "integrations",
      label: "Integrations",
      show:
        (!!currentTenant && isTenantAdmin(user?.capabilities, currentTenant.id)) ||
        !!isInstanceAdmin(user?.capabilities),
    },
    { id: "admin", label: "Admin", show: !!isInstanceAdmin(user?.capabilities) },
  ];

  return (
    <div className="flex flex-col w-full">
      <PageHeader
        title="Settings"
        subtitle="Configure your Stategraph console preferences"
      />

      {/* Tabs */}
      <div className="px-4 sm:px-6 border-b border-[var(--sg-border)]">
        <div className="flex gap-0 overflow-x-auto">
          {tabs.filter(t => t.show).map((tab) => (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              disabled={integrationSecretAtRisk && tab.id !== activeTab}
              className={`shrink-0 whitespace-nowrap px-4 py-2.5 text-sm font-medium border-b-2 transition-colors disabled:opacity-50 disabled:cursor-not-allowed ${
                activeTab === tab.id
                  ? "border-[var(--sg-accent)] text-[var(--sg-accent)]"
                  : "border-transparent text-[var(--sg-text-muted)] hover:text-[var(--sg-text)] hover:border-[var(--sg-text-dim)]"
              }`}
            >
              {tab.label}
            </button>
          ))}
        </div>
      </div>

      {/* Account Tab */}
      {activeTab === "account" && (
        <>
          <PageSection title="Profile">
            <PageSurface>
              {authLoading ? (
                <div className="flex items-center gap-4">
                  <div className="h-16 w-16 rounded-full sg-skeleton-shimmer" />
                  <div className="space-y-2">
                    <div className="h-5 w-32 sg-skeleton-shimmer" />
                    <div className="h-4 w-48 sg-skeleton-shimmer" />
                  </div>
                </div>
              ) : user ? (
                <div className="space-y-4">
                  <div className="flex items-start gap-4">
                    <Avatar user={user} size={64} />
                    <div className="flex-1 min-w-0">
                      <h3 className="text-lg font-semibold text-[var(--sg-text)]">
                        {user.name}
                      </h3>
                      {user.email && (
                        <div className="flex items-center gap-2 mt-1">
                          <Mail className="h-4 w-4 text-[var(--sg-text-muted)]" />
                          <span className="text-sm text-[var(--sg-text-muted)]">
                            {user.email}
                          </span>
                        </div>
                      )}
                      <div className="flex items-center gap-2 mt-1">
                        <Shield className="h-4 w-4 text-[var(--sg-text-muted)]" />
                        <span className="text-sm text-[var(--sg-text-muted)]">
                          {getUserTypeDisplay(user)}
                        </span>
                      </div>
                      <div className="flex items-center gap-2 mt-1">
                        <UserIcon className="h-4 w-4 text-[var(--sg-text-muted)]" />
                        <span className="text-xs text-[var(--sg-text-dim)] font-mono">
                          ID: {user.id}
                        </span>
                      </div>
                    </div>
                  </div>

                  {/* Sign Out Button - only for OAuth users */}
                  {user.type === "user" && (
                    <div className="pt-2">
                      <Button
                        variant="outline"
                        onClick={logout}
                        className="gap-2 text-[var(--sg-error)] border-[var(--sg-error)]/30 hover:bg-[var(--sg-error)]/10 hover:border-[var(--sg-error)]"
                      >
                        <LogOut className="h-4 w-4" />
                        Sign out
                      </Button>
                    </div>
                  )}
                </div>
              ) : (
                <div className="text-sm text-[var(--sg-text-muted)]">
                  Not signed in
                </div>
              )}
            </PageSurface>
          </PageSection>

          {mode === "COMMUNISM" && <PlanSection />}

          {/* License Section: only for a build that needs a license. */}
          {mode !== "COMMUNISM" && licenseRequired && (
          <PageSection title="License">
            <PageSurface>
              <div className="space-y-3">
                <div className="flex items-center gap-3">
                  <ScrollText className="h-5 w-5 text-[var(--sg-text-muted)]" />
                  <div>
                    <div className="text-sm font-semibold text-[var(--sg-text)]">
                      {licensed ? "Licensed" : "No License"}
                    </div>
                    <div className="text-xs text-[var(--sg-text-muted)]">
                      {licensed
                        ? "Active license"
                        : "Enter a license key to activate"}
                    </div>
                  </div>
                </div>
                <div className="pt-2">
                  <Button
                    variant="default"
                    {...router.nav('/settings/license')}
                    className="gap-2"
                  >
                    <ScrollText className="h-4 w-4" />
                    View Details
                  </Button>
                </div>
              </div>
            </PageSurface>
          </PageSection>
          )}

          {/* Version Section — hidden in COMMUNISM mode, where users run on a
              shared hosted substrate and don't self-upgrade. */}
          {mode !== "COMMUNISM" && (
            <PageSection title="Version">
              <PageSurface>
                <VersionInfo />
              </PageSurface>
            </PageSection>
          )}

          {/* Debug aid, opt-in via Preferences > Show Debug Information. Unlike Version, it is not
              hidden in COMMUNISM mode: "why was I refused?" is a question on every deployment. */}
          {settings.showDebugInfo && (
            <PageSection title="Permission">
              <PageSurface>
                <PermissionInfo capabilities={user?.capabilities} />
              </PageSurface>
            </PageSection>
          )}
        </>
      )}

      {/* API Keys Tab */}
      {activeTab === "api-keys" && (
        <ApiKeysTab
          user={user}
          apiKeys={apiKeys}
          apiKeysLoading={apiKeysLoading}
          apiKey={apiKey}
          apiKeyName={apiKeyName}
          apiKeyLoading={apiKeyLoading}
          apiKeyError={apiKeyError}
          apiKeyCopied={apiKeyCopied}
          serviceAccountName={serviceAccountName}
          serviceAccountToken={serviceAccountToken}
          serviceAccountLoading={serviceAccountLoading}
          serviceAccountError={serviceAccountError}
          serviceAccountCopied={serviceAccountCopied}
          revokingId={revokingId}
          currentTenant={currentTenant ? { id: currentTenant.id, name: currentTenant.name } : null}
          setApiKeyName={setApiKeyName}
          setServiceAccountName={setServiceAccountName}
          handleCreateApiKey={handleCreateApiKey}
          handleCopyApiKey={handleCopyApiKey}
          handleCreateServiceAccount={handleCreateServiceAccount}
          handleCopyServiceAccountToken={handleCopyServiceAccountToken}
          handleRevokeApiKey={handleRevokeApiKey}
          apiKeysError={apiKeysError}
          revokeError={revokeError}
          handleDismissApiKey={() => setApiKey(null)}
          handleDismissServiceAccountToken={() => setServiceAccountToken(null)}
        />
      )}

      {/* Preferences Tab */}
      {activeTab === "tenant" && currentTenant && (
        <>
          <PageSection title="Tenant">
            <PageSurface>
              <dl className="grid grid-cols-1 gap-4 sm:grid-cols-[auto_1fr] sm:gap-x-8">
                <dt className="text-sm text-[var(--sg-text-muted)]">Name</dt>
                <dd className="flex items-center gap-2 text-sm font-medium text-[var(--sg-text)]">
                  <span className="break-all">{currentTenant.name}</span>
                  {/* Tenant rename: admin capability only, matching the endpoint's gate
                      (users-manage holders can manage members but not relabel the tenant). */}
                  {isTenantAdmin(user?.capabilities, currentTenant.id) && (
                    <TenantRename tenantId={currentTenant.id} tenantName={currentTenant.name} />
                  )}
                </dd>
                <dt className="text-sm text-[var(--sg-text-muted)]">ID</dt>
                <dd className="font-mono text-sm text-[var(--sg-text)]">{currentTenant.id}</dd>
                <dt className="text-sm text-[var(--sg-text-muted)]">Your role</dt>
                <dd className="text-sm text-[var(--sg-text)]">
                  {isTenantAdmin(user?.capabilities, currentTenant.id) ? "Admin" : "Member"}
                </dd>
              </dl>
            </PageSurface>
          </PageSection>

          {tenants.length > 1 && (
            <PageSection title="Switch tenant">
              <PageSurface>
                <div className="space-y-3">
                  <div className="text-xs text-[var(--sg-text-muted)]">
                    Select the tenant workspace to use across all pages
                  </div>
                  {tenantsLoading ? (
                    <div className="text-sm text-[var(--sg-text-muted)]">Loading tenants...</div>
                  ) : (
                    <Select
                      value={currentTenant.id}
                      onValueChange={(value) => {
                        const tenant = tenants.find((t) => t.id === value);
                        if (tenant) {
                          track("tenant_switched", { to_tenant_id: tenant.id, source: "settings" });
                          setCurrentTenant(tenant);
                        }
                      }}
                    >
                      <SelectTrigger className="w-full sm:w-[300px]" style={{ background: 'var(--sg-bg-2)', borderColor: 'var(--sg-border)' }}>
                        <div className="flex items-center gap-2">
                          <Building2 className="h-4 w-4" style={{ color: 'var(--sg-text-muted)' }} />
                          <SelectValue placeholder="Select a tenant" />
                        </div>
                      </SelectTrigger>
                      <SelectContent>
                        {tenants.map((tenant) => (
                          <SelectItem key={tenant.id} value={tenant.id}>
                            {tenant.name}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  )}
                </div>
              </PageSurface>
            </PageSection>
          )}

          {/* Tenant creation: installation admin only, matching the endpoint's gate. */}
          {isInstanceAdmin(user?.capabilities) && (
            <PageSection title="Create a tenant">
              <PageSurface>
                <div className="space-y-2">
                  <div className="text-xs text-[var(--sg-text-muted)]">
                    A separate workspace with its own states, members, and settings.
                  </div>
                  <div className="flex items-center gap-2">
                    <Input
                      placeholder="New tenant name"
                      value={newTenantName}
                      onChange={(e) => setNewTenantName(e.target.value)}
                      onKeyDown={(e) => { if (e.key === "Enter") void handleCreateTenant(); }}
                      className="w-full sm:w-[300px]"
                    />
                    <Button
                      variant="outline"
                      onClick={() => void handleCreateTenant()}
                      disabled={creatingTenant || !newTenantName.trim()}
                    >
                      Create tenant
                    </Button>
                  </div>
                  {createTenantError && (
                    <div className="mt-2 text-xs text-[var(--sg-error)]">{createTenantError}</div>
                  )}
                </div>
              </PageSurface>
            </PageSection>
          )}
        </>
      )}

      {activeTab === "preferences" && (
        <>
          {/* Appearance Settings */}
          <PageSection title="Appearance">
            <PageSurface>
              <div className="space-y-6">
                {/* Theme Setting */}
                <div className="space-y-3">
                  <div>
                    <div className="text-sm font-semibold text-[var(--sg-text)] mb-1">
                      Theme
                    </div>
                    <div className="text-xs text-[var(--sg-text-muted)]">
                      Choose your preferred color scheme for the console
                    </div>
                  </div>
                  <div className="flex items-center gap-3">
                    <button
                      onClick={() => setTheme('light')}
                      className={`flex flex-col items-center gap-2 p-4 rounded-lg border transition-colors ${
                        theme === 'light'
                          ? 'border-[var(--sg-accent)] bg-[var(--sg-accent-bg)]'
                          : 'border-[var(--sg-border)] hover:border-[var(--sg-text-dim)]'
                      }`}
                    >
                      <Sun className="h-5 w-5" style={{ color: theme === 'light' ? 'var(--sg-accent)' : 'var(--sg-text-muted)' }} />
                      <span className="text-xs font-medium" style={{ color: theme === 'light' ? 'var(--sg-accent)' : 'var(--sg-text)' }}>
                        Light
                      </span>
                    </button>
                    <button
                      onClick={() => setTheme('dark')}
                      className={`flex flex-col items-center gap-2 p-4 rounded-lg border transition-colors ${
                        theme === 'dark'
                          ? 'border-[var(--sg-accent)] bg-[var(--sg-accent-bg)]'
                          : 'border-[var(--sg-border)] hover:border-[var(--sg-text-dim)]'
                      }`}
                    >
                      <Moon className="h-5 w-5" style={{ color: theme === 'dark' ? 'var(--sg-accent)' : 'var(--sg-text-muted)' }} />
                      <span className="text-xs font-medium" style={{ color: theme === 'dark' ? 'var(--sg-accent)' : 'var(--sg-text)' }}>
                        Dark
                      </span>
                    </button>
                    <button
                      onClick={() => setTheme('system')}
                      className={`flex flex-col items-center gap-2 p-4 rounded-lg border transition-colors ${
                        theme === 'system'
                          ? 'border-[var(--sg-accent)] bg-[var(--sg-accent-bg)]'
                          : 'border-[var(--sg-border)] hover:border-[var(--sg-text-dim)]'
                      }`}
                    >
                      <Monitor className="h-5 w-5" style={{ color: theme === 'system' ? 'var(--sg-accent)' : 'var(--sg-text-muted)' }} />
                      <span className="text-xs font-medium" style={{ color: theme === 'system' ? 'var(--sg-accent)' : 'var(--sg-text)' }}>
                        System
                      </span>
                    </button>
                  </div>
                </div>

                <div className="h-px bg-[var(--sg-border)]" />

                {/* Compact Mode Setting */}
                <div className="flex items-center justify-between">
                  <div>
                    <div className="text-sm font-semibold text-[var(--sg-text)] mb-1">
                      Compact Mode
                    </div>
                    <div className="text-xs text-[var(--sg-text-muted)]">
                      Use a denser layout with reduced spacing
                    </div>
                  </div>
                  <button
                    onClick={() => updateSetting('compactMode', !settings.compactMode)}
                    className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors ${
                      settings.compactMode ? 'bg-[var(--sg-accent)]' : 'bg-[var(--sg-bg-0)]'
                    } border border-[var(--sg-border)]`}
                  >
                    <span
                      className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${
                        settings.compactMode ? 'translate-x-6' : 'translate-x-1'
                      }`}
                    />
                  </button>
                </div>
              </div>
            </PageSurface>
          </PageSection>

          {/* Data Display Settings */}
          <PageSection title="Data Display">
            <PageSurface>
              <div className="space-y-6">
                {/* Items Per Page Setting */}
                <div className="space-y-3">
                  <div>
                    <div className="text-sm font-semibold text-[var(--sg-text)] mb-1">
                      Items Per Page
                    </div>
                    <div className="text-xs text-[var(--sg-text-muted)]">
                      Default number of items to display in tables and lists
                    </div>
                  </div>
                  <Select
                    value={settings.itemsPerPage.toString()}
                    onValueChange={(value) => updateSetting('itemsPerPage', parseInt(value))}
                  >
                    <SelectTrigger className="w-full sm:w-[180px]" style={{ background: 'var(--sg-bg-2)', borderColor: 'var(--sg-border)' }}>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="25">25 items</SelectItem>
                      <SelectItem value="50">50 items</SelectItem>
                      <SelectItem value="100">100 items</SelectItem>
                      <SelectItem value="200">200 items</SelectItem>
                    </SelectContent>
                  </Select>
                </div>

                <div className="h-px bg-[var(--sg-border)]" />

                {/* Timezone Setting */}
                <div className="space-y-3">
                  <div>
                    <div className="text-sm font-semibold text-[var(--sg-text)] mb-1">
                      Timezone
                    </div>
                    <div className="text-xs text-[var(--sg-text-muted)]">
                      Display timestamps in local time or UTC
                    </div>
                  </div>
                  <Select
                    value={settings.timezone}
                    onValueChange={(value: 'local' | 'utc') => updateSetting('timezone', value)}
                  >
                    <SelectTrigger className="w-full sm:w-[180px]" style={{ background: 'var(--sg-bg-2)', borderColor: 'var(--sg-border)' }}>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="local">Local Time</SelectItem>
                      <SelectItem value="utc">UTC</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
              </div>
            </PageSurface>
          </PageSection>

          {/* Advanced Settings */}
          <PageSection title="Advanced">
            <PageSurface>
              <div className="space-y-6">
                {/* Show Debug Info */}
                <div className="flex items-center justify-between">
                  <div>
                    <div className="text-sm font-semibold text-[var(--sg-text)] mb-1">
                      Show Debug Information
                    </div>
                    <div className="text-xs text-[var(--sg-text-muted)]">
                      Display technical debug information in the console
                    </div>
                  </div>
                  <button
                    onClick={() => updateSetting('showDebugInfo', !settings.showDebugInfo)}
                    className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors ${
                      settings.showDebugInfo ? 'bg-[var(--sg-accent)]' : 'bg-[var(--sg-bg-0)]'
                    } border border-[var(--sg-border)]`}
                  >
                    <span
                      className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${
                        settings.showDebugInfo ? 'translate-x-6' : 'translate-x-1'
                      }`}
                    />
                  </button>
                </div>

                <div className="h-px bg-[var(--sg-border)]" />

                {/* Confirm Dangerous Actions */}
                <div className="flex items-center justify-between">
                  <div>
                    <div className="text-sm font-semibold text-[var(--sg-text)] mb-1">
                      Confirm Dangerous Actions
                    </div>
                    <div className="text-xs text-[var(--sg-text-muted)]">
                      Require confirmation before destructive operations
                    </div>
                  </div>
                  <button
                    onClick={() => updateSetting('confirmDangerousActions', !settings.confirmDangerousActions)}
                    className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors ${
                      settings.confirmDangerousActions ? 'bg-[var(--sg-accent)]' : 'bg-[var(--sg-bg-0)]'
                    } border border-[var(--sg-border)]`}
                  >
                    <span
                      className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${
                        settings.confirmDangerousActions ? 'translate-x-6' : 'translate-x-1'
                      }`}
                    />
                  </button>
                </div>

                <div className="h-px bg-[var(--sg-border)]" />

                {/* Reset Settings */}
                <div className="space-y-3">
                  <div>
                    <div className="text-sm font-semibold text-[var(--sg-text)] mb-1">
                      Reset All Settings
                    </div>
                    <div className="text-xs text-[var(--sg-text-muted)]">
                      Restore all settings to their default values
                    </div>
                  </div>
                  <Button
                    variant="outline"
                    onClick={() => {
                      if (window.confirm('Are you sure you want to reset all settings to defaults?')) {
                        resetSettings();
                      }
                    }}
                    className="gap-2"
                  >
                    <RotateCcw className="h-4 w-4" />
                    Reset to Defaults
                  </Button>
                </div>
              </div>
            </PageSurface>
          </PageSection>
        </>
      )}

      {/* Resource Types Tab */}
      {activeTab === "resource-types" && currentTenant && (
        <PageSection title={`Resource types in ${currentTenant.name}`}>
          <PageSurface>
            <ResourceTypesPanel tenantId={currentTenant.id} />
          </PageSurface>
        </PageSection>
      )}

      {/* Admin Tab */}
      {activeTab === "members" &&
        currentTenant &&
        (isTenantAdmin(user?.capabilities, currentTenant.id) ||
          canManageUsersInTenant(user?.capabilities, currentTenant.id)) && (
          <PageSection title={`Members of tenant ${currentTenant.name}`}>
            <PageSurface>
              <MembersPanel
                tenantId={currentTenant.id}
                currentUserId={user?.id}
                canGrantAdmin={isTenantAdmin(user?.capabilities, currentTenant.id)}
                canRevokeAnyKeys={isInstanceAdmin(user?.capabilities)}
              />
            </PageSurface>
          </PageSection>
        )}

      {activeTab === "integrations" &&
        showGithubAppPanel({ instanceAdmin: isInstanceAdmin(user?.capabilities), mode }) && (
        <PageSection title="GitHub App">
          <PageSurface>
            <GithubAppPanel />
          </PageSurface>
        </PageSection>
      )}

      {activeTab === "integrations" &&
        currentTenant &&
        isTenantAdmin(user?.capabilities, currentTenant.id) && (
          <PageSection title="VCS Integrations">
            <PageSurface>
              <VcsIntegrations onSecretAtRiskChange={setIntegrationSecretAtRisk} />
            </PageSurface>
          </PageSection>
        )}

      {activeTab === "admin" && isInstanceAdmin(user?.capabilities) && (
        <>
          {/* CreateUserDialog shows no AdminRightsNotice when it grants installation admin: a new
              account has no API key that could retain stale rights. */}
          <PageSection title="Users" actions={<CreateUserDialog />}>
            <PageSurface>
              <UsersTable />
            </PageSurface>
          </PageSection>
        </>
      )}
    </div>
  );
}

export default function SettingsPage() {
  return (
    <Suspense fallback={<div className="text-[var(--sg-text-muted)]">Loading...</div>}>
      <AuthGuard>
        <SettingsPageContent />
      </AuthGuard>
    </Suspense>
  );
}
