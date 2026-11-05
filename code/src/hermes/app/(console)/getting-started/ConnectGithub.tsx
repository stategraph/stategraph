"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { useSearchParams } from "next/navigation";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardHeader,
  CardTitle,
  CardDescription,
  CardContent,
} from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { ArrowRight, Check, Github, Loader2, RefreshCw } from "lucide-react";
import { WizardShell } from "@/components/getting-started";
import { StepHeading } from "./orchestrationSteps";
import { useInstallationGate } from "./useInstallationGate";
import {
  claimGithubInstallation,
  createGithubAppManifest,
  githubClaimStartUrl,
  linkVcsInstallation,
  listClaimableGithub,
  listUnclaimedGithub,
  type GithubUnclaimedInstallation,
} from "@/lib/api/client";
import {
  GITHUB_APP_NAME_MAX,
  GITHUB_APP_RESULT_MESSAGE,
  GITHUB_CONNECT_STEP_LABELS,
  githubAppNameSuggestion,
  githubAppResult,
  githubConnectStep,
  githubConnectSteps,
  githubInstallUrl,
  postGithubAppManifest,
  type GithubConnectStep,
} from "@/lib/getting-started/github-app";
import { useSetupProgress, useTenant } from "@/contexts";
import { useAuth } from "@/components/auth";
import { useCapabilities } from "@/hooks";
import { isInstanceAdmin, isTenantAdmin } from "@/lib/api/capabilities";
import { OrchestrationUnavailable } from "@/components/orchestration";
import { pushGettingStartedEvent } from "@/lib/analytics";
import type { VcsProvider } from "@/lib/vcs/links";
import {
  ORCHESTRATION_COPY,
  githubConnectedDescription,
} from "@/lib/getting-started/orchestration-constants";
import {
  TENANT_ADMIN_REQUIRED,
  githubConnectErrorMessage,
  githubConnectRefusal,
  githubSelfServeErrorMessage,
  githubSelfServeRefusal,
} from "./githubConnectErrors";

// The create step polls the server this often while the engine restarts with
// the new App.
const READY_POLL_MS = 3000;

// Where the browser lands after GitHub answers. The backend honours a
// site-relative path, or an absolute URL on the console's own origin.
const CLAIM_RETURN_PATH = "/getting-started/?path=github";

// What claim start and the callback append to that path. Anything else means
// the handshake did not complete, and each case needs a different sentence: only
// "no_admin" is the user's to act on.
const CLAIM_RESULT_MESSAGE: Record<string, string> = {
  installed:
    "The GitHub app is installed. Verify with GitHub to link the installation to this tenant.",
  requested:
    "An owner of the GitHub organization must approve the install. Then an owner must link the installation to this tenant.",
  no_admin:
    "GitHub did not report any organization you administer with the Stategraph app installed. Install the app on an organization you own, or ask one of its owners to connect it.",
  forbidden:
    "Stategraph could not read your GitHub organization memberships. This is a server configuration problem, not something you can fix. Ask an admin to link the installation for you.",
  expired: "That took too long, so the request was discarded. Verify with GitHub again.",
  error: "Something went wrong talking to GitHub. Try again.",
  unavailable:
    "Orchestration or the GitHub app's OAuth client is not configured on this server, so it cannot verify your access.",
  not_member:
    "You are not a member of this tenant, so you cannot link an installation to it. Ask one of its admins to add you.",
};

/** A listed installation plus the cursor of the page it arrived on, so a claim can
 *  re-read that page to check the row is still unclaimed. The self-serve list is
 *  not paginated, so its rows carry a null cursor. */
type Row = GithubUnclaimedInstallation & {
  pageCursor: string | null;
};

interface ConnectGithubProps {
  onBack: () => void;
  onRepositories: () => void;
  onConnected?: (provider: VcsProvider) => void;
}

