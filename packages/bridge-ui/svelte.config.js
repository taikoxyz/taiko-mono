import adapter from '@sveltejs/adapter-vercel';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';

/** @type {import('@sveltejs/kit').Config} */
const config = {
  // Consult https://kit.svelte.dev/docs/integrations#preprocessors
  // for more information about preprocessors
  preprocess: vitePreprocess({ script: true }),

  compilerOptions: {
    // The app and its component tests still use the Svelte 4 component API
    // (`new Component({ target, props })`). Keep that API working under Svelte 5
    // until the components are migrated to runes.
    compatibility: {
      componentApi: 4,
    },
  },

  kit: {
    adapter: adapter({
      runtime: 'nodejs20.x',
    }),
  },
};

export default config;
