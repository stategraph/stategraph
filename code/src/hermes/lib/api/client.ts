// Stategraph API Client
// All types derived from api_schemas/stategraph/api.json via openapi-typescript

import type { components } from "./types-generated";
import { parseLinkHeader, hasNextPage } from "./pagination";

// ============================================================================
// SCHEMA TYPES (re-exported from generated types)
// ============================================================================

// Flexible attribute map used by the UI. The OpenAPI spec leaves attributes
// untyped, so we expose a string index and a few known optional fields that
// components rely on.
export type InstanceAttributes = {
  tags?: Record<string, string>;
  availability_zone?: string;
  zone?: string;
  arn?: string;
  name?: string;
  region?: string;
  location?: string;
  azure_location?: string;
  aws_region?: string;
  gcp_region?: string;
  [key: string]: unknown;
};

export type User = components["schemas"]["user"];
export type Tenant = components["schemas"]["tenant"];
export type State = components["schemas"]["state"] & {
  updated_at?: string;
};
export type StateSummary = components["schemas"]["state-summary"];
export type ResourcesSummary = components["schemas"]["resources-summary"];
export type Instance = components["schemas"]["instance"] & {
  attributes?: InstanceAttributes;
  sensitive_attributes?: InstanceAttributes;
  state_id?: string;
  state_name?: string;
};
export type InstancesResponse = {
  results: Instance[];
};
export type BlastRadiusNode = components["schemas"]["blast-radius-node"];
export type BlastRadiusEdge = components["schemas"]["blast-radius-edge"];
export type InstanceBlastRadiusResponse = components["schemas"]["instance-blast-radius"];
/** Derived by indexed access so they track the schema rather than restating it. */
export type BlastRadiusEdgeKind = BlastRadiusEdge["kind"];
export type Module = components["schemas"]["module"];
export type ModulesResponse = components["schemas"]["modules"];
export type UserTenantsResponse = components["schemas"]["user-tenants"];
export type TenantStatesResponse = components["schemas"]["tenant-states"];
export type Transaction = components["schemas"]["tx"];
export type TransactionsResponse = components["schemas"]["txs"];
export type AdminRights = components["schemas"]["admin-rights"];
export type UsersListResponse = components["schemas"]["users-list-response"];
export type UserDetailResponse = components["schemas"]["user-detail-response"];
export type UserCreateRequest = components["schemas"]["user-create-request"];
export type UserCreateResponse = components["schemas"]["user-create-response"];
export type UserUpdateRequest = components["schemas"]["user-update-request"];
export type UserUpdateResponse = components["schemas"]["user-update-response"];
export type UserDeleteResponse = components["schemas"]["user-delete-response"];
export type UserChangePasswordRequest = components["schemas"]["user-change-password-request"];
export type UserChangePasswordResponse = components["schemas"]["user-change-password-response"];
export type UserSetInstanceAdminRequest = components["schemas"]["user-set-instance-admin-request"];
export type UserSetInstanceAdminResponse = components["schemas"]["user-set-instance-admin-response"];
export type TransactionLog = components["schemas"]["tx_log"];
export type TransactionLogsResponse = components["schemas"]["tx_logs"];
export type VersionResponse = components["schemas"]["version-response"];
export type SetupAdminResponse = components["schemas"]["setup-admin-response"];
export type LoginPasswordResponse = components["schemas"]["login-password-response"];
export type TenantSummary = components["schemas"]["tenant-summary"];
export type TenantResourceTypes = components["schemas"]["tenant-resource-types"];
export type DedicatedCreateRequest = components["schemas"]["dedicated-stategraph-create-request"];
export type Dedicated = components["schemas"]["dedicated-stategraph"];
export type DedicatedStategraphsResponse = components["schemas"]["dedicated-stategraphs-response"];
export type DedicatedHandoff = components["schemas"]["dedicated-stategraph-handoff-response"];
export type DedicatedRegionsResponse = components["schemas"]["dedicated-stategraph-regions-response"];

export interface GitHubRelease {
  tag_name: string;
  html_url: string;
  published_at: string;
  prerelease: boolean;
}

// ============================================================================
// API CLIENT
// ============================================================================

// ============================================================================
// Runtime session expiry
// ============================================================================

// A 401 after the app is already authenticated means the session was lost mid-use
// (expired or revoked server-side). A 401 means *only* "no session": it is answered by
// the session middleware before an endpoint runs, so nothing past that point may use it.
// Capability denials are 403; a state or transaction that does not exist, or is in a
// tenant we are not in, is 404 (Sgs_common.respond_state_access_err) — notably a stale
// deep link to a deleted state, which must not log anyone out. So any 401 reaching here
// is a genuine session loss, not an authorization refusal. The app registers a handler
// (AuthProvider) that re-authenticates instead of leaving a dead screen.
type SessionExpiredHandler = () => void;
let sessionExpiredHandler: SessionExpiredHandler | null = null;

/** Register the handler invoked when a request fails with 401 (session gone). Pass null to clear. */
export function setSessionExpiredHandler(fn: SessionExpiredHandler | null): void {
  sessionExpiredHandler = fn;
}

/**
 * Get the API base URL.
 * - Uses NEXT_PUBLIC_API_BASE env var if set (baked into build at build time)
 * - Defaults to http://localhost:8080 in development mode
 * - Uses current browser origin in production (for static builds deployed to production)
 */
export const getApiBase = () => {
  if (process.env.NEXT_PUBLIC_API_BASE) {
    return process.env.NEXT_PUBLIC_API_BASE;
  }

  // In development mode, default to backend on port 8080
  if (process.env.NODE_ENV === 'development') {
    return 'http://localhost:8080';
  }

  // In production, use same origin as frontend
  return typeof window !== 'undefined' ? window.location.origin : '';
};

/**
 * Core fetch function with retry logic for API calls.
 * Returns both data and headers to support pagination.
 */
/**
 * RequestInit plus `sensitive`: the response body carries a credential the
 * server hands out exactly once (an access token, a webhook secret), so the
 * debug log must not echo it — the devtools console buffer, console exports
 * and logging extensions all outlive the screen that shows it once.
 * `noRetry`: the request is one-shot, so it is never re-sent after a network
 * error; a 401 is still retried, since the session gate refuses it before the
 * endpoint runs.
 */
type FetchOptions = RequestInit & { sensitive?: boolean; noRetry?: boolean };

async function fetchAPICore<T>(
  path: string,
  options?: FetchOptions
): Promise<{ data: T; status: number; linkHeader: string | null; headers: Headers }> {
  const { sensitive, noRetry, ...init } = options ?? {};
  const maxRetries = 3;
  const baseDelay = 100;
  const url = `${getApiBase()}${path}`;
  console.log(`[fetchAPI] ${init.method || 'GET'} ${url}`);

  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      const response = await fetch(url, {
        ...init,
        credentials: 'include',
        headers: {
          'Content-Type': 'application/json',
          ...init.headers,
        },
      });

      if (!response.ok) {
        if (response.status === 401 && attempt < maxRetries - 1) {
          const delay = baseDelay * Math.pow(2, attempt);
          console.log(`[fetchAPI] 401 error, retrying in ${delay}ms (attempt ${attempt + 1}/${maxRetries})`);
          await new Promise(resolve => setTimeout(resolve, delay));
          continue;
        }

        // Retries for 401 are exhausted at this point (the continue above handles the
        // earlier attempts), so a 401 here is a settled session loss: notify the app.
        if (response.status === 401 && sessionExpiredHandler) {
          sessionExpiredHandler();
        }

        let errorMessage = `API error: ${response.status} ${response.statusText}`;
        let errorBody: unknown = null;
        try {
          errorBody = await response.json();
          console.error('[API Error Body]', errorBody);
          const b = errorBody as { id?: string; data?: string } | null;
          if (b?.id) errorMessage += ` - ${b.id}`;
          if (b?.data) errorMessage += `: ${b.data}`;
        } catch {
          // If body parsing fails, just use the status text
        }

        const err = new Error(errorMessage) as Error & {
          status: number;
          body: unknown;
        };
        err.status = response.status;
        err.body = errorBody;
        throw err;
      }

      // 204 No Content has no body; callers that use this status (e.g.
      // DELETE) get `null` as the generic data slot. Don't call .json()
      // on an empty body — it throws SyntaxError on every runtime.
      const data =
        response.status === 204 || response.headers.get('content-length') === '0'
          ? (null as unknown as T)
          : ((await response.json()) as T);
      if (sensitive) console.log(`[fetchAPI] Response: <redacted>`);
      else console.log(`[fetchAPI] Response:`, data);

      return {
        data,
        status: response.status,
        linkHeader: response.headers.get('link'),
        headers: response.headers,
      };
    } catch (error) {
      // One-shot endpoints (e.g. GitLab provisioning) must not re-POST on a
      // network error: the first attempt may have committed server-side.
      if (!noRetry && attempt < maxRetries - 1 && error instanceof TypeError) {
        const delay = baseDelay * Math.pow(2, attempt);
        console.log(`[fetchAPI] Network error, retrying in ${delay}ms (attempt ${attempt + 1}/${maxRetries})`);
        await new Promise(resolve => setTimeout(resolve, delay));
        continue;
      }
      throw error;
    }
  }

  throw new Error('API request failed after retries');
}

