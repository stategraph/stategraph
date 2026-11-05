/** File name for a step output downloaded as text (see lib/export downloadFile). */

export function outputFilename(parts: {
  repo?: string;
  pullNumber?: string;
  runType?: string;
  step?: string;
}): string {
  const segs: string[] = [];
  if (parts.repo) segs.push(parts.repo);
  if (parts.pullNumber) segs.push(`PR${parts.pullNumber}`);
  if (parts.runType) segs.push(parts.runType);
  if (parts.step) segs.push(parts.step.replace(/\//g, "_"));
  segs.push(new Date().toISOString().replace(/[:.]/g, "-").slice(0, 19));
  const base = segs.join("_").replace(/[^a-zA-Z0-9\-_]/g, "_");
  return `${base || "terraform_output"}.txt`;
}
