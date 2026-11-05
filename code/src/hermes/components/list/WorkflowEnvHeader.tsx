import { TableHead } from "@/components/ui/table";
import { InfoTip } from "@/components/ui/info-tip";

/**
 * The "Workflow env" column header with the one explanation of what a
 * workflow environment is. Callers render it only when some row sets one.
 * `className` is forwarded to the underlying TableHead.
 */
export function WorkflowEnvHeader({ className }: { className?: string }) {
  return (
    <TableHead className={className}>
      <span className="inline-flex items-center gap-1">
        Workflow env
        <InfoTip label="Workflow environment">
          The optional per-workflow environment set in{" "}
          <span className="font-mono">.stategraph/config.yml</span> (legacy{" "}
          <span className="font-mono">.terrateam/config.yml</span>) — analogous to a
          GitHub/GitLab deployment environment. Shown only when a workflow sets it.
        </InfoTip>
      </span>
    </TableHead>
  );
}
