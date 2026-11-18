import adapter from '@sveltejs/adapter-vercel';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';

/** @type {import('@sveltejs/kit').Config} */
const config = {
  // Consult https://kit.svelte.dev/docs/integrations#preprocessors
  // for more information about preprocessors
  preprocess: vitePreprocess({ script: true }),

  compilerOptions: {
    // Preserve the component constructor, $set, and $on APIs during the Svelte 5 upgrade.
    compatibility: { componentApi: 4 },
  },

  kit: {
    adapter: adapter({
      runtime: 'nodejs22.x',
    }),
  },
};

export default config;
