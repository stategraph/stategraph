"use client";

import { Suspense, useEffect, useState } from "react";
import { useSearchParams } from "next/navigation";
import { useDeepLinkRouter } from "@/hooks";
import { pushGettingStartedEvent, startSessionRecording } from "@/lib/analytics";
import { nextPathSelectionAttempt } from "@/lib/getting-started/path-attempts";
import type { VcsProvider } from "@/lib/vcs/links";
import { DEMO_REPOSITORY_SEARCH_VALUE } from "@/lib/getting-started/orchestration-state";
import {
  clearGithubInstallPending,
  githubInstallReturnHref,
  readGithubInstallPending,
} from "@/lib/getting-started/github-install-return";
import { SetupShell } from "@/components/getting-started";
import { ConnectGitlab } from "./ConnectGitlab";
import { ConnectGithub } from "./ConnectGithub";
import { OrchestrateFlow } from "./OrchestrateFlow";
import { useOrchestrationAvailability } from "./useOrchestrationAvailability";

/** The wizards this page renders behind `?path=`. Without one it is the orchestration flow. */
type Path = "github" | "gitlab" | "orchestrate";

function GettingStartedContent() {
  useEffect(() => {
    startSessionRecording();
  }, []);

  const router = useDeepLinkRouter();
  const searchParams = useSearchParams();
  const { availability, retry: retryAvailability } = useOrchestrationAvailability();
  const raw = searchParams.get("path");
  const path: Path = raw === "github" || raw === "gitlab" ? raw : "orchestrate";

  // A return from a GitHub install that reached this page without its wizard
  // path resumes the GitHub wizard instead of the path selector. Read once and
  // dropped when the wizard path lands, so a later Back to the selector stays there.
  const [installReturn, setInstallReturn] = useState(() =>
    raw === null
      ? githubInstallReturnHref({ search: searchParams, pending: readGithubInstallPending() })
      : null,
  );
  const resuming = installReturn !== null && raw === null;
  useEffect(() => {
    if (!resuming || installReturn === null) return;
    clearGithubInstallPending();
    router.replace(installReturn);
  }, [resuming, installReturn, router]);
  if (raw !== null && installReturn !== null) setInstallReturn(null);

  useEffect(() => {
    if (resuming) return;
    pushGettingStartedEvent("getting_started_viewed", { path });
  }, [path, resuming]);

  const backToSelector = (): void => {
    clearGithubInstallPending();
    router.push("/getting-started");
  };

  const connectProvider = (provider: VcsProvider): void => {
    pushGettingStartedEvent("getting_started_path_selected", {
      path: provider,
      attempt: nextPathSelectionAttempt(),
    });
    const params = new URLSearchParams({ path: provider });
    router.push(`/getting-started?${params.toString()}`);
  };

  const connected = (provider: VcsProvider): void => {
    const params = new URLSearchParams({
      path: "orchestrate",
      step: "repo",
      provider,
      repo: "",
    });
    router.push(`/getting-started?${params.toString()}`);
  };

  if (resuming) {
    return <div className="p-8 text-sm text-[var(--sg-text-muted)]">Loading…</div>;
  }

  if (path === "gitlab") {
    return (
      <SetupShell>
        <ConnectGitlab
          onBack={backToSelector}
          initialDemo={
            searchParams.get("demo") === DEMO_REPOSITORY_SEARCH_VALUE
          }
        />
      </SetupShell>
    );
  }

  if (path === "github") {
    return (
      <SetupShell>
        <ConnectGithub
          onBack={backToSelector}
          onRepositories={() => router.push("/repositories")}
          onConnected={connected}
        />
      </SetupShell>
    );
  }

  return (
    <SetupShell>
      <OrchestrateFlow
        availability={availability}
        onRetryAvailability={retryAvailability}
        onBack={backToSelector}
        onConnect={connectProvider}
      />
    </SetupShell>
  );
}

export default function GettingStartedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-sm text-[var(--sg-text-muted)]">Loading…</div>}>
      <GettingStartedContent />
    </Suspense>
  );
}
