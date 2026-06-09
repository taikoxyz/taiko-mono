import path from "path";
import { defineConfig } from "vitest/config";

// Mirrors the path aliases declared in tsconfig.json so the unit tests
// resolve the same modules the app does. The original SvelteKit app pointed a
// handful of these aliases at manual `__mocks__` fixtures; in this Next.js port
// the same fixtures live under `src/tests/mocks` and the generated config files
// under `src/config/generated`.
export default defineConfig({
  test: {
    environment: "jsdom",
    setupFiles: ["./src/tests/setup.ts"],
    globals: true,
    include: ["./src/**/*.{test,spec}.{js,ts,tsx}"],
  },
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
      $components: path.resolve(__dirname, "./src/components"),
      $stores: path.resolve(__dirname, "./src/stores"),
      $config: path.resolve(__dirname, "./src/app.config.ts"),
      $libs: path.resolve(__dirname, "./src/libs"),
      $abi: path.resolve(__dirname, "./src/abi/index.ts"),
      $bridgeConfig: path.resolve(
        __dirname,
        "./src/config/generated/bridgeConfig.ts",
      ),
      $chainConfig: path.resolve(
        __dirname,
        "./src/config/generated/chainConfig.ts",
      ),
      $relayerConfig: path.resolve(
        __dirname,
        "./src/config/generated/relayerConfig.ts",
      ),
      $eventIndexerConfig: path.resolve(
        __dirname,
        "./src/config/generated/eventIndexerConfig.ts",
      ),
      $customToken: path.resolve(
        __dirname,
        "./src/config/generated/customTokenConfig.ts",
      ),
      $nftAPI: path.resolve(__dirname, "./src/libs/nft"),
      $mocks: path.resolve(__dirname, "./src/tests/mocks/index.ts"),
    },
  },
});
