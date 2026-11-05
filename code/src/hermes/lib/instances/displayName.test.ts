/**
 * Tests for display name resolution
 * Run with: npx tsx lib/instances/displayName.test.ts
 */

import { getInstanceDisplayName, hasCustomDisplayName } from './displayName';
import type { Instance } from '@/lib/api/client';

console.log('🧪 Testing Display Name Resolution\n');
console.log('='.repeat(60));

let passed = 0;
let failed = 0;

interface TestCase {
  name: string;
  instance: Partial<Instance>;
  expectedDisplayName: string;
  shouldHaveCustomName?: boolean;
}

const testCases: TestCase[] = [
  {
    name: 'Uses tags.Name (AWS convention)',
    instance: {
      address: 'module.vpc.aws_instance.web_server',
      provider: 'registry.terraform.io/hashicorp/aws',
      type: 'aws_instance',
      attributes: {
        tags: {
          Name: 'Production Web Server',
        },
      },
    },
    expectedDisplayName: 'Production Web Server',
    shouldHaveCustomName: true,
  },
  {
    name: 'Uses generic name attribute',
    instance: {
      address: 'aws_s3_bucket.data',
      provider: 'registry.terraform.io/hashicorp/aws',
      type: 'aws_s3_bucket',
      attributes: {
        name: 'my-data-bucket',
      },
    },
    expectedDisplayName: 'my-data-bucket',
    shouldHaveCustomName: true,
  },
  {
    name: 'Uses S3 bucket field',
    instance: {
      address: 'aws_s3_bucket.logs',
      provider: 'aws',
      type: 'aws_s3_bucket',
      attributes: {
        bucket: 'app-logs-bucket',
      },
    },
    expectedDisplayName: 'app-logs-bucket',
    shouldHaveCustomName: true,
  },
  {
    name: 'Uses RDS identifier',
    instance: {
      address: 'aws_db_instance.main',
      provider: 'aws',
      type: 'aws_db_instance',
      attributes: {
        db_instance_identifier: 'prod-postgres-01',
      },
    },
    expectedDisplayName: 'prod-postgres-01',
    shouldHaveCustomName: true,
  },
  {
    name: 'Uses Lambda function_name',
    instance: {
      address: 'aws_lambda_function.processor',
      provider: 'aws',
      type: 'aws_lambda_function',
      attributes: {
        function_name: 'image-processor',
      },
    },
    expectedDisplayName: 'image-processor',
    shouldHaveCustomName: true,
  },
  {
    name: 'Falls back to compact address - simple',
    instance: {
      address: 'aws_instance.web',
      provider: 'registry.terraform.io/hashicorp/aws',
      type: 'aws_instance',
      attributes: {},
    },
    expectedDisplayName: 'web',
    shouldHaveCustomName: true, // Different from full address
  },
  {
    name: 'Falls back to compact address - with module',
    instance: {
      address: 'module.networking.aws_vpc.main',
      provider: 'registry.terraform.io/hashicorp/aws',
      type: 'aws_vpc',
      attributes: {},
    },
    expectedDisplayName: 'main',
    shouldHaveCustomName: true, // Different from full address
  },
  {
    name: 'Falls back to compact address - with array index',
    instance: {
      address: 'aws_subnet.private[0]',
      provider: 'registry.terraform.io/hashicorp/aws',
      type: 'aws_subnet',
      attributes: {},
    },
    expectedDisplayName: 'private',
    shouldHaveCustomName: true, // Different from full address
  },
  {
    name: 'Falls back to compact address - nested module',
    instance: {
      address: 'module.vpc.module.subnets.aws_subnet.private[2]',
      provider: 'registry.terraform.io/hashicorp/aws',
      type: 'aws_subnet',
      attributes: {},
    },
    expectedDisplayName: 'private',
    shouldHaveCustomName: true, // Different from full address
  },
  {
    name: 'Falls back to compact address - data source',
    instance: {
      address: 'data.aws_ami.ubuntu',
      provider: 'registry.terraform.io/hashicorp/aws',
      type: 'aws_ami',
      attributes: {},
    },
    expectedDisplayName: 'ubuntu',
    shouldHaveCustomName: true, // Different from full address
  },
  {
    name: 'Prefers tags.Name over attributes.name',
    instance: {
      address: 'aws_instance.web',
      provider: 'registry.terraform.io/hashicorp/aws',
      type: 'aws_instance',
      attributes: {
        name: 'generic-name',
        tags: {
          Name: 'Tagged Name',
        },
      },
    },
    expectedDisplayName: 'Tagged Name',
    shouldHaveCustomName: true,
  },
  {
    name: 'Prefers tags.Name over provider field',
    instance: {
      address: 'aws_s3_bucket.data',
      provider: 'registry.terraform.io/hashicorp/aws',
      type: 'aws_s3_bucket',
      attributes: {
        bucket: 'bucket-name',
        tags: {
          Name: 'My Bucket',
        },
      },
    },
    expectedDisplayName: 'My Bucket',
    shouldHaveCustomName: true,
  },
  {
    name: 'Trims whitespace from tags.Name',
    instance: {
      address: 'aws_instance.web',
      provider: 'registry.terraform.io/hashicorp/aws',
      type: 'aws_instance',
      attributes: {
        tags: {
          Name: '  Padded Name  ',
        },
      },
    },
    expectedDisplayName: 'Padded Name',
    shouldHaveCustomName: true,
  },
  {
    name: 'Ignores empty tags.Name',
    instance: {
      address: 'aws_instance.web',
      provider: 'registry.terraform.io/hashicorp/aws',
      type: 'aws_instance',
      attributes: {
        tags: {
          Name: '   ',
        },
      },
    },
    expectedDisplayName: 'web',
    shouldHaveCustomName: true, // "web" differs from "aws_instance.web"
  },
  {
    name: 'Handles missing attributes',
    instance: {
      address: 'aws_instance.test',
      provider: 'registry.terraform.io/hashicorp/aws',
      type: 'aws_instance',
    },
    expectedDisplayName: 'test',
    shouldHaveCustomName: true, // "test" differs from "aws_instance.test"
  },
  {
    name: 'Handles empty address',
    instance: {
      address: '',
      provider: 'registry.terraform.io/hashicorp/aws',
      type: 'aws_instance',
      attributes: {},
    },
    expectedDisplayName: '—',
    shouldHaveCustomName: true, // Because it's not the same as the (empty) address
  },
  {
    name: 'Google Cloud - compute instance',
    instance: {
      address: 'google_compute_instance.app',
      provider: 'google',
      type: 'google_compute_instance',
      attributes: {
        name: 'production-app-server',
      },
    },
    expectedDisplayName: 'production-app-server',
    shouldHaveCustomName: true,
  },
  {
    name: 'Azure - virtual machine',
    instance: {
      address: 'azurerm_virtual_machine.web',
      provider: 'azurerm',
      type: 'azurerm_virtual_machine',
      attributes: {
        name: 'web-vm-01',
      },
    },
    expectedDisplayName: 'web-vm-01',
    shouldHaveCustomName: true,
  },
  {
    name: 'Kubernetes - deployment with nested name',
    instance: {
      address: 'kubernetes_deployment.api',
      provider: 'kubernetes',
      type: 'kubernetes_deployment',
      attributes: {
        metadata: [
          {
            name: 'api-deployment',
          },
        ],
      },
    },
    expectedDisplayName: 'api-deployment',
    shouldHaveCustomName: true,
  },
  {
    name: 'Complex module path with count',
    instance: {
      address: 'module.eks.module.node_groups.aws_launch_template.workers[0]',
      provider: 'registry.terraform.io/hashicorp/aws',
      type: 'aws_launch_template',
      attributes: {},
    },
    expectedDisplayName: 'workers',
    shouldHaveCustomName: true, // "workers" differs from full address
  },
];