async function fetchAPI<T>(path: string, options?: FetchOptions): Promise<T> {
  const result = await fetchAPICore<T>(path, options);
  return result.data;
}

/**
 * Like fetchAPI but returns both data and headers for pagination support.
 */
async function fetchAPIWithHeaders<T>(
  path: string,
  options?: RequestInit
): Promise<{ data: T; status: number; linkHeader: string | null; headers: Headers }> {
  return fetchAPICore<T>(path, options);
}

/**
 * Check if we're authenticated by calling whoami.
 * Returns the user if authenticated, null otherwise.
 */
export async function checkAuth(): Promise<User | null> {
  try {
    console.log('[checkAuth] Checking authentication via /api/v1/whoami');
    const user = await whoami();
    console.log('[checkAuth] ✓ Already authenticated! User:', user);
    return user;
  } catch (_error) {
    console.log('[checkAuth] Not authenticated yet');
    return null;
  }
}

/**
 * Initialize authentication by setting the session cookie.
 * This is a fallback used when checkAuth() returns null.
 *
 * @param sessionId - JWT session token from backend
 * @returns true if cookie was set successfully
 */
export async function initializeAuth(sessionId: string): Promise<boolean> {
  try {
    const url = `${getApiBase()}/api/v1/auth/set-cookie?session-id=${sessionId}`;
    console.log('[initializeAuth] Setting session cookie');

    const response = await fetch(url, { credentials: 'include' });

    if (!response.ok) {
      const text = await response.text();
      console.error('[initializeAuth] Failed to set cookie:', text);
      return false;
    }

    console.log('[initializeAuth] ✓ Cookie set successfully');
    return true;
  } catch (error) {
    console.error('[initializeAuth] Exception:', error);
    return false;
  }
}

/**
 * Sign out: forget the persisted session id, then navigate to GET /api/v1/logout, which clears the
 * session cookies and redirects to the login page.
 *
 * The stored session id must go first: AuthProvider exchanges it for a new cookie on the next visit.
 * `?prompt=1` keeps the login page from auto-forwarding back to the IdP, whose session usually
 * outlives ours and would undo the logout.
 */
export function logout(): void {
  localStorage.removeItem('stategraph-session-id');
  // In development, use full origin (frontend on :3000, backend on :8080)
  // In production, use relative path to avoid port number issues with reverse proxies
  const loginUrl = process.env.NODE_ENV === 'development'
    ? `${window.location.origin}/login?prompt=1`
    : '/login?prompt=1';
  // eslint-disable-next-line @next/next/no-location-assign-relative-destination -- backend endpoint, not a Next.js page: full-page navigation is required
  window.location.href = `${getApiBase()}/api/v1/logout?rd=${encodeURIComponent(loginUrl)}`;
}

/**
 * @deprecated Use checkAuth() instead - it returns the user directly
 */
export async function isAuthenticated(): Promise<boolean> {
  const user = await checkAuth();
  return user !== null;
}

// ============================================================================
// LICENSE
// ============================================================================

export type LicenseStatusResponse = components["schemas"]["license-status-response"];
export type LicenseResponse = components["schemas"]["license-response"];

/**
 * GET /api/v1/license/status - Get current license status
 */
export async function getLicenseStatus(): Promise<LicenseStatusResponse> {
  const response = await fetch(`${getApiBase()}/api/v1/license/status`, {
    credentials: 'include',
  });

  if (!response.ok) {
    throw new Error(`License status check failed: ${response.status}`);
  }

  return response.json();
}

/**
 * POST /api/v1/license - Apply a license key
 */
export async function submitLicense(licenseKey: string): Promise<LicenseResponse> {
  const response = await fetch(`${getApiBase()}/api/v1/license`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    credentials: 'include',
    body: JSON.stringify({ license_key: licenseKey }),
  });

  if (!response.ok) {
    const body = (await response.json().catch(() => null)) as
      | { id?: string; data?: string }
      | null;
    throw new Error(body?.data || response.statusText || 'Invalid license key');
  }

  return response.json();
}

// ============================================================================
// SETUP STATUS
// ============================================================================

export type SetupStatusResponse = components["schemas"]["setup-status-response"];

/** GET /api/v1/setup/status - Check if initial setup/registration is needed */
export async function getSetupStatus(): Promise<SetupStatusResponse> {
  const response = await fetch(`${getApiBase()}/api/v1/setup/status`, {
    credentials: 'include',
  });
  if (!response.ok) {
    throw new Error(`Setup status check failed: ${response.status}`);
  }
  return response.json();
}

// ============================================================================
// LOGIN OPTIONS (check for OAuth providers vs local auth mode)
// ============================================================================

export type LoginOption = components["schemas"]["login-option"];
export type LoginOptionsResponse = components["schemas"]["login-options"];

/**
 * GET /api/v1/login/options - Get available login options (OAuth providers or local auth)
 * If options array is empty, we're in local auth mode (password-based)
 */
export async function getLoginOptions(): Promise<LoginOptionsResponse> {
  const response = await fetch(`${getApiBase()}/api/v1/login/options`, {
    credentials: 'include',
  });
  if (!response.ok) {
    throw new Error(`Failed to fetch login options: ${response.status}`);
  }
  return response.json();
}

// ============================================================================
// REGISTRATION
// ============================================================================

/**
 * Create first admin user in local auth mode (POST /api/v1/setup/admin)
 */
export async function createAdminUser(
  email: string,
  password: string,
  name?: string,
  organization?: string
): Promise<SetupAdminResponse> {
  const response = await fetch(`${getApiBase()}/api/v1/setup/admin`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password, name, organization }),
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(error || 'Failed to create admin user');
  }

  return response.json();
}

/** POST /api/v1/setup/magic-claim — admin bootstrap via signed token. */
export type MagicClaimErrorBody = components["schemas"]["error-response"];
export async function claimMagicLink(
  token: string,
  password: string,
): Promise<SetupAdminResponse> {
  const response = await fetch(`${getApiBase()}/api/v1/setup/magic-claim`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ token, password }),
  });

  if (!response.ok) {
    // Try to surface the structured error so the page can fork on
    // codes like SETUP_ALREADY_COMPLETE / MAGIC_TOKEN_EXPIRED.
    const body = (await response.json().catch(() => null)) as MagicClaimErrorBody | null;
    const err = new Error(body?.data || body?.id || 'Magic-link claim failed') as Error & {
      status: number;
      code?: string;
    };
    err.status = response.status;
    if (body?.id) err.code = body.id;
    throw err;
  }

  return response.json();
}

/**
 * Login with email and password in local auth mode (POST /api/v1/login/password)
 */
export async function loginWithPassword(
  email: string,
  password: string
): Promise<LoginPasswordResponse> {
  const response = await fetch(`${getApiBase()}/api/v1/login/password`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    credentials: 'include',
    body: JSON.stringify({ email, password }),
  });

  if (!response.ok) {
    const error = await response.json().catch(() => ({ error: 'Login failed' }));
    throw new Error(error.error || 'Invalid credentials');
  }

  return response.json();
}

// ============================================================================
// API FUNCTIONS (only endpoints from api.json)
// ============================================================================

/** GET /api/v1/whoami */
export async function whoami(): Promise<User> {
  return fetchAPI<User>('/api/v1/whoami');
}

/** GET /api/v1/user/tenants */
export async function getUserTenants(): Promise<UserTenantsResponse> {
  return fetchAPI<UserTenantsResponse>('/api/v1/user/tenants');
}

// ---------- Dedicated Stategraph (Aegis proxy) ----------

/** POST /api/v1/dedicated-stategraphs — provision a dedicated Stategraph instance. */
export async function createDedicated(body: DedicatedCreateRequest): Promise<Dedicated> {
  return fetchAPI<Dedicated>('/api/v1/dedicated-stategraphs', {
    method: 'POST',
    body: JSON.stringify(body),
  });
}

/** GET /api/v1/dedicated-stategraphs — list dedicated instances owned by the calling user. */
export async function listDedicatedStategraphs(): Promise<DedicatedStategraphsResponse> {
  return fetchAPI<DedicatedStategraphsResponse>('/api/v1/dedicated-stategraphs');
}

/** GET /api/v1/dedicated-stategraphs/{id} — poll the provisioning status of one instance. */
export async function getDedicated(id: string): Promise<Dedicated> {
  return fetchAPI<Dedicated>(`/api/v1/dedicated-stategraphs/${encodeURIComponent(id)}`);
}

/** POST /api/v1/dedicated-stategraphs/{id}/handoff — mint a magic-link URL for the new instance. */
export async function getDedicatedHandoff(id: string): Promise<DedicatedHandoff> {
  return fetchAPI<DedicatedHandoff>(
    `/api/v1/dedicated-stategraphs/${encodeURIComponent(id)}/handoff`,
    { method: 'POST' },
  );
}

/**
 * DELETE /api/v1/dedicated-stategraphs/{id} — destroy a dedicated instance.
 *
 * Aegis tears down substrate (database, service, DNS, TLS) and removes the row. The slug stays
 * reserved on Aegis for ~5 minutes after destroy so the same name can't be claimed mid-teardown.
 */
