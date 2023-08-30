import { sveltekit } from '@sveltejs/kit/vite';
import tsconfigPaths from 'vite-tsconfig-paths';
import { defineConfig } from 'vitest/config';

import { exportConfigToEnv } from './vite-plugins/exportConfigToEnv';
import { generateBridgeConfig } from './vite-plugins/generateBridgeConfig';
import { generateChainConfig } from './vite-plugins/generateChainConfig';
import { generateCustomTokenConfig } from './vite-plugins/generateCustomTokenConfig';
import { generateRelayerConfig } from './vite-plugins/generateRelayerConfig';

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
  ],
  test: {
    environment: 'jsdom',
    globals: true,
    include: ['src/**/*.{test,spec}.{js,ts}'],
  },
});
