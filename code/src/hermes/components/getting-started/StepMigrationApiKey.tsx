"use client";

import { useState, useCallback } from "react";
import { type WizardActions } from "@/lib/getting-started";
import { useTenant } from "@/contexts";
import { useDeepLinkRouter } from "@/hooks";
import { createApiKey, createApiUser } from "@/lib/api/client";
import { Button } from "@/components/ui/button";
import { CodeBlock } from "./CodeBlock";
import {
  ArrowLeft,
  ArrowRight,
  Key,
  Bot,
  Copy,
  Check,
  ExternalLink,
} from "lucide-react";
import { track } from "@/lib/analytics";

type KeyMode = "personal" | "service-account";

interface StepMigrationApiKeyProps {
  actions: WizardActions;
  /** Where Back goes from the first step, or null for no Back at all. */
  backHref: string | null;
  backLabel: string;
}

export function StepMigrationApiKey({
  actions,
  backHref,
  backLabel,
}: StepMigrationApiKeyProps) {
  const router = useDeepLinkRouter();
  const { currentTenant } = useTenant();
  const [mode, setMode] = useState<KeyMode>("personal");

  // Personal API key state
  const [apiKey, setApiKey] = useState<string | null>(null);
  const [apiKeyLoading, setApiKeyLoading] = useState(false);
  const [apiKeyError, setApiKeyError] = useState<string | null>(null);
  const [apiKeyCopied, setApiKeyCopied] = useState(false);

  // Service account state
  const [serviceAccountName, setServiceAccountName] = useState("");
  const [serviceAccountToken, setServiceAccountToken] = useState<string | null>(
    null
  );
  const [serviceAccountLoading, setServiceAccountLoading] = useState(false);
  const [serviceAccountError, setServiceAccountError] = useState<string | null>(
    null
  );
  const [serviceAccountCopied, setServiceAccountCopied] = useState(false);

  const copyToClipboard = useCallback(
    async (text: string, setCopied: (v: boolean) => void) => {
      try {
        await navigator.clipboard.writeText(text);
        setCopied(true);
        setTimeout(() => setCopied(false), 2000);
      } catch {
        const textArea = document.createElement("textarea");
        textArea.value = text;
        document.body.appendChild(textArea);
        textArea.select();
        document.execCommand("copy");
        document.body.removeChild(textArea);
        setCopied(true);
        setTimeout(() => setCopied(false), 2000);
      }
    },
    []
  );

  const handleCreateApiKey = useCallback(async () => {
    setApiKeyLoading(true);
    setApiKeyError(null);
    setApiKey(null);
    setApiKeyCopied(false);

    try {
      const response = await createApiKey({ name: "UI-generated key" });
      track("api_key_created", { source: "migration_wizard" });
      setApiKey(response.token);
      actions.setApiKey(response.token);
    } catch (error) {
      setApiKeyError(
        error instanceof Error ? error.message : "Failed to create API key"
      );
    } finally {
      setApiKeyLoading(false);
    }
  }, [actions]);

  const handleCreateServiceAccount = useCallback(async () => {
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
      track("service_account_created", { source: "migration_wizard" });
      setServiceAccountToken(response.token);
      actions.setApiKey(response.token);
      setServiceAccountName("");
    } catch (error) {
      setServiceAccountError(
        error instanceof Error
          ? error.message
          : "Failed to create service account"
      );
    } finally {
      setServiceAccountLoading(false);
    }
  }, [serviceAccountName, currentTenant, actions]);

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-semibold tracking-tight sm:text-3xl lg:text-4xl text-[var(--sg-text)]">
          Create an API key
        </h2>
        <p className="mt-3 max-w-prose text-base lg:text-lg text-[var(--sg-text-muted)]">
          An API key authenticates the CLI and Terraform with Stategraph. Copy
          the token. You need it in the next step.
        </p>
        <a
          href="https://stategraph.com/docs/velocity/setup"
          target="_blank"
          rel="noopener noreferrer"
          className="inline-flex items-center gap-1 text-sm text-[var(--sg-accent)] hover:underline mt-2"
        >
          Stategraph setup docs
          <ExternalLink className="h-3 w-3" />
        </a>
      </div>

      {/* Mode selector */}
      <div className="flex flex-wrap gap-2">
        <button
          onClick={() => setMode("personal")}
          className={`flex items-center gap-2 px-3 py-1.5 text-xs rounded-md border transition-colors ${
            mode === "personal"
              ? "border-[var(--sg-accent)] bg-[var(--sg-accent-bg)] text-[var(--sg-accent)]"
              : "border-[var(--sg-border)] bg-[var(--sg-bg-2)] text-[var(--sg-text)] hover:border-[var(--sg-text-dim)]"
          }`}
        >
          <Key className="h-3.5 w-3.5" />
          Personal API Key
        </button>
        <button
          onClick={() => setMode("service-account")}
          className={`flex items-center gap-2 px-3 py-1.5 text-xs rounded-md border transition-colors ${
            mode === "service-account"
              ? "border-[var(--sg-accent)] bg-[var(--sg-accent-bg)] text-[var(--sg-accent)]"
              : "border-[var(--sg-border)] bg-[var(--sg-bg-2)] text-[var(--sg-text)] hover:border-[var(--sg-text-dim)]"
          }`}
        >
          <Bot className="h-3.5 w-3.5" />
          Service Account
        </button>
      </div>

      {/* Personal API Key */}
      {mode === "personal" && (
        <div className="space-y-4">
          <div className="text-xs text-[var(--sg-text-muted)]">
            Generate a key tied to your user account for CLI access.
          </div>

          {apiKeyError && (
            <div className="p-3 rounded-lg bg-[var(--sg-error)]/10 border border-[var(--sg-error)]/30">
              <div className="text-sm text-[var(--sg-error)]">
                {apiKeyError}
              </div>
            </div>
          )}

          {apiKey ? (
            <div className="space-y-3">
              <div className="p-3 rounded-lg bg-[var(--sg-success)]/10 border border-[var(--sg-success)]/30">
                <div className="text-sm text-[var(--sg-success)] mb-1">
                  API key created!
                </div>
                <div className="text-xs text-[var(--sg-text-muted)]">
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
                  onClick={() => copyToClipboard(apiKey, setApiKeyCopied)}
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
              <div className="text-sm text-[var(--sg-text-muted)]">
                Set it as an environment variable:
              </div>
              <CodeBlock code={`export STATEGRAPH_API_KEY="${apiKey}"`} />
            </div>
          ) : (
            <Button
              onClick={handleCreateApiKey}
              disabled={apiKeyLoading}
              className="gap-2"
            >
              <Key className="h-4 w-4" />
              {apiKeyLoading ? "Creating..." : "Create API Key"}
            </Button>
          )}
        </div>
      )}

      {/* Service Account */}
      {mode === "service-account" && (
        <div className="space-y-4">
          <div className="text-xs text-[var(--sg-text-muted)]">
            Create a dedicated API identity for CI/CD pipelines. Service
            accounts are separate identities that survive employee turnover.
          </div>

          {serviceAccountError && (
            <div className="p-3 rounded-lg bg-[var(--sg-error)]/10 border border-[var(--sg-error)]/30">
              <div className="text-sm text-[var(--sg-error)]">
                {serviceAccountError}
              </div>
            </div>
          )}

          {serviceAccountToken ? (
            <div className="space-y-3">
              <div className="p-3 rounded-lg bg-[var(--sg-success)]/10 border border-[var(--sg-success)]/30">
                <div className="text-sm text-[var(--sg-success)] mb-1">
                  Service account created!
                </div>
                <div className="text-xs text-[var(--sg-text-muted)]">
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
                  onClick={() =>
                    copyToClipboard(serviceAccountToken, setServiceAccountCopied)
                  }
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
              <div className="text-sm text-[var(--sg-text-muted)]">
                Set it as an environment variable:
              </div>
              <CodeBlock code={`export STATEGRAPH_API_KEY="${serviceAccountToken}"`} />
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
                  disabled={
                    serviceAccountLoading ||
                    !serviceAccountName.trim() ||
                    !currentTenant
                  }
                  className="gap-2 shrink-0"
                >
                  <Bot className="h-4 w-4" />
                  {serviceAccountLoading ? "Creating..." : "Create"}
                </Button>
              </div>
              {!currentTenant && (
                <div className="text-xs text-[var(--sg-warning)]">
                  No tenant selected. Select a tenant in Settings &gt; Workspace
                  first.
                </div>
              )}
              {currentTenant && (
                <div className="text-xs text-[var(--sg-text-dim)]">
                  Will be added to tenant:{" "}
                  <span className="text-[var(--sg-text-muted)]">
                    {currentTenant.name}
                  </span>
                </div>
              )}
            </div>
          )}
        </div>
      )}

      <div className="flex justify-between pt-2">
        {backHref ? (
          <Button variant="outline" {...router.nav(backHref)}>
            <ArrowLeft className="h-4 w-4 mr-1" />
            {backLabel}
          </Button>
        ) : (
          <span />
        )}
        <Button onClick={actions.nextStep}>
          Continue
          <ArrowRight className="h-4 w-4 ml-1" />
        </Button>
      </div>
    </div>
  );
}
