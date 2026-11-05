"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { ArrowRight, Check, Loader2, Minus, ExternalLink, Trash2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Timestamp } from "@/components/ui/timestamp";
import {
  createDedicated,
  deleteDedicated,
  getDedicated,
  getDedicatedHandoff,
  type Dedicated,
} from "@/lib/api/client";
import {
  DEDICATED_SLUG_MAX,
  isValidDedicatedSlug,
} from "@/lib/utils/dedicated-slug";
import { useDedicatedAvailability } from "@/hooks";
import { track } from "@/lib/analytics";

/**
 * /provision — single page with two modes keyed off `?id=`.
 *
 *   form mode (no id): one input → POST /api/v1/dedicated-stategraphs →
 *                      router.replace(`/provision?id=…`).
 *   status mode (id):  poll GET /api/v1/dedicated-stategraphs/:id every
 *                      3s until terminal; Open → handoff → cross-origin
 *                      redirect to the new FQDN's /claim.
 */

// Happy-path progression. Aegis returns more statuses
// (suspended/pending_destroy/deleted) but those aren't reachable from
// the freshly-provisioned flow — we render them as a generic banner
// if they show up.
const PROGRESS_STEPS: Array<{ key: string; label: string }> = [
  { key: "pending", label: "Queued" },
  { key: "provisioning_project", label: "Allocating substrate project" },
  { key: "provisioning_database", label: "Provisioning database" },
  { key: "provisioning_secrets", label: "Wiring credentials" },
  { key: "provisioning_services", label: "Starting Stategraph service" },
  { key: "configuring_domain", label: "Configuring DNS + TLS certificate" },
  { key: "health_checking", label: "Verifying health" },
  { key: "active", label: "Ready" },
];

const TERMINAL_STATUSES = new Set([
  "active",
  "failed",
  "deleted",
  "pending_destroy",
  "suspended",
]);

const POLL_INTERVAL_MS = 3_000;

export function ProvisionClient() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const id = searchParams.get("id");
  const { capability: dedicatedCapability, isLoading: capabilityLoading } =
    useDedicatedAvailability();
  const dedicatedEnabled = dedicatedCapability?.enabled === true;

  // Dedicated provisioning can be disabled (STATEGRAPH_DEDICATED_ENABLED=off).
  // The page is unreachable from the UI in that case and the backend 404s, but
  // a direct/deep link would otherwise render a dead form — bounce home once
  // capabilities resolve.
  useEffect(() => {
    if (!capabilityLoading && !dedicatedEnabled) router.replace("/");
  }, [capabilityLoading, dedicatedEnabled, router]);

  if (capabilityLoading || !dedicatedEnabled) return null;

  if (id) return <StatusMode id={id} />;
  return <FormMode />;
}

// ---------------- Form mode ----------------

