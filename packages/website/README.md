# Taiko documentation website

## Install pnpm

Make sure you have pnpm installed on your system. You can install it by npm as well:

```sh
npm install -g pnpm
```

or on any POSIX systems by wget one-line official command:

```sh
wget -qO- https://get.pnpm.io/install.sh | sh -
```

for any specific cases or systems check the official page: https://pnpm.io/installation.

## Install dependencies

```sh
pnpm install
```

## Start a local development server

```sh
pnpm dev
```

## Create redirects for broken links

Look at [next.config.js](./next.config.js) and [nextjs redirect docs](https://nextjs.org/docs/pages/api-reference/next-config-js/redirects).

## Contributing

Refer to [CONTRIBUTING.md](../../CONTRIBUTING.md).
