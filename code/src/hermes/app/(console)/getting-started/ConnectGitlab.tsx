"use client";

import { useEffect, useRef, useState } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  Card,
  CardHeader,
  CardTitle,
  CardDescription,
  CardContent,
} from "@/components/ui/card";
import {
  ArrowLeft,
  ArrowRight,
  Check,
  Copy,
  ExternalLink,
  Loader2,
} from "lucide-react";
import {
  executeMQL,
  getApiBase,
  listVcsInstallations,
  provisionGitlab,
  rotateGitlab,
} from "@/lib/api/client";
import { copyText } from "@/lib/utils/clipboard";
import { asText, orchestrationUnavailable } from "@/lib/mql/providers";
import { OrchestrationUnavailable } from "@/components/orchestration";
import { useSetupProgress, useTenant } from "@/contexts";
import { ENGINE_SETUP_HREF, STATE_SETUP_HREF } from "@/lib/getting-started/setup-progress";
import { useAuth } from "@/components/auth";
import { useDeepLinkRouter } from "@/hooks";
import { isTenantAdmin } from "@/lib/api/capabilities";
import { pushGettingStartedEvent } from "@/lib/analytics";
import {
  DEMO_REPOSITORIES,
  GITLAB_PIPELINE_YAML,
  ORCHESTRATION_COPY,
} from "@/lib/getting-started/orchestration-constants";
import {
  DEMO_REPOSITORY_SEARCH_VALUE,
  isRepositorySlug,
} from "@/lib/getting-started/orchestration-state";
import {
  gitlabBaseUrl,
  gitlabInstallationLinkQuery,
  gitlabInstallationStateQuery,
  gitlabResumeOutcome,
  gitlabWizardLinks,
  isValidGroupId,
} from "./mqlQueries";
import { gitlabProvisionErrorMessage } from "./gitlabProvisionErrors";
import { gitlabRotateErrorMessage } from "@/lib/api/gitlabRotateErrors";
import {
  CredentialsStep,
  DoneStep,
  FirstChangeStep,
  ForkStep,
  PullRequestStep,
} from "./orchestrationSteps";
import { WizardShell } from "@/components/getting-started";

const COPY = ORCHESTRATION_COPY;

/* The step lists are the iris getting-started `gitlab-setup` and
   `gitlab-demo-setup` flows (the guides the GitLab integration was built
   against; GitLab installs are finicky, so every step is carried over, copy
   as-is or very close), followed by the shared credentials and first request
   steps. The only iris step not ported is the group PICKER: the console has no
   GitLab OAuth to list groups, so the group is entered manually with
   where-to-find-it guidance. Verify is folded into the Webhook step exactly as
   iris does it. */
type Step =
  | "group"
  | "repo"
  | "fork"
  | "token"
  | "webhook"
  | "variables"
  | "pipeline"
  | "credentials"
  | "wait"
  | "change"
  | "done";

const OWN_STEPS: readonly Step[] = [
  "group",
  "repo",
  "token",
  "webhook",
  "variables",
  "pipeline",
  "credentials",
  "wait",
  "done",
];

const DEMO_STEPS: readonly Step[] = [
  "group",
  "repo",
  "fork",
  "token",
  "webhook",
  "variables",
  "change",
  "done",
];

const STEP_LABELS: Record<Step, string> = {
  group: "Group",
  repo: "Repository",
  fork: "Fork",
  token: "Token",
  webhook: "Webhook",
  variables: "CI/CD role",
  pipeline: "Pipeline",
  credentials: "Credentials",
  wait: "Merge request",
  change: "First change",
  done: "Done",
};

type RailStep = Step | "connect";

const RAIL_LABELS: Record<RailStep, string> = { connect: "Connect", ...STEP_LABELS };

/* iris step vocabulary, so the getting-started funnel joins across the
   iris → console migration. */
const IRIS_STEP_NAMES: Record<Step, string> = {
  group: "select-group",
  repo: "select-repo",
  fork: "fork",
  token: "submit-token",
  webhook: "configure-webhook",
  variables: "configure-variables",
  pipeline: "add-pipeline",
  credentials: "credentials",
  wait: "merge-request",
  change: "make-changes",
  done: "success",
};

const GITLAB_DEMO_PROJECT =
  DEMO_REPOSITORIES.gitlab.slug.split("/").at(-1) ?? DEMO_REPOSITORY_SEARCH_VALUE;

