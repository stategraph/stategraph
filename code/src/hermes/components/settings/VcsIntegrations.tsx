"use client";

import { useCallback, useEffect, useState } from "react";
import { Check, Copy, GitlabIcon, GithubIcon, KeyRound, Loader2, RefreshCw, Trash2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  unlinkVcsInstallation,
  executeMQL,
  listVcsInstallations,
  rotateGitlab,
  type VcsInstallation,
} from "@/lib/api/client";
import { useTenant } from "@/contexts";
import { gitlabRotateErrorMessage } from "@/lib/api/gitlabRotateErrors";
import { vcsUnlinkErrorMessage } from "@/lib/api/vcsUnlinkErrors";
import { copyText } from "@/lib/utils/clipboard";
import { orchestrationUnavailable } from "@/lib/mql/providers";
import { track } from "@/lib/analytics";

/* Tenant-scoped name resolution: the installation list carries core ids only,
   and the MQL catalog's map tables join them to provider-side ids and names. */
const GITLAB_NAMES_QUERY =
  "select gim.core_id as core_id, gim.installation_id as installation_id, gi.name as name, gi.state as state " +
  "from gitlab_installations_map as gim " +
  "inner join gitlab_installations as gi on gi.id = gim.installation_id limit 200";
const GITHUB_NAMES_QUERY =
  "select gim.core_id as core_id, gi.login as login, gi.state as state " +
  "from github_installations_map as gim " +
  "inner join github_installations as gi on gi.id = gim.installation_id limit 200";

const s = (v: unknown): string => (typeof v === "string" ? v : v == null ? "" : String(v));
const n = (v: unknown): number => (typeof v === "number" ? v : typeof v === "string" ? Number(v) || 0 : 0);

interface Row {
  provider: string;
  coreId: string;
  linkedAt: string;
  /** GitLab group id / GitHub installation id, when resolvable via MQL. */
  providerId: number | null;
  name: string;
  state: string;
}

/* What unlinking does: the link is read only by the console side (MQL views,
   rotation), never by the engine, and re-linking is the instance-admin PUT. */
function unlinkConfirmation(row: Row): string {
  const gitlab = row.provider === "gitlab";
  return (
    `Remove ${row.name || row.coreId} from this tenant? Its runs, pull requests and stacks stop appearing here, and ` +
    (gitlab
      ? "its credentials can no longer be rotated from this tenant"
      : "it can no longer be managed from this tenant") +
    `. Nothing is deleted and nothing changes in ${gitlab ? "GitLab" : "GitHub"}: plans and applies keep running. Only an instance admin can link it back` +
    (gitlab ? ", and Get Started cannot reconnect a GitLab group that was removed" : "") +
    "."
  );
}

