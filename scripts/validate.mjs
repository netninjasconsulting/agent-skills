#!/usr/bin/env node
// validate.mjs: check every skill against the Agent Skills format and this repository's own rules.
//
// Copyright 2026 Net Ninjas Consulting
// SPDX-License-Identifier: Apache-2.0
//
// Usage: node scripts/validate.mjs
//
// No dependencies. Reads files only. Exits 1 when any check fails.

import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const skillsDir = path.join(root, "skills");
const failures = [];
const fail = (where, message) => failures.push(`${path.relative(root, where) || "."}: ${message}`);
const read = (file) => readFileSync(file, "utf8");

/** Every file under a folder, depth first. */
function walk(dir) {
  return readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const full = path.join(dir, entry.name);
    // .superpowers is the git-ignored scratch folder of the planning tools.
    if (entry.name === ".git" || entry.name === "node_modules" || entry.name === ".superpowers") return [];
    return entry.isDirectory() ? walk(full) : [full];
  });
}

/**
 * The frontmatter of a SKILL.md as a flat map. The skills use plain `key: value`
 * lines and one nested `metadata:` block, so a full YAML parser is not needed.
 */
function frontmatter(file) {
  const text = read(file);
  const match = /^---\n([\s\S]*?)\n---\n/.exec(text);
  if (!match) return { fields: null, body: text };
  const fields = {};
  let parent = null;
  for (const line of match[1].split("\n")) {
    const nested = /^ {2}([A-Za-z0-9_-]+):\s*(.*)$/.exec(line);
    const top = /^([A-Za-z0-9_-]+):\s*(.*)$/.exec(line);
    if (nested && parent) fields[`${parent}.${nested[1]}`] = nested[2].replace(/^"(.*)"$/, "$1");
    else if (top) {
      parent = top[2] === "" ? top[1] : null;
      if (top[2] !== "") fields[top[1]] = top[2].replace(/^"(.*)"$/, "$1");
    } else if (line.trim() !== "") fail(file, `frontmatter line not understood: ${line}`);
  }
  return { fields, body: text.slice(match[0].length) };
}

// Each third-party skill that any skill names must be credited in NOTICE with its source.
const credits = [
  { name: "Superpowers", source: "https://github.com/obra/superpowers" },
  { name: "Ponytail", source: "https://github.com/DietrichGebert/ponytail" },
  { name: "UI UX Pro Max", source: "https://github.com/nextlevelbuilder/ui-ux-pro-max-skill" },
  { name: "security-audit", source: "https://github.com/cloudflare/security-audit-skill" },
];

const scopeLine = "This is a quick check. It is not a penetration test and it is not legal advice.";

// Names that contain the word and are someone else's: a product name, or an ecosystem's own command.
// "audit log" is GitHub's own name for the feature the agent permissions policy cites.
const auditAllowed =
  /security-audit(-skill)?|\baudit logs?\b|\b(npm|pnpm|yarn npm|yarn|bun|cargo|composer|bundle) audit\b|\b(pip|cargo|bundler)-audit\b|audit fix|ecosystem's own audit command/gi;

const skills = readdirSync(skillsDir).filter((name) => statSync(path.join(skillsDir, name)).isDirectory());
const versions = new Set();

