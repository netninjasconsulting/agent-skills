// Test fixture.
import * as Sentry from "@sentry/node";

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  // Sends request bodies, headers, and user details with every event.
  sendDefaultPii: true,
  integrations: [Sentry.requestDataIntegration({ include: { data: true, headers: true, ip: true } })],
  tracesSampleRate: 1.0,
});
