# Independent review: branch A

Reviewed `2c244d98a7c4e06dec0420351d349900faf9375a` against main `346a8a7`. All finding line numbers refer to that reviewed commit. Changes from the Net Ninjas original are included in this branch after the review. Findings describe the reviewed head; fixes are identified below.

## Critical

1. `skills/agent-permissions-check/scripts/list-agent-config.sh:353`: hidden-block depth counts braces but ignores arrays. Input `hidden-array.json` below prints a credential under `env`. This defeats the reader's explicit hidden-block rule and exposes values to an agent's context. Count arrays as well as objects. Fixed with a regression.

```json
{
 "mcpServers": {
  "auth": {
   "env": [
    {"command": "FIXTUREVALUE-hidden-array"}
   ]
  }
 }
}
```

Exact original output line (spaces then a tab):

```text
     5	    {"command": "FIXTUREVALUE-hidden-array"}
```

2. `skills/agent-permissions-check/scripts/list-agent-config.sh:260`: the server-name exemption uses object depth only. Input `server-array.json` below mistakes the hidden `auth` block for a server name under `servers`. Credential output is outside the documented plain-word exception because the block is explicitly hidden. Count all nesting when identifying immediate server children. Fixed with a regression.

```json
{
 "servers": [
  {"auth": {
   "command": "FIXTUREVALUE-hidden-server"
  }}
 ]
}
```

Exact output:

```text
     4	   "command": "FIXTUREVALUE-hidden-server"
```

3. `skills/agent-permissions-check/scripts/list-agent-config.sh:330`: escaped JSON keys are compared without decoding. Input `escaped-key.json` uses valid JSON spelling of `env`; descendants print despite being credentials. Hide escaped-key containers unless they can be decoded safely. Fixed conservatively; escaped value strings are hidden whole too.

```json
{
 "servers": {
  "headers": {
   "\u0065nv": {
    "command": "FIXTUREVALUE-escaped-key"
   }
  }
 }
}
```

Exact output:

```text
     5	    "command": "FIXTUREVALUE-escaped-key"
```

4. `skills/agent-permissions-check/scripts/list-agent-config.sh:496`: YAML recognises neither quoted credential keys, quoted multiline continuation, nor flow mappings; its expression exception accepts arbitrary suffixes. File `quoted.yml` and exact original output follow. These are normal workflow credential layouts, so a masked read puts credentials into the reviewer's context. Track quoted scalars, recognise quoted keys, require complete expressions, and hide credential-bearing flow mappings. Fixed, with regressions.

```yaml
env:
  'API_TOKEN': FIXTUREVALUE-quoted
  API_TOKEN: "first
    FIXTUREVALUE-second"
  API_TOKEN: ${{ secrets.KEY }} FIXTUREVALUE-suffix
```

```text
     2	  'API_TOKEN': FIXTUREVALUE-quoted
     4	    FIXTUREVALUE-second"
     5	  API_TOKEN: ${{ secrets.KEY }} FIXTUREVALUE-suffix
```

File `flow.yml`: `env: {API_TOKEN: FIXTUREVALUE-flow}`. Exact output:

```text
     1	env: {API_TOKEN: FIXTUREVALUE-flow}
```

5. `skills/agent-permissions-check/scripts/list-agent-config.sh:571`: escaped text terminates credential matching and the remainder survives. File `saved.json`, in the saved-approval layout, and exact output:

```json
{"permissions":{"allow":["Bash(API_TOKEN=FIXTUREVALUE-first\nFIXTUREVALUE-second curl *)"]}}
```

```text
     1	{"permissions":{"allow":["Bash(API_TOKEN=<redacted>\nFIXTUREVALUE-second curl *)"]}}
```

File `escaped.md`: `Authorization: Bearer FIXTUREVALUE-first\nFIXTUREVALUE-second`. Exact output:

```text
     1	Authorization: <redacted>\nFIXTUREVALUE-second
```

Recognised credentials can therefore leak via saved shell approvals or Markdown headers. Hide escaped strings and the remainder of escaped free text rather than trying to reconstruct them with regular expressions. Fixed conservatively; harmless text after an escape is hidden as well.

## Important: understated limit

`CHANGELOG.md:37` describes only short plain words as undetectable. Arbitrarily long alphabetic credentials have no recognised token shape and survive the mixed-letter/digit heuristic too. That is an understated limit, rather than a new report of the acknowledged positional-word case. The limit now says so explicitly. The heuristic remains unsuitable as a guarantee that arbitrary input contains no credential; the unconditional security property cannot be inferred from these passing tests.

## Checks and portability

Original B's validator, scanner, reader and names-filter suites passed on macOS. A's original validator, scanner and reader suites were also run. A has no names-filter test yet; that test belongs to B. ShellCheck 0.11.0 passes. Corrected reader tests pass with macOS sh and dash, BSD sed, and BSD awk. BusyBox is unavailable on this macOS host (Homebrew has no formula). No GNU-only behaviour is required by the tested paths.

