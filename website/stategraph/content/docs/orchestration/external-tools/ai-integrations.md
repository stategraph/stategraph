---
title: AI integrations
description: Send plan and apply results from Stategraph Orchestration to an LLM in a post hook and post the summary or error analysis on the pull request.
order: 3
---

An AI integration sends the results of a Stategraph Orchestration plan or apply to an LLM, and posts the response on the pull request. The response can be a change summary, risk flags, or an error diagnosis. Run it from a [hook](/docs/reference/orchestration/configuration/hooks) or a [workflow](/docs/reference/orchestration/configuration/workflows) step, with any LLM API. The examples use Anthropic, OpenAI, and Google.

For AI agents that use Infrastructure as a Database, with skills for queries, plans, imports, refactors, and cost, see [AI agents](/docs/ai).

## How it works

1. When every directory of a plan or apply is complete, Orchestration writes the results to `$TERRATEAM_RESULTS_FILE` as JSON. Then the post hooks run.
2. A post hook script reads the file, takes what it needs, and sends it to an LLM provider.
3. The script prints the LLM response to stdout.
4. With `capture_output: true` and `visible_on: always`, the response goes into the pull request comment.

## Use cases

- Plan summary: what will change, the risks, and the blast radius. Reviewers get a plain-language overview, not raw Terraform output.
- Plan error analysis: the root cause of a failed plan, and fixes. This helps when not every reviewer is a Terraform expert.
- Apply summary: what was deployed, the warnings in the output, and the resources to verify after deployment.
- Apply error analysis: the root cause of a failed apply (partial state, provider errors, permission problems), and remediation steps.
- Security and compliance review: open security groups, public buckets, missing encryption, IAM policies with too many permissions, and similar issues in the plan.

## Configuration

Run AI feedback from hooks or from workflow steps:

| | Hooks | Workflow steps |
|---|---|---|
| Runs | Once, after every directory and workspace | Once per directory and workspace |
| Input | `$TERRATEAM_RESULTS_FILE`, with the aggregated results | The plan file of one directory, in `$TERRATEAM_PLAN_FILE` |
| Best for | One summary comment | Feedback on each directory |
| API calls | One per operation | One per directory and workspace |

### Hooks approach

```yaml
hooks:
  plan:
    post:
      - type: run
        cmd: ['bash', '${TERRATEAM_ROOT}/scripts/ai-feedback.sh']
        capture_output: true
        run_on: always
        visible_on: always
        ignore_errors: true
```

For apply feedback, add the same under `hooks.apply.post`:

```yaml
hooks:
  apply:
    post:
      - type: run
        cmd: ['bash', '${TERRATEAM_ROOT}/scripts/ai-feedback.sh']
        capture_output: true
        run_on: always
        visible_on: always
        ignore_errors: true
```

### Workflow approach

`$TERRATEAM_RESULTS_FILE` is not set in workflow steps. The script builds its own input, for example with `terraform show -json "$TERRATEAM_PLAN_FILE"`, and sends it to the LLM.

```yaml
workflows:
  - tag_query: ""
    plan:
      - type: init
      - type: plan
      - type: run
        cmd: ['bash', '${TERRATEAM_ROOT}/scripts/ai-plan-feedback.sh']
        capture_output: true
        run_on: always
        visible_on: always
        ignore_errors: true
```

## Example scripts

Each script sends `$TERRATEAM_RESULTS_FILE` to an LLM provider from a post hook. The file holds the plan and apply output, success or failure, and the cost estimate, so the script sends it unchanged and the LLM reads it. Save the script as `scripts/ai-feedback.sh` in your repository. For the workflow approach, replace the `RESULTS=$(cat "$TERRATEAM_RESULTS_FILE")` line with `RESULTS=$(terraform show -json "$TERRATEAM_PLAN_FILE")`.

### Anthropic (Claude)

