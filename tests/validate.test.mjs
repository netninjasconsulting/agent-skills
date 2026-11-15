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
const first = "1. The AI feature works inside the signed-in user's permissions.";
const second = "2. The interface says it's AI and marks what it generated.";
const stop1 = '| Client and API | What the request carries, and which fields the feature really needs. |';
const stop2 = '| Policy gateway | Which identifiers get removed or pseudonymised, and where the lookup table lives. |';
const column1 = '| `tenant_id` | The customer the call was made for |';
const column2 = '| `action_id` | The user-visible action. One action can make several calls |';
// The serverless deploy check pins its eighteen checks, its status and verdict tables, and the order of the first three.
const serverless = 'skills/serverless-deploy-check/';
const e1 = 'E1. Every function sets its memory, and its CPU, where the platform has a setting.';
const e2 = 'E2. Every function has a time limit that is set on purpose and sits below the platform\'s maximum.';
const s3 = 'S3. Secrets live in the platform\'s secret store, not in configuration or code.';
const verdict = '| Not ready to deploy | Any of S1 to S5 is a fail. |';
const statusRow = '| ask the team | The part that the repository can show is met, and the rest sits outside it. | 0 |';
const order = 'Order: S3, S4, S1, S5, S2, S6, S7, E3, S8, S9, S10, E1, E2, E4, E5, E6, E7, E8.';
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
  ['serverless: reword check', 'SKILL.md', s => s.replace(e1, e1.replace('sets', 'chooses')), serverless],
  ['serverless: reword check heading', 'references/checks.md', s => s.replace('### ' + s3, '### ' + s3.replace('live', 'sit')), serverless],
  ['serverless: renumber check', 'SKILL.md', s => s.replace(e2, e2.replace('E2.', 'E9.')), serverless],
  ['serverless: renumber check heading', 'references/checks.md', s => s.replace('### ' + e2, '### ' + e2.replace('E2.', 'E12.')), serverless],
  ['serverless: reorder checks', 'SKILL.md', s => s.replace(e1, '@@E1@@').replace(e2, e1).replace('@@E1@@', e2), serverless],
  ['serverless: duplicate check', 'SKILL.md', s => s.replace(e1, e1 + '\n' + e1), serverless],
  ['serverless: decoy original check in a code fence', 'SKILL.md', s => s.replace(e1, e1.replace('sets', 'chooses')) + '\n```text\n' + e1 + '\n```\n', serverless],
  ['serverless: reword verdict', 'SKILL.md', s => s.replace(verdict, verdict.replace('Not ready', 'Not yet ready')), serverless],
  ['serverless: reword status row', 'SKILL.md', s => s.replace(statusRow, statusRow.replace('sits outside it', 'is unknown')), serverless],
  ['serverless: change first-three order', 'SKILL.md', s => s.replace(order, order.replace('S3, S4, S1', 'S4, S3, S1')), serverless],
  ['serverless: change first-three order in checks.md', 'references/checks.md', s => s.replace(order, order.replace('S7, E3', 'E3, S7')), serverless],
];
let failed = 0;
try {
  cpSync(root, work, { recursive: true, filter: p => !['.git', '.superpowers', 'node_modules'].includes(path.basename(p)) });
  const run = () => spawnSync(process.execPath, ['scripts/validate.mjs'], { cwd: work, encoding: 'utf8', env: { PATH: process.env.PATH, HOME: work, TMPDIR: work }, timeout: 10000 });
  if (run().status !== 0) throw new Error('The unmodified repository does not validate');
  for (const [name, relative, mutate, base = skill] of cases) {
    const file = path.join(work, base, relative);
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
