// Metadata extraction utilities for instances
// Derives environment, location, IaC status, and other inventory metadata

import { Instance } from '@/lib/api/client';

/**
 * IaC status values for inventory view
 */
export type IaCStatus = 'codified' | 'drifted' | 'ghost' | 'unmanaged';

/**
 * Attribute fields `getLocation` reads directly as a region value, ordered by
 * reliability. Exported so a slim server-side attribute projection can keep
 * exactly the keys the region heuristic needs (see instances/mqlQueries.ts).
 */
export const REGION_DIRECT_FIELDS = [
  'region',          // Most common
  'location',        // Azure primary field
  'aws_region',      // Explicit AWS
  'gcp_region',      // Explicit GCP
  'azure_location',  // Explicit Azure
] as const;

/**
 * Attribute fields `getLocation` derives a region from by parsing (AZ suffix,
 * ARN region segment) rather than reading directly.
 */
export const REGION_DERIVED_FIELDS = ['availability_zone', 'zone', 'arn'] as const;

/**
 * Every attribute key the location heuristic inspects. Single source of truth
 * for the slim attribute allowlist in instances/mqlQueries.ts, so the SQL
 * projection cannot drift from what `getLocation` actually reads.
 */
export const LOCATION_SOURCE_FIELDS = [
  ...REGION_DIRECT_FIELDS,
  ...REGION_DERIVED_FIELDS,
] as const;

/**
 * Extract environment from instance tags or attributes.
 * Common tag keys: Environment, Env, environment, env
 */
export function getEnvironment(instance: Instance): string | undefined {
  if (!instance.attributes?.tags) {
    return undefined;
  }

  const tags = instance.attributes.tags;

  // Check common environment tag keys
  const envKeys = ['Environment', 'Env', 'environment', 'env'];
  for (const key of envKeys) {
    const value = tags[key];
    if (value && typeof value === 'string' && value.trim()) {
      return value.trim();
    }
  }

  return undefined;
}

/**
 * Extract location/region from instance attributes (best-effort only).
 * Returns region string, "global" for global resources, or undefined if unknown.
 *
 * Rules:
 * - Only return location if confidently known
 * - Check common provider-specific fields
 * - Identify globally-scoped resources
 * - Return undefined (not "unknown") when location cannot be determined
 */
export function getLocation(instance: Instance): string | undefined {
  if (!instance.attributes) {
    // Check for global resources by type even without attributes
    if (isGlobalResourceType(instance.type)) {
      return 'global';
    }
    return undefined;
  }

  // Common region/location fields across providers (ordered by reliability)
  // Check for direct region fields
  for (const field of REGION_DIRECT_FIELDS) {
    const value = instance.attributes[field];
    if (value && typeof value === 'string' && value.trim()) {
      return value.trim();
    }
  }

  // Extract region from availability zone (e.g., "us-east-1a" -> "us-east-1")
  const az = instance.attributes.availability_zone || instance.attributes.zone;
  if (az && typeof az === 'string' && az.trim()) {
    // AWS AZ format: region + letter (e.g., us-east-1a)
    const azTrimmed = az.trim();
    const regionMatch = azTrimmed.match(/^([a-z]{2}-[a-z]+-\d+)[a-z]$/);
    if (regionMatch) {
      return regionMatch[1];
    }
  }

  // Best-effort ARN parsing for AWS resources
  const arn = instance.attributes.arn;
  if (arn && typeof arn === 'string' && arn.trim()) {
    const region = extractRegionFromArn(arn);
    if (region) {
      return region;
    }
  }

  // Check for global resources by type
  if (isGlobalResourceType(instance.type)) {
    return 'global';
  }

  // Cannot confidently determine location
  return undefined;
}

/**
 * Check if a resource type is globally scoped (not region-specific).
 */
function isGlobalResourceType(resourceType: string): boolean {
  const globalTypes = [
    // AWS global services
    'aws_iam_role',
    'aws_iam_user',
    'aws_iam_policy',
    'aws_iam_group',
    'aws_iam_access_key',
    'aws_route53_zone',
    'aws_route53_record',
    'aws_cloudfront_distribution',
    'aws_cloudfront_origin_access_identity',
    'aws_organizations_organization',
    'aws_organizations_account',

    // GCP global services
    'google_project',
    'google_project_iam_member',
    'google_project_iam_binding',

    // Azure global services
    'azurerm_subscription',
    'azurerm_management_group',

    // GitHub/GitLab (not region-scoped)
    'github_repository',
    'github_team',
    'gitlab_project',
    'gitlab_group',
  ];

  return globalTypes.includes(resourceType);
}

