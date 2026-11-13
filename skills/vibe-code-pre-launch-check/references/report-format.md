# Report format

Print the report in this shape. Keep the headings and their order. Leave a group heading in place and write "Nothing found." under it when the group is empty.

````markdown
# Pre-launch check: <repository name>

**Verdict: <Ready | Fix first | Do not launch>.** <One sentence with the reason.>

This is a quick check. It is not a penetration test and it is not legal advice.

## The three fixes to make first

1. <Finding title> (<reach group>, effort <S | M | L>)
2. ...
3. ...

## Findings

### Anyone on the internet

#### 1. <Short title that names the problem>

- **What:** <One or two sentences.>
- **Where:** `<path>:<line>`
- **Why it matters:** <What an attacker gets, in plain words.>
- **Fix:**

  ```<language>
  <the smallest change that closes it, with placeholders for any secret>
  ```

- **Effort:** <S | M | L>

### Any signed-in user

...

### Anyone holding a leaked key or repository access

...

## Personal data (flag only)

- <Kind of personal data>: stored in `<path>:<line>`. <Written to logs at `<path>:<line>`, or "No logging of it found in the repository.">

## Not checked

- <Each check that was skipped, with the reason.>

## Going deeper

This check reads the repository once. For a deep review, I point to security-audit by Cloudflare, Inc., a free, open-source skill (https://github.com/cloudflare/security-audit-skill, MIT licence).

---

Checked with the Vibe-code pre-launch check, a free skill from Net Ninjas Consulting: https://www.netninjas.eu/skills
````

## Rules for the parts

- **Numbering.** Findings are numbered once across the whole report, so "the three fixes" can refer to them.
- **Where.** One path and line per finding. When the same problem repeats, give the first place and add "and N more: `<path>:<line>`, ...".
- **Fix.** A snippet in the project's own language and framework. Any secret is a placeholder. When the first step is to rotate a key, the fix says so before the code.
- **Effort.** S is under one hour. M is up to half a day. L is more than a day.
- **Assumptions.** Start the sentence with "Assumption:". Example: "Assumption: this repository is or will be public. Nothing in the files says either way."
- **Not checked.** Always present. It lists live URLs (never scanned), anything outside the repository (provider dashboards, DNS, the running database), the registry checks when the answer was no, and any stack the checks do not cover.
- **Fewer than three findings.** List the ones there are under "The three fixes to make first". With no findings, write "Nothing to fix first."
