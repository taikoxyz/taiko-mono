import { defineConfig } from "vite";
import { svelte } from "@sveltejs/vite-plugin-svelte";
import polyfillNode from "rollup-plugin-polyfill-node";
import { viteStaticCopy } from "vite-plugin-static-copy";

// https://vitejs.dev/config/
export default defineConfig({
  define: {
    global: 'globalThis',
    process: import.meta
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
