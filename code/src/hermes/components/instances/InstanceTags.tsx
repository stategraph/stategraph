"use client";

import { Instance } from '@/lib/api/client';
import { getSortedTags } from '@/lib/instances/tags';
import { Badge } from '@/components/ui/badge';

interface InstanceTagsProps {
  instance: Instance;
  maxTags?: number;
  showPriorityOnly?: boolean;
}

/**
 * Render instance tags as inline pills.
 * Priority tags (Environment, Project, etc.) are shown first.
 */
export function InstanceTags({
  instance,
  maxTags = 5,
  showPriorityOnly = false,
}: InstanceTagsProps) {
  const allTags = getSortedTags(instance);

  if (allTags.length === 0) {
    return null;
  }

  // Filter to priority tags only if requested
  const tagsToShow = showPriorityOnly
    ? allTags.filter(tag => tag.isPriority)
    : allTags;

  // Limit number of tags shown
  const visibleTags = tagsToShow.slice(0, maxTags);
  const remainingCount = tagsToShow.length - visibleTags.length;

  return (
    <div className="flex flex-wrap gap-1.5 items-center">
      {visibleTags.map((tag) => (
        <Badge
          key={`${tag.key}-${tag.value}`}
          variant="secondary"
          className={`text-xs font-normal ${
            tag.isPriority
              ? 'bg-[var(--sg-accent-bg)] text-[var(--sg-accent)] border-[var(--sg-accent)]/30'
              : 'bg-[var(--sg-bg-1)] text-[var(--sg-text-muted)] border-[var(--sg-border)]'
          }`}
        >
          <span className="font-medium">{tag.key}:</span>
          <span className="ml-1">{tag.value}</span>
        </Badge>
      ))}

      {remainingCount > 0 && (
        <Badge
          variant="outline"
          className="text-xs bg-transparent text-[var(--sg-text-dim)] border-[var(--sg-border)]"
        >
          +{remainingCount} more
        </Badge>
      )}
    </div>
  );
}
