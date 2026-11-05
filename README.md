<p align="center">
  <a href="https://stategraph.com">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/stategraph/brand-artifacts/c6f63a114680a786452b2f28af87637c66c3ec10/logos/wordmark/stategraph_logo_wordmark_white.svg">
      <img alt="Stategraph" src="https://raw.githubusercontent.com/stategraph/brand-artifacts/c6f63a114680a786452b2f28af87637c66c3ec10/logos/wordmark/stategraph_logo_wordmark_black.svg" width="400">
    </picture>
  </a>
</p>

<h3 align="center">Terraform without the state file bottleneck</h3>

<p align="center">
  Terraform and OpenTofu from pull requests, with state stored as a dependency graph in PostgreSQL.<br>
  Plans read only what a change touches. Changes that do not overlap run at the same time.
</p>

<p align="center">
  <a href="https://stategraph.com">Website</a> ·
  <a href="https://stategraph.com/docs">Docs</a> ·
  <a href="https://stategraph.com/blog">Blog</a> ·
  <a href="https://stategraph.com/slack">Slack</a>
</p>

<p align="center">
  <a href="https://github.com/stategraph/stategraph/stargazers"><img alt="GitHub Stars" src="https://img.shields.io/github/stars/stategraph/stategraph"></a>
  <a href="https://github.com/stategraph/releases/releases"><img alt="Latest Release" src="https://img.shields.io/github/v/release/stategraph/releases?color=%239F50DA"></a>
  <a href="https://stategraph.com/slack"><img alt="Join our Slack" src="https://img.shields.io/badge/slack-join%20chat-blue"></a>
  <a href="https://ocaml.org"><img alt="OCaml" src="https://img.shields.io/badge/OCaml-EC6813?logo=ocaml&logoColor=fff"></a>
  <a href="https://opensource.org/licenses/MPL-2.0"><img alt="License: MPL-2.0" src="https://img.shields.io/badge/License-MPL--2.0-blue.svg"></a>
</p>

---

## What is Stategraph?

Stategraph runs Terraform and OpenTofu from pull requests, and can store your state as a graph in PostgreSQL instead of a state file. It has two parts:

* **Stategraph Orchestration**: plans every pull request on GitHub or GitLab and posts the result as a comment. Policy checks, cost estimates, and approvals run in the review. The apply runs on merge or on a comment. Open source and self-hostable.
* **Stategraph Infrastructure as a Database**: stores each state as a dependency graph in PostgreSQL. A plan reads only the resources your change reaches, changes that touch different resources apply at the same time, and you can query every state with SQL. Works from the CLI with any CI; no VCS provider required.

Each part works without the other. You can start with Orchestration against your existing state backend and move the state into the database later.

<div align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/stategraph-platform-dark.svg">
    <img
      src="assets/stategraph-platform-light.svg"
      alt="The Stategraph platform: pull requests, the CLI, the API, and AI agents connect to the Stategraph server, where Orchestration runs on top of Infrastructure as a Database. Together they power policy, remote execution, inventory, cost, security, and compliance."
      width="800"
      loading="lazy"
    >
  </picture>
</div>

## Ship from the pull request

Open source, MPL-2.0 · GitHub and GitLab

Orchestration plans each pull request and posts the plan as a comment. The apply runs on a `stategraph apply` comment or on merge.

* **Plan on every pull request**, posted as a comment
* **Apply from the pull request**, with approvals routed by CODEOWNERS
* **Policy checks** with OPA/Rego, Conftest, and Checkov before an apply
* **Cost estimates** in the pull request, with thresholds that require another approval
* **Dependency-aware runs**: layers and stacks run in dependency order, in parallel where they can
* **Drift detection** on a schedule, scoped by a tag query, and reconciled on request
* **Tag-based configuration** for 10 or 10,000 workspaces, in a monorepo or across repositories
* **Terraform, OpenTofu, Terragrunt, CDKTF, and Pulumi**

