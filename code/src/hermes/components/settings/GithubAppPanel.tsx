"use client";

import { useCallback, useEffect, useState } from "react";
import { useSearchParams } from "next/navigation";
import { ExternalLink, Github, KeyRound, Loader2, RefreshCw, Trash2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Timestamp } from "@/components/ui/timestamp";
import {
  createGithubAppManifest,
  deleteGithubApp,
  getGithubApp,
  setGithubAppCredentials,
  type GithubAppResponse,
} from "@/lib/api/client";
import { useCapabilities } from "@/hooks";
import {
  GITHUB_APP_REPLACE_WARNING,
  GITHUB_APP_ROTATE_WARNING,
  githubAppCredentials,
  githubAppCredentialsError,
  githubAppDeleteConfirmation,
  githubAppEngineState,
  githubAppSourceDescription,
} from "@/lib/getting-started/github-app-panel";
import {
  GITHUB_APP_NAME_MAX,
  GITHUB_APP_RESULT_MESSAGE,
  githubAppNameSuggestion,
  githubAppResult,
  postGithubAppManifest,
} from "@/lib/getting-started/github-app";
import { githubAppErrorMessage } from "@/app/(console)/settings/githubAppErrors";

/* The engine restarts on a write, so the panel re-reads until it reports itself
   running. Bounded: an App the engine cannot run never reports ready, and a tab
   left open must not ask forever. */
const READY_POLL_MS = 3000;
const READY_POLL_LIMIT = 20;

/* Where GitHub returns the operator after a replace. Without it the manifest
   flow lands on the getting-started wizard, which is the other caller. */
const RETURN_PATH = "/settings/?tab=integrations";

type Action = "replace" | "rotate" | "delete";

