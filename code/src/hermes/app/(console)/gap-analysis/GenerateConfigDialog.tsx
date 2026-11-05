"use client";

import { useState, useEffect } from "react";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import {
  Copy,
  Download,
  CheckCircle,
  AlertTriangle,
  Loader2,
  FileCode,
  ChevronDown,
  ChevronUp,
} from "lucide-react";
import { Prism as SyntaxHighlighter } from "react-syntax-highlighter";
import { vs } from "react-syntax-highlighter/dist/esm/styles/prism";
import { UnmanagedResource, GapAnalysisProvider, generateTofuImport, TofuImportResponse } from "@/lib/api/client";
import { useTenant } from "@/contexts";
import { track } from "@/lib/analytics";

interface GenerateConfigDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  resources: UnmanagedResource[];
  provider: GapAnalysisProvider;
}

export function GenerateConfigDialog({
  open,
  onOpenChange,
  resources,
  provider,
}: GenerateConfigDialogProps) {
  const { currentTenant } = useTenant();
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState<TofuImportResponse | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [copied, setCopied] = useState(false);
  const [showUnsupported, setShowUnsupported] = useState(false);

  // Generate config when dialog opens
  useEffect(() => {
    if (open && resources.length > 0 && currentTenant) {
      generateConfig();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open]);

  const generateConfig = async () => {
    if (!currentTenant) {
      setError("No tenant selected");
      return;
    }

    setLoading(true);
    setError(null);
    setResult(null);

    try {
      const response = await generateTofuImport(currentTenant.id, resources, provider);

      if (response.error) {
        setError(response.message || response.error);
      } else {
        setResult(response);
        track('import_config_generated', { provider, resource_count: resources.length });
      }
    } catch (e) {
      console.error("Generate config error:", e);
      setError(e instanceof Error ? e.message : "Failed to generate configuration");
    } finally {
      setLoading(false);
    }
  };

  const handleCopy = async () => {
    if (!result?.generated_hcl) return;

    try {
      await navigator.clipboard.writeText(result.generated_hcl);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch (e) {
      console.error("Failed to copy:", e);
    }
  };

  const handleDownload = () => {
    if (!result?.generated_hcl) return;

    const blob = new Blob([result.generated_hcl], { type: "text/plain" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `generated-${provider}-${Date.now()}.tf`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  };

  const handleClose = () => {
    if (!loading) {
      onOpenChange(false);
      // Reset state after dialog closes
      setTimeout(() => {
        setResult(null);
        setError(null);
        setCopied(false);
        setShowUnsupported(false);
      }, 300);
    }
  };

  return (
    <Dialog open={open} onOpenChange={handleClose}>
      <DialogContent className="sm:max-w-[800px] max-h-[85vh] flex flex-col">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <FileCode className="h-5 w-5" />
            Generate Terraform Configuration
          </DialogTitle>
          <DialogDescription>
            Generating Terraform resource definitions for {resources.length} selected resource{resources.length !== 1 ? 's' : ''}
          </DialogDescription>
        </DialogHeader>

        <div className="flex-1 min-h-0 flex flex-col gap-4 py-4 overflow-hidden">
          {/* Loading State */}
          {loading && (
            <div className="flex flex-col items-center justify-center py-12 gap-4">
              <Loader2 className="h-8 w-8 animate-spin text-[var(--sg-primary)]" />
              <div className="text-sm text-[var(--sg-text-muted)]">
                Generating configuration...
              </div>
              <div className="text-xs text-[var(--sg-text-muted)]">
                This may take a moment depending on the number of resources.
              </div>
            </div>
          )}

          {/* Error State */}
          {error && !loading && (
            <div className="flex items-start gap-3 p-4 rounded-lg border border-[var(--sg-error)] bg-[var(--sg-error)]/5">
              <AlertTriangle className="h-5 w-5 text-[var(--sg-error)] flex-shrink-0 mt-0.5" />
              <div>
                <div className="font-medium text-[var(--sg-error)]">Generation Failed</div>
                <div className="text-sm text-[var(--sg-text-muted)] mt-1">{error}</div>
              </div>
            </div>
          )}

          {/* Result State */}
          {result && !loading && (
            <>
              {/* Summary badges */}
              <div className="flex items-center gap-3">
                <div className="flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-[var(--sg-success)]/10 text-[var(--sg-success)] text-sm">
                  <CheckCircle className="h-3.5 w-3.5" />
                  {result.supported_count} resource{result.supported_count !== 1 ? 's' : ''} generated
                </div>
                {result.unsupported_count > 0 && (
                  <div className="flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-[var(--sg-warning)]/10 text-[var(--sg-warning)] text-sm">
                    <AlertTriangle className="h-3.5 w-3.5" />
                    {result.unsupported_count} unsupported
                  </div>
                )}
              </div>

              {/* Unsupported resources warning */}
              {result.unsupported_count > 0 && result.unsupported_resources && (
                <div className="flex-shrink-0 rounded-lg border border-[var(--sg-warning)] bg-[var(--sg-warning)]/5">
                  <button
                    onClick={() => setShowUnsupported(!showUnsupported)}
                    className="flex items-center justify-between w-full p-3 text-left hover:bg-[var(--sg-warning)]/10 transition-colors rounded-lg"
                  >
                    <div className="flex items-center gap-2 text-sm text-[var(--sg-warning)]">
                      <AlertTriangle className="h-4 w-4 flex-shrink-0" />
                      <span>
                        {result.unsupported_count} resource type{result.unsupported_count !== 1 ? 's' : ''} not yet supported
                      </span>
                    </div>
                    {showUnsupported ? (
                      <ChevronUp className="h-4 w-4 text-[var(--sg-warning)] flex-shrink-0" />
                    ) : (
                      <ChevronDown className="h-4 w-4 text-[var(--sg-warning)] flex-shrink-0" />
                    )}
                  </button>
                  {showUnsupported && (
                    <div className="px-3 pb-3 pt-0 border-t border-[var(--sg-warning)]/30">
                      <div className="space-y-1 mt-2 max-h-32 overflow-auto">
                        {result.unsupported_resources.map((res, idx) => (
                          <div key={idx} className="text-xs text-[var(--sg-text-muted)] font-mono">
                            {res.service}/{res.resource_type}
                          </div>
                        ))}
                      </div>
                    </div>
                  )}
                </div>
              )}

              {/* Generated HCL Preview */}
              {result.generated_hcl && (
                <div className="flex-1 min-h-0 rounded-lg border border-[var(--sg-border)] overflow-auto">
                  <SyntaxHighlighter
                    language="hcl"
                    style={vs}
                    customStyle={{
                      margin: 0,
                      padding: "1rem",
                      fontSize: "0.75rem",
                      background: "transparent",
                      border: "none",
                    }}
                    showLineNumbers
                    lineNumberStyle={{
                      minWidth: "2.5em",
                      paddingRight: "1em",
                      opacity: 0.5,
                      userSelect: "none",
                    }}
                  >
                    {result.generated_hcl}
                  </SyntaxHighlighter>
                </div>
              )}
            </>
          )}
        </div>

        <DialogFooter className="flex-shrink-0">
          <Button variant="outline" onClick={handleClose} disabled={loading}>
            Close
          </Button>
          {result && !error && (
            <>
              <Button variant="outline" onClick={handleCopy} disabled={!result.generated_hcl}>
                {copied ? (
                  <>
                    <CheckCircle className="h-4 w-4 mr-2 text-[var(--sg-success)]" />
                    Copied!
                  </>
                ) : (
                  <>
                    <Copy className="h-4 w-4 mr-2" />
                    Copy to Clipboard
                  </>
                )}
              </Button>
              <Button onClick={handleDownload} disabled={!result.generated_hcl}>
                <Download className="h-4 w-4 mr-2" />
                Download .tf
              </Button>
            </>
          )}
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
