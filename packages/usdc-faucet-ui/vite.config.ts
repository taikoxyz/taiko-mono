import { sveltekit } from '@sveltejs/kit/vite';
import dotenv from 'dotenv';
import { defineConfig } from 'vite';
import tsconfigPaths from 'vite-tsconfig-paths';

if (process.env.NODE_ENV === 'test') {
  dotenv.config({ path: './.env.test' });
}

export default defineConfig({
  build: {
    sourcemap: true,
  },
  plugins: [sveltekit(), tsconfigPaths({ ignoreConfigErrors: true })],
});