for (const name of skills) {
  const dir = path.join(skillsDir, name);
  const skillFile = path.join(dir, "SKILL.md");
  if (!existsSync(skillFile)) {
    fail(dir, "no SKILL.md");
    continue;
  }
  const { fields, body } = frontmatter(skillFile);
  if (!fields) {
    fail(skillFile, "no YAML frontmatter");
    continue;
  }

  // The Agent Skills specification (https://agentskills.io/specification).
  if (fields.name !== name) fail(skillFile, `name "${fields.name}" does not match the folder "${name}"`);
  if (!/^[a-z0-9]+(-[a-z0-9]+)*$/.test(name) || name.length > 64) fail(skillFile, "name must be lowercase letters, numbers, and single hyphens, 64 characters at most");
  const description = fields.description ?? "";
  if (description.length === 0 || description.length > 1024) fail(skillFile, `description must be 1 to 1024 characters (it is ${description.length})`);
  if (!description.startsWith("Use when ")) fail(skillFile, 'description must start with "Use when "');
  if ((fields.compatibility ?? "").length > 500) fail(skillFile, "compatibility must be 500 characters at most");
  if (read(skillFile).split("\n").length > 500) fail(skillFile, "SKILL.md must stay under 500 lines");

  // This repository's rules.
  if (fields.license !== "Apache-2.0") fail(skillFile, 'license must be "Apache-2.0"');
  if (fields["metadata.author"] !== "Net Ninjas Consulting") fail(skillFile, 'metadata.author must be "Net Ninjas Consulting"');
  if (!/^\d+\.\d+\.\d+$/.test(fields["metadata.version"] ?? "")) fail(skillFile, "metadata.version must look like 1.2.3");
  versions.add(fields["metadata.version"]);
  if (!existsSync(path.join(dir, "README.md"))) fail(dir, "no README.md");
  if (!existsSync(path.join(root, "tests", "fixtures", name))) fail(dir, `no fixture at tests/fixtures/${name}`);
  if (!/^## Ground rules$/m.test(body)) fail(skillFile, 'no "## Ground rules" section');

  const files = walk(dir);
  const all = files.filter((file) => file.endsWith(".md")).map(read).join("\n");
  if (!all.includes(scopeLine)) fail(dir, "the scope line is missing from the skill's report format");
  if (!all.includes("https://www.netninjas.us")) fail(dir, "no link to netninjas.us");
  for (const credit of credits) {
    if (all.includes(credit.source) && !read(path.join(root, "NOTICE")).includes(credit.source)) fail(dir, `${credit.name} is named and not credited in NOTICE`);
  }
  if (name.includes("audit")) fail(dir, 'a Net Ninjas skill name never contains "audit"');
}

if (versions.size > 1) fail(skillsDir, `the skills carry different versions: ${[...versions].join(", ")}`);
const [version] = versions;
if (version && !read(path.join(root, "CHANGELOG.md")).includes(`## ${version}`)) fail(path.join(root, "CHANGELOG.md"), `no entry for version ${version}`);

for (const required of ["LICENSE", "NOTICE", "README.md", "CHANGELOG.md"]) {
  if (!existsSync(path.join(root, required))) fail(root, `${required} is missing`);
}
const notice = existsSync(path.join(root, "NOTICE")) ? read(path.join(root, "NOTICE")) : "";
if (!notice.includes("Copyright 2026 Net Ninjas Consulting")) fail(path.join(root, "NOTICE"), 'the line "Copyright 2026 Net Ninjas Consulting" is missing');
for (const credit of credits) if (!notice.includes(credit.source)) fail(path.join(root, "NOTICE"), `no credit for ${credit.name}`);
if (!read(path.join(root, "LICENSE")).includes("Apache License") || !read(path.join(root, "LICENSE")).includes("Version 2.0")) fail(path.join(root, "LICENSE"), "not the Apache License 2.0");

// Copy rules for everything Net Ninjas wrote. Fixtures are test data, and LICENSE is not ours to edit.
const prose = walk(root).filter((file) => {
  const relative = path.relative(root, file);
  if (!file.endsWith(".md") && path.basename(file) !== "NOTICE") return false;
  if (!relative.startsWith(path.join("tests", "fixtures") + path.sep)) return true;
  return relative.endsWith("EXPECTED.md") || relative.endsWith("scenarios.md");
});

for (const file of prose) {
  const content = read(file);
  const lines = content.split("\n");
  let inCode = false;
  lines.forEach((line, index) => {
    const at = `line ${index + 1}`;
    if (/^\s*(```|````)/.test(line)) inCode = !inCode;
    if (/[‑–—]/.test(line)) fail(file, `${at}: em dash, en dash, or non-breaking hyphen`);
    const withoutNames = line.replace(auditAllowed, "");
    // Lines that state the rule itself have to name the word they rule out.
    const statesTheRule = /never "audit"|an "audit"|contains "audit"|"audit" or|word "audit"/.test(line);
    if (/audit/i.test(withoutNames) && !statesTheRule) fail(file, `${at}: "audit" outside a third-party name`);
    if (/penetration test|pen[- ]test/i.test(line) && !line.includes("It is not a penetration test") && !/"penetration test"/.test(line)) fail(file, `${at}: "penetration test" outside the scope line`);
    // UK spelling, outside code spans, links, and URLs.
    const plain = line.replace(/`[^`]*`/g, "").replace(/\]\([^)]*\)/g, "]").replace(/https?:\/\/\S+/g, "");
    const us = inCode ? null : plain.match(/\b(organiz|authoriz|unauthoriz|optimiz|customiz|recogniz|summariz|prioritiz|minimiz|behavior|favor|center\b|analyz)\w*/gi);
    if (us) fail(file, `${at}: US spelling (${us.join(", ")})`);
  });

  // Relative links must point at something that exists.
  for (const match of content.matchAll(/\]\((?!https?:|mailto:|#)([^)#\s]+)(#[^)]*)?\)/g)) {
    const target = path.resolve(path.dirname(file), match[1]);
    if (!existsSync(target)) fail(file, `broken link: ${match[1]}`);
  }
}

// The ten checks keep the wording of the published checklist.
const tenChecks = [
  "We protect main.",
  "Format, lint, and type checks run on every pull request.",
  "Tests run and must pass.",
  "The build runs on every pull request.",
  "Secret scanning with push protection is on.",
  "Dependency review and updates run automatically.",
  "Static analysis runs.",
  "Only the pipeline deploys, with OIDC.",
  "Every pull request gets a preview deployment.",
  "Production has an uptime check and error tracking.",
];
const gitops = path.join(skillsDir, "gitops-hygiene-check", "SKILL.md");
if (existsSync(gitops)) {
  const content = read(gitops);
  tenChecks.forEach((check, index) => {
    if (!content.includes(`${index + 1}. ${check}`)) fail(gitops, `check ${index + 1} does not match the published wording: ${check}`);
  });
}

// Modified from the Net Ninjas original during independent review.
// The AI feature architecture check keeps the wording of three published takeaways:
// the checklist, the data path map, and the cost worksheet.
const twelveChecks = [
  "The AI feature works inside the signed-in user's permissions.",
  "The interface says it's AI and marks what it generated.",
  "Every request passes authentication and validation before a prompt exists.",
  "A policy step removes or pseudonymises the personal data a task doesn't need.",
  "Retrieval reads only the sources we approved.",
  "The retrieval service applies the tenant filter in code.",
  "Every model call goes through one gateway.",
  "The feature still works when the model is slow or down.",
  "An evaluation set from real cases scores every change.",
  "A named person approves the outputs that matter.",
  "Every request leaves a trace we can query.",
  "We know what one AI action costs, per customer.",
];
const scoreBands = [
  "Ready for a customer's security review. The work now is keeping the evaluation set and the traces current.",
  "Close. A layer with two noes is the one I'd expect to break first.",
  "I'd start with layers 2 and 3. A leak of personal data, or of another customer's data, is the mistake that's hardest to undo.",
];
const tenStops = [
  "Client and API",
  "Policy gateway",
  "Prompt builder",
  "Retrieval and vector store",
  "Model endpoint",
  "Response handling",
  "Application logs",
  "Tracing and error tracking",
  "Evaluation sets",
  "Backups and snapshots",
];
const eightLeakPaths = [
  "Prompts and responses stay out of our application logs.",
  "Our tracing and error tools don't capture request bodies.",
  "The model endpoint is pinned to one region.",
  "We know what the model provider keeps, and for how long.",
  "The pseudonymisation table sits apart from the prompts.",
  "A deleted record also leaves the vector store.",
  "Our evaluation sets hold synthetic or anonymised cases.",
  "Backups and snapshots stay in the approved regions.",
];
const scoreRanges = ["11 to 12", "8 to 10", "0 to 7"];
const costColumns = ["tenant_id", "action_id", "model", "input_tokens", "cached_input_tokens", "output_tokens", "created_at"];
// The published query, with the site's domain written as on netninjas.us.
const costQuery = [
  "-- cost_per_action.sql (PostgreSQL)",
  "-- From the talk \"Your AI feature is an architecture problem\" (netninjas.us/events).",
  "-- Model cost per customer and per AI action over the last 30 days.",
  "--",
  "-- ai_requests:  one row per model call (tenant_id, action_id, model,",
  "--               input_tokens, cached_input_tokens, output_tokens, created_at).",
  "--               input_tokens counts the tokens billed at the full input price.",
  "-- model_prices: one row per model, in euros per million tokens, copied from",
  "--               the provider's current price list.",
  "",
  "WITH calls AS (",
  "  SELECT",
  "    r.tenant_id,",
  "    r.action_id,",
  "    ( r.input_tokens        * p.input_per_million",
  "    + r.cached_input_tokens * p.cached_input_per_million",
  "    + r.output_tokens       * p.output_per_million ) / 1000000.0 AS cost_eur",
  "  FROM ai_requests r",
  "  JOIN model_prices p ON p.model = r.model",
  "  WHERE r.created_at >= now() - interval '30 days'",
  ")",
  "SELECT",
  "  tenant_id,",
  "  count(DISTINCT action_id)                                AS actions,",
  "  count(*)                                                 AS model_calls,",
  "  round(sum(cost_eur), 2)                                  AS model_cost_eur,",
  "  round(sum(cost_eur) / count(DISTINCT action_id), 4)      AS cost_per_action_eur",
  "FROM calls",
  "GROUP BY tenant_id",
  "ORDER BY model_cost_eur DESC;",
];
// Match the visible structures in their own sections. A spare copy in a code
// example or a comment must not satisfy a changed live checklist.
const visibleLines = (lines) => {
  let fence = null;
  return lines.join("\n").replace(/<!--[\s\S]*?-->/g, "").split("\n").filter((line) => {
    const marker = /^\s*(`{3,}|~{3,})/.exec(line)?.[1];
    if (marker) {
      if (fence === null) fence = marker;
      else if (marker[0] === fence[0] && marker.length >= fence.length) fence = null;
      return false;
    }
    return fence === null;
  });
};
const sectionLines = (lines, heading) => {
  const starts = lines.flatMap((line, i) => line === heading ? [i] : []);
  if (starts.length !== 1) return [];
  const end = lines.findIndex((line, i) => i > starts[0] && /^## /.test(line));
  return lines.slice(starts[0] + 1, end === -1 ? undefined : end);
};
const sameLines = (file, actual, expected, label) => {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) fail(file, `${label} must match the published wording once, in order`);
};
const stopRows = [
  "What the request carries, and which fields the feature really needs.",
  "Which identifiers get removed or pseudonymised, and where the lookup table lives.",
  "Whether the finished prompt still holds a name, a date of birth, or a record number.",
  "Which sources the embeddings came from, and whether a deleted record leaves the index.",
  "The region of the endpoint, and what the provider keeps and for how long.",
  "Where re-identification happens, and who approves the draft.",
  "Whether prompts or responses appear in a log line.",
  "Whether request bodies travel to a tool outside our approved regions.",
  "Whether test cases hold real records or synthetic ones.",
  "Whether copies of the stores above stay in the same region.",
];
const aiSkill = path.join(skillsDir, "ai-feature-architecture-check");
if (existsSync(aiSkill)) {
  const linesOf = (file) => (existsSync(file) ? read(file).split("\n") : []);
  const skillFile = path.join(aiSkill, "SKILL.md");
  const skillLines = visibleLines(linesOf(skillFile));
  const checksFile = path.join(aiSkill, "references", "checks.md");
  const checksLines = visibleLines(linesOf(checksFile));
  sameLines(skillFile, sectionLines(skillLines, "## The twelve checks").filter(line => /^\d+\. /.test(line)), twelveChecks.map((check, i) => `${i + 1}. ${check}`), "the twelve checks");
  sameLines(checksFile, checksLines.filter(line => /^### \d+\. /.test(line)), twelveChecks.map((check, i) => `### ${i + 1}. ${check}`), "the twelve check headings");
  sameLines(skillFile, skillLines.filter(line => /^\| \d+ to \d+ \|/.test(line)), scoreBands.map((band, i) => `| ${scoreRanges[i]} | ${band} |`), "the score bands");
  // A whole line must match, so that "2. ..." is not found inside "12. ...".
  twelveChecks.forEach((check, index) => {
    if (!skillLines.includes(`${index + 1}. ${check}`)) fail(skillFile, `check ${index + 1} does not match the published wording: ${check}`);
    if (!checksLines.includes(`### ${index + 1}. ${check}`)) fail(checksFile, `the heading of check ${index + 1} does not match the published wording: ${check}`);
  });
  scoreBands.forEach((band, index) => {
    if (!skillLines.includes(`| ${scoreRanges[index]} | ${band} |`)) fail(skillFile, `the score band ${scoreRanges[index]} does not match the published wording: ${band}`);
  });
  const dataPathFile = path.join(aiSkill, "references", "data-path.md");
  const dataPathLines = visibleLines(linesOf(dataPathFile));
  sameLines(dataPathFile, sectionLines(dataPathLines, "## The ten stops").filter(line => /^\| /.test(line)).slice(2), tenStops.map((stop, i) => `| ${stop} | ${stopRows[i]} |`), "the ten stops");
  sameLines(dataPathFile, sectionLines(dataPathLines, "## The eight leak paths").filter(line => /^\d+\. /.test(line)), eightLeakPaths.map((leak, i) => `${i + 1}. ${leak}`), "the eight leak paths");
  tenStops.forEach((stop) => {
    if (!dataPathLines.some((line) => line.startsWith(`| ${stop} | `))) fail(dataPathFile, `a stop does not match the published wording: ${stop}`);
  });
  eightLeakPaths.forEach((leak, index) => {
    if (!dataPathLines.includes(`${index + 1}. ${leak}`)) fail(dataPathFile, `leak path ${index + 1} does not match the published wording: ${leak}`);
  });
  const costFile = path.join(aiSkill, "references", "cost.md");
  const costLines = linesOf(costFile);
  sameLines(costFile, sectionLines(visibleLines(costLines), "## The seven columns").filter(line => /^\| `/.test(line)).map(line => line.split("|")[1].trim()), costColumns.map(column => "`" + column + "`"), "the seven cost columns");
  const querySection = sectionLines(costLines.join("\n").replace(/<!--[\s\S]*?-->/g, "").split("\n"), "## The published query");
  const queryFences = querySection.flatMap((line, i) => /^```/.test(line) ? [i] : []);
  if (queryFences.length !== 2 || querySection[queryFences[0]] !== "```sql" || querySection[queryFences[1]] !== "```") {
    fail(costFile, "the published query needs exactly one SQL code block");
  } else {
    sameLines(costFile, querySection.slice(queryFences[0] + 1, queryFences[1]), costQuery, "the complete published query");
  }
  costColumns.forEach((column) => {
    if (!costLines.some((line) => line.startsWith(`| \`${column}\` | `))) fail(costFile, `the cost column ${column} is missing from the table of seven columns`);
  });
  const queryStart = costLines.indexOf(costQuery[0]);
  if (queryStart === -1) {
    fail(costFile, "the published cost query is missing");
  } else {
    costQuery.forEach((line, index) => {
      if (costLines[queryStart + index] !== line) fail(costFile, `line ${index + 1} of the cost query does not match the published query: ${line}`);
    });
  }
  const expectedFile = path.join(root, "tests", "fixtures", "ai-feature-architecture-check", "EXPECTED.md");
  const expectedLines = linesOf(expectedFile);
  if (expectedLines.length > 0) {
    twelveChecks.forEach((check, index) => {
      if (!expectedLines.some((line) => line.startsWith(`| ${index + 1} | ${check} | `))) fail(expectedFile, `check ${index + 1} does not match the published wording: ${check}`);
    });
    eightLeakPaths.forEach((leak, index) => {
      if (!expectedLines.some((line) => line.startsWith(`| ${index + 1} | ${leak} | `))) fail(expectedFile, `leak path ${index + 1} does not match the published wording: ${leak}`);
    });
  }
}

// The serverless deploy check keeps one wording for its eighteen checks, its statuses,
// its verdicts, and the order of the first three, so that a takeaway can be cut from them.
const eighteenChecks = [
  "E1. Every function sets its memory, and its CPU, where the platform has a setting.",
  "E2. Every function has a time limit that is set on purpose and sits below the platform's maximum.",
  "E3. Concurrency and fan-out have a ceiling.",
  "E4. The runtime and the CPU architecture are current.",
  "E5. The deploy package holds only what the function runs.",
  "E6. Clients and connections are created once and reused, through a pooler where the database needs one.",
  "E7. Large request and response bodies are streamed, not held in memory.",
  "E8. Start-up work is small.",
  "S1. Every public entry point checks who is calling, or is public on purpose.",
  "S2. Each function's permissions cover only what it uses.",
  "S3. Secrets live in the platform's secret store, not in configuration or code.",
  "S4. No server secret reaches the browser bundle.",
  "S5. The data layer enforces access itself.",
  "S6. Webhook and scheduled endpoints verify the caller.",
  "S7. Requests meet a size limit and a rate limit before they cost money.",
  "S8. Cross-origin rules name their origins.",
  "S9. Deploys use short-lived credentials.",
  "S10. Logs leave out secrets and request bodies, and have a retention period.",
];
const serverlessStatuses = [
  "| pass | Every part of the check is met, with evidence. | 1 |",
  "| warn | Part of the check is met, and the missing part would be in the repository. | 0 |",
  "| fail | The check is not met, or nothing for it is found in the repository. | 0 |",
  "| ask the team | The part that the repository can show is met, and the rest sits outside it. | 0 |",
  "| does not apply | No platform in the repository has this setting. | not counted |",
];
const serverlessVerdicts = [
  "| Not ready to deploy | Any of S1 to S5 is a fail. |",
  "| Ready after the first three | No fail in S1 to S5, and at least one of the eighteen checks is a fail or a warn. |",
  "| Ready from what the repository shows | No fail and no warn. |",
];
const firstThreeOrder = "Order: S3, S4, S1, S5, S2, S6, S7, E3, S8, S9, S10, E1, E2, E4, E5, E6, E7, E8.";
const serverlessSkill = path.join(skillsDir, "serverless-deploy-check");
if (existsSync(serverlessSkill)) {
  const linesOf = (file) => (existsSync(file) ? visibleLines(read(file).split("\n")) : []);
  const skillFile = path.join(serverlessSkill, "SKILL.md");
  const skillLines = linesOf(skillFile);
  const checksFile = path.join(serverlessSkill, "references", "checks.md");
  const checksLines = linesOf(checksFile);
  const checksSection = sectionLines(skillLines, "## The eighteen checks");
  // Whole lines, in their own sections, so that "S1. ..." is not found inside "S10. ...".
  sameLines(skillFile, checksSection.filter((line) => /^[ES]\d+\. /.test(line)), eighteenChecks, "the eighteen checks");
  sameLines(checksFile, checksLines.filter((line) => /^#+ [ES]\d+\. /.test(line)), eighteenChecks.map((check) => `### ${check}`), "the eighteen check headings");
  sameLines(skillFile, checksSection.filter((line) => /^\| (pass|warn|fail|ask the team|does not apply) \|/.test(line)), serverlessStatuses, "the status table");
  sameLines(skillFile, sectionLines(skillLines, "## The verdict").filter((line) => /^\| (Not ready|Ready)/.test(line)), serverlessVerdicts, "the verdict table");
  sameLines(skillFile, sectionLines(skillLines, "## The first three to change").filter((line) => /^Order:/.test(line)), [firstThreeOrder], "the order of the first three");
  sameLines(checksFile, sectionLines(checksLines, "## The first three to change").filter((line) => /^Order:/.test(line)), [firstThreeOrder], "the order of the first three");
  eighteenChecks.forEach((check) => {
    if (!skillLines.includes(check)) fail(skillFile, `a check does not match its fixed wording: ${check}`);
    if (!checksLines.includes(`### ${check}`)) fail(checksFile, `a check heading does not match its fixed wording: ${check}`);
  });
  [...serverlessStatuses, ...serverlessVerdicts, firstThreeOrder].forEach((line) => {
    if (!skillLines.includes(line)) fail(skillFile, `a line does not match its fixed wording: ${line}`);
  });
}

// The Kubernetes workload check keeps one wording for its eighteen checks, its statuses, its verdicts,
// and the order of the first three, and one fixed command list for its cluster script.
const kubernetesChecks = [
  "R1. Every container sets a CPU request and a memory request, init containers and sidecars included.",
  "R2. Every container sets a memory limit.",
  "R3. Each memory limit sits close to its request.",
  "R4. Every autoscaler has what it needs to work.",
  "R5. Every namespace sets defaults or ceilings for CPU and memory.",
  "R6. Scratch space has a ceiling.",
  "R7. Batch work has a deadline, and scheduled runs do not pile up.",
  "R8. Requests match measured use.",
  "K1. No container runs as root or privileged.",
  "K2. Every container drops all capabilities and blocks privilege escalation.",
  "K3. Every container's root filesystem is read-only.",
  "K4. No pod shares the host's network, processes, or files.",
  "K5. Each workload has its own ServiceAccount, and mounts a token only when it calls the API.",
  "K6. RBAC rules name their verbs and their resources.",
  "K7. Secrets stay out of manifests and values files.",
  "K8. A NetworkPolicy covers every workload.",
  "K9. Every image is pinned by digest and comes from a named registry.",
  "K10. Every namespace enforces the restricted Pod Security level.",
];
const kubernetesStatuses = [
  "| pass | Every part of the check is met, from what the reader printed. | 1 |",
  "| warn | The check is met in part, and the missing part would be in the repository. | 0 |",
  "| fail | A printed field breaks the check, or a setting it needs is absent. | 0 |",
  "| ask the team | The part that the repository can show is met, and the rest sits outside it. | 0 |",
  "| does not apply | The environment holds nothing that the check judges. | not counted |",
];
const kubernetesVerdicts = [
  "| Not ready for production | Any of K1, K4, K6, or K7 is a fail. |",
  "| Ready after the first three | None of K1, K4, K6, or K7 is a fail, and at least one of the eighteen checks is a fail or a warn. |",
  "| Ready from what the repository shows | No check is a fail or a warn. |",
];
const kubernetesOrder = "Order: K7, K6, K4, K1, K8, K5, K2, K10, R1, R2, K9, K3, R3, R4, R5, R6, R7.";
const kubernetesRules = [
  'With several workloads in an environment, judge each one. The check gets the weakest status: fail, then warn, then "ask the team", then pass. The evidence names the workload that earned it. A workload whose part does not apply leaves the comparison.',
  'R8 cannot pass from the repository. When R1 fails, R8 does not apply. Otherwise R8 is "ask the team", and the cluster pass is how it is answered. R3 uses a line of this skill\'s own, not a Kubernetes rule: a memory limit of more than twice its request is a warn.',
];
// The rulings of the review: the K7 fail list, K4 on any hostPath, K6 on a cluster-admin binding and its subject rule,
// each once in checks.md, and ground rule 10 with its pointer to the absent-fields table.
const kubernetesRulings = [
  "  - **The fail list.** A name whose last word is `password`, `passwd`, `pass`, `pwd`, `pw`, `passphrase`, `secret`, `token`, `apikey`, `privatekey`, `accesskey`, `secretkey`, `credential`, or `credentials`; or whose last two words are `api key`, `private key`, `access key`, or `secret key`; or that is a single word ending in `password` or `passwd` (`PGPASSWORD`). These names are never on it: `existingSecret`, `secretName`, `secretRef`, `secretKeyRef`, `automountServiceAccountToken`, any name whose word before the last is `existing`, and these exact whole names, in any case: `PWD` (a working directory), `OLDPWD`, and `NOPASSWD`. They stay on the ask list where the reader's wide list marks them. So `DB_PASSWORD`, `smtp.password`, `MAP_TILES_API_KEY`, `partner-api-token`, `PGPASSWORD`, `RABBITMQ_DEFAULT_PASS`, `MYSQL_PWD`, `ADMIN_PW`, and `PASSPHRASE` are on the fail list, and `DB_PASSWORD_FILE`, `TOKEN_TTL`, `tls.secretName`, `existingSecret`, and `auth.enabled` are not.",
  "- **Fail:** a pod prints `host-network=true`, `host-pid=true`, or `host-ipc=true`; or it has a `hostPath` volume, read-only or not. A read-only mount narrows what the pod can change on the node and still shares the node's files (K15). The evidence names each `mount.<volume-name>` line.",
  "- **The `cluster-admin` binding.** A binding to `cluster-admin` fails K6 when any subject reaches a workload: a ServiceAccount (`subject.<n>.kind=ServiceAccount`, the `default` account included), a `User` in the service-account form (`subject.<n>.user-form=service-account`), or a group (`subject.<n>.kind=Group`). Kubernetes authenticates a ServiceAccount as the user `system:serviceaccount:<namespace>:<name>`, RBAC grants a role to the user that a `User` subject names, and every ServiceAccount belongs to the group `system:serviceaccounts` (checked, K16, K27, and K35, 16 Nov 2026). The reader prints no group name, so every group counts.",
  "- **The subject rule.** A subject that reaches a workload is one of the three above. A `User` with `user-form=plain` is a person or a system user, not a workload, and is not a K6 case. A `User` with `user-form=other` is \"ask the team\" in K6, and \"not found in the repository\" in the reach map. The subject rule decides two things only: the built-in roles (the `cluster-admin` fail, and the `admin` and `edit` warn), and the marks of the reach map. A Role or ClusterRole defined in the repository is judged on its own rules, whatever binds it.",
];
// The subject rules of the reach map: what each subject reaches, and the order inside the cell.
const kubernetesReachRules = [
  "- A ServiceAccount subject (`subject.<n>.kind=ServiceAccount`) reaches exactly the account that its `subject.<n>.name` and `subject.<n>.namespace` give, whatever kind of binding holds it and wherever the binding lives.",
  "- A `User` in the service-account form (`subject.<n>.user-form=service-account`) reaches the account of every workload of the environment, whatever the binding's kind or namespace. The reader never prints a `User` name, and the name can give an account in any namespace, so the reader cannot tie the subject to one account.",
  "- A group (`subject.<n>.kind=Group`) reaches the account of every workload of the environment, whatever the binding's kind or namespace. The reader prints no group name, so every group counts.",
  "A `User` with `user-form=other` may be a ServiceAccount in the user form, and the reader could not tell. Every workload of the environment, whatever the binding's kind or namespace, gets \"not found in the repository\" in this cell, with the reason. A `User` with `user-form=plain` is a person or a system user, and reaches no workload.",
  "The kind of the binding decides only where the rights apply: a RoleBinding gives them inside its own namespace, and a ClusterRoleBinding gives them in the whole cluster. The cell says which. The cost of this rule is that workloads other than the one a binding names are marked too, because the reader does not print the name.",
  "Where \"broad\" and \"not found in the repository\" both hold for the cell, the cell is \"broad\", and it still lists the reason for \"not found in the repository\".",
];
const kubernetesRule10 = "10. **A pass needs a field the reader printed.** A README, a comment, or a name never passes a check. A field that is \"not found\" can neither pass nor fail a check: the check is \"ask the team\" at best, and the field is listed under \"Not checked\". The one exception is the table \"Absent fields\" in `references/checks.md`: a key that is absent from an object the reader printed whole means the setting is not made, and the Kubernetes default applies. A field that prints `other`, or sits in a file that was not read, is never the default and never passes.";
// The K7 table: one status for each case, every row of it.
const kubernetesK7Rows = [
  "| Case | Fields | Status |",
  "| --- | --- | --- |",
  "| A Secret with values in the repository | A `Secret` object that prints at least one `secret-key.data` or `secret-key.string-data`, and no `sops=present` | fail |",
  "| A Secret with a SOPS block and a value in clear | `sops=present` and `sops-clear-count` above 0 | fail |",
  "| A Secret encrypted by SOPS | `sops=present` and `sops-clear-count=0` | pass for that object |",
  "| A Secret with a SOPS block and no count | `sops=present` with `sops-clear-count=other`, or with no `sops-clear-count` line | ask the team |",
  "| A Secret whose keys are all empty | only `secret-key.data-empty` or `secret-key.string-data-empty` lines | not a K7 case |",
  "| A sealed or external secret kind | A kind the reader does not read, such as `SealedSecret` or `ExternalSecret` | not a K7 case: \"Not checked\" |",
  "| An env var with a written value and a name on the fail list | `env.<NAME>=literal` | fail |",
  "| An env var with an empty value | `env.<NAME>=literal-empty` | not a K7 case |",
  "| A ConfigMap key or a values key that looks encrypted | `configmap-data.<key>=encrypted` or `values-key.<path>=encrypted` | not a K7 case |",
  "| A key with a value in a values file, named on the fail list | `values-key.<path>=scalar` or `values-key.<path>=block-scalar` with the kind `Values` | fail |",
  "| A key with a value in an `Application`'s inline values, named on the fail list | `values-key.<path>=scalar` or `values-key.<path>=block-scalar` with the kind `Application` or `ApplicationSet` | fail |",
  "| A key with a value in a ConfigMap, named on the fail list | `configmap-data.<key>=scalar` or `configmap-data.<key>=block-scalar`. A ConfigMap gives no secrecy (K21) | fail |",
  "| A key in an `ApplicationSet` list generator, named on the fail list | `list-element.<i>.<j>.<key>` | fail |",
  "| A name on the ask list, in any of the five cases above | `env.<NAME>=literal`, `values-key.<path>=scalar` or `block-scalar`, `configmap-data.<key>=scalar` or `block-scalar`, `list-element.<i>.<j>.<key>` | ask the team |",
  "| A credential-like command or argument item | `args-credential-like-count` above 0 | ask the team |",
  "| A credential-like annotation key with a value | `annotation-credential-like-count` above 0 | ask the team |",
  "| A user part in a repository address | `source.<n>.url-has-user-part=true`. The reader does not tell a user name from a password | ask the team |",
  "| A key or an env entry the reader could not read | `env-other-count` above 0, `values-key-unreadable-count` above 0, `source.<n>.helm-values=other` | ask the team at best; the file and line go under \"Not checked\" |",
];
// The cluster script runs these commands and no others. Each is pinned whole, in order, in the
// script's own block and in the code block of fields.md, so that a command added, removed, or
// changed in either place fails here.
const getColumns = "--no-headers --all-namespaces=false --watch=false --watch-only=false --selector= --field-selector= --ignore-not-found=false --output-watch-events=false --show-kind=false --show-labels=false --show-managed-fields=false --label-columns= --subresource= --allow-missing-template-keys=true --template= --filename= --kustomize= --raw= --request-timeout=20s -o custom-columns=";
const clusterCommands = [
  "kubectl config current-context --kubeconfig= --context= --server= --cluster= --profile=none --cache-dir=",
  "kubectl top pod --containers --namespace=<name> --context=<context> --kubeconfig= --server= --cluster= --profile=none --cache-dir= --no-headers --all-namespaces=false --selector= --field-selector= --show-swap=false --sum=false --request-timeout=20s",
  "kubectl get pods --namespace=<name> --context=<context> --kubeconfig= --server= --cluster= --profile=none --cache-dir= " + getColumns + "POD:.metadata.name,CONTAINERS:.spec.containers[*].name,CPU_REQ:.spec.containers[*].resources.requests.cpu,MEM_REQ:.spec.containers[*].resources.requests.memory,CPU_LIM:.spec.containers[*].resources.limits.cpu,MEM_LIM:.spec.containers[*].resources.limits.memory,STATUS_NAMES:.status.containerStatuses[*].name,RESTARTS:.status.containerStatuses[*].restartCount,LAST_END:.status.containerStatuses[*].lastState.terminated.reason",
  "kubectl get verticalpodautoscalers.autoscaling.k8s.io --namespace=<name> --context=<context> --kubeconfig= --server= --cluster= --profile=none --cache-dir= " + getColumns + "VPA:.metadata.name,TARGET_KIND:.spec.targetRef.kind,TARGET:.spec.targetRef.name,MODE:.spec.updatePolicy.updateMode,RECO_CONTAINER:.status.recommendation.containerRecommendations[*].containerName,CPU_TARGET:.status.recommendation.containerRecommendations[*].target.cpu,MEM_TARGET:.status.recommendation.containerRecommendations[*].target.memory,CPU_LOWER:.status.recommendation.containerRecommendations[*].lowerBound.cpu,MEM_LOWER:.status.recommendation.containerRecommendations[*].lowerBound.memory,CPU_UPPER:.status.recommendation.containerRecommendations[*].upperBound.cpu,MEM_UPPER:.status.recommendation.containerRecommendations[*].upperBound.memory",
  "kubectl get horizontalpodautoscalers.autoscaling --namespace=<name> --context=<context> --kubeconfig= --server= --cluster= --profile=none --cache-dir= " + getColumns + "HPA:.metadata.name,TARGET_KIND:.spec.scaleTargetRef.kind,TARGET:.spec.scaleTargetRef.name,MIN:.spec.minReplicas,MAX:.spec.maxReplicas,CURRENT:.status.currentReplicas,DESIRED:.status.desiredReplicas,METRIC_TYPE:.spec.metrics[*].type,METRIC:.spec.metrics[*].resource.name,UTILIZATION:.spec.metrics[*].resource.target.averageUtilization",
];
const kubernetesSkill = path.join(skillsDir, "kubernetes-workload-check");
if (existsSync(kubernetesSkill)) {
  const linesOf = (file) => (existsSync(file) ? visibleLines(read(file).split("\n")) : []);
  const skillFile = path.join(kubernetesSkill, "SKILL.md");
  const skillLines = linesOf(skillFile);
  const checksFile = path.join(kubernetesSkill, "references", "checks.md");
  const checksLines = linesOf(checksFile);
  const checksSection = sectionLines(skillLines, "## The eighteen checks");
  // Whole lines, in their own sections, so that "K1. ..." is not found inside "K10. ...".
  sameLines(skillFile, checksSection.filter((line) => /^[RK]\d+\. /.test(line)), kubernetesChecks, "the eighteen checks");
  sameLines(checksFile, checksLines.filter((line) => /^#+ [RK]\d+\. /.test(line)), kubernetesChecks.map((check) => `### ${check}`), "the eighteen check headings");
  sameLines(skillFile, checksSection.filter((line) => /^\| (pass|warn|fail|ask the team|does not apply) \|/.test(line)), kubernetesStatuses, "the status table");
  sameLines(skillFile, sectionLines(skillLines, "## The verdict").filter((line) => /^\| (Not ready|Ready)/.test(line)), kubernetesVerdicts, "the verdict table");
  sameLines(skillFile, sectionLines(skillLines, "## The first three to change").filter((line) => /^Order:/.test(line)), [kubernetesOrder], "the order of the first three");
  sameLines(checksFile, sectionLines(checksLines, "## The first three to change").filter((line) => /^Order:/.test(line)), [kubernetesOrder], "the order of the first three");
  kubernetesChecks.forEach((check) => {
    if (!skillLines.includes(check)) fail(skillFile, `a check does not match its fixed wording: ${check}`);
    if (!checksLines.includes(`### ${check}`)) fail(checksFile, `a check heading does not match its fixed wording: ${check}`);
  });
  [...kubernetesStatuses, ...kubernetesVerdicts, kubernetesOrder, ...kubernetesRules].forEach((line) => {
    if (!skillLines.includes(line)) fail(skillFile, `a line does not match its fixed wording: ${line}`);
  });
  // Every row of the two tables, so that an extra row fails whatever its first cell says.
  sameLines(skillFile, checksSection.filter((line) => /^\| /.test(line)), ["| Status | Meaning | Points |", "| --- | --- | --- |", ...kubernetesStatuses], "every row of the status table");
  sameLines(skillFile, sectionLines(skillLines, "## The verdict").filter((line) => /^\| /.test(line)), ["| Verdict | Rule |", "| --- | --- |", ...kubernetesVerdicts], "every row of the verdict table");
  // One order line in each file, and the two rules each once.
  sameLines(skillFile, skillLines.filter((line) => /Order:/.test(line)), [kubernetesOrder], "the one order line");
  sameLines(checksFile, checksLines.filter((line) => /Order:/.test(line)), [kubernetesOrder], "the one order line");
  kubernetesRules.forEach((rule) => sameLines(skillFile, skillLines.filter((line) => line === rule), [rule], "the weakest-status rule and the R3 line"));
  // Each check sits under its own score.
  const sizing = kubernetesChecks.filter((check) => check.startsWith("R"));
  const security = kubernetesChecks.filter((check) => check.startsWith("K"));
  const between = (lines, from, to) => {
    const a = lines.indexOf(from);
    const b = to === null ? lines.length : lines.indexOf(to);
    return a === -1 || b === -1 || b < a ? [] : lines.slice(a + 1, b);
  };
  const isCheck = (line) => /^[RK]\d+\. /.test(line);
  sameLines(skillFile, between(checksSection, "**Sizing**", "**Security**").filter(isCheck), sizing, "the sizing checks under Sizing");
  sameLines(skillFile, between(checksSection, "**Security**", null).filter(isCheck), security, "the security checks under Security");
  sameLines(checksFile, sectionLines(checksLines, "## Sizing").filter((line) => /^#+ [RK]\d+\. /.test(line)), sizing.map((check) => `### ${check}`), "the sizing check headings under Sizing");
  sameLines(checksFile, sectionLines(checksLines, "## Security").filter((line) => /^#+ [RK]\d+\. /.test(line)), security.map((check) => `### ${check}`), "the security check headings under Security");
  const reachFile = path.join(kubernetesSkill, "references", "reach-map.md");
  const reachLines = linesOf(reachFile);
  kubernetesReachRules.forEach((rule) => sameLines(reachFile, reachLines.filter((line) => line === rule), [rule], "a subject rule of the reach map"));
  kubernetesRulings.forEach((rule) => sameLines(checksFile, checksLines.filter((line) => line === rule), [rule], "a ruled rule of checks.md"));
  sameLines(skillFile, skillLines.filter((line) => line === kubernetesRule10), [kubernetesRule10], "ground rule 10 with its pointer to the absent-fields table");
  sameLines(checksFile, between(checksLines, `### ${kubernetesChecks[14]}`, `### ${kubernetesChecks[15]}`).filter((line) => /^\| /.test(line)), kubernetesK7Rows, "every row of the K7 table");
  const script = path.join(kubernetesSkill, "scripts", "read-cluster-usage.sh");
  const scriptLines = existsSync(script) ? read(script).split("\n") : [];
  const begin = scriptLines.indexOf("# BEGIN the fixed command list");
  const end = scriptLines.indexOf("# END the fixed command list");
  const scriptBlock = begin === -1 || end < begin ? [] : scriptLines.slice(begin + 1, end);
  // Every line of the block is one command, CMD_<NAME>='<command>', and nothing else.
  const scriptCommands = scriptBlock.map((line) => /^CMD_[A-Z]+='([^']*)'$/.exec(line)?.[1] ?? `not a command line: ${line}`);
  sameLines(script, scriptCommands, clusterCommands, "the fixed command list of the cluster script");
  const fieldsFile = path.join(kubernetesSkill, "references", "fields.md");
  const fieldsLines = existsSync(fieldsFile) ? read(fieldsFile).split("\n") : [];
  const intro = fieldsLines.findIndex((line) => line.startsWith("The fixed command list of the cluster script"));
  const open = fieldsLines.findIndex((line, i) => i > intro && line === "```text");
  const close = fieldsLines.findIndex((line, i) => i > open && line === "```");
  const fieldsCommands = intro === -1 || open === -1 || close === -1 ? [] : fieldsLines.slice(open + 1, close);
  sameLines(fieldsFile, fieldsCommands, clusterCommands, "the fixed command list of the cluster script");
}

// The nine rows of the agent permissions check keep the wording of the published policy.
const nineRows = [
  ["Repository", "Open branches and pull requests, and comment.", "Push to main, merge, approve its own work, or edit workflow files.", "A branch ruleset with no bypass for the bot, and CODEOWNERS on .github/."],
  ["Identity", "Act as its own bot account or GitHub App.", "Use a person's account or personal access token.", "A GitHub App with the fewest permissions. Its installation tokens expire after an hour."],
  ["Secrets", "Use the secrets of its sandbox.", "Read production secrets or long-lived cloud keys.", "Production secrets only in an environment with required reviewers."],
  ["Cloud", "Read and write in a sandbox account.", "Reach production accounts.", "A separate account, with OIDC roles scoped to it."],
  ["Data", "Work with synthetic or anonymised fixtures.", "Read production customer data.", "No production credentials in the sandbox, and no copies of production data there."],
  ["Runners", "Run in fresh, isolated runners.", "Run on a laptop or a runner with a network path to production.", "GitHub-hosted or ephemeral runners only."],
  ["Outside input", "Read issues, web pages, and READMEs as data.", "Follow instructions found in them.", "No secrets for workflows that outside contributors trigger."],
  ["Review", "Review code as an extra reviewer that comments.", "Give the approving review.", "A required approval from a human code owner."],
  ["Record", "Act under its own identity, with every action in the log.", "Act anonymously or under a shared login.", "An audit log we keep, so last week's agent changes are one query away."],
];
const agentChecks = path.join(skillsDir, "agent-permissions-check", "references", "checks.md");
if (existsSync(agentChecks)) {
  const lines = read(agentChecks).split("\n");
  nineRows.forEach(([area, may, mayNot, enforce], index) => {
    const row = `row ${index + 1} (${area})`;
    if (!lines.includes(`### ${index + 1}. ${area}`)) fail(agentChecks, `${row} has no heading "### ${index + 1}. ${area}"`);
    if (!lines.includes(`- **The agent may:** ${may}`)) fail(agentChecks, `${row}: "The agent may" does not match the published wording: ${may}`);
    if (!lines.includes(`- **The agent may not:** ${mayNot}`)) fail(agentChecks, `${row}: "The agent may not" does not match the published wording: ${mayNot}`);
    if (!lines.includes(`- **How we enforce it:** ${enforce}`)) fail(agentChecks, `${row}: "How we enforce it" does not match the published wording: ${enforce}`);
  });
}

// The guided app starter keeps three properties that a security scan of 14 November 2026 found broken:
// it writes no file outside the project folder, it builds the pipeline from a template that ships
// with the skill, and it does not take direction from the packages it installs.
const starter = path.join(skillsDir, "guided-app-starter");
if (existsSync(starter)) {
  const starterSkill = path.join(starter, "SKILL.md");
  const instructions = walk(starter).filter((file) => file === starterSkill || (file.endsWith(".md") && file.includes(`${path.sep}references${path.sep}`)));
  for (const file of instructions) {
    read(file).split("\n").forEach((line, index) => {
      const at = `line ${index + 1}`;
      // A request body goes to gh on standard input, so no body file exists in any folder.
      if (/gh api\b.*--input\s+(?!-(\s|$))/.test(line)) fail(file, `${at}: gh api must read its body from standard input (--input -), not from a file`);
      if (/\b(ruleset|security|environment)\.json\b/.test(line)) fail(file, `${at}: a request body file is named, and the skill writes none`);
      // The instructions name no web page as the source of a workflow. The bundled template is the source.
      if (line.includes("starter-github-actions-workflow")) fail(file, `${at}: the workflow comes from assets/ci.yml, not from a web page`);
    });
  }
  const template = path.join(starter, "assets", "ci.yml");
  if (!existsSync(template)) fail(starter, "no bundled workflow template at assets/ci.yml");
  else {
    const yaml = read(template);
    const defaultPermissions = /^permissions:\n((?:[ \t]+[^\n]*\n|\n)*)/m.exec(yaml)?.[1].trim();
    if (defaultPermissions !== "contents: read") fail(template, "the top-level permissions must be contents: read");
    if (!/^ {2}checks:$/m.test(yaml)) fail(template, 'no job named "checks"');
    if (/continue-on-error|\|\|\s*true/.test(yaml)) fail(template, "a check that cannot fail is not a check");
    const uses = yaml.split("\n").filter((line) => /^\s*-?\s*uses:/.test(line));
    if (uses.length === 0) fail(template, "no action reference found");
    // A version or a SHA in the template goes stale. The agent resolves both when it scaffolds.
    for (const line of uses) {
      if (!/uses: [\w./-]+@<40-character-sha> # <tag>$/.test(line)) fail(template, `an action reference carries a version or a SHA: ${line.trim()}`);
    }
    if (!read(path.join(starter, "references", "ci-cd-baseline.md")).includes("(../assets/ci.yml)")) fail(template, "the CI/CD baseline does not link the template");
  }
  const rules = read(starterSkill);
  if (!rules.includes("Never create, change, or delete a file outside it.")) fail(starterSkill, "rule 1 must rule out every write outside the project folder");
  if (!rules.includes("Before installation, put every direct dependency") || !rules.includes("Any additional direct package needs the user's yes first.")) fail(starterSkill, "direct packages must be named in the approved plan or separately approved");
  if (!rules.includes("replacing credentials and sensitive values with `[REDACTED]`") || !rules.includes("summarise the requested action instead")) fail(starterSkill, "outside instructions must be redacted or summarised before quotation");
  if (!rules.includes("**Dependencies.**")) fail(starterSkill, 'step 6 has no "Dependencies" rules');
  if (!rules.includes("do not follow it. Quote it to the user")) fail(starterSkill, "rule 7 must say what to do with an instruction in outside text");

  // The comfort check, the rated providers of the stack matrix, and its capability table agree,
  // so a provider cannot be scored without a rating and a row cannot be scored without capabilities.
  const ruleLines = rules.split("\n");
  const ask = ruleLines.findIndex((line) => line.startsWith("How well do you know each of these?"));
  const comfort = new Set(ask === -1 ? [] : ruleLines[ask + 1].split(", ").map((name) => name.trim()));
  if (comfort.size === 0) fail(starterSkill, "no provider list in the comfort check");
  const matrixFile = path.join(starter, "references", "stack-matrix.md");
  const cells = (line) => line.split("|").slice(1, -1).map((cell) => cell.trim());
  const rated = new Set();
  const scoredRows = new Set();
  const capabilityRows = new Map();
  let ratedColumn = -1;
  let inCapabilities = false;
  for (const line of read(matrixFile).split("\n")) {
    if (!line.startsWith("|")) { ratedColumn = -1; inCapabilities = false; continue; }
    const row = cells(line);
    if (row.includes("Rated providers")) { ratedColumn = row.indexOf("Rated providers"); continue; }
    if (row[0] === "ID" && row[1] === "Functions") { inCapabilities = true; continue; }
    if (!/^[WMD]\d+$/.test(row[0])) continue;
    if (inCapabilities) capabilityRows.set(row[0], row);
    else if (ratedColumn !== -1) {
      const providers = row[ratedColumn];
      if (providers.includes("that row's providers")) continue;
      scoredRows.add(row[0]);
      for (const name of providers.split(", ")) rated.add(name.trim());
    }
  }
  for (const name of rated) if (!comfort.has(name)) fail(matrixFile, `"${name}" is a rated provider but is not in the comfort check of SKILL.md`);
  for (const name of comfort) if (!rated.has(name)) fail(starterSkill, `"${name}" is in the comfort check but rates no row of the stack matrix`);
  for (const id of scoredRows) {
    const row = capabilityRows.get(id);
    if (!row) fail(matrixFile, `${id} has no line in "Capabilities by row"`);
    else if (row.length !== 9 || row.some((cell) => cell === "")) fail(matrixFile, `${id} must fill all eight capability cells`);
  }
  for (const id of capabilityRows.keys()) if (!scoredRows.has(id)) fail(matrixFile, `${id} is in "Capabilities by row" but in no platform table`);
}

if (failures.length > 0) {
  console.error(failures.join("\n"));
  console.error(`\n${failures.length} problem(s) in ${skills.length} skill(s).`);
  process.exit(1);
}
console.log(`validate: ${skills.length} skills, ${prose.length} files of copy, no problems.`);