function RotateDialog({
  row,
  tenantId,
  onSecretAtRisk,
  onClose,
}: {
  row: Row;
  tenantId: string;
  onSecretAtRisk: (atRisk: boolean) => void;
  onClose: () => void;
}) {
  const [token, setToken] = useState("");
  const [regen, setRegen] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [secret, setSecret] = useState<string | null>(null);
  const [acked, setAcked] = useState(false);
  const [doneNoSecret, setDoneNoSecret] = useState(false);

  const submit = async () => {
    setError(null);
    if (!token.trim() && !regen) {
      setError("Provide a new token, tick regenerate, or both.");
      return;
    }
    setBusy(true);
    try {
      const res = await rotateGitlab(tenantId, row.providerId as number, {
        ...(token.trim() ? { access_token: token.trim() } : {}),
        ...(regen ? { regenerate_webhook_secret: true } : {}),
      });
      setToken("");
      if (res.webhook_secret) {
        setSecret(res.webhook_secret);
        onSecretAtRisk(true);
      } else setDoneNoSecret(true);
    } catch (e) {
      setError(gitlabRotateErrorMessage(e, "Rotation failed."));
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-2)] p-4 space-y-3">
      <div className="text-sm font-medium text-[var(--sg-text)]">
        Rotate credentials — {row.name || row.coreId}
      </div>
      {secret ? (
        <>
          <div className="space-y-1.5">
            <div className="text-xs text-[var(--sg-text-muted)]">New webhook secret</div>
            <div className="flex items-center gap-2">
              <code className="flex-1 px-3 py-2 rounded-md bg-[var(--sg-bg-1)] border border-[var(--sg-border)] font-mono text-xs break-all">
                {secret}
              </code>
              <Button
                variant="outline"
                size="icon-sm"
                aria-label="Copy new webhook secret"
                onClick={() =>
                  void copyText(secret).then((ok) => {
                    if (ok) {
                      setAcked(true);
                      onSecretAtRisk(false);
                    }
                    else setError("Could not copy automatically — select the secret above and copy it manually.");
                  })
                }
              >
                <Copy className="h-4 w-4" />
              </Button>
            </div>
          </div>
          <div className="rounded-md bg-[var(--sg-warning)]/10 border border-[var(--sg-warning)]/30 px-3 py-2 text-xs text-[var(--sg-warning)]">
            This secret is shown once. Update the webhook in GitLab now — the old secret stopped
            working the moment this one was generated.
          </div>
          <label className="flex items-start gap-2 text-sm text-[var(--sg-text)] cursor-pointer">
            <input
              type="checkbox"
              className="mt-0.5"
              checked={acked}
              onChange={(e) => {
                setAcked(e.target.checked);
                onSecretAtRisk(!e.target.checked);
              }}
            />
            I&apos;ve saved the new secret into GitLab (or somewhere safe)
          </label>
          {error ? <div className="text-xs text-[var(--sg-error)]">{error}</div> : null}
          <div className="flex justify-end">
            <Button onClick={onClose} disabled={!acked}>
              Done
            </Button>
          </div>
        </>
      ) : doneNoSecret ? (
        <>
          <div className="text-sm text-[var(--sg-success)] flex items-center gap-2">
            <Check className="h-4 w-4" /> Access token updated.
          </div>
          <div className="flex justify-end">
            <Button onClick={onClose}>Done</Button>
          </div>
        </>
      ) : (
        <>
          <div className="space-y-1.5">
            <label htmlFor={`rotate-token-${row.coreId}`} className="text-xs text-[var(--sg-text-muted)] block">
              New access token (leave blank to keep the current one)
            </label>
            <Input
              id={`rotate-token-${row.coreId}`}
              type="password"
              value={token}
              onChange={(e) => setToken(e.target.value)}
              placeholder="glpat-..."
              disabled={busy}
            />
          </div>
          <label className="flex items-start gap-2 text-sm text-[var(--sg-text)] cursor-pointer">
            <input
              type="checkbox"
              className="mt-0.5"
              checked={regen}
              onChange={(e) => setRegen(e.target.checked)}
              disabled={busy}
            />
            Regenerate the webhook secret (shown once; the old secret stops working)
          </label>
          {error ? <div className="text-xs text-[var(--sg-error)]">{error}</div> : null}
          <div className="flex justify-end gap-2">
            <Button variant="outline" onClick={onClose} disabled={busy}>
              Cancel
            </Button>
            <Button onClick={() => void submit()} disabled={busy}>
              {busy ? <Loader2 className="h-4 w-4 mr-1 animate-spin" /> : <KeyRound className="h-4 w-4 mr-1" />}
              {busy ? "Rotating..." : "Rotate"}
            </Button>
          </div>
        </>
      )}
    </div>
  );
}

/**
 * Settings → Integrations: the tenant's linked VCS installations with
 * credential rotation for GitLab entries (via the same-tenant rotation
 * endpoint). Names resolve tenant-scoped through the MQL catalog; when the
 * orchestration surface is off, rows fall back to core ids.
 */
