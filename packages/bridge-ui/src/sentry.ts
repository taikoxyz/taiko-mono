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
  Sentry.init({
    dsn,
    environment,

    integrations: [new Sentry.BrowserTracing()],

    sampleRate: isProd ? 0.6 : 1.0,
    tracesSampleRate: isProd ? 0.6 : 1.0,
    maxBreadcrumbs: 50,
  });
}
