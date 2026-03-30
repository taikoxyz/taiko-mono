import { defineConfig, loadEnv } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), "");
  return {
    plugins: [react()],
    resolve: {
      alias: {
        "@": "/src",
      },
    },
    server: {
      proxy: {
        "/api/builder": {
          target: env.VITE_BUILDER_API_URL || "http://127.0.0.1:4545",
          changeOrigin: true,
          followRedirects: true,
          rewrite: (path) => path.replace(/^\/api\/builder/, ""),
        },
      },
    },
  };
});