function FormMode() {
  const router = useRouter();
  const [name, setName] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const trimmed = name.trim();
  const valid = isValidDedicatedSlug(trimmed);
  const showValidationHint = trimmed.length > 0 && !valid;
  const previewFqdn = trimmed.length > 0 ? `${trimmed}.stategraph.cloud` : null;

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!valid || submitting) return;
    setSubmitting(true);
    setError(null);
    try {
      const resp = await createDedicated({ name: trimmed, slug: trimmed });
      track("dedicated_created", { dedicated_id: resp.id });
      router.replace(`/provision?id=${encodeURIComponent(resp.id)}`);
    } catch (e) {
      setError(translateCreateError(e));
      setSubmitting(false);
    }
  }

  return (
    <div className="min-h-screen flex items-start justify-center p-6 pt-16">
      <div className="w-full max-w-md">
        <h1 className="text-2xl font-semibold mb-2">Create Dedicated Stategraph</h1>
        <p className="text-[var(--sg-text-muted)] mb-6 text-sm">
          Provision a single-tenant Stategraph instance on its own subdomain.
          When it&apos;s ready we&apos;ll email you a magic link, and it&apos;ll
          show up in your sidebar.
        </p>

        <form onSubmit={onSubmit} className="space-y-4">
          <div>
            <label htmlFor="name" className="block text-sm font-medium mb-1">
              Name
            </label>
            <input
              id="name"
              type="text"
              autoFocus
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="foobar"
              maxLength={DEDICATED_SLUG_MAX}
              autoComplete="off"
              className="w-full px-3 py-2 rounded-lg bg-[var(--sg-bg-0)] border border-[var(--sg-border)] text-sm text-[var(--sg-text)] placeholder:text-[var(--sg-text-dim)] focus:outline-none focus:ring-2 focus:ring-[var(--sg-accent)]/50"
            />
            <div className="mt-1 text-xs text-[var(--sg-text-muted)]">
              1–{DEDICATED_SLUG_MAX} lowercase letters, digits, dashes. Must start with a
              letter.
            </div>
            {showValidationHint && (
              <div className="mt-1 text-xs text-[var(--sg-error)]">
                That doesn&apos;t match the format above.
              </div>
            )}
            {previewFqdn && valid && (
              <div className="mt-2 text-xs text-[var(--sg-text-muted)]">
                Your URL will be{" "}
                <span className="font-mono text-[var(--sg-text)]">{previewFqdn}</span>
              </div>
            )}
          </div>

          {error && (
            <div className="p-3 rounded-lg bg-[var(--sg-error)]/10 border border-[var(--sg-error)]/30">
              <div className="text-sm text-[var(--sg-error)]">{error}</div>
            </div>
          )}

          <Button
            type="submit"
            disabled={!valid || submitting}
            className="w-full h-11"
          >
            {submitting ? "Provisioning…" : "Provision"}
            {!submitting && <ArrowRight className="ml-2 h-4 w-4" />}
          </Button>
        </form>
      </div>
    </div>
  );
}

function translateCreateError(e: unknown): string {
  const err = e as Error & { status?: number; body?: unknown };
  const body = err.body as { error?: unknown; message?: string } | null;
  if (err.status === 403 && body?.error === "personal_email_blocked") {
    // Aegis rejects free-provider / disposable email addresses with a
    // human-readable message — forward it verbatim so the user knows
    // how to get unblocked (contact support).
    return (
      body.message ||
      "Dedicated Stategraph Cloud instances require a work email. Contact support@stategraph.com if you need an exception."
    );
  }
  if (err.status === 409) {
    // Aegis returns two 409 shapes: a plain collision, or a cooldown
    // window after a recent delete. The cooldown body carries its own
    // human message — forward it verbatim so the user sees how long
    // they have to wait.
    if (body?.error === "slug_in_cooldown" && body.message) return body.message;
    return "That name is already in use — pick another.";
  }
  if (err.status === 400)
    return "That name isn't allowed (it may be reserved or malformed). Pick another.";
  if (err.status === 412)
    return "Your account needs an email before provisioning. Add one in settings and try again.";
  if (err.status === 502)
    return "Provisioning service is temporarily unavailable. Try again in a moment.";
  if (err.status === 503)
    return "Provisioning isn't configured on this instance. Contact support.";
  return err.message || "Couldn't start provisioning. Try again.";
}

// ---------------- Status mode ----------------