Runs on GitHub and GitLab. Configure it in `.stategraph/config.yml`. See the [Orchestration docs](https://stategraph.com/docs/orchestration).

## Drop the global lock

With a state file, every write locks the whole file. Infrastructure as a Database stores each state as a graph of resources and dependencies in PostgreSQL, and locks only the resources a change touches.

**Dynamic state sizing.** A plan walks only the subgraph your change reaches, not the whole state. Work scales with the size of your change, not the size of your state.

**Concurrent changes.** Each plan and apply is a transaction that locks the resources it changes. Changes that do not overlap apply at the same time. Changes that overlap are rejected at commit.

<div align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/subgraph-execution-dark.svg">
    <img
      src="assets/subgraph-execution-light.svg"
      alt="Animation comparing serial execution behind a global lock with Stategraph's subgraph execution, where independent resources apply in parallel"
      width="800"
    >
  </picture>
</div>

**SQL across every state.** JOINs, CTEs, and blast radius, from the console, the CLI, or the API.

```console
$ stategraph query "SELECT type, count(*) FROM resources GROUP BY type"
 aws_instance         20
 aws_security_group   15
 aws_subnet            6
```

Every plan and apply is recorded as a transaction, with its logs. A change that reaches several states applies as one transaction with `stategraph tf mtx`.

**One graph at any size.** You never split a state to make it faster.

## Built for agents

Skills teach any AI agent the Stategraph workflows: query, plan and apply, import, refactor, cost, and security.

```console
$ npx skills add stategraph/skills
```

With Infrastructure as a Database, an agent's access token grants plan and apply separately, down to a single resource. Every action the agent takes is a transaction on the timeline. A model can ignore a prompt. It cannot use a capability that its token does not grant.

## Terraform vs. Stategraph

| | Terraform | Stategraph |
|---|---|---|
| Language | HCL | HCL, with the same modules and providers |
| State | A file behind a global lock | A dependency graph in PostgreSQL, with history |
| Plan | The whole file, every time | Only what your change touches |
| Changes in flight | One | As many as do not overlap |
| Across states | In sequence, by hand | One atomic transaction |
| Questions | grep a JSON file | SQL across everything |
| Workflow | Bring your own CI | Pull-request orchestration built in |
| AI agents | Blanket credentials | Skills and scoped tokens |

## Get started

### Stategraph Orchestration

**Hosted:** [Start free](https://app.stategraph.cloud). Connects to GitHub or GitLab; plan limits are on the [pricing](https://stategraph.com/pricing) page.

**Self-hosted (Open Source):** the `ghcr.io/stategraph/stategraph-server-oss` image.

```bash
git clone https://github.com/stategraph/stategraph
cd stategraph/docker/stategraph
docker compose up -d
# then open http://localhost:8080 and create the first account
```

The open-source build runs Orchestration. To connect GitHub or GitLab, with your own public URL or with Terratunnel, follow the [self-hosted Open Source quickstart](https://stategraph.com/docs/get-started/quickstart/self-hosted-open-source).

### Stategraph Infrastructure as a Database

You need a running Stategraph server first. Pick one:

**Hosted:** [Stategraph Cloud](https://app.stategraph.cloud). We run the server.

**Self-hosted:** the Enterprise build, with a license key, on your PostgreSQL, deployed with Docker Compose, Kubernetes, ECS, or Cloud Run. See [Self-hosting](https://stategraph.com/docs/admin/self-hosting).

**BYOC:** we operate Stategraph inside your AWS, GCP, or Azure account. [Contact us](https://stategraph.com/contact).

Then install the CLI and point it at your server:

```bash
curl -sSL https://get.stategraph.com/install.sh | sh

export STATEGRAPH_API_BASE="https://your-server.example.com"
export STATEGRAPH_API_KEY="<your-api-key>"        # console: Settings → API Keys
export STATEGRAPH_TENANT_ID="<your-tenant-id>"    # shown in stategraph info

stategraph info                     # confirm the connection
```

Then import a state:

```bash
terraform state pull > terraform.tfstate
stategraph import tf --name networking terraform.tfstate
stategraph plan                     # plan against the imported state
```

* **Your Terraform, unmodified**: Stategraph runs the Terraform or OpenTofu binary you already use. No provider changes, no HCL edits; `terraform plan`/`apply` becomes `stategraph plan`/`apply`.
* **No VCS provider required**: the CLI talks to the server directly. Use it with Orchestration, with your existing CI, or from your laptop.
* **Credentials stay with you**: the CLI runs Terraform where you run it. The server stores state; it never runs Terraform and never sees your cloud.
* **Reversible**: `stategraph states export` writes a standard `terraform.tfstate` back out.

The full walkthrough, including exploring what you imported, is in the [quickstart](https://stategraph.com/docs/get-started/quickstart/import-state).

## Learn more

* [Quickstart](https://stategraph.com/docs/get-started/quickstart): Stategraph Cloud, self-hosted, or import your state
* [Core concepts](https://stategraph.com/docs/get-started/core-concepts): states, transactions, and the graph
* [Orchestration docs](https://stategraph.com/docs/orchestration): PR workflows, policy, cost, drift
* [CLI reference](https://stategraph.com/docs/cli): every command
* [Editions and pricing](https://stategraph.com/docs/get-started/editions): Open Source, Enterprise, Infrastructure as a Database, and the [Stategraph Cloud plans](https://stategraph.com/pricing)

## Community

* [Slack](https://stategraph.com/slack): chat with the team and other users
* [GitHub Discussions](https://github.com/orgs/stategraph/discussions): questions and ideas
* [GitHub Issues](https://github.com/stategraph/stategraph/issues): bugs and feature requests

## Contributing

We welcome contributions! See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

The code in this repository is [MPL-2.0](LICENSE) licensed.

Stategraph Infrastructure as a Database is commercial software, available in the hosted service or self-hosted with a license key. Stategraph Orchestration is open source, with enterprise features (RBAC, centralized configuration, advanced approval workflows) available in the hosted service and the self-hosted Enterprise Edition. Hosted plan limits are on the [pricing](https://stategraph.com/pricing) page.
