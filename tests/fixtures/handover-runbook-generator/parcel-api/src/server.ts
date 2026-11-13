import * as Sentry from "@sentry/node";
import { Pool } from "pg";
import Stripe from "stripe";

Sentry.init({ dsn: process.env.SENTRY_DSN });

export const pool = new Pool({ connectionString: process.env.DATABASE_URL });
export const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!);
export const exportBucket = process.env.EXPORT_BUCKET;
