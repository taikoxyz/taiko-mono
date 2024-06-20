import { sveltekit } from '@sveltejs/kit/vite'
import tsconfigPaths from 'vite-tsconfig-paths'
import { defineConfig } from 'vitest/config'

export default defineConfig({
    plugins: [sveltekit(), tsconfigPaths()],
    test: {
      environment: 'jsdom',
    globals: true,
        include: ['src/**/*.{test,spec}.{js,ts}'],
    },
        optimizeDeps: {
          exclude: ['@urql/svelte'],
        },
        /*
        define: {
          'process.env': {
            'PUBLIC_WALLETCONNECT_PROJECT_ID': ''
          }
        }*/
        // other properties
})