export function VcsIntegrations({
  onSecretAtRiskChange,
}: {
  onSecretAtRiskChange?: (atRisk: boolean) => void;
} = {}) {
  const { currentTenant } = useTenant();
  const [rows, setRows] = useState<Row[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [rotating, setRotating] = useState<string | null>(null);
  // The name lookup goes through the orchestration MQL tables; without them a
  // GitLab row has no group id, so it cannot be rotated.
  const [orchestrationOff, setOrchestrationOff] = useState(false);
  // A rotated webhook secret is shown once, inside the open RotateDialog. Until
  // it is acknowledged, every in-page exit that would unmount the dialog is
  // closed -- the row buttons here, the settings tabs through the callback --
  // and a reload/close asks for confirmation. Switching tenants and App Router
  // navigation (sidebar, breadcrumb) cannot be intercepted.
  const [secretAtRisk, setSecretAtRiskState] = useState(false);
  const setSecretAtRisk = useCallback(
    (atRisk: boolean) => {
      setSecretAtRiskState(atRisk);
      onSecretAtRiskChange?.(atRisk);
    },
    [onSecretAtRiskChange],
  );
  useEffect(() => {
    if (!secretAtRisk) return;
    const onBeforeUnload = (e: BeforeUnloadEvent) => {
      e.preventDefault();
    };
    window.addEventListener("beforeunload", onBeforeUnload);
    return () => window.removeEventListener("beforeunload", onBeforeUnload);
  }, [secretAtRisk]);
  // An unmount (a tenant switch that drops admin, say) must not leave the
  // page's tabs locked.
  useEffect(() => () => onSecretAtRiskChange?.(false), [onSecretAtRiskChange]);
  const [removing, setRemoving] = useState<string | null>(null);
  const [confirmRemove, setConfirmRemove] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (!currentTenant) return;
    setError(null);
    setOrchestrationOff(false);
    try {
      const list = await listVcsInstallations(currentTenant.id);
      const [gl, gh] = await Promise.all([
        executeMQL(GITLAB_NAMES_QUERY).catch((e) => {
          if (!orchestrationUnavailable(e)) throw e;
          setOrchestrationOff(true);
          return { data: [] as unknown[] };
        }),
        executeMQL(GITHUB_NAMES_QUERY).catch((e) => {
          if (!orchestrationUnavailable(e)) throw e;
          setOrchestrationOff(true);
          return { data: [] as unknown[] };
        }),
      ]);
      const glById = new Map(
        gl.data.map((r) => {
          const o = r as Record<string, unknown>;
          return [s(o.core_id), { id: n(o.installation_id), name: s(o.name), state: s(o.state) }] as const;
        }),
      );
      const ghById = new Map(
        gh.data.map((r) => {
          const o = r as Record<string, unknown>;
          return [s(o.core_id), { name: s(o.login), state: s(o.state) }] as const;
        }),
      );
      setRows(
        list.results.map((inst: VcsInstallation) => {
          const gitlab = inst.provider === "gitlab" ? glById.get(inst.installation_core_id) : undefined;
          const github = inst.provider === "github" ? ghById.get(inst.installation_core_id) : undefined;
          return {
            provider: inst.provider,
            coreId: inst.installation_core_id,
            linkedAt: inst.created_at,
            providerId: gitlab ? gitlab.id : null,
            name: gitlab?.name ?? github?.name ?? "",
            state: gitlab?.state ?? github?.state ?? "",
          };
        }),
      );
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to load integrations.");
    }
  }, [currentTenant]);

  useEffect(() => {
    const t = window.setTimeout(() => void load(), 0);
    return () => window.clearTimeout(t);
  }, [load]);

  const remove = async (row: Row) => {
    if (!currentTenant) return;
    setError(null);
    setRemoving(row.coreId);
    try {
      await unlinkVcsInstallation(currentTenant.id, row.provider, row.coreId);
      track("vcs_integration_removed", { vcs_provider: row.provider });
      setConfirmRemove(null);
      await load();
    } catch (e) {
      const message = vcsUnlinkErrorMessage(e, "Failed to remove the integration.");
      // A 404 row is stale: drop it. load() clears the error first, so set ours after it.
      if ((e as { status?: number } | null)?.status === 404) {
        setConfirmRemove(null);
        await load();
      }
      setError(message);
    } finally {
      setRemoving(null);
    }
  };

  if (!currentTenant) return null;

  return (
    <div className="space-y-3">
      <div className="flex items-center justify-between">
        <p className="text-sm text-[var(--sg-text-muted)]">
          {orchestrationOff
            ? "Orchestration is not enabled on this server: installations are listed by id, and GitLab credentials cannot be rotated."
            : "VCS installations linked to this tenant. GitLab credentials (access token, webhook secret) can be rotated here by a tenant admin."}
        </p>
        <Button variant="outline" size="sm" onClick={() => void load()}>
          <RefreshCw className="h-3.5 w-3.5 mr-1" /> Refresh
        </Button>
      </div>
      {error ? <div className="text-sm text-[var(--sg-error)]">{error}</div> : null}
      {rows === null ? (
        error ? null : <div className="text-sm text-[var(--sg-text-muted)]">Loading…</div>
      ) : rows.length === 0 ? (
        <div className="text-sm text-[var(--sg-text-muted)]">
          No VCS installations linked yet — connect one from Get Started.
        </div>
      ) : (
        <div className="space-y-2">
          {rows.map((row) => (
            <div key={`${row.provider}-${row.coreId}`} className="rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-1)] p-3 space-y-3">
              <div className="flex items-center gap-3 flex-wrap">
                {row.provider === "gitlab" ? (
                  <GitlabIcon className="h-4 w-4 text-[var(--sg-text-muted)]" />
                ) : (
                  <GithubIcon className="h-4 w-4 text-[var(--sg-text-muted)]" />
                )}
                <span className="text-sm font-medium text-[var(--sg-text)]">
                  {row.name || row.coreId}
                </span>
                {row.state ? (
                  <span className="text-xs px-1.5 py-0.5 rounded border border-[var(--sg-border)] bg-[var(--sg-bg-2)] text-[var(--sg-text-muted)]">
                    {row.state}
                  </span>
                ) : null}
                <span className="text-xs text-[var(--sg-text-dim)]">{row.provider}</span>
                <span className="ml-auto text-xs text-[var(--sg-text-muted)]">
                  linked {new Date(row.linkedAt).toLocaleDateString()}
                </span>
                {row.provider === "gitlab" && row.providerId ? (
                  <Button
                    variant="outline"
                    size="sm"
                    disabled={rotating !== null}
                    onClick={() => setRotating(row.coreId)}
                  >
                    <KeyRound className="h-3.5 w-3.5 mr-1" />
                    Rotate credentials
                  </Button>
                ) : null}
                <Button
                  variant="outline"
                  size="sm"
                  className="text-[var(--sg-error)] border-[var(--sg-error)]/30 hover:bg-[var(--sg-error)]/10 hover:border-[var(--sg-error)]"
                  disabled={rotating !== null || removing !== null}
                  onClick={() => setConfirmRemove(confirmRemove === row.coreId ? null : row.coreId)}
                >
                  <Trash2 className="h-3.5 w-3.5 mr-1" />
                  Remove
                </Button>
              </div>
              {row.provider === "gitlab" && !row.providerId && !orchestrationOff ? (
                <div className="text-xs text-[var(--sg-text-muted)]">
                  Rotation unavailable: this group&apos;s details could not be read, which happens
                  when you are not a member of this tenant.
                </div>
              ) : null}
              {confirmRemove === row.coreId ? (
                <div className="rounded-md bg-[var(--sg-error)]/5 border border-[var(--sg-error)]/30 px-3 py-2.5 space-y-2">
                  <div className="text-sm text-[var(--sg-text)]">{unlinkConfirmation(row)}</div>
                  <div className="flex justify-end gap-2">
                    <Button variant="outline" size="sm" onClick={() => setConfirmRemove(null)}>
                      Cancel
                    </Button>
                    <Button
                      size="sm"
                      className="bg-[var(--sg-error)] hover:bg-[var(--sg-error)]/90 text-white"
                      onClick={() => void remove(row)}
                      disabled={removing === row.coreId}
                    >
                      {removing === row.coreId ? <Loader2 className="h-3.5 w-3.5 mr-1 animate-spin" /> : null}
                      Remove integration
                    </Button>
                  </div>
                </div>
              ) : null}
              {rotating === row.coreId && row.providerId ? (
                <RotateDialog
                  row={row}
                  tenantId={currentTenant.id}
                  onSecretAtRisk={setSecretAtRisk}
                  onClose={() => {
                    setSecretAtRisk(false);
                    setRotating(null);
                  }}
                />
              ) : null}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