export async function deleteDedicated(id: string): Promise<void> {
  await fetchAPI<null>(`/api/v1/dedicated-stategraphs/${encodeURIComponent(id)}`, {
    method: 'DELETE',
  });
}

/** GET /api/v1/dedicated-stategraph-regions — list regions a dedicated instance can be provisioned in. */
export async function listDedicatedRegions(): Promise<DedicatedRegionsResponse> {
  return fetchAPI<DedicatedRegionsResponse>('/api/v1/dedicated-stategraph-regions');
}

/** GET /api/v1/tenants/{tenant_id}/states */
export async function getTenantStates(tenantId: string): Promise<TenantStatesResponse> {
  return fetchAPI<TenantStatesResponse>(`/api/v1/tenants/${tenantId}/states`);
}

/** GET /api/v1/tenants/{tenant_id}/summary */
export async function getTenantSummary(tenantId: string, stateId?: string): Promise<TenantSummary> {
  const params = stateId ? `?state_id=${encodeURIComponent(stateId)}` : '';
  return fetchAPI<TenantSummary>(`/api/v1/tenants/${tenantId}/summary${params}`);
}

/** GET /api/v1/tenants/{tenant_id}/resource-types */
export async function getTenantResourceTypes(
  tenantId: string,
  stateId?: string,
): Promise<TenantResourceTypes> {
  const params = stateId ? `?state_id=${encodeURIComponent(stateId)}` : '';
  return fetchAPI<TenantResourceTypes>(`/api/v1/tenants/${tenantId}/resource-types${params}`);
}

/** GET /api/v1/states/{state_id}/summary */
export async function getStateSummary(stateId: string): Promise<StateSummary> {
  return fetchAPI<StateSummary>(`/api/v1/states/${stateId}/summary`);
}

/** GET /api/v1/states/{state_id}/resources/summary */
export async function getStateResourcesSummary(stateId: string): Promise<ResourcesSummary> {
  return fetchAPI<ResourcesSummary>(`/api/v1/states/${stateId}/resources/summary`);
}

/** GET /api/v1/states/{state_id}/instances */
export async function getStateInstances(
  stateId: string,
  options?: {
    page?: string[];
    q?: string;
    tz?: string;
    limit?: number;
  }
): Promise<{ data: InstancesResponse; linkHeader: string | null }> {
  const params = new URLSearchParams();

  if (options?.page) {
    options.page.forEach(p => params.append('page', p));
  }
  if (options?.q) {
    params.append('q', options.q);
  }
  if (options?.tz) {
    params.append('tz', options.tz);
  }
  if (options?.limit) {
    params.append('limit', options.limit.toString());
  }

  const queryString = params.toString();
  const path = `/api/v1/states/${stateId}/instances${queryString ? `?${queryString}` : ''}`;

  return fetchAPIWithHeaders<InstancesResponse>(path);
}

export type TenantCosts = components["schemas"]["tenant-costs"];
export type TenantCostState = components["schemas"]["tenant-cost-state"];
export type CostBreakdownEntry = components["schemas"]["cost-breakdown-entry"];
export type TenantCostHistory = components["schemas"]["tenant-cost-history"];
export type TenantCostHistoryPoint = components["schemas"]["tenant-cost-history-point"];
export type TenantCostTagKeys = components["schemas"]["tenant-cost-tag-keys"];

/** GET /api/v1/tenants/{tenant_id}/costs */
export async function getTenantCosts(
  tenantId: string,
  options?: { tag_key?: string }
): Promise<TenantCosts> {
  const params = new URLSearchParams();
  if (options?.tag_key) params.append("tag_key", options.tag_key);
  const queryString = params.toString();
  const path = `/api/v1/tenants/${encodeURIComponent(tenantId)}/costs${queryString ? `?${queryString}` : ""}`;
  return fetchAPI<TenantCosts>(path);
}

/** GET /api/v1/tenants/{tenant_id}/costs/history */
export async function getTenantCostHistory(
  tenantId: string,
  options?: {
    from?: string;
    to?: string;
    group_by?: "provider" | "type" | "tag";
    tag_key?: string;
  }
): Promise<TenantCostHistory> {
  const params = new URLSearchParams();
  if (options?.from) params.append("from", options.from);
  if (options?.to) params.append("to", options.to);
  if (options?.group_by) params.append("group_by", options.group_by);
  if (options?.tag_key) params.append("tag_key", options.tag_key);
  const queryString = params.toString();
  const path = `/api/v1/tenants/${encodeURIComponent(tenantId)}/costs/history${queryString ? `?${queryString}` : ""}`;
  return fetchAPI<TenantCostHistory>(path);
}

/** GET /api/v1/tenants/{tenant_id}/costs/tag-keys */
export async function getTenantCostTagKeys(tenantId: string): Promise<TenantCostTagKeys> {
  return fetchAPI<TenantCostTagKeys>(
    `/api/v1/tenants/${encodeURIComponent(tenantId)}/costs/tag-keys`
  );
}

// ============================================================================
// Actual (FOCUS) spend: attribution coverage + the unmanaged-spend list.
// These are billed facts from the tenant's FOCUS billing exports, distinct
// from the estimated rollup above; they back the "Actual" basis of the cost
// pages. Configure sources via the billing-sources endpoints below.
// ============================================================================

export type TenantCostAttribution = components["schemas"]["tenant-cost-attribution"];
export type TenantCostAttributionProvider =
  components["schemas"]["tenant-cost-attribution-provider"];
export type TenantCostUnmanaged = components["schemas"]["tenant-cost-unmanaged"];
export type TenantCostUnmanagedEntry = components["schemas"]["tenant-cost-unmanaged-entry"];

/**
 * GET /api/v1/tenants/{tenant_id}/costs/attribution -- attribution coverage
 * for the tenant's actual (FOCUS) spend: billed cost split into attributed /
 * unmanaged / unallocated, whole-tenant and per provider, with the
 * cost-weighted coverage percent and the charge-period window the totals
 * cover.
 */
export async function getTenantCostAttribution(
  tenantId: string
): Promise<TenantCostAttribution> {
  return fetchAPI<TenantCostAttribution>(
    `/api/v1/tenants/${encodeURIComponent(tenantId)}/costs/attribution`
  );
}

/**
 * GET /api/v1/tenants/{tenant_id}/costs/unmanaged -- the resources the bill
 * names that match no managed resource, one entry per (resource_id, provider)
 * with summed billed cost. Cursor-paginated via the Link header (see
 * {@link parseLinkHeader}), ordered by (resource_id, provider).
 */
export async function getTenantCostUnmanaged(
  tenantId: string,
  options?: { page?: string[]; limit?: number }
): Promise<{ data: TenantCostUnmanaged; linkHeader: string | null }> {
  const params = new URLSearchParams();
  if (options?.page) {
    options.page.forEach((p) => params.append("page", p));
  }
  if (options?.limit) {
    params.append("limit", options.limit.toString());
  }
  const queryString = params.toString();
  const path = `/api/v1/tenants/${encodeURIComponent(tenantId)}/costs/unmanaged${queryString ? `?${queryString}` : ""}`;
  return fetchAPIWithHeaders<TenantCostUnmanaged>(path);
}

export type Capabilities = components["schemas"]["capabilities"];
export type CostAvailability = components["schemas"]["costs-availability"];
export type DedicatedAvailability = components["schemas"]["dedicated-availability"];
export type SecurityAvailability = components["schemas"]["security-availability"];

/** GET /api/v1/capabilities -- server capability flags. Designed to grow:
 *  new feature flags become new fields on the response, so per-feature
 *  selectors live on top of this single endpoint (see useCostAvailability). */
export async function getCapabilities(): Promise<Capabilities> {
  return fetchAPI<Capabilities>("/api/v1/capabilities");
}

// ============================================================================
// Per-state security: the latest current scan's findings (with graph-derived
// enrichment) plus a severity/coverage summary. Back the Security Findings
// page. Both endpoints degrade cleanly to a 200 with empty/zeroed data when a
// state has never been scanned, and 503 when security is disabled server-side.
// ============================================================================

export type SecurityStateFindings = components["schemas"]["security-state-findings"];
export type SecurityFinding = components["schemas"]["security-finding"];
export type SecurityFindingsSummary = components["schemas"]["security-findings-summary"];
export type SecurityScan = components["schemas"]["security-scan"];

/**
 * GET /api/v1/states/{state_id}/security/findings -- the latest current scan
 * for a state plus its findings. `severity` filters to a single effective
 * severity; `limit` caps the first page (pagination is via Link header, which
 * the Findings page does not yet follow).
 */
export async function getStateSecurityFindings(
  stateId: string,
  opts?: { severity?: string; limit?: number }
): Promise<SecurityStateFindings> {
  const params = new URLSearchParams();
  if (opts?.severity) params.set("severity", opts.severity);
  if (typeof opts?.limit === "number") params.set("limit", String(opts.limit));
  const qs = params.toString();
  return fetchAPI<SecurityStateFindings>(
    `/api/v1/states/${encodeURIComponent(stateId)}/security/findings${qs ? `?${qs}` : ""}`
  );
}

/**
 * GET /api/v1/states/{state_id}/security/findings/summary -- severity
 * breakdown, internet-reachable count, and top checks for the state's latest
 * current scan.
 */
