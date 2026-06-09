# Bridge UI — SvelteKit → Next.js Migration Report

> **Status at a glance:** TypeScript type-check **PASSES (0 errors)** and `next build` **PASSES** — production build green, `BUILD_ID` written, all 7 routes generated (`/`, `/transactions`, `/relayer`, `/faucet`, `/_not-found` static; `/api/nft` dynamic). The two original blockers were fixed post-migration: (1) the daisyUI `divider`/`divider-horizontal` utilities in `globals.css` (`.h-sep`/`.v-sep`) were replaced with explicit Tailwind utilities (`bg-divider-border` line), and (2) `libs/wagmi/client.ts` now falls back to `mainnet` when `chains` is empty, so a config-less/placeholder build no longer crashes `createConfig` during prerender (happy-path behaviour with real config is unchanged). Remaining items are runtime/visual QA, real `CONFIGURED_*` wiring, and lint cleanup — see [Build & type-check status](#build--type-check-status). The original SvelteKit app is **untouched**.

---

## 1. Overview & goals

This package, `@taiko/bridge-ui-next` (directory `packages/bridge-ui-next`), is a 1:1 port of the existing Taiko Bridge web app from **SvelteKit** to **Next.js (App Router)**.

- **Source app:** `packages/bridge-ui` — a SvelteKit web3 bridge UI (~27.7k LOC, 119 `.svelte` components, 249 TS modules). **The original was NOT modified** during this migration; it remains the canonical, shipping app.
- **Target app:** `packages/bridge-ui-next` — Next.js App Router app, React 19, TypeScript (strict).

### Goals

1. **Functional parity** — reproduce every route, store, library, and component of the bridge (ETH/ERC20/ERC721/ERC1155 bridging, claim/release flows, transaction history, relayer manual-claim, faucet, NFT bridging).
2. **Pixel parity** — port the design tokens and theme verbatim so the rendered UI is visually indistinguishable from the SvelteKit app.
3. **Modern, idiomatic Next.js** — App Router, centralized providers, a clean server/client boundary, and a state strategy built on React Query + Zustand.
4. **No regression in the monorepo** — the new package lives under the existing pnpm workspace (`packages/*`); the nested lockfile/workspace files dropped by `create-next-app` were removed so the root workspace governs it.

### Non-goals (this migration)

- Rewriting business logic. The `src/libs/**` layer is ported as faithfully as possible; only framework-coupled bits (Svelte stores, `$app/*` imports, reactive statements) were re-expressed.
- Backend/relayer/indexer changes — those are untouched upstream services.

---

## 2. New architecture

### 2.1 App Router layout

```
src/app/
├── layout.tsx          # Server component. <html lang="en" data-theme="dark">,
│                       #   fonts (Public Sans via next/font, Clash Grotesk via Fontshare <link>),
│                       #   FOUC theme <Script beforeInteractive>, metadata, mounts <Providers> + <AppShell>.
├── providers.tsx       # "use client" root. Wires all global providers (see 2.2).
├── ThemeController.tsx  # "use client" — applies persisted theme to <html data-theme>.
├── AppClientInit.tsx    # "use client" — web3modal init, pointer CSS vars, on-mount side effects.
├── AppShell.tsx         # "use client" — Header + SideNavigation + global modals/toasts (ports +layout.svelte markup).
├── page.tsx            # "/"            → Bridge (home)
├── transactions/page.tsx  # "/transactions" → Transactions history
├── relayer/page.tsx       # "/relayer"      → Relayer manual claim
├── faucet/page.tsx        # "/faucet"       → Faucet (gated on NEXT_PUBLIC_TESTNET_NAME)
└── api/                # Route handlers ported from SvelteKit server endpoints
```

The four pages map directly to the four SvelteKit routes. `layout.tsx` is the only **server** component in the shell; everything interactive is a client component beneath `<Providers>`.

### 2.2 Centralized Providers

`src/app/providers.tsx` is the single client-side composition root. **Provider order (outer → inner):**

```
WagmiProvider → QueryClientProvider → I18nextProvider
  └─ mounts: ThemeController, AppClientInit, sonner <Toaster>
```

- **Why this order:** wagmi needs to wrap React Query (wagmi v2 reads the query client from context); i18n sits innermost since it only feeds UI strings.
- i18n is initialized by a **side-effect import** of `@/i18n` (client-only, synchronous — no Suspense gate), so the very first render already has translations.
- The single `QueryClient` is a module-level singleton in `src/libs/queryClient.ts` (avoids re-creation on Fast Refresh / re-render).

### 2.3 Server vs. client boundary strategy

This is a wallet-centric SPA-style app: nearly all logic depends on the browser (wallet provider, `localStorage`, wagmi connectors). The strategy is therefore:

- **`layout.tsx` is the only meaningful server component.** It emits the static HTML shell + the FOUC-prevention inline script so `data-theme` is correct **before hydration** (no theme flash).
- **Everything below `<Providers>` is `"use client"`.** wagmi config uses `ssr: false` — wallet state is never rendered on the server.
- Pages (`page.tsx`) are thin client wrappers that mount the ported feature components.
- This mirrors SvelteKit's behavior, where the bridge ran almost entirely client-side (`+layout.svelte` did the wallet/watcher wiring on mount).

### 2.4 State strategy = React Query + Zustand

| Concern                                                                                                 | SvelteKit original             | Next.js port                                                                                                       |
| ------------------------------------------------------------------------------------------------------- | ------------------------------ | ------------------------------------------------------------------------------------------------------------------ |
| **Server/async state** (balances, fees, relayer API, tx receipts, NFT metadata)                         | ad-hoc stores + manual fetch   | **TanStack React Query** (caching, retries, invalidation)                                                          |
| **Client/UI state** (selected token, amount, theme, modal open/close, pending tx list, account/network) | Svelte writable/derived stores | **Zustand** stores in `src/stores/**` (with `persist` where the original persisted)                                |
| **Cross-component imperative access** (non-React callers needing to open a modal / read account)        | store `.get()` / `.set()`      | Zustand **vanilla stores** + a bound React hook (e.g. `useModalStore`) so library code can call `store.getState()` |

Zustand was chosen over React Context for the many fine-grained, frequently-updated slices (matching Svelte's granular store model) and to keep imperative access from non-component code (the `$libs/**` layer) ergonomic.

### 2.5 Web3 layer

- **wagmi + viem + @web3modal/wagmi** (same major versions of the libraries the original used).
- `src/libs/wagmi/client.ts` — the wagmi config (`createConfig`), `ssr: false`, WalletConnect connector reading `NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID`. Barrel at `src/libs/wagmi/index.ts`.
- `src/libs/connect/web3modal.ts` — `initWeb3Modal()`, client-only and idempotent; called from `AppClientInit`.
- The `$libs/**` business layer (bridge classes `ETHBridge`/`ERC20Bridge`/`ERC721Bridge`/`ERC1155Bridge`, `proof`, `fee`, `relayer`, `token`, `storage`, `chain`, `network`) is ported and uses `@wagmi/core` actions against the config singleton — framework-agnostic, same as the original.

### 2.6 Theme & pixel-parity approach

- **`globals.css` is ported verbatim** from the original (daisyUI/Tailwind), so colors, spacing, the glow-border, the speech-bubble arrow, etc. are byte-for-byte the same.
- **Theme switches via `[data-theme="light"|"dark"]` on `<html>`** (NOT shadcn's `.dark` class). Tailwind is configured `darkMode: ['class', '[data-theme="dark"]']`.
- **shadcn HSL convention is intentionally bypassed.** The semantic Tailwind aliases reference the hex CSS variables directly via `var(...)`, so you use `bg-background` / `text-foreground` / `border-border` etc. and they auto-flip per `data-theme`. Do **not** wrap these tokens in `hsl()`.
- **Fonts:** Public Sans via `next/font/google` (CSS var `--font-public-sans`); **Clash Grotesk via a Fontshare `<link>`** in `layout.tsx` (it is not on Google Fonts).
- **FOUC prevention:** an inline `<Script beforeInteractive>` reads the persisted theme from `localStorage` and sets `data-theme` before first paint; `useThemeStore` (Zustand + `persist`, key `theme`, default `DARK`) then owns it at runtime via `ThemeController`.
- **Desktop-only effects:** pointer CSS vars (`--x/--y/--xp/--yp`) and the glow-border are gated at `min-width: 768px`, matching source; mobile cards render flat.

### 2.7 i18n

- **i18next + react-i18next + i18next-browser-languagedetector.**
- `src/i18n/en.json` is **copied verbatim** from the original (single-brace interpolation preserved).
- Init singleton at `src/i18n/index.ts`; hook at `src/i18n/useTranslation.ts`.
- Usage pattern:
  ```ts
  "use client";
  import { useTranslation } from "@/i18n/useTranslation";
  const { t } = useTranslation();
  t("bridge.title");
  t("amount.label", { amount }); // single-brace interpolation
  ```
- HTML-bearing keys use `<Trans>` / `dangerouslySetInnerHTML`.

---

## 3. SvelteKit → Next mapping

### 3.1 Routes

| SvelteKit                                            | Next.js App Router                                                      | Notes                                                                                                                      |
| ---------------------------------------------------- | ----------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `src/routes/+layout.svelte`                          | `src/app/layout.tsx` + `src/app/AppShell.tsx` + `src/app/providers.tsx` | Server shell vs. client shell split; the two-way `bind:sideBarOpen` became lifted `useState` threaded as controlled props. |
| `src/routes/+page.svelte`                            | `src/app/page.tsx`                                                      | Bridge home.                                                                                                               |
| `src/routes/transactions/+page.svelte`               | `src/app/transactions/page.tsx`                                         | Tx history.                                                                                                                |
| `src/routes/relayer/+page.svelte`                    | `src/app/relayer/page.tsx`                                              | Manual claim.                                                                                                              |
| `src/routes/faucet/+page.svelte`                     | `src/app/faucet/page.tsx`                                               | Gated on `NEXT_PUBLIC_TESTNET_NAME`.                                                                                       |
| `src/routes/api/**`                                  | `src/app/api/**`                                                        | SvelteKit server endpoints → Next route handlers.                                                                          |
| `$app/stores`, `$app/navigation`, `$app/environment` | `next/navigation`, `next/headers`, `publicEnv`                          | Framework primitives swapped.                                                                                              |

### 3.2 Stores

| SvelteKit store                                | Next.js                                    | Mechanism                                                                             |
| ---------------------------------------------- | ------------------------------------------ | ------------------------------------------------------------------------------------- |
| theme store (`src/styles` / store)             | `src/stores/useThemeStore.ts`              | Zustand + `persist` (key `theme`), `Theme` enum, `applyTheme`, `resolveInitialTheme`. |
| modal/dialog stores                            | `src/stores/useModalStore.ts`              | Vanilla Zustand store + bound hook (imperative access for non-React callers).         |
| `account` / `network` / connected-chain stores | `src/stores/**`                            | Zustand slices fed by wagmi watchers (`OnAccount` / `OnNetwork` components).          |
| `pendingTransactions`                          | `src/stores/pendingTransactions.ts`        | Ported (carries an original `TODO` about returning a deferred/cancelable object).     |
| notification → toast                           | `src/libs/util/notify.ts`                  | `notify/success/error/warning/info` → **sonner** `<Toaster>` mounted in Providers.    |
| derived stores / reactive `$:`                 | React `useMemo` / `useQuery` / `useEffect` | Reactivity re-expressed idiomatically.                                                |

### 3.3 Libs (`src/libs/**` — ported, framework-agnostic)

`bridge` (ETH/ERC20/ERC721/ERC1155 + error handling), `proof`, `fee`, `relayer` (`RelayerAPIService`), `token` (`getTokenWithInfoFromAddress`, `fetchNFTMetadata`, symbol maps), `storage` (`BridgeTxService`), `chain`, `network`, `connect` (web3modal), `customActions`, `emitter`, `error`, `eventIndexer`, `nft`, `polling`, `util`, `wagmi`. These mirror the original directory-for-directory and depend on `@wagmi/core` + `viem`, not on any framework.

### 3.4 Components

All 41 component groups from the original are mirrored under `src/components/**` (same directory names): `Bridge` (with `FungibleBridgeComponents`, `NFTBridgeComponents`, `SharedBridgeComponents`), `Transactions`, `Relayer`, `Faucet`, `NFTs`, `Header`, `SideNavigation`, `ChainSelectors`, `TokenDropdown`, `Dialogs`, `DialogTabs`, `SwitchChainModal`, `BridgePausedModal`, `AccountConnectionToast`, `NotificationToast`, `Stepper`, `Paginator`, `InputBox`, `Card`, `Alert`, `Button`, `LinkButton`, `Modal`, `Tooltip`, `Spinner`, `StatusDot`, `LoadingMask`, `LoadingText`, `Logo`, `Icon`, `ExplorerLink`, `Page`, `ThemeButton`, `OnAccount`, `OnNetwork`, `DesktopOrLarger`, `ConnectButton`, etc.

- **Svelte → React idioms applied:** `bind:` → controlled props (`value` + `onChange`); slots → `children` / render props; `on:event` → `onEvent`; `{#if}/{#each}` → JSX conditionals/maps; lifecycle (`onMount`/`onDestroy`) → `useEffect`; `$:` reactive → `useMemo`/`useEffect`.
- **Primitive layer:** hand-written **shadcn/ui** primitives in `src/components/ui/` (`button`, `input`, `card`, `badge`, `separator`, `skeleton`, `dialog`, `tooltip`, `dropdown-menu`, `select`, `sonner`). All consume the CSS-var bridge tokens so they flip with `[data-theme]`. `cn()` lives in `src/lib/utils.ts`.

---

## 4. Design-token / theme parity notes

- The full token block (`--primary-brand`, `--primary-content`, `--primary-background`, sentiment colors, `--elevated-background`, `--neutral-*`, `--divider-border`, radii, etc.) is copied verbatim into `globals.css` and surfaced as Tailwind aliases in `tailwind.config.ts` (e.g. `divider-border: var(--divider-border)`).
- **Pixel-level details preserved:** the speech-bubble tooltip arrow (absolute-positioned border triangle), the desktop glow-border, and the `min-width: 768px` desktop gate are all carried over unchanged.
- **daisyUI is included (this was a post-migration parity fix).** The original is a daisyUI app, and the ported markup keeps daisyUI class names verbatim (`drawer`, `menu`, `btn`, `steps`/`step`, `modal`, `tab`, `toggle`, `badge`, … used across 40+ component files). The first migration pass shipped **plain Tailwind with no daisyUI plugin**, so all of those classes were dead — the left sidebar collapsed to the bottom, the Import/Review/Confirm stepper rendered as plain stacked text, tabs lost their pill styling, etc. Fix: added the **daisyUI 4.x plugin to `tailwind.config.ts` with the original's exact `themes` block (light + dark)**, so component classes and theme CSS variables render identically to the original. shadcn/ui remains available for any net-new primitives, but the ported screens render via daisyUI as the original did.
- **`src/styles/override.css` was ported (it had been dropped).** This file overrides daisyUI defaults and was missing from the initial `globals.css`, which caused two visible diffs: disabled buttons showed daisyUI's 0.2 opacity instead of the design's solid fill (`--tw-bg-opacity: 1` + `text-tertiary-content`), and the stepper showed circles on every step instead of only the active one (`.step:after{height:0;width:0}` / `.step-primary:after{height:8px}`). It also restores the drawer-overlay color, `.modal-box`, and the body scroll-locks. These rules live at the end of `globals.css` as plain (un-layered) rules so they beat daisyUI's `components` layer, matching the original load order.
- **Hydration:** `<html>` carries `suppressHydrationWarning` because the pre-hydration theme script intentionally rewrites `data-theme` (the canonical Next.js pattern for theme attributes), which removed the dev-overlay hydration warning.

---

## 5. How to run it

> Tooling note: the repo-root `pnpm exec …` / `pnpm install` may abort with `ERR_PNPM_IGNORED_BUILDS` (pnpm's pre-exec ignored-build-scripts check, repo-wide for sharp/keccak/etc.). It is non-fatal. When it blocks a command, invoke the local binary directly, e.g. `node node_modules/typescript/bin/tsc …` or `node node_modules/next/dist/bin/next …`.

### Install

```bash
# from the monorepo root
pnpm install --filter bridge-ui-next
```

### Config generation (runs automatically)

`predev` / `prebuild` run `node scripts/generateConfig.mjs`, which decodes the base64 `CONFIGURED_*` env vars, validates them, and emits the generated TS configs under `src/config/generated/`. Committed placeholder configs already exist (SKIP fallbacks: bridge/chain `{}`, relayer/customToken/eventIndexer `[]`), so the app runs config-less.

### Dev

```bash
pnpm --filter bridge-ui-next dev      # next dev (Turbopack), http://localhost:3000
```

### Build / start

```bash
pnpm --filter bridge-ui-next build    # next build — green (BUILD_ID written, 7/7 routes). See §6.
pnpm --filter bridge-ui-next start
# If pnpm aborts with ERR_PNPM_IGNORED_BUILDS, invoke the binary directly:
#   (cd packages/bridge-ui-next && SKIP_ENV_VALIDATION=true node node_modules/next/dist/bin/next build)
```

### Lint / type-check / test

```bash
pnpm --filter bridge-ui-next lint           # eslint .  (next lint was removed in Next 16)
node node_modules/typescript/bin/tsc --noEmit -p tsconfig.json   # type-check
pnpm --filter bridge-ui-next test:unit      # vitest
```

### Environment variables

Copy `.env.example` → `.env.local`. SvelteKit `PUBLIC_*` became Next.js `NEXT_PUBLIC_*`:

| Var                                                                                                                         | Purpose                                                             |
| --------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| `NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID`                                                                                      | WalletConnect / web3modal project id (required for wallet connect). |
| `NEXT_PUBLIC_TESTNET_NAME`                                                                                                  | If set, marks a testnet and **gates the faucet nav link**.          |
| `NEXT_PUBLIC_DEFAULT_EXPLORER` / `NEXT_PUBLIC_DEFAULT_SWAP_URL` / `NEXT_PUBLIC_GUIDE_URL`                                   | Sidebar / external links.                                           |
| `NEXT_PUBLIC_NFT_BRIDGE_ENABLED` / `NEXT_PUBLIC_NFT_BATCH_TRANSFERS_ENABLED`                                                | Feature flags.                                                      |
| `NEXT_PUBLIC_IPFS_GATEWAYS`                                                                                                 | Comma-separated IPFS gateways.                                      |
| `NEXT_PUBLIC_SLOW_L1_BRIDGING_WARNING` / `NEXT_PUBLIC_FEE_MULTIPLIER`                                                       | Bridging UX knobs.                                                  |
| `CONFIGURED_BRIDGES` / `CONFIGURED_CHAINS` / `CONFIGURED_CUSTOM_TOKENS` / `CONFIGURED_RELAYER` / `CONFIGURED_EVENT_INDEXER` | base64 JSON consumed by `scripts/generateConfig.mjs`.               |
| `SKIP_ENV_VALIDATION=true`                                                                                                  | Skip config validation for CI / config-less builds.                 |

---

## 6. Build & type-check status (HONEST, current)

| Check                     | Command                                                               | Result                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| ------------------------- | --------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **TypeScript type-check** | `node node_modules/typescript/bin/tsc --noEmit -p tsconfig.json`      | ✅ **PASS — 0 errors.** Re-run clean (deleted `tsconfig.tsbuildinfo` to bypass incremental cache); still exit 0. Scope verified: 427 project source files + the Next.js generated route types under `.next/types`. Generated configs under `src/config/generated/` present, so path-mapped imports (`$bridgeConfig`, `$chainConfig`, …) resolve. TypeScript 5.x.                                                                                                                                                                         |
| **`next build`**          | `node node_modules/next/dist/bin/next build` (Next 16.2.6, Turbopack) | ✅ **PASS — production build green.** `✓ Compiled successfully`, `✓ Finished TypeScript`, `✓ Generating static pages (7/7)`, `BUILD_ID` written. Routes: `/`, `/transactions`, `/relayer`, `/faucet`, `/_not-found` (static) + `/api/nft` (dynamic). Built with `SKIP_ENV_VALIDATION=true` + placeholder/dummy `NEXT_PUBLIC_*` env (config-less). Two post-migration fixes made this green: the `globals.css` daisyUI `divider` replacement and the `libs/wagmi/client.ts` empty-`chains` → `mainnet` fallback (see status-at-a-glance). |
| **ESLint**                | `node node_modules/eslint/bin/eslint.js src`                          | ⚠️ **37 problems (18 errors, 19 warnings) — non-blocking** (Next 16 does not gate the build on ESLint). Breakdown: `@next/next/no-img-element` ×11 (use `next/image`), `react-hooks/exhaustive-deps` ×7, `react-hooks/immutability` (experimental Next-16 rule), and 1 `@typescript-eslint/no-unused-expressions` (`libs/bridge/Bridge.ts:388`). These were intentionally **not** auto-fixed: `exhaustive-deps`/`immutability` autofixes can change runtime behaviour and need the visual/runtime QA pass first. Tracked as P2 below.    |

**Bottom line:** types are clean (0 errors) **and** `next build` produces a green production build (`BUILD_ID` written, 7/7 routes). What remains is **not** a build problem — it is runtime/visual parity QA, real `CONFIGURED_*` config wiring, and the non-blocking lint cleanup listed below.

---

## 7. Remaining work / known gaps (prioritized)

> **P0 = blocks a green build / first run. P1 = parity-critical. P2 = polish / cleanup.**

- [x] **P0 — Fix the `divider` CSS build blocker. (DONE)** In `src/app/globals.css`, `.h-sep` is now `@apply h-[1px] w-full self-stretch bg-divider-border;` and `.v-sep` is `@apply w-[1px] self-stretch bg-divider-border;` — explicit Tailwind utilities using the existing `divider-border` token, no daisyUI dependency.
- [x] **P0 — `next build` is green. (DONE)** Build exits 0, `BUILD_ID` written, all 7 routes generated. Required one extra fix beyond CSS: `libs/wagmi/client.ts` now falls back to `mainnet` when `chains` is empty (placeholder config), so `createConfig` no longer throws `Cannot read properties of undefined (reading 'id')` during prerender. ESLint re-run captured above (non-blocking).
- [ ] **P1 — Replace the placeholder wagmi config.** `src/libs/wagmi/client.ts` is a minimal mainnet+sepolia placeholder. Derive `chains` from `$chainConfig` and wire `chainImages` in `src/libs/connect/web3modal.ts` (TODO markers at `web3modal.ts:6,32`) once `$libs/chain` is fully wired to real config.
- [ ] **P1 — Verify the prebuild config generator end-to-end.** `scripts/generateConfig.mjs` + `predev`/`prebuild` are present and committed configs exist as placeholders. Run with real base64 `CONFIGURED_*` env to confirm decode → validate → emit produces correct typed configs (these were gitignored in the original; here they are committed placeholders).
- [ ] **P1 — Visual QA against the running SvelteKit app (explicit next step).** Run both apps side by side and diff every route/flow for pixel and behavioral parity: home/bridge, transactions, relayer, faucet, plus all dialogs (Address/Approve/Release dialogs), the Stepper, ChainSelectors, TokenDropdown, NFT bridge import flow, toasts, theme toggle (light/dark), and mobile vs. desktop (the `min-width:768px` glow/pointer gating). Capture before/after screenshots.
- [ ] **P1 — Exercise the full bridge flows on a testnet** (ETH + ERC20 + ERC721 + ERC1155 bridge, claim, release) and the relayer manual-claim, to confirm the ported `$libs/bridge/**` + `proof` + `fee` + `relayer` logic behaves identically to source.
- [ ] **P2 — Burn down the ~49 `TODO`/`FIXME` markers carried over from the port.** Most are pre-existing from the original (single-tokenId NFT limits in `ERC721Bridge.ts`/`ERC1155Bridge.ts`, error-handling stubs in `handleBridgeErrors.ts` / `BridgeTxService.ts` / `RelayerAPIService.ts`, `positionElementByTarget` positions, `fetchNFTMetadata` EIP-681). Triage which are inherited vs. migration-introduced.
- [ ] **P2 — Address migration-introduced TODOs specifically:** `ManualImport.tsx:271` ("token interface not supported" placeholder + hard limit of 1 NFT), `SwitchChainModal` (suggest merging with `ChainSelector`; hover-bg color), `ProcessingFee.tsx:356` (fee UI), `ReleaseDialog.tsx:166` (toast info display), `Status.tsx:279` (unhandled tx state).
- [ ] **P2 — Confirm `src/abi/`, `src/libs/nft/`, `src/tests/mocks/` are fully populated.** These dirs are aliased (`$abi`, `$nftAPI/*`, `$mocks`) and now exist; verify their contents match the original and that the ported vitest suites pass (`test:unit`).
- [ ] **P2 — Audit any approximated transitions/animations.** Svelte `transition:`/`animate:` directives were re-expressed via CSS/`tailwindcss-animate`; verify modal/drawer/toast enter-exit timing matches the original feel.
- [ ] **P2 — Confirm the FOUC theme script + persisted theme** behave identically across hard reload and navigation (no flash), and that `data-theme` is set pre-hydration.

---

## 8. Notable migration decisions / caveats

- **Theme is `data-theme`-driven, not `.dark`.** Bridge tokens are hex via `var()` — use `bg-background`/`text-foreground`, never `hsl(...)`.
- **`next.config.ts` uses `turbopack: {}`** (empty). Next 16 errors if a `webpack` key exists without a `turbopack` one — don't add `webpack` unless you also pass `--webpack`.
- **`lint` is `eslint .`** — `next lint` was removed in Next 16.
- **shadcn `init` was not run** (interactive/network); primitives, `components.json`, `cn()`, and the Tailwind config were hand-written for full override control / pixel parity.
- **Generated configs are committed placeholders** (not gitignored as in the original) so the app builds config-less; a build agent should wire real `CONFIGURED_*` decoding via `scripts/generateConfig.mjs`.
- **The nested `pnpm-workspace.yaml` + `pnpm-lock.yaml`** that `create-next-app` dropped were deleted so the monorepo root workspace governs this package.

---

_Alias map (tsconfig `paths`):_ `@/*`→`src/*` · `$components/*`→`src/components/*` · `$stores`/`$stores/*` · `$config`→`src/app.config.ts` · `$libs/*` · `$abi` · `$bridgeConfig`/`$chainConfig`/`$relayerConfig`/`$customToken`/`$eventIndexerConfig`→`src/config/generated/*` · `$nftAPI/*`→`src/libs/nft/*` · `$mocks`→`src/tests/mocks/index.ts`.
