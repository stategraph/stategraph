export interface PillGroupOption<T extends string> {
  id: T;
  label: string;
  title?: string;
}

export interface PillGroupProps<T extends string> {
  options: readonly PillGroupOption<T>[];
  value: T;
  onChange: (next: T) => void;
}

/**
 * The pill-group single-select used by the cost pages' toolbar controls
 * (range, basis, group-by, dimension). One definition so the pills sitting
 * side by side in the same row cannot drift apart in styling.
 */
export function PillGroup<T extends string>({ options, value, onChange }: PillGroupProps<T>) {
  return (
    <div className="flex flex-wrap gap-1 p-1 bg-[var(--sg-bg-1)] border border-[var(--sg-border-light)] rounded-md w-fit">
      {options.map((o) => {
        const active = o.id === value;
        return (
          <button
            key={o.id}
            onClick={() => onChange(o.id)}
            title={o.title}
            className={`px-3 py-1 text-sm rounded transition-colors ${
              active
                ? "bg-[var(--sg-accent)] text-[var(--sg-bg-0)]"
                : "text-[var(--sg-text-muted)] hover:text-[var(--sg-text)] hover:bg-[var(--sg-bg-2)]"
            }`}
          >
            {o.label}
          </button>
        );
      })}
    </div>
  );
}
