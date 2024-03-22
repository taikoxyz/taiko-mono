import path from 'path';
import { defineProject } from 'vitest/config';

export default defineProject({
  test: {
    environment: 'jsdom',
    // setupFiles: ['./../../setup.ts'],
    setupFiles: ['./src/tests/setup.ts'],
    globals: true,
    include: ['./**/*.{test,spec}.{js,ts}'],
  },
  resolve: {
    alias: {
      $components: path.resolve(__dirname, './src/components'),
      $stores: path.resolve(__dirname, './src/stores'),
      $config: path.resolve(__dirname, './src/app.config.ts'),
      $libs: path.resolve(__dirname, './src/libs'),
      $abi: path.resolve(__dirname, './src/abi/index.ts'),
      $bridgeConfig: path.resolve(__dirname, './__mocks__/$bridgeConfig.ts'),
      $chainConfig: path.resolve(__dirname, './src/generated/chainConfig.ts'),
      $relayerConfig: path.resolve(__dirname, './src/generated/relayerConfig.ts'),
      $customToken: path.resolve(__dirname, './src/generated/customTokenConfig.ts'),
      $mocks: path.resolve(__dirname, './src/tests/mocks/index.ts'),
      '$env/static/public': path.resolve(__dirname, './__mocks__/$env/static/public.ts'),
    },
  },
});
