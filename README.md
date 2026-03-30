<p align="center">
  <img src="./.github/SurgeLogoOnly.svg" width="80" alt="Surge Logo" />
</p>

<h1 align="center">
  Surge Rollup Framework
</h1>

<p align="center">
  A high-performance rollup framework built on a modified Taiko Alethia stack, featuring realtime proving, synchronous composability, Gigagas performance, and Stage 2 trustless security.
</p>

<div align="center">

[![Twitter Follow](https://img.shields.io/twitter/follow/Nethermind?style=social)](https://x.com/Nethermind)
[![Discord](https://img.shields.io/discord/629004402170134531?color=%235865F2&label=Discord&logo=discord&logoColor=%23fff)](https://discord.com/invite/PaCMRFdvWT)

</div>

Learn more at [surge.wtf](https://www.surge.wtf) or check out the official docs at [docs.surge.wtf](https://docs.surge.wtf).

## Documentation

- [Surge docs](https://docs.surge.wtf) — High-level concepts, guides, resources, and reference pages for getting started.
- [Protocol specs](./packages/protocol/docs/Derivation.md) — In-depth specifications of the protocol for deeper understanding.
- [Smart contracts](./packages/protocol/contracts/) — Protocol smart contracts, fully documented with NatSpec.

## Packages

| Package                                                       | Description                                                        |
| :------------------------------------------------------------ | :----------------------------------------------------------------- |
| [balance-monitor](./packages/balance-monitor)                 | Service that monitors Ethereum L1/L2 addresses and token balances. |
| [bridge-ui](./packages/bridge-ui)                             | Bridge UI.                                                         |
| [docs-site](./packages/docs-site)                             | End user documentation site.                                       |
| [ejector](./packages/ejector)                                 | Preconfirmation ejector service for operators with issues.         |
| [eventindexer](./packages/eventindexer)                       | Event indexer.                                                     |
| [fork-diff](./packages/fork-diff)                             | Fork diff page.                                                    |
| [nfts](./packages/nfts)                                       | NFT-related smart contracts and utilities.                         |
| [protocol](./packages/protocol)                               | Surge protocol smart contracts.                                    |
| [relayer](./packages/relayer)                                 | Bridge backend relayer.                                            |
| [supplementary-contracts](./packages/supplementary-contracts) | Supplementary contracts not part of the core protocol.             |
| [taiko-client](./packages/taiko-client)                       | Client implementation in Go.                                       |
| [taiko-client-rs](./packages/taiko-client-rs)                 | Client implementation in Rust.                                     |
| [ui-lib](./packages/ui-lib)                                   | UI library.                                                        |

## Related Repositories

- [Nethermind](https://github.com/NethermindEth/nethermind): The Nethermind execution client.
- [Raiko](https://github.com/NethermindEth/raiko): Surge's prover client.
- [Surge Documentation](https://github.com/NethermindEth/surge-docs): Comprehensive documentation for Surge, including setup guides and technical details.
- [Simple Surge Node](https://github.com/NethermindEth/simple-surge-node): A simplified presetup docker compose of a Surge node for developers.
- [Alethia Reth](https://github.com/NethermindEth/alethia-reth): A high-performance Rust execution client for the Surge framework.

## Issues

If you find a bug or have a feature request, please [open an issue](https://github.com/NethermindEth/surge/issues/).

## Contributing

Check out [CONTRIBUTING.md](./CONTRIBUTING.md) for details on how to contribute.

## Getting support

Reach out to the community on [Discord](https://discord.com/invite/PaCMRFdvWT) if you need any help!
