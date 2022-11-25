import { defineConfig } from "vite";
import { svelte } from "@sveltejs/vite-plugin-svelte";
import polyfillNode from "rollup-plugin-polyfill-node";

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [svelte(), polyfillNode()],
});