// Run all tests
testCases.forEach((test) => {
  try {
    const displayName = getInstanceDisplayName(test.instance as Instance);
    const nameMatches = displayName === test.expectedDisplayName;

    let customNameMatches = true;
    if (test.shouldHaveCustomName !== undefined) {
      const hasCustom = hasCustomDisplayName(test.instance as Instance);
      customNameMatches = hasCustom === test.shouldHaveCustomName;
    }

    if (nameMatches && customNameMatches) {
      console.log(`✅ PASS: ${test.name}`);
      console.log(`   Display name: "${displayName}"`);
      passed++;
    } else {
      console.log(`❌ FAIL: ${test.name}`);
      if (!nameMatches) {
        console.log(`   Expected: "${test.expectedDisplayName}"`);
        console.log(`   Got: "${displayName}"`);
      }
      if (!customNameMatches) {
        console.log(`   Custom name check failed`);
        console.log(`   Expected hasCustomDisplayName: ${test.shouldHaveCustomName}`);
        console.log(`   Got: ${hasCustomDisplayName(test.instance as Instance)}`);
      }
      failed++;
    }
  } catch (error) {
    console.log(`❌ FAIL: ${test.name} (threw error: ${error})`);
    failed++;
  }
});

console.log('\n' + '='.repeat(60));
console.log(`\n📊 Results: ${passed} passed, ${failed} failed out of ${testCases.length} tests`);

if (failed === 0) {
  console.log('\n🎉 All display name tests passed!');
  console.log('\n✅ Features verified:');
  console.log('   • Priority order: tags.Name > attributes.name > provider fields > compact address');
  console.log('   • AWS resource types (S3, RDS, Lambda, EC2, etc.)');
  console.log('   • Google Cloud resource types');
  console.log('   • Azure resource types');
  console.log('   • Kubernetes resources with nested metadata');
  console.log('   • Module path stripping');
  console.log('   • Array index removal');
  console.log('   • Data source handling');
  console.log('   • Whitespace trimming');
  console.log('   • Empty/missing attribute handling');
  console.log('   • Custom name detection');
}

process.exit(failed > 0 ? 1 : 0);
