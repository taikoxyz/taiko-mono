import { sveltekit } from '@sveltejs/kit/vite';
import dotenv from 'dotenv';
import tsconfigPaths from 'vite-tsconfig-paths';
import { defineProject } from 'vitest/dist/config';

import { generateBridgeConfig } from './scripts/vite-plugins/generateBridgeConfig';
import { generateChainConfig } from './scripts/vite-plugins/generateChainConfig';
import { generateCustomTokenConfig } from './scripts/vite-plugins/generateCustomTokenConfig';
import { generateEventIndexerConfig } from './scripts/vite-plugins/generateEventIndexerConfig';
import { generateRelayerConfig } from './scripts/vite-plugins/generateRelayerConfig';

if (process.env.NODE_ENV === 'test') {
  dotenv.config({ path: './.env.test' });
}

export default defineProject({
  build: {
    sourcemap: true,
  },
  plugins: [
    sveltekit(),
    // This plugin gives vite the ability to resolve imports using TypeScript's path mapping.
    // https://www.npmjs.com/package/vite-tsconfig-paths
    tsconfigPaths({ ignoreConfigErrors: true }),
    generateBridgeConfig(),
    generateChainConfig(),
    generateRelayerConfig(),
    generateCustomTokenConfig(),
    generateEventIndexerConfig(),
  ],
  test: {
    environment: 'jsdom',
    globals: true,
    include: ['./**/*.{test,spec}.{js,ts}'],
  },
});
