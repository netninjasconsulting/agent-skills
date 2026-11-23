# Stack matrix

Platform by provider, to framework, data layer, capabilities, and deploy target.

**Checked on 23 November 2026.** Each provider fact below is marked "checked" (read in the provider's own documentation on that date, or on 13 November 2026 for facts carried over from 0.2.0, with sources at the end) or "verify" (not confirmed on that date: read the current documentation before relying on it). Provider offers change often. This file is re-checked at every release of the skill.

## Contents

1. [How to choose](#how-to-choose)
2. [Web](#web)
3. [Mobile](#mobile)
4. [Desktop](#desktop)
5. [Capabilities by row](#capabilities-by-row)
6. [Email](#email)
7. [US regions](#us-regions)
8. [EU regions and what still leaves the EU](#eu-regions-and-what-still-leaves-the-eu)
9. [What each GitHub plan allows](#what-each-github-plan-allows)
10. [Sources](#sources)

## How to choose

1. **Take the table for the platform** from step 1.
2. **Remove rows that fail a hard need.**
   - Data shape "rows and relations" removes rows whose data layer is a document store. "Documents and feeds" removes nothing: a relational or document-relational database can hold documents. Convex is document-relational (tables of documents that reference each other by ID), so it meets either shape.
   - Real-time "yes" removes rows where real-time is "extra provider".
   - Region "the EU, and the data must stay" removes rows marked "not for strict EU residency". Region "the United States", which is also the default when the user gives no answer, removes nothing.
   - A monthly budget under 25 US dollars or euros removes rows marked "hourly-billed parts", and rows whose cell in [Capabilities by row](#capabilities-by-row) is marked "hourly-billed" for a capability the user needs.
3. **Score what is left.**
   - Fit: one point for each of these needs that the user has and that the row meets with no extra provider:
     - sign-in, the data shape, real-time, and file storage (from the platform table)
     - scheduled jobs, workflows, queues, pub/sub, offline sync, full-text search, and vector search (from [Capabilities by row](#capabilities-by-row))
     - EU residency.
   - A relational or document-relational row meets either data shape. EU residency is a need only when the user chose the EU. It then counts for "must stay" and for "a preference" alike, and a row marked "not for strict EU residency" does not meet it. For the United States it is not a need, so it scores nothing for any row.
   - A cell marked "(beta)" meets the need. The recommendation names every beta part that the choice rests on.
   - Functions, payments, and email score nothing. Every row runs server functions. Every row takes payments the same way, through a payment provider's webhook. Every row sends email the same way, through Resend (see [Email](#email)).
   - Comfort: the average of the user's ratings (0 to 3) for the providers in the row's "Rated providers" column.
   - Score = fit + 2 × comfort.
4. **Pick the highest score.** On a tie, take the row with fewer providers. If still tied, take the first row in the table.
5. **Check the winner's comfort.** If its comfort average is below 1 and another row is within 1 point of fit and at least 1 higher in comfort average, recommend that other row and say why.
6. **Name what was ruled out**: the runner-up and the one reason it lost.

If every row is removed in step 2, say which need removed the last ones and ask which need can give. Do not invent a stack that is not in the table.

## Web

| ID | Framework and hosting | Data layer | Sign-in | File storage | Real-time | Rated providers | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| W1 | Next.js on Vercel | Neon Postgres (relational) | Better Auth in the app, on the same database | Vercel Blob | Extra provider | GitHub, Vercel, Neon | |
| W2 | Next.js on Vercel | Supabase Postgres (relational) | Supabase Auth | Supabase Storage | Supabase Realtime | GitHub, Vercel, Supabase | |
| W3 | A framework with a Workers adapter, on Cloudflare Workers with static assets | Cloudflare D1 (relational, SQLite) | Better Auth in the app, on D1 | Cloudflare R2 | Durable Objects | GitHub, Cloudflare | Fewest providers |
| W4 | Same as W3 | Neon Postgres through Hyperdrive (relational) | Better Auth in the app | Cloudflare R2 | Durable Objects | GitHub, Cloudflare, Neon | For data that outgrows SQLite or needs Postgres features |
| W5 | Next.js or Angular on Firebase App Hosting | Cloud Firestore (documents) | Firebase Authentication | Cloud Storage for Firebase | Firestore listeners | GitHub, Firebase | Not for strict EU residency (see below) |
| W6 | Next.js on AWS Amplify Hosting | Amazon RDS or Aurora (relational) | Amazon Cognito | Amazon S3 | AWS AppSync subscriptions | GitHub, AWS | Hourly-billed parts (the database) |
| W7 | Next.js on AWS Amplify Hosting | Amazon DynamoDB (documents) | Amazon Cognito | Amazon S3 | AWS AppSync subscriptions | GitHub, AWS | |
| W8 | Next.js on Vercel | Convex (document-relational) | Convex Auth (beta), in Convex | Convex file storage | Convex reactive queries | GitHub, Vercel, Convex | |
| W9 | Same as W3 | Convex (document-relational) | Convex Auth (beta), in Convex | Convex file storage | Convex reactive queries | GitHub, Cloudflare, Convex | |

Framework notes:

- Cloudflare tells new projects to start on Workers, not on Pages (checked). Frameworks with a Workers adapter include React Router, Astro, SvelteKit, and Next.js through the OpenNext adapter (verify the adapter's status for the chosen framework).
- Amplify Hosting supports Next.js server-side rendering, feature branches, and pull request previews (checked). Its supported Next.js versions trail the newest release (verify before choosing a version).
- Firebase App Hosting supports Next.js 13.5 and later and Angular, builds from a connected GitHub repository, and is available in `europe-west4` (checked).
- Vercel Blob is Vercel's own object storage, on all plans, with private and public stores (checked). Version 0.2.0 of this matrix listed W1's file storage as "extra provider". That was wrong, and it is corrected here.
- Convex is the backend in W8 and W9: database, server functions, file storage, scheduling, search, and real-time. It does not host a server-rendered frontend, so the frontend runs on Vercel or Workers (checked). Convex Auth is in beta (checked). It supports a React app served from a CDN, a full-stack Next.js app, and React Native (checked). For another framework, verify its support, or use Better Auth through Convex's own `@convex-dev/better-auth` component, which also runs inside Convex (checked).

## Mobile

| ID | App | Backend | Sign-in | File storage | Real-time | Rated providers | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| M1 | Expo (React Native) | Supabase Postgres (relational) | Supabase Auth | Supabase Storage | Supabase Realtime | GitHub, Supabase | |
| M2 | Expo (React Native) | Cloud Firestore (documents) | Firebase Authentication | Cloud Storage for Firebase | Firestore listeners | GitHub, Firebase | Not for strict EU residency (see below) |
| M3 | Expo (React Native) | An API from the web table (W1 to W9), chosen by the same rules | From that row | From that row | From that row | GitHub, and that row's providers | For apps with their own server logic |
| M4 | Expo (React Native) | Convex (document-relational) | Convex Auth (beta), in Convex | Convex file storage | Convex reactive queries | GitHub, Convex | |

Builds, store submission, and over-the-air updates run on Expo Application Services (EAS Build, EAS Submit, EAS Update), with EAS Workflows in `.eas/workflows/` or GitHub Actions calling EAS (checked). Expo needs its own account. It is not in the comfort list, so it does not change the score. Store accounts (Apple, Google) belong to the user and are never touched by this skill. Convex has an Expo quickstart (checked).

## Desktop

| ID | App | Backend | Rated providers | Notes |
| --- | --- | --- | --- | --- |
| D1 | Tauri 2 (a web interface in a Rust shell) | None, or a row from the web table chosen by the same rules | GitHub, and that row's providers | Default. Small installers |
| D2 | Electron | None, or a row from the web table | GitHub, and that row's providers | When the app needs Node.js APIs in the main process, or the team already ships Electron |

Tauri 2 is stable (checked). `tauri-apps/tauri-action` builds for macOS, Windows, and Linux on GitHub Actions and uploads to a GitHub Release, and Tauri's updater reads from that release (checked). Code-signing certificates belong to the user: they add them as repository secrets in GitHub's interface, and this skill never sees them.

## Capabilities by row

What each row offers for the capabilities that step 3 asks about, with no extra provider. "Extra provider" means the row needs another vendor for it. M3, D1, and D2 take the cells of the web row they use.

| ID | Functions | Scheduled jobs | Workflows | Queues | Pub/sub | Offline sync | Full-text search | Vector search |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| W1 | Vercel Functions | Vercel Cron Jobs | Vercel Workflow (beta) | Vercel Queues (beta) | Vercel Queues topics (beta) | Extra provider | Postgres full-text search | pgvector on Neon |
| W2 | Vercel Functions, Supabase Edge Functions | Supabase Cron, Vercel Cron Jobs | Vercel Workflow (beta) | Supabase Queues | Supabase Realtime Broadcast | Extra provider | Postgres full-text search | pgvector on Supabase |
| W3 | Workers | Cron Triggers | Cloudflare Workflows | Cloudflare Queues | Durable Objects | Extra provider | D1 with FTS5 | Vectorize |
| W4 | Workers | Cron Triggers | Cloudflare Workflows | Cloudflare Queues | Durable Objects | Extra provider | Postgres full-text search | pgvector on Neon, or Vectorize |
| W5 | Cloud Functions for Firebase | Scheduled functions | Google Cloud Workflows, in the same project | Task queue functions | Pub/Sub triggers | Firestore offline persistence | Extra provider | Firestore vector search |
| W6 | AWS Lambda | Amazon EventBridge Scheduler | AWS Step Functions | Amazon SQS | Amazon SNS or EventBridge | Extra provider | Postgres full-text search | pgvector on RDS or Aurora |
| W7 | AWS Lambda | Amazon EventBridge Scheduler | AWS Step Functions | Amazon SQS | Amazon SNS or EventBridge | Extra provider | Amazon OpenSearch Service (hourly-billed) | Amazon S3 Vectors |
| W8 | Convex functions, Vercel Functions | Convex cron jobs and scheduler | Convex Workflow component | Convex Workpool component | Convex reactive queries | Extra provider | Convex search indexes | Convex vector indexes |
| W9 | Convex functions, Workers | Convex cron jobs and scheduler | Convex Workflow component | Convex Workpool component | Convex reactive queries | Extra provider | Convex search indexes | Convex vector indexes |
| M1 | Supabase Edge Functions | Supabase Cron | Extra provider | Supabase Queues | Supabase Realtime Broadcast | Extra provider | Postgres full-text search | pgvector on Supabase |
| M2 | Cloud Functions for Firebase | Scheduled functions | Google Cloud Workflows, in the same project | Task queue functions | Pub/Sub triggers | Firestore offline persistence | Extra provider | Firestore vector search |
| M4 | Convex functions | Convex cron jobs and scheduler | Convex Workflow component | Convex Workpool component | Convex reactive queries | Extra provider | Convex search indexes | Convex vector indexes |

What the words mean here:

- **Functions**: server code that the provider runs. Every row has them, so they score nothing.
- **Scheduled jobs**: code that runs on a timetable (cron).
- **Workflows**: durable runs of several steps that survive a crash or a deploy, with retries and waits.
- **Queues**: background jobs taken from a queue, with retries.
- **Pub/sub**: one event delivered to several listeners, on the server or to connected clients.
- **Offline sync**: the app keeps working without a network and syncs its changes later. This is different from real-time, which needs a connection.
- **Full-text search** and **vector search**: search by words, and search by meaning over embeddings for AI features.

Notes on the cells:

- Vercel: Queues is in beta (checked). Workflow runs on Vercel Functions and Queues (checked). Verify whether it is still in beta. Vercel Cron Jobs: verify plan limits.
- Neon: `pg_cron` runs only while the compute is active, so W1 and W4 schedule jobs on the host (Vercel Cron Jobs, Cron Triggers), not in Neon (checked). pgvector on Neon: verify.
- Supabase: Queues is built on the `pgmq` extension and stores messages in Postgres (checked). Realtime has Broadcast, Presence, and Postgres Changes (checked). Supabase Cron: checked. Edge Functions and pgvector: verify.
- Cloudflare: D1 supports the FTS5 module for full-text search (checked). Vectorize is generally available (checked). Workflows, Queues, and Durable Objects: verify which of them need the Workers Paid plan, which starts at 5 US dollars a month (checked).
- Firebase: Cloud Functions, and so scheduled functions, task queues, and Pub/Sub triggers, need the pay-as-you-go Blaze plan (checked). Firestore offline persistence is on by default on Android and Apple platforms and off by default on the web (checked). Firestore vector search runs exact nearest-neighbour queries (checked). Verify whether it is still in preview. Full-text search needs an extension backed by another vendor, such as Algolia (checked). Text search in Firestore Enterprise edition is in preview (checked), so it does not count. Google Cloud Workflows and Pub/Sub run in the Firebase project's own Google Cloud project, with no other account (verify).
- AWS: DataStore, Amplify's offline layer, is not part of Amplify Gen 2, and Gen 1 reaches end of life on 1 May 2027 (checked). S3 Vectors is generally available in 14 regions, among them N. Virginia and Frankfurt (checked). OpenSearch Service and pgvector on RDS: verify.
- Convex: cron jobs, the scheduler, file storage, search indexes, and vector indexes are part of Convex (checked). The Workflow and Workpool components are packages maintained by Convex (`@convex-dev/workflow`, `@convex-dev/workpool`) that run inside the deployment (checked), so they go in the plan by name (SKILL.md, step 6). Convex does not provide full offline sync (checked).

## Email

Every row sends email through Resend, the kit's choice for email since 0.3.0. Email scores nothing, because every row uses it the same way.

- Resend needs its own account. It is not in the comfort list, so it does not change the score.
- The API key is a stored secret. The user adds it as `RESEND_API_KEY` in the secret store of the place that sends the email: Vercel, Cloudflare (`wrangler secret put`), Supabase, Firebase, AWS, or the Convex deployment's environment variables. The skill never sees it (SKILL.md, rule 3).
- On W8, W9, and M4, Convex has a Resend component, `@convex-dev/resend` (checked). On the other rows, the app calls Resend from its own server functions.
- The sending region is set per domain in Resend: `us-east-1` (N. Virginia) for the United States, or `eu-west-1` (Ireland) for the EU (checked).
- Verifying the sending domain (its DNS records) is the user's step. The skill names it in the closing summary under "Next three steps".

## US regions

Use these values when the user chose the United States or gave no answer. Each one goes on the confirmation card.

| Provider | US setting to use | What to know |
| --- | --- | --- |
| Vercel | Function region `iad1` (Washington, D.C.), which is also Vercel's default. A Blob store in the same region | Checked. Static files are cached on a global network |
| Neon | Region `aws-us-east-1` (N. Virginia). Other US regions: `aws-us-east-2` (Ohio), `aws-us-west-2` (Oregon) | Checked. The region is set when the project is created and cannot be changed |
| Supabase | A specific region: `us-east-1` (N. Virginia), `us-east-2` (Ohio), `us-west-1` (N. California), or `us-west-2` (Oregon) | Checked. Choose a specific region, not the general "Americas" group. Database, Auth, and Storage stay in the project's region |
| Cloudflare D1 | Location hint `enam` (Eastern North America) or `wnam` (Western North America) | Checked. D1 has no United States jurisdiction: the jurisdictions are `eu` and `fedramp`. A hint is a preference, not a guarantee |
| Cloudflare R2 | Location hint `enam` or `wnam` | Checked. R2 has no United States jurisdiction either. A location hint is not a guarantee |
| Cloudflare Durable Objects | The `us` jurisdiction | Checked. Durable Objects have three jurisdictions: `eu`, `us`, and `fedramp`. A jurisdiction is a guarantee. The location hints `enam` and `wnam` are a best effort and not a guarantee |
| Firebase | Firestore location `nam5` (United States multi-region) or a single US region such as `us-east4` (Northern Virginia). App Hosting in `us-east4` (N. Virginia), `us-central1` (Iowa), or `us-east5` (Columbus) | Checked. The Firestore location cannot be changed later. App Hosting has six regions: these three, `europe-west4`, `asia-east1`, and `asia-southeast1` |
| AWS | Region `us-east-1` (N. Virginia), or `us-east-2` (Ohio), `us-west-2` (Oregon) | Global services such as IAM, CloudFront, and Route 53 are not regional |
| Convex | Region `aws-us-east-1` (N. Virginia). The CLI takes `us` as a short form | Checked. All of the deployment's infrastructure runs in its region. The region is chosen when the deployment is created. Moving it later takes a backup and a restore into a new deployment. US usage is billed at the standard rate |
| Resend | Sending region `us-east-1` (N. Virginia), set when the domain is added | Checked. Account data, email metadata, and logs are stored in the United States |

A US region is a location, not a legal guarantee. Where a provider offers only a hint, say so on the card.

## EU regions and what still leaves the EU

Use these values when the user chose the EU. Each one goes on the confirmation card.

| Provider | EU setting to use | What to know |
| --- | --- | --- |
| Vercel | Function region `fra1` (Frankfurt), set with `"regions": ["fra1"]` in `vercel.json`. Other EU regions: `arn1` (Stockholm), `cdg1` (Paris), `dub1` (Dublin). A Blob store in the same region | Checked. The default function region is `iad1` in the United States. `lhr1` is London, outside the EU. Static files are cached on a global network. Vercel Queues and Workflow: verify where they store data |
| Neon | Region `aws-eu-central-1` (Frankfurt) | Checked. The region is set when the project is created and cannot be changed. `aws-eu-west-2` is London, outside the EU. Neon's Azure regions are being retired |
| Supabase | A specific region: `eu-central-1` (Frankfurt), `eu-west-1` (Ireland), `eu-west-3` (Paris), or `eu-north-1` (Stockholm) | Checked. Choose a specific region, not the general "Europe" group, which can place a project in London or Zurich. Database, Auth, and Storage stay in the project's region, and so do Queues and Cron, which live in the database. Edge Functions run near the caller unless a region is forced |
| Cloudflare D1 | `--jurisdiction eu` when the database is created | Checked. Cannot be added or changed later. It controls where the database runs and stores data. Workers still answer requests from Cloudflare's global network |
| Cloudflare R2 | `--jurisdiction eu` when the bucket is created | Checked. A jurisdiction is a guarantee. A location hint is not |
| Cloudflare Durable Objects | The `eu` jurisdiction | Verify the current syntax in the Durable Objects documentation |
| Cloudflare Queues, Workflows, and Vectorize | No EU setting was confirmed on the check date | Verify before relying on one of them for EU residency |
| Firebase | Firestore location `eur3` (Belgium and the Netherlands) or a single EU region. App Hosting in `europe-west4` | Checked. The Firestore location cannot be changed later. Firebase Authentication: no data location setting was found in the documentation read on the check date (verify). Until that is confirmed, rows with Firebase Authentication are "not for strict EU residency" |
| AWS | Region `eu-central-1` (Frankfurt), or `eu-west-1` (Ireland), `eu-west-3` (Paris), `eu-north-1` (Stockholm) | Global services such as IAM, CloudFront, and Route 53 are not regional |
| Convex | Region `aws-eu-west-1` (Ireland). The CLI takes `eu` as a short form | Checked. All of the deployment's infrastructure runs in its region. EU regions are on every plan, including the free plan. Usage outside the United States is billed at 1.3 times the standard rate. Moving a deployment between regions takes a backup and a restore |
| Resend | Sending region `eu-west-1` (Ireland), set when the domain is added | Checked. The region controls where email is sent from, not where data is stored. Account data, email metadata, and logs are stored in the United States, under Standard Contractual Clauses and the EU-U.S. Data Privacy Framework |

Every row sends some data outside the chosen region: provider account data, billing data, logs and metrics the provider keeps, email data held by Resend, and anything the app sends to a third party (payments, LLM providers). Say so in the recommendation. Whether a setup meets a legal requirement is a question for the user's own counsel.

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

All rows checked on 13 November 2026. When a control is not available, say so, name the plan that has it, and use the fallback in the CI/CD baseline.

## Sources

Read on 13 November 2026:

- Vercel regions: https://vercel.com/docs/regions and https://vercel.com/docs/functions/configuring-functions/region
- Neon regions: https://neon.com/docs/introduction/regions
- Supabase regions: https://supabase.com/docs/guides/platform/regions and https://supabase.com/regions
- Cloudflare D1 data location: https://developers.cloudflare.com/d1/configuration/data-location/
- Cloudflare R2 data location: https://developers.cloudflare.com/r2/reference/data-location/
- Cloudflare Durable Objects data location: https://developers.cloudflare.com/durable-objects/reference/data-location/
- Cloudflare Workers Builds: https://developers.cloudflare.com/workers/ci-cd/builds/
- Firestore locations: https://firebase.google.com/docs/firestore/locations
- Firebase App Hosting, with its locations: https://firebase.google.com/docs/app-hosting/about-app-hosting#locations
- Firebase privacy and security: https://firebase.google.com/support/privacy
- AWS Amplify Hosting: https://docs.aws.amazon.com/amplify/latest/userguide/welcome.html
- Expo CI/CD: https://docs.expo.dev/tutorial/cicd/introduction/
- Tauri on GitHub Actions: https://v2.tauri.app/distribute/pipelines/github
- GitHub rulesets: https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets
- GitHub security features: https://docs.github.com/en/code-security/getting-started/github-security-features
- GitHub environments: https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments

Read on 23 November 2026:

- Convex regions and regional pricing: https://docs.convex.dev/production/regions
- Convex as a document-relational database: https://docs.convex.dev/understanding/overview
- Convex cron jobs: https://docs.convex.dev/scheduling/cron-jobs
- Convex scheduler: https://docs.convex.dev/api/interfaces/server.Scheduler
- Convex file storage: https://docs.convex.dev/file-storage/upload-files
- Convex full-text search: https://docs.convex.dev/search/text-search
- Convex vector search: https://docs.convex.dev/search/vector-search
- Convex Auth, and its beta status: https://docs.convex.dev/auth/overview and https://labs.convex.dev/auth
- Convex and Better Auth: https://docs.convex.dev/client/svelte/authentication
- Convex Workflow and Workpool components: https://github.com/get-convex/workflow and https://github.com/get-convex/workpool
- Convex on Vercel, the Marketplace, and preview deployments: https://docs.convex.dev/production/hosting/vercel
- Convex preview deployments: https://docs.convex.dev/production/multiple-deployments
- Convex custom hosting: https://docs.convex.dev/production/hosting/custom
- Convex React Native quickstart: https://docs.convex.dev/quickstart/react-native
- Convex CLI (login, project, deployment): https://docs.convex.dev/cli/reference/account, https://docs.convex.dev/cli/reference/project, and https://docs.convex.dev/cli/reference/deployment
- Convex and offline sync: https://www.convex.dev/sync
- Convex Resend component: https://docs.convex.dev/config/convex.config.ts
- Resend regions and data residency: https://resend.com/docs/dashboard/domains/regions and https://resend.com/security/gdpr
- Vercel Queues: https://vercel.com/docs/queues and https://vercel.com/docs/queues/concepts
- Vercel Workflows: https://vercel.com/docs/workflows
- Vercel Blob: https://vercel.com/docs/vercel-blob and https://vercel.com/docs/vercel-blob/private-storage
- Neon `pg_cron`: https://neon.com/docs/extensions/pg_cron
- Supabase Queues: https://supabase.com/docs/guides/queues
- Supabase background jobs and Cron: https://supabase.com/kb/faqs/background-jobs/background-job-processing
- Supabase Realtime: https://supabase.com/docs/guides/realtime
- Cloudflare D1 SQL statements and FTS5: https://developers.cloudflare.com/d1/sql-api/sql-statements/
- Cloudflare Vectorize pricing and status: https://developers.cloudflare.com/vectorize/platform/pricing/
- Cloudflare Workers pricing: https://developers.cloudflare.com/workers/platform/pricing/
- Firebase scheduled functions and the Blaze plan: https://firebase.google.com/docs/functions/schedule-functions
- Firestore offline data: https://firebase.google.com/docs/firestore/manage-data/enable-offline
- Firestore vector search: https://firebase.google.com/docs/firestore/vector-search
- Firestore release notes: https://docs.cloud.google.com/firestore/docs/release-notes
- Algolia search for Firestore: https://www.algolia.com/developers/firebase-search-extension/
- Amplify Gen 1 maintenance and DataStore: https://docs.amplify.aws/gen1/swift/build-a-backend/graphqlapi/offline/
- Amazon S3 Vectors: https://aws.amazon.com/about-aws/whats-new/2025/12/amazon-s3-vectors-generally-available