```bash
#!/usr/bin/env bash
set -euo pipefail

# Requires ANTHROPIC_API_KEY as a GitHub secret or GitLab CI/CD variable
RESULTS=$(cat "$TERRATEAM_RESULTS_FILE")

RESPONSE=$(curl -s https://api.anthropic.com/v1/messages \
  -H "content-type: application/json" \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -d "$(jq -n --arg results "$RESULTS" '{
    model: "claude-opus-5",
    max_tokens: 4096,
    system: "You are a Terraform expert. Analyze the following Stategraph results JSON. Summarize the changes, flag any risks or errors, and highlight anything that deserves reviewer attention. Be concise.",
    messages: [{role: "user", content: $results}]
  }')")

echo "$RESPONSE" | jq -r '.content[] | select(.type == "text") | .text'
```

### OpenAI (ChatGPT)

```bash
#!/usr/bin/env bash
set -euo pipefail

# Requires OPENAI_API_KEY as a GitHub secret or GitLab CI/CD variable
RESULTS=$(cat "$TERRATEAM_RESULTS_FILE")

RESPONSE=$(curl -s https://api.openai.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -d "$(jq -n --arg results "$RESULTS" '{
    model: "gpt-4o",
    max_tokens: 1024,
    messages: [
      {role: "system", content: "You are a Terraform expert. Analyze the following Stategraph results JSON. Summarize the changes, flag any risks or errors, and highlight anything that deserves reviewer attention. Be concise."},
      {role: "user", content: $results}
    ]
  }')")

echo "$RESPONSE" | jq -r '.choices[0].message.content'
```

### Google (Gemini)

```bash
#!/usr/bin/env bash
set -euo pipefail

# Requires GOOGLE_API_KEY as a GitHub secret or GitLab CI/CD variable
RESULTS=$(cat "$TERRATEAM_RESULTS_FILE")

RESPONSE=$(curl -s "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$GOOGLE_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg results "$RESULTS" '{
    system_instruction: {parts: [{text: "You are a Terraform expert. Analyze the following Stategraph results JSON. Summarize the changes, flag any risks or errors, and highlight anything that deserves reviewer attention. Be concise."}]},
    contents: [{parts: [{text: $results}]}]
  }')")

echo "$RESPONSE" | jq -r '.candidates[0].content.parts[0].text'
```

## Storing API keys

Store the provider API key, for example `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, or `GOOGLE_API_KEY`, as a GitHub secret or a GitLab CI/CD variable. The script reads it as an environment variable. Do not let the script print the key: `capture_output: true` posts its output to the pull request.

### GitHub

Store the key as a [GitHub secret](https://docs.github.com/en/actions/security-for-github-actions/security-guides/using-secrets-in-github-actions) in your repository:

1. Open the repository **Settings**, then **Secrets and variables**, then **Actions**.
2. Click **New repository secret**.
3. Add the key.

To scope a key to `production` or `staging`, use [GitHub Environments](/docs/orchestration/security/github-environments), a GitHub Actions feature.

### GitLab

Store the key as a [CI/CD variable](https://docs.gitlab.com/ee/ci/variables/) on your project or group:

1. Open your GitLab project and go to **Settings**, then **CI/CD**, then **Variables**.
2. Click **Add variable** and enter the key name and value.
3. Mark the variable as masked, leave **Protect variable** cleared, then click **Add variable**.

GitLab passes protected variables only to pipelines on protected branches. Orchestration runs plans on the source branch of the merge request, so those runs do not get a protected variable.

## Tips and best practices

- `run_on: always` gives feedback on success and on failure. Error analysis gives the most value.
- `visible_on: always` shows the response in the pull request comment for every outcome.
- `ignore_errors: true` stops an LLM API failure from blocking a plan or apply.
- Truncate large plans. The example scripts send the full results file: add a `head -c` or `jq` filter to stay in the limits of your provider.
- Use stricter, security-focused prompts for production directories, and shorter summaries for development.
- Build the JSON with `jq -n`, as the examples do, so special characters in Terraform output are escaped correctly.

## Next Steps

- [AI agents](/docs/ai): use Infrastructure as a Database from an AI agent
- [hooks reference](/docs/reference/orchestration/configuration/hooks): the `run` hook keys
- [Environment variables](/docs/orchestration/configuration/environment-variables): the shape of the results file
