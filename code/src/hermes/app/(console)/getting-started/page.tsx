"use client";

import { Suspense, useEffect } from "react";
import { useSearchParams } from "next/navigation";
import { useDeepLinkRouter } from "@/hooks";
import { pushGettingStartedEvent } from "@/lib/analytics";
import type { VcsProvider } from "@/lib/vcs/links";
import { DEMO_REPOSITORY_SEARCH_VALUE } from "@/lib/getting-started/orchestration-state";
import { SetupShell } from "@/components/getting-started";
import { ConnectGitlab } from "./ConnectGitlab";
import { ConnectGithub } from "./ConnectGithub";
import { OrchestrateFlow } from "./OrchestrateFlow";
import { useOrchestrationAvailability } from "./useOrchestrationAvailability";

/** The wizards this page renders behind `?path=`. Without one it is the orchestration flow. */
type Path = "github" | "gitlab" | "orchestrate";

function GettingStartedContent() {
  const router = useDeepLinkRouter();
  const searchParams = useSearchParams();
  const { availability, retry: retryAvailability } = useOrchestrationAvailability();
  const raw = searchParams.get("path");
  const path: Path = raw === "github" || raw === "gitlab" ? raw : "orchestrate";

  useEffect(() => {
    pushGettingStartedEvent("getting_started_viewed", { path });
  }, [path]);

  const connectProvider = (provider: VcsProvider): void => {
    pushGettingStartedEvent("getting_started_path_selected", { path: provider });
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

  if (path === "gitlab") {
    return (
      <SetupShell>
        <ConnectGitlab
          onBack={() => router.push("/getting-started")}
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
          onBack={() => router.push("/getting-started")}
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
        onBack={() => router.push("/getting-started")}
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
