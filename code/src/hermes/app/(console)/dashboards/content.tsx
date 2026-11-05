"use client";

import { useState } from 'react';
import { useDeepLinkRouter } from '@/hooks';
import { Plus, LayoutDashboard, Calendar, FileText } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { PageHeader, PageSection } from '@/components/page';
import { useDashboards } from '../query/useDashboards';
import { DashboardCreateDialog } from '../query/DashboardCreateDialog';
import type { DashboardInput } from '../query/dashboardRepository';
import { track } from '@/lib/analytics';

export function DashboardsContent() {
  const router = useDeepLinkRouter();
  const { dashboards, saveDashboard } = useDashboards();
  const [showCreateDialog, setShowCreateDialog] = useState(false);

  const handleCreateDashboard = (input: DashboardInput) => {
    const newDashboard = saveDashboard(input);
    track("dashboard_created", { visualization_count: input.visualizationIds?.length ?? 0 });
    router.push(`/dashboard?id=${newDashboard.id}`);
  };

  const formatDate = (isoString: string) => {
    const date = new Date(isoString);
    return date.toLocaleDateString('en-US', {
      month: 'long',
      day: 'numeric',
      year: 'numeric',
    });
  };

  return (
    <div className="h-full flex flex-col bg-[var(--sg-bg-0)]">
      {/* Header */}
      <PageHeader
        title="Dashboards"
        subtitle="Organize visualizations into custom dashboards for quick analysis"
      >
        <Button onClick={() => setShowCreateDialog(true)}>
          <Plus className="w-4 h-4 mr-2" />
          New Dashboard
        </Button>
      </PageHeader>

      {/* Content */}
      <div className="flex-1 overflow-y-auto px-6 py-6">
        <PageSection>
          {dashboards.length === 0 ? (
            // Empty State
            <div className="flex items-center justify-center py-24">
              <div className="text-center max-w-md">
                <LayoutDashboard className="w-16 h-16 mx-auto mb-4 text-[var(--sg-text-muted)] opacity-50" />
                <h3 className="text-lg font-semibold text-[var(--sg-text)] mb-2">
                  No Dashboards Yet
                </h3>
                <p className="text-sm text-[var(--sg-text-muted)] mb-6">
                  Create your first dashboard to organize saved visualizations into a single view.
                </p>
                <Button onClick={() => setShowCreateDialog(true)}>
                  <Plus className="w-4 h-4 mr-2" />
                  Create Dashboard
                </Button>
              </div>
            </div>
          ) : (
            // Dashboard Grid
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              {dashboards.map((dashboard) => (
                <button
                  key={dashboard.id}
                  {...router.nav(`/dashboard?id=${dashboard.id}`)}
                  className="text-left p-6 rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-1)] hover:bg-[var(--sg-bg-2)] hover:border-[var(--sg-accent)] transition-colors duration-200 group"
                >
                  <div className="flex items-start gap-3 mb-3">
                    <LayoutDashboard className="w-5 h-5 text-[var(--sg-accent)] flex-shrink-0 mt-0.5" />
                    <div className="flex-1 min-w-0">
                      <h3 className="text-base font-semibold text-[var(--sg-text)] mb-1 group-hover:text-[var(--sg-accent)] transition-colors">
                        {dashboard.name}
                      </h3>
                      {dashboard.description && (
                        <p className="text-sm text-[var(--sg-text-muted)] line-clamp-2 mb-2">
                          {dashboard.description}
                        </p>
                      )}
                    </div>
                  </div>

                  <div className="flex items-center gap-4 text-xs text-[var(--sg-text-dim)]">
                    <div className="flex items-center gap-1">
                      <Calendar className="w-3 h-3" />
                      <span>{formatDate(dashboard.createdAt)}</span>
                    </div>
                    <div className="flex items-center gap-1">
                      <FileText className="w-3 h-3" />
                      <span>
                        {dashboard.visualizationIds.length}{' '}
                        {dashboard.visualizationIds.length === 1 ? 'chart' : 'charts'}
                      </span>
                    </div>
                  </div>
                </button>
              ))}
            </div>
          )}
        </PageSection>
      </div>

      {/* Create Dialog */}
      <DashboardCreateDialog
        isOpen={showCreateDialog}
        onClose={() => setShowCreateDialog(false)}
        onCreate={handleCreateDashboard}
      />
    </div>
  );
}
