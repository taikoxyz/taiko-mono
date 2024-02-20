import { sveltekit } from '@sveltejs/kit/vite';
import tsconfigPaths from 'vite-tsconfig-paths';
import { defineConfig } from 'vitest/dist/config';

import { generateBridgeConfig } from './scripts/vite-plugins/generateBridgeConfig';
import { generateChainConfig } from './scripts/vite-plugins/generateChainConfig';
import { generateCustomTokenConfig } from './scripts/vite-plugins/generateCustomTokenConfig';
import { generateEventIndexerConfig } from './scripts/vite-plugins/generateEventIndexerConfig';
import { generateRelayerConfig } from './scripts/vite-plugins/generateRelayerConfig';

export default defineConfig({
  build: {
    sourcemap: true,
  },
  plugins: [
    sveltekit(),
    // This plugin gives vite the ability to resolve imports using TypeScript's path mapping.
    // https://www.npmjs.com/package/vite-tsconfig-paths
    tsconfigPaths(),
    generateBridgeConfig(),
    generateChainConfig(),
    generateRelayerConfig(),
    generateCustomTokenConfig(),
    generateEventIndexerConfig(),
  ],
  test: {
    environment: 'jsdom',
    globals: true,
    include: ['src/**/*.{test,spec}.{js,ts}'],
  },
});