function StatusMode({ id }: { id: string }) {
  const [data, setData] = useState<Dedicated | null>(null);
  const [loadErr, setLoadErr] = useState<string | null>(null);

  const status = data?.status;
  const isTerminal = status !== undefined && TERMINAL_STATUSES.has(status);

  useEffect(() => {
    // Single effect drives both the initial load and the polling
    // interval until the deployment reaches a terminal status. Skips
    // ticks while the tab is hidden so a backgrounded page doesn't
    // hammer Aegis.
    let cancelled = false;

    const tick = async () => {
      if (typeof document !== "undefined" && document.hidden) return;
      try {
        const next = await getDedicated(id);
        if (cancelled) return;
        setData(next);
        setLoadErr(null);
      } catch (e) {
        if (cancelled) return;
        const err = e as Error & { status?: number };
        setLoadErr(err.status === 404 ? "not_found" : "transient");
      }
    };

    void tick();
    const handle = setInterval(() => {
      if (isTerminal) return;
      void tick();
    }, POLL_INTERVAL_MS);
    return () => {
      cancelled = true;
      clearInterval(handle);
    };
  }, [id, isTerminal]);

  // Mirror deployment state into the tab title so users tabbed away
  // (a common case — provisioning takes 3-5 minutes) notice the change
  // from "Provisioning …" to "ready" or "failed" without bringing the
  // tab forward. Next.js owns the title on subsequent navigations.
  useEffect(() => {
    if (!data) return;
    if (status === "active" && data.fqdn) {
      document.title = `${data.fqdn} ready`;
    } else if (status === "failed") {
      document.title = data.name
        ? `Provisioning failed — ${data.name}`
        : "Provisioning failed";
    } else {
      const label = data.slug ? `${data.slug}.stategraph.cloud` : data.name;
      document.title = `Provisioning ${label}…`;
    }
  }, [data, status]);

  if (loadErr === "not_found") {
    return (
      <div className="min-h-screen flex items-center justify-center p-6">
        <div className="max-w-md text-center">
          <h1 className="text-2xl font-semibold mb-2">We couldn&apos;t find that deployment</h1>
          <p className="text-[var(--sg-text-muted)] mb-6">
            It may have been deleted, or you may not own it.
          </p>
          <Link href="/provision" className="text-[var(--sg-accent)] hover:underline">
            Start over
          </Link>
        </div>
      </div>
    );
  }

  if (data && status === "active" && data.fqdn) {
    return <ActiveScreen data={data} />;
  }

  if (data && status === "failed") {
    return <FailedScreen data={data} />;
  }

  return (
    <InFlightScreen
      data={data}
      status={status}
      isTerminal={isTerminal}
      loadErr={loadErr}
    />
  );
}

// ---------------- In-flight (provisioning) ----------------

function InFlightScreen({
  data,
  status,
  isTerminal,
  loadErr,
}: {
  data: Dedicated | null;
  status: string | undefined;
  isTerminal: boolean;
  loadErr: string | null;
}) {
  const router = useRouter();

  return (
    <div className="min-h-screen flex items-start justify-center p-6 pt-16">
      <div className="w-full max-w-lg">
        {data && (
          <div className="mb-6 flex items-center gap-2.5 p-3 rounded-lg bg-[var(--sg-success)]/10 border border-[var(--sg-success)]/30">
            <div className="h-6 w-6 rounded-full bg-[var(--sg-success)]/20 flex items-center justify-center flex-shrink-0">
              <Check
                className="h-3.5 w-3.5 text-[var(--sg-success)]"
                aria-hidden="true"
              />
            </div>
            <div className="text-sm min-w-0">
              <span className="font-medium text-[var(--sg-text)]">Created</span>
              {data.slug && (
                <span className="text-[var(--sg-text-muted)]">
                  {" — "}
                  <span className="font-mono text-[var(--sg-text)] break-all">
                    {data.slug}.stategraph.cloud
                  </span>
                </span>
              )}
            </div>
          </div>
        )}

        <h1 className="text-2xl font-semibold mb-2">
          {data?.name ? <>Provisioning {data.name}</> : <>Provisioning…</>}
        </h1>
        <p className="text-[var(--sg-text-muted)] mb-6 text-sm">
          This usually takes 3–5 minutes. You can close this tab — we&apos;ll email
          you a magic link when it&apos;s ready, and your deployment will also show
          up in your sidebar.
        </p>

        {loadErr === "transient" && !isTerminal && (
          <div className="mb-4 p-2 rounded-md bg-[var(--sg-warning)]/10 border border-[var(--sg-warning)]/30">
            <div className="text-xs text-[var(--sg-warning)]">
              Temporarily unable to refresh status — retrying.
            </div>
          </div>
        )}

        <ProgressList status={status} />

        {/* Unexpected non-terminal-yet status (e.g., suspended/pending_destroy
            for a brand-new row — shouldn't happen on a fresh provision but
            we surface it rather than infinite-spinning). */}
        {status &&
          !PROGRESS_STEPS.some((s) => s.key === status) &&
          status !== "failed" &&
          status !== "active" && (
            <div className="mt-6 p-3 rounded-lg bg-[var(--sg-bg-0)] border border-[var(--sg-border)]">
              <div className="text-sm text-[var(--sg-text)] mb-1">
                Status: <span className="font-mono">{status}</span>
              </div>
              <div className="text-xs text-[var(--sg-text-muted)]">
                This deployment isn&apos;t in the normal provisioning flow. Contact support
                if you didn&apos;t expect this.
              </div>
            </div>
          )}

        {data && (
          <div className="mt-10">
            <DangerZone
              id={data.id}
              name={data.name}
              slug={data.slug}
              onDestroyed={() => router.push("/provision")}
            />
          </div>
        )}
      </div>
    </div>
  );
}