/**
 * Extract region from AWS ARN (best-effort only).
 * ARN format: arn:partition:service:region:account-id:resource
 */
function extractRegionFromArn(arn: string): string | undefined {
  if (!arn.startsWith('arn:')) {
    return undefined;
  }

  const parts = arn.split(':');
  if (parts.length < 6) {
    return undefined;
  }

  const region = parts[3]; // Region is the 4th component (0-indexed: 3)

  // Empty region means global service
  if (!region || region === '') {
    return undefined; // Will be handled by global type check
  }

  // Validate region format (e.g., us-east-1)
  if (/^[a-z]{2}-[a-z]+-\d+$/.test(region)) {
    return region;
  }

  return undefined;
}

/**
 * Derive IaC status for an instance.
 *
 * For now, all instances from Terraform state are "codified".
 * In the future, this could be enriched with drift detection.
 */
export function getIaCStatus(_instance: Instance): IaCStatus {
  // All instances in Terraform state are codified
  // Future: Check for drift detection metadata when available
  return 'codified';
}

/**
 * Get status badge color based on IaC status
 */
export function getStatusColor(status: IaCStatus): string {
  switch (status) {
    case 'codified':
      return 'bg-[var(--sg-success)]/10 text-[var(--sg-success)] border-[var(--sg-success)]/30';
    case 'drifted':
      return 'bg-[var(--sg-warning)]/10 text-[var(--sg-warning)] border-[var(--sg-warning)]/30';
    case 'ghost':
      return 'bg-[var(--sg-error)]/10 text-[var(--sg-error)] border-[var(--sg-error)]/30';
    case 'unmanaged':
      return 'bg-[var(--sg-text-dim)]/10 text-[var(--sg-text-dim)] border-[var(--sg-text-dim)]/30';
  }
}

/**
 * Get status label
 */
export function getStatusLabel(status: IaCStatus): string {
  switch (status) {
    case 'codified':
      return 'Codified';
    case 'drifted':
      return 'Drifted';
    case 'ghost':
      return 'Ghost';
    case 'unmanaged':
      return 'Unmanaged';
  }
}

/**
 * Extract project name from tags
 */
export function getProject(instance: Instance): string | undefined {
  if (!instance.attributes?.tags) {
    return undefined;
  }

  const tags = instance.attributes.tags;
  const projectKeys = ['Project', 'project', 'Application', 'App', 'application', 'app'];

  for (const key of projectKeys) {
    const value = tags[key];
    if (value && typeof value === 'string' && value.trim()) {
      return value.trim();
    }
  }

  return undefined;
}

/**
 * Extract owner from tags
 */
export function getOwner(instance: Instance): string | undefined {
  if (!instance.attributes?.tags) {
    return undefined;
  }

  const tags = instance.attributes.tags;
  const ownerKeys = ['Owner', 'owner', 'Team', 'team'];

  for (const key of ownerKeys) {
    const value = tags[key];
    if (value && typeof value === 'string' && value.trim()) {
      return value.trim();
    }
  }

  return undefined;
}

/**
 * Check if instance has drift (placeholder for future)
 */
export function hasDrift(_instance: Instance): boolean {
  // Placeholder: will be implemented when drift detection is available
  return false;
}

/**
 * Check if instance has policy violations (placeholder for future)
 */
export function hasPolicyViolations(_instance: Instance): boolean {
  // Placeholder: will be implemented when policy engine is available
  return false;
}

/**
 * Get resource flags for display
 */
export interface ResourceFlags {
  hasDrift: boolean;
  hasPolicy: boolean;
  hasRelationships: boolean;
}

export function getResourceFlags(instance: Instance): ResourceFlags {
  return {
    hasDrift: hasDrift(instance),
    hasPolicy: hasPolicyViolations(instance),
    hasRelationships: (instance.dependencies?.length || 0) > 0,
  };
}