export async function getStateSecurityFindingsSummary(
  stateId: string
): Promise<SecurityFindingsSummary> {
  return fetchAPI<SecurityFindingsSummary>(
    `/api/v1/states/${encodeURIComponent(stateId)}/security/findings/summary`
  );
}

/**
 * POST /api/v1/states/{state_id}/security/scan -- trigger a fresh current
 * security scan for a state. Returns the async {@link Task} (202); poll it with
 * {@link getTask} / `pollTask`. The scan runs in the background and writes a new
 * scan row when done. 503 when security is disabled server-side (callers gate on
 * the security capability, so that is not expected in normal use).
 */
export async function triggerStateSecurityScan(stateId: string): Promise<Task> {
  return fetchAPI<Task>(
    `/api/v1/states/${encodeURIComponent(stateId)}/security/scan`,
    { method: "POST" }
  );
}

export type TenantSecurityHistory = components["schemas"]["tenant-security-history"];
export type TenantSecurityBreakdownEntry =
  components["schemas"]["tenant-security-breakdown-entry"];

/**
 * GET /api/v1/tenants/{tenant_id}/security/findings/history -- tenant-wide
 * security posture over time, one entry per day; the last entry of `points` is
 * the current snapshot. Each entry carries both the severity and blast
 * breakdowns. `from` / `to` are ISO 8601 bounds (default: last 30 days). Mirrors
 * {@link getTenantCostHistory}.
 */
export async function getTenantSecurityHistory(
  tenantId: string,
  options?: { from?: string; to?: string }
): Promise<TenantSecurityHistory> {
  const params = new URLSearchParams();
  if (options?.from) params.append("from", options.from);
  if (options?.to) params.append("to", options.to);
  const queryString = params.toString();
  const path = `/api/v1/tenants/${encodeURIComponent(tenantId)}/security/findings/history${queryString ? `?${queryString}` : ""}`;
  return fetchAPI<TenantSecurityHistory>(path);
}

// ============================================================================
// Per-transaction security impact: the plan-time (or post-commit) security
// delta a tx introduces vs each affected state's latest current scan -- the
// full added/resolved finding lists. Backs the Transaction Detail "Security
// delta" section. (A severity-only rollup is also served at .../impact/summary.)
// ============================================================================

export type TxSecurityImpact = components["schemas"]["tx-security-impact"];

/** Result of {@link getTxSecurityImpact}: ready / still computing / none. */
export type TxSecurityDeltaResult =
  | { status: "ready"; impact: TxSecurityImpact }
  | { status: "computing" }
  | { status: "none" };

/**
 * GET /api/v1/tx/{tx_id}/security/impact -- the per-tx security delta with the
 * full added/resolved finding lists. 200 once the planned scan has run; 202
 * ("computing") while the eager preview scan is still in flight; 404 once the tx
 * is aborted, or it has no preview / is unknown.
 */
export async function getTxSecurityImpact(
  txId: string
): Promise<TxSecurityDeltaResult> {
  const url = `${getApiBase()}/api/v1/tx/${encodeURIComponent(
    txId
  )}/security/impact`;
  const response = await fetch(url, {
    credentials: "include",
    headers: { "Content-Type": "application/json" },
  });
  if (response.status === 200) {
    const impact: TxSecurityImpact = await response.json();
    return { status: "ready", impact };
  }
  if (response.status === 202) return { status: "computing" };
  if (response.status === 404) return { status: "none" };
  if (response.status === 401) throw new Error("Unauthorized");
  throw new Error(`API error: ${response.status} ${response.statusText}`);
}

// ============================================================================
// Per-state costs: latest snapshot + per-resource breakdown, coverage gaps,
// and on-demand recalculation. These complement the tenant rollup endpoints
// above and back the Cost Analysis page + the cost woven into resource/module
// surfaces.
// ============================================================================

export type StateCosts = components["schemas"]["state-costs"];
export type InstanceCost = components["schemas"]["instance-cost"];
export type CostComponent = components["schemas"]["cost-component"];
export type StateCostUnsupported = components["schemas"]["state-cost-unsupported"];
export type StateCostUnsupportedResource =
  components["schemas"]["state-cost-unsupported-resource"];
export type Task = components["schemas"]["task"];

/**
 * Thrown by {@link calculateStateCost} when the server has no pricing service
 * configured (HTTP 503). Lets the UI surface a precise "pricing not configured"
 * message instead of a generic request failure.
 */
export class PricingNotConfiguredError extends Error {
  constructor(message = "Pricing service is not configured on this server") {
    super(message);
    this.name = "PricingNotConfiguredError";
  }
}

/**
 * GET /api/v1/states/{state_id}/costs -- the latest priced snapshot for a
 * state: top-level totals + coverage counters + the per-resource
 * `instance_costs` breakdown. Throws with `status === 404` when the state has
 * never been priced (callers should treat that as an empty/"not yet priced"
 * state, not an error).
 */
export async function getStateCosts(stateId: string): Promise<StateCosts> {
  return fetchAPI<StateCosts>(`/api/v1/states/${encodeURIComponent(stateId)}/costs`);
}

/**
 * GET /api/v1/states/{state_id}/costs/unsupported -- resources excluded from
 * the priced totals: either an unknown resource type or a recognised type with
 * no billable price (free / usage-based).
 */
export async function getStateCostUnsupported(
  stateId: string
): Promise<StateCostUnsupported> {
  return fetchAPI<StateCostUnsupported>(
    `/api/v1/states/${encodeURIComponent(stateId)}/costs/unsupported`
  );
}

export type StateCostActuals = components["schemas"]["state-cost-actuals"];
export type StateCostActualResource = components["schemas"]["state-cost-actual-resource"];

/**
 * GET /api/v1/states/{state_id}/costs/actuals -- actual (FOCUS) spend
 * attributed to the state's resources over the loaded billing window: state
 * total plus per-address breakdown. Always 200; an empty breakdown means no
 * billing line matched the state's resources (meaningful, not an error).
 */
export async function getStateCostActuals(stateId: string): Promise<StateCostActuals> {
  return fetchAPI<StateCostActuals>(
    `/api/v1/states/${encodeURIComponent(stateId)}/costs/actuals`
  );
}

/**
 * POST /api/v1/states/{state_id}/costs/calculate -- kick off a fresh cost
 * snapshot. Returns the async {@link Task} (202); poll it with {@link getTask}
 * / `pollTask`. Throws {@link PricingNotConfiguredError} on 503.
 */
export async function calculateStateCost(stateId: string): Promise<Task> {
  try {
    return await fetchAPI<Task>(
      `/api/v1/states/${encodeURIComponent(stateId)}/costs/calculate`,
      { method: "POST" }
    );
  } catch (err) {
    if ((err as { status?: number }).status === 503) {
      throw new PricingNotConfiguredError();
    }
    throw err;
  }
}

/** GET /api/v1/tasks/{task_id} -- poll an async task's status. */
export async function getTask(taskId: string): Promise<Task> {
  return fetchAPI<Task>(`/api/v1/tasks/${taskId}`);
}

/**
 * GET /api/v1/states/{state_id}/instances/{instance_address}/blast-radius
 *
 * The graph of everything a change to this instance would reach. `maxDepth` bounds how many
 * dependency hops come back; the response says whether it was cut.
 */
export async function getInstanceBlastRadius(
  stateId: string,
  instanceAddress: string,
  opts?: { maxDepth?: number; limit?: number }
): Promise<InstanceBlastRadiusResponse> {
  // URL encode the instance address to handle special characters
  const encodedAddress = encodeURIComponent(instanceAddress);
  const params = new URLSearchParams();
  if (opts?.maxDepth !== undefined) params.set("max_depth", String(opts.maxDepth));
  if (opts?.limit !== undefined) params.set("limit", String(opts.limit));
  const query = params.toString();
  return fetchAPI<InstanceBlastRadiusResponse>(
    `/api/v1/states/${stateId}/instances/${encodedAddress}/blast-radius${query ? `?${query}` : ""}`
  );
}

/** GET /api/v1/mql - Execute MQL query */
export async function executeMQL(
  query: string,
  options?: {
    page?: string[];
    tz?: string;
  }
): Promise<{
  data: unknown[];
  linkHeader: string | null;
  paginationError: string | null;
  /**
   * When the query carried no explicit LIMIT and matched more rows than the
   * server default, the response is truncated at that default and this holds the
   * cap (e.g. 20); null otherwise. A caller treating the result as complete
   * (counting/summing it) should paginate or fail loudly when this is set, since
   * the rows are an undercount rather than the whole answer.
   */
  defaultLimitApplied: number | null;
}> {
  const params = new URLSearchParams();

  params.append('q', query);

  if (options?.page) {
    options.page.forEach(p => params.append('page', p));
  }
  if (options?.tz) {
    params.append('tz', options.tz);
  }

  const queryString = params.toString();
  const path = `/api/v1/mql?${queryString}`;

  const result = await fetchAPIWithHeaders<unknown[]>(path);
  const paginationError = result.headers.get('mql-pagination-error');
  const defaultLimitHeader = result.headers.get('mql-default-limit-applied');
  const parsedDefaultLimit =
    defaultLimitHeader !== null ? Number.parseInt(defaultLimitHeader, 10) : Number.NaN;
  const defaultLimitApplied = Number.isNaN(parsedDefaultLimit) ? null : parsedDefaultLimit;
  return { data: result.data, linkHeader: result.linkHeader, paginationError, defaultLimitApplied };
}