// ---------------- Failed ----------------

function FailedScreen({ data }: { data: Dedicated }) {
  return (
    <div className="min-h-screen flex items-start justify-center p-6 pt-16">
      <div className="w-full max-w-lg">
        <h1 className="text-2xl font-semibold mb-2">Provisioning failed</h1>
        <p className="text-[var(--sg-text-muted)] mb-6 text-sm font-mono">
          {data.name}
        </p>
        <div className="mb-6 p-3 rounded-lg bg-[var(--sg-error)]/10 border border-[var(--sg-error)]/30">
          <div className="text-sm text-[var(--sg-error)] mb-1 font-medium">
            We couldn&apos;t finish provisioning your deployment.
          </div>
          <div className="text-xs text-[var(--sg-text-muted)]">
            {data.failure_reason ?? "An unknown error occurred."}
          </div>
          <div className="mt-3">
            <Link
              href="/provision"
              className="text-sm text-[var(--sg-accent)] hover:underline"
            >
              Start over
            </Link>
          </div>
        </div>
      </div>
    </div>
  );
}

// ---------------- Active (success) ----------------

function ActiveScreen({ data }: { data: Dedicated }) {
  const router = useRouter();
  const [opening, setOpening] = useState(false);
  const [openErr, setOpenErr] = useState<string | null>(null);

  // Open ⇒ Aegis handoff ⇒ cross-origin /claim?token=… on the new
  // instance, which sets a session cookie and redirects to the console.
  // We deliberately do NOT link straight to https://${fqdn} — that would
  // dump the user on the login page of an instance they've never signed
  // into.
  async function onOpen() {
    if (opening) return;
    setOpening(true);
    setOpenErr(null);
    try {
      const resp = await getDedicatedHandoff(data.id);
      window.location.href = resp.url;
    } catch {
      setOpening(false);
      setOpenErr("Couldn't mint a sign-in link. Try again in a moment.");
    }
  }

  return (
    <div className="min-h-screen flex items-start justify-center p-6 pt-16">
      <div className="w-full max-w-lg">
        <div className="flex items-center gap-2.5 mb-2">
          <div className="h-6 w-6 rounded-full bg-[var(--sg-success)]/15 flex items-center justify-center flex-shrink-0">
            <Check className="h-4 w-4 text-[var(--sg-success)]" aria-hidden="true" />
          </div>
          <h1 className="text-2xl font-semibold">{data.name} is ready</h1>
        </div>
        <p className="text-[var(--sg-text-muted)] mb-6 text-sm font-mono">
          {data.fqdn}
        </p>

        <div className="rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-0)] p-4 space-y-3 mb-6">
          <InfoRow label="URL">
            <span className="font-mono text-[var(--sg-text)]">{data.fqdn}</span>
          </InfoRow>
          {data.region && (
            <InfoRow label="Region">
              <span className="font-mono">{data.region}</span>
            </InfoRow>
          )}
          <InfoRow label="Status">
            <span className="inline-flex items-center gap-1.5 text-[var(--sg-success)] font-medium">
              <span className="h-1.5 w-1.5 rounded-full bg-[var(--sg-success)]" />
              Active
            </span>
          </InfoRow>
          <InfoRow label="Created">
            <Timestamp date={data.created_at} />
          </InfoRow>
        </div>

        <div className="space-y-2 mb-10">
          <button
            type="button"
            onClick={onOpen}
            disabled={opening}
            className="w-full inline-flex items-center justify-center gap-2 h-12 px-4 rounded-[var(--sg-button-radius)] bg-[var(--sg-accent-button)] hover:bg-[var(--sg-accent-button-hover)] text-white text-base font-medium transition-colors disabled:opacity-60 disabled:cursor-not-allowed"
          >
            {opening ? (
              <>
                <Loader2 className="h-4 w-4 animate-spin" aria-hidden="true" />
                Signing you in…
              </>
            ) : (
              <>
                <ExternalLink className="h-4 w-4" aria-hidden="true" />
                Open {data.fqdn}
              </>
            )}
          </button>
          {openErr ? (
            <p className="text-xs text-center text-[var(--sg-error)]">{openErr}</p>
          ) : (
            <p className="text-xs text-center text-[var(--sg-text-muted)]">
              Signs you in via a one-time link. We also emailed you a 24-hour
              magic link if you&apos;d rather sign in from your inbox.
            </p>
          )}
        </div>

        <DangerZone
          id={data.id}
          name={data.name}
          slug={data.slug}
          onDestroyed={() => router.push("/provision")}
        />
      </div>
    </div>
  );
}

