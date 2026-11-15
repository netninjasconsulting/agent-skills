# Snippets

Ready to paste. Adapt names, paths, and commands to the repository, and say which lines were adapted. Every value in angle brackets is a placeholder. Never fill one in with a real credential.

The settings formats change often. Each snippet names the page it was checked against on 15 November 2026.

## Contents

1. [A ruleset the agent cannot bypass](#a-ruleset-the-agent-cannot-bypass) (Repository, Review)
2. [CODEOWNERS for workflow and agent files](#codeowners-for-workflow-and-agent-files) (Repository, Review)
3. [An agent workflow that holds nothing worth stealing](#an-agent-workflow-that-holds-nothing-worth-stealing) (Identity, Secrets, Runners, Outside input)
4. [Production secrets behind an environment](#production-secrets-behind-an-environment) (Secrets)
5. [Claude Code: ask first, and keep secrets out of reach](#claude-code-ask-first-and-keep-secrets-out-of-reach) (Part B)
6. [Codex: ask first, inside the workspace](#codex-ask-first-inside-the-workspace) (Part B)
7. [An MCP server that names a variable](#an-mcp-server-that-names-a-variable) (Part B)

## A ruleset the agent cannot bypass

In the repository on GitHub: Settings, Rules, Rulesets, New branch ruleset. Target the default branch.

- Require a pull request before merging, with one approval and "Require review from Code Owners".
- Require approval of the most recent push by someone other than the person who pushed it.
- Require status checks to pass.
- Leave the bypass list empty. No bot, no app, and no agent's account goes in it.

Then, under Settings, Actions, General, clear "Allow GitHub Actions to create and approve pull requests" unless a workflow needs to open pull requests. If one does, the ruleset above still keeps it from approving its own work, because the approving review has to come from a code owner.

Rulesets work in public repositories on every plan. Private repositories need GitHub Pro, Team, or Enterprise.

## CODEOWNERS for workflow and agent files

```text
# .github/CODEOWNERS
/.github/            @<owner-or-team>
/.claude/            @<owner-or-team>
/.codex/             @<owner-or-team>
/.mcp.json           @<owner-or-team>
/CLAUDE.md           @<owner-or-team>
/AGENTS.md           @<owner-or-team>
```

The owners are people or a team of people. A bot as a code owner approves its own work.

## An agent workflow that holds nothing worth stealing

```yaml
# .github/workflows/agent.yml
name: agent

on:
  issues:
    types: [labeled]

# The agent may open a branch and a pull request. It may not approve or merge.
permissions:
  contents: write
  pull-requests: write

jobs:
  agent:
    # Only a maintainer can add the label, so an outside contributor cannot start this job.
    if: github.event.label.name == 'agent' && contains(fromJSON('["OWNER","MEMBER","COLLABORATOR"]'), github.event.issue.author_association)
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - uses: actions/create-github-app-token@<full-commit-sha>
        id: app
        with:
          app-id: ${{ vars.AGENT_APP_ID }}
          private-key: ${{ secrets.AGENT_APP_PRIVATE_KEY }}
      - uses: actions/checkout@<full-commit-sha>
        with:
          persist-credentials: false
      - uses: <agent-action>@<full-commit-sha>
        with:
          github-token: ${{ steps.app.outputs.token }}
        env:
          # The model key, and nothing else. No cloud keys and no production secrets.
          <MODEL_API_KEY_NAME>: ${{ secrets.<MODEL_API_KEY_NAME> }}
```

What it changes:

- The job never runs on `pull_request_target`, `issue_comment`, or `workflow_run`, so text from an outside contributor does not reach a job that holds a secret.
- The token comes from a GitHub App with the fewest permissions it needs, and it expires after an hour. No personal access token.
- `runs-on` is a GitHub-hosted image, which is fresh for each run.
- Pin each action to a full commit SHA.

## Production secrets behind an environment

In the repository on GitHub: Settings, Environments, New environment, `production`.

- Add required reviewers. They are people.
- Limit deployment branches to the default branch.
- Move every production secret from repository secrets into this environment.

Only the deploy job names the environment:

```yaml
jobs:
  deploy:
    environment: production
```

An agent job that does not name the environment cannot read its secrets.

## Claude Code: ask first, and keep secrets out of reach

Checked against https://code.claude.com/docs/en/settings and https://code.claude.com/docs/en/permissions.

```json
{
  "permissions": {
    "defaultMode": "default",
    "disableBypassPermissionsMode": "disable",
    "allow": [
      "Bash(npm run lint)",
      "Bash(npm run test *)"
    ],
    "ask": [
      "Bash(git push *)"
    ],
    "deny": [
      "Read(./.env)",
      "Read(./.env.*)",
      "Read(./secrets/**)",
      "Bash(gh pr merge *)",
      "Bash(terraform apply *)"
    ]
  }
}
```

- This goes in `.claude/settings.json`, so the whole team gets it.
- Deny rules are evaluated first, and a narrower allow rule cannot carve an exception out of one.
- Remove a bare `Bash` and `mcp__*` from every allow list, including the one in the home folder. Allow the commands and the tools the work needs, by name.
- Leave `enableAllProjectMcpServers` out, so each person approves each server in `.mcp.json` once.

## Codex: ask first, inside the workspace

Checked against https://learn.chatgpt.com/docs/config-file/config-reference.md.

```toml
# .codex/config.toml, or ~/.codex/config.toml
approval_policy = "on-request"
sandbox_mode = "workspace-write"

[sandbox_workspace_write]
network_access = false
```

## An MCP server that names a variable

A token written into the file travels with the repository. Name an environment variable in its place, and set the variable outside the repository.

```json
{
  "mcpServers": {
    "<server-name>": {
      "type": "http",
      "url": "https://<host>/mcp",
      "headers": {
        "Authorization": "Bearer ${<TOKEN_VARIABLE_NAME>}"
      }
    }
  }
}
```

For Codex, `bearer_token_env_var = "<TOKEN_VARIABLE_NAME>"` does the same for a remote server.

After the change, treat the old token as leaked: revoke it where it was issued and create a new one. Removing it from the file does not remove it from Git history.
