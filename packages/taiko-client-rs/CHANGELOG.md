# Changelog

## [2.1.0](https://github.com/taikoxyz/taiko-mono/compare/taiko-alethia-client-rs-v2.0.0...taiko-alethia-client-rs-v2.1.0) (2025-10-31)


### Features

* **protocol:** integrate signal service with shasta ([#20270](https://github.com/taikoxyz/taiko-mono/issues/20270)) ([8b26e13](https://github.com/taikoxyz/taiko-mono/commit/8b26e136733a76207aa02e1dfb40a27e5c30cbeb))
* **taiko-client-rs:** changes based on protocol [#20584](https://github.com/taikoxyz/taiko-mono/issues/20584) and [#20590](https://github.com/taikoxyz/taiko-mono/issues/20590) ([#20602](https://github.com/taikoxyz/taiko-mono/issues/20602)) ([c252aca](https://github.com/taikoxyz/taiko-mono/commit/c252acabf585eb6f172d6c4f1b2d2c0ff2d7a138))
* **taiko-client-rs:** derive Debug to `ShastaEventIndexer` struct on `event-indexer` rust crate ([#20515](https://github.com/taikoxyz/taiko-mono/issues/20515)) ([b11cec4](https://github.com/taikoxyz/taiko-mono/commit/b11cec492e8f91a7e0aa41f76a906620e3618523))
* **taiko-client-rs:** introduce Shasta `driver` rust crate ([#20368](https://github.com/taikoxyz/taiko-mono/issues/20368)) ([7827f52](https://github.com/taikoxyz/taiko-mono/commit/7827f5245e490ee75c9e1013b3c5a67e66a23cbd))
* **taiko-client-rs:** rust client updates based on Shasta `AnchorForkRouter` protocol changes ([#20548](https://github.com/taikoxyz/taiko-mono/issues/20548)) ([be58b46](https://github.com/taikoxyz/taiko-mono/commit/be58b4632f72e52c114e207d15a3806f0bbdfcc9))
* **taiko-client,taiko-client-rs:** remove `blockIndex` in `anchorV4` ([#20610](https://github.com/taikoxyz/taiko-mono/issues/20610)) ([1ce7094](https://github.com/taikoxyz/taiko-mono/commit/1ce709490ae2107d53db664409b56476f730c46f))
* **taiko-client:** introduce Shasta `event-indexer` / `proposer` rust crates ([#20293](https://github.com/taikoxyz/taiko-mono/issues/20293)) ([8274479](https://github.com/taikoxyz/taiko-mono/commit/827447969d99b9c1cd7d2451795ef4ecbd61645c))


### Bug Fixes

* **ejector, repo:** refactor ejector `Cargo.toml` into `./packages`, fix `release-please` ([#20391](https://github.com/taikoxyz/taiko-mono/issues/20391)) ([359db1c](https://github.com/taikoxyz/taiko-mono/commit/359db1cc59275188b21cb436d981c9a4b2d4dd24))
* **taiko-client-rs:** Missing licenses for taiko-client-rs crates ([#20407](https://github.com/taikoxyz/taiko-mono/issues/20407)) ([479624c](https://github.com/taikoxyz/taiko-mono/commit/479624c9429419bdb49cbf13552f542176a98012))


### Chores

* **taiko-client-rs:** bump rust `event-scanner` dep to `0.4.0-alpha` ([#20595](https://github.com/taikoxyz/taiko-mono/issues/20595)) ([311ed4e](https://github.com/taikoxyz/taiko-mono/commit/311ed4e1a28ecf76490687a58f0a6f46b879b59c))
* **taiko-client-rs:** use `alethia-reth` crates ([#20402](https://github.com/taikoxyz/taiko-mono/issues/20402)) ([02e2479](https://github.com/taikoxyz/taiko-mono/commit/02e247939f6401697834c1a1c05b1f73aa713794))


### Code Refactoring

* **protocol,taiko-client-rs,taiko-client:** move LibManifest constants to Derivation.md ([#20545](https://github.com/taikoxyz/taiko-mono/issues/20545)) ([da27f44](https://github.com/taikoxyz/taiko-mono/commit/da27f4441507190eba742dcf90404956eeb67b45))
* **protocol:** clean up folder structure and remove Pacaya contracts ([#20413](https://github.com/taikoxyz/taiko-mono/issues/20413)) ([697cf80](https://github.com/taikoxyz/taiko-mono/commit/697cf80e3629e371fcacbf9026b5a54c7b046536))
