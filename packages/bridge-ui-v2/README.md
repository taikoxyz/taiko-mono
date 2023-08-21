# Bridge UI v2

## Developing

Installed dependencies with `pnpm install`

Set up environment variables

```bash
cp .env.example .env

# update environment variables in .env

source .env
```

Set up chain/bridge configurations

```bash
cp config/sample/configuredBridges.example config/configuredBridges.json
cp config/sample/configuredChains.example config/configuredChains.json

# fill in all the configuration details...

source config/configuredChains.json
source config/configuredBridges.json
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
