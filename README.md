<p align="center">
  <img src="./packages/branding/Logo/SVG/Taiko_Logo_Fluo.svg" width="80" alt="Logo for Taiko" />
</p>

<h1 align="center">
  TAIKO
</h1>

<p align="center">
  A decentralized, Ethereum-equivalent ZK-Rollup.
  <br />
  <a href="https://taiko.xyz" target="_blank"><strong>Explore the website</strong></a>
</p>

<div align="center">

[![Twitter Follow](https://img.shields.io/twitter/follow/taikoxyz?style=social)](https://twitter.com/taikoxyz)
[![Discord](https://img.shields.io/discord/984015101017346058?color=%235865F2&label=Discord&logo=discord&logoColor=%23fff)](https://discord.gg/taikoxyz)
[![GitPOAP Badge](https://public-api.gitpoap.io/v1/repo/taikoxyz/taiko-mono/badge)](https://www.gitpoap.io/gh/taikoxyz/taiko-mono)

[![GitHub Workflow Status](https://img.shields.io/github/workflow/status/taikoxyz/taiko-mono/Solidity?label=Protocol&logo=github)](https://github.com/taikoxyz/taiko-mono/actions/workflows/solidity.yml)
[![GitHub Workflow Status](https://img.shields.io/github/workflow/status/taikoxyz/taiko-mono/Golang?label=Relayer&logo=github)](https://github.com/taikoxyz/taiko-mono/actions/workflows/golang.yml)
[![GitHub Workflow Status](https://img.shields.io/github/workflow/status/taikoxyz/taiko-mono/Bridge%20UI?label=Bridge%20UI&logo=github)](https://github.com/taikoxyz/taiko-mono/actions/workflows/typescript.yml)
[![GitHub Workflow Status](https://img.shields.io/github/workflow/status/taikoxyz/taiko-mono/Website?label=Website&logo=github)](https://github.com/taikoxyz/taiko-mono/actions/workflows/website.yml)

[![Codecov](https://img.shields.io/codecov/c/github/taikoxyz/taiko-mono?flag=protocol&label=Protocol&logo=codecov&token=E468X2PTJC)](https://app.codecov.io/gh/taikoxyz/taiko-mono/tree/main/packages/protocol)
[![Codecov](https://img.shields.io/codecov/c/github/taikoxyz/taiko-mono?flag=relayer&label=Relayer&logo=codecov&token=E468X2PTJC)](https://app.codecov.io/gh/taikoxyz/taiko-mono/tree/main/packages/relayer)
[![Codecov](https://img.shields.io/codecov/c/github/taikoxyz/taiko-mono?flag=bridge-ui&label=Bridge%20UI&logo=codecov&token=E468X2PTJC)](https://app.codecov.io/gh/taikoxyz/taiko-mono/tree/main/packages/bridge-ui)

</div>

## Project structure

<pre>
taiko-mono
├── <a href="./CONTRIBUTING.md">CONTRIBUTING.md</a>
├── <a href="./README.md">README.md</a>
...
├── <a href="./packages">packages</a>
│   ├── <a href="./packages/branding">branding</a>: Taiko branding materials
│   ├── <a href="./packages/bridge-frontend">bridge-frontend</a>: Bridge frontend UI
│   ├── <a href="./packages/protocol">protocol</a>: L1 and L2 protocol smart contracts
│   ├── <a href="./packages/relayer">relayer</a>: Bridge relayer
│   ├── <a href="./packages/website">website</a>: Main documentation website at taiko.xyz
│   └── <a href="./packages/whitepaper">whitepaper</a>: Whitepaper source files with automated publishing
...
</pre>

## Github Actions

Each commit will automatically trigger the GitHub Actions to run. If any commit message in your push or the HEAD commit of your PR contains the strings [skip ci], [ci skip], [no ci], [skip actions], or [actions skip] workflows triggered on the push or pull_request events will be skipped.

## Contributors ✨

Thanks goes to these wonderful people! If you would like to contribute, please read the [Contributing guide](./CONTRIBUTING.md). You can also reach out to the community on [Discord](https://discord.gg/taikoxyz).

<a href="https://github.com/taikoxyz/taiko-mono/graphs/contributors">
  <p align="center">
    <img width="720" src="https://contrib.rocks/image?repo=taikoxyz/taiko-mono" />
  </p>
</a>

<p align="center">
  Made with <a rel="noopener noreferrer" target="_blank" href="https://contrib.rocks">contrib.rocks</a>
</p>
