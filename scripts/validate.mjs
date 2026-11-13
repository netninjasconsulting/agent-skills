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
    if (entry.name === ".git" || entry.name === "node_modules") return [];
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
const auditAllowed =
  /security-audit(-skill)?|\b(npm|pnpm|yarn npm|yarn|bun|cargo|composer|bundle) audit\b|\b(pip|cargo|bundler)-audit\b|audit fix|ecosystem's own audit command/gi;

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
  if (!all.includes("https://www.netninjas.eu")) fail(dir, "no link to netninjas.eu");
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

if (failures.length > 0) {
  console.error(failures.join("\n"));
  console.error(`\n${failures.length} problem(s) in ${skills.length} skill(s).`);
  process.exit(1);
}
console.log(`validate: ${skills.length} skills, ${prose.length} files of copy, no problems.`);
