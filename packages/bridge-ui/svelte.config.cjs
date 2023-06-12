const { withSentryConfig } = require('@sentry/svelte');
const sveltePreprocess = require('svelte-preprocess');

const svelteConfig = {
  compilerOptions: {
    enableSourcemap: true,
  },

  preprocess: sveltePreprocess({
    sourceMap: true,
  }),
};

const sentryOptions = {
  componentTracking: {
    trackComponents: ['BridgeForm', 'Transactions', 'Transaction', 'Faucet'],
  },
};

module.exports = withSentryConfig(svelteConfig, sentryOptions);