/** GET /api/v1/states/{state_id}/modules */
export async function getStateModules(
  stateId: string,
  options?: {
    page?: string[];
    limit?: number;
  }
): Promise<ModulesResponse> {
  const params = new URLSearchParams();

  if (options?.page) {
    options.page.forEach((p) => params.append('page', p));
  }
  if (options?.limit) {
    params.append('limit', options.limit.toString());
  }

  const queryString = params.toString();
  const path = `/api/v1/states/${stateId}/modules${queryString ? `?${queryString}` : ''}`;

  return fetchAPI<ModulesResponse>(path);
}

/** POST /api/v1/tenants/{tenant_id}/states/import */
export async function importState(tenantId: string, name: string, state: unknown): Promise<State> {
  return fetchAPI<State>(`/api/v1/tenants/${tenantId}/states/import`, {
    method: 'POST',
    body: JSON.stringify({ name, state }),
  });
}

/**
 * Fetch ALL instances in a state, following the endpoint's pagination cursor to
 * exhaustion (not a single capped request — see body).
 */
export async function getAllStateInstances(stateId: string): Promise<Instance[]> {
  // The instances endpoint caps each page well below any requested limit, so a
  // single request is always partial — follow the `Link: rel="next"` cursor to
  // exhaustion. A page-count guard bounds the loop for pathological states.
  const MAX_PAGES = 2000;
  const all: Instance[] = [];
  let page: string[] | undefined = undefined;
  for (let i = 0; i < MAX_PAGES; i++) {
    const { data, linkHeader } = await getStateInstances(stateId, { limit: 5000, page });
    all.push(...data.results);
    const links = parseLinkHeader(linkHeader);
    if (!hasNextPage(links) || !links.next) break;
    page = links.next;
  }
  return all;
}

/** GET /api/v1/tenants/{tenant_id}/tx */
export async function getTenantTransactions(
  tenantId: string,
  options?: {
    page?: string[];
    limit?: number;
    /** ISO-8601 lower bound on created_at (inclusive). */
    from?: string;
    /** ISO-8601 upper bound on created_at (inclusive). */
    to?: string;
  }
): Promise<TransactionsResponse> {
  const params = new URLSearchParams();

  if (options?.page) {
    options.page.forEach((p) => params.append('page', p));
  }
  if (options?.limit) {
    params.append('limit', options.limit.toString());
  }
  if (options?.from) {
    params.append('from', options.from);
  }
  if (options?.to) {
    params.append('to', options.to);
  }

  const queryString = params.toString();
  const path = `/api/v1/tenants/${tenantId}/tx${queryString ? `?${queryString}` : ''}`;

  return fetchAPI<TransactionsResponse>(path);
}

/** Same as getTenantTransactions but also returns the Link header so callers
 *  can drive cursor-based prev/next pagination. */
export async function getTenantTransactionsPaginated(
  tenantId: string,
  options?: {
    page?: string[];
    limit?: number;
    from?: string;
    to?: string;
  }
): Promise<{ data: TransactionsResponse; linkHeader: string | null }> {
  const params = new URLSearchParams();
  if (options?.page) {
    options.page.forEach((p) => params.append('page', p));
  }
  if (options?.limit) {
    params.append('limit', options.limit.toString());
  }
  if (options?.from) {
    params.append('from', options.from);
  }
  if (options?.to) {
    params.append('to', options.to);
  }
  const queryString = params.toString();
  const path = `/api/v1/tenants/${tenantId}/tx${queryString ? `?${queryString}` : ''}`;
  return fetchAPIWithHeaders<TransactionsResponse>(path);
}

export type TxDetailResponse = components["schemas"]["tx-detail"];
export type TxPlanOperation = components["schemas"]["plan-operation"];

/** GET /api/v1/tx/{tx_id} — the run-detail envelope: enriched tx row and touched
 * state ids. The plan operations and the apply output are paginated companions,
 * see {@link getTxPlanOperations} and {@link getTxOutput}. */
export async function getTxDetail(txId: string): Promise<TxDetailResponse> {
  return fetchAPI<TxDetailResponse>(`/api/v1/tx/${encodeURIComponent(txId)}`);
}

export type TxPlanOperations = components["schemas"]["plan-operations"];
export type TxOutputChunk = components["schemas"]["tx-output-chunk"];
export type TxOutputChunks = components["schemas"]["tx-output-chunks"];
export type TxOutputPayloadKind = NonNullable<TxOutputChunks["payload"]>;
export type RunFailure = components["schemas"]["run-failure"];

function pagedQuery(options?: { page?: string[]; limit?: number }): string {
  const params = new URLSearchParams();
  options?.page?.forEach((p) => params.append("page", p));
  if (options?.limit) params.append("limit", options.limit.toString());
  const qs = params.toString();
  return qs ? `?${qs}` : "";
}

/** GET /api/v1/tx/{tx_id}/plan-operations — one page of the per-resource plan
 * operations, ordered by address; paginated via the Link header. */
export async function getTxPlanOperations(
  txId: string,
  options?: { page?: string[]; limit?: number }
): Promise<{ data: TxPlanOperations; linkHeader: string | null }> {
  return fetchAPIWithHeaders<TxPlanOperations>(
    `/api/v1/tx/${encodeURIComponent(txId)}/plan-operations${pagedQuery(options)}`
  );
}

/** GET /api/v1/tx/{tx_id}/output — one page of the apply's stored chunk rows,
 * paginated via the Link header; the page's payload names what they reassemble
 * to. Reassembly is the caller's job: see `lib/tx/output.ts`. */
export async function getTxOutput(
  txId: string,
  options?: { page?: string[]; limit?: number }
): Promise<{ data: TxOutputChunks; linkHeader: string | null }> {
  return fetchAPIWithHeaders<TxOutputChunks>(
    `/api/v1/tx/${encodeURIComponent(txId)}/output${pagedQuery(options)}`
  );
}

export type TxCostDelta = components["schemas"]["tx-cost-delta"];
export type TxCostStatus = components["schemas"]["tx-cost-status"];

/**
 * GET /api/v1/tx/{tx_id}/costs — the plan-time current-vs-planned cost preview.
 * Returns the {@link TxCostDelta} (HTTP 200) or a {@link TxCostStatus}
 * `{ status: "computing" }` (HTTP 202) while the preview is still calculating.
 */
export async function getTxCostDelta(txId: string): Promise<TxCostDelta | TxCostStatus> {
  return fetchAPI<TxCostDelta | TxCostStatus>(`/api/v1/tx/${encodeURIComponent(txId)}/costs`);
}

/** POST /api/v1/tx/{tx_id}/abort — marks the tx aborted; works on any state. */
export async function abortTransaction(txId: string): Promise<Transaction> {
  return fetchAPI<Transaction>(`/api/v1/tx/${encodeURIComponent(txId)}/abort`, {
    method: "POST",
  });
}

export type GitlabProvisionRequest = components["schemas"]["gitlab-provision-request"];
export type GitlabProvisionResponse = components["schemas"]["gitlab-provision-response"];

/** POST /api/v1/tenants/{tenant_id}/vcs-installations/gitlab. Provision a GitLab
 *  group installation and link it to the tenant. The webhook_secret in the
 *  response is returned exactly once — the caller must surface it immediately. */
export async function provisionGitlab(
  tenantId: string,
  body: GitlabProvisionRequest
): Promise<GitlabProvisionResponse> {
  return fetchAPI<GitlabProvisionResponse>(
    `/api/v1/tenants/${encodeURIComponent(tenantId)}/vcs-installations/gitlab`,
    { method: "POST", body: JSON.stringify(body), sensitive: true, noRetry: true }
  );
}

export type GithubAppManifestRequest = components["schemas"]["github-app-manifest-request"];
export type GithubAppManifestResponse = components["schemas"]["github-app-manifest-response"];

/** POST /api/v1/setup/github-app/manifest. The GitHub App manifest of this
 *  deployment and the form to post it to GitHub with. Instance admin only. */
export async function createGithubAppManifest(
  body: GithubAppManifestRequest
): Promise<GithubAppManifestResponse> {
  return fetchAPI<GithubAppManifestResponse>("/api/v1/setup/github-app/manifest", {
    method: "POST",
    body: JSON.stringify(body),
    noRetry: true,
  });
}

export type GithubAppResponse = components["schemas"]["github-app-response"];

/** GET /api/v1/setup/github-app. The App the engine uses and where it comes
 *  from. Instance admin only. */
export async function getGithubApp(): Promise<GithubAppResponse> {
  return fetchAPI<GithubAppResponse>("/api/v1/setup/github-app");
}

/** DELETE /api/v1/setup/github-app. Removes the stored App, so the engine
 *  restarts with no GitHub service. The id is the confirmation: this destroys
 *  the only copy of the App's private key. */
export async function deleteGithubApp(appId: number): Promise<void> {
  await fetchAPI<void>("/api/v1/setup/github-app", {
    method: "DELETE",
    body: JSON.stringify({ app_id: appId }),
    noRetry: true,
  });
}

