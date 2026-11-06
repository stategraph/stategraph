---
title: How it works
description: Follow a change through Stategraph: the pull request flow in Orchestration, how Infrastructure as a Database runs it, and where each part runs.
order: 2
---


Stategraph runs a change to your cloud in one of two ways: Orchestration runs it from a pull request, and the `stategraph` CLI runs it with Infrastructure as a Database.

## The pull request flow

<figure class="docs-figure">
<div class="yt-lite" data-id="AEWnITtgLhA">
<button type="button" aria-label="Play the video: Stategraph Orchestration, how it works" onclick="var b=this.closest('.yt-lite'),f=document.createElement('iframe');f.src='https://www.youtube-nocookie.com/embed/'+b.dataset.id+'?autoplay=1&amp;rel=0&amp;iv_load_policy=3&amp;cc_load_policy=0&amp;playsinline=1&amp;color=white';f.title=this.getAttribute('aria-label');f.allow='accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture';f.allowFullscreen=true;b.replaceChildren(f);"><span class="yt-poster"><span class="yt-poster-kicker">Video &middot; 4 min</span><span class="yt-poster-title">Stategraph Orchestration, how it works</span></span><span class="yt-play" aria-hidden="true"></span></button>
</div>
<figcaption>Orchestration in 4 minutes. <a href="https://youtu.be/AEWnITtgLhA">Watch on YouTube</a>.</figcaption>
</figure>

1. You open, update, or comment on a pull request.
2. Orchestration finds the directories that the change touches. You can set [which files count](/docs/reference/orchestration/configuration/when-modified).
3. Your CI runner plans each directory, as if the pull request were merged.
4. Orchestration posts the plan on the pull request.
5. Your [policy checks](/docs/orchestration/external-tools/opa) and a cost estimate run with the plan. A failed check can [block the apply](/docs/orchestration/governance/gatekeeper) until someone approves it.
6. You comment `stategraph apply`, or you merge, if you turned on [apply after merge](/docs/orchestration/workflows/apply-after-merge).
7. Orchestration applies the plan that you reviewed, and [locks](/docs/orchestration/workflows/advanced/lock-management) those directories until the pull request merges.

- If another pull request changes the same directories first, the apply stops and asks for a new plan.
- Before a `stategraph apply` runs, [your rules](/docs/reference/orchestration/configuration/apply-requirements) must pass, for example approvals.
- With Enterprise, you can also [control who can run each command](/docs/reference/orchestration/configuration/access-control).

## Infrastructure as a Database

<figure class="docs-figure">
<div class="yt-lite" data-id="LBTpPQHlDZo">
<button type="button" aria-label="Play the video: Stategraph, how it works" onclick="var b=this.closest('.yt-lite'),f=document.createElement('iframe');f.src='https://www.youtube-nocookie.com/embed/'+b.dataset.id+'?autoplay=1&amp;rel=0&amp;iv_load_policy=3&amp;cc_load_policy=0&amp;playsinline=1&amp;color=white';f.title=this.getAttribute('aria-label');f.allow='accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture';f.allowFullscreen=true;b.replaceChildren(f);"><span class="yt-poster"><span class="yt-poster-kicker">Video &middot; 3 min</span><span class="yt-poster-title">Infrastructure as a Database, how it works</span></span><span class="yt-play" aria-hidden="true"></span></button>
</div>
<figcaption>Infrastructure as a Database in 3 minutes. <a href="https://youtu.be/LBTpPQHlDZo">Watch on YouTube</a>.</figcaption>
</figure>

1. You run `stategraph plan` or `stategraph apply`. In a pull request, [Orchestration can do this for you](/docs/infrastructure-as-a-database/orchestration).
2. The CLI sends your Terraform code and the change to the server.
3. The server records the change and returns only the code that the change needs: the changed resources, what they depend on, and what depends on them.
4. The CLI runs Terraform or OpenTofu on it, with your local credentials, and reports the result to the server.
5. The CLI shows the diff, the errors, or a summary.

- The server keeps your state as a graph in PostgreSQL. It does not run your plans and applies.
- Stategraph [locks single resources](/docs/infrastructure-as-a-database/resource-locking), not the whole state. Changes to different resources run at the same time. If two changes touch the same resource, the later one fails.

## Where each part runs

- Stategraph runs on Stategraph Cloud, or on your own Docker Compose, Kubernetes, Amazon ECS, or Google Cloud Run deployment: see [Self-hosting](/docs/admin/self-hosting). It stores your states, transactions, users, and tenants, and serves the console and the API. The open-source edition runs Orchestration: see [Self-hosted](/docs/get-started/quickstart/self-hosted).
- Plans and applies run on your GitHub Actions or GitLab CI runners. The `stategraph` CLI runs there or on your machine.
- With Orchestration, you can query runs, pull requests, drift schedules, and more with SQL in your tenant.

## Next steps

- [Core concepts](/docs/get-started/core-concepts): the vocabulary.
- [Workflows](/docs/orchestration/workflows): pull request triggers.
- [Self-hosting](/docs/admin/self-hosting): run Stategraph yourself.
- [Enable Orchestration](/docs/admin/self-hosting/orchestration): GitHub App, GitLab, webhook secret, and databases.
- [Infrastructure as a Database](/docs/infrastructure-as-a-database): transactions, locking, and multi-state transactions.
- [Use with Orchestration](/docs/infrastructure-as-a-database/orchestration): pull request runs with Infrastructure as a Database.
