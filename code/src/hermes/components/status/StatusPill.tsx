import { TONE_CLASS, type Tone } from "./tones";

/**
 * The one status badge. Same geometry as the Stacks chip so a run outcome, a
 * PR state and a stack state read as the same kind of object everywhere.
 */
export function StatusPill({
  tone,
  label,
  ariaPrefix = "Status",
}: {
  tone: Tone;
  label: string;
  ariaPrefix?: string;
}) {
  return (
    <span
      role="status"
      aria-label={`${ariaPrefix}: ${label}`}
      className={`inline-block px-2 py-0.5 text-[10px] uppercase tracking-wide font-medium rounded border ${TONE_CLASS[tone]}`}
    >
      {label}
    </span>
  );
}
