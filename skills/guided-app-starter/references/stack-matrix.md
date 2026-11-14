# Stack matrix

Platform by provider, to framework, data layer, and deploy target.

**Checked on 13 November 2026.** Each provider fact below is marked "checked" (read in the provider's own documentation on that date; sources at the end) or "verify" (not confirmed on that date: read the current documentation before relying on it). Provider offers change often. This file is re-checked at every release of the skill.

## Contents

1. [How to choose](#how-to-choose)
2. [Web](#web)
3. [Mobile](#mobile)
4. [Desktop](#desktop)
5. [US regions](#us-regions)
6. [EU regions and what still leaves the EU](#eu-regions-and-what-still-leaves-the-eu)
7. [What each GitHub plan allows](#what-each-github-plan-allows)
8. [Sources](#sources)

## How to choose

1. **Take the table for the platform** from step 1.
2. **Remove rows that fail a hard need.**
   - Data shape "rows and relations" removes rows whose data layer is a document store. "Documents and feeds" removes nothing: a relational database can hold documents.
   - Real-time "yes" removes rows where real-time is "extra provider".
   - Region "the EU, and the data must stay" removes rows marked "not for strict EU residency". Region "the United States", which is also the default when the user gives no answer, removes nothing.
   - A monthly budget under 25 US dollars or euros removes rows marked "hourly-billed parts".
3. **Score what is left.**
   - Fit: one point for each of these needs that the user has and that the row meets with no extra provider: sign-in, the data shape, real-time, file storage, EU residency. A relational row meets either data shape. EU residency is a need only when the user chose the EU. It then counts for "must stay" and for "a preference" alike, and a row marked "not for strict EU residency" does not meet it. For the United States it is not a need, so it scores nothing for any row. Payments score nothing: every row takes payments the same way, through a payment provider's webhook.
   - Comfort: the average of the user's ratings (0 to 3) for the providers in the row's "Rated providers" column.
   - Score = fit + 2 × comfort.
4. **Pick the highest score.** On a tie, take the row with fewer providers. If still tied, take the first row in the table.
5. **Check the winner's comfort.** If its comfort average is below 1 and another row is within 1 point of fit and at least 1 higher in comfort average, recommend that other row and say why.
6. **Name what was ruled out**: the runner-up and the one reason it lost.

If every row is removed in step 2, say which need removed the last ones and ask which need can give. Do not invent a stack that is not in the table.

## Web

| ID | Framework and hosting | Data layer | Sign-in | File storage | Real-time | Rated providers | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| W1 | Next.js on Vercel | Neon Postgres (relational) | Better Auth in the app, on the same database | Extra provider | Extra provider | GitHub, Vercel, Neon | |
| W2 | Next.js on Vercel | Supabase Postgres (relational) | Supabase Auth | Supabase Storage | Supabase Realtime | GitHub, Vercel, Supabase | |
| W3 | A framework with a Workers adapter, on Cloudflare Workers with static assets | Cloudflare D1 (relational, SQLite) | Better Auth in the app, on D1 | Cloudflare R2 | Durable Objects | GitHub, Cloudflare | Fewest providers |
| W4 | Same as W3 | Neon Postgres through Hyperdrive (relational) | Better Auth in the app | Cloudflare R2 | Durable Objects | GitHub, Cloudflare, Neon | For data that outgrows SQLite or needs Postgres features |
| W5 | Next.js or Angular on Firebase App Hosting | Cloud Firestore (documents) | Firebase Authentication | Cloud Storage for Firebase | Firestore listeners | GitHub, Firebase | Not for strict EU residency (see below) |
| W6 | Next.js on AWS Amplify Hosting | Amazon RDS or Aurora (relational) | Amazon Cognito | Amazon S3 | AWS AppSync subscriptions | GitHub, AWS | Hourly-billed parts (the database) |
| W7 | Next.js on AWS Amplify Hosting | Amazon DynamoDB (documents) | Amazon Cognito | Amazon S3 | AWS AppSync subscriptions | GitHub, AWS | |

Framework notes:

- Cloudflare tells new projects to start on Workers, not on Pages (checked). Frameworks with a Workers adapter include React Router, Astro, SvelteKit, and Next.js through the OpenNext adapter (verify the adapter's status for the chosen framework).
- Amplify Hosting supports Next.js server-side rendering, feature branches, and pull request previews (checked). Its supported Next.js versions trail the newest release (verify before choosing a version).
- Firebase App Hosting supports Next.js 13.5 and later and Angular, builds from a connected GitHub repository, and is available in `europe-west4` (checked).

## Mobile

| ID | App | Backend | Sign-in | File storage | Real-time | Rated providers | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| M1 | Expo (React Native) | Supabase Postgres (relational) | Supabase Auth | Supabase Storage | Supabase Realtime | GitHub, Supabase | |
| M2 | Expo (React Native) | Cloud Firestore (documents) | Firebase Authentication | Cloud Storage for Firebase | Firestore listeners | GitHub, Firebase | Not for strict EU residency (see below) |
| M3 | Expo (React Native) | An API from the web table (W1 to W7), chosen by the same rules | From that row | From that row | From that row | GitHub, and that row's providers | For apps with their own server logic |

Builds, store submission, and over-the-air updates run on Expo Application Services (EAS Build, EAS Submit, EAS Update), with EAS Workflows in `.eas/workflows/` or GitHub Actions calling EAS (checked). Expo needs its own account. It is not in the comfort list, so it does not change the score. Store accounts (Apple, Google) belong to the user and are never touched by this skill.

## Desktop

| ID | App | Backend | Rated providers | Notes |
| --- | --- | --- | --- | --- |
| D1 | Tauri 2 (a web interface in a Rust shell) | None, or a row from the web table chosen by the same rules | GitHub, and that row's providers | Default. Small installers |
| D2 | Electron | None, or a row from the web table | GitHub, and that row's providers | When the app needs Node.js APIs in the main process, or the team already ships Electron |

Tauri 2 is stable (checked). `tauri-apps/tauri-action` builds for macOS, Windows, and Linux on GitHub Actions and uploads to a GitHub Release, and Tauri's updater reads from that release (checked). Code-signing certificates belong to the user: they add them as repository secrets in GitHub's interface, and this skill never sees them.

## US regions

Use these values when the user chose the United States or gave no answer. Each one goes on the confirmation card.

| Provider | US setting to use | What to know |
| --- | --- | --- |
| Vercel | Function region `iad1` (Washington, D.C.), which is also Vercel's default | Checked. Static files are cached on a global network |
| Neon | Region `aws-us-east-1` (N. Virginia). Other US regions: `aws-us-east-2` (Ohio), `aws-us-west-2` (Oregon) | Checked. The region is set when the project is created and cannot be changed |
| Supabase | A specific region: `us-east-1` (N. Virginia), `us-east-2` (Ohio), `us-west-1` (N. California), or `us-west-2` (Oregon) | Checked. Choose a specific region, not the general "Americas" group. Database, Auth, and Storage stay in the project's region |
| Cloudflare D1 | Location hint `enam` (Eastern North America) or `wnam` (Western North America) | Checked. D1 has no United States jurisdiction: the jurisdictions are `eu` and `fedramp`. A hint is a preference, not a guarantee |
| Cloudflare R2 | Location hint `enam` or `wnam` | Checked. R2 has no United States jurisdiction either. A location hint is not a guarantee |
| Cloudflare Durable Objects | Location hint `enam` or `wnam` | Verify whether a `us` jurisdiction is available in the Durable Objects documentation |
| Firebase | Firestore location `nam5` (United States multi-region) or a single US region such as `us-east4` (Northern Virginia). App Hosting in a US region | Checked for Firestore: the location cannot be changed later. Verify the US regions that App Hosting offers |
| AWS | Region `us-east-1` (N. Virginia), or `us-east-2` (Ohio), `us-west-2` (Oregon) | Global services such as IAM, CloudFront, and Route 53 are not regional |

A US region is a location, not a legal guarantee. Where a provider offers only a hint, say so on the card.

## EU regions and what still leaves the EU

Use these values when the user chose the EU. Each one goes on the confirmation card.

| Provider | EU setting to use | What to know |
| --- | --- | --- |
| Vercel | Function region `fra1` (Frankfurt), set with `"regions": ["fra1"]` in `vercel.json`. Other EU regions: `arn1` (Stockholm), `cdg1` (Paris), `dub1` (Dublin) | Checked. The default function region is `iad1` in the United States. `lhr1` is London, outside the EU. Static files are cached on a global network |
| Neon | Region `aws-eu-central-1` (Frankfurt) | Checked. The region is set when the project is created and cannot be changed. `aws-eu-west-2` is London, outside the EU. Neon's Azure regions are being retired |
| Supabase | A specific region: `eu-central-1` (Frankfurt), `eu-west-1` (Ireland), `eu-west-3` (Paris), or `eu-north-1` (Stockholm) | Checked. Choose a specific region, not the general "Europe" group, which can place a project in London or Zurich. Database, Auth, and Storage stay in the project's region. Edge Functions run near the caller unless a region is forced |
| Cloudflare D1 | `--jurisdiction eu` when the database is created | Checked. Cannot be added or changed later. It controls where the database runs and stores data. Workers still answer requests from Cloudflare's global network |
| Cloudflare R2 | `--jurisdiction eu` when the bucket is created | Checked. A jurisdiction is a guarantee. A location hint is not |
| Cloudflare Durable Objects | The `eu` jurisdiction | Verify the current syntax in the Durable Objects documentation |
| Firebase | Firestore location `eur3` (Belgium and the Netherlands) or a single EU region. App Hosting in `europe-west4` | Checked. The Firestore location cannot be changed later. Firebase Authentication: no data location setting was found in the documentation read on the check date (verify). Until that is confirmed, rows with Firebase Authentication are "not for strict EU residency" |
| AWS | Region `eu-central-1` (Frankfurt), or `eu-west-1` (Ireland), `eu-west-3` (Paris), `eu-north-1` (Stockholm) | Global services such as IAM, CloudFront, and Route 53 are not regional |

Every row sends some data outside the chosen region: provider account data, billing data, logs and metrics the provider keeps, and anything the app sends to a third party (payments, email, LLM providers). Say so in the recommendation. Whether a setup meets a legal requirement is a question for the user's own counsel.

## What each GitHub plan allows

These decide what step 8 can turn on. Read the repository's visibility and the account's plan before promising a control.

| Control | Public repository | Private repository |
| --- | --- | --- |
| Rulesets (branch protection) | Every plan | GitHub Pro, Team, or Enterprise |
| Secret scanning and push protection | Free | Needs GitHub Secret Protection |
| Dependency review and code scanning (CodeQL) | Free | Needs GitHub Code Security |
| Environments | Every plan | GitHub Pro, Team, or Enterprise |
| Required reviewers on an environment | Every plan | GitHub Enterprise |
| Dependabot alerts and version updates | Every plan | Every plan |

All rows checked. When a control is not available, say so, name the plan that has it, and use the fallback in the CI/CD baseline.

## Sources

Read on 13 November 2026.

- Vercel regions: https://vercel.com/docs/regions and https://vercel.com/docs/functions/configuring-functions/region
- Neon regions: https://neon.com/docs/introduction/regions
- Supabase regions: https://supabase.com/docs/guides/platform/regions and https://supabase.com/regions
- Cloudflare D1 data location: https://developers.cloudflare.com/d1/configuration/data-location/
- Cloudflare R2 data location: https://developers.cloudflare.com/r2/reference/data-location/
- Cloudflare Durable Objects data location: https://developers.cloudflare.com/durable-objects/reference/data-location/
- Cloudflare Workers Builds: https://developers.cloudflare.com/workers/ci-cd/builds/
- Firestore locations: https://firebase.google.com/docs/firestore/locations
- Firebase App Hosting: https://firebase.google.com/docs/app-hosting/about-app-hosting
- Firebase privacy and security: https://firebase.google.com/support/privacy
- AWS Amplify Hosting: https://docs.aws.amazon.com/amplify/latest/userguide/welcome.html
- Expo CI/CD: https://docs.expo.dev/tutorial/cicd/introduction/
- Tauri on GitHub Actions: https://v2.tauri.app/distribute/pipelines/github
- GitHub rulesets: https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets
- GitHub security features: https://docs.github.com/en/code-security/getting-started/github-security-features
- GitHub environments: https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments
