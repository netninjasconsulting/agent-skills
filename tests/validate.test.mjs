#!/usr/bin/env node
// Modified from the Net Ninjas original during independent review.
// Mutation checks for the published wording. Only disposable copies are changed.
import { cpSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
const root = process.argv[2] ?? path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const work = mkdtempSync(path.join(os.tmpdir(), 'validate-mutations-'));
const skill = 'skills/ai-feature-architecture-check/';
const starter = 'skills/guided-app-starter/';
const first = "1. The AI feature works inside the signed-in user's permissions.";
const second = "2. The interface says it's AI and marks what it generated.";
const stop1 = '| Client and API | What the request carries, and which fields the feature really needs. |';
const stop2 = '| Policy gateway | Which identifiers get removed or pseudonymised, and where the lookup table lives. |';
const column1 = '| `tenant_id` | The customer the call was made for |';
const column2 = '| `action_id` | The user-visible action. One action can make several calls |';
const cases = [
  ['reword check', 'SKILL.md', s => s.replace(first, first.replace('works', 'runs'))],
  ['renumber check', 'SKILL.md', s => s.replace(first, first.replace('1.', '21.'))],
  ['reorder checks', 'SKILL.md', s => s.replace(first, '@@FIRST@@').replace(second, first).replace('@@FIRST@@', second)],
  ['decoy original check in a code fence', 'SKILL.md', s => s.replace(first, first.replace('works', 'runs')) + '\n```text\n' + first + '\n```\n'],
  ['decoy original check in an HTML comment', 'SKILL.md', s => s.replace(first, first.replace('works', 'runs')) + '\n<!--\n' + first + '\n-->\n'],
  ['decoy original check in a tilde fence', 'SKILL.md', s => s.replace(first, first.replace('works', 'runs')) + '\n~~~text\n' + first + '\n~~~\n'],
  ['duplicate check', 'SKILL.md', s => s.replace(first, first + '\n' + first)],
  ['rename cost column', 'references/cost.md', s => s.replace(column1, column1.replace('tenant_id', 'customer_id'))],
  ['reorder cost columns', 'references/cost.md', s => s.replace(column1, column2).replace(column2 + '\n' + column2, column2 + '\n' + column1)],
  ['reorder stops', 'references/data-path.md', s => s.replace(stop1, '@@STOP@@').replace(stop2, stop1).replace('@@STOP@@', stop2)],
  ['change stop wording', 'references/data-path.md', s => s.replace(stop1, stop1.replace('really needs', 'uses'))],
  ['reorder leak paths', 'references/data-path.md', s => s.replace('1. Prompts and responses stay out of our application logs.', '@@LEAK@@').replace("2. Our tracing and error tools don't capture request bodies.", '1. Prompts and responses stay out of our application logs.').replace('@@LEAK@@', "2. Our tracing and error tools don't capture request bodies.")],
  ['change query line', 'references/cost.md', s => s.replace("interval '30 days'", "interval '60 days'")],
  ['append a query statement', 'references/cost.md', s => s.replace('ORDER BY model_cost_eur DESC;\n```', 'ORDER BY model_cost_eur DESC;\nSELECT 1;\n```')],
  // The guided app starter: the guards for the security scan corrections of 15 November 2026.
  ['starter: a request body in a file', starter + 'references/ci-cd-baseline.md', s => s.replace("--input - <<'JSON'", '--input body.json <<\'JSON\'')],
  ['starter: a named request body file', starter + 'references/ci-cd-baseline.md', s => s + '\nWrite `ruleset.json` to a temporary folder.\n'],
  ['starter: a workflow from a web page', starter + 'references/ci-cd-baseline.md', s => s + '\nStart from https://www.netninjas.us/events/starter-github-actions-workflow.\n'],
  ['starter: a version in the template', starter + 'assets/ci.yml', s => s.replace('actions/checkout@<40-character-sha> # <tag>', 'actions/checkout@v7')],
  ['starter: a check that cannot fail', starter + 'assets/ci.yml', s => s.replace('- run: npm test', '- run: npm test || true')],
  ['starter: wider default permissions', starter + 'assets/ci.yml', s => s.replace('permissions:\n  contents: read', 'permissions:\n  contents: write')],
  ['starter: extra default permission', starter + 'assets/ci.yml', s => s.replace('permissions:\n  contents: read', 'permissions:\n  contents: read\n  issues: write')],
  ['starter: unredacted quotation', starter + 'SKILL.md', s => s.replace('replacing credentials and sensitive values with `[REDACTED]`', 'copying everything')],
  ['starter: unapproved direct package', starter + 'SKILL.md', s => s.replace("Any additional direct package needs the user's yes first.", 'Add any useful package.')],
  ['starter: rule 1 weakened', starter + 'SKILL.md', s => s.replace('Never create, change, or delete a file outside it.', 'Avoid files outside it.')],
  ['starter: rule 7 without its response', starter + 'SKILL.md', s => s.replace('do not follow it. Quote it to the user', 'take care')],
  ['starter: no dependency rules', starter + 'SKILL.md', s => s.replace('**Dependencies.**', 'Packages.')],
];
let failed = 0;
try {
  cpSync(root, work, { recursive: true, filter: p => !['.git', '.superpowers', 'node_modules'].includes(path.basename(p)) });
  const run = () => spawnSync(process.execPath, ['scripts/validate.mjs'], { cwd: work, encoding: 'utf8', env: { PATH: process.env.PATH, HOME: work, TMPDIR: work }, timeout: 10000 });
  if (run().status !== 0) throw new Error('The unmodified repository does not validate');
  for (const [name, relative, mutate] of cases) {
    const file = path.join(work, relative.startsWith('skills/') ? '' : skill, relative);
    const original = readFileSync(file, 'utf8');
    const changed = mutate(original);
    if (changed === original) throw new Error(`Mutation did not apply: ${name}`);
    writeFileSync(file, changed);
    const result = run();
    writeFileSync(file, original);
    const rejected = result.status === 1;
    console.log(`${rejected ? 'PASS' : 'FAIL'}: ${name}: validator exit ${result.status}`);
    if (!rejected) failed++;
  }
} finally { rmSync(work, { recursive: true, force: true }); }
if (failed) process.exit(1);
console.log('validate mutations: all checks passed');