export type GithubAppCredentialsRequest = components["schemas"]["github-app-credentials-request"];

/** PUT /api/v1/setup/github-app/credentials. Replaces the credentials the operator
 *  rotated on GitHub. A field left out keeps its stored value. The id binds the
 *  write to the App the operator was looking at, so a replacement made meanwhile
 *  cannot receive it. */
export async function setGithubAppCredentials(
  appId: number,
  credentials: Omit<GithubAppCredentialsRequest, "app_id">
): Promise<void> {
  await fetchAPI<void>("/api/v1/setup/github-app/credentials", {
    method: "PUT",
    body: JSON.stringify({ app_id: appId, ...credentials }),
    noRetry: true,
  });
}

export type VcsInstallationListResponse = components["schemas"]["vcs-installation-list-response"];
export type GitlabRotateRequest = components["schemas"]["gitlab-rotate-request"];
export type GitlabRotateResponse = components["schemas"]["gitlab-rotate-response"];

/** GET /api/v1/tenants/{tenant_id}/vcs-installations. The tenant's linked VCS
 *  installations (both providers), core ids only — names resolve via MQL. */
export async function listVcsInstallations(tenantId: string): Promise<VcsInstallationListResponse> {
  return fetchAPI<VcsInstallationListResponse>(
    `/api/v1/tenants/${encodeURIComponent(tenantId)}/vcs-installations`
  );
}

/** DELETE /api/v1/tenants/{tenant_id}/vcs-installations/{provider}/{core_id}.
 *  Unlink an installation from the tenant (a tenant admin who is a member). The
 *  installation and its history remain in the engine; re-linking is the
 *  instance-admin PUT (linkVcsInstallation). */
export async function unlinkVcsInstallation(
  tenantId: string,
  provider: string,
  installationCoreId: string
): Promise<void> {
  await fetchAPI<void>(
    `/api/v1/tenants/${encodeURIComponent(tenantId)}/vcs-installations/${encodeURIComponent(provider)}/${encodeURIComponent(installationCoreId)}`,
    { method: "DELETE" }
  );
}

/** PUT /api/v1/tenants/{tenant_id}/vcs-installations/gitlab/{group_id}. Rotate
 *  a provisioned GitLab installation's credentials — new access token and/or a
 *  regenerated webhook secret (returned exactly once). 404 (empty body) covers
 *  a group that was never provisioned, one linked to another tenant, and one
 *  linked to no tenant. */
export async function rotateGitlab(
  tenantId: string,
  groupId: number,
  body: GitlabRotateRequest
): Promise<GitlabRotateResponse> {
  return fetchAPI<GitlabRotateResponse>(
    `/api/v1/tenants/${encodeURIComponent(tenantId)}/vcs-installations/gitlab/${groupId}`,
    { method: "PUT", body: JSON.stringify(body), sensitive: true }
  );
}

export type GithubUnclaimedInstallation = components["schemas"]["github-unclaimed-installation"];
export type GithubUnclaimedInstallations = components["schemas"]["github-unclaimed-installations"];
export type VcsInstallation = components["schemas"]["vcs-installation"];

/** GET /api/v1/vcs-installations/github/unclaimed. One page of the GitHub
 *  installations linked to no tenant — the instance-wide set an admin can claim.
 *  Instance admin only. Pass the previous page's `next_cursor` to continue; the
 *  response says whether another page follows. */
export async function listUnclaimedGithub(
  cursor?: string | null
): Promise<GithubUnclaimedInstallations> {
  const params = new URLSearchParams();
  if (cursor) params.append("cursor", cursor);
  const query = params.toString();
  return fetchAPI<GithubUnclaimedInstallations>(
    `/api/v1/vcs-installations/github/unclaimed${query ? `?${query}` : ""}`
  );
}

/** PUT /api/v1/tenants/{tenant_id}/vcs-installations/{provider}/{core_id}. Link
 *  an installation to the tenant (the claim step). */
export async function linkVcsInstallation(
  tenantId: string,
  provider: string,
  installationCoreId: string
): Promise<VcsInstallation> {
  return fetchAPI<VcsInstallation>(
    `/api/v1/tenants/${encodeURIComponent(tenantId)}/vcs-installations/${encodeURIComponent(
      provider
    )}/${encodeURIComponent(installationCoreId)}`,
    { method: "PUT" }
  );
}

export type GithubClaimableInstallations = components["schemas"]["github-claimable-installations"];

/** GET /api/v1/tenants/{tenant_id}/vcs-installations/github/claim/start. A
 *  full-page navigation, not a fetch: the browser leaves for GitHub and comes
 *  back to `rd` with a `github_claim` result. */
export function githubClaimStartUrl(tenantId: string, rd: string): string {
  return `${getApiBase()}/api/v1/tenants/${encodeURIComponent(
    tenantId
  )}/vcs-installations/github/claim/start?rd=${encodeURIComponent(rd)}`;
}

/** GET /api/v1/tenants/{tenant_id}/vcs-installations/github/claimable. The
 *  installations this user proved they administer that no tenant holds yet.
 *  Needs the proof cookie the claim callback set; 412 without it. */
export async function listClaimableGithub(
  tenantId: string
): Promise<GithubClaimableInstallations> {
  return fetchAPI<GithubClaimableInstallations>(
    `/api/v1/tenants/${encodeURIComponent(tenantId)}/vcs-installations/github/claimable`
  );
}

/** POST /api/v1/tenants/{tenant_id}/vcs-installations/github/claim. The
 *  self-serve claim: tenant admin plus proof, instead of instance admin. */
export async function claimGithubInstallation(
  tenantId: string,
  installationCoreId: string
): Promise<VcsInstallation> {
  return fetchAPI<VcsInstallation>(
    `/api/v1/tenants/${encodeURIComponent(tenantId)}/vcs-installations/github/claim`,
    {
      method: "POST",
      noRetry: true,
      body: JSON.stringify({ installation_core_id: installationCoreId }),
    }
  );
}

/** GET /api/v1/tx/{tx_id}/logs */
export async function getTransactionLogs(
  txId: string,
  options?: {
    page?: string[];
    q?: string;
    tz?: string;
    limit?: number;
  }
): Promise<TransactionLogsResponse> {
  const params = new URLSearchParams();

  if (options?.page) {
    options.page.forEach((p) => params.append('page', p));
  }
  if (options?.q) {
    params.append('q', options.q);
  }
  if (options?.tz) {
    params.append('tz', options.tz);
  }
  if (options?.limit) {
    params.append('limit', options.limit.toString());
  }

  const queryString = params.toString();
  const path = `/api/v1/tx/${txId}/logs${queryString ? `?${queryString}` : ''}`;

  return fetchAPI<TransactionLogsResponse>(path);
}

export type MQLSchemaColumn = components["schemas"]["mql-schema-column"];
export type MQLSchemaTable = components["schemas"]["mql-schema-table"];
export type MQLSchemaResponse = components["schemas"]["mql-schema-response"];

/** GET /api/v1/mql/schema - Get MQL schema */
export async function getMQLSchema(): Promise<MQLSchemaResponse> {
  return fetchAPI<MQLSchemaResponse>('/api/v1/mql/schema');
}

// ============================================================================
// VERSION API
// ============================================================================

/** GET /api/v1/version - Get current server version */
export async function getServerVersion(): Promise<VersionResponse> {
  return fetchAPI<VersionResponse>('/api/v1/version');
}

/** Fetch latest release from GitHub API */
export async function getLatestGitHubRelease(): Promise<GitHubRelease | null> {
  try {
    const response = await fetch(
      'https://api.github.com/repos/stategraph/releases/releases/latest',
      { headers: { 'Accept': 'application/vnd.github.v3+json' } }
    );
    if (!response.ok) return null;
    return response.json();
  } catch {
    return null;
  }
}

// ============================================================================
// GAP ANALYSIS TYPES (from OpenAPI schema)
// ============================================================================

export type GapAnalysisSummary = components["schemas"]["gap-analysis-summary"];
export type UnmanagedResource = components["schemas"]["unmanaged-resource"];
export type GapAnalysisResponse = components["schemas"]["gap-analysis-response"];
export type GapAnalysisJobStatus = components["schemas"]["gap-analysis-job-status"];

// Warning type used by frontend (not in OpenAPI schema - internal frontend type)
export interface AWSConfigWarning {
  code: string;
  message: string;
  fix?: string;
}

export type GapAnalysisProvider = 'aws' | 'gcp' | 'azure';

export type GapAnalysisResult =
  | { status: 'ready'; data: GapAnalysisResponse }
  | { status: 'running'; job: GapAnalysisJobStatus }
  | { status: 'failed'; job: GapAnalysisJobStatus };

