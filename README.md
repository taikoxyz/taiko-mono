<p align="center">
  <img src="./.github/taiko-icon-blk.svg" width="80" alt="Logo for Taiko" />
</p>

<h1 align="center">
  Taiko Alethia
</h1>

<p align="center">
  The first based rollup.
</p>

<div align="center">

[![Twitter Follow](https://img.shields.io/twitter/follow/taikoxyz?style=social)](https://twitter.com/taikoxyz)
[![Discord](https://img.shields.io/discord/984015101017346058?color=%235865F2&label=Discord&logo=discord&logoColor=%23fff)](https://discord.com/invite/GqehHsxDgP)
[![YouTube](https://img.shields.io/youtube/channel/subscribers/UCxd_ARE9LtAEdnRQA6g1TaQ)](https://www.youtube.com/@taikoxyz)

[![GitPOAP Badge](https://public-api.gitpoap.io/v1/repo/taikoxyz/taiko-mono/badge)](https://www.gitpoap.io/gh/taikoxyz/taiko-mono)
[![License](https://img.shields.io/github/license/taikoxyz/taiko-mono)](https://github.com/taikoxyz/taiko-mono/blob/main/LICENSE)

</div>

> [!WARNING]
> The `main` branch is under active development for the next Shasta fork. For the latest version of the Taiko Alethia protocol contracts (Pacaya fork), please use the [`taiko-alethia-protocol-v2.3.1`](https://github.com/taikoxyz/taiko-mono/tree/taiko-alethia-protocol-v2.3.1) branch. The release process involves security measures that the `main` branch does not guarantee.

## Documentation

Get started with Taiko Alethia:

- [Taiko Alethia docs](https://docs.taiko.xyz) — High-level concepts, guides, resources, and reference pages for getting started.
- [Protocol specs](./packages/protocol/docs/README.md) — In-depth specifications of the Taiko Alethia protocol for deeper understanding.
- [Smart contracts](./packages/protocol/contracts/) — Taiko Alethia protocol smart contracts, fully documented with NatSpec.

## Packages

> [!TIP]
> Make sure your node is using the latest version tags for taiko-client and taiko-geth. Check out the [node releases page](https://docs.taiko.xyz/network-reference/software-releases-and-deployments)!

| Package                                                       | Description                                                        |
| :------------------------------------------------------------ | :----------------------------------------------------------------- |
| [balance-monitor](./packages/balance-monitor)                 | Service that monitors Ethereum L1/L2 addresses and token balances. |
| [bridge-ui](./packages/bridge-ui)                             | Bridge UI.                                                         |
| [docs-site](./packages/docs-site)                             | End user documentation site.                                       |
| [ejector](./packages/ejector)                                 | Preconfirmation ejector service for operators with issues.         |
| [eventindexer](./packages/eventindexer)                       | Event indexer.                                                     |
| [fork-diff](./packages/fork-diff)                             | Fork diff page.                                                    |
| [nfts](./packages/nfts)                                       | NFT-related smart contracts and utilities.                         |
| [protocol](./packages/protocol)                               | Taiko Alethia protocol smart contracts.                            |
| [relayer](./packages/relayer)                                 | Bridge backend relayer.                                            |
| [snaefell-ui](./packages/snaefell-ui)                         | Snaefell UI.                                                       |
| [supplementary-contracts](./packages/supplementary-contracts) | Supplementary contracts not part of the Taiko Alethia protocol.    |
| [taiko-client](./packages/taiko-client)                       | Taiko Alethia client implementation in Go.                         |
| [taiko-client-rs](./packages/taiko-client-rs)                 | Taiko Alethia client implementation in Rust.                       |
| [taikoon-ui](./packages/taikoon-ui)                           | Taikoon UI.                                                        |
| [ui-lib](./packages/ui-lib)                                   | UI library.                                                        |

## Issues

If you find a bug or have a feature request, please [open an issue](https://github.com/taikoxyz/taiko-mono/issues/new/choose).

## Contributing

Check out [CONTRIBUTING.md](./CONTRIBUTING.md) for details on how to contribute. You can also check out our grants cycle at [https://taiko.xyz/grant-program](https://taiko.xyz/grant-program).

## Getting support

Reach out to the community on [Discord](https://discord.com/invite/GqehHsxDgP) if you need any help!
