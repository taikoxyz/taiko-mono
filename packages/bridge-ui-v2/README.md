# Bridge UI v2

## Developing

Install all dependencies with

```bash
pnpm install
```

### Set up environment variables

```bash
cp .env.example .env

# update environment variables in .env
1
source .env
```

### Set up chain/bridge configurations

There are some additional configuration files you have to fill in or copy from a vault:

| Name                  | Description                                                                              |
| --------------------- | ---------------------------------------------------------------------------------------- |
| **configuredBridges** | Defines the chains that are connected via taiko bridges and lists the contract addresses |
| **configuredChains**  | Defines some metadata for the chains, such as name, icons, explorer URL, etc.            |
| **configuredRelayer** | If chains have a relayer, the URL and the chain IDs it covers are entered here           |

To get started, run the following commands in `/packages/bridge-ui-v2/`

```bash
cp config/sample/configuredBridges.example config/configuredBridges.json
cp config/sample/configuredChains.example config/configuredChains.json
cp config/sample/configuredRelayer.example config/configuredRelayer.json


```

This will generate the config file in `src/generated/` when you start the server or run a build

start a development server:

```bash
pnpm run dev

# or start the server and open the app in a new browser tab
pnpm run dev -- --open
```

## Building

To create a production version of your app:

```bash
npm run build
```

You can preview the production build with `npm run preview`.

> To deploy your app, you may need to install an [adapter](https://kit.svelte.dev/docs/adapters) for your target environment.