The new credential cases failed against the original reader before fixes. Independently removing HIDE_KEYS in an archived scratch copy makes the original suite fail at the hidden TOML case. This shows that the original suite detects that mutation, but not the newly found inputs. Scanner tests are scripted examples, not an exhaustive proof. All newly supplied credentials contain FIXTUREVALUE. Home-mode tests used only the fixture's stand-in folder.

Execution used an empty environment and scratch HOME under sandbox-exec, with network denied and /Users reads denied. macOS shell and Git temporary-file behaviour required allowing temporary-directory writes; this was not the strict per-directory write sandbox described by the security-review skill. No fixture application, provider call, or model code was executed.

## Documentation and fixture findings

Reviewed original commit 2c244d9, against main 346a8a7. These line references are from that original commit. Findings below were corrected in the worktree unless marked unresolved.

## Important

- `skills/agent-permissions-check/references/checks.md:37`: Repository could be enforced with a CODEOWNERS file even when code owner review is not required. A PR-only rule and an owner file do not prevent the bot changing workflows. Require the actual code owner approval setting and effective bypass checks. GitHub's [CODEOWNERS documentation](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners) distinguishes automatic review requests from required approval.
- `skills/agent-permissions-check/references/checks.md:50`: Identity could be enforced by any app-token step, regardless of permissions, or by a workflow token. Neither proves the published mechanism (a GitHub App with the fewest permissions). Require evidence of the app and effective least privilege; unknown effective permissions are not checked.
- `skills/agent-permissions-check/references/checks.md:73`: different account identifiers plus OIDC were sufficient for Cloud enforced even if the role could assume into production. Require policy and trust evidence that the agent cannot reach production; otherwise not checked or stated only. This follows from the policy's own scoped-role mechanism.
- `skills/agent-permissions-check/references/checks.md:95`: every self-hosted/custom runner was open, although the published policy expressly allows ephemeral runners. The open-rows variant gives only a label, not lifetime or network evidence. Its original row 6 open and headline 0 of 9 (0 not checked) do not follow. Correct result is row 6 not checked and 0 of 9 enforced (1 not checked). Require positive lifetime/isolation evidence for enforcement or exposure evidence for open.
- `skills/agent-permissions-check/references/agent-files.md:60,66` and `references/checks.md:142`: current Codex facts were stale. Explicit `approval_policy = "untrusted"` is unsupported; `on-failure` is deprecated. Since 0.134.0 config profiles live in separate `<name>.config.toml` files, and inline `[profiles.<name>]` settings no longer apply. Treating a legacy inline never policy as active overstates access and misses current profiles. Corrected facts and added separate config profiles to Not checked. Sources: [configuration reference](https://learn.chatgpt.com/docs/config-file/config-reference), [profile migration](https://learn.chatgpt.com/docs/config-file/config-advanced#profiles).
- `skills/agent-permissions-check/references/agent-files.md:51,54,90`: inventory omits `AGENTS.override.md`, which replaces AGENTS.md at that level, without naming it as a limit. The report could treat an inactive instruction file as the active policy. Added explicit limit for overrides/fallback names. Source: [instruction discovery](https://learn.chatgpt.com/docs/agent-configuration/agents-md).

## Minor

- `references/checks.md:36`: PAT presence alone made Repository open because bypass rights "can include" the forbidden access, contradicting open's evidence requirement. Check effective rights; plain fixture still open because its workflow approves the agent's own work at workflow line 25.
- `SKILL.md:24`, `references/checks.md:187`: B8 was omitted when absent, contradicting mandatory eight rows at SKILL lines 98 and 176. Keep the row with not found text.
- `references/checks.md:20,22,24`: no-gh rule says not checked unless open, while general precedence and the instruction search require stated only. Clarified precedence and default cases for partial/unclassified inputs.
- `SKILL.md:38`: fixture builder creates no origin; unconditional not-checked wording for GitHub-dependent rows contradicted file-proven open and stated-only results. Clarified that unavailable remote settings do not erase file evidence.
- `references/checks.md:198`: Confirm first mentions only not-checked status although line 27 requires it for open/stated-only rows with unread settings too. Fixed, with deterministic tie order for Part B remedies.
- `references/checks.md:173`: Codex per-server default_tools_approval_mode=approve was described as approving all tools of all servers. Corrected scope and per-tool override qualification.
- `tests/fixtures/agent-permissions-check/EXPECTED.md:79`: home mode "may then include" prompt-skipping in the first three is impossible because more than three open rows outrank Part B. Corrected unchanged first-three list.
- `tests/fixtures/agent-permissions-check/scenarios.md:29`: plain fixture claimed to show all five statuses. It shows four, with no not-found row. Corrected.

## Facts confirmed, including entries previously marked verify

Claude paths, saved Bash approvals, trust for tracked local/shared allow rules, list merging, project bypass/auto exclusion and pre-2.1.257 bypass behaviour match the current [settings](https://code.claude.com/docs/en/settings) and [permissions](https://code.claude.com/docs/en/permissions) documentation. These checked claims hold.

All nine published policy rows, order, may, may-not, and enforcement columns match the [published page](https://www.netninjas.us/events/agent-permissions-one-page), apart from intended UK spelling. Fetched HTML and parsed its table when web reader could not open it.

Previously unverified Claude instruction paths confirmed using [memory](https://code.claude.com/docs/en/memory). Credentials path confirmed using [authentication](https://code.claude.com/docs/en/authentication): Linux/Windows use the file; macOS normally uses Keychain, with file fallback. Sandbox facts confirmed using [sandboxing](https://code.claude.com/docs/en/sandboxing). The shell sandbox is not a boundary for every tool/MCP server. MCP layouts and expansion confirmed in [MCP](https://code.claude.com/docs/en/mcp); credential variables can deliberately expand empty in remote headers/URLs.

Previously unverified Codex hooks paths confirmed using [hooks](https://learn.chatgpt.com/docs/hooks), with project trust and separate hook trust qualification. Global instructions confirmed using [instruction discovery](https://learn.chatgpt.com/docs/agent-configuration/agents-md). auth.json and alternate OS store confirmed using [authentication](https://learn.chatgpt.com/docs/auth). A missing auth.json does not prove absence of credentials. Current approval, sandbox, permissions, MCP fields and tool overrides checked against the configuration reference. Added custom permission profile handling to B3 because sandbox_mode alone misses those boundaries.

## Independent fixture pass

Derived rows from fixture sources BEFORE opening EXPECTED.md. Built plain2 and open2 using make-repo.sh under sandbox-exec with no network, empty environment, a scratch HOME, and no access to /Users. Used actual CommandLineTools git to avoid Apple shim cache writes. Inventory and --show used for every listed repository agent file in plain; open workflow checked separately (all other files identical). Declined gh, real home, and policy-file writing. No credential stores read. No customer records read. All fake credentials came from supplied fixture and contain FIXTUREVALUE.

Original plain derivation: Repository open; Identity open; Secrets not checked; Cloud stated only; Data open; Runners enforced; Outside input open; Review open; Record open. Headline 1 of 9 (1 not checked). First three Outside input, Repository, Identity. Matches EXPECTED once missing-remote and PAT causation are corrected.

Original open-rows mechanically gave all open under the old runner rule, but the rule overstates the evidence. Corrected derivation: all open except Runners not checked, headline 0 of 9 (1 not checked). First three Outside input, Secrets, Repository. Part B unchanged.

Unclear as a different agent: absence of a remote versus local workflow findings; B8 optional versus mandatory; no-gh stated-only precedence; legacy Codex profiles versus current profiles; runner labels treated as behaviour. Changes make those decisions explicit.

## Claims that do not hold

- agent-files claim current profiles can set any key under inline names.
- checks claim all server tools approved by one server default.
- EXPECTED home run can promote a prompt-skipping mode into first three despite open-row priority.
- scenarios plain fixture includes all five statuses.
- scenarios and make-repo comment label alone establishes open Runners; original all-open headline follows only from an overbroad rule.

## Not judged

Other vendors' verify entries (Gemini/Copilot/Cursor/VS Code) are outside this delegated Claude/Codex fact scope. Real effective GitHub settings, app rights, cloud IAM and runner isolation were not queried; the fixture is offline and user says no gh. Source documentation establishes the required evidence, not live effective rights. This delegated review does not cover reader attacks, shell portability, tests, PR descriptions, or branch B; parent owns them.

## Claims that do not hold

PR 6's broad statement that the script prints files with values hidden is contradicted by the exact outputs above. The claim that a server called auth/env/oauth/headers still hides nested credential blocks needs qualification: the array and escaped-key cases defeat that handling. This does not prove that the previously reported fifteen individual fixes were never made; it shows that those historical fixes were insufficient to establish the stated security property.

The changelog understates the plain-word limit. The original tests/RESULTS.md and PR description treat the open-rows runner status and headline as correct; self-hosted alone does not establish that conclusion. Historical model run counts and the claim that each prior test failed first cannot be independently reconstructed from checked-in summaries.

## Not judged

- BusyBox execution: no local executable or macOS package available.
- Real home, credentials, effective GitHub settings, and cloud rights: intentionally excluded by the requested scope and offline fixture answers.
- Interactive policy-file writing and a fully conversational skill run: the fixtures were built and worked manually, with no to gh and the policy file. This does not validate question timing.
- Exhaustive malformed input and odd-byte behaviour: cases exercise CRLF and escaped content, but cannot establish the universal no-credential property over arbitrary bytes.

## Verdict

Branch A at the reviewed commit is not ready to merge because the reader leaks recognised credentials and several permission statuses overstate enforcement; the reproduced paths and documentation findings are fixed in the accompanying commit, with the heuristic limitation explicitly retained.
