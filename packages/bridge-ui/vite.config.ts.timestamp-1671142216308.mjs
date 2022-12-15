// vite.config.ts
import { defineConfig } from "file:///home/jeff/code/taikochain/taiko-mono/node_modules/.pnpm/vite@3.2.4/node_modules/vite/dist/node/index.js";
import { svelte } from "file:///home/jeff/code/taikochain/taiko-mono/node_modules/.pnpm/@sveltejs+vite-plugin-svelte@1.3.1_svelte@3.53.1+vite@3.2.4/node_modules/@sveltejs/vite-plugin-svelte/dist/index.js";
import polyfillNode from "file:///home/jeff/code/taikochain/taiko-mono/node_modules/.pnpm/rollup-plugin-polyfill-node@0.10.2_rollup@2.79.1/node_modules/rollup-plugin-polyfill-node/dist/index.js";
import { viteStaticCopy } from "file:///home/jeff/code/taikochain/taiko-mono/node_modules/.pnpm/vite-plugin-static-copy@0.12.0_vite@3.2.4/node_modules/vite-plugin-static-copy/dist/index.js";
var vite_config_default = defineConfig({
  define: {
    global: "globalThis"
  },
  plugins: [
    svelte(),
    polyfillNode(),
    viteStaticCopy({
      targets: [
        {
          src: "src/assets/lottie/loader.json",
          dest: "lottie"
        }
      ]
    })
  ]
});
export {
  vite_config_default as default
};
//# sourceMappingURL=data:application/json;base64,ewogICJ2ZXJzaW9uIjogMywKICAic291cmNlcyI6IFsidml0ZS5jb25maWcudHMiXSwKICAic291cmNlc0NvbnRlbnQiOiBbImNvbnN0IF9fdml0ZV9pbmplY3RlZF9vcmlnaW5hbF9kaXJuYW1lID0gXCIvaG9tZS9qZWZmL2NvZGUvdGFpa29jaGFpbi90YWlrby1tb25vL3BhY2thZ2VzL2JyaWRnZS11aVwiO2NvbnN0IF9fdml0ZV9pbmplY3RlZF9vcmlnaW5hbF9maWxlbmFtZSA9IFwiL2hvbWUvamVmZi9jb2RlL3RhaWtvY2hhaW4vdGFpa28tbW9uby9wYWNrYWdlcy9icmlkZ2UtdWkvdml0ZS5jb25maWcudHNcIjtjb25zdCBfX3ZpdGVfaW5qZWN0ZWRfb3JpZ2luYWxfaW1wb3J0X21ldGFfdXJsID0gXCJmaWxlOi8vL2hvbWUvamVmZi9jb2RlL3RhaWtvY2hhaW4vdGFpa28tbW9uby9wYWNrYWdlcy9icmlkZ2UtdWkvdml0ZS5jb25maWcudHNcIjtpbXBvcnQgeyBkZWZpbmVDb25maWcgfSBmcm9tIFwidml0ZVwiO1xuaW1wb3J0IHsgc3ZlbHRlIH0gZnJvbSBcIkBzdmVsdGVqcy92aXRlLXBsdWdpbi1zdmVsdGVcIjtcbmltcG9ydCBwb2x5ZmlsbE5vZGUgZnJvbSBcInJvbGx1cC1wbHVnaW4tcG9seWZpbGwtbm9kZVwiO1xuaW1wb3J0IHsgdml0ZVN0YXRpY0NvcHkgfSBmcm9tIFwidml0ZS1wbHVnaW4tc3RhdGljLWNvcHlcIjtcblxuLy8gaHR0cHM6Ly92aXRlanMuZGV2L2NvbmZpZy9cbmV4cG9ydCBkZWZhdWx0IGRlZmluZUNvbmZpZyh7XG4gIGRlZmluZToge1xuICAgIGdsb2JhbDogJ2dsb2JhbFRoaXMnLFxuICB9LFxuICBwbHVnaW5zOiBbXG4gICAgc3ZlbHRlKCksXG4gICAgcG9seWZpbGxOb2RlKCksXG4gICAgdml0ZVN0YXRpY0NvcHkoe1xuICAgICAgdGFyZ2V0czogW1xuICAgICAgICB7XG4gICAgICAgICAgc3JjOiBcInNyYy9hc3NldHMvbG90dGllL2xvYWRlci5qc29uXCIsXG4gICAgICAgICAgZGVzdDogXCJsb3R0aWVcIixcbiAgICAgICAgfSxcbiAgICAgIF0sXG4gICAgfSksXG4gIF0sXG59KTtcbiJdLAogICJtYXBwaW5ncyI6ICI7QUFBMFYsU0FBUyxvQkFBb0I7QUFDdlgsU0FBUyxjQUFjO0FBQ3ZCLE9BQU8sa0JBQWtCO0FBQ3pCLFNBQVMsc0JBQXNCO0FBRy9CLElBQU8sc0JBQVEsYUFBYTtBQUFBLEVBQzFCLFFBQVE7QUFBQSxJQUNOLFFBQVE7QUFBQSxFQUNWO0FBQUEsRUFDQSxTQUFTO0FBQUEsSUFDUCxPQUFPO0FBQUEsSUFDUCxhQUFhO0FBQUEsSUFDYixlQUFlO0FBQUEsTUFDYixTQUFTO0FBQUEsUUFDUDtBQUFBLFVBQ0UsS0FBSztBQUFBLFVBQ0wsTUFBTTtBQUFBLFFBQ1I7QUFBQSxNQUNGO0FBQUEsSUFDRixDQUFDO0FBQUEsRUFDSDtBQUNGLENBQUM7IiwKICAibmFtZXMiOiBbXQp9Cg==
