"use client";

import { ChevronRight } from "lucide-react";
import { parseModulePath, buildModulePath } from "@/app/(console)/modules/loader";

interface ModuleBreadcrumbProps {
  path: string;
  onNavigate: (path: string) => void;
}

export function ModuleBreadcrumb({ path, onNavigate }: ModuleBreadcrumbProps) {
  const segments = parseModulePath(path);

  return (
    <div className="flex items-center gap-1 flex-wrap">
      {segments.map((segment, index) => {
        const isLast = index === segments.length - 1;
        const targetPath = buildModulePath(segments, index);

        return (
          <div key={`${segment}-${index}`} className="flex items-center gap-1">
            <button
              onClick={() => onNavigate(targetPath)}
              className={`
                px-2 py-1 rounded transition-colors duration-150
                ${
                  isLast
                    ? 'sg-secondary-header text-[var(--sg-text)] cursor-default'
                    : 'sg-metadata text-[var(--sg-text-muted)] hover:text-[var(--sg-accent)] hover:bg-[var(--sg-bg-2)]'
                }
              `}
              disabled={isLast}
            >
              {segment}
            </button>
            {!isLast && (
              <ChevronRight className="h-3.5 w-3.5 text-[var(--sg-text-dim)]" />
            )}
          </div>
        );
      })}
    </div>
  );
}
