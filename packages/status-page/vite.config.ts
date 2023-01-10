import { defineConfig } from "vite";
import { svelte } from "@sveltejs/vite-plugin-svelte";
import polyfillNode from "rollup-plugin-polyfill-node";
import { viteStaticCopy } from "vite-plugin-static-copy";

// https://vitejs.dev/config/
export default defineConfig({
  define: {
    global: 'globalThis',
    'process.env.NODE_DEBUG': false,
    'process.env.LINK_API_URL': false,
    'process.env.SDK_VERSION': "'unknown'"
  },
  plugins: [
    svelte(),
    polyfillNode(),
    viteStaticCopy({
      targets: [
        {
          src: "src/assets/lottie/loader.json",
          dest: "lottie",
        },
      ],
    }),
  ],
});
