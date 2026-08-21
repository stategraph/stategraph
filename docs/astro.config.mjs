import { defineConfig } from "astro/config";
import starlight from "@astrojs/starlight";
import starlightImageZoom from "starlight-image-zoom";

export default defineConfig({
  vite: {
    define: {
      'process.env.NODE_ENV': JSON.stringify(process.env.NODE_ENV)
    }
  },
  site: 'https://docs.terrateam.io',
  integrations: [
    starlight({
      title: "Terrateam",
      components: {
        SiteTitle: './src/components/SiteTitle.astro',
      },
      plugins: [starlightImageZoom()],
      description: "Terraform and OpenTofu automation on GitHub",
      logo: {
        src: "/src/assets/logo-wordmark.svg",
        replacesTitle: true,
      },
      head: [
        // Only add this script in production environment (vercel env var)
        ...(process.env.NODE_ENV === 'production'
          ? [
              {
                tag: 'script',
                attrs: {
                  src: '/ph-init.js', // Initialize PostHog
                  defer: true,
                },
              },
            ]
          : []
        ),
      ],
      social: [
        {
          icon: "github",
          label: "GitHub",
          href: "https://github.com/stategraph/stategraph",
        },
      ],
      customCss: process.env.NO_GRADIENTS
        ? []
        : [
            "/src/assets/docs.css",
            "@fontsource/roboto",
            "/src/styles/mermaid.css"  
          ],
      sidebar: [
        {
          label: "Overview",
          items: [
            { label: "Welcome", link: "/overview/" },
            { label: "How It Works", link: "/overview/how-it-works" },
            { label: "Core Concepts", link: "/overview/core-concepts" },
            { label: "Editions", link: "/editions/" },
          ],
        },
        {
          label: "Quickstart",
          items: [
            { label: "Getting Started", link: "/quickstart/" },
            { label: "First Plan & Apply", link: "/quickstart/cloud/first-plan-apply" },
          ],
        },
        {
          label: "Configuration",
          collapsed: true,
          items: [
            { label: "Getting Started", link: "/configuration/" },
            { label: "Modules & Dependencies", link: "/configuration/modules" },
            { label: "Secrets & Variables", link: "/configuration/variables/" },
            { label: "Environment Variables", link: "/configuration/variables/environment-variables" },
          ],
        },
        {
          label: "Workflows",
          collapsed: true,
          items: [
            { label: "PR Workflows", link: "/workflows/pull-request/" },
            { label: "Apply After Merge", link: "/workflows/apply-after-merge" },
            { label: "Rollbacks", link: "/workflows/rollbacks" },
            {
              label: "Advanced Patterns",
              collapsed: true,
              items: [
                { label: "GitFlow", link: "/workflows/advanced/gitflow" },
                { label: "Layered Runs", link: "/workflows/advanced/layered-runs" },
                { label: "Dynamic Config", link: "/workflows/advanced/dynamic-configuration" },
                { label: "Terragrunt Config Builder", link: "/workflows/advanced/terragrunt-config-builder" },
                { label: "Custom Workflows", link: "/workflows/advanced/custom-commands" },
                { label: "Custom Runners", link: "/workflows/advanced/runs-on" },
                { label: "Engine Setup", link: "/workflows/advanced/engine-setup" },
                { label: "Tree Builder", link: "/workflows/advanced/tree-builder-setup" },
                { label: "Tag System", link: "/workflows/advanced/tag-system" },
                { label: "Lock Management", link: "/workflows/advanced/lock-management" },
                { label: "Multi-Environment", link: "/workflows/advanced/multi-environment" },
                { label: "Stacks", link: "/workflows/advanced/stacks" },
                { label: "YAML Anchors", link: "/workflows/advanced/yaml-anchors" },
                { label: "GitHub Reusable Workflows", link: "/workflows/advanced/github-reusable-workflows" },
              ],
            },
          ],
        },
        {
          label: "Integrations",
          collapsed: true,
          items: [
            {
              label: "Cloud Providers",
              collapsed: true,
              items: [
                {
                  label: "AWS",
                  collapsed: true,
                  items: [
                    { autogenerate: { directory: "integrations/cloud-providers/aws" } },
                  ],
                },
                {
                  label: "Google Cloud",
                  collapsed: true,
                  items: [
                    { autogenerate: { directory: "integrations/cloud-providers/gcp" } },
                  ],
                },
                {
                  label: "Azure",
                  collapsed: true,
                  items: [
                    { autogenerate: { directory: "integrations/cloud-providers/azure" } },
                  ],
                },
                { label: "Other", link: "/integrations/cloud-providers/other" },
              ],
            },
            {
              label: "IaC Tools",
              collapsed: true,
              items: [
                { label: "Terraform", link: "/integrations/iac-tools/terraform" },
                { label: "OpenTofu", link: "/integrations/iac-tools/opentofu" },
                { label: "Terragrunt", link: "/integrations/iac-tools/terragrunt" },
                { label: "Pulumi", link: "/integrations/iac-tools/pulumi" },
                { label: "CDK for Terraform", link: "/integrations/iac-tools/cdktf" },
                { label: "Stategraph", link: "/integrations/iac-tools/stategraph" },
                { label: "Migrate from Terraform Cloud", link: "/integrations/iac-tools/terraform-cloud-migration" },
              ],
            },
            {
              label: "External Tools",
              collapsed: true,
              items: [
                { label: "Cost Estimation", link: "/integrations/external-tools/infracost" },
                { label: "OPA Policies", link: "/integrations/external-tools/opa" },
                { label: "Checkov Scanning", link: "/integrations/external-tools/checkov" },
                { label: "Webhooks", link: "/integrations/external-tools/webhooks" },
                { label: "AI Integrations", link: "/integrations/external-tools/ai-integrations" },
                { label: "Resourcely", link: "/integrations/external-tools/resourcely" },
                { label: "Installing Packages", link: "/integrations/external-tools/installing-packages" },
              ],
            },
          ],
        },
        {
          label: "Security & Governance",
          collapsed: true,
          items: [
            {
              label: "Security",
              collapsed: true,
              items: [
                { label: "Best Practices", link: "/security/best-practices" },
                { label: "Audit Trail", link: "/security/audit-trail" },
                { label: "Cloud Credentials", link: "/security/cloud-credentials" },
                { label: "Hardening AWS OIDC", link: "/security/hardening-aws-oidc" },
                { label: "Plan File Storage", link: "/security/plan-file-storage" },
                { label: "GitHub Environments", link: "/integrations/external-tools/github-environments" },
                { label: "Private Runners", link: "/security/private-runners" },
                { label: "Self-Signed Certs", link: "/security/self-signed-certificates" },
              ],
            },
            {
              label: "Governance",
              collapsed: true,
              items: [
                { label: "RBAC", link: "/governance/rbac" },
                { label: "CODEOWNERS Integration", link: "/configuration/access-control/codeowners" },
                { label: "Drift Detection", link: "/governance/drift-detection" },
                { label: "Gatekeeper", link: "/governance/gatekeeper" },
                { label: "Centralized Config", link: "/governance/centralized-config" },
                { label: "Config Overrides", link: "/governance/config-overrides" },
              ],
            },
          ],
        },
        {
          label: "Self-Hosted",
          collapsed: true,
          items: [
            { label: "Getting Started", link: "/quickstart/self-hosted/" },
            { label: "Docker Compose", link: "/quickstart/self-hosted/docker-compose" },
            { label: "Kubernetes", link: "/quickstart/self-hosted/kubernetes" },
            { label: "AWS ECS", link: "/quickstart/self-hosted/aws" },
            { label: "Environment Variables", link: "/self-hosted/environment-variables" },
            { label: "Observability and Metrics", link: "/self-hosted/observability-metrics" },
          ],
        },
        {
          label: "Reference",
          collapsed: true,
          items: [
            {
              label: "API Reference",
              collapsed: true,
              items: [
                { label: "Overview", link: "/reference/api/" },
                { label: "GitHub Installations", link: "/reference/api/github-installations" },
                { label: "GitLab Installations", link: "/reference/api/gitlab-installations" },
                { label: "Access Tokens", link: "/reference/api/access-tokens" },
                { label: "Key-Value Store", link: "/reference/api/kv-store" },
                { label: "Authentication", link: "/reference/api/authentication" },
                { label: "Stacks", link: "/reference/api/stacks" },
                { label: "System & Admin", link: "/reference/api/system-admin" },
              ],
            },
            {
              label: "Commands",
              collapsed: true,
              items: [
                { label: "plan", link: "/reference/commands/plan" },
                { label: "apply", link: "/reference/commands/apply" },
                { label: "apply-force", link: "/reference/commands/apply-force" },
                { label: "apply-autoapprove", link: "/reference/commands/apply-autoapprove" },
                { label: "unlock", link: "/reference/commands/unlock" },
                { label: "gate approve", link: "/reference/commands/gate-approve" },
                { label: "repo-config", link: "/reference/commands/repo-config" },
                { label: "feedback", link: "/reference/commands/feedback" },
                { label: "help", link: "/reference/commands/help" },
              ],
            },
            {
              label: "Configuration Reference",
              collapsed: true,
              items: [
                { label: "access-control", link: "/reference/configuration/access-control" },
                { label: "apply-requirements", link: "/reference/configuration/apply-requirements" },
                { label: "automerge", link: "/reference/configuration/automerge" },
                { label: "batch-runs", link: "/reference/configuration/batch-runs" },
                { label: "config-builder", link: "/reference/configuration/config-builder" },
                { label: "cost-estimation", link: "/reference/configuration/cost-estimation" },
                { label: "default-branch-overrides", link: "/reference/configuration/default-branch-overrides" },
                { label: "definitions", link: "/reference/configuration/definitions" },
                { label: "destination-branches", link: "/reference/configuration/destination-branches" },
                { label: "dirs", link: "/reference/configuration/dirs" },
                { label: "drift", link: "/reference/configuration/drift" },
                { label: "enabled", link: "/reference/configuration/enabled" },
                { label: "engine", link: "/reference/configuration/engine" },
                { label: "hooks", link: "/reference/configuration/hooks" },
                { label: "ignore-patterns", link: "/reference/configuration/ignore-patterns" },
                { label: "indexer", link: "/reference/configuration/indexer" },
                { label: "lock-policy", link: "/reference/configuration/lock-policy" },
                { label: "notifications", link: "/reference/configuration/notifications" },
                { label: "parallel-runs", link: "/reference/configuration/parallel-runs" },
                { label: "stacks", link: "/reference/configuration/stacks" },
                { label: "storage", link: "/reference/configuration/storage" },
                { label: "tag-queries", link: "/reference/configuration/tag-queries" },
                { label: "tags", link: "/reference/configuration/tags" },
                { label: "tree-builder", link: "/reference/configuration/tree-builder" },
                { label: "version", link: "/reference/configuration/version" },
                { label: "when-modified", link: "/reference/configuration/when-modified" },
                { label: "workflows", link: "/reference/configuration/workflows" },
              ],
            },
          ],
        },
        {
          label: "Company",
          collapsed: true,
          items: [
            { label: "Billing", link: "/billing" },
          ],
        },
      ],
    }),
  ],
  markdown: {
    rehypePlugins: []
  },
  redirects: {
    // Root redirect
    '/': '/overview/',
    // Main section redirects
    '/cloud-providers': '/integrations/cloud-providers/aws/',
    '/integrations': '/integrations/cloud-providers/aws/',
    '/self-hosted': '/quickstart/self-hosted/',
    // Old structure redirects
    '/how-it-works': '/overview/how-it-works',
    '/quickstart-guide': '/quickstart/',
    '/getting-started/quickstart-guide': '/quickstart/',
    '/getting-started/concepts': '/overview/core-concepts',
    '/getting-started/configuration': '/configuration/',
    '/getting-started/plan-and-apply': '/quickstart/cloud/first-plan-apply',
    '/getting-started/pull-requests-and-triggers': '/workflows/pull-request/',
    '/getting-started/secrets-and-variables': '/configuration/variables/',
    '/getting-started/tag-queries': '/reference/configuration/tag-queries',
    
    // Cloud providers
    '/cloud-providers/aws': '/integrations/cloud-providers/aws/',
    '/cloud-providers/gcp': '/integrations/cloud-providers/gcp/',
    '/cloud-providers/azure': '/integrations/cloud-providers/azure/',
    '/cloud-providers/other': '/integrations/cloud-providers/other',
    '/cloud-provider-setup/aws': '/integrations/cloud-providers/aws/',
    '/cloud-provider-setup/gcp': '/integrations/cloud-providers/gcp/',
    '/cloud-provider-setup/azure': '/integrations/cloud-providers/azure/',
    '/cloud-provider-setup/other': '/integrations/cloud-providers/other',
    
    // Security and compliance
    '/security-and-compliance/plan-and-apply-permissions': '/governance/rbac',
    '/security-and-compliance/role-based-access-control': '/governance/rbac',
    '/security-and-compliance/best-practices': '/security/best-practices',
    '/security-and-compliance/audit-trail': '/security/audit-trail',
    '/security-and-compliance/apply-requirements-and-overrides': '/reference/configuration/apply-requirements',
    '/security-and-compliance/policy-enforcement-with-opa': '/integrations/external-tools/opa',
    '/security-and-compliance/private-runners': '/security/private-runners',
    '/security-and-compliance/rollbacks': '/workflows/rollbacks',
    '/security-and-compliance/scan-plans-with-checkov': '/integrations/external-tools/checkov',
    '/security-and-compliance/self-signed-certificates': '/security/self-signed-certificates',
    '/advanced-workflows/multiple-environments': '/workflows/advanced/multi-environment',
    
    // Self-hosted
    '/self-hosted/getting-started': '/quickstart/self-hosted/',
    '/self-hosted/docker-compose': '/quickstart/self-hosted/docker-compose',
    '/self-hosted/kubernetes': '/quickstart/self-hosted/kubernetes',
    '/self-hosted/aws': '/quickstart/self-hosted/aws',
    '/self-hosted/instructions': '/quickstart/self-hosted/',
    '/self-hosted/editions': '/editions/',

    // Top-level marketing-site landing redirects
    '/gitops': '/overview/how-it-works',
    '/workflows': '/workflows/pull-request/',
    '/scale': '/workflows/advanced/multi-environment',
    '/security': '/security/best-practices',
    
    // Configuration references
    '/configuration-reference/access-control': '/reference/configuration/access-control',
    '/configuration-reference/apply-requirements': '/reference/configuration/apply-requirements',
    '/configuration-reference/workflows': '/reference/configuration/workflows',
    '/configuration-reference/hooks': '/reference/configuration/hooks',
    '/configuration-reference/dirs': '/reference/configuration/dirs',
    '/configuration-reference/indexer': '/reference/configuration/indexer',
    '/configuration-reference/engine': '/reference/configuration/engine',
    '/configuration-reference/when-modified': '/reference/configuration/when-modified',
    '/configuration-reference/storage': '/reference/configuration/storage',
    '/configuration-reference/drift': '/reference/configuration/drift',
    '/configuration-reference/automerge': '/reference/configuration/automerge',
    '/configuration-reference/batch-runs': '/reference/configuration/batch-runs',
    '/configuration-reference/config-builder': '/reference/configuration/config-builder',
    '/configuration-reference/cost-estimation': '/reference/configuration/cost-estimation',
    '/configuration-reference/default-branch-overrides': '/reference/configuration/default-branch-overrides',
    '/configuration-reference/destination-branches': '/reference/configuration/destination-branches',
    '/configuration-reference/enabled': '/reference/configuration/enabled',
    '/configuration-reference/notifications': '/reference/configuration/notifications',
    '/configuration-reference/parallel-runs': '/reference/configuration/parallel-runs',
    '/configuration-reference/tags': '/reference/configuration/tags',
    '/configuration-reference/tree-builder': '/reference/configuration/tree-builder',
    '/configuration-reference/version': '/reference/configuration/version',
    
    // Advanced workflows
    '/advanced-workflows/drift-detection': '/governance/drift-detection',
    '/advanced-workflows/apply-after-merge': '/workflows/apply-after-merge',
    '/advanced-workflows/gitflow': '/workflows/advanced/gitflow',
    '/advanced-workflows/tags': '/workflows/advanced/tag-system',
    '/advanced-workflows/centralized-configuration': '/governance/centralized-config',
    '/advanced-workflows/cloud-credentials': '/security/cloud-credentials',
    '/advanced-workflows/codeowners-enforcement': '/configuration/access-control/codeowners',
    '/advanced-workflows/custom-plan-and-apply': '/workflows/advanced/custom-commands',
    '/advanced-workflows/dynamic-configuration': '/workflows/advanced/dynamic-configuration',
    '/advanced-workflows/engine': '/workflows/advanced/engine-setup',
    '/advanced-workflows/feature-branch-configuration': '/governance/config-overrides',
    '/advanced-workflows/gatekeeper': '/governance/gatekeeper',
    '/advanced-workflows/github-reusable-workflows': '/workflows/advanced/github-reusable-workflows',
    '/advanced-workflows/ignore-directory': '/reference/configuration/ignore-patterns',
    '/advanced-workflows/layered-runs': '/workflows/advanced/layered-runs',
    '/advanced-workflows/locks-and-concurrency': '/workflows/advanced/lock-management',
    '/advanced-workflows/modules-and-automatic-discovery': '/configuration/modules',
    '/advanced-workflows/runs-on': '/workflows/advanced/runs-on',
    '/advanced-workflows/tree-builder': '/workflows/advanced/tree-builder-setup',
    
    // Command references
    '/command-reference/plan': '/reference/commands/plan',
    '/command-reference/apply': '/reference/commands/apply',
    '/command-reference/apply-force': '/reference/commands/apply-force',
    '/command-reference/apply-autoapprove': '/reference/commands/apply-autoapprove',
    '/command-reference/unlock': '/reference/commands/unlock',
    '/command-reference/feedback': '/reference/commands/feedback',
    
    // Integrations
    '/integrations/cdktf': '/integrations/iac-tools/cdktf',
    '/integrations/cost-estimation': '/integrations/external-tools/infracost',
    '/integrations/environment-variables': '/configuration/variables/environment-variables',
    '/integrations/github-environments': '/integrations/external-tools/github-environments',
    '/integrations/installing-packages': '/integrations/external-tools/installing-packages',
    '/integrations/opentofu': '/integrations/iac-tools/opentofu',
    '/integrations/plan-file-storage': '/security/plan-file-storage',
    '/integrations/pulumi': '/integrations/iac-tools/pulumi',
    '/integrations/resourcely': '/integrations/external-tools/resourcely',
    '/integrations/terraform-versions': '/integrations/iac-tools/terraform',
    '/integrations/terragrunt': '/integrations/iac-tools/terragrunt',
    '/integrations/webhooks': '/integrations/external-tools/webhooks',

    // Guides
    '/guides/migrating-from-terraform-cloud': '/integrations/iac-tools/terraform-cloud-migration',

    // Missing redirects for code references
    '/advanced-workflows/gatekeeper-requirements': '/governance/gatekeeper',
    '/cloud-provider-setup/aws': '/integrations/cloud-providers/aws/',
    '/cloud-provider-setup/gcp': '/integrations/cloud-providers/gcp/',
    '/cloud-provider-setup/azure': '/integrations/cloud-providers/azure/',
    '/cloud-provider-setup/other': '/integrations/cloud-providers/other',
    '/getting-started': '/quickstart/',

    // Missing stacks redirect
    '/configuration-reference/stacks': '/reference/configuration/stacks',
    '/advanced-workflows/stacks': '/workflows/advanced/stacks',
    '/advanced-workflows/yaml-anchors': '/workflows/advanced/yaml-anchors',

    // Company
    '/company/billing': '/billing',
    '/company/support': '/support',
    
    // External links
    '/company/privacy-policy': 'https://terrateam.io/privacy-policy',
    '/company/cookies': 'https://terrateam.io/cookies',
    '/company/terms-of-service': 'https://terrateam.io/terms-of-service',
    '/company/security-and-data': 'https://terrateam.io/security',
  },
});
