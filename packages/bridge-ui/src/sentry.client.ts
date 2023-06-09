import * as Sentry from '@sentry/svelte';

const hostname = globalThis?.location?.hostname ?? 'localhost';
const environment =
  hostname === 'localhost'
    ? 'local'
    : hostname.match(/\.vercel\.app$|\.internal.taiko.xyz$/)
    ? 'development'
    : hostname.match(/\.test\.taiko\.xyz$/)
    ? 'production'
    : 'unknown';

const isProd = environment === 'production';

export function setupSentry(dsn: string) {
  // https://docs.sentry.io/platforms/javascript/guides/svelte/configuration/options/#common-options
  Sentry.init({
    dsn,

    // https://docs.sentry.io/product/sentry-basics/environments/
    environment,

    // https://docs.sentry.io/platforms/javascript/guides/svelte/configuration/options/#max-breadcrumbs
    maxBreadcrumbs: 50,

    // https://docs.sentry.io/platforms/javascript/performance/instrumentation/automatic-instrumentation/
    integrations: [new Sentry.BrowserTracing()],

    // https://docs.sentry.io/platforms/javascript/guides/svelte/configuration/sampling/#sampling-error-events
    sampleRate: isProd ? 0.6 : 1.0,

    // https://docs.sentry.io/platforms/javascript/guides/svelte/configuration/sampling/#sampling-transaction-events
    tracesSampleRate: isProd ? 0.2 : 1.0,
  });
}