function InfoRow({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="flex items-baseline justify-between gap-4 text-sm">
      <span className="text-[var(--sg-text-muted)] text-xs uppercase tracking-wider font-semibold">
        {label}
      </span>
      <span className="text-[var(--sg-text)] text-right min-w-0 break-all">{children}</span>
    </div>
  );
}

function ProgressList({ status }: { status: string | undefined }) {
  const reachedIdx = status
    ? PROGRESS_STEPS.findIndex((s) => s.key === status)
    : -1;

  return (
    <ol className="space-y-2">
      {PROGRESS_STEPS.map((step, i) => {
        const state =
          reachedIdx === -1
            ? "pending"
            : i < reachedIdx
              ? "done"
              : i === reachedIdx
                ? status === "active"
                  ? "done"
                  : "active"
                : "pending";
        return (
          <li
            key={step.key}
            className="flex items-center gap-3 p-2.5 rounded-lg bg-[var(--sg-bg-0)] border border-[var(--sg-border)]"
          >
            <StepIcon state={state} />
            <span
              className={
                state === "done"
                  ? "text-sm text-[var(--sg-text)]"
                  : state === "active"
                    ? "text-sm text-[var(--sg-text)] font-medium"
                    : "text-sm text-[var(--sg-text-muted)]"
              }
            >
              {step.label}
            </span>
          </li>
        );
      })}
    </ol>
  );
}

function StepIcon({ state }: { state: "done" | "active" | "pending" }) {
  switch (state) {
    case "done":
      return <Check className="h-4 w-4 text-[var(--sg-success)]" aria-hidden="true" />;
    case "active":
      return (
        <Loader2
          className="h-4 w-4 animate-spin text-[var(--sg-accent)]"
          aria-hidden="true"
        />
      );
    case "pending":
      return (
        <Minus className="h-4 w-4 text-[var(--sg-text-muted)]" aria-hidden="true" />
      );
  }
}

// ---------------- Danger zone (destroy) ----------------

