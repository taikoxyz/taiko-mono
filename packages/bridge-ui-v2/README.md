# Bridge UI v2

## Developing

Installed dependencies with `pnpm install`

Set up environment variables

```bash
cp .env.example .env

# update environment variables in .env

source .env
```

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