/** GET /api/v1/tenants/{tenant_id}/gaps - Get gap analysis for tenant */
export async function getGapAnalysis(
  tenantId: string,
  provider: GapAnalysisProvider,
  options?: { source?: 'cache' | 'no-cache' }
): Promise<GapAnalysisResult> {
  const params = new URLSearchParams({ provider });
  if (options?.source) {
    params.set('source', options.source);
  }
  const url = `${getApiBase()}/api/v1/tenants/${tenantId}/gaps?${params}`;
  const response = await fetch(url, {
    credentials: 'include',
    headers: { 'Content-Type': 'application/json' },
  });

  if (response.status === 200) {
    const data: GapAnalysisResponse = await response.json();
    return { status: 'ready', data };
  }

  if (response.status === 202) {
    const job: GapAnalysisJobStatus = await response.json();
    if (job.status === 'failed') {
      return { status: 'failed', job };
    }
    return { status: 'running', job };
  }

  if (response.status === 401) {
    throw new Error('Unauthorized');
  }

  throw new Error(`API error: ${response.status} ${response.statusText}`);
}

// ============================================================================
// GAP ANALYSIS CONFIG TYPES (from OpenAPI schema)
// ============================================================================

export type GapAnalysisConfigResponse = components["schemas"]["gap-analysis-config-response"];

/** GET /api/v1/tenants/{tenant_id}/gaps/config - Check provider config for gap analysis */
export async function getGapAnalysisConfig(
  tenantId: string,
  provider: GapAnalysisProvider
): Promise<GapAnalysisConfigResponse> {
  return fetchAPI<GapAnalysisConfigResponse>(`/api/v1/tenants/${tenantId}/gaps/config?provider=${provider}`);
}

// ============================================================================
// TOFU IMPORT TYPES (from OpenAPI schema)
// ============================================================================

export type TofuImportRequest = components["schemas"]["gap-import-request"];
export type UnsupportedResource = components["schemas"]["unsupported-resource"];
export type TofuImportResponse = components["schemas"]["gap-import-response"];

/** POST /api/v1/tenants/{tenant_id}/gaps/import - Generate OpenTofu config for resources */
export async function generateTofuImport(
  tenantId: string,
  resources: UnmanagedResource[],
  provider: GapAnalysisProvider = 'aws'
): Promise<TofuImportResponse> {
  return fetchAPI<TofuImportResponse>(`/api/v1/tenants/${tenantId}/gaps/import`, {
    method: 'POST',
    body: JSON.stringify({ resources, provider }),
  });
}

// ============================================================================
// API KEY MANAGEMENT (from OpenAPI schema)
// ============================================================================

export type AccessTokenSummary = components["schemas"]["access-token-summary"];
export type AccessTokenListResponse = components["schemas"]["access-token-list-response"];
export type AccessTokenRevokeResponse = components["schemas"]["access-token-revoke-response"];
export type CreateApiKeyResponse = components["schemas"]["access-token-create-response"];

/**
 * POST /api/v1/user/access-tokens - Create a persistent API key
 *
 * Creates a new API key (UUID) stored in the database that can be used for CLI
 * and programmatic access (e.g., Terraform backend in CI pipelines).
 *
 * @param options - Options for the API key
 * @param options.name - A name/description for the API key
 * @returns The generated API key token (UUID)
 */
export async function createApiKey(options: { name: string }): Promise<CreateApiKeyResponse> {
  return fetchAPI<CreateApiKeyResponse>('/api/v1/user/access-tokens', {
    method: 'POST',
    body: JSON.stringify({ name: options.name }),
    sensitive: true,
  });
}

/**
 * GET /api/v1/user/access-tokens - List access tokens for the current user
 */
export async function listApiKeys(): Promise<AccessTokenListResponse> {
  return fetchAPI<AccessTokenListResponse>('/api/v1/user/access-tokens');
}

/**
 * POST /api/v1/user/access-tokens/revoke - Revoke an access token
 */
export async function revokeApiKey(tokenId: string): Promise<AccessTokenRevokeResponse> {
  return fetchAPI<AccessTokenRevokeResponse>(`/api/v1/user/access-tokens/revoke?token_id=${encodeURIComponent(tokenId)}`, {
    method: 'POST',
  });
}

// ============================================================================
// SERVICE ACCOUNT (API USER) MANAGEMENT (from OpenAPI schema)
// ============================================================================

export type CreateApiUserResponse = components["schemas"]["api-user-create-response"];

/**
 * POST /api/v1/api-users - Create a service account (api type user)
 *
 * Creates a dedicated API user for CI pipelines or programmatic access.
 * Unlike personal API keys, these are separate identities that survive
 * employee turnover and provide clear audit trails.
 *
 * @param options.name - Name for the service account (e.g., "ci-production")
 * @param options.tenant_id - Tenant to add the service account to
 * @returns The user_id and API token
 */
export async function createApiUser(options: { name: string; tenant_id: string }): Promise<CreateApiUserResponse> {
  return fetchAPI<CreateApiUserResponse>('/api/v1/api-users', {
    method: 'POST',
    body: JSON.stringify({ name: options.name, tenant_id: options.tenant_id }),
    sensitive: true,
  });
}

// ============================================================================
// USER MANAGEMENT
// ============================================================================

/**
 * GET /api/v1/users - List all users (admin only)
 */
export async function listUsers(params?: {
  type?: string;
  search?: string;
  cursor?: string;
  limit?: number;
}): Promise<UsersListResponse> {
  const searchParams = new URLSearchParams();
  if (params?.type) searchParams.set('type', params.type);
  if (params?.search) searchParams.set('search', params.search);
  if (params?.cursor) searchParams.set('cursor', params.cursor);
  if (params?.limit) searchParams.set('limit', params.limit.toString());

  const query = searchParams.toString();
  return fetchAPI<UsersListResponse>(`/api/v1/users${query ? `?${query}` : ''}`);
}

/**
 * GET /api/v1/users/detail - Get a user's details. Allowed for a caller holding an admin or
 * users-manage grant that reaches one of the user's tenants, and for the user themselves; the
 * tenant list answers only the memberships inside that reach (`tenants_complete` says which).
 */
export async function getUserDetail(userId: string): Promise<UserDetailResponse> {
  return fetchAPI<UserDetailResponse>(`/api/v1/users/detail?user_id=${userId}`);
}

/**
 * POST /api/v1/users - Create a new user (admin only)
 */
export async function createUser(data: UserCreateRequest): Promise<UserCreateResponse> {
  return fetchAPI<UserCreateResponse>('/api/v1/users', {
    method: 'POST',
    body: JSON.stringify(data),
  });
}

/**
 * PUT /api/v1/users/update - Update user (admin for all fields, self for name/avatar)
 */
export async function updateUser(userId: string, data: UserUpdateRequest): Promise<UserUpdateResponse> {
  return fetchAPI<UserUpdateResponse>(`/api/v1/users/update?user_id=${userId}`, {
    method: 'PUT',
    body: JSON.stringify(data),
  });
}

/**
 * DELETE /api/v1/users/delete - Delete user (admin only, soft delete)
 */
export async function deleteUser(userId: string): Promise<UserDeleteResponse> {
  return fetchAPI<UserDeleteResponse>(`/api/v1/users/delete?user_id=${userId}`, {
    method: 'DELETE',
  });
}

/**
 * POST /api/v1/users/change-password - Change user password
 * Admin can change any password without current password.
 * Users can change own password with current password verification.
 */
export async function changeUserPassword(
  userId: string,
  data: UserChangePasswordRequest
): Promise<UserChangePasswordResponse> {
  return fetchAPI<UserChangePasswordResponse>(`/api/v1/users/change-password?user_id=${userId}`, {
    method: 'POST',
    body: JSON.stringify(data),
  });
}

/**
 * POST /api/v1/users/set-instance-admin - Set the installation-wide admin grant (admin only)
 * Cannot remove admin from last admin user, nor from yourself.
 */
export async function setUserInstanceAdmin(
  userId: string,
  isAdmin: boolean
): Promise<UserSetInstanceAdminResponse> {
  return fetchAPI<UserSetInstanceAdminResponse>(`/api/v1/users/set-instance-admin?user_id=${userId}`, {
    method: 'POST',
    body: JSON.stringify({ is_instance_admin: isAdmin }),
  });
}

/**
 * DELETE /api/v1/states/{state_id} - Delete a state
 * Soft delete by default; pass hardDelete=true for permanent removal.
 */
export async function deleteState(stateId: string): Promise<void> {
  const url = `${getApiBase()}/api/v1/states/${stateId}?hard_delete=true`;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 10000);
  try {
    const response = await fetch(url, {
      method: 'DELETE',
      credentials: 'include',
      headers: { 'Content-Length': '0' },
      signal: controller.signal,
    });
    if (!response.ok) {
      let errorMessage = `API error: ${response.status} ${response.statusText}`;
      try {
        const errorBody = await response.json();
        if (errorBody?.id) errorMessage += ` - ${errorBody.id}`;
        if (errorBody?.data) errorMessage += `: ${errorBody.data}`;
      } catch {
        // empty
      }
      throw new Error(errorMessage);
    }
  } catch (e) {
    if (e instanceof DOMException && e.name === 'AbortError') {
      throw new Error('Delete request timed out — is the backend running?');
    }
    throw e;
  } finally {
    clearTimeout(timeout);
  }
}

// ============================================================================
// FOCUS billing sources (actual-cost ingestion config; admin only)
// ============================================================================