export function ConnectGithub({ onBack, onRepositories, onConnected }: ConnectGithubProps) {
  const { currentTenant } = useTenant();
  const { user } = useAuth();
  const { capabilities, refresh: refreshCapabilities } = useCapabilities();
  const { refresh: refreshSetupProgress } = useSetupProgress();
  const searchParams = useSearchParams();
  const appUrl = capabilities?.github_app_url;
  const githubApp = capabilities?.github_app;
  const githubAppRes = githubAppResult(searchParams.get("github_app"));
  // Installing the app on your own GitHub organization is the half anyone can
  // do, and is the prerequisite for either claim, so the wizard must not hide it.
  // Claiming is instance admin (any unclaimed installation) or tenant admin (an
  // installation GitHub says they administer).
  const instanceAdmin = isInstanceAdmin(user?.capabilities);
  const tenantAdmin = isTenantAdmin(user?.capabilities, currentTenant?.id);

  const claimResult = searchParams.get("github_claim");
  const proven = claimResult === "ready";

  // Null until the user moves the wizard by hand; until then the server's own
  // report decides, so there is one rule rather than a state to keep in step
  // with it.
  const [chosenStep, setStep] = useState<GithubConnectStep | null>(null);
  const step =
    chosenStep ??
    githubConnectStep({
      claimResult,
      creatable: githubApp?.creatable ?? true,
      ready: githubApp?.ready ?? false,
    });
  const [appName, setAppName] = useState(githubAppNameSuggestion);
  const [organization, setOrganization] = useState("");
  const [creating, setCreating] = useState(false);
  // The App is stored and the engine is restarting with it: the install link
  // must wait, or the install webhook lands on nothing.
  const waiting = githubApp !== undefined && githubApp.configured && !githubApp.ready;

  useEffect(() => {
    if (!waiting || step !== "create") return;
    let cancelled = false;
    const id = window.setInterval(() => {
      if (!cancelled) refreshCapabilities();
    }, READY_POLL_MS);
    return () => {
      cancelled = true;
      window.clearInterval(id);
    };
  }, [waiting, step, refreshCapabilities]);

  const createApp = async () => {
    setError(null);
    setCreating(true);
    try {
      const trimmedOrganization = organization.trim();
      const res = await createGithubAppManifest({
        name: appName.trim(),
        ...(trimmedOrganization === "" ? {} : { organization: trimmedOrganization }),
      });
      pushGettingStartedEvent("getting_started_step_completed", {
        path: "github",
        step: "github_app_create_started",
      });
      postGithubAppManifest(res);
    } catch (e) {
      setError(githubConnectErrorMessage(e, "Failed to prepare the GitHub App."));
      setCreating(false);
    }
  };
  const [installs, setInstalls] = useState<Row[] | null>(null);
  // The cursor for the page after the ones loaded, or null when the end has been
  // reached. Nothing is hidden: every installation is reachable by walking.
  const [nextCursor, setNextCursor] = useState<string | null>(null);
  const [loadingMore, setLoadingMore] = useState(false);
  const [claimedLogin, setClaimedLogin] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  // instanceAdmin reads the session's capabilities; the server is the one that
  // decides. A grant revoked mid-session still lands here, and the list is then
  // unreachable, so the step says so instead of looking empty.
  const [forbidden, setForbidden] = useState(false);
  // 503 from the list endpoint: the server runs without orchestration, so the
  // terrateam read FDW this whole path depends on was never built.
  const [unavailable, setUnavailable] = useState(false);
  // 412 from the self-serve endpoints: the proof is missing, expired, or was
  // minted for another user or tenant, so the handshake has to run again.
  const [proofSpent, setProofSpent] = useState(false);

  // Which list step 1 shows. A proof takes precedence, since the user just
  // completed the handshake for it; otherwise an instance admin gets the full
  // unclaimed list, and a tenant admin is offered the handshake.
  const selfServe = proven && !proofSpent;
  const adminList = !selfServe && instanceAdmin && !forbidden;
  const offerVerify = !selfServe && !adminList && tenantAdmin;

  /** Load one page. A null cursor restarts at the newest; anything else appends. */
  const load = useCallback(async (cursor: string | null) => {
    setError(null);
    if (cursor === null) setLoading(true);
    else setLoadingMore(true);
    try {
      const res = await listUnclaimedGithub(cursor);
      const rows: Row[] = res.results.map((r) => ({ ...r, pageCursor: cursor }));
      setInstalls((prev) => (cursor === null || prev === null ? rows : [...prev, ...rows]));
      setNextCursor(res.has_more ? (res.next_cursor ?? null) : null);
      setForbidden(false);
    } catch (e) {
      switch (githubConnectRefusal(e)) {
        case "orchestration":
          setUnavailable(true);
          break;
        case "capability":
          setForbidden(true);
          break;
        default:
          setError(githubConnectErrorMessage(e, "Failed to load installations."));
      }
      if (cursor === null) setInstalls([]);
    } finally {
      setLoading(false);
      setLoadingMore(false);
    }
  }, []);

  /** A failure on the self-serve endpoints. Their 403 is not the instance-admin
   *  gate, so it is never answered by asking for an instance admin. */
  const selfServeFailed = useCallback((e: unknown, fallback: string) => {
    switch (githubSelfServeRefusal(e)) {
      case "orchestration":
        setUnavailable(true);
        break;
      case "proof":
        setProofSpent(true);
        setInstalls(null);
        break;
      default:
        setError(githubSelfServeErrorMessage(e, fallback));
    }
  }, []);

  /** The installations the proof names that no tenant holds yet. */
  const loadClaimable = useCallback(async () => {
    if (!currentTenant) return;
    setError(null);
    setLoading(true);
    try {
      const res = await listClaimableGithub(currentTenant.id);
      setInstalls(res.results.map((r) => ({ ...r, pageCursor: null })));
      setNextCursor(null);
    } catch (e) {
      selfServeFailed(e, "Failed to load installations.");
      setInstalls([]);
    } finally {
      setLoading(false);
    }
  }, [currentTenant, selfServeFailed]);

  const refresh = useCallback(
    () => (selfServe ? loadClaimable() : load(null)),
    [selfServe, loadClaimable, load]
  );

  useEffect(() => {
    if (step === "link" && (selfServe || adminList)) void refresh();
  }, [step, selfServe, adminList, refresh]);

  const verifyWithGithub = () => {
    if (!currentTenant) return;
    pushGettingStartedEvent("getting_started_step_completed", {
      path: "github",
      step: "github_identity_verification_started",
    });
    // In development the console and the API are on different ports, so the
    // return has to name the console's origin; in production a path is enough.
    const rd =
      process.env.NODE_ENV === "development"
        ? window.location.origin + CLAIM_RETURN_PATH
        : CLAIM_RETURN_PATH;
    window.location.href = githubClaimStartUrl(currentTenant.id, rd);
  };

  const claim = async (inst: Row) => {
    if (!currentTenant) {
      setError("Select a tenant first.");
      return;
    }
    setError(null);
    setLoading(true);
    try {
      if (selfServe) {
        // The server links only an installation no tenant holds, in the same
        // statement that checks it, so a lost race answers 409 instead of
        // moving the installation.
        await claimGithubInstallation(currentTenant.id, inst.installation_core_id);
      } else {
        // The list is a snapshot, and the link endpoint MOVES an installation
        // rather than refusing one another tenant already holds. Re-read first so
        // a claim that raced another admin stops here, instead of silently taking
        // the installation away from whoever got there first. This narrows the
        // window rather than closing it; only the server can do that.
        //
        // Re-read the page this row came from, not the first one: with the list
        // paginated, a row further down is legitimately absent from page one and
        // would otherwise read as someone else's claim.
        const current = await listUnclaimedGithub(inst.pageCursor);
        if (!current.results.some((i) => i.installation_core_id === inst.installation_core_id)) {
          // Re-list first: a listing clears the banner as it starts.
          await refresh();
          setError(`${inst.login} was claimed by someone else while this list was open.`);
          return;
        }
        await linkVcsInstallation(currentTenant.id, "github", inst.installation_core_id);
      }
      setClaimedLogin(inst.login);
      refreshSetupProgress();
      // The event name is the whole funnel signal; the installation's GitHub id
      // is an identifier and must not reach the tag manager's data layer.
      pushGettingStartedEvent("getting_started_github_installation_claimed", { path: "github" });
      pushGettingStartedEvent("getting_started_completed", { path: "github" });
      setStep("done");
    } catch (e) {
      const status = (e as { status?: number } | null)?.status;
      if (selfServe && status === 409) {
        // Another tenant took it between the listing and the claim. Re-listing
        // is the honest response: the row is gone. The listing clears the
        // banner as it starts, so the message is set once it has finished.
        await refresh();
        setError(`${inst.login} was claimed by another tenant while this list was open.`);
      } else if (selfServe) selfServeFailed(e, "Failed to claim the installation.");
      else if (githubConnectRefusal(e) === "orchestration") setUnavailable(true);
      else setError(githubConnectErrorMessage(e, "Failed to claim the installation."));
    } finally {
      setLoading(false);
    }
  };


  // GitHub returns the user here after the install: start the verification at
  // once instead of asking for a click.
  const verifyRef = useRef(verifyWithGithub);
  verifyRef.current = verifyWithGithub;
  const [autoVerified, setAutoVerified] = useState(false);
  useEffect(() => {
    if (autoVerified || claimResult !== "installed" || !offerVerify || !currentTenant) return;
    setAutoVerified(true);
    verifyRef.current();
  }, [autoVerified, claimResult, offerVerify, currentTenant]);

  // One administered installation to link: link it without a second click.
  const claimRef = useRef(claim);
  claimRef.current = claim;
  const [autoClaimed, setAutoClaimed] = useState(false);
  useEffect(() => {
    if (autoClaimed || !selfServe || loading || installs === null || installs.length !== 1) return;
    setAutoClaimed(true);
    void claimRef.current(installs[0]);
  }, [autoClaimed, selfServe, loading, installs]);

  // An installation already linked to this tenant: continue to the repository
  // step rather than offering the link flow again.
  const { state: linked } = useInstallationGate(currentTenant?.id ?? "", {
    enabled: tenantAdmin && currentTenant !== null,
  });
  const linkedGithub = linked.rows.some((row) => row.provider === "github");
  const [relink, setRelink] = useState(false);
  const showLinkFlow = !linkedGithub || relink || claimResult !== null || step === "done";

  if (unavailable) return <OrchestrationUnavailable />;

  return (
    <WizardShell
      steps={githubConnectSteps(githubApp?.creatable ?? true)}
      labels={GITHUB_CONNECT_STEP_LABELS}
      currentStep={step}
      onReset={onBack}
    >
      <StepHeading
        title="Connect GitHub"
        lead="Create the Stategraph GitHub App, install it, then link the installation to this tenant."
      />

      {githubAppRes !== null && githubAppRes !== "created" ? (
        <div className="rounded-md border border-[var(--sg-warning)]/30 bg-[var(--sg-warning)]/10 px-3 py-2 text-sm text-[var(--sg-warning)]">
          {GITHUB_APP_RESULT_MESSAGE[githubAppRes]}
        </div>
      ) : null}

      {step === "create" ? (
        <Card>
          <CardHeader>
            <CardTitle>Create the GitHub App</CardTitle>
            <CardDescription>
              Stategraph needs a GitHub App of its own. GitHub opens with the App filled in. Create
              it there, and GitHub brings you back here.
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            {githubApp === undefined ? (
              <div className="p-4 text-sm text-[var(--sg-text-muted)] flex items-center gap-2">
                <Loader2 className="h-4 w-4 animate-spin" /> Loading…
              </div>
            ) : waiting ? (
              <div className="p-4 text-sm text-[var(--sg-text-muted)] flex items-center gap-2">
                <Loader2 className="h-4 w-4 animate-spin" /> The App is created. Starting the
                orchestration engine.
              </div>
            ) : !instanceAdmin ? (
              <div className="rounded-md border border-[var(--sg-warning)]/30 bg-[var(--sg-warning)]/10 px-3 py-2 text-sm text-[var(--sg-warning)]">
                Creating the App needs an instance admin. Ask one to open this page.
              </div>
            ) : (
              <>
                <div className="space-y-1.5">
                  <div className="text-sm text-[var(--sg-text)]">App name</div>
                  <Input
                    value={appName}
                    onChange={(e) => {
                      setError(null);
                      setAppName(e.target.value);
                    }}
                    maxLength={GITHUB_APP_NAME_MAX}
                    placeholder="stategraph-a1b2c3d4"
                  />
                  <p className="text-xs text-[var(--sg-text-muted)]">
                    GitHub requires a name no other App uses.
                  </p>
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
                <div className="flex justify-end pt-2">
                  <Button
                    onClick={() => void createApp()}
                    disabled={creating || appName.trim() === ""}
                  >
                    {creating ? (
                      <>
                        <Loader2 className="h-4 w-4 mr-1 animate-spin" /> Opening GitHub…
                      </>
                    ) : (
                      <>
                        Create on GitHub <ArrowRight className="h-4 w-4 ml-1" />
                      </>
                    )}
                  </Button>
                </div>
              </>
            )}
          </CardContent>
        </Card>
      ) : null}

      {!showLinkFlow ? (
        <Card>
          <CardHeader>
            <CardTitle>GitHub is connected</CardTitle>
            <CardDescription>
              A GitHub installation is linked to this tenant. Continue to pick a repository, or link
              another installation.
            </CardDescription>
          </CardHeader>
          <CardContent className="flex flex-wrap gap-2">
            <Button onClick={() => onConnected?.("github")}>
              {ORCHESTRATION_COPY.handoff} <ArrowRight className="h-4 w-4 ml-1" />
            </Button>
            <Button variant="outline" onClick={() => setRelink(true)}>
              Link another installation
            </Button>
          </CardContent>
        </Card>
      ) : null}

      {error ? (
        <div className="p-3 rounded-lg bg-[var(--sg-error)]/10 border border-[var(--sg-error)]/30">
          <div className="text-sm text-[var(--sg-error)]">{error}</div>
        </div>
      ) : null}

      {showLinkFlow && step === "install" ? (
        <Card>
          <CardHeader>
            <CardTitle>Install the GitHub App</CardTitle>
            <CardDescription>
              Install the Stategraph GitHub App on the organization that owns your repositories.
              Choose the repositories it may read. GitHub opens, and brings you back here when the
              install is done.
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            {!instanceAdmin && !tenantAdmin ? (
              // Installing the app is real work on someone else's GitHub
              // organization. Say up front that the claim needs a grant this
              // session lacks, rather than letting them find out at step 2.
              <div className="rounded-md border border-[var(--sg-warning)]/30 bg-[var(--sg-warning)]/10 px-3 py-2 text-sm text-[var(--sg-warning)]">
                You can install the app. {TENANT_ADMIN_REQUIRED} Line one up before you start, or hand
                them this page once the app is installed.
              </div>
            ) : null}
            {appUrl ? (
              <Button asChild>
                <a href={githubInstallUrl(appUrl)}>
                  Install on GitHub <ArrowRight className="h-4 w-4 ml-1" />
                </a>
              </Button>
            ) : (
              <div className="rounded-md border border-[var(--sg-border)] bg-[var(--sg-bg-2)] px-3 py-2 text-sm text-[var(--sg-text-muted)]">
                No app install URL is configured on this server. Install the Stategraph GitHub app from
                your GitHub organization&apos;s settings, then continue to claim it.
              </div>
            )}
            <div className="flex justify-end pt-2">
              <Button variant="outline" onClick={() => setStep("link")}>
                I installed it
                <ArrowRight className="h-4 w-4 ml-1" />
              </Button>
            </div>
          </CardContent>
        </Card>
      ) : null}

      {showLinkFlow && step === "link" ? (
        <Card>
          <CardHeader>
            <CardTitle>Link the installation</CardTitle>
            <CardDescription>
              Pick the installation to link to this tenant. If it is not here yet, give GitHub a
              moment and refresh.
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            {claimResult !== null && claimResult !== "ready" ? (
              <div
                className={
                  // "installed" and "requested" are where GitHub drops the user
                  // after an app install: a prompt for the next step, not a failure.
                  claimResult === "installed" || claimResult === "requested"
                    ? "rounded-md border border-[var(--sg-border)] bg-[var(--sg-bg-2)] px-3 py-2 text-sm text-[var(--sg-text-muted)]"
                    : "rounded-md border border-[var(--sg-warning)]/30 bg-[var(--sg-warning)]/10 px-3 py-2 text-sm text-[var(--sg-warning)]"
                }
              >
                {CLAIM_RESULT_MESSAGE[claimResult] ?? CLAIM_RESULT_MESSAGE.error}
              </div>
            ) : null}

            {offerVerify ? (
              <div className="space-y-3">
                <div className="rounded-md border border-[var(--sg-border)] bg-[var(--sg-bg-2)] px-3 py-2 text-sm text-[var(--sg-text-muted)]">
                  Sign in with GitHub so Stategraph can confirm which organizations you administer.
                  You will only be offered installations on those organizations.
                </div>
                <Button onClick={verifyWithGithub} disabled={!currentTenant}>
                  <Github className="h-4 w-4 mr-1" /> Verify with GitHub
                </Button>
              </div>
            ) : !selfServe && !adminList ? (
              <div className="rounded-md border border-[var(--sg-warning)]/30 bg-[var(--sg-warning)]/10 px-3 py-2 text-sm text-[var(--sg-warning)]">
                {TENANT_ADMIN_REQUIRED}
              </div>
            ) : installs === null || loading ? (
              <div className="p-4 text-sm text-[var(--sg-text-muted)] flex items-center gap-2">
                <Loader2 className="h-4 w-4 animate-spin" /> Loading installations…
              </div>
            ) : installs.length === 0 ? (
              <div className="p-4 text-sm text-[var(--sg-text-muted)]">
                {selfServe
                  ? "Every organization you administer is already linked to a tenant. Install the app on another organization, then verify again."
                  : "No unclaimed installations found. Install the app on GitHub, then refresh."}
              </div>
            ) : (
              <div className="rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-1)] overflow-hidden divide-y divide-[var(--sg-border)]">
                {installs.map((inst) => (
                  <div key={inst.installation_core_id} className="flex items-center gap-3 px-4 py-3">
                    <Github className="h-4 w-4 text-[var(--sg-text-muted)]" />
                    <span className="font-mono text-sm text-[var(--sg-text)]">{inst.login}</span>
                    <span className="text-xs text-[var(--sg-text-dim)]">
                      {inst.target_type === "User" ? "personal account" : "organization"}
                    </span>
                    {inst.state === "suspended" ? (
                      <span
                        className="text-xs text-[var(--sg-warning)]"
                        title="The app is installed but suspended on GitHub. Unsuspend it there, or claiming it now will orchestrate nothing until you do."
                      >
                        suspended on GitHub
                      </span>
                    ) : (
                      <span className="text-xs text-[var(--sg-text-dim)]">{inst.state}</span>
                    )}
                    <Button size="sm" className="ml-auto" onClick={() => void claim(inst)} disabled={loading}>
                      Claim
                    </Button>
                  </div>
                ))}
              </div>
            )}
            {nextCursor && adminList ? (
              <div className="flex justify-center">
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => void load(nextCursor)}
                  disabled={loadingMore || loading}
                >
                  {loadingMore ? (
                    <>
                      <Loader2 className="h-4 w-4 mr-1 animate-spin" /> Loading…
                    </>
                  ) : (
                    "Load more"
                  )}
                </Button>
              </div>
            ) : null}
            <div className="flex justify-between pt-2">
              <Button
                variant="outline"
                onClick={() => void refresh()}
                disabled={loading || (!selfServe && !adminList)}
              >
                <RefreshCw className="h-4 w-4 mr-1" /> Refresh
              </Button>
            </div>
          </CardContent>
        </Card>
      ) : null}

      {step === "done" ? (
        <Card>
          <CardHeader>
            <CardTitle>Connected</CardTitle>
            <CardDescription>
              {githubConnectedDescription(claimedLogin)}
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="p-3 rounded-lg bg-[var(--sg-success)]/10 border border-[var(--sg-success)]/30">
              <div className="text-sm text-[var(--sg-success)] flex items-center gap-2">
                <Check className="h-4 w-4" />
                {claimedLogin} is connected.
              </div>
            </div>
            {onConnected ? (
              <Button onClick={() => onConnected("github")}>
                {ORCHESTRATION_COPY.handoff}
              </Button>
            ) : (
              <Button variant="outline" onClick={onRepositories}>
                View repositories
              </Button>
            )}
          </CardContent>
        </Card>
      ) : null}
    </WizardShell>
  );
}
