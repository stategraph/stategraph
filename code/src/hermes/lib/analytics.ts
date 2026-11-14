// Analytics event helpers.
//
// Two sinks, both live only when the server runs in COMMUNISM mode:
//
// - Google Tag Manager `dataLayer`. GTM itself is injected by nginx in that
//   mode only; elsewhere `dataLayer` is an array nobody reads. Build a GTM
//   "Custom Event" trigger on the event name to act on it.
// - PostHog (the stategraph.com project). `startAnalytics` loads posthog-js
//   only for COMMUNISM mode in a production build. Calls made before it has
//   decided are queued, then flushed or dropped.
//
// Event properties carry ids, counts and enums only: never names, emails,
// tokens, MQL text, resource addresses or repository names. Person
// properties are set in `identifyUser` alone.

import type { CaptureResult, PostHog } from "posthog-js";
import type { User } from "@/lib/api/client";

const POSTHOG_KEY = "phc_BRE04JP5CJDtgAFF7dqCz10jAtU4YL8W9XqUmoBkQsK";
const POSTHOG_HOST = "https://eu.i.posthog.com";

type Call = (posthog: PostHog) => void;

let started = false;
let client: PostHog | null = null;
// Null once analytics is known to be off.
let pending: Call[] | null = [];

function withPostHog(call: Call) {
  if (client) {
    call(client);
  } else if (pending) {
    pending.push(call);
  }
}

function stripQuery(value: string): string {
  const cut = value.search(/[?#]/);
  return cut === -1 ? value : value.slice(0, cut);
}

/**
 * Remove the query string and fragment from every URL-valued property. The
 * console routes on query parameters, and those carry session ids, invite
 * and claim tokens, MQL text and resource addresses.
 */
export function scrubUrls(event: CaptureResult | null): CaptureResult | null {
  if (!event) return event;
  for (const props of [event.properties, event.$set, event.$set_once]) {
    if (!props) continue;
    for (const [key, value] of Object.entries(props)) {
      if (typeof value === "string" && /^https?:\/\//.test(value)) {
        props[key] = stripQuery(value);
      }
    }
  }
  return event;
}

/**
 * Decide once whether PostHog runs, from the server mode reported by
 * `/api/v1/setup/status`. Anything other than COMMUNISM drops the queue.
 */
export async function startAnalytics(mode: string | undefined): Promise<void> {
  if (started) return;
  started = true;
  if (mode !== "COMMUNISM" || process.env.NODE_ENV !== "production") {
    pending = null;
    return;
  }
  try {
    const { default: posthog } = await import("posthog-js");
    posthog.init(POSTHOG_KEY, {
      api_host: POSTHOG_HOST,
      defaults: "2026-01-30",
      person_profiles: "identified_only",
      autocapture: false,
      capture_pageview: "history_change",
      capture_pageleave: true,
      disable_session_recording: true,
      disable_surveys: true,
      before_send: scrubUrls,
    });
    posthog.register({ app: "console" });
    client = posthog;
    const calls = pending ?? [];
    pending = null;
    calls.forEach((call) => call(posthog));
  } catch (err) {
    pending = null;
    console.warn("[analytics] PostHog failed to load:", err);
  }
}

/** Capture a product event in PostHog. */
export function track(event: string, props?: Record<string, unknown>) {
  withPostHog((posthog) => posthog.capture(event, props));
}

/** Tie this browser to the signed-in user. */
export function identifyUser(user: User) {
  withPostHog((posthog) =>
    posthog.identify(user.id, {
      email: user.email,
      auth_origin: user.auth_origin ?? "local",
    })
  );
}

/** Attach the selected tenant to every later event. */
export function setAnalyticsTenant(tenantId: string | undefined) {
  withPostHog((posthog) =>
    tenantId ? posthog.register({ tenant_id: tenantId }) : posthog.unregister("tenant_id")
  );
}

/** Record the logout and forget the user, before the page navigates away. */
export function trackLogout() {
  withPostHog((posthog) => {
    posthog.capture("logged_out");
    posthog.reset();
  });
}

function pushDataLayer(event: string, props?: Record<string, unknown>) {
  if (typeof window === "undefined") return;
  const w = window as unknown as { dataLayer?: Record<string, unknown>[] };
  w.dataLayer = w.dataLayer || [];
  w.dataLayer.push({ event, ...(props ?? {}) });
}

/**
 * Push a "sign_up" event — fire on a brand-new registration ONLY, never on a
 * returning login. `method` distinguishes the local-auth setup flow ("local")
 * from the hosted OAuth flow ("oauth"). Matches the GA4 recommended event name.
 */
export function pushSignupEvent(method: "local" | "oauth") {
  pushDataLayer("sign_up", { method });
  track("sign_up", { method });
}

/**
 * Push a getting-started funnel event. Names match the existing
 * `getting_started_*` funnel (viewed / path_selected / gitlab_group_selected /
 * completed) so funnels stay comparable across the iris → console migration.
 * `props` carries the path and any step detail.
 */
export function pushGettingStartedEvent(
  name:
    | "getting_started_viewed"
    | "getting_started_path_selected"
    | "getting_started_gitlab_group_selected"
    | "getting_started_step_completed"
    | "getting_started_github_installation_claimed"
    | "getting_started_first_run_detected"
    | "getting_started_completed",
  props?: Record<string, unknown>
) {
  pushDataLayer(name, props);
  track(name, props);
}