export function GithubAppPanel() {
  const { capabilities } = useCapabilities();
  const searchParams = useSearchParams();
  /* GitHub's manifest flow returns here after a Replace, with the outcome in
     the query. */
  const result = githubAppResult(searchParams.get("github_app"));
  const [app, setApp] = useState<GithubAppResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [open, setOpen] = useState<Action | null>(null);
  const [name, setName] = useState(githubAppNameSuggestion);
  const [organization, setOrganization] = useState("");
  const [pem, setPem] = useState("");
  const [clientSecret, setClientSecret] = useState("");
  const [webhookSecret, setWebhookSecret] = useState("");

  const load = useCallback(async (): Promise<void> => {
    try {
      const res = await getGithubApp();
      setApp(res);
      setError(null);
    } catch (e) {
      setError(githubAppErrorMessage(e, "Failed to read the GitHub App."));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  const stored = app?.source === "stored" ? app.app : undefined;
  const waiting = stored !== undefined && !stored.loaded;

  const [polls, setPolls] = useState(0);
  useEffect(() => {
    if (!waiting || polls >= READY_POLL_LIMIT) return;
    let inFlight = false;
    const id = window.setInterval(() => {
      if (inFlight || document.hidden) return;
      inFlight = true;
      setPolls((n) => n + 1);
      void load().finally(() => {
        inFlight = false;
      });
    }, READY_POLL_MS);
    return () => window.clearInterval(id);
  }, [waiting, polls, load]);

  const replace = async () => {
    setError(null);
    setBusy(true);
    try {
      const trimmed = organization.trim();
      // replace: the server refuses a manifest when it already holds an App,
      // so that a stale tab cannot create a second one on GitHub. This is the
      // deliberate swap.
      const form = await createGithubAppManifest({
        name: name.trim(),
        replace: true,
        rd: RETURN_PATH,
        ...(trimmed === "" ? {} : { organization: trimmed }),
      });
      postGithubAppManifest(form);
    } catch (e) {
      setError(githubAppErrorMessage(e, "Failed to prepare the new GitHub App."));
      setBusy(false);
    }
  };

  const credentials = githubAppCredentials({ pem, clientSecret, webhookSecret });
  const credentialsError = githubAppCredentialsError(credentials);

  const clearRotation = () => {
    setPem("");
    setClientSecret("");
    setWebhookSecret("");
  };

  const rotate = async () => {
    if (stored === undefined || credentialsError !== null) return;
    setError(null);
    setBusy(true);
    try {
      await setGithubAppCredentials(stored.app_id, credentials);
      clearRotation();
      setOpen(null);
      await load();
    } catch (e) {
      setError(githubAppErrorMessage(e, "Failed to store the credentials."));
    } finally {
      setBusy(false);
    }
  };

  const remove = async () => {
    if (stored === undefined) return;
    setError(null);
    setBusy(true);
    try {
      await deleteGithubApp(stored.app_id);
      setOpen(null);
      await load();
    } catch (e) {
      setError(githubAppErrorMessage(e, "Failed to remove the GitHub App."));
    } finally {
      setBusy(false);
    }
  };

  if (loading) {
    return (
      <div className="p-4 text-sm text-[var(--sg-text-muted)] flex items-center gap-2">
        <Loader2 className="h-4 w-4 animate-spin" /> Loading…
      </div>
    );
  }

  const source = app?.source ?? "none";
  const appUrl = stored?.html_url ?? capabilities?.github_app_url;

  return (
    <div className="space-y-4">
      <p className="text-sm text-[var(--sg-text-muted)]">{githubAppSourceDescription(source)}</p>

      {result !== null && result !== "created" ? (
        <div className="rounded-md border border-[var(--sg-warning)]/30 bg-[var(--sg-warning)]/10 px-3 py-2 text-sm text-[var(--sg-warning)]">
          {GITHUB_APP_RESULT_MESSAGE[result]}
        </div>
      ) : null}

      {waiting && polls >= READY_POLL_LIMIT ? (
        <div className="rounded-md border border-[var(--sg-warning)]/30 bg-[var(--sg-warning)]/10 px-3 py-2 text-sm text-[var(--sg-warning)]">
          The orchestration engine has not picked this App up. Check its log, then refresh.
        </div>
      ) : null}

      {error ? <div className="text-sm text-[var(--sg-error)]">{error}</div> : null}

      {stored ? (
        <div className="rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-1)] p-3 space-y-2">
          <div className="flex items-center gap-3">
            <Github className="h-4 w-4 text-[var(--sg-text-muted)]" />
            <span className="font-mono text-sm text-[var(--sg-text)]">{stored.slug}</span>
            <span className="text-xs text-[var(--sg-text-dim)]">app id {stored.app_id}</span>
            <span className="ml-auto text-xs text-[var(--sg-text-dim)]">
              <Timestamp date={stored.created_at} relative />
            </span>
          </div>
          <div className="text-xs text-[var(--sg-text-muted)] flex items-center gap-2">
            {waiting ? <Loader2 className="h-3 w-3 animate-spin" /> : null}
            {githubAppEngineState(stored.loaded)}
          </div>
        </div>
      ) : null}

      <div className="flex flex-wrap gap-2">
        {appUrl ? (
          <Button asChild variant="outline" size="sm">
            <a href={appUrl} target="_blank" rel="noreferrer">
              <ExternalLink className="h-4 w-4 mr-1" /> Open on GitHub
            </a>
          </Button>
        ) : null}
        <Button variant="outline" size="sm" onClick={() => void load()} disabled={busy}>
          <RefreshCw className="h-4 w-4 mr-1" /> Refresh
        </Button>
        {stored !== undefined ? (
          <>
            <Button
              variant="outline"
              size="sm"
              onClick={() => setOpen(open === "replace" ? null : "replace")}
              disabled={busy}
            >
              <Github className="h-4 w-4 mr-1" /> Replace
            </Button>
            <Button
              variant="outline"
              size="sm"
              onClick={() => setOpen(open === "rotate" ? null : "rotate")}
              disabled={busy}
            >
              <KeyRound className="h-4 w-4 mr-1" /> Rotate credentials
            </Button>
            <Button
              variant="outline"
              size="sm"
              onClick={() => setOpen(open === "delete" ? null : "delete")}
              disabled={busy}
              className="text-[var(--sg-error)] border-[var(--sg-error)]/30 hover:bg-[var(--sg-error)]/10 hover:border-[var(--sg-error)]"
            >
              <Trash2 className="h-4 w-4 mr-1" /> Remove
            </Button>
          </>
        ) : null}
      </div>

      {open === "replace" ? (
        <div className="rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-2)] p-3 space-y-3">
          <p className="text-sm text-[var(--sg-text-muted)]">{GITHUB_APP_REPLACE_WARNING}</p>
          <div className="space-y-1.5">
            <div className="text-sm text-[var(--sg-text)]">App name</div>
            <Input
              value={name}
              onChange={(e) => {
                setError(null);
                setName(e.target.value);
              }}
              maxLength={GITHUB_APP_NAME_MAX}
              placeholder="stategraph-a1b2c3d4"
            />
          </div>
          <div className="space-y-1.5">
            <div className="text-sm text-[var(--sg-text)]">Organization</div>
            <Input
              value={organization}
              onChange={(e) => {
                setError(null);
                setOrganization(e.target.value);
              }}
              placeholder="my-org"
            />
            <p className="text-xs text-[var(--sg-text-muted)]">
              Leave empty to create the App on your own account.
            </p>
          </div>
          <div className="flex justify-end gap-2">
            <Button variant="outline" size="sm" onClick={() => setOpen(null)} disabled={busy}>
              Cancel
            </Button>
            <Button size="sm" onClick={() => void replace()} disabled={busy || name.trim() === ""}>
              {busy ? (
                <>
                  <Loader2 className="h-4 w-4 mr-1 animate-spin" /> Opening GitHub…
                </>
              ) : (
                "Create on GitHub"
              )}
            </Button>
          </div>
        </div>
      ) : null}

      {open === "rotate" ? (
        <div className="rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-2)] p-3 space-y-3">
          <p className="text-sm text-[var(--sg-text-muted)]">{GITHUB_APP_ROTATE_WARNING}</p>
          <div className="space-y-1.5">
            <div className="text-sm text-[var(--sg-text)]">Private key</div>
            <Textarea
              value={pem}
              onChange={(e) => {
                setError(null);
                setPem(e.target.value);
              }}
              placeholder="-----BEGIN RSA PRIVATE KEY-----"
              spellCheck={false}
              className="h-32 font-mono text-xs"
            />
          </div>
          <div className="space-y-1.5">
            <div className="text-sm text-[var(--sg-text)]">Client secret</div>
            <Input
              type="password"
              value={clientSecret}
              onChange={(e) => {
                setError(null);
                setClientSecret(e.target.value);
              }}
              spellCheck={false}
              className="font-mono text-xs"
            />
            <p className="text-xs text-[var(--sg-text-muted)]">
              Signs console users in. A stale one breaks sign-in, not webhooks.
            </p>
          </div>
          <div className="space-y-1.5">
            <div className="text-sm text-[var(--sg-text)]">Webhook secret</div>
            <Input
              type="password"
              value={webhookSecret}
              onChange={(e) => {
                setError(null);
                setWebhookSecret(e.target.value);
              }}
              spellCheck={false}
              className="font-mono text-xs"
            />
            <p className="text-xs text-[var(--sg-text-muted)]">
              Signs webhook events. A stale one stops every run.
            </p>
          </div>
          <div className="flex items-center justify-end gap-2">
            {credentialsError !== null ? (
              <p className="mr-auto text-xs text-[var(--sg-text-muted)]">{credentialsError}</p>
            ) : null}
            <Button
              variant="outline"
              size="sm"
              onClick={() => {
                clearRotation();
                setOpen(null);
              }}
              disabled={busy}
            >
              Cancel
            </Button>
            <Button
              size="sm"
              onClick={() => void rotate()}
              disabled={busy || credentialsError !== null}
            >
              {busy ? <Loader2 className="h-4 w-4 mr-1 animate-spin" /> : null}
              Store
            </Button>
          </div>
        </div>
      ) : null}

      {open === "delete" && stored ? (
        <div className="rounded-lg border border-[var(--sg-error)]/30 bg-[var(--sg-error)]/10 p-3 space-y-3">
          <p className="text-sm text-[var(--sg-error)]">
            {githubAppDeleteConfirmation(stored.slug)}
          </p>
          <div className="flex justify-end gap-2">
            <Button variant="outline" size="sm" onClick={() => setOpen(null)} disabled={busy}>
              Cancel
            </Button>
            <Button variant="destructive" size="sm" onClick={() => void remove()} disabled={busy}>
              {busy ? <Loader2 className="h-4 w-4 mr-1 animate-spin" /> : null}
              Remove
            </Button>
          </div>
        </div>
      ) : null}
    </div>
  );
}
