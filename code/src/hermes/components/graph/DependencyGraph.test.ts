/**
 * Tests for DependencyGraph helper functions
 *
 * Note: This tests the helper functions extracted from DependencyGraph.tsx
 * We don't test the full component since it requires DOM/D3 integration
 */

import type { GraphNode } from '@/lib/graph';

/**
 * Extract a human-readable name from a graph node.
 * (Copied from DependencyGraph.tsx for testing)
 */
function getHumanName(node: GraphNode): string {
  // Try attributes.name first
  if (node.attributes?.name && typeof node.attributes.name === 'string') {
    return node.attributes.name;
  }

  // Try attributes.id if it looks human-friendly (not an ARN or UUID)
  if (node.attributes?.id && typeof node.attributes.id === 'string') {
    const id = node.attributes.id;
    // Skip if it looks like an ARN, UUID, or long hash
    if (!id.startsWith('arn:') && id.length < 50 && !id.match(/^[0-9a-f]{8}-[0-9a-f]{4}-/)) {
      return id;
    }
  }

  // Fall back to last part of address
  const parts = node.address.split('.');
  return parts[parts.length - 1] || node.address;
}

/**
 * Format a resource type for display.
 * (Copied from DependencyGraph.tsx for testing)
 */
function formatResourceType(type: string): string {
  // Remove provider prefix (aws_, google_, azurerm_, etc.)
  return type.replace(/^[a-z]+_/, '');
}

// Run tests
let passedTests = 0;
let failedTests = 0;

function expect(actual: unknown) {
  return {
    toBe(expected: unknown) {
      if (actual !== expected) {
        throw new Error(`Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
      }
    },
  };
}

const tests = [
  {
    name: 'getHumanName: uses attributes.name when available',
    fn: () => {
      const node: GraphNode = {
        id: 'test',
        address: 'module.web.aws_instance.server',
        type: 'aws_instance',
        kind: 'resource',
        distance: 0,
        isRoot: true,
        width: 220,
        height: 80,
        attributes: {
          name: 'web-server-prod',
          id: 'i-1234567890',
        },
      };
      expect(getHumanName(node)).toBe('web-server-prod');
    },
  },
  {
    name: 'getHumanName: uses attributes.id when friendly',
    fn: () => {
      const node: GraphNode = {
        id: 'test',
        address: 'module.web.aws_instance.server',
        type: 'aws_instance',
        kind: 'resource',
        distance: 0,
        isRoot: true,
        width: 220,
        height: 80,
        attributes: { id: 'my-instance' },
      };
      expect(getHumanName(node)).toBe('my-instance');
    },
  },
  {
    name: 'getHumanName: skips ARN format ids',
    fn: () => {
      const node: GraphNode = {
        id: 'test',
        address: 'module.web.aws_instance.server',
        type: 'aws_instance',
        kind: 'resource',
        distance: 0,
        isRoot: true,
        width: 220,
        height: 80,
        attributes: {
          id: 'arn:aws:ec2:us-east-1:123456789012:instance/i-1234567890abcdef0',
        },
      };
      expect(getHumanName(node)).toBe('server');
    },
  },
  {
    name: 'getHumanName: skips UUID format ids',
    fn: () => {
      const node: GraphNode = {
        id: 'test',
        address: 'module.web.aws_instance.server',
        type: 'aws_instance',
        kind: 'resource',
        distance: 0,
        isRoot: true,
        width: 220,
        height: 80,
        attributes: { id: '123e4567-e89b-12d3-a456-426614174000' },
      };
      expect(getHumanName(node)).toBe('server');
    },
  },
  {
    name: 'getHumanName: falls back to last part of address',
    fn: () => {
      const node: GraphNode = {
        id: 'test',
        address: 'module.web.aws_instance.server',
        type: 'aws_instance',
        kind: 'resource',
        distance: 0,
        isRoot: true,
        width: 220,
        height: 80,
      };
      expect(getHumanName(node)).toBe('server');
    },
  },
  {
    name: 'formatResourceType: removes AWS provider prefix',
    fn: () => {
      expect(formatResourceType('aws_instance')).toBe('instance');
      expect(formatResourceType('aws_s3_bucket')).toBe('s3_bucket');
      expect(formatResourceType('aws_api_gateway_deployment')).toBe('api_gateway_deployment');
    },
  },
  {
    name: 'formatResourceType: removes Google provider prefix',
    fn: () => {
      expect(formatResourceType('google_compute_instance')).toBe('compute_instance');
    },
  },
  {
    name: 'formatResourceType: removes Azure provider prefix',
    fn: () => {
      expect(formatResourceType('azurerm_virtual_machine')).toBe('virtual_machine');
    },
  },
];

for (const test of tests) {
  try {
    test.fn();
    console.log(`✓ ${test.name}`);
    passedTests++;
  } catch (err) {
    console.error(`✗ ${test.name}`);
    console.error(`  ${err instanceof Error ? err.message : String(err)}`);
    failedTests++;
  }
}

console.log(`\nTests: ${passedTests} passed, ${failedTests} failed`);
process.exit(failedTests > 0 ? 1 : 0);
