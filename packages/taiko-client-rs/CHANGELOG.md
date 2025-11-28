# Changelog

## [2.1.0](https://github.com/taikoxyz/taiko-mono/compare/taiko-alethia-client-rs-v2.0.0...taiko-alethia-client-rs-v2.1.0) (2025-11-28)


### Features

* **protocol,taiko-client,taiko-client-rs:** upgrade preconf whitelist in `DeployProtocolOnL1` ([#20700](https://github.com/taikoxyz/taiko-mono/issues/20700)) ([4e84208](https://github.com/taikoxyz/taiko-mono/commit/4e842086939a869f7287cc149c6b27b08803b032))
* **protocol:** integrate signal service with shasta ([#20270](https://github.com/taikoxyz/taiko-mono/issues/20270)) ([8b26e13](https://github.com/taikoxyz/taiko-mono/commit/8b26e136733a76207aa02e1dfb40a27e5c30cbeb))
* **taiko-client-rs:** add local Shasta codec decoder with CLI flag ([#20726](https://github.com/taikoxyz/taiko-mono/issues/20726)) ([b66f507](https://github.com/taikoxyz/taiko-mono/commit/b66f507c0ba949d40b1b4de6691bea3fce4b62ea))
* **taiko-client-rs:** changes based on protocol [#20584](https://github.com/taikoxyz/taiko-mono/issues/20584) and [#20590](https://github.com/taikoxyz/taiko-mono/issues/20590) ([#20602](https://github.com/taikoxyz/taiko-mono/issues/20602)) ([c252aca](https://github.com/taikoxyz/taiko-mono/commit/c252acabf585eb6f172d6c4f1b2d2c0ff2d7a138))
* **taiko-client-rs:** check `Shasta` fork activation based on timestamp ([#20621](https://github.com/taikoxyz/taiko-mono/issues/20621)) ([9fd1bb0](https://github.com/taikoxyz/taiko-mono/commit/9fd1bb012e6db6ae802fb3296a706aef984d9f4c))
* **taiko-client-rs:** derive Debug to `ShastaEventIndexer` struct on `event-indexer` rust crate ([#20515](https://github.com/taikoxyz/taiko-mono/issues/20515)) ([b11cec4](https://github.com/taikoxyz/taiko-mono/commit/b11cec492e8f91a7e0aa41f76a906620e3618523))
* **taiko-client-rs:** fallback search for `start_tag` by inbox activation timestamp ([#20813](https://github.com/taikoxyz/taiko-mono/issues/20813)) ([41ca4aa](https://github.com/taikoxyz/taiko-mono/commit/41ca4aa8f15bdf7a960b701ced41e6ea6b43d09b))
* **taiko-client-rs:** index `anchor::BondInstruction` instead of `codec::BondInstruction` ([#20622](https://github.com/taikoxyz/taiko-mono/issues/20622)) ([11cb8be](https://github.com/taikoxyz/taiko-mono/commit/11cb8bea0f2bd3e44010b5694540c89c9e4b6056))
* **taiko-client-rs:** introduce `detect_known_canonical_proposal` checks ([#20683](https://github.com/taikoxyz/taiko-mono/issues/20683)) ([5692536](https://github.com/taikoxyz/taiko-mono/commit/569253601186ebee26b90d0222c063d53c2b44c6))
* **taiko-client-rs:** introduce `RESUME_REORG_CUSHION_SLOTS` for driver ([#20679](https://github.com/taikoxyz/taiko-mono/issues/20679)) ([ae3dc5a](https://github.com/taikoxyz/taiko-mono/commit/ae3dc5a4ff2d9f24c311b9c6081a1431fd4976b7))
* **taiko-client-rs:** introduce Shasta `driver` rust crate ([#20368](https://github.com/taikoxyz/taiko-mono/issues/20368)) ([7827f52](https://github.com/taikoxyz/taiko-mono/commit/7827f5245e490ee75c9e1013b3c5a67e66a23cbd))
* **taiko-client-rs:** rust client updates based on Shasta `AnchorForkRouter` protocol changes ([#20548](https://github.com/taikoxyz/taiko-mono/issues/20548)) ([be58b46](https://github.com/taikoxyz/taiko-mono/commit/be58b4632f72e52c114e207d15a3806f0bbdfcc9))
* **taiko-client-rs:** update Rust contract bindings ([#20812](https://github.com/taikoxyz/taiko-mono/issues/20812)) ([c29c755](https://github.com/taikoxyz/taiko-mono/commit/c29c755b8e35237582ccb175cbb6bf8b13086891))
* **taiko-client-rs:** wire finalized Shasta proposal into forkchoice updates ([#20809](https://github.com/taikoxyz/taiko-mono/issues/20809)) ([a1a72e4](https://github.com/taikoxyz/taiko-mono/commit/a1a72e423f0e145cea9fee48b7d797f99a086108))
* **taiko-client,taiko-client-rs:** align Shasta manifest validation with the latest protocol updates ([#20775](https://github.com/taikoxyz/taiko-mono/issues/20775)) ([5e18853](https://github.com/taikoxyz/taiko-mono/commit/5e18853b253d7c4e8db2d8c547870c11a3af45d9))
* **taiko-client,taiko-client-rs:** only allow one block per forced inclusion ([#20778](https://github.com/taikoxyz/taiko-mono/issues/20778)) ([685445a](https://github.com/taikoxyz/taiko-mono/commit/685445abe0c753b35832a8e5064110e281c7012f))
* **taiko-client,taiko-client-rs:** remove `blockIndex` in `anchorV4` ([#20610](https://github.com/taikoxyz/taiko-mono/issues/20610)) ([1ce7094](https://github.com/taikoxyz/taiko-mono/commit/1ce709490ae2107d53db664409b56476f730c46f))
* **taiko-client,taiko-client-rs:** update `MaxBlockGasLimit` to `45_000_000` ([#20788](https://github.com/taikoxyz/taiko-mono/issues/20788)) ([4f31233](https://github.com/taikoxyz/taiko-mono/commit/4f31233fed5e1829b84f5e5a740ac8c7a46ccccf))
* **taiko-client:** introduce Shasta `event-indexer` / `proposer` rust crates ([#20293](https://github.com/taikoxyz/taiko-mono/issues/20293)) ([8274479](https://github.com/taikoxyz/taiko-mono/commit/827447969d99b9c1cd7d2451795ef4ecbd61645c))


### Bug Fixes

* **ejector, repo:** refactor ejector `Cargo.toml` into `./packages`, fix `release-please` ([#20391](https://github.com/taikoxyz/taiko-mono/issues/20391)) ([359db1c](https://github.com/taikoxyz/taiko-mono/commit/359db1cc59275188b21cb436d981c9a4b2d4dd24))
* **taiko-client-rs:** Missing licenses for taiko-client-rs crates ([#20407](https://github.com/taikoxyz/taiko-mono/issues/20407)) ([479624c](https://github.com/taikoxyz/taiko-mono/commit/479624c9429419bdb49cbf13552f542176a98012))
* **taiko-client-rs:** remove redundant 'to' override; rely on contract binding address ([#20628](https://github.com/taikoxyz/taiko-mono/issues/20628)) ([2a60c95](https://github.com/taikoxyz/taiko-mono/commit/2a60c953fbab9c172b418b79f980198c9d500b29))
* **taiko-client,taiko-client-rs:** ensure forced inclusion manifests reuse proposer auth ([#20747](https://github.com/taikoxyz/taiko-mono/issues/20747)) ([6432f1c](https://github.com/taikoxyz/taiko-mono/commit/6432f1c6530e36d500fe5128d23e44baba2f1206))
* **taiko-client,taiko-client-rs:** ensure Shasta low-bond proposals set `block.extradata` bit even for default payloads ([#20745](https://github.com/taikoxyz/taiko-mono/issues/20745)) ([095311b](https://github.com/taikoxyz/taiko-mono/commit/095311b3d90743f1f8c3e2da1e52dfb67f4bfc0a))
* **taiko-client,taiko-client-rs:** only apply default low-bond manifests for normal proposer sources ([#20748](https://github.com/taikoxyz/taiko-mono/issues/20748)) ([aa1956a](https://github.com/taikoxyz/taiko-mono/commit/aa1956a2a65e2dccaab8c15f95844668fa2704ea))
* **taiko-client,taiko-client-rs:** remove the `finalizationGracePeriod` check in `getTransitionsForFinalization` ([#20693](https://github.com/taikoxyz/taiko-mono/issues/20693)) ([35301ae](https://github.com/taikoxyz/taiko-mono/commit/35301aea752328184c83c0d0d91df096872124c3))
* **taiko-client,taiko-client-rs:** update gas-limit clamp ([#20746](https://github.com/taikoxyz/taiko-mono/issues/20746)) ([c2c12b5](https://github.com/taikoxyz/taiko-mono/commit/c2c12b527adb9749155761b2b7c8431dc5f15273))


### Chores

* **protocol,taiko-client,taiko-client-rs:** cherry pick pr 20762 ([#20763](https://github.com/taikoxyz/taiko-mono/issues/20763)) ([09ff83f](https://github.com/taikoxyz/taiko-mono/commit/09ff83f348c19ad11c920adc881dcc76ed62194d))
* **protocol:** add `MAX_BLOCK_GAS_LIMIT` ([#20522](https://github.com/taikoxyz/taiko-mono/issues/20522)) ([9878f60](https://github.com/taikoxyz/taiko-mono/commit/9878f6022393ad70446bc5350b8b5e8c9350af09))
* **taiko-client-rs:** add more metrics for driver ([#20751](https://github.com/taikoxyz/taiko-mono/issues/20751)) ([9d10a1c](https://github.com/taikoxyz/taiko-mono/commit/9d10a1cf74dcd3ba3f6a740cfe310f2d47bb0884))
* **taiko-client-rs:** bump rust `event-scanner` dep to `0.4.0-alpha` ([#20595](https://github.com/taikoxyz/taiko-mono/issues/20595)) ([311ed4e](https://github.com/taikoxyz/taiko-mono/commit/311ed4e1a28ecf76490687a58f0a6f46b879b59c))
* **taiko-client-rs:** improve rust driver logging and derivation pipeline ([#20651](https://github.com/taikoxyz/taiko-mono/issues/20651)) ([0ca71a4](https://github.com/taikoxyz/taiko-mono/commit/0ca71a425ecb75bec7ed737c258f1a35362f4873))
* **taiko-client-rs:** update `event-scanner` && `alethia-reth` ([#20805](https://github.com/taikoxyz/taiko-mono/issues/20805)) ([811e34d](https://github.com/taikoxyz/taiko-mono/commit/811e34d7fee38302c5e362586e7f9de7bfb398b5))
* **taiko-client-rs:** use `alethia-reth` crates ([#20402](https://github.com/taikoxyz/taiko-mono/issues/20402)) ([02e2479](https://github.com/taikoxyz/taiko-mono/commit/02e247939f6401697834c1a1c05b1f73aa713794))
* **taiko-client,taiko-client-rs:** update Go / Rust contract bindings ([#20711](https://github.com/taikoxyz/taiko-mono/issues/20711)) ([15ccd79](https://github.com/taikoxyz/taiko-mono/commit/15ccd79536211e47610d457d1914c002cce8fe5b))
* **taiko-client:** improve `ResetL1Current` to set Shasta anchor number ([#20761](https://github.com/taikoxyz/taiko-mono/issues/20761)) ([14f9367](https://github.com/taikoxyz/taiko-mono/commit/14f93671c2fbea1cd747ad5779cc1507eeadda53))


### Code Refactoring

* **protocol,taiko-client-rs,taiko-client:** move LibManifest constants to Derivation.md ([#20545](https://github.com/taikoxyz/taiko-mono/issues/20545)) ([da27f44](https://github.com/taikoxyz/taiko-mono/commit/da27f4441507190eba742dcf90404956eeb67b45))
* **protocol:** clean up folder structure and remove Pacaya contracts ([#20413](https://github.com/taikoxyz/taiko-mono/issues/20413)) ([697cf80](https://github.com/taikoxyz/taiko-mono/commit/697cf80e3629e371fcacbf9026b5a54c7b046536))


### Tests

* **taiko-client-rs:** use `test-context` to simplify tests ([#20866](https://github.com/taikoxyz/taiko-mono/issues/20866)) ([5176f13](https://github.com/taikoxyz/taiko-mono/commit/5176f13aa11118f0825ae93d48fecce110598819))