export type BillingSource = components["schemas"]["billing-source"];
export type BillingSourceCreateRequest = components["schemas"]["billing-source-create-request"];
export type BillingSourceUpdateRequest = components["schemas"]["billing-source-update-request"];
export type BillingSourceSyncRequest = components["schemas"]["billing-source-sync-request"];
export type BillingSourceSyncResponse = components["schemas"]["billing-source-sync-response"];

/** POST /api/v1/tenants/{tenant_id}/billing-sources */
export async function createBillingSource(
  tenantId: string,
  data: BillingSourceCreateRequest
): Promise<BillingSource> {
  return fetchAPI<BillingSource>(
    `/api/v1/tenants/${encodeURIComponent(tenantId)}/billing-sources`,
    { method: "POST", body: JSON.stringify(data) }
  );
}

/** PUT /api/v1/tenants/{tenant_id}/billing-sources/{billing_source_id} */
export async function updateBillingSource(
  tenantId: string,
  id: string,
  data: BillingSourceUpdateRequest
): Promise<BillingSource> {
  return fetchAPI<BillingSource>(
    `/api/v1/tenants/${encodeURIComponent(tenantId)}/billing-sources/${encodeURIComponent(id)}`,
    { method: "PUT", body: JSON.stringify(data) }
  );
}

/** DELETE /api/v1/tenants/{tenant_id}/billing-sources/{billing_source_id} */
export async function deleteBillingSource(tenantId: string, id: string): Promise<void> {
  await fetchAPI<void>(
    `/api/v1/tenants/${encodeURIComponent(tenantId)}/billing-sources/${encodeURIComponent(id)}`,
    { method: "DELETE" }
  );
}

/** POST /api/v1/tenants/{tenant_id}/billing-sources/{billing_source_id}/sync */
export async function syncBillingSource(
  tenantId: string,
  id: string,
  data?: BillingSourceSyncRequest
): Promise<BillingSourceSyncResponse> {
  return fetchAPI<BillingSourceSyncResponse>(
    `/api/v1/tenants/${encodeURIComponent(tenantId)}/billing-sources/${encodeURIComponent(id)}/sync`,
    { method: "POST", body: JSON.stringify(data ?? {}) }
  );
}

// ============================================================
// Tenant membership & invitations (tenant-admin scoped)
// ============================================================

export type TenantMember = components["schemas"]["tenant-member"];
export type TenantMembersResponse = components["schemas"]["tenant-members-response"];
export type TenantMemberRemoveResponse = components["schemas"]["tenant-member-remove-response"];
export type TenantMemberSetRoleRequest = components["schemas"]["tenant-member-set-role-request"];
export type TenantInvitation = components["schemas"]["tenant-invitation"];
export type TenantInvitationsResponse = components["schemas"]["tenant-invitations-response"];
export type InvitationCreateRequest = components["schemas"]["invitation-create-request"];
export type InvitationCreateResponse = components["schemas"]["invitation-create-response"];
export type InvitationPreviewResponse = components["schemas"]["invitation-preview-response"];
export type InvitationAcceptResponse = components["schemas"]["invitation-accept-response"];

/** GET /api/v1/tenants/{tenant_id}/members */
export async function listTenantMembers(
  tenantId: string,
  options?: { search?: string; role?: string; cursor?: string; limit?: number }
): Promise<TenantMembersResponse> {
  const params = new URLSearchParams();
  if (options?.search) params.append("search", options.search);
  if (options?.role) params.append("role", options.role);
  if (options?.cursor) params.append("cursor", options.cursor);
  if (options?.limit != null) params.append("limit", String(options.limit));
  const qs = params.toString();
  return fetchAPI<TenantMembersResponse>(
    `/api/v1/tenants/${encodeURIComponent(tenantId)}/members${qs ? `?${qs}` : ""}`
  );
}

/** DELETE /api/v1/tenants/{tenant_id}/members?user_id= */
export async function removeTenantMember(
  tenantId: string,
  userId: string
): Promise<TenantMemberRemoveResponse> {
  // Explicit empty body: without a Content-Length the backend waits for one when
  // reached directly (dev on :8080, no nginx in front).
  return fetchAPI<TenantMemberRemoveResponse>(
    `/api/v1/tenants/${encodeURIComponent(tenantId)}/members?user_id=${encodeURIComponent(userId)}`,
    { method: "DELETE", body: "" }
  );
}

/** POST /api/v1/tenants/{tenant_id}/members/set-role?user_id= */
export async function setTenantMemberRole(
  tenantId: string,
  userId: string,
  data: TenantMemberSetRoleRequest
): Promise<TenantMember> {
  return fetchAPI<TenantMember>(
    `/api/v1/tenants/${encodeURIComponent(tenantId)}/members/set-role?user_id=${encodeURIComponent(userId)}`,
    { method: "POST", body: JSON.stringify(data) }
  );
}

/** POST /api/v1/tenants/{tenant_id}/members — add an existing user to the tenant as a plain member.
 *  Distinct from an invitation (which is for someone with no account yet). Idempotent. */
export type TenantMemberAddRequest = components["schemas"]["tenant-member-add-request"];
/**
 * POST /api/v1/tenants/{tenant_id}/members
 *
 * `created` distinguishes the two success statuses the endpoint answers with: 201 when this call
 * made the membership, 200 when the user was already a member. The members listing cannot stand in
 * for it -- it is oldest-membership-first and read one page at a time, so a user's absence from it
 * proves nothing.
 */
export async function addTenantMember(
  tenantId: string,
  userId: string
): Promise<{ member: TenantMember; created: boolean }> {
  const result = await fetchAPIWithHeaders<TenantMember>(
    `/api/v1/tenants/${encodeURIComponent(tenantId)}/members`,
    { method: "POST", body: JSON.stringify({ user_id: userId }) }
  );
  return { member: result.data, created: result.status === 201 };
}

export type TenantCreateRequest = components["schemas"]["tenant-create-request"];

/** POST /api/v1/tenants — create a tenant (instance admin). Returns the new tenant. */
export async function createTenant(name: string): Promise<Tenant> {
  const body: TenantCreateRequest = { name };
  return fetchAPI<Tenant>("/api/v1/tenants", {
    method: "POST",
    body: JSON.stringify(body),
  });
}

export type TenantUpdateRequest = components["schemas"]["tenant-update-request"];

/**
 * PUT /api/v1/tenants/{tenant_id} — rename the tenant. Returns the tenant as stored, so the caller
 * gets the server's trimmed name rather than the string it sent.
 *
 * Gated on the tenant-admin capability, not users-manage: someone who manages members cannot
 * relabel the tenant.
 */
export async function renameTenant(tenantId: string, data: TenantUpdateRequest): Promise<Tenant> {
  return fetchAPI<Tenant>(`/api/v1/tenants/${encodeURIComponent(tenantId)}`, {
    method: "PUT",
    body: JSON.stringify(data),
  });
}

/** GET /api/v1/tenants/{tenant_id}/invitations */
export async function listTenantInvitations(
  tenantId: string,
  options?: { cursor?: string; limit?: number }
): Promise<TenantInvitationsResponse> {
  const params = new URLSearchParams();
  if (options?.cursor) params.append("cursor", options.cursor);
  if (options?.limit != null) params.append("limit", String(options.limit));
  const qs = params.toString();
  return fetchAPI<TenantInvitationsResponse>(
    `/api/v1/tenants/${encodeURIComponent(tenantId)}/invitations${qs ? `?${qs}` : ""}`
  );
}

/** POST /api/v1/tenants/{tenant_id}/invitations */
export async function createTenantInvitation(
  tenantId: string,
  data: InvitationCreateRequest
): Promise<InvitationCreateResponse> {
  return fetchAPI<InvitationCreateResponse>(
    `/api/v1/tenants/${encodeURIComponent(tenantId)}/invitations`,
    { method: "POST", body: JSON.stringify(data) }
  );
}

/** POST /api/v1/tenants/{tenant_id}/invitations/reissue?id= */
export async function reissueTenantInvitation(
  tenantId: string,
  invitationId: string
): Promise<InvitationCreateResponse> {
  return fetchAPI<InvitationCreateResponse>(
    `/api/v1/tenants/${encodeURIComponent(tenantId)}/invitations/reissue?id=${encodeURIComponent(invitationId)}`,
    { method: "POST", body: "" }
  );
}

/** POST /api/v1/tenants/{tenant_id}/invitations/revoke?id= */
export async function revokeTenantInvitation(
  tenantId: string,
  invitationId: string
): Promise<void> {
  await fetchAPI<void>(
    `/api/v1/tenants/${encodeURIComponent(tenantId)}/invitations/revoke?id=${encodeURIComponent(invitationId)}`,
    { method: "POST", body: "" }
  );
}

/** GET /api/v1/invitations/preview?token= — unauthenticated; the token is the credential. */
export async function previewInvitation(token: string): Promise<InvitationPreviewResponse> {
  return fetchAPI<InvitationPreviewResponse>(
    `/api/v1/invitations/preview?token=${encodeURIComponent(token)}`
  );
}

/** POST /api/v1/invitations/accept — joins the signed-in user to the invitation's tenant. */
export async function acceptInvitation(token: string): Promise<InvitationAcceptResponse> {
  return fetchAPI<InvitationAcceptResponse>(`/api/v1/invitations/accept`, {
    method: "POST",
    body: JSON.stringify({ token }),
  });
}
