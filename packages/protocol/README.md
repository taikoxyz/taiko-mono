# Taiko Protocol

This repository contains rollup contracts on both L1 and L2 and other assisting code.

## Deployment

To deploy TaikoL1 on the hardhat network, run:

```bash
yarn deploy:hardhat
```

## Testing

To run test cases on hardhat network:

```bash
yarn test
```

To run test cases that rley on a go-ethereum node:

```bash
yarn test:geth
```

## Github Actions

Each commit will automatically trigger the GitHub Actions to run. If any commit message in your push or the HEAD commit of your PR contains the strings [skip ci], [ci skip], [no ci], [skip actions], or [actions skip] workflows triggered on the push or pull_request events will be skipped.
