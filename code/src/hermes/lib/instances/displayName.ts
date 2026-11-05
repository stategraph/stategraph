// Display name resolution for instances
// Derives human-readable names from instance attributes

import { Instance } from '@/lib/api/client';

/**
 * Well-known provider fields for extracting display names.
 * Organized by provider and resource type for best-effort matching.
 */
const PROVIDER_NAME_FIELDS: Record<string, Record<string, string[]>> = {
  aws: {
    aws_s3_bucket: ['bucket'],
    aws_db_instance: ['db_instance_identifier', 'identifier'],
    aws_rds_cluster: ['cluster_identifier'],
    aws_ecs_cluster: ['name'],
    aws_ecs_service: ['name'],
    aws_ecs_task_definition: ['family'],
    aws_iam_role: ['name'],
    aws_iam_user: ['name'],
    aws_iam_policy: ['name'],
    aws_lambda_function: ['function_name'],
    aws_instance: ['id', 'private_dns'],
    aws_vpc: ['id'],
    aws_subnet: ['id'],
    aws_security_group: ['name'],
    aws_alb: ['name'],
    aws_lb: ['name'],
    aws_route53_zone: ['name'],
    aws_route53_record: ['name'],
    aws_cloudfront_distribution: ['id'],
    aws_dynamodb_table: ['name'],
    aws_sqs_queue: ['name'],
    aws_sns_topic: ['name'],
    aws_kinesis_stream: ['name'],
    aws_ecr_repository: ['name'],
    aws_elasticache_cluster: ['cluster_id'],
  },
  google: {
    google_compute_instance: ['name'],
    google_storage_bucket: ['name'],
    google_sql_database_instance: ['name'],
    google_container_cluster: ['name'],
  },
  azurerm: {
    azurerm_virtual_machine: ['name'],
    azurerm_storage_account: ['name'],
    azurerm_sql_server: ['name'],
    azurerm_kubernetes_cluster: ['name'],
  },
  kubernetes: {
    kubernetes_deployment: ['metadata.0.name'],
    kubernetes_service: ['metadata.0.name'],
    kubernetes_namespace: ['metadata.0.name'],
    kubernetes_pod: ['metadata.0.name'],
  },
};

/**
 * Extract a value from a nested object using dot notation.
 * e.g., "metadata.0.name" -> attributes.metadata[0].name
 */
function getNestedValue(obj: unknown, path: string): unknown {
  if (!obj) return undefined;

  const parts = path.split('.');
  let current: unknown = obj;

  for (const part of parts) {
    if (current === null || current === undefined) return undefined;

    // Handle array indices
    const index = parseInt(part, 10);
    if (!isNaN(index)) {
      current = Array.isArray(current) ? current[index] : undefined;
    } else {
      current = (current as Record<string, unknown>)[part];
    }
  }

  return current;
}

/**
 * Attempt to extract a display name from well-known provider fields.
 */
function getProviderFieldName(instance: Instance): string | undefined {
  if (!instance.attributes) return undefined;

  const provider = instance.provider.toLowerCase();
  const resourceType = instance.type.toLowerCase();

  // Check for provider-specific fields
  const providerFields = PROVIDER_NAME_FIELDS[provider];
  if (providerFields) {
    const typeFields = providerFields[resourceType];
    if (typeFields) {
      for (const field of typeFields) {
        const value = getNestedValue(instance.attributes, field);
        if (value && typeof value === 'string' && value.trim()) {
          return value.trim();
        }
      }
    }
  }

  return undefined;
}

/**
 * Resolve a human-readable display name for an instance.
 *
 * Resolution order (first match wins):
 * 1. instance.attributes?.tags?.Name
 * 2. instance.attributes?.name
 * 3. Well-known provider fields (S3 bucket, RDS identifier, etc.)
 * 4. Compact fallback derived from instance.address
 *
 * The compact fallback:
 * - Strips module prefixes
 * - Removes array indices
 * - Extracts the resource name (last segment)
 *
 * This is computed at render time only and never stored or sent to the API.
 */
export function getInstanceDisplayName(instance: Instance): string {
  // 1. Try tags.Name (AWS convention)
  const tagsName = instance.attributes?.tags?.Name;
  if (tagsName && typeof tagsName === 'string' && tagsName.trim()) {
    return tagsName.trim();
  }

  // 2. Try generic name attribute
  const genericName = instance.attributes?.name;
  if (genericName && typeof genericName === 'string' && genericName.trim()) {
    return genericName.trim();
  }

  // 3. Try well-known provider fields
  const providerName = getProviderFieldName(instance);
  if (providerName) {
    return providerName;
  }

  // 4. Compact fallback from Terraform address
  return getCompactAddressName(instance.address);
}

/**
 * Create a compact, human-scannable name from a Terraform address.
 *
 * Transformations:
 * - module.networking.aws_ecs_cluster.main → main
 * - module.vpc.aws_subnet.private[0] → private
 * - aws_s3_bucket.logs → logs
 * - data.aws_ami.ubuntu → ubuntu
 *
 * Rules:
 * 1. Strip module prefixes (everything before resource type)
 * 2. Extract resource name (last segment after resource type)
 * 3. Remove array indices [0], [1], etc.
 */
function getCompactAddressName(address: string): string {
  if (!address || !address.trim()) {
    return '—';
  }

  // Remove array indices: [0], [1], ["key"], etc.
  const cleaned = address.replace(/\[[^\]]+\]/g, '');

  // Split by dots
  const segments = cleaned.split('.');

  if (segments.length === 0) {
    return address; // Shouldn't happen, but safeguard
  }

  // Address patterns:
  // 1. Simple: resource_type.name (e.g., aws_s3_bucket.logs)
  // 2. Module: module.path.resource_type.name
  // 3. Data: data.resource_type.name
  // 4. Count/each: resource_type.name[0] (already stripped)

  // Strategy: Find the resource type segment, then take the next segment
  // Resource types contain underscores and start with provider prefix
  // Examples: aws_s3_bucket, google_compute_instance, azurerm_virtual_machine

  // Find last segment that looks like a resource type (has underscores)
  let resourceTypeIndex = -1;
  for (let i = segments.length - 1; i >= 0; i--) {
    if (segments[i].includes('_')) {
      resourceTypeIndex = i;
      break;
    }
  }

  // If we found a resource type and there's a segment after it, use that
  if (resourceTypeIndex >= 0 && resourceTypeIndex < segments.length - 1) {
    return segments[resourceTypeIndex + 1];
  }

  // Fallback: use the last segment (most specific)
  return segments[segments.length - 1];
}

/**
 * Check if the display name is derived (not the Terraform address).
 * Useful for UI decisions like showing an icon or styling differently.
 */
export function hasCustomDisplayName(instance: Instance): boolean {
  const displayName = getInstanceDisplayName(instance);
  return displayName !== instance.address;
}
