# Where agents keep their settings

Every fact here was read from the vendor's own documentation on 15 November 2026, or it is marked "verify". These files change often. Before relying on a row marked "verify", read the vendor's current page, or say in the report that the fact dates from this file.

`scripts/list-agent-config.sh` looks for exactly the paths in the three tables below. It never walks the home folder.

Sources:

- Claude Code settings: https://code.claude.com/docs/en/settings
- Claude Code permissions: https://code.claude.com/docs/en/permissions
- Claude Code MCP: https://code.claude.com/docs/en/mcp
- Codex configuration reference: https://learn.chatgpt.com/docs/config-file/config-reference.md

## Claude Code

| Path | Where | Kind | What it controls | Status |
| --- | --- | --- | --- | --- |
| `.claude/settings.json` | Repository | settings | Shared permissions, hooks, and environment for everyone in the project | checked |
| `.claude/settings.local.json` | Repository, kept out of Git | settings | One person's overrides, and the "don't ask again" approvals Claude Code saves | checked |
| `.mcp.json` | Repository | mcp | Project-scoped MCP servers | checked |
| `CLAUDE.md` | Repository | instructions | Standing instructions | checked |
| `CLAUDE.local.md`, `.claude/CLAUDE.md`, `.claude/rules/` | Repository | instructions | More instruction files | verify |
| `.claude/settings.json` | Home | settings | One person's settings for every project | checked |
| `.claude.json` | Home | mcp | Account details, user-scoped and local-scoped MCP servers, and trust decisions | checked |
| `.claude/CLAUDE.md` | Home | instructions | One person's standing instructions | verify |
| `.claude/.credentials.json` | Home | credential-store | Sign-in tokens. Never shown | verify |

Keys that carry permissions:

- `permissions.allow`, `permissions.ask`, and `permissions.deny` hold rule strings such as `Bash(npm run test *)`, `Read(./.env)`, `WebFetch`, and `mcp__<server>__<tool>`. Rules are evaluated in the order deny, ask, allow, and the first match decides. checked
- `permissions.defaultMode` sets the permission mode. The modes that remove prompts are `bypassPermissions`, `auto`, `dontAsk`, and, for file edits, `acceptEdits`. checked
- `permissions.additionalDirectories` adds folders outside the working folder. checked
- `permissions.disableBypassPermissionsMode` and `permissions.disableAutoMode`, set to `"disable"`, turn those modes off from any settings file. checked
- `enableAllProjectMcpServers`, `enabledMcpjsonServers`, and `disabledMcpjsonServers` approve or reject the servers in `.mcp.json`. checked
- `hooks` runs commands on events. checked
- `env` and `apiKeyHelper` can hold or produce credentials. They are never shown. checked
- An MCP server entry has `command`, `args`, and `env` for a local server, or `type`, `url`, `headers`, and `headersHelper` for a remote one. `${VAR}` is expanded in `command`, `args`, `env`, `url`, and `headers`, so a server can name a variable where it would hold a token. checked
- `sandbox` settings. verify

Three facts that change a status:

1. `permissions.defaultMode` values `auto` and `bypassPermissions` take no effect from `.claude/settings.json` or `.claude/settings.local.json`. They take effect from the home folder file, from managed settings, or from a command-line flag. The settings page says that `bypassPermissions` took effect from any file before version 2.1.257. checked
2. `permissions.allow` rules and `permissions.additionalDirectories` in the shared project file apply only after each person trusts the folder. `deny` and `ask` rules apply at once. checked
3. Lists such as `permissions.allow` merge across files. A home-folder allow rule applies in every project. checked

## Codex

| Path | Where | Kind | What it controls | Status |
| --- | --- | --- | --- | --- |
| `.codex/config.toml` | Repository | settings | Project settings. Codex loads them only for a trusted project | checked |
| `AGENTS.md` | Repository | instructions | Standing instructions | checked |
| `.codex/hooks.json` | Repository | hooks | Commands that run on events | verify |
| `.codex/config.toml` | Home | settings | One person's settings, including MCP servers | checked |
| `.codex/AGENTS.md` | Home | instructions | One person's standing instructions | verify |
| `.codex/hooks.json` | Home | hooks | Commands that run on events | verify |
| `.codex/auth.json` | Home | credential-store | Sign-in tokens. Never shown | checked |

Keys that carry permissions:

- `approval_policy`: `on-request`, `never`, or a `granular` table. `never` removes every prompt. Older values such as `untrusted` and `on-failure` still appear in some files. checked for the first three, verify for the older two
- `sandbox_mode`: `read-only`, `workspace-write`, or `danger-full-access`. checked
- `sandbox_workspace_write.network_access` and `sandbox_workspace_write.writable_roots`. checked
- `default_permissions` and the `permissions.<name>` profiles. checked
- `[mcp_servers.<id>]`: `command`, `args`, `env`, and `env_vars` for a local server, or `url`, `bearer_token_env_var`, `http_headers`, and `env_http_headers` for a remote one. `bearer_token_env_var` and `env_http_headers` name a variable and hold no token. `env`, `http_headers`, and `oauth.client_secret` can hold one, and they are never shown. checked
- `enabled_tools`, `disabled_tools`, `default_tools_approval_mode`, and `tools.<tool>.approval_mode` on a server. checked
- `profiles` can set any of the keys above under another name. checked

## Shared layer

For every other agent, version 1 reads three things and no tool-specific settings.

| Path | Where | Kind | Agent it usually belongs to | Status |
| --- | --- | --- | --- | --- |
| `AGENTS.md` | Repository | instructions | Many agents | checked |
| `GEMINI.md` | Repository | instructions | Gemini CLI | verify |
| `.github/copilot-instructions.md` | Repository | instructions | GitHub Copilot | verify |
| `.cursorrules`, `.cursor/rules/` | Repository | instructions | Cursor | verify |
| `.cursor/mcp.json` | Repository | mcp | Cursor | verify |
| `.vscode/mcp.json` | Repository | mcp | VS Code | verify |
| `.gemini/settings.json` | Repository | mcp | Gemini CLI | verify |
| `.cursor/mcp.json` | Home | mcp | Cursor | verify |
| `.gemini/settings.json` | Home | mcp | Gemini CLI | verify |
| `.github/workflows/*` that run an agent | Repository | workflow | Any | checked |

A workflow "runs an agent" when it uses an action whose name contains `claude-code`, `codex`, `copilot`, `cursor`, `gemini-cli`, `aider`, or `opencode`, or when a step runs the `claude` or `codex` command.

## Not checked in version 1

Name each of these under "Not checked" in the report.

- Managed settings that an employer installs: a `managed-settings.json` file in a system folder, a device management policy, or server-managed settings. They rank above every file this check reads.
- Codex `requirements.toml` and other managed configuration.
- A home folder moved with `CLAUDE_CONFIG_DIR` or `CODEX_HOME`.
- Flags on the command line, such as `--permission-mode`, `--settings`, `--dangerously-skip-permissions`, and Codex `--sandbox`. Scripts and workflows in the repository that pass them are read. A person's shell history is not.
- Tool-specific settings of agents other than Claude Code and Codex.
- Cloud sessions, which read only some of these files.
