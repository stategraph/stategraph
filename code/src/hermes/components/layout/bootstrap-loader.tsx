import { Loader2 } from "lucide-react";

/**
 * BootstrapLoader — the single, calm loading visual shown while the app is
 * resolving auth / setup before any console chrome is revealed. One quiet
 * spinner, no text, no layout shift — so the first-load sequence reads as one
 * continuous load rather than a cascade of differently-styled screens.
 */
export function BootstrapLoader() {
  return (
    <div className="flex min-h-screen items-center justify-center bg-[var(--sg-bg-0)]">
      <Loader2 className="h-5 w-5 animate-spin text-[var(--sg-text-dim)]" />
    </div>
  );
}
