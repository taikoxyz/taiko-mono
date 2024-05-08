# Guardian prover health check UI

This package contains the Guardian prover health check UI built with svelte and wagmi

- [Guardian prover health check UI](#guardian-prover-health-check-ui)
  - [Development setup](#development-setup)
    - [Set up environment variables](#set-up-environment-variables)
    - [Start a development server:](#start-a-development-server)
  - [Building](#building)

## Development setup

To get started, open your terminal in `/packages/guardian-prover-health-check-ui/`

Install all dependencies with

```bash
pnpm install
```

### Set up environment variables

```bash
cp .env.example .env
```

Then update environment variables in .env

```bash
source .env
```

### Set up configurations

```ENV
VITE_GUARDIAN_PROVER_API_URL=
VITE_GUARDIAN_PROVER_CONTRACT_ADDRESS=
VITE_RPC_URL=
```

### Start a development server:

```bash
pnpm dev

# or start the server and open the app in a new browser tab
pnpm dev -- --open

# if you want to expose the IP to your network you can use this flag
pnpm dev --host

```

## Building

To create a production version of your app:

```bash
pnpm run build
```

You can preview the production build with `pnpm run preview`.

To deploy your app, you may need to install an [adapter](https://kit.svelte.dev/docs/adapters) for your target environment.
