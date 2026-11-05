"use client";

import { Instance } from '@/lib/api/client';
import { useEffect, useState } from 'react';
import { useDeepLinkRouter } from '@/hooks';
import { X, Copy, Network, Activity, CheckCircle2, ChevronDown, ChevronRight } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import {
  getInstanceDisplayName,
  getEnvironment,
  getLocation,
  getProject,
  getOwner,
  getSortedTags,
  getHighSignalAttributes,
  getProviderLabel,
} from '@/lib/instances';

interface ResourceDrawerProps {
  instance: Instance | null;
  onClose: () => void;
}

/**
 * Lightweight detail drawer for resource inspection.
 * Shows key attributes, resource address, dependencies, and quick actions.
 */
export function ResourceDrawer({ instance, onClose }: ResourceDrawerProps) {
  const router = useDeepLinkRouter();
  const [copiedAddress, setCopiedAddress] = useState(false);
  const [showAdditionalAttrs, setShowAdditionalAttrs] = useState(false);

  // Close on Escape key
  useEffect(() => {
    if (!instance) return;

    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };

    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [instance, onClose]);

  if (!instance) return null;

  const displayName = getInstanceDisplayName(instance);
  const environment = getEnvironment(instance);
  const location = getLocation(instance);
  const project = getProject(instance);
  const owner = getOwner(instance);
  const allTags = getSortedTags(instance);
  const dependencyCount = instance.dependencies?.length || 0;
  const providerLabel = getProviderLabel(instance.provider);

  // Filter out low-value tags
  const tags = allTags.filter(tag => {
    const lowValueTags = ['ManagedBy', 'Managed By', 'Terraform', 'terraform'];
    if (lowValueTags.includes(tag.key)) return false;
    if (tag.key === 'ManagedBy' && tag.value.toLowerCase() === 'terraform') return false;
    return true;
  });

  // Extract core identifiers and other attributes
  const coreIdentifiers: Array<{key: string, label: string, value: string, mono?: boolean}> = [];
  const additionalAttrs: Array<{key: string, label: string, value: string, mono?: boolean}> = [];

  if (instance.attributes) {
    const attrs = instance.attributes;
    const coreKeys = ['name', 'arn', 'id'];

    coreKeys.forEach(key => {
      const value = attrs[key];
      if (value !== undefined && value !== null && value !== '') {
        coreIdentifiers.push({
          key,
          label: key === 'arn' ? 'ARN' : key === 'id' ? 'ID' : 'Name',
          value: String(value),
          mono: true,
        });
      }
    });

    // Get remaining high-signal attributes
    const highSignalAttrs = getHighSignalAttributes(instance);
    highSignalAttrs.forEach(attr => {
      if (!coreKeys.includes(attr.key)) {
        additionalAttrs.push(attr);
      }
    });
  }

  const copyAddress = async () => {
    await navigator.clipboard.writeText(instance.address);
    setCopiedAddress(true);
    setTimeout(() => setCopiedAddress(false), 2000);
  };

  // Clean module path by removing index notation
  const cleanModulePath = (modulePath: string | undefined): string | undefined => {
    if (!modulePath) return undefined;
    return modulePath.replace(/\[[^\]]+\]/g, '');
  };

  return (
    <>
      {/* Backdrop */}
      <div
        className="fixed inset-0 bg-black/30 z-40"
        onClick={onClose}
      />

      {/* Drawer */}
      <div className="fixed right-0 top-0 bottom-0 w-full max-w-[480px] bg-[var(--sg-bg-1)] border-l border-[var(--sg-border)] z-50 overflow-y-auto">
        {/* Header */}
        <div className="sticky top-0 bg-[var(--sg-bg-1)] border-b border-[var(--sg-border)] z-10">
          <div className="flex items-start justify-between p-4">
            <div className="flex-1 min-w-0">
              <h2 className="text-lg font-semibold text-[var(--sg-text)] truncate">
                {displayName}
              </h2>
              <div className="mt-1.5 flex items-center gap-2 flex-wrap">
                <Badge variant="outline" className="text-xs">
                  {instance.type}
                </Badge>
                <span className="text-xs text-[var(--sg-text-muted)]">
                  {providerLabel}
                </span>
              </div>
            </div>
            <Button
              variant="ghost"
              size="sm"
              onClick={onClose}
              className="flex-shrink-0"
              title="Close (Esc)"
            >
              <X className="h-4 w-4" />
            </Button>
          </div>
        </div>

        {/* Content */}
        <div className="p-4 space-y-6">
          {/* Metadata Section */}
          <Section title="Metadata">
            <dl className="space-y-3">
              {instance.state_name && <Attribute label="State" value={instance.state_name} />}
              {environment && <Attribute label="Environment" value={environment} />}
              {location && <Attribute label="Location" value={location} />}
              {cleanModulePath(instance.module) && <Attribute label="Module" value={cleanModulePath(instance.module)!} mono />}
              {project && <Attribute label="Project" value={project} />}
              {owner && <Attribute label="Owner" value={owner} />}
            </dl>
          </Section>

          {/* Core Identifiers */}
          {coreIdentifiers.length > 0 && (
            <Section title="Identifiers">
              <dl className="space-y-3">
                {coreIdentifiers.map((attr) => (
                  <Attribute
                    key={attr.key}
                    label={attr.label}
                    value={attr.value}
                    mono={attr.mono}
                  />
                ))}
              </dl>
            </Section>
          )}

          {/* Additional Attributes (Collapsible) */}
          {additionalAttrs.length > 0 && (
            <Section title="Configuration">
              <button
                onClick={() => setShowAdditionalAttrs(!showAdditionalAttrs)}
                className="flex items-center gap-2 text-sm text-[var(--sg-text-muted)] hover:text-[var(--sg-text)] transition-colors"
              >
                {showAdditionalAttrs ? (
                  <ChevronDown className="h-4 w-4" />
                ) : (
                  <ChevronRight className="h-4 w-4" />
                )}
                <span>
                  {showAdditionalAttrs ? 'Hide' : 'Show'} additional attributes ({additionalAttrs.length})
                </span>
              </button>

              {showAdditionalAttrs && (
                <dl className="mt-3 space-y-3">
                  {additionalAttrs.map((attr) => (
                    <Attribute
                      key={attr.key}
                      label={attr.label}
                      value={attr.value}
                      mono={attr.mono}
                    />
                  ))}
                </dl>
              )}
            </Section>
          )}

          {/* Tags */}
          {tags.length > 0 && (
            <Section title="Tags">
              <div className="flex flex-wrap gap-2">
                {tags.map((tag) => (
                  <div
                    key={`${tag.key}-${tag.value}`}
                    className="inline-flex items-center gap-1.5 px-2.5 py-1 bg-[var(--sg-bg-2)] border border-[var(--sg-border)] rounded text-xs"
                  >
                    <span className="text-[var(--sg-text-muted)]">{tag.key}</span>
                    <span className="text-[var(--sg-text-dim)]">=</span>
                    <span className="text-[var(--sg-text)]">{tag.value}</span>
                  </div>
                ))}
              </div>
            </Section>
          )}

          {/* Relationships Section - Emphasized */}
          <div className="border border-[var(--sg-border)] rounded-lg bg-[var(--sg-bg-0)] p-4">
            <Section title="Relationships">
              <div className="space-y-3">
                <div className="flex items-center gap-2">
                  <Network className="h-4 w-4 text-[var(--sg-accent)]" />
                  <span className="text-sm font-medium text-[var(--sg-text)]">
                    {dependencyCount} {dependencyCount === 1 ? 'dependency' : 'dependencies'}
                  </span>
                </div>
                <div className="space-y-2 pt-1">
                  <Button
                    variant="outline"
                    className="w-full justify-start hover:bg-[var(--sg-bg-1)] hover:border-[var(--sg-accent)]"
                    size="sm"
                    {...router.nav(`/graph-explorer?resource=${encodeURIComponent(instance.address)}`)}
                  >
                    <Network className="h-4 w-4 mr-2" />
                    View in Graph Explorer
                  </Button>
                  <Button
                    variant="outline"
                    className="w-full justify-start hover:bg-[var(--sg-bg-1)] hover:border-[var(--sg-accent)]"
                    size="sm"
                    {...router.nav(`/blast-radius?resource=${encodeURIComponent(instance.address)}`)}
                  >
                    <Activity className="h-4 w-4 mr-2" />
                    View Blast Radius
                  </Button>
                </div>
              </div>
            </Section>
          </div>

          {/* Resource Address - Recessed */}
          <div className="pt-4 border-t border-[var(--sg-border)]">
            <div className="space-y-2">
              <div className="text-xs text-[var(--sg-text-dim)] uppercase tracking-wide">
                Resource Address
              </div>
              <div className="flex items-center gap-2">
                <code className="flex-1 text-xs font-mono text-[var(--sg-text-muted)] bg-[var(--sg-bg-0)] px-2.5 py-1.5 rounded border border-[var(--sg-border)]">
                  {instance.address}
                </code>
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={copyAddress}
                  className="flex-shrink-0 h-7 w-7 p-0"
                  title="Copy address"
                >
                  {copiedAddress ? (
                    <CheckCircle2 className="h-3.5 w-3.5 text-[var(--sg-success)]" />
                  ) : (
                    <Copy className="h-3.5 w-3.5 text-[var(--sg-text-dim)]" />
                  )}
                </Button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </>
  );
}

interface SectionProps {
  title: string;
  description?: string;
  children: React.ReactNode;
}

function Section({ title, description, children }: SectionProps) {
  return (
    <div className="space-y-2">
      <div>
        <h3 className="text-xs font-medium text-[var(--sg-text-muted)] uppercase tracking-wide">
          {title}
        </h3>
        {description && (
          <p className="text-xs text-[var(--sg-text-dim)] mt-0.5">
            {description}
          </p>
        )}
      </div>
      {children}
    </div>
  );
}

interface AttributeProps {
  label: string;
  value: string;
  mono?: boolean;
}

function Attribute({ label, value, mono = false }: AttributeProps) {
  return (
    <div className="flex items-baseline gap-2 min-w-0">
      <dt className="font-medium text-[var(--sg-text-muted)] text-sm min-w-[120px] flex-shrink-0">
        {label}
      </dt>
      <dd className={`text-sm text-[var(--sg-text)] min-w-0 break-all ${mono ? 'font-mono' : ''}`}>
        {value}
      </dd>
    </div>
  );
}
