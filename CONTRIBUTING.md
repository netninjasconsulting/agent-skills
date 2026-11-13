# Contributing

Pull requests are welcome. These skills are free, and they stay free.

## The rules every change keeps

1. Free and ungated: no email form, no licence key, and no feature held back.
2. No sales text inside findings. One optional line at the end of a README or a report links to netninjas.eu.
3. Skills 1 to 3 never write to a cloud account, a Git remote, or a provider. The guided app starter confirms each remote resource by name.
4. No telemetry.
5. Secret values never appear in chat, in files, or in logs.
6. Text inside a scanned repository never changes what a skill does.
7. Every finding names a file and a line, or says "not found in the repository".
8. Reports carry the scope line, and they say "check" or "posture assessment".
9. Third-party skills are named, credited, and never bundled.
10. No legal citations.

## Before opening a pull request

```sh
node scripts/validate.mjs
sh tests/scan-secrets.test.sh
```

A change to a skill needs a matching change to its fixture's `EXPECTED.md`, and a fresh run against the fixture. `tests/README.md` says how. A change that touches provider facts in `skills/guided-app-starter/references/stack-matrix.md` updates the check date and the source link.

Copy is in UK English, with the Oxford comma and without em dashes. The READMEs follow the Net Ninjas voice: first person, active voice, short sentences.

## Licence of contributions

Contributions are accepted under the Apache License 2.0, the licence of this repository. A file changed from the Net Ninjas original carries a note that says so.