function DangerZone({
  id,
  name,
  slug,
  onDestroyed,
}: {
  id: string;
  name: string;
  slug: string;
  onDestroyed: () => void;
}) {
  const [open, setOpen] = useState(false);

  return (
    <div className="rounded-lg border border-[var(--sg-error)]/30 bg-[var(--sg-error)]/5 p-4">
      <div className="text-xs uppercase tracking-wider font-semibold text-[var(--sg-error)] mb-2">
        Danger zone
      </div>
      <p className="text-sm text-[var(--sg-text-muted)] mb-3 leading-snug">
        Destroying tears down the substrate (database, service, DNS, TLS) and removes
        the deployment. <strong className="text-[var(--sg-text)]">This can&apos;t be
        undone.</strong>
      </p>
      <Button variant="destructive" size="sm" onClick={() => setOpen(true)}>
        <Trash2 className="h-3.5 w-3.5" aria-hidden="true" />
        Destroy {name}
      </Button>
      <DestroyDialog
        open={open}
        onOpenChange={setOpen}
        id={id}
        name={name}
        slug={slug}
        onDestroyed={onDestroyed}
      />
    </div>
  );
}

function DestroyDialog({
  open,
  onOpenChange,
  id,
  name,
  slug,
  onDestroyed,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  id: string;
  name: string;
  slug: string;
  onDestroyed: () => void;
}) {
  // When closed, render an empty Dialog so the parent's open<->setOpen
  // wiring still works but no transient state hangs around. Each new
  // open remounts DestroyDialogBody fresh — no need to reset via an
  // effect.
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      {open && (
        <DestroyDialogBody
          id={id}
          name={name}
          slug={slug}
          onCancel={() => onOpenChange(false)}
          onDestroyed={onDestroyed}
        />
      )}
    </Dialog>
  );
}

function DestroyDialogBody({
  id,
  name,
  slug,
  onCancel,
  onDestroyed,
}: {
  id: string;
  name: string;
  slug: string;
  onCancel: () => void;
  onDestroyed: () => void;
}) {
  const [confirm, setConfirm] = useState("");
  const [destroying, setDestroying] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const canDestroy = confirm === slug && !destroying;

  async function handleDestroy() {
    if (!canDestroy) return;
    setDestroying(true);
    setErr(null);
    try {
      await deleteDedicated(id);
      track("dedicated_destroyed", { dedicated_id: id });
      onDestroyed();
    } catch (e) {
      const error = e as Error;
      setErr(error.message || "Couldn't destroy this deployment. Try again.");
      setDestroying(false);
    }
  }

  return (
    <DialogContent>
      <DialogHeader>
        <DialogTitle>Destroy {name}?</DialogTitle>
        <DialogDescription>
          This tears down the database, service, DNS record, and TLS certificate, and
          removes the deployment. It can&apos;t be undone.
        </DialogDescription>
      </DialogHeader>

      <div className="space-y-3">
        <p className="text-xs text-[var(--sg-text-muted)]">
          The name <span className="font-mono text-[var(--sg-text)]">{slug}</span> stays
          reserved for ~5 minutes after destroy so the substrate can finish releasing
          it. You can pick a different name immediately, or re-use this one after the
          cooldown.
        </p>
        <label className="block text-sm">
          <span className="block text-[var(--sg-text-muted)] mb-1.5">
            Type{" "}
            <span className="font-mono text-[var(--sg-text)]">{slug}</span> to confirm:
          </span>
          <input
            type="text"
            value={confirm}
            onChange={(e) => setConfirm(e.target.value)}
            autoComplete="off"
            autoFocus
            className="w-full px-3 py-2 rounded-md bg-[var(--sg-bg-0)] border border-[var(--sg-border)] text-sm text-[var(--sg-text)] font-mono focus:outline-none focus:ring-2 focus:ring-[var(--sg-error)]/40"
          />
        </label>
        {err && <div className="text-xs text-[var(--sg-error)]">{err}</div>}
      </div>

      <DialogFooter>
        <Button variant="outline" onClick={onCancel} disabled={destroying}>
          Cancel
        </Button>
        <Button
          variant="destructive"
          onClick={handleDestroy}
          disabled={!canDestroy}
        >
          {destroying ? "Destroying…" : `Destroy ${name}`}
        </Button>
      </DialogFooter>
    </DialogContent>
  );
}

