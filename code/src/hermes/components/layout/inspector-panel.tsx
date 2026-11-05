interface InspectorPanelProps {
  title?: string;
  children: React.ReactNode;
}

export function InspectorPanel({ title = "Inspector", children }: InspectorPanelProps) {
  return (
    <div className="flex flex-col h-full">
      {/* Header */}
      <div className="flex-shrink-0 p-4 border-b border-[var(--sg-border)]">
        <h2 className="text-sm font-semibold text-[var(--sg-text)]">{title}</h2>
      </div>

      {/* Scrollable Body */}
      <div className="flex-1 overflow-auto p-4 space-y-4">
        {children}
      </div>
    </div>
  );
}

export function InspectorSection({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div>
      <h3 className="sg-section-header">{title}</h3>
      <div className="space-y-2">
        {children}
      </div>
    </div>
  );
}

export function InspectorField({ label, value }: { label: string; value: React.ReactNode }) {
  return (
    <div className="flex flex-col gap-1">
      <span className="text-xs text-[var(--sg-text-muted)]">{label}</span>
      <span className="text-sm text-[var(--sg-text)] font-mono">{value}</span>
    </div>
  );
}
