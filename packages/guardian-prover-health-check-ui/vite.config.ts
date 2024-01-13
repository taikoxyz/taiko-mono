import { sveltekit } from '@sveltejs/kit/vite';
import tsconfigPaths from 'vite-tsconfig-paths';
import { defineConfig } from 'vitest/dist/config.cjs';

export default defineConfig({
	plugins: [sveltekit(), tsconfigPaths()],
	test: {
		environment: 'jsdom',
		globals: true,
		include: ['src/**/*.{test,spec}.{js,ts}']
	}
});
