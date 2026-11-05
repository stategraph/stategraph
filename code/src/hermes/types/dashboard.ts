// Dashboard metrics from state summaries

export type ProviderDistribution = Record<string, number>;

export interface DashboardMetrics {
  // State info
  stateName: string;

  // Counts from state-summary endpoint
  totalResources: number;
  totalInstances: number;
  totalProviders: number;
  totalModules: number;
  totalEdges: number;

  // Derived from resources-summary endpoint
  totalResourceTypes: number;
  providerDistribution: ProviderDistribution;

  // Resource type breakdown (aggregated from resources-summary)
  resourceTypes: Record<string, number>;
}
