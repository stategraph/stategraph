# Getting started surfaces

Hermes has two setup flows and one page that reports on both.

## Get started

`app/(console)/getting-started/page.tsx` renders the orchestration flow at `/getting-started` inside `SetupShell`; `?path=github` and `?path=gitlab` render the provider connect flows.

`contexts/SetupProgressContext.tsx` loads the facts every setup surface reads (the Home welcome panel, the first-run redirect, the Done steps) once per tenant. `lib/getting-started/setup-progress.ts` turns them into a status per setup and owns the setup routes and copy. `lib/getting-started/start-intent.ts` reads the `?start=` parameter the website may add to the landing URL. `lib/getting-started/first-run.ts` remembers, per tenant and browser, that the user was sent into setup once; after that Home stays Home.

## Repository orchestration

`app/(console)/getting-started/OrchestrateFlow.tsx` renders the steps: Install, Repository, then either the own-repository path (Workflow file, Credentials, Pull request, Done) or the example path (Fork, Enable Actions, First change, Done). `orchestrationSteps.tsx` holds the step components both providers share. `ConnectGithub.tsx` is the GitHub App install and claim flow; `ConnectGitlab.tsx` is the GitLab group, token, webhook, CI/CD role and pipeline flow, with its own example path.

`lib/getting-started/orchestration-state.ts` owns the step ids, the rails per provider and path, and tenant-scoped persistence under `stategraph-orchestration-onboarding:<tenantId>`. URL values for `step`, `repo` and `provider` take precedence over stored values. The example path carries `demo=kick-the-tires` so it stays correct when browser storage is unavailable. This state never reads or clears the state-import wizard key.

`lib/getting-started/orchestration-constants.ts` owns the displayed copy, documentation links, and the canonical GitHub Actions workflow body. Its test checks the workflow body against the workflow path and dispatch inputs the GitHub engine uses.

## State import

`app/(console)/migrate-stategraph/page.tsx` hosts the state-import wizard inside `SetupShell`: API key, Configure CLI, Import, Verify, then Orchestration when the tenant has a linked VCS installation, then Done. `?step=orchestration` opens the Orchestration step directly. `?from=orchestrate` gives the first step a Back button to `/getting-started?path=orchestrate`.

`lib/getting-started/wizard-state.ts` owns the step list and persists the position under `stategraph-getting-started`. The API key and the engine-step result stay in memory for the session.

The step components in this directory render the flow. `doc-constants.ts` is the source for commands, the runner secret names, the engine config snippets and documentation-derived copy used by those steps.

## Shared components

`SetupShell.tsx` is the column a setup flow renders in: wider than a console page, inside the normal console chrome.

`WizardShell.tsx` accepts generic step ids, labels, the current step, and a reset callback. Both flows use the same progress treatment without sharing state.

`CodeBlock.tsx` renders copyable command or YAML text.
