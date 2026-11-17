import { Loader2 } from "lucide-react";

/**
 * BootstrapLoader — the single, calm loading visual shown while the app is
 * resolving auth / setup before any console chrome is revealed. One quiet
 * spinner, no layout shift — so the first-load sequence reads as one
 * continuous load rather than a cascade of differently-styled screens.
 * `message`, when set, is one line of text under the spinner.
 */
export function BootstrapLoader({ message }: { message?: string }) {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center gap-3 bg-[var(--sg-bg-0)]">
      <Loader2 className="h-5 w-5 animate-spin text-[var(--sg-text-dim)]" />
      {message && <p className="px-4 text-center text-sm text-[var(--sg-text-muted)]">{message}</p>}
    </div>
  );
}
