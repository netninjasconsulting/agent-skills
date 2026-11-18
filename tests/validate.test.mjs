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
// The serverless deploy check pins its eighteen checks, its status and verdict tables, and the order of the first three.
const serverless = 'skills/serverless-deploy-check/';
const e1 = 'E1. Every function sets its memory, and its CPU, where the platform has a setting.';
const e2 = 'E2. Every function has a time limit that is set on purpose and sits below the platform\'s maximum.';
const s3 = 'S3. Secrets live in the platform\'s secret store, not in configuration or code.';
const verdict = '| Not ready to deploy | Any of S1 to S5 is a fail. |';
const verdict2 = '| Ready after the first three | No fail in S1 to S5, and at least one of the eighteen checks is a fail or a warn. |';
const statusRow = '| ask the team | The part that the repository can show is met, and the rest sits outside it. | 0 |';
const order = 'Order: S3, S4, S1, S5, S2, S6, S7, E3, S8, S9, S10, E1, E2, E4, E5, E6, E7, E8.';
// The Kubernetes workload check pins its eighteen checks, its status and verdict tables, the order
// of the first three, and the fixed command list of its cluster script.
const kubernetes = 'skills/kubernetes-workload-check/';
const r1 = 'R1. Every container sets a CPU request and a memory request, init containers and sidecars included.';
const r2 = 'R2. Every container sets a memory limit.';
const k7 = 'K7. Secrets stay out of manifests and values files.';
const k8sVerdicts = [
  '| Not ready for production | Any of K1, K4, K6, or K7 is a fail. |',
  '| Ready after the first three | None of K1, K4, K6, or K7 is a fail, and at least one of the eighteen checks is a fail or a warn. |',
  '| Ready from what the repository shows | No check is a fail or a warn. |',
];
const k8sStatusRow = '| ask the team | The part that the repository can show is met, and the rest sits outside it. | 0 |';
const k8sOrder = 'Order: K7, K6, K4, K1, K8, K5, K2, K10, R1, R2, K9, K3, R3, R4, R5, R6, R7.';
const cmdEnd = '# END the fixed command list';
const k8sWeakest = 'With several workloads in an environment, judge each one. The check gets the weakest status: fail, then warn, then "ask the team", then pass. The evidence names the workload that earned it. A workload whose part does not apply leaves the comparison.';
const k8sTwice = 'R8 cannot pass from the repository. When R1 fails, R8 does not apply. Otherwise R8 is "ask the team", and the cluster pass is how it is answered. R3 uses a line of this skill\'s own, not a Kubernetes rule: a memory limit of more than twice its request is a warn.';
const k8sLastStatus = '| does not apply | The environment holds nothing that the check judges. | not counted |';
const k7Row = '| A Secret with values in the repository | A `Secret` object that prints at least one `secret-key.data` or `secret-key.string-data`, and no `sops=present` | fail |';
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
  ['serverless: reword the second verdict rule', 'SKILL.md', s => s.replace(verdict2, verdict2.replace('at least one of the eighteen checks', 'any other check')), serverless],
  ['serverless: reword status row', 'SKILL.md', s => s.replace(statusRow, statusRow.replace('sits outside it', 'is unknown')), serverless],
  ['serverless: change first-three order', 'SKILL.md', s => s.replace(order, order.replace('S3, S4, S1', 'S4, S3, S1')), serverless],
  ['serverless: change first-three order in checks.md', 'references/checks.md', s => s.replace(order, order.replace('S7, E3', 'E3, S7')), serverless],
  ['kubernetes: reword check', 'SKILL.md', s => s.replace(r2, r2.replace('sets', 'has')), kubernetes],
  ['kubernetes: reword check heading', 'references/checks.md', s => s.replace('### ' + k7, '### ' + k7.replace('stay out of', 'are kept out of')), kubernetes],
  ['kubernetes: renumber check', 'SKILL.md', s => s.replace(r2, r2.replace('R2.', 'R9.')), kubernetes],
  ['kubernetes: renumber check heading', 'references/checks.md', s => s.replace('### ' + k7, '### ' + k7.replace('K7.', 'K11.')), kubernetes],
  ['kubernetes: swap two checks', 'SKILL.md', s => s.replace(r1, '@@R1@@').replace(r2, r1).replace('@@R1@@', r2), kubernetes],
  ['kubernetes: swap two check headings', 'references/checks.md', s => s.replace('### ' + r1, '@@R1@@').replace('### ' + r2, '### ' + r1).replace('@@R1@@', '### ' + r2), kubernetes],
  ['kubernetes: duplicate check', 'SKILL.md', s => s.replace(r1, r1 + '\n' + r1), kubernetes],
  ['kubernetes: decoy original check in a code fence', 'SKILL.md', s => s.replace(r2, r2.replace('sets', 'has')) + '\n```text\n' + r2 + '\n```\n', kubernetes],
  ['kubernetes: reword the first verdict row', 'SKILL.md', s => s.replace(k8sVerdicts[0], k8sVerdicts[0].replace('Not ready for production', 'Not ready to ship')), kubernetes],
  ['kubernetes: reword the second verdict row', 'SKILL.md', s => s.replace(k8sVerdicts[1], k8sVerdicts[1].replace('at least one of the eighteen checks', 'any other check')), kubernetes],
  ['kubernetes: reword the third verdict row', 'SKILL.md', s => s.replace(k8sVerdicts[2], k8sVerdicts[2].replace('No check is a fail or a warn.', 'No check is a fail.')), kubernetes],
  ['kubernetes: reword status row', 'SKILL.md', s => s.replace(k8sStatusRow, k8sStatusRow.replace('sits outside it', 'is unknown')), kubernetes],
  ['kubernetes: change first-three order', 'SKILL.md', s => s.replace(k8sOrder, k8sOrder.replace('K7, K6', 'K6, K7')), kubernetes],
  ['kubernetes: change first-three order in checks.md', 'references/checks.md', s => s.replace(k8sOrder, k8sOrder.replace('R6, R7', 'R7, R6')), kubernetes],
  ['kubernetes: an extra status row', 'SKILL.md', s => s.replace(k8sLastStatus, k8sLastStatus + '\n| skip | The team says so. | 1 |'), kubernetes],
  ['kubernetes: an extra verdict row', 'SKILL.md', s => s.replace(k8sVerdicts[2], k8sVerdicts[2] + '\n| Good enough | The team says so. |'), kubernetes],
  ['kubernetes: a second order line', 'SKILL.md', s => s.replace('## The verdict\n', '## The verdict\n\nOrder: R1, R2.\n'), kubernetes],
  ['kubernetes: a second order line in checks.md', 'references/checks.md', s => s.replace('## Known limits\n', '## Known limits\n\nOrder: R1, R2.\n'), kubernetes],
  ['kubernetes: R8 moved under Security', 'SKILL.md', s => s.replace('R8. Requests match measured use.\n\n**Security**\n', '\n**Security**\n\nR8. Requests match measured use.\n'), kubernetes],
  ['kubernetes: R8 heading moved under Security', 'references/checks.md', s => s.replace('\n## Security\n', '\n').replace('### R8. ', '## Security\n\n### R8. '), kubernetes],
  ['kubernetes: a K7 case with another status', 'references/checks.md', s => s.replace(k7Row, k7Row.replace('| fail |', '| ask the team |')), kubernetes],
  ['kubernetes: a K7 case added', 'references/checks.md', s => s.replace(k7Row, k7Row + '\n| A Secret the team trusts | `secret-type` | pass |'), kubernetes],
  ['kubernetes: the R3 line reworded', 'SKILL.md', s => s.replace(k8sTwice, k8sTwice.replace('more than twice', 'more than four times')), kubernetes],
  ['kubernetes: the weakest-status rule reworded', 'SKILL.md', s => s.replace(k8sWeakest, k8sWeakest.replace('the weakest status', 'the most common status')), kubernetes],
  ['kubernetes: a fail-list word dropped', 'references/checks.md', s => s.replace("`pwd`, `pw`, `passphrase`", "`pwd`, `passphrase`"), kubernetes],
  ['kubernetes: an exact-name exclusion dropped', 'references/checks.md', s => s.replace('`PWD` (a working directory), `OLDPWD`, and `NOPASSWD`', '`PWD` (a working directory) and `OLDPWD`'), kubernetes],
  ['kubernetes: the service-account user form dropped', 'references/checks.md', s => s.replace(', a `User` in the service-account form (`subject.<n>.user-form=service-account`),', ','), kubernetes],
  ['kubernetes: the subject rule renamed', 'references/checks.md', s => s.replace('- **The subject rule.**', '- **A note on subjects.**'), kubernetes],
  ['kubernetes: a plain User counted as a workload', 'references/checks.md', s => s.replace('is a person or a system user, not a workload, and is not a K6 case', 'counts like a ServiceAccount'), kubernetes],
  ['kubernetes: an unread User form let through', 'references/checks.md', s => s.replace('A `User` with `user-form=other` is "ask the team"', 'A `User` with `user-form=other` is not a K6 case'), kubernetes],
  ['kubernetes: reach map: a plain User counted as a workload', 'references/reach-map.md', s => s.replace('is a person or a system user, and reaches no workload', 'counts like a ServiceAccount'), kubernetes],
  ['kubernetes: reach map: groups left out', 'references/reach-map.md', s => s.replace('The reader prints no group name, so every group counts', 'The reader prints no group name, so no group counts'), kubernetes],
  ['kubernetes: reach map: a user form narrowed to the binding namespace', 'references/reach-map.md', s => s.replace("(`subject.<n>.user-form=service-account`) reaches the account of every workload of the environment, whatever the binding's kind or namespace.", '(`subject.<n>.user-form=service-account`) reaches the account of every workload in the namespace of a RoleBinding.'), kubernetes],
  ['kubernetes: reach map: not found put before broad', 'references/reach-map.md', s => s.replace('both hold for the cell, the cell is "broad"', 'both hold for the cell, the cell is "not found in the repository"'), kubernetes],
  ['kubernetes: a read-only hostPath let through', 'references/checks.md', s => s.replace('or it has a `hostPath` volume, read-only or not.', 'or it has a `hostPath` volume mounted read-write.'), kubernetes],
  ['kubernetes: the cluster-admin binding softened', 'references/checks.md', s => s.replace('A binding to `cluster-admin` fails K6 when', 'A binding to `cluster-admin` warns on K6 when'), kubernetes],
  ['kubernetes: rule 10 without its pointer', 'SKILL.md', s => s.replace('The one exception is the table "Absent fields" in `references/checks.md`', 'The one exception is a key that is absent'), kubernetes],
  ['kubernetes: a command added to the fixed list', 'scripts/read-cluster-usage.sh', s => s.replace(cmdEnd, "CMD_SECRETS='kubectl get secrets --namespace=<name> -o yaml'\n" + cmdEnd), kubernetes],
  ['kubernetes: a command changed in the fixed list', 'scripts/read-cluster-usage.sh', s => s.replace('--request-timeout=20s -o custom-columns=HPA:', '--request-timeout=20s -o yaml -o custom-columns=HPA:'), kubernetes],
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
  for (const [name, relative, mutate, base = skill] of cases) {
    const file = path.join(work, relative.startsWith('skills/') ? '' : base, relative);
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