export function ConnectGitlab({
  onBack,
  initialDemo = false,
}: {
  onBack: () => void;
  initialDemo?: boolean;
}) {
  const { currentTenant } = useTenant();
  const { user } = useAuth();
  const router = useDeepLinkRouter();
  const { refresh: refreshSetupProgress } = useSetupProgress();
  const [step, setStep] = useState<Step>("group");
  const [gitlabUrl, setGitlabUrl] = useState("https://gitlab.com");
  const [groupId, setGroupId] = useState("");
  const [groupName, setGroupName] = useState("");
  const [project, setProject] = useState(initialDemo ? GITLAB_DEMO_PROJECT : "");
  const [demoSelected, setDemoSelected] = useState(initialDemo);
  const [forkPath, setForkPath] = useState("");
  const [forkError, setForkError] = useState<string | null>(null);
  const [token, setToken] = useState("");
  const [webhookSecret, setWebhookSecret] = useState("");
  const [secretAcked, setSecretAcked] = useState(false);
  // The group actually provisioned: the verify poll must query THIS, not the
  // editable field (which the user could change after provisioning).
  const [provisionedId, setProvisionedId] = useState<string>("");
  const [installState, setInstallState] = useState<string | null>(null);
  // The installation state rotation found. Only a "pending" one can still be
  // verified: a delivery carrying the new secret is what moves it to
  // installed, and an installed one never moves again.
  const [rotatedFrom, setRotatedFrom] = useState<string | null>(null);
  const rotationUnverifiable = rotatedFrom === "installed";
  // Resumed an already-connected group: nothing was provisioned, rotated or verified here.
  const [resumed, setResumed] = useState(false);
  const webhookUnverifiable = rotationUnverifiable || resumed;
  const [verifyError, setVerifyError] = useState<string | null>(null);
  // The status check is a separate round trip against the orchestration
  // tables; when they are absent it gets the same notice every other
  // orchestration screen shows, not a raw MQL error.
  const [unavailable, setUnavailable] = useState(false);
  const [copiedYaml, setCopiedYaml] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [conflict, setConflict] = useState(false);
  const projectInputRef = useRef<HTMLInputElement>(null);

  const steps = demoSelected ? DEMO_STEPS : OWN_STEPS;
  const webhookUrl = `${getApiBase()}/api/v1/gitlab/events`;
  const base = gitlabBaseUrl(gitlabUrl) ?? "https://gitlab.com";
  const gitlabDotCom = base.toLowerCase() === "https://gitlab.com";
  const { hooksUrl, cicdUrl, repoUrl, groupTokensUrl, projectTokensUrl, personalTokensUrl } =
    gitlabWizardLinks(base, groupName.trim(), project.trim());

  const advance = (from: Step, to: Step): void => {
    pushGettingStartedEvent("getting_started_step_completed", {
      path: "repo",
      vcs_provider: "gitlab",
      step: IRIS_STEP_NAMES[from],
      step_index: steps.indexOf(from) + 1,
    });
    if (to === "done") {
      pushGettingStartedEvent("getting_started_completed", { path: "gitlab" });
    }
    setError(null);
    setStep(to);
  };

  const back = (to: Step): void => {
    setError(null);
    // The offer to rotate belongs to the group that answered 409, and going
    // back is how the group id gets edited.
    setConflict(false);
    if (to === "group" || to === "repo" || to === "fork" || to === "token") setResumed(false);
    setStep(to);
  };

  // Once provisioned, and until the operator says the secret is saved, leaving
  // the wizard loses it for good: the server returns it once, and getting
  // another means rotating the credentials, which invalidates this one. The
  // in-component exit is closed and a reload/close asks for confirmation; App
  // Router navigation (sidebar, breadcrumb) cannot be intercepted.
  const secretAtRisk = webhookSecret !== "" && !secretAcked;
  useEffect(() => {
    if (!secretAtRisk) return;
    const onBeforeUnload = (e: BeforeUnloadEvent) => {
      e.preventDefault();
    };
    window.addEventListener("beforeunload", onBeforeUnload);
    return () => window.removeEventListener("beforeunload", onBeforeUnload);
  }, [secretAtRisk]);

  const handleCreate = async (): Promise<void> => {
    setError(null);
    setConflict(false);
    if (!currentTenant) {
      setError("Select a tenant first.");
      return;
    }
    setLoading(true);
    try {
      // The webhook secret is generated server-side and returned exactly once.
      const res = await provisionGitlab(currentTenant.id, {
        group_id: Number(groupId.trim()),
        name: groupName.trim(),
        access_token: token.trim(),
      });
      setWebhookSecret(res.webhook_secret);
      refreshSetupProgress();
      setProvisionedId(String(res.group_id));
      setInstallState(res.state);
      setSecretAcked(false);
      // The access token has done its one job; do not keep an api-scoped
      // GitLab credential in the React tree for the rest of the wizard.
      setToken("");
      // The event name is the whole funnel signal; a customer's group id is
      // an identifier and must not reach the tag manager's data layer.
      pushGettingStartedEvent("getting_started_gitlab_group_selected", { path: "gitlab" });
      advance("token", "webhook");
    } catch (e) {
      // 409 is the already-provisioned answer: offer same-tenant rotation or,
      // for the example fork, another group, since this console cannot read the
      // existing installation's webhook secret back.
      const alreadyProvisioned = (e as { status?: number } | null)?.status === 409;
      if (alreadyProvisioned) setConflict(true);
      setError(
        alreadyProvisioned && demoSelected
          ? `${COPY.repo.demo.gitlabExistingGroup} ${COPY.repo.demo.gitlabChooseGroup}`
          : gitlabProvisionErrorMessage(e, "Failed to create the installation."),
      );
    } finally {
      setLoading(false);
    }
  };

  const handleRotate = async (): Promise<void> => {
    setError(null);
    if (!currentTenant) {
      setError("Select a tenant first.");
      return;
    }
    setLoading(true);
    try {
      // Same-tenant recovery for an already-provisioned group: optionally
      // store the newly entered token, always mint a fresh webhook secret so
      // the flow continues exactly like a fresh provision.
      const res = await rotateGitlab(currentTenant.id, Number(groupId.trim()), {
        ...(token.trim() ? { access_token: token.trim() } : {}),
        regenerate_webhook_secret: true,
      });
      setWebhookSecret(res.webhook_secret ?? "");
      refreshSetupProgress();
      setProvisionedId(String(res.group_id));
      setRotatedFrom(res.state);
      setInstallState(res.state === "installed" ? null : res.state);
      setSecretAcked(false);
      // The access token has done its one job, as in handleCreate.
      setToken("");
      setConflict(false);
      advance("token", "webhook");
    } catch (e) {
      setError(gitlabRotateErrorMessage(e, "Rotation failed."));
    } finally {
      setLoading(false);
    }
  };

  // Already connected and working: skip the credential steps and resume at the
  // remaining self-attested setup (CI/CD role, pipeline) -- but only for a
  // group linked to this tenant whose installation has received a delivery.
  const handleResume = async (): Promise<void> => {
    setError(null);
    if (!currentTenant) {
      setError("Select a tenant first.");
      return;
    }
    setLoading(true);
    try {
      const [list, probe] = await Promise.all([
        listVcsInstallations(currentTenant.id),
        executeMQL(gitlabInstallationLinkQuery(groupId)),
      ]);
      const outcome = gitlabResumeOutcome(
        list.results.filter((i) => i.provider === "gitlab").map((i) => i.installation_core_id),
        probe.data,
      );
      if (outcome === "not-linked") {
        // Rotation would 404 as well, so neither offer applies.
        setConflict(false);
        setError(
          "This GitLab group's installation is not linked to this tenant, so there is no setup here to continue or rotate. Linking it to this tenant needs an instance admin.",
        );
        return;
      }
      if (outcome === "pending") {
        setError(
          "This GitLab group's installation has not received a webhook delivery yet, so there is nothing working to continue from. Rotate its credentials to get a webhook secret you can see.",
        );
        return;
      }
      setProvisionedId(groupId.trim());
      setInstallState(null);
      // Resuming sends no token; do not keep it in the tree, as in handleCreate.
      setToken("");
      setResumed(true);
      setConflict(false);
      for (const resumedStep of ["token", "webhook"] as const)
        pushGettingStartedEvent("getting_started_step_completed", {
          path: "repo",
          vcs_provider: "gitlab",
          step: IRIS_STEP_NAMES[resumedStep],
          step_index: steps.indexOf(resumedStep) + 1,
          resumed: true,
        });
      setStep("variables");
    } catch (e) {
      if (orchestrationUnavailable(e)) setUnavailable(true);
      else
        setError(
          `Could not check whether this group is connected: ${e instanceof Error ? e.message : "request failed"}.`,
        );
    } finally {
      setLoading(false);
    }
  };

  const handleVerify = async (): Promise<void> => {
    setVerifyError(null);
    setLoading(true);
    try {
      const res = await executeMQL(gitlabInstallationStateQuery(provisionedId));
      const row = res.data[0] as { state?: unknown } | undefined;
      const st = asText(row?.state) || "not found";
      setInstallState(st);
      if (st === "installed") {
        advance("webhook", "variables");
      } else {
        setVerifyError("Webhook is not active yet. Please test it with a Push Event in GitLab.");
      }
    } catch (e) {
      if (orchestrationUnavailable(e)) setUnavailable(true);
      else
        setVerifyError(
          `Could not check the webhook status: ${e instanceof Error ? e.message : "request failed"}. Try again, or skip verification.`,
        );
    } finally {
      setLoading(false);
    }
  };

  // Every copy control surfaces a failed copy; the secret's also ticks the gate.
  const copyField = async (value: string, what: string): Promise<boolean> => {
    setError(null);
    const ok = await copyText(value);
    if (!ok) setError(`Could not copy automatically. Select ${what} and copy it manually.`);
    return ok;
  };

  const copySecret = async () => {
    // A failed copy leaves the acknowledgement checkbox below as the manual
    // way through the gate, so the step is never a dead end.
    if (await copyField(webhookSecret, "the secret token below")) setSecretAcked(true);
  };

  const copyYaml = async () => {
    if (await copyField(GITLAB_PIPELINE_YAML, "the YAML")) {
      setCopiedYaml(true);
      window.setTimeout(() => setCopiedYaml(false), 2000);
    }
  };

  const chooseOwn = (): void => {
    setDemoSelected(false);
    setConflict(false);
    advance("repo", "token");
  };

  const chooseDemo = (): void => {
    setDemoSelected(true);
    setProject(GITLAB_DEMO_PROJECT);
    setForkPath(`${groupName.trim()}/${GITLAB_DEMO_PROJECT}`);
    setForkError(null);
    setConflict(false);
    setError(null);
    advance("repo", "fork");
  };

  const confirmFork = (): void => {
    const normalized = forkPath.trim().replace(/^\/+|\/+$/g, "");
    if (
      !isRepositorySlug(normalized) ||
      normalized.toLowerCase() === DEMO_REPOSITORIES.gitlab.slug
    ) {
      setForkError(COPY.fork.pathInvalid);
      return;
    }
    const prefix = `${groupName.trim()}/`;
    setProject(
      normalized.startsWith(prefix)
        ? normalized.slice(prefix.length)
        : normalized.split("/").slice(1).join("/"),
    );
    setForkError(null);
    advance("fork", "token");
  };

  if (unavailable) return <OrchestrationUnavailable />;

  // The provisioning endpoint gates on Caps.admin_tenant. Say so before the
  // operator mints a group access token and pastes it in, not after.
  if (!isTenantAdmin(user?.capabilities, currentTenant?.id)) {
    return (
      <div className="space-y-6">
        <button onClick={onBack} className="text-sm text-[var(--sg-text-muted)] hover:text-[var(--sg-text)]">
          ← Back
        </button>
        <Card>
          <CardHeader>
            <CardTitle>Tenant admin required</CardTitle>
            <CardDescription>
              Connecting a GitLab group requires admin on this tenant. Ask a tenant admin to run this
              step.
            </CardDescription>
          </CardHeader>
        </Card>
      </div>
    );
  }

  const railSteps: readonly RailStep[] = ["connect", ...steps];

  return (
    <WizardShell steps={railSteps} labels={RAIL_LABELS} currentStep={step} onReset={onBack}>
      {secretAtRisk ? (
        <div className="text-sm text-[var(--sg-text-dim)]">
          Save the webhook secret below before you leave this step.
        </div>
      ) : null}

      {error ? (
        <div className="p-3 rounded-lg bg-[var(--sg-error)]/10 border border-[var(--sg-error)]/30">
          <div className="text-sm text-[var(--sg-error)]">{error}</div>
        </div>
      ) : null}

      {step === "group" ? (
        <Card>
          <CardHeader>
            <CardTitle className="text-2xl font-semibold tracking-tight sm:text-3xl lg:text-4xl"><h2>Select your GitLab group</h2></CardTitle>
            <CardDescription className="mt-3 max-w-prose text-base lg:text-lg">
              Stategraph connects to one GitLab group. Every link in the next steps is built from
              it. Personal namespaces are not supported.
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-1.5">
              <div className="text-sm text-[var(--sg-text)]">GitLab URL</div>
              <Input
                value={gitlabUrl}
                onChange={(e) => {
                  const nextUrl = e.target.value;
                  setGitlabUrl(nextUrl);
                  if (gitlabBaseUrl(nextUrl)?.toLowerCase() !== "https://gitlab.com") {
                    setDemoSelected(false);
                  }
                }}
                placeholder="https://gitlab.com"
              />
              <p className="text-xs text-[var(--sg-text-muted)]">
                Change this only for self-managed GitLab.
              </p>
            </div>
            <div className="space-y-1.5">
              <div className="text-sm text-[var(--sg-text)]">Group ID</div>
              <Input
                value={groupId}
                onChange={(e) => {
                  setError(null);
                  setConflict(false);
                  setGroupId(e.target.value);
                }}
                placeholder="e.g. 1043"
              />
              <p className="text-xs text-[var(--sg-text-muted)]">
                The numeric ID shown under the group name on your group&apos;s GitLab page, or in
                the group&apos;s three-dot menu under Copy group ID. It is not verified, so check
                it: a typo provisions an installation that never receives webhooks.
              </p>
            </div>
            <div className="space-y-1.5">
              <div className="text-sm text-[var(--sg-text)]">Group name</div>
              <Input
                value={groupName}
                onChange={(e) => {
                  setConflict(false);
                  setError(null);
                  setGroupName(e.target.value);
                }}
                placeholder="e.g. acme"
              />
              <p className="text-xs text-[var(--sg-text-muted)]">
                The group path exactly as it appears in URLs.
              </p>
            </div>
            <div className="flex justify-between pt-2">
              <Button variant="outline" onClick={onBack}>
                <ArrowLeft className="h-4 w-4 mr-1" />
                Back
              </Button>
              <Button
                onClick={() => {
                  setError(null);
                  if (!gitlabBaseUrl(gitlabUrl)) {
                    setError("GitLab URL must be a full http(s) URL, e.g. https://gitlab.com");
                    return;
                  }
                  if (!isValidGroupId(groupId)) {
                    setError("Group ID must be the numeric GitLab group ID.");
                    return;
                  }
                  if (!groupName.trim()) {
                    setError("Group name is required.");
                    return;
                  }
                  advance("group", "repo");
                }}
              >
                Continue with {groupName.trim() || "this group"}
                <ArrowRight className="h-4 w-4 ml-1" />
              </Button>
            </div>
          </CardContent>
        </Card>
      ) : null}

      {step === "repo" ? (
        <div className="space-y-4">
          <div>
            <h2 className="text-2xl font-semibold tracking-tight sm:text-3xl lg:text-4xl text-[var(--sg-text)]">Select repository</h2>
            <p className="mt-3 max-w-prose text-base lg:text-lg text-[var(--sg-text-muted)]">
              Choose the project where you want to enable Stategraph automation.
            </p>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <Card className="h-full gap-4 border-2">
              <CardHeader>
                <CardTitle>{COPY.repo.own.title}</CardTitle>
              </CardHeader>
              <CardContent className="flex flex-1 flex-col gap-3">
                <div className="space-y-1.5">
                  <label htmlFor="gitlab-project" className="text-sm text-[var(--sg-text)]">
                    Enter your repository name
                  </label>
                  <div className="flex items-center gap-0">
                    <span className="px-3 py-2 rounded-l-md border border-r-0 border-[var(--sg-border)] bg-[var(--sg-bg-2)] text-sm text-[var(--sg-text-muted)]">
                      {groupName}/
                    </span>
                    <Input
                      ref={projectInputRef}
                      id="gitlab-project"
                      className="rounded-l-none"
                      value={demoSelected ? "" : project}
                      onChange={(e) => {
                        setDemoSelected(false);
                        setProject(e.target.value);
                      }}
                      onKeyDown={(e) => {
                        if (e.key === "Enter" && project.trim() && !demoSelected) chooseOwn();
                      }}
                      placeholder="my-terraform-repo"
                    />
                  </div>
                  <p className="text-xs text-[var(--sg-text-muted)]">
                    Used to build the exact GitLab links in the next steps: webhooks, CI/CD
                    settings and the pipeline file all live on this project.
                  </p>
                </div>
                <Button
                  className="mt-auto self-start"
                  onClick={chooseOwn}
                  disabled={demoSelected || !project.trim()}
                >
                  {COPY.common.continue}
                  <ArrowRight className="h-4 w-4 ml-1" />
                </Button>
              </CardContent>
            </Card>
            {gitlabDotCom ? (
              <Card className="h-full gap-4 border-2">
                <CardHeader>
                  <CardTitle>{COPY.repo.demo.title.gitlab}</CardTitle>
                  <CardDescription>{COPY.repo.demo.body.gitlab}</CardDescription>
                </CardHeader>
                <CardContent className="mt-auto">
                  <Button onClick={chooseDemo}>
                    {COPY.repo.demo.action.gitlab}
                    <ArrowRight className="h-4 w-4 ml-1" />
                  </Button>
                </CardContent>
              </Card>
            ) : null}
          </div>
          <div>
            <Button variant="outline" onClick={() => back("group")}>
              <ArrowLeft className="h-4 w-4 mr-1" />
              Back
            </Button>
          </div>
        </div>
      ) : null}

      {step === "fork" ? (
        <ForkStep
          provider="gitlab"
          path={{
            value: forkPath,
            onChange: (value) => {
              setForkError(null);
              setForkPath(value);
            },
            error: forkError,
          }}
          onBack={() => back("repo")}
          onConfirm={confirmFork}
        />
      ) : null}

      {step === "token" ? (
        <Card>
          <CardHeader>
            <CardTitle className="text-2xl font-semibold tracking-tight sm:text-3xl lg:text-4xl"><h2>Submit a GitLab access token</h2></CardTitle>
            <CardDescription className="mt-3 max-w-prose text-base lg:text-lg">
              Stategraph uses this token to call the GitLab API on behalf of your group. Choose the
              most narrowly scoped token that fits your setup.
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <TokenChoice
              title="Group access token"
              suffix="(recommended)"
              badge="GitLab Premium or Ultimate"
              body="Scoped to this group only and not tied to a person. Available on any tier for self-managed GitLab."
              link={groupTokensUrl}
              linkLabel="Open group access tokens"
            />
            <TokenChoice
              title="Project access token"
              badge="GitLab Premium or Ultimate"
              body="Scoped to a single project. Use only if you are connecting one repository. Available on any tier for self-managed GitLab."
              link={projectTokensUrl}
              linkLabel="Open project access tokens"
            />
            <TokenChoice
              title="Personal access token"
              suffix="(fallback)"
              body="Works on any plan, but tied to your user account. If you lose access to the group, Stategraph loses access too. Use the classic form so you can grant the api scope; fine-grained tokens have no equivalent yet."
              link={personalTokensUrl}
              linkLabel="Open personal access tokens"
            />
            <div className="border-t border-[var(--sg-border)] pt-3 text-xs text-[var(--sg-text-muted)]">
              Whichever you pick, the token needs the <strong>api</strong> scope. Group and project
              tokens also need at least the <strong>Developer</strong> role. Personal tokens have no
              role selector.
            </div>
            <div className="space-y-1.5">
              <label htmlFor="gitlab-access-token" className="text-sm text-[var(--sg-text)] block">
                Access token
              </label>
              <Input
                id="gitlab-access-token"
                type="password"
                value={token}
                onChange={(e) => setToken(e.target.value)}
                placeholder="Enter your GitLab access token"
                disabled={loading}
              />
              <p className="text-xs text-[var(--sg-text-muted)]">
                Stored write-only on the installation and never displayed again. To replace it
                later, rotate the credentials in Settings → Integrations.
              </p>
            </div>
            <div className="flex justify-between pt-2 flex-wrap gap-2">
              <Button variant="outline" onClick={() => back(demoSelected ? "fork" : "repo")}>
                <ArrowLeft className="h-4 w-4 mr-1" />
                Back
              </Button>
              <div className="flex gap-2 flex-wrap">
                {conflict && demoSelected ? (
                  <Button
                    variant="outline"
                    onClick={() => back("group")}
                    disabled={loading}
                  >
                    {COPY.repo.demo.gitlabChooseGroupAction}
                  </Button>
                ) : conflict ? (
                  <>
                    <Button
                      variant="outline"
                      onClick={() => void handleResume()}
                      disabled={loading}
                    >
                      Already connected, continue setup
                    </Button>
                    <Button variant="outline" onClick={() => void handleRotate()} disabled={loading}>
                      {loading ? <Loader2 className="h-4 w-4 mr-1 animate-spin" /> : null}
                      Rotate credentials and continue
                    </Button>
                  </>
                ) : null}
                <Button
                  onClick={() => void handleCreate()}
                  disabled={
                    loading || !token.trim() || (conflict && demoSelected)
                  }
                >
                  {loading ? <Loader2 className="h-4 w-4 mr-1 animate-spin" /> : null}
                  {loading ? "Submitting..." : "Submit token"}
                </Button>
              </div>
            </div>
          </CardContent>
        </Card>
      ) : null}

      {step === "webhook" ? (
        <Card>
          <CardHeader>
            <CardTitle className="text-2xl font-semibold tracking-tight sm:text-3xl lg:text-4xl"><h2>Configure the webhook</h2></CardTitle>
            <CardDescription className="mt-3 max-w-prose text-base lg:text-lg">
              Add a webhook to your {demoSelected ? "forked " : ""}project so Stategraph can respond
              to merge requests and code changes.
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="text-sm font-medium text-[var(--sg-text)]">Instructions:</div>
            <ol className="list-decimal pl-5 space-y-2 text-sm text-[var(--sg-text)]">
              <li>
                <a
                  href={hooksUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-[var(--sg-accent)] hover:underline inline-flex items-center gap-1"
                >
                  Open your project webhooks <ExternalLink className="h-3 w-3" />
                </a>
              </li>
              <li>
                Click <strong>Add new webhook</strong>
              </li>
              <li>
                <strong>URL:</strong>{" "}
                <code className="text-xs bg-[var(--sg-bg-2)] px-1.5 py-0.5 rounded break-all">{webhookUrl}</code>
                <Button
                  variant="outline"
                  size="icon-sm"
                  className="ml-2 align-middle"
                  onClick={() => void copyField(webhookUrl, "the URL")}
                  aria-label="Copy webhook URL"
                >
                  <Copy className="h-3 w-3" />
                </Button>
              </li>
              <li>
                <strong>Secret token:</strong>{" "}
                <code className="text-xs bg-[var(--sg-bg-2)] px-1.5 py-0.5 rounded break-all font-mono">
                  {webhookSecret}
                </code>
                <Button
                  variant="outline"
                  size="icon-sm"
                  className="ml-2 align-middle"
                  onClick={() => void copySecret()}
                  aria-label="Copy secret token"
                >
                  <Copy className="h-3 w-3" />
                </Button>
              </li>
              <li>
                Enable these triggers:
                <ul className="list-disc pl-5 mt-1 space-y-0.5 text-[var(--sg-text-muted)]">
                  <li>Push events</li>
                  <li>Comments</li>
                  <li>Merge request events</li>
                  <li>Job events</li>
                </ul>
              </li>
              <li>
                Click <strong>Add webhook</strong>
              </li>
              <li>
                Find the new webhook in the list and click <strong>Test → Push events</strong> to
                activate it
              </li>
              <li>
                Click <strong>Verify webhook</strong> below
              </li>
            </ol>
            <div className="rounded-md bg-[var(--sg-warning)]/10 border border-[var(--sg-warning)]/30 px-3 py-2 text-xs text-[var(--sg-warning)]">
              This secret is shown once. Copy it into GitLab now. Stategraph will not display it
              again. If it is lost, rotating the credentials in Settings → Integrations issues a new
              one and this one stops working.
            </div>
            {verifyError ? (
              <div className="p-3 rounded-lg bg-[var(--sg-error)]/10 border border-[var(--sg-error)]/30">
                <div className="text-sm text-[var(--sg-error)]">{verifyError}</div>
              </div>
            ) : null}
            {installState && installState !== "installed" ? (
              <div className="text-xs text-[var(--sg-text-muted)]">
                Current status: <span className="font-medium">{installState}</span>
              </div>
            ) : null}
            {/* EVERY way forward (Verify, Skip, Back) is gated on
                acknowledging the secret: the server returns it exactly once
                (iris could re-fetch its secret; here a lost one can only be
                replaced by rotation, which invalidates it), so it
                is gone once this component unmounts. Stepping back from the
                CI/CD role step re-shows it from memory. The checkbox is also
                the manual way through when the clipboard copy fails. */}
            <label className="flex items-start gap-2 text-sm text-[var(--sg-text)] cursor-pointer">
              <input
                type="checkbox"
                className="mt-0.5"
                checked={secretAcked}
                onChange={(e) => setSecretAcked(e.target.checked)}
              />
              I saved the secret token into GitLab (or somewhere safe)
            </label>
            {rotationUnverifiable ? (
              <>
                <p className="text-xs text-[var(--sg-text-muted)]">
                  This installation was already active, so its status does not change when GitLab
                  starts sending the new secret. On the webhook in GitLab, Test → Push events answers
                  HTTP 200 once it has the new secret and HTTP 500 while it still sends the old one.
                </p>
                <div className="flex justify-end pt-2">
                  <Button disabled={!secretAcked} onClick={() => advance("webhook", "variables")}>
                    Continue
                    <ArrowRight className="h-4 w-4 ml-1" />
                  </Button>
                </div>
              </>
            ) : (
              <div className="flex justify-between pt-2 flex-wrap gap-2">
                <Button
                  variant="outline"
                  disabled={!secretAcked}
                  onClick={() => {
                    setVerifyError(null);
                    advance("webhook", "variables");
                  }}
                >
                  Skip verification
                </Button>
                <Button onClick={() => void handleVerify()} disabled={loading || !secretAcked}>
                  {loading ? <Loader2 className="h-4 w-4 mr-1 animate-spin" /> : <Check className="h-4 w-4 mr-1" />}
                  {loading ? "Checking..." : "Verify webhook"}
                </Button>
              </div>
            )}
          </CardContent>
        </Card>
      ) : null}

      {step === "variables" ? (
        <Card>
          <CardHeader>
            <CardTitle className="text-2xl font-semibold tracking-tight sm:text-3xl lg:text-4xl"><h2>Configure CI/CD variables</h2></CardTitle>
            <CardDescription className="mt-3 max-w-prose text-base lg:text-lg">
              Configure project settings to allow Stategraph to pass credentials securely to your
              Terraform runs.
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <ol className="list-decimal pl-5 space-y-2 text-sm text-[var(--sg-text)]">
              <li>
                Go to your GitLab project CI/CD settings
                <div className="text-xs mt-0.5">
                  <a
                    href={cicdUrl}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="text-[var(--sg-accent)] hover:underline inline-flex items-center gap-1"
                  >
                    Project → Settings → CI/CD <ExternalLink className="h-3 w-3" />
                  </a>
                </div>
              </li>
              <li>
                Expand the <strong>Variables</strong> section
              </li>
              <li>Find <strong>Minimum role to use pipeline variables</strong></li>
              <li>
                Select <strong>Developer</strong> from the dropdown
                <div className="text-xs text-[var(--sg-text-muted)] mt-0.5">
                  This allows Stategraph to use pipeline variables
                </div>
              </li>
              <li>
                Click <strong>Save changes</strong>
              </li>
            </ol>
            <div className="rounded-md bg-[var(--sg-warning)]/10 border border-[var(--sg-warning)]/30 px-3 py-2 text-xs text-[var(--sg-warning)]">
              <strong>Important:</strong> This allows Stategraph to run pipelines with variables
              containing your cloud credentials and Terraform configuration.
            </div>
            <div className="flex justify-between pt-2">
              <Button variant="outline" onClick={() => back(resumed ? "token" : "webhook")}>
                <ArrowLeft className="h-4 w-4 mr-1" />
                Back
              </Button>
              <Button onClick={() => advance("variables", demoSelected ? "change" : "pipeline")}>
                CI/CD configured
                <ArrowRight className="h-4 w-4 ml-1" />
              </Button>
            </div>
          </CardContent>
        </Card>
      ) : null}

      {step === "pipeline" ? (
        <Card>
          <CardHeader>
            <CardTitle className="text-2xl font-semibold tracking-tight sm:text-3xl lg:text-4xl"><h2>Add the .gitlab-ci.yml file</h2></CardTitle>
            <CardDescription className="mt-3 max-w-prose text-base lg:text-lg">
              Add the Stategraph CI/CD template to your repository to enable Terraform automation.
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <ol className="list-decimal pl-5 space-y-2 text-sm text-[var(--sg-text)]">
              <li>
                Create or edit <code className="text-xs bg-[var(--sg-bg-2)] px-1.5 py-0.5 rounded">.gitlab-ci.yml</code>{" "}
                in{" "}
                <a
                  href={repoUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-[var(--sg-accent)] hover:underline inline-flex items-center gap-1"
                >
                  your repository root <ExternalLink className="h-3 w-3" />
                </a>
              </li>
              <li>Add this content:</li>
            </ol>
            <div className="relative">
              <pre className="text-xs font-mono bg-[var(--sg-bg-2)] border border-[var(--sg-border)] rounded-md p-3 overflow-x-auto max-h-96 text-[var(--sg-text)]">
                {GITLAB_PIPELINE_YAML}
              </pre>
              <Button
                variant="outline"
                size="sm"
                className="absolute top-2 right-2"
                onClick={() => void copyYaml()}
              >
                {copiedYaml ? <Check className="h-3.5 w-3.5 mr-1" /> : <Copy className="h-3.5 w-3.5 mr-1" />}
                {copiedYaml ? "Copied" : "Copy"}
              </Button>
            </div>
            <ol className="list-decimal pl-5 text-sm text-[var(--sg-text)]" start={3}>
              <li>Commit and push to your default branch</li>
            </ol>
            <div className="rounded-md bg-[var(--sg-accent-bg)] border border-[var(--sg-accent)]/30 px-3 py-2 text-xs text-[var(--sg-text)]">
              <strong>Note:</strong> If you already have a .gitlab-ci.yml file, integrate these
              rules with your existing jobs. Contact support for help with complex setups.
            </div>
            <div className="rounded-md bg-[var(--sg-bg-2)] border border-[var(--sg-border)] px-3 py-2 text-xs text-[var(--sg-text-muted)]">
              <strong>Self-managed GitLab:</strong> the include looks up{" "}
              <code>terrateam-io/terrateam-template</code> on your own instance. Mirror
              gitlab.com/terrateam-io/terrateam-template to that path first, or pipeline creation fails.
            </div>
            <div className="flex justify-between pt-2">
              <Button variant="outline" onClick={() => back("variables")}>
                <ArrowLeft className="h-4 w-4 mr-1" />
                Back
              </Button>
              <Button onClick={() => advance("pipeline", "credentials")}>
                Pipeline added
                <ArrowRight className="h-4 w-4 ml-1" />
              </Button>
            </div>
          </CardContent>
        </Card>
      ) : null}

      {step === "credentials" ? (
        <Card>
          <CardContent className="pt-6">
            <CredentialsStep
              provider="gitlab"
              onBack={() => back("pipeline")}
              onDone={() => advance("credentials", "wait")}
              onSkip={() => advance("credentials", "wait")}
            />
          </CardContent>
        </Card>
      ) : null}

      {step === "wait" ? (
        <Card>
          <CardContent className="pt-6">
            <PullRequestStep
              provider="gitlab"
              onBack={() => back("credentials")}
              onConfirm={() => advance("wait", "done")}
            />
          </CardContent>
        </Card>
      ) : null}

      {step === "change" ? (
        <Card>
          <CardContent className="pt-6">
            <FirstChangeStep
              provider="gitlab"
              editUrl={repoUrl ? `${repoUrl}/-/edit/main/${COPY.change.editPath}` : undefined}
              onBack={() => back("variables")}
              onConfirm={() => advance("change", "done")}
            />
          </CardContent>
        </Card>
      ) : null}

      {step === "done" ? (
        <Card>
          <CardContent className="pt-6">
            <DoneStep
              provider="gitlab"
              summary={
                <div className="space-y-2">
                  <div className="p-3 rounded-lg bg-[var(--sg-success)]/10 border border-[var(--sg-success)]/30 space-y-2">
                    <div className="text-sm font-medium text-[var(--sg-text)]">What you set up</div>
                    {[
                      resumed
                        ? `GitLab group ${groupName || "already"} connected to this tenant`
                        : rotatedFrom !== null
                          ? `GitLab group ${groupName} credentials rotated`
                          : `GitLab group ${groupName} connected`,
                      ...(resumed ? [] : ["Access token stored on the installation"]),
                      ...(installState === "installed" ? ["Webhook verified"] : []),
                      "CI/CD pipeline-variable role configured",
                      ...(demoSelected ? [] : ["GitLab CI pipeline added"]),
                    ].map((row) => (
                      <div key={row} className="text-sm text-[var(--sg-success)] flex items-center gap-2">
                        <Check className="h-4 w-4" />
                        {row}
                      </div>
                    ))}
                  </div>
                  {webhookUnverifiable ? (
                    <p className="text-xs text-[var(--sg-warning)]">
                      Webhook not verified: check in GitLab that Test → Push events on the webhook
                      answers HTTP 200.
                    </p>
                  ) : installState !== "installed" ? (
                    <p className="text-xs text-[var(--sg-warning)]">
                      Webhook not verified: the installation stays pending until GitLab delivers its
                      first event (Test → Push events).
                    </p>
                  ) : null}
                </div>
              }
              onSetUpState={() => router.push(STATE_SETUP_HREF)}
              onSwitchEngine={() => router.push(ENGINE_SETUP_HREF)}
              onConsole={() => router.push("/")}
              onManageUsers={() => router.push("/settings/users")}
            />
          </CardContent>
        </Card>
      ) : null}

      <div className="text-xs text-[var(--sg-text-muted)] text-center">
        Need help? Check the{" "}
        <a
          href="https://stategraph.com/docs"
          target="_blank"
          rel="noopener noreferrer"
          className="text-[var(--sg-accent)] hover:underline"
        >
          documentation
        </a>{" "}
        or get help on{" "}
        <a
          href="https://stategraph.com/slack"
          target="_blank"
          rel="noopener noreferrer"
          className="text-[var(--sg-accent)] hover:underline"
        >
          Slack
        </a>
        .
      </div>
    </WizardShell>
  );
}

function TokenChoice({
  title,
  suffix,
  badge,
  body,
  link,
  linkLabel,
}: {
  title: string;
  suffix?: string;
  badge?: string;
  body: string;
  link: string;
  linkLabel: string;
}) {
  return (
    <div className="rounded-md border border-[var(--sg-border)] bg-[var(--sg-bg-1)] px-3 py-2.5 space-y-1">
      <div className="flex items-center gap-2 flex-wrap">
        <span className="text-sm font-medium text-[var(--sg-text)]">{title}</span>
        {suffix ? <span className="text-xs text-[var(--sg-text-dim)]">{suffix}</span> : null}
        {badge ? (
          <span className="text-[10px] uppercase tracking-wide px-1.5 py-0.5 rounded border border-[var(--sg-accent)]/40 bg-[var(--sg-accent-bg)] text-[var(--sg-accent)]">
            {badge}
          </span>
        ) : null}
      </div>
      <p className="text-xs text-[var(--sg-text-muted)]">{body}</p>
      {link ? (
        <a
          href={link}
          target="_blank"
          rel="noopener noreferrer"
          className="text-xs text-[var(--sg-accent)] hover:underline inline-flex items-center gap-1"
        >
          {linkLabel} <ExternalLink className="h-3 w-3" />
        </a>
      ) : null}
    </div>
  );
}
