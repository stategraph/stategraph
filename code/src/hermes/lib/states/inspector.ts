// State inspector utilities - Transform instance data into Terraform state structure
// This provides a realistic view of the state file for read-only inspection.

import type { Instance, State, StateSummary } from "@/lib/api/client";

// ============================================================================
// Types
// ============================================================================

/**
 * Terraform state file structure (simplified for inspection).
 * Based on terraform.io state format v4 schema.
 */
export interface TerraformStateFile {
  version: number;
  terraform_version: string;
  serial: number;
  lineage: string;
  outputs: Record<string, unknown>;
  resources: TerraformResource[];
  metadata?: {
    created_at?: string;
    group_id?: string;
    workspace?: string;
  };
}

export interface TerraformResource {
  mode: "managed" | "data";
  type: string;
  name: string;
  provider: string;
  instances: TerraformInstance[];
}

export interface TerraformInstance {
  schema_version: number;
  attributes: Record<string, unknown>;
  sensitive_attributes?: Array<{ type: string; value?: unknown }>;
  dependencies?: string[];
}

// ============================================================================
// Transform Functions
// ============================================================================

/**
 * Transform Stategraph instances into a Terraform state file structure.
 * This creates a realistic representation for read-only inspection.
 */
export function constructTerraformState(
  state: State,
  instances: Instance[],
  _summary?: StateSummary
): TerraformStateFile {
  // Group instances by type+name
  const resourceMap = new Map<string, Instance[]>();

  instances.forEach((instance) => {
    const key = instance.address; // Use address as the grouping key
    if (!resourceMap.has(key)) {
      resourceMap.set(key, []);
    }
    resourceMap.get(key)!.push(instance);
  });

  // Transform to Terraform resource format
  const resources: TerraformResource[] = [];

  instances.forEach((instance) => {
    // Parse address to get type and name
    // Format: resource_type.resource_name or module.module_name.resource_type.resource_name
    const addressParts = instance.address.split(".");

    const type = instance.type;
    const name = addressParts[addressParts.length - 1];

    // Check if resource already exists
    const existingResource = resources.find(
      (r) => r.type === type && r.name === name
    );

    const tfInstance: TerraformInstance = {
      schema_version: 1,
      attributes: instance.attributes || {},
      dependencies: instance.dependencies || [],
    };

    if (instance.sensitive_attributes) {
      tfInstance.sensitive_attributes = [
        { type: "get_attr", value: instance.sensitive_attributes },
      ];
    }

    if (existingResource) {
      existingResource.instances.push(tfInstance);
    } else {
      resources.push({
        mode: "managed",
        type,
        name,
        provider: instance.provider || "unknown",
        instances: [tfInstance],
      });
    }
  });

  return {
    version: 4,
    terraform_version: "1.0.0", // Placeholder - backend doesn't track this
    serial: 1,
    lineage: state.id, // Use state ID as lineage
    outputs: {}, // Outputs not tracked separately yet
    resources,
    metadata: {
      created_at: state.created_at,
      group_id: state.group_id,
      workspace: state.workspace,
    },
  };
}

/**
 * Group resources by provider for better organization in the inspector.
 */
export function groupResourcesByProvider(
  resources: TerraformResource[]
): Map<string, TerraformResource[]> {
  const grouped = new Map<string, TerraformResource[]>();

  resources.forEach((resource) => {
    const provider = resource.provider || "unknown";
    if (!grouped.has(provider)) {
      grouped.set(provider, []);
    }
    grouped.get(provider)!.push(resource);
  });

  return grouped;
}

/**
 * Extract provider configurations from resources.
 */
export function extractProviders(
  resources: TerraformResource[]
): Map<string, { count: number; types: Set<string> }> {
  const providers = new Map<
    string,
    { count: number; types: Set<string> }
  >();

  resources.forEach((resource) => {
    const provider = resource.provider || "unknown";
    if (!providers.has(provider)) {
      providers.set(provider, { count: 0, types: new Set() });
    }
    const providerData = providers.get(provider)!;
    providerData.count += resource.instances.length;
    providerData.types.add(resource.type);
  });

  return providers;
}

/**
 * Search filter for state content.
 * Returns true if the resource matches the search query.
 */
export function matchesSearch(
  resource: TerraformResource,
  query: string
): boolean {
  if (!query) return true;

  const lowerQuery = query.toLowerCase();

  // Search in type and name
  if (
    resource.type.toLowerCase().includes(lowerQuery) ||
    resource.name.toLowerCase().includes(lowerQuery) ||
    resource.provider.toLowerCase().includes(lowerQuery)
  ) {
    return true;
  }

  // Search in attributes
  for (const instance of resource.instances) {
    const attrString = JSON.stringify(instance.attributes).toLowerCase();
    if (attrString.includes(lowerQuery)) {
      return true;
    }
  }

  return false;
}

/**
 * Sanitize state data for display.
 * Removes or truncates overly large or sensitive fields.
 */
export function sanitizeForDisplay(
  state: TerraformStateFile
): TerraformStateFile {
  // Create a deep copy
  const sanitized = JSON.parse(JSON.stringify(state)) as TerraformStateFile;

  // Remove or truncate large attribute values
  sanitized.resources.forEach((resource) => {
    resource.instances.forEach((instance) => {
      Object.keys(instance.attributes).forEach((key) => {
        const value = instance.attributes[key];

        // Truncate very long strings
        if (typeof value === "string" && value.length > 1000) {
          instance.attributes[key] = value.substring(0, 1000) + "... (truncated)";
        }

        // Hide sensitive-looking fields by default
        if (
          key.toLowerCase().includes("password") ||
          key.toLowerCase().includes("secret") ||
          key.toLowerCase().includes("key")
        ) {
          instance.attributes[key] = "***REDACTED***";
        }
      });
    });
  });

  return sanitized;
}
