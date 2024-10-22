# Changelog

## [0.39.1](https://github.com/taikoxyz/taiko-mono/compare/taiko-client-v0.39.0...taiko-client-v0.39.1) (2024-10-22)


### Bug Fixes

* **taiko-client:** fix `lastVerifiedBlockHash` fetch ([#18277](https://github.com/taikoxyz/taiko-mono/issues/18277)) ([8512f45](https://github.com/taikoxyz/taiko-mono/commit/8512f456f033130ecb0e5493a3c36be025908228))

## [0.39.0](https://github.com/taikoxyz/taiko-mono/compare/taiko-client-v0.38.0...taiko-client-v0.39.0) (2024-10-21)


### Features

* **taiko-client:** update `OntakeForkHeight` in mainnet ([#18253](https://github.com/taikoxyz/taiko-mono/issues/18253)) ([21c6235](https://github.com/taikoxyz/taiko-mono/commit/21c62355575adae6d99e1a117f357c6429d79b4c))


### Documentation

* **taiko-client:** update readme how to do integration test ([#18256](https://github.com/taikoxyz/taiko-mono/issues/18256)) ([b12b32e](https://github.com/taikoxyz/taiko-mono/commit/b12b32e92b5803f15047a6da2b73135f12b9406d))


### Tests

* **taiko-client:** introduce `taiko-reth` as another L2 node in testing ([#18223](https://github.com/taikoxyz/taiko-mono/issues/18223)) ([e856273](https://github.com/taikoxyz/taiko-mono/commit/e85627365d423fd8353b5bff92e80978774e9c50))

## [0.38.0](https://github.com/taikoxyz/taiko-mono/compare/taiko-client-v0.37.0...taiko-client-v0.38.0) (2024-10-09)


### Features

* **taiko-client:** add `proposer_pool_content_fetch_time` metric ([#18190](https://github.com/taikoxyz/taiko-mono/issues/18190)) ([35579df](https://github.com/taikoxyz/taiko-mono/commit/35579dfa938562969da2395492f4472c300574dd))


### Chores

* **taiko-client:** bump dependencies ([#18202](https://github.com/taikoxyz/taiko-mono/issues/18202)) ([219a7e8](https://github.com/taikoxyz/taiko-mono/commit/219a7e87c09c7e4ac8d545c65c77a29e6f818701))


### Tests

* **taiko-client:** remove an unnecessary test ([#18218](https://github.com/taikoxyz/taiko-mono/issues/18218)) ([d624e29](https://github.com/taikoxyz/taiko-mono/commit/d624e29ce1c0ae9ef6704d96516d632600213e13))

## [0.37.0](https://github.com/taikoxyz/taiko-mono/compare/taiko-client-v0.36.0...taiko-client-v0.37.0) (2024-09-28)


### Features

* **taiko-client:** allow `--l1.beacon` to be optional when a blob server is given ([#18094](https://github.com/taikoxyz/taiko-mono/issues/18094)) ([f4d47a3](https://github.com/taikoxyz/taiko-mono/commit/f4d47a3f988462605f04106b14394bb400fc9669))
* **taiko-client:** improve some logs in zk producer ([#18117](https://github.com/taikoxyz/taiko-mono/issues/18117)) ([109595e](https://github.com/taikoxyz/taiko-mono/commit/109595e7b285709833a782ee0959fd1a815ef706))
* **taiko-client:** support `TaikoL1.proposeBlocksV2` ([#18116](https://github.com/taikoxyz/taiko-mono/issues/18116)) ([d0c0fed](https://github.com/taikoxyz/taiko-mono/commit/d0c0fed57c8b8ba139b65d0215df1976358e7635))
* **taiko-client:** update contract bingdings ([#18182](https://github.com/taikoxyz/taiko-mono/issues/18182)) ([8954764](https://github.com/taikoxyz/taiko-mono/commit/8954764d96c256408c1cfd77deb1621da288a33c))
* **taiko-client:** update prover balance check to include bond balance ([#18092](https://github.com/taikoxyz/taiko-mono/issues/18092)) ([5d5ca74](https://github.com/taikoxyz/taiko-mono/commit/5d5ca74970f88493ea75b14a13fe852f840f019a))


### Bug Fixes

* **taiko-client:** dont check l1heightInAnchor vs l1Height when detecting reorg ([#18110](https://github.com/taikoxyz/taiko-mono/issues/18110)) ([7ed9b6f](https://github.com/taikoxyz/taiko-mono/commit/7ed9b6f647fd1611e036ce12e4fd96696ef231ea))
* **taiko-client:** fix blob server API URL when fetching blob data ([#18109](https://github.com/taikoxyz/taiko-mono/issues/18109)) ([7230dfd](https://github.com/taikoxyz/taiko-mono/commit/7230dfd1150edc7c08be6f97a46c1184a0b2d289))
* **taiko-client:** fix process in handling empty proof ([#18128](https://github.com/taikoxyz/taiko-mono/issues/18128)) ([d6d90d8](https://github.com/taikoxyz/taiko-mono/commit/d6d90d887be8955f844c52c4fb100fa46d66fa47))
* **taiko-client:** fix revert case when propose blob blocks ([#18185](https://github.com/taikoxyz/taiko-mono/issues/18185)) ([656e757](https://github.com/taikoxyz/taiko-mono/commit/656e757d629131cb03af894269ef447c39e9741e))
* **taiko-client:** improve prover balance check based on 18092 ([#18129](https://github.com/taikoxyz/taiko-mono/issues/18129)) ([b6cd50b](https://github.com/taikoxyz/taiko-mono/commit/b6cd50b61577d1eaa7aa29bd3e728271bcd4996f))
* **taiko-client:** record `lastProposedAt` after ontake fork ([#18166](https://github.com/taikoxyz/taiko-mono/issues/18166)) ([ea0ca90](https://github.com/taikoxyz/taiko-mono/commit/ea0ca9040cc3d1d9fec50777d40b3cf69803c115))
* **taiko-client:** revert path changes about SocialScan endpoint ([#18119](https://github.com/taikoxyz/taiko-mono/issues/18119)) ([38fa03a](https://github.com/taikoxyz/taiko-mono/commit/38fa03ab78d9cf4e70df8c623a74a4d69cf85682))


### Chores

* **protocol:** remove reliance on taiko contracts and update golangci-lint ([#18151](https://github.com/taikoxyz/taiko-mono/issues/18151)) ([92f571a](https://github.com/taikoxyz/taiko-mono/commit/92f571a15daa4ad300b4665bbace9248c439fd11))
* **taiko-client:** revert building changes ([#18174](https://github.com/taikoxyz/taiko-mono/issues/18174)) ([485b2ee](https://github.com/taikoxyz/taiko-mono/commit/485b2ee9a4bf4e16b9d0ab7b704eba0b0a46996c))
* **taiko-client:** try cross-compile taiko-client to speed up docker building ([#18171](https://github.com/taikoxyz/taiko-mono/issues/18171)) ([9dbad24](https://github.com/taikoxyz/taiko-mono/commit/9dbad24cefcd260e2b452c9e8a46fcbe5f327cb4))


### Tests

* **taiko-client:** disable docker pull in hive test ([#18101](https://github.com/taikoxyz/taiko-mono/issues/18101)) ([95c9da2](https://github.com/taikoxyz/taiko-mono/commit/95c9da29fdd432de156f331802b79703a2311898))
* **taiko-client:** introduce `TestProposeTxListOntake` ([#18167](https://github.com/taikoxyz/taiko-mono/issues/18167)) ([5023226](https://github.com/taikoxyz/taiko-mono/commit/5023226a7aa2e7355e835f9447b17eb85c60032a))
* **taiko-client:** introduce blob-server and blob-l1-beacon hive tests ([#18121](https://github.com/taikoxyz/taiko-mono/issues/18121)) ([c544fe8](https://github.com/taikoxyz/taiko-mono/commit/c544fe8c33e26bfae951fb15c423aec2b749d092))
* **taiko-client:** upgrade full sync and snap sync hive tests ([#18010](https://github.com/taikoxyz/taiko-mono/issues/18010)) ([1d18c17](https://github.com/taikoxyz/taiko-mono/commit/1d18c170566aed645e2e03b024e7fe2f2a01756d))


### Workflow

* **protocol:** avoid installing `netcat` in action ([#18159](https://github.com/taikoxyz/taiko-mono/issues/18159)) ([7e27d1d](https://github.com/taikoxyz/taiko-mono/commit/7e27d1de388755b167d864df37133bfedafa2462))

## [0.36.0](https://github.com/taikoxyz/taiko-mono/compare/taiko-client-v0.35.0...taiko-client-v0.36.0) (2024-09-12)


### Features

* **taiko-client:** update Go contract bindings after protocol restructure ([#18075](https://github.com/taikoxyz/taiko-mono/issues/18075)) ([57f4953](https://github.com/taikoxyz/taiko-mono/commit/57f49530828e6da2d28ab3979576befdee626c7d))

## [0.35.0](https://github.com/taikoxyz/taiko-mono/compare/taiko-client-v0.34.1...taiko-client-v0.35.0) (2024-09-10)


### Features

* **taiko-client:** add two more new ZK related metrics ([#18043](https://github.com/taikoxyz/taiko-mono/issues/18043)) ([e43eeac](https://github.com/taikoxyz/taiko-mono/commit/e43eeacb5b7a3d1fc412ffafc39f329f68ff7b40))
* **taiko-client:** remove the legacy `290` tier ([#18035](https://github.com/taikoxyz/taiko-mono/issues/18035)) ([5064037](https://github.com/taikoxyz/taiko-mono/commit/50640377db773763c3ccba1bc4f342cd1e497147))
* **taiko-client:** update `ontakeForkHeight` to Sep 24, 2024 ([#18047](https://github.com/taikoxyz/taiko-mono/issues/18047)) ([a1ff620](https://github.com/taikoxyz/taiko-mono/commit/a1ff620507e4a8077705c981c3622e3787a55ecd))
* **taiko-client:** update contract binding & add `Proposer` ([#18053](https://github.com/taikoxyz/taiko-mono/issues/18053)) ([d0554a2](https://github.com/taikoxyz/taiko-mono/commit/d0554a208c4913751ff5b273f3e96ca298279d14))
* **taiko-client:** use `proveBlocks` by default for post ontake blocks ([#18042](https://github.com/taikoxyz/taiko-mono/issues/18042)) ([15709af](https://github.com/taikoxyz/taiko-mono/commit/15709af1520251f4baeba7d2bbbc8de841bee718))


### Bug Fixes

* **taiko-client:** use proposed at, not timestamp when fetching blob ([#18055](https://github.com/taikoxyz/taiko-mono/issues/18055)) ([32d95c1](https://github.com/taikoxyz/taiko-mono/commit/32d95c1d9e887e886da57e580554413b4f3a19c5))

## [0.34.1](https://github.com/taikoxyz/taiko-mono/compare/taiko-client-v0.34.0...taiko-client-v0.34.1) (2024-09-04)


### Bug Fixes

* **taiko-client:** temp support tier 290 ([#18030](https://github.com/taikoxyz/taiko-mono/issues/18030)) ([f1aeac3](https://github.com/taikoxyz/taiko-mono/commit/f1aeac39d3c2ce06578a64bbe8a2fe4343d212f4))

## [0.34.0](https://github.com/taikoxyz/taiko-mono/compare/taiko-client-v0.33.1...taiko-client-v0.34.0) (2024-09-02)


### Features

* **taiko-client:** introduce sp1 zk proof ([#18003](https://github.com/taikoxyz/taiko-mono/issues/18003)) ([492c208](https://github.com/taikoxyz/taiko-mono/commit/492c208b97e8fa08eb3e11b0a8712a5542eba660))
* **taiko-client:** remove an unused field in prover ([#18024](https://github.com/taikoxyz/taiko-mono/issues/18024)) ([5d416d2](https://github.com/taikoxyz/taiko-mono/commit/5d416d2366e485b242818fb1a15eb0281cb7cedf))
* **taiko-client:** remove an unused filed in proposer ([#18021](https://github.com/taikoxyz/taiko-mono/issues/18021)) ([64fdf5c](https://github.com/taikoxyz/taiko-mono/commit/64fdf5c80708b14d2cefadfbd78ee59810df3f65))
* **taiko-client:** update Go contract bindings ([#18012](https://github.com/taikoxyz/taiko-mono/issues/18012)) ([7f054ca](https://github.com/taikoxyz/taiko-mono/commit/7f054ca4505313f8fc500cdb28bf223a254424e2))

## [0.33.1](https://github.com/taikoxyz/taiko-mono/compare/taiko-client-v0.33.0...taiko-client-v0.33.1) (2024-08-30)


### Bug Fixes

* **taiko-client:** initialize private mempool transaction sender in `InitFromConfig` ([#18005](https://github.com/taikoxyz/taiko-mono/issues/18005)) ([58f1c85](https://github.com/taikoxyz/taiko-mono/commit/58f1c85ad471a545f8f00bfd32b3241657f38e8f))

## [0.33.0](https://github.com/taikoxyz/taiko-mono/compare/taiko-client-v0.32.0...taiko-client-v0.33.0) (2024-08-29)


### Features

* **taiko-client:** introduce `CalculateBaseFee()` method ([#17989](https://github.com/taikoxyz/taiko-mono/issues/17989)) ([fdee419](https://github.com/taikoxyz/taiko-mono/commit/fdee4195541e5c675561cf34c5e1a9e3e3990bbf))
* **taiko-client:** introduce `TxMgrSelector` for proposer / prover ([#17986](https://github.com/taikoxyz/taiko-mono/issues/17986)) ([6eb298f](https://github.com/taikoxyz/taiko-mono/commit/6eb298f31723e838ac4261fbecbfcfce371d8606))
* **taiko-client:** update Go contract bindings ([#17997](https://github.com/taikoxyz/taiko-mono/issues/17997)) ([606114f](https://github.com/taikoxyz/taiko-mono/commit/606114faa0b5642055455f07cbd7ec2c3c23b00c))
* **taiko-client:** update protocol configs temporarily ([#17999](https://github.com/taikoxyz/taiko-mono/issues/17999)) ([7893700](https://github.com/taikoxyz/taiko-mono/commit/789370090ffb7d985b2d9d55bf4efec8495df6bd))


### Bug Fixes

* **taiko-client:** fix CallOpts and `TestTreasuryIncome` test case ([#18000](https://github.com/taikoxyz/taiko-mono/issues/18000)) ([5707a08](https://github.com/taikoxyz/taiko-mono/commit/5707a08ffab3c981f0f23bcb8c7833176903d183))


### Chores

* **taiko-client:** don't use color prefix in log's terminal handler ([#17991](https://github.com/taikoxyz/taiko-mono/issues/17991)) ([1675cec](https://github.com/taikoxyz/taiko-mono/commit/1675cecab5773d1c4fdf82b8e000a6f5bebddfc6))


### Tests

* **taiko-client:** support full sync and snap sync in hive test ([#17995](https://github.com/taikoxyz/taiko-mono/issues/17995)) ([831198b](https://github.com/taikoxyz/taiko-mono/commit/831198baecc5f0e10c5c8fac1c04f9dad320c63c))
* **taiko-client:** support multi clusters reorg hive test ([#17987](https://github.com/taikoxyz/taiko-mono/issues/17987)) ([28d9072](https://github.com/taikoxyz/taiko-mono/commit/28d90729adc391cb04b58fa2c32a9e3bfbd989a5))

## [0.32.0](https://github.com/taikoxyz/taiko-mono/compare/taiko-client-v0.31.0...taiko-client-v0.32.0) (2024-08-27)


### Features

* **taiko-client:** add optional `l1.private` ([#17962](https://github.com/taikoxyz/taiko-mono/issues/17962)) ([9274f2d](https://github.com/taikoxyz/taiko-mono/commit/9274f2dc90f18c58cc208146f584c9f9715d3d60))
* **taiko-client:** optimising statistics on proof request times ([#17976](https://github.com/taikoxyz/taiko-mono/issues/17976)) ([791f44f](https://github.com/taikoxyz/taiko-mono/commit/791f44f381fa362f24c4beff5b5b25c47929bbc4))


### Bug Fixes

* **taiko-client:** fix some issues about `calculateBaseFee` ([#17978](https://github.com/taikoxyz/taiko-mono/issues/17978)) ([b010efe](https://github.com/taikoxyz/taiko-mono/commit/b010efe195259e7c98e0ad6fb91b0c6484ae2b80))
* **taiko-client:** prints logs when using `privateTxMgr` ([#17980](https://github.com/taikoxyz/taiko-mono/issues/17980)) ([a0c3388](https://github.com/taikoxyz/taiko-mono/commit/a0c33882ca00fb834001abac95b6ade656d55e87))


### Chores

* **taiko-client:** fix lint errors ([#17969](https://github.com/taikoxyz/taiko-mono/issues/17969)) ([eedec99](https://github.com/taikoxyz/taiko-mono/commit/eedec991c92d5fcd418cde4db9d16c9b36122a0a))
* **taiko-client:** keep env vars same with the flag name ([#17964](https://github.com/taikoxyz/taiko-mono/issues/17964)) ([d08a1de](https://github.com/taikoxyz/taiko-mono/commit/d08a1de8a36a4bac484bf0390728cb8ed87b3a0b))


### Tests

* **taiko-client:** introduce multi nodes hive test ([#17981](https://github.com/taikoxyz/taiko-mono/issues/17981)) ([9910863](https://github.com/taikoxyz/taiko-mono/commit/9910863865ecf7f583552e74f6a5d2e1a4060dca))
* **taiko-client:** introduce reorg hive test ([#17965](https://github.com/taikoxyz/taiko-mono/issues/17965)) ([ab601ee](https://github.com/taikoxyz/taiko-mono/commit/ab601eea813190a314555c1773a982de16da0e59))
* **taiko-client:** open container logs and close build image logs ([#17959](https://github.com/taikoxyz/taiko-mono/issues/17959)) ([b541201](https://github.com/taikoxyz/taiko-mono/commit/b54120141f0e18f1912db66d28390d2a92af36c9))
* **taiko-client:** update HIVE test configurations ([#17950](https://github.com/taikoxyz/taiko-mono/issues/17950)) ([4818274](https://github.com/taikoxyz/taiko-mono/commit/4818274860e8d626e5456479a520229e7c17f31c))

## [0.31.0](https://github.com/taikoxyz/taiko-mono/compare/taiko-client-v0.30.0...taiko-client-v0.31.0) (2024-08-20)


### Features

* **taiko-client:** update hekla's protocol config ([#17955](https://github.com/taikoxyz/taiko-mono/issues/17955)) ([4b6a70d](https://github.com/taikoxyz/taiko-mono/commit/4b6a70dd4fb22146ee6702b8484a4a2b4fbce6c2))

## [0.30.0](https://github.com/taikoxyz/taiko-mono/compare/taiko-client-v0.29.0...taiko-client-v0.30.0) (2024-08-19)


### Features

* **protocol:** introduce `AssembleAnchorV2Tx` method in `AnchorTxConstructor` ([#17850](https://github.com/taikoxyz/taiko-mono/issues/17850)) ([f71b178](https://github.com/taikoxyz/taiko-mono/commit/f71b1780eb98ff3cbbcf7def4388837f33e3fe37))
* **protocol:** introduce risc0 proof ([#17877](https://github.com/taikoxyz/taiko-mono/issues/17877)) ([bcb57cb](https://github.com/taikoxyz/taiko-mono/commit/bcb57cb81d12d0c09656582ad9140b38015b3a58))
* **taiko-client:** add `RaikoZKVMHostEndpoint` and rename ([#17926](https://github.com/taikoxyz/taiko-mono/issues/17926)) ([0838f79](https://github.com/taikoxyz/taiko-mono/commit/0838f7993015fc9fc9cacfb3da7b100d52bc856c))
* **taiko-client:** changes based on the latest basefee improvements ([#17911](https://github.com/taikoxyz/taiko-mono/issues/17911)) ([0c10ac9](https://github.com/taikoxyz/taiko-mono/commit/0c10ac9c4973d3ef8a5e35a8646516639b328fa0))
* **taiko-client:** client changes for `ontake` fork ([#17746](https://github.com/taikoxyz/taiko-mono/issues/17746)) ([2aabf3d](https://github.com/taikoxyz/taiko-mono/commit/2aabf3de3456ce8cbd56d15be336d08445b9f242))
* **taiko-client:** client updates based on [#17871](https://github.com/taikoxyz/taiko-mono/issues/17871) ([#17873](https://github.com/taikoxyz/taiko-mono/issues/17873)) ([dbed3ab](https://github.com/taikoxyz/taiko-mono/commit/dbed3aba3d7f49f982f6335b79f5d5b096f890a3))
* **taiko-client:** introduce `BasefeeSharingPctg` in `BlockMetadata` ([#17853](https://github.com/taikoxyz/taiko-mono/issues/17853)) ([5f2d696](https://github.com/taikoxyz/taiko-mono/commit/5f2d6961b9d077e47f34bf7f5d1fbffaf380bde1))
* **taiko-client:** introduce `TaikoDataBlockV2` ([#17936](https://github.com/taikoxyz/taiko-mono/issues/17936)) ([c608116](https://github.com/taikoxyz/taiko-mono/commit/c608116523922fa4664968dc73608a118b5b97ba))
* **taiko-client:** introduce `TierZkVMRisc0ID` ([#17915](https://github.com/taikoxyz/taiko-mono/issues/17915)) ([96aa5c2](https://github.com/taikoxyz/taiko-mono/commit/96aa5c2a5cd096ac3560fe17106ec042a877bfc1))
* **taiko-client:** remove `basefeeSharingPctg` from metadata ([#17890](https://github.com/taikoxyz/taiko-mono/issues/17890)) ([57c8f6f](https://github.com/taikoxyz/taiko-mono/commit/57c8f6f3a8f920bab8fecd75bfa36a6b71ef808d))
* **taiko-client:** update `BlockParamsV2` struct ([#17893](https://github.com/taikoxyz/taiko-mono/issues/17893)) ([a1043a8](https://github.com/taikoxyz/taiko-mono/commit/a1043a85631892e0b03e0f9f4bb850d4e9a70967))
* **taiko-client:** update Go contract bindings ([#17869](https://github.com/taikoxyz/taiko-mono/issues/17869)) ([d9bd72b](https://github.com/taikoxyz/taiko-mono/commit/d9bd72b76aa0bed4ccfe834053f6561a53e1367d))
* **taiko-client:** update Go contract bindings ([#17885](https://github.com/taikoxyz/taiko-mono/issues/17885)) ([3179074](https://github.com/taikoxyz/taiko-mono/commit/31790747cfc743b218d5a3568b9d70b64df5a86c))
* **taiko-client:** update ontake basefee calculation ([#17892](https://github.com/taikoxyz/taiko-mono/issues/17892)) ([6972dea](https://github.com/taikoxyz/taiko-mono/commit/6972dea313edbc9a30617d2f7aea2dfc9230c432))


### Bug Fixes

* **taiko-client:** avoid seting nil value to `GuardianProverHeartbeater` ([#17802](https://github.com/taikoxyz/taiko-mono/issues/17802)) ([4076324](https://github.com/taikoxyz/taiko-mono/commit/40763241b5f2960f019d6be7e1040c65765f938a))
* **taiko-client:** fix zk status recognition ([#17946](https://github.com/taikoxyz/taiko-mono/issues/17946)) ([164e476](https://github.com/taikoxyz/taiko-mono/commit/164e47686f41cbb119a230c7a1ad56ef4d0b3117))


### Chores

* **protocol:** revert `TAIKO_TOKEN` name changes in `DeployOnL1` ([#17927](https://github.com/taikoxyz/taiko-mono/issues/17927)) ([cf1a15f](https://github.com/taikoxyz/taiko-mono/commit/cf1a15f46344e60448c5fdcbcae02521fb5b7c04))
* **taiko-client:** add hive tests to workflow ([#17897](https://github.com/taikoxyz/taiko-mono/issues/17897)) ([323d728](https://github.com/taikoxyz/taiko-mono/commit/323d7285d83b83adfd220747fb3f55b5cd72d877))
* **taiko-client:** update `hive_tests.sh` ([#17923](https://github.com/taikoxyz/taiko-mono/issues/17923)) ([05d49b0](https://github.com/taikoxyz/taiko-mono/commit/05d49b07f9131bc034d00ad6cb7b7868a9af2bfc))


### Code Refactoring

* **taiko-client:** rm unused `L1_NODE_HTTP_ENDPOINT` ([#17768](https://github.com/taikoxyz/taiko-mono/issues/17768)) ([73c7aee](https://github.com/taikoxyz/taiko-mono/commit/73c7aeeffaffbf875af84e8be595af828877be2b))


### Tests

* **taiko-client:** update hive dependence and fix bug about hive test ([#17930](https://github.com/taikoxyz/taiko-mono/issues/17930)) ([dd40a4e](https://github.com/taikoxyz/taiko-mono/commit/dd40a4e6696b9c27135823cd545e7e5249a66e8c))
* **taiko-client:** use env names which defined in flag configs ([#17921](https://github.com/taikoxyz/taiko-mono/issues/17921)) ([196b74e](https://github.com/taikoxyz/taiko-mono/commit/196b74eb2b4498bc3e6511915e011a885fcc530f))

## [0.29.0](https://github.com/taikoxyz/taiko-mono/compare/taiko-client-v0.28.0...taiko-client-v0.29.0) (2024-07-05)


### Features

* **taiko-client:** add `--epoch.minTip` flag ([#17726](https://github.com/taikoxyz/taiko-mono/issues/17726)) ([a331e9d](https://github.com/taikoxyz/taiko-mono/commit/a331e9d88b72f5f07e43a711dd9a3ac913c4d4f6))
* **taiko-client:** add `defaultRequestTimeout` for `SGXProofProducer` ([#17724](https://github.com/taikoxyz/taiko-mono/issues/17724)) ([e301451](https://github.com/taikoxyz/taiko-mono/commit/e3014519cebaef6a5a37d7982121c39f5b82ee27))
* **taiko-client:** add proof status check before generating proof ([#17711](https://github.com/taikoxyz/taiko-mono/issues/17711)) ([9a8e15e](https://github.com/taikoxyz/taiko-mono/commit/9a8e15eccb720dda3a703937aae5c8ae3dc495c2))
* **taiko-client:** call `CreateAccessList` ([#17691](https://github.com/taikoxyz/taiko-mono/issues/17691)) ([9bb4b9c](https://github.com/taikoxyz/taiko-mono/commit/9bb4b9c94f3bc2a8fef1c793d13bf749d8c0614f))
* **taiko-client:** improve `ProverProvenByGuardianGauge` metric ([#17703](https://github.com/taikoxyz/taiko-mono/issues/17703)) ([c88fcd1](https://github.com/taikoxyz/taiko-mono/commit/c88fcd11fa29beb6a7529e5b8bf172a6a9cd6ecd))
* **taiko-client:** introduce `--epoch.allowZeroInterval` flag ([#17727](https://github.com/taikoxyz/taiko-mono/issues/17727)) ([e76890d](https://github.com/taikoxyz/taiko-mono/commit/e76890d9223cdd68d3d97202a9a12a1f6d9b217f))
* **taiko-client:** introduce `AccessList` ([#17676](https://github.com/taikoxyz/taiko-mono/issues/17676)) ([3c95477](https://github.com/taikoxyz/taiko-mono/commit/3c95477a284ac94c7e3ce85c9cefdadc1aaacd06))
* **taiko-client:** introduce `TryDecompressHekla()` ([#17735](https://github.com/taikoxyz/taiko-mono/issues/17735)) ([67a7a37](https://github.com/taikoxyz/taiko-mono/commit/67a7a372a3931a0959a2422c753e97bddaa35961))
* **taiko-client:** make request timeout to raiko configurable ([#17728](https://github.com/taikoxyz/taiko-mono/issues/17728)) ([f8f796c](https://github.com/taikoxyz/taiko-mono/commit/f8f796cc87e1d2398af299716960c9d03cdfcb35))
* **taiko-client:** remove prover server package ([#17748](https://github.com/taikoxyz/taiko-mono/issues/17748)) ([b064ea0](https://github.com/taikoxyz/taiko-mono/commit/b064ea0a22413a7856cd7d41a2ac92a0beeba556))
* **taiko-client:** revert access list changes ([#17694](https://github.com/taikoxyz/taiko-mono/issues/17694)) ([fd15dab](https://github.com/taikoxyz/taiko-mono/commit/fd15dabc01666fdbee949a9ecb6805d2ce8fc7f9))
* **taiko-client:** update bindings && fix tests ([#17680](https://github.com/taikoxyz/taiko-mono/issues/17680)) ([10b95e1](https://github.com/taikoxyz/taiko-mono/commit/10b95e1c54dfe77de2badbe77439c2449cc9a65e))
* **taiko-client:** update Go contract bindings ([#17733](https://github.com/taikoxyz/taiko-mono/issues/17733)) ([9d18504](https://github.com/taikoxyz/taiko-mono/commit/9d185041c7fe9c3787f1a73f89bb0dc6cfce32bc))


### Code Refactoring

* **taiko-client:** rm tier fee related flag ([#17750](https://github.com/taikoxyz/taiko-mono/issues/17750)) ([b41437b](https://github.com/taikoxyz/taiko-mono/commit/b41437b47a8ad3bc68edbfb8d9aea6b2fbbe9b05))
* **taiko-client:** rm unused code and refactor ([#17723](https://github.com/taikoxyz/taiko-mono/issues/17723)) ([8c9a032](https://github.com/taikoxyz/taiko-mono/commit/8c9a0329b2702d68e18ba97c506c5d1ad20c92c7))
* **taiko-client:** rm unused tier fee ([#17740](https://github.com/taikoxyz/taiko-mono/issues/17740)) ([3e139fa](https://github.com/taikoxyz/taiko-mono/commit/3e139fa4114807d68d02d2af30c7d5ad3759ec38))

## [0.28.0](https://github.com/taikoxyz/taiko-mono/compare/taiko-client-v0.27.1...taiko-client-v0.28.0) (2024-06-24)


### Features

* **taiko-client:** improve some comments in prover ([#17668](https://github.com/taikoxyz/taiko-mono/issues/17668)) ([e7afcfe](https://github.com/taikoxyz/taiko-mono/commit/e7afcfe18399240fbac04a7d90a52fe17edcab67))


### Chores

* **taiko-client:** revert the failed cross-compilation ([#17670](https://github.com/taikoxyz/taiko-mono/issues/17670)) ([0a1de79](https://github.com/taikoxyz/taiko-mono/commit/0a1de792eaf0c17de1b873a465febe1dca9ce16a))

## [0.27.1](https://github.com/taikoxyz/taiko-mono/compare/taiko-client-v0.27.0...taiko-client-v0.27.1) (2024-06-24)


### Bug Fixes

* **taiko-client:** remove Go build cache ([#17661](https://github.com/taikoxyz/taiko-mono/issues/17661)) ([f6075f7](https://github.com/taikoxyz/taiko-mono/commit/f6075f75ca57b8136e7edfed2b73912c79ccec63))

## [0.27.0](https://github.com/taikoxyz/taiko-mono/compare/taiko-client-v0.26.0...taiko-client-v0.27.0) (2024-06-24)


### Features

* **taiko-client:** build using cross-compilation ([#17564](https://github.com/taikoxyz/taiko-mono/issues/17564)) ([e66a0c8](https://github.com/taikoxyz/taiko-mono/commit/e66a0c889eade8e323255d3129faa4fd512d5c94))
* **taiko-client:** disable hook in client ([#17642](https://github.com/taikoxyz/taiko-mono/issues/17642)) ([099ce22](https://github.com/taikoxyz/taiko-mono/commit/099ce22139e8c545a46369dce158de4b9bb6297e))
* **taiko-client:** update Go contract bindings ([#17568](https://github.com/taikoxyz/taiko-mono/issues/17568)) ([f190919](https://github.com/taikoxyz/taiko-mono/commit/f19091941362609b736bbbf1eee28fc459fc324a))

## [0.26.0](https://github.com/taikoxyz/taiko-mono/compare/taiko-client-v0.25.0...taiko-client-v0.26.0) (2024-06-08)


### Features

* **taiko-client:** allow hooks to be empty if prover and proposer are the same address ([#17520](https://github.com/taikoxyz/taiko-mono/issues/17520)) ([2db6d2c](https://github.com/taikoxyz/taiko-mono/commit/2db6d2c3a978b75f0f57337f1481d1a1066594ea))


### Bug Fixes

* **taiko-client:** fix an address check in `AssignProver` ([#17526](https://github.com/taikoxyz/taiko-mono/issues/17526)) ([d6001d3](https://github.com/taikoxyz/taiko-mono/commit/d6001d3f52bed12ff962c7558b9fc173fc964ddb))

## [0.25.0](https://github.com/taikoxyz/taiko-mono/compare/taiko-client-v0.24.0...taiko-client-v0.25.0) (2024-06-04)


### Features

* **taiko-client:** remove useless function and correct erorr handling ([#17463](https://github.com/taikoxyz/taiko-mono/issues/17463)) ([4e93a57](https://github.com/taikoxyz/taiko-mono/commit/4e93a57e11980c199be7d38aaefcd64dacb96131))
* **taiko-client:** update bindings based on protocol `TierRouter` update ([#17475](https://github.com/taikoxyz/taiko-mono/issues/17475)) ([0e9d160](https://github.com/taikoxyz/taiko-mono/commit/0e9d1608635fefaa34b1a07900978b22efe14712))

## [0.24.0](https://github.com/taikoxyz/taiko-mono/compare/taiko-client-v0.23.1...taiko-client-v0.24.0) (2024-05-30)


### Features

* **taiko-client:** improve chain head check in `NeedReSync` ([#17431](https://github.com/taikoxyz/taiko-mono/issues/17431)) ([4dbe0af](https://github.com/taikoxyz/taiko-mono/commit/4dbe0af09c97d85706325a6bc1a270383930a62c))

## [0.23.1](https://github.com/taikoxyz/taiko-mono/compare/taiko-client-v0.23.0...taiko-client-v0.23.1) (2024-05-29)


### Bug Fixes

* **taiko-client:** fix an url path issue in `BeaconClient` ([#17417](https://github.com/taikoxyz/taiko-mono/issues/17417)) ([012d532](https://github.com/taikoxyz/taiko-mono/commit/012d53272b8e59aed87f7757ec11008a24702f14))

## [0.23.0](https://github.com/taikoxyz/taiko-mono/compare/taiko-client-v0.22.0...taiko-client-v0.23.0) (2024-05-26)


### Features

* **bridge-ui:** release  ([#17071](https://github.com/taikoxyz/taiko-mono/issues/17071)) ([2fa3ae0](https://github.com/taikoxyz/taiko-mono/commit/2fa3ae0b2b2317a467709110c381878a3a9f8ec6))
* **taiko-client:** bump Go contract bindings ([#17068](https://github.com/taikoxyz/taiko-mono/issues/17068)) ([f1462c2](https://github.com/taikoxyz/taiko-mono/commit/f1462c28aa72104a20a2bcdf805092eab35f62a7))
* **taiko-client:** change guardian provers  to directly submit proofs instead of contests ([#17069](https://github.com/taikoxyz/taiko-mono/issues/17069)) ([d669263](https://github.com/taikoxyz/taiko-mono/commit/d66926308681893aa7e7342288d157d9a5e1b392))
* **taiko-client:** fix a prover flag ([#17315](https://github.com/taikoxyz/taiko-mono/issues/17315)) ([5806fcc](https://github.com/taikoxyz/taiko-mono/commit/5806fccea1f595c2db71ba438a324fbfd8e464ed))
* **taiko-client:** improve progress tracker ([#17281](https://github.com/taikoxyz/taiko-mono/issues/17281)) ([5d05226](https://github.com/taikoxyz/taiko-mono/commit/5d0522601a4343c930322d448e4989129561f38b))
* **taiko-client:** integrate `ProverSet` in client ([#17253](https://github.com/taikoxyz/taiko-mono/issues/17253)) ([f086850](https://github.com/taikoxyz/taiko-mono/commit/f086850906920ffad604805678c7813097f57719))
* **taiko-client:** integrate new Raiko APIs (openAPI) ([#17039](https://github.com/taikoxyz/taiko-mono/issues/17039)) ([e36d5b7](https://github.com/taikoxyz/taiko-mono/commit/e36d5b7708b11b14e811f066fb7302a15fd7c24a))
* **taiko-client:** integrate new Raiko APIs (openAPI) ([#17254](https://github.com/taikoxyz/taiko-mono/issues/17254)) ([fea1cbe](https://github.com/taikoxyz/taiko-mono/commit/fea1cbe594460365d63f6d08815bc95b50bb4af1))
* **taiko-client:** integrate SocialScan blob storage service ([#17297](https://github.com/taikoxyz/taiko-mono/issues/17297)) ([0aaa6ce](https://github.com/taikoxyz/taiko-mono/commit/0aaa6ce56fd6a7e4497c97c68257bba8ac770e2e))
* **taiko-client:** only invalid status need to return error ([#17266](https://github.com/taikoxyz/taiko-mono/issues/17266)) ([e7111e0](https://github.com/taikoxyz/taiko-mono/commit/e7111e0a84dcdad0a695c62be69304a02763e4a0))
* **taiko-client:** private key both with and without the hex prefix ([#17098](https://github.com/taikoxyz/taiko-mono/issues/17098)) ([f80504a](https://github.com/taikoxyz/taiko-mono/commit/f80504aa167ea8593e2e184f2a44355f9159d7f9))
* **taiko-client:** remove `raiko` from guardian prover ([#17289](https://github.com/taikoxyz/taiko-mono/issues/17289)) ([bed6414](https://github.com/taikoxyz/taiko-mono/commit/bed641486e79e346c7ca49190cb77c18859621bf))
* **taiko-client:** remove an unused file ([#17166](https://github.com/taikoxyz/taiko-mono/issues/17166)) ([5a9b0ec](https://github.com/taikoxyz/taiko-mono/commit/5a9b0ecb0e1a7740c80d7fa1dff98266347bc337))
* **taiko-client:** remove useless flags about raiko ([#17302](https://github.com/taikoxyz/taiko-mono/issues/17302)) ([7945142](https://github.com/taikoxyz/taiko-mono/commit/794514227afee296e1e2fed82e85769cc5efe1d0))
* **taiko-client:** revert the change of handling forkchoiceupdate status ([#17288](https://github.com/taikoxyz/taiko-mono/issues/17288)) ([140aa25](https://github.com/taikoxyz/taiko-mono/commit/140aa251f70c7985782d7a141c1839f19374acc2))
* **taiko-client:** switching from blobstorage server to blobscan-api ([#17244](https://github.com/taikoxyz/taiko-mono/issues/17244)) ([fbdb7c0](https://github.com/taikoxyz/taiko-mono/commit/fbdb7c078e738cb2c170299ac2bee0f72ec3601b))
* **taiko-client:** temp log ([#17324](https://github.com/taikoxyz/taiko-mono/issues/17324)) ([c96c6ee](https://github.com/taikoxyz/taiko-mono/commit/c96c6eee4f43d1aab284c60287b2928d382275ef))
* **taiko-client:** update Go contract bindings ([#17086](https://github.com/taikoxyz/taiko-mono/issues/17086)) ([14ebeff](https://github.com/taikoxyz/taiko-mono/commit/14ebeffd8cb4ed148d79789009444b54359bf77f))
* **taiko-client:** use taiko-geth params ([#17044](https://github.com/taikoxyz/taiko-mono/issues/17044)) ([9e85e2f](https://github.com/taikoxyz/taiko-mono/commit/9e85e2fe3ba15f72fb3bbc6fa165a71a7aaee845))


### Bug Fixes

* **taiko-client:** `config.LProposerPrivKey` loads an incorrect flag value ([#17107](https://github.com/taikoxyz/taiko-mono/issues/17107)) ([8f69963](https://github.com/taikoxyz/taiko-mono/commit/8f699634ecd953e7b159d72c3676e08e58a81460))
* **taiko-client:** fix a JWT parsing issue ([#17325](https://github.com/taikoxyz/taiko-mono/issues/17325)) ([6c30f93](https://github.com/taikoxyz/taiko-mono/commit/6c30f9351d215748903a517fff59138d3ccf3f39))
* **taiko-client:** fix a prover balance check issue ([#17318](https://github.com/taikoxyz/taiko-mono/issues/17318)) ([f0b26b9](https://github.com/taikoxyz/taiko-mono/commit/f0b26b90847f6652793807a6bd8897b0d994bca0))
* **taiko-client:** fix an issue in `BlockProposed` event handler && remove some unused code ([#17065](https://github.com/taikoxyz/taiko-mono/issues/17065)) ([5c4a025](https://github.com/taikoxyz/taiko-mono/commit/5c4a0251b6a52300a460acd82bd98b23adaeefa5))
* **taiko-client:** fix an issue in `checkMinEthAndToken` ([#17320](https://github.com/taikoxyz/taiko-mono/issues/17320)) ([e007150](https://github.com/taikoxyz/taiko-mono/commit/e0071506e1e64e97c4f3474c765be3ba93e7b57a))
* **taiko-client:** fix an issue in `CreateAssignment` ([#17323](https://github.com/taikoxyz/taiko-mono/issues/17323)) ([5ddb4c5](https://github.com/taikoxyz/taiko-mono/commit/5ddb4c56994fbf7336dd4fa6e096e9a699ce4a5f))
* **taiko-client:** remove useless config in prover ([#17335](https://github.com/taikoxyz/taiko-mono/issues/17335)) ([3c37890](https://github.com/taikoxyz/taiko-mono/commit/3c37890cadb15bcc28d0de22b139a7c681e4d08d))

## [0.22.0](https://github.com/taikoxyz/taiko-client/compare/v0.21.0...v0.22.0) (2024-04-19)


### Features

* **bindings:** update Go contract bindings && bump `taiko-geth` version ([#727](https://github.com/taikoxyz/taiko-client/issues/727)) ([1003687](https://github.com/taikoxyz/taiko-client/commit/1003687d909fe72936834ba345deeb294fa06d8e))
* **cmd:** default unit for all related flags / logs ([#729](https://github.com/taikoxyz/taiko-client/issues/729)) ([ec7ba9d](https://github.com/taikoxyz/taiko-client/commit/ec7ba9d696fe1b051de5e12878553fe035c046fa))
* **driver:** only allow one successful beacon sync ([#718](https://github.com/taikoxyz/taiko-client/issues/718)) ([e6d48ab](https://github.com/taikoxyz/taiko-client/commit/e6d48abb4308c93e7bc3e0d070e7934bb5cfe9b6))
* **metrics:** collect `txmgr` metrics ([#725](https://github.com/taikoxyz/taiko-client/issues/725)) ([7fb762a](https://github.com/taikoxyz/taiko-client/commit/7fb762a6cf101b905f1d3bcb8c0adacd77467518))
* **metrics:** remove an unused metric ([#712](https://github.com/taikoxyz/taiko-client/issues/712)) ([76f4003](https://github.com/taikoxyz/taiko-client/commit/76f40038cef70e4736f87c9568c8a70779b47d98))
* **metrics:** remove some unused metrics ([#724](https://github.com/taikoxyz/taiko-client/issues/724)) ([bce8ebb](https://github.com/taikoxyz/taiko-client/commit/bce8ebbdffd7144be3d54b75efdae2c08e74d455))
* **proposer:** introduce `TxSender` for proposer ([#723](https://github.com/taikoxyz/taiko-client/issues/723)) ([c71155e](https://github.com/taikoxyz/taiko-client/commit/c71155e1fa2d0ba0359d36ab98d450855e022dfa))
* **prover:** check proof status before sending the transaction ([#731](https://github.com/taikoxyz/taiko-client/issues/731)) ([a9d637a](https://github.com/taikoxyz/taiko-client/commit/a9d637a2fd086d6dfc0236c6f13c918c7eb7816c))
* **prover:** introduce three `raiko` related flags ([#711](https://github.com/taikoxyz/taiko-client/issues/711)) ([7540be2](https://github.com/taikoxyz/taiko-client/commit/7540be21d88a4689f03aa866d93475843f798770))
* **prover:** use `--guardian.submissionDelay` flag ([#730](https://github.com/taikoxyz/taiko-client/issues/730)) ([c7db741](https://github.com/taikoxyz/taiko-client/commit/c7db7419a66ffa3cfd21b28a32ac3a1528e09b48))
* **rpc:** improve `L2ParentByBlockID` ([#715](https://github.com/taikoxyz/taiko-client/issues/715)) ([036f8e6](https://github.com/taikoxyz/taiko-client/commit/036f8e643b09c0125a7cf4a0da265463289596df))
* **rpc:** keep retrying when connecting to endpoints ([#708](https://github.com/taikoxyz/taiko-client/issues/708)) ([771f133](https://github.com/taikoxyz/taiko-client/commit/771f1334e7efacc17e6ff0f5768a5cf54eecafb3))
* **rpc:** remove `WaitL1Origin()` method ([#716](https://github.com/taikoxyz/taiko-client/issues/716)) ([70913c6](https://github.com/taikoxyz/taiko-client/commit/70913c60edc87bb93cbc185277f4862c5420cade))


### Bug Fixes

* **proposer:** fix an issue in `ProposeOp` ([#728](https://github.com/taikoxyz/taiko-client/issues/728)) ([24a8e1d](https://github.com/taikoxyz/taiko-client/commit/24a8e1d52270c9f1681a2e1d6ca376d7c1faf4a7))

## [0.21.0](https://github.com/taikoxyz/taiko-client/compare/v0.20.0...v0.21.0) (2024-04-10)


### Features

* **bindings:** bump bindings ([#671](https://github.com/taikoxyz/taiko-client/issues/671)) ([16fe52a](https://github.com/taikoxyz/taiko-client/commit/16fe52a94337ab27a53c8c6213a6c13702b79171))
* **bindings:** update Go contract bindings ([#680](https://github.com/taikoxyz/taiko-client/issues/680)) ([b64bf1a](https://github.com/taikoxyz/taiko-client/commit/b64bf1a6a5a5ebce0c312d40ea13155db55d0b21))
* **bindings:** update Go contract bindings ([#689](https://github.com/taikoxyz/taiko-client/issues/689)) ([fd98d4b](https://github.com/taikoxyz/taiko-client/commit/fd98d4bab4be82d0220e8805e17592feceabb519))
* **bindings:** update Go contract bindings ([#697](https://github.com/taikoxyz/taiko-client/issues/697)) ([993d491](https://github.com/taikoxyz/taiko-client/commit/993d4919958181e38cc413a73ea278c8ab5ab439))
* **bindings:** update Go contract bindings ([#705](https://github.com/taikoxyz/taiko-client/issues/705)) ([a97255d](https://github.com/taikoxyz/taiko-client/commit/a97255dd18df15a4a2ad47f900bc5458679546d6))
* **cmd:** revert `SubcommandApplication` context changes ([#701](https://github.com/taikoxyz/taiko-client/issues/701)) ([985f030](https://github.com/taikoxyz/taiko-client/commit/985f030209029c3f8fca6dc814b524c7ef16b898))
* **driver:** add blob datasource ([#688](https://github.com/taikoxyz/taiko-client/issues/688)) ([a598847](https://github.com/taikoxyz/taiko-client/commit/a5988478251179a72dd7b5ca71754b8c0fbeb666))
* **driver:** fix the latest verified block hash check when using snap sync ([#700](https://github.com/taikoxyz/taiko-client/issues/700)) ([3cae4ea](https://github.com/taikoxyz/taiko-client/commit/3cae4eadc24f07b87808db0df419c894b0c93357))
* **driver:** improve driver implementation ([#672](https://github.com/taikoxyz/taiko-client/issues/672)) ([55717c8](https://github.com/taikoxyz/taiko-client/commit/55717c8ff8c9541640c5368c2e937451ae6af7aa))
* **driver:** update snap sync strategy ([#695](https://github.com/taikoxyz/taiko-client/issues/695)) ([7a68a25](https://github.com/taikoxyz/taiko-client/commit/7a68a25f6c16878e0cf44b3ef3816e9f6544d263))
* **flags:** remove `--rpc.waitReceiptTimeout` flag ([#684](https://github.com/taikoxyz/taiko-client/issues/684)) ([a70519b](https://github.com/taikoxyz/taiko-client/commit/a70519b585ac19a1ad8df629edf8364a3afaf8cf))
* **pkg:** update `WaitTillL2ExecutionEngineSynced` ([#677](https://github.com/taikoxyz/taiko-client/issues/677)) ([2c2b996](https://github.com/taikoxyz/taiko-client/commit/2c2b996be04d445b289a9c65aebb01f4afd1ed3b))
* **proof_producer:** update `sgxProducer` request body ([#693](https://github.com/taikoxyz/taiko-client/issues/693)) ([ba40ced](https://github.com/taikoxyz/taiko-client/commit/ba40ceddea6857f68d9a0187e490306038ee1e48))
* **proof_producer:** update SGX `proofParam.bootstrap` to `false` ([#694](https://github.com/taikoxyz/taiko-client/issues/694)) ([78d5303](https://github.com/taikoxyz/taiko-client/commit/78d5303033992c46f7edd22ae1384eff59fa735d))
* **proposer:** add more tests for propsoer ([#686](https://github.com/taikoxyz/taiko-client/issues/686)) ([cd26204](https://github.com/taikoxyz/taiko-client/commit/cd2620486c8cd8e1c4f293036e4afc3dabec46cb))
* **proposer:** improve proposing strategy  ([#682](https://github.com/taikoxyz/taiko-client/issues/682)) ([62cc7ff](https://github.com/taikoxyz/taiko-client/commit/62cc7ffcc3e7b08fb1bd040081a34bf676ec0832))
* **proposer:** remove `--tierFee.max` flag ([#702](https://github.com/taikoxyz/taiko-client/issues/702)) ([553c432](https://github.com/taikoxyz/taiko-client/commit/553c4322812f69e8ace719612e4c3f7696263cd2))
* **prover_producer:** update `SGXRequestProofBodyParam` ([#691](https://github.com/taikoxyz/taiko-client/issues/691)) ([41c2019](https://github.com/taikoxyz/taiko-client/commit/41c201937aa5613e3d4d81a3478f2c67a942b387))
* **prover:** stop retrying when error is `vm.ErrExecutionReverted` ([#706](https://github.com/taikoxyz/taiko-client/issues/706)) ([971f581](https://github.com/taikoxyz/taiko-client/commit/971f5815d767c0d152cac510c67928dc4e355279))


### Bug Fixes

* **pkg:** remove redundant alias ([#665](https://github.com/taikoxyz/taiko-client/issues/665)) ([bd1c324](https://github.com/taikoxyz/taiko-client/commit/bd1c3241554cbbf3a905a3cf1554368870dacf9e))
* **proposer:** fix tier fee ([#687](https://github.com/taikoxyz/taiko-client/issues/687)) ([651f188](https://github.com/taikoxyz/taiko-client/commit/651f18891d77e87f9ee4906b7298e8ab89deb1ee))
* **proposer:** rename `lastUnfilteredPoolContentProposedAt` ([#685](https://github.com/taikoxyz/taiko-client/issues/685)) ([8c85703](https://github.com/taikoxyz/taiko-client/commit/8c8570313a2e37f63284a1f78eee2d7eded09dde))
* **prover:** do not retry when the status in receipt is not `types.ReceiptStatusSuccessful` ([#675](https://github.com/taikoxyz/taiko-client/issues/675)) ([5f91e0e](https://github.com/taikoxyz/taiko-client/commit/5f91e0e4f2788b71f3ea6c814171a0d4532c0918))
* **prover:** fix `tx.gasLimit` flag for prover ([#692](https://github.com/taikoxyz/taiko-client/issues/692)) ([6683d54](https://github.com/taikoxyz/taiko-client/commit/6683d54e7526c53197e9bc6d414f2cfca586a1bd))
* **prover:** fix a check in `isValidProof()` ([#679](https://github.com/taikoxyz/taiko-client/issues/679)) ([16857ba](https://github.com/taikoxyz/taiko-client/commit/16857ba2d07bc969223f90fcd20c5dbae084beaa))

## [0.20.0](https://github.com/taikoxyz/taiko-client/compare/v0.19.0...v0.20.0) (2024-03-28)


### Features

* **all:** clean up unused signal service related code ([#581](https://github.com/taikoxyz/taiko-client/issues/581)) ([13f896a](https://github.com/taikoxyz/taiko-client/commit/13f896af4689df14853ceb838fd6eb1e0a64a9ba))
* **all:** use an unified transaction sender implementation ([#560](https://github.com/taikoxyz/taiko-client/issues/560)) ([1bd56c0](https://github.com/taikoxyz/taiko-client/commit/1bd56c0d660842fb499336d011e87d7b30c527b9))
* **bindings:** update Go contract bindings ([#561](https://github.com/taikoxyz/taiko-client/issues/561)) ([bacedb0](https://github.com/taikoxyz/taiko-client/commit/bacedb0c3dcffd973c61e901529cfba773812e64))
* **bindings:** update Go contract bindings ([#570](https://github.com/taikoxyz/taiko-client/issues/570)) ([e70b7a0](https://github.com/taikoxyz/taiko-client/commit/e70b7a031bc069d527d5518d7928f969fd2c15c1))
* **bindings:** update Go contract bindings ([#574](https://github.com/taikoxyz/taiko-client/issues/574)) ([ac9788f](https://github.com/taikoxyz/taiko-client/commit/ac9788f44b5fbb56a1f438a77114a8601e84689f))
* **bindings:** update Go contract bindings ([#583](https://github.com/taikoxyz/taiko-client/issues/583)) ([1acfc5f](https://github.com/taikoxyz/taiko-client/commit/1acfc5f982c48843fecdceec0dd07dad1d1154e4))
* **bindings:** update Go contract bindings ([#587](https://github.com/taikoxyz/taiko-client/issues/587)) ([2237295](https://github.com/taikoxyz/taiko-client/commit/2237295da0fb9cf259e8dc58de1426e4f1a67989))
* **bindings:** update Go contract bindings ([#607](https://github.com/taikoxyz/taiko-client/issues/607)) ([1b03e6a](https://github.com/taikoxyz/taiko-client/commit/1b03e6a8aadfb960ba2d91a1796ff70a92bcb9fb))
* **bindings:** update Go contract bindings ([#619](https://github.com/taikoxyz/taiko-client/issues/619)) ([4145dae](https://github.com/taikoxyz/taiko-client/commit/4145dae931b414eb719f1fab565f5d2156cec12a))
* **bindings:** update Go contract bindings ([#646](https://github.com/taikoxyz/taiko-client/issues/646)) ([13c6ac2](https://github.com/taikoxyz/taiko-client/commit/13c6ac2ba96c5c4de7da8a20ebe6bbf66e872c8f))
* **bindings:** update Go contract bindings ([#657](https://github.com/taikoxyz/taiko-client/issues/657)) ([eb3cd58](https://github.com/taikoxyz/taiko-client/commit/eb3cd5832b3e7713eb7bcf5716deb6f6fb5fbca5))
* **bindings:** update Go contract bindings ([#660](https://github.com/taikoxyz/taiko-client/issues/660)) ([6fe4dda](https://github.com/taikoxyz/taiko-client/commit/6fe4dda3752164dd441e49cdc15ba6584b9be568))
* **bindings:** update Go contract bindings && add more logs for prover ([#632](https://github.com/taikoxyz/taiko-client/issues/632)) ([1c90c6a](https://github.com/taikoxyz/taiko-client/commit/1c90c6a4ed3244e0bd176625f17cfbcbc1f36c0e))
* **blob:** fix bug when blob decode with 0 ([#627](https://github.com/taikoxyz/taiko-client/issues/627)) ([df0e897](https://github.com/taikoxyz/taiko-client/commit/df0e8974ae79f116363f027116d13532349929e6))
* **blob:** set min blob fee ([#636](https://github.com/taikoxyz/taiko-client/issues/636)) ([1727fc5](https://github.com/taikoxyz/taiko-client/commit/1727fc532d505526d99e85a11d4927b7bf32f73c))
* **driver:** fix a block number issue ([#656](https://github.com/taikoxyz/taiko-client/issues/656)) ([eced566](https://github.com/taikoxyz/taiko-client/commit/eced566090f4c98456efa4a5e00544d1bccfd915))
* **driver:** improve driver implementation ([#639](https://github.com/taikoxyz/taiko-client/issues/639)) ([fbd4d06](https://github.com/taikoxyz/taiko-client/commit/fbd4d06ac41cfd13aba729d037f664947f984092))
* **driver:** improve driver state ([#591](https://github.com/taikoxyz/taiko-client/issues/591)) ([1fd9084](https://github.com/taikoxyz/taiko-client/commit/1fd908415d9ef2d7956d1c3565ad4f18f003dc76))
* **driver:** introduce `StateVariablesUpdated` event ([#666](https://github.com/taikoxyz/taiko-client/issues/666)) ([8ecd440](https://github.com/taikoxyz/taiko-client/commit/8ecd44066eccf674561713ce21187f5cd23bd21a))
* **driver:** update `defaultMaxTxPerBlock` ([#604](https://github.com/taikoxyz/taiko-client/issues/604)) ([3f99b4a](https://github.com/taikoxyz/taiko-client/commit/3f99b4a67896e1fa88a0cfcb8eff8eabc779d6b7))
* **driver:** update `ForkchoiceStateV1` params ([#640](https://github.com/taikoxyz/taiko-client/issues/640)) ([9cbe4b8](https://github.com/taikoxyz/taiko-client/commit/9cbe4b8d3c499d97f6e0aadc298075f6764681f7))
* **metrics:** add more transaction sender metrics ([#630](https://github.com/taikoxyz/taiko-client/issues/630)) ([26ed379](https://github.com/taikoxyz/taiko-client/commit/26ed3793b5bf93ef215960c99598fa7e1603a730))
* **metrics:** update default metrics registry ([#617](https://github.com/taikoxyz/taiko-client/issues/617)) ([e1f5393](https://github.com/taikoxyz/taiko-client/commit/e1f5393849f79a3f4618f9fb1bf671513787ec70))
* **pkg:** improve / simplify reorg check logic ([#647](https://github.com/taikoxyz/taiko-client/issues/647)) ([0b08772](https://github.com/taikoxyz/taiko-client/commit/0b0877278177613b9871258847c9fe8cbbd2c1ea))
* **pkg:** improve sender ([#603](https://github.com/taikoxyz/taiko-client/issues/603)) ([af4f072](https://github.com/taikoxyz/taiko-client/commit/af4f072e6b942f85572a97a723ddfb3eff3b6ea0))
* **pkg:** introduce `blob.go` ([#644](https://github.com/taikoxyz/taiko-client/issues/644)) ([995b449](https://github.com/taikoxyz/taiko-client/commit/995b449fbc5d398dc793d647ee58b55df2dffdd7))
* **pkg:** make `chainID` part of `rpc.EthClient` ([#563](https://github.com/taikoxyz/taiko-client/issues/563)) ([f5d1146](https://github.com/taikoxyz/taiko-client/commit/f5d11460aa1bf740a037aa328dc8a2878b94832a))
* **pkg:** move `sender` from `internal` to `pkg` ([#626](https://github.com/taikoxyz/taiko-client/issues/626)) ([05100b3](https://github.com/taikoxyz/taiko-client/commit/05100b3860ad37222946aaec3d8ae10794fd9108))
* **pkg:** remove `defaultMaxTransactionsPerBlock` config ([#611](https://github.com/taikoxyz/taiko-client/issues/611)) ([1b21e4c](https://github.com/taikoxyz/taiko-client/commit/1b21e4c42d6e41e931e2bcc93dc4e19115acceaf))
* **pkg:** remove `IsArchiveNode` check for L1 endpoint ([#652](https://github.com/taikoxyz/taiko-client/issues/652)) ([fed3a27](https://github.com/taikoxyz/taiko-client/commit/fed3a27c17260e81726f946170b3f02e5af5197e))
* **proposer:** add more logs for debugging ([#643](https://github.com/taikoxyz/taiko-client/issues/643)) ([a554017](https://github.com/taikoxyz/taiko-client/commit/a55401758756eefb29929657cda10311bbc4ee17))
* **proposer:** improve proposer flag configs ([#589](https://github.com/taikoxyz/taiko-client/issues/589)) ([8159155](https://github.com/taikoxyz/taiko-client/commit/815915523dcce292c1c22caba4fde82cddb2e740))
* **proposer:** introduce `zlib` for transactions list bytes compression ([#649](https://github.com/taikoxyz/taiko-client/issues/649)) ([dd50068](https://github.com/taikoxyz/taiko-client/commit/dd500684e4af894a89f2ef5e6641f58f1a57e6b8))
* **proposer:** introduce proposer transaction builder ([#612](https://github.com/taikoxyz/taiko-client/issues/612)) ([9bd2aea](https://github.com/taikoxyz/taiko-client/commit/9bd2aea11e25273349130cdc0f9503fe86af9fa6))
* **prover:** add `--prover.minEthBalance` and `--prover.minTaikoTokenBalance` flags ([#641](https://github.com/taikoxyz/taiko-client/issues/641)) ([1a7128b](https://github.com/taikoxyz/taiko-client/commit/1a7128b472115b697dac2fa00db8d901994f5c19))
* **prover:** clean up `PSE_ZKEVM` related code ([#582](https://github.com/taikoxyz/taiko-client/issues/582)) ([ffcc2b2](https://github.com/taikoxyz/taiko-client/commit/ffcc2b2451e2a29a144c33b202ad1b311a07bf42))
* **prover:** cleanup more database related code ([#621](https://github.com/taikoxyz/taiko-client/issues/621)) ([58c2d10](https://github.com/taikoxyz/taiko-client/commit/58c2d10a3c2dcbd16ec343f59242d01f8a3e1ec9))
* **prover:** fix a `RequestProof` issue ([#588](https://github.com/taikoxyz/taiko-client/issues/588)) ([0f15192](https://github.com/taikoxyz/taiko-client/commit/0f15192abe0c3169544bb1e705d583d045c31359))
* **prover:** fix bug ([#655](https://github.com/taikoxyz/taiko-client/issues/655)) ([d110fb4](https://github.com/taikoxyz/taiko-client/commit/d110fb4b80dec2520d3d667f41bd5ea94615217b))
* **prover:** improve prover ([#633](https://github.com/taikoxyz/taiko-client/issues/633)) ([b80ce2c](https://github.com/taikoxyz/taiko-client/commit/b80ce2c4c576b6f00da07500044d464735f3f7f4))
* **prover:** improve prover implementation ([#616](https://github.com/taikoxyz/taiko-client/issues/616)) ([b7af09c](https://github.com/taikoxyz/taiko-client/commit/b7af09cb247214d1b5d1c6d177fa2fb013f803da))
* **prover:** improve prover implementation ([#635](https://github.com/taikoxyz/taiko-client/issues/635)) ([5983828](https://github.com/taikoxyz/taiko-client/commit/59838286c5b0ef4e0f4680126ac6be155059a2b0))
* **prover:** improve prover server tier fees check ([#642](https://github.com/taikoxyz/taiko-client/issues/642)) ([662d99f](https://github.com/taikoxyz/taiko-client/commit/662d99ff33c15568663610e91d41c8f44ff4a12f))
* **prover:** parse contest submission custom errors ([#624](https://github.com/taikoxyz/taiko-client/issues/624)) ([2d00517](https://github.com/taikoxyz/taiko-client/commit/2d005175904dda7cad0836c275b2b6319ae5a114))
* **prover:** remove more database related code ([#623](https://github.com/taikoxyz/taiko-client/issues/623)) ([3963208](https://github.com/taikoxyz/taiko-client/commit/39632084b033bccc3aba716c9a37f7155477097d))
* **prover:** update `SGXProducer` ([#566](https://github.com/taikoxyz/taiko-client/issues/566)) ([93e0660](https://github.com/taikoxyz/taiko-client/commit/93e0660917c37451d95b6d0600041f473d6f391e))
* **prover:** update server APIs ([#618](https://github.com/taikoxyz/taiko-client/issues/618)) ([64ec861](https://github.com/taikoxyz/taiko-client/commit/64ec861e88a0db6754364d113c91ddf24a95c15f))
* **repo:** introduce `txmgr` package ([#658](https://github.com/taikoxyz/taiko-client/issues/658)) ([ba65882](https://github.com/taikoxyz/taiko-client/commit/ba65882b894ffcc02b248f12d62364838476b3da))
* **sender:** add `sender.GetOpts` method ([#613](https://github.com/taikoxyz/taiko-client/issues/613)) ([2644e60](https://github.com/taikoxyz/taiko-client/commit/2644e607b54d7ba3b7d174ed170f5d49750a69a0))
* **sender:** change to use tick and remove handle reorg function ([#571](https://github.com/taikoxyz/taiko-client/issues/571)) ([27f79c0](https://github.com/taikoxyz/taiko-client/commit/27f79c0500540b147bba180cbfd617474d60f165))
* **sender:** fix a `gasLimt` default value bug ([#585](https://github.com/taikoxyz/taiko-client/issues/585)) ([d323c6f](https://github.com/taikoxyz/taiko-client/commit/d323c6ff602caefee837e112c7b86f5b349f95fe))
* **sender:** improve `adjustGasFee` ([#637](https://github.com/taikoxyz/taiko-client/issues/637)) ([090a466](https://github.com/taikoxyz/taiko-client/commit/090a4665d26c7e819c6b81c99a7482d2a3341ac2))
* **sender:** improve default values setting ([#628](https://github.com/taikoxyz/taiko-client/issues/628)) ([d734626](https://github.com/taikoxyz/taiko-client/commit/d734626f58ec4dcec027b2302bab0365bf85beba))
* **sender:** no `MaxGasFee` default value ([#596](https://github.com/taikoxyz/taiko-client/issues/596)) ([540fd77](https://github.com/taikoxyz/taiko-client/commit/540fd7726635def149444c3eda2feae73fbcb321))
* **sender:** upgrade sender txID ([#625](https://github.com/taikoxyz/taiko-client/issues/625)) ([0aaf06b](https://github.com/taikoxyz/taiko-client/commit/0aaf06bb0940e6d2dac45b702d6b042bda64898f))
* **tx_list_validator:** remove unused code in `tx_list_validator` package ([#609](https://github.com/taikoxyz/taiko-client/issues/609)) ([cc4e302](https://github.com/taikoxyz/taiko-client/commit/cc4e3026051c8bfbeed590d5acde921bfb40a0f3))
* **utils:** replace `mathutils` ([#595](https://github.com/taikoxyz/taiko-client/issues/595)) ([514869d](https://github.com/taikoxyz/taiko-client/commit/514869da1dec700db0b42be08156438b643132f0))


### Bug Fixes

* **cmd:** fix some context close issues ([#650](https://github.com/taikoxyz/taiko-client/issues/650)) ([f561847](https://github.com/taikoxyz/taiko-client/commit/f561847ad6aede44aea309084b28d363fdc3aa9e))
* **driver:** fix a blob decoding issue ([#629](https://github.com/taikoxyz/taiko-client/issues/629)) ([0a29936](https://github.com/taikoxyz/taiko-client/commit/0a29936f34478d6e0be810eb2d9cd445948892f2))
* **driver:** fix a reorg check issue in driver ([#634](https://github.com/taikoxyz/taiko-client/issues/634)) ([7abd6d0](https://github.com/taikoxyz/taiko-client/commit/7abd6d0d54267d7f7092f502cdfe3c4554329bec))
* **flag:** add a missing flag configuration for prover ([#567](https://github.com/taikoxyz/taiko-client/issues/567)) ([6d6d9c6](https://github.com/taikoxyz/taiko-client/commit/6d6d9c60e3caf498e1f1f8a9c6d5e8c0020814b9))
* **flags:** fix a small issue in `txmgr` flags ([#661](https://github.com/taikoxyz/taiko-client/issues/661)) ([c1765c8](https://github.com/taikoxyz/taiko-client/commit/c1765c83a945f6b817db528b4516bfc2fca1d700))
* **flags:** fix logger level flags ([#575](https://github.com/taikoxyz/taiko-client/issues/575)) ([d315605](https://github.com/taikoxyz/taiko-client/commit/d315605d7d101f723a5c870571848fba50c8c6ae))
* **pkg:** fix a bug in transaction sender ([#606](https://github.com/taikoxyz/taiko-client/issues/606)) ([40325bc](https://github.com/taikoxyz/taiko-client/commit/40325bc346aace3bb8c42ed8cb54bd00173f4734))
* **pkg:** fix a sender error check issue ([#602](https://github.com/taikoxyz/taiko-client/issues/602)) ([f801f28](https://github.com/taikoxyz/taiko-client/commit/f801f28050159f9c41e706c8d90bf4cdef188816))
* **pkg:** fix a typo ([#597](https://github.com/taikoxyz/taiko-client/issues/597)) ([428a89e](https://github.com/taikoxyz/taiko-client/commit/428a89e0641c4ed91b6800d06d7dfd1f8849feef))
* **propsoer:** use `L1BlockBuilderTip` flag value ([#584](https://github.com/taikoxyz/taiko-client/issues/584)) ([2068697](https://github.com/taikoxyz/taiko-client/commit/20686979fe62f92967afe4fc245a800a6d04acec))
* **transaction_builder:** fix an issue in `BlobTransactionBuilder.Build` ([#662](https://github.com/taikoxyz/taiko-client/issues/662)) ([45ef240](https://github.com/taikoxyz/taiko-client/commit/45ef240fe40026d7648b4c6cdbf9cc83ba4d5ee9))

## [0.19.0](https://github.com/taikoxyz/taiko-client/compare/v0.18.0...v0.19.0) (2024-02-19)


### Features

* **all:** changes based on protocol `TaikoL1.getBlock()` update ([#558](https://github.com/taikoxyz/taiko-client/issues/558)) ([c853370](https://github.com/taikoxyz/taiko-client/commit/c853370c7ec85d1fea058b667097430f13b744fd))
* **all:** sync state root rather than signal service's storage root ([#549](https://github.com/taikoxyz/taiko-client/issues/549)) ([b05c0d6](https://github.com/taikoxyz/taiko-client/commit/b05c0d6d2f1bf94051297df15330ccce669eb63e))
* **bindings:** try parsing more custom errors ([#531](https://github.com/taikoxyz/taiko-client/issues/531)) ([025d985](https://github.com/taikoxyz/taiko-client/commit/025d9852ba5c06983b50836c21e7ad5a8f8c04b2))
* **bindings:** update `AssigmentHook` signing based on protocol updates ([#519](https://github.com/taikoxyz/taiko-client/issues/519)) ([73a6047](https://github.com/taikoxyz/taiko-client/commit/73a604757995460fdc481548e56111766b63b307))
* **bindings:** update Go contract bindings ([#471](https://github.com/taikoxyz/taiko-client/issues/471)) ([23ce311](https://github.com/taikoxyz/taiko-client/commit/23ce3119478eaa025d05890a5b1c8188216beb29))
* **bindings:** update Go contract bindings ([#520](https://github.com/taikoxyz/taiko-client/issues/520)) ([386e848](https://github.com/taikoxyz/taiko-client/commit/386e848f33157ef63ff58919eb7ecf4c4fb4b1c5))
* **bindings:** update Go contract bindings ([#551](https://github.com/taikoxyz/taiko-client/issues/551)) ([4ace57c](https://github.com/taikoxyz/taiko-client/commit/4ace57c1d1f4bcc3473a341eaa5f16918a84aea3))
* **bindings:** update Go contract bindings ([#553](https://github.com/taikoxyz/taiko-client/issues/553)) ([77d270b](https://github.com/taikoxyz/taiko-client/commit/77d270ba8b13d3946fbe94a8a7ccac17a363207a))
* **bindings:** update Go contracts bindings ([#543](https://github.com/taikoxyz/taiko-client/issues/543)) ([ec81ff3](https://github.com/taikoxyz/taiko-client/commit/ec81ff39686e94b4a0bbb99f48fadce18371ce0c))
* **client:** upgrade shell scripts and replace docker image links ([#495](https://github.com/taikoxyz/taiko-client/issues/495)) ([8f0b4c8](https://github.com/taikoxyz/taiko-client/commit/8f0b4c811574259b24a49573eaef77bd6887f12d))
* **config:** simplify config loading ([#507](https://github.com/taikoxyz/taiko-client/issues/507)) ([5f9d843](https://github.com/taikoxyz/taiko-client/commit/5f9d8435ba73267761fe5ee2d186aa34822823e7))
* **docs:** add `README` for debugging tests ([#498](https://github.com/taikoxyz/taiko-client/issues/498)) ([b4a102d](https://github.com/taikoxyz/taiko-client/commit/b4a102d6779548a4ff5ac1a7d7dce6bc487c26ac))
* **docs:** update swag and swagger docs ([#482](https://github.com/taikoxyz/taiko-client/issues/482)) ([1e26b9e](https://github.com/taikoxyz/taiko-client/commit/1e26b9e6a78c2356064e0d041621192f70cfcada))
* **driver:** update `TaikoL2.anchor` transaction gas limit ([#559](https://github.com/taikoxyz/taiko-client/issues/559)) ([fb9cd12](https://github.com/taikoxyz/taiko-client/commit/fb9cd12c6fb595ab37a4913b0c384c7d49087fd0))
* **driver:** updates based on the protocol `ICrossChainSync` changes ([#555](https://github.com/taikoxyz/taiko-client/issues/555)) ([09248b9](https://github.com/taikoxyz/taiko-client/commit/09248b973c05809299b8e0ca1146e0d5a0d2f3e5))
* **internal:** add `internal` dir and format import order ([#506](https://github.com/taikoxyz/taiko-client/issues/506)) ([fdcb4bc](https://github.com/taikoxyz/taiko-client/commit/fdcb4bc8212ffe654a1784bb6f4e2dc6c2119367))
* **metrics:** add some new metrics ([#479](https://github.com/taikoxyz/taiko-client/issues/479)) ([cfeffca](https://github.com/taikoxyz/taiko-client/commit/cfeffca2d447d1e2c0eff059570dd94696c4bbf9))
* **pkg:** fix a log issue in `ensureGenesisMatched` && update a config ([#504](https://github.com/taikoxyz/taiko-client/issues/504)) ([4c01872](https://github.com/taikoxyz/taiko-client/commit/4c018728150857c484ef247ce03045ba462ce80e))
* **pkg:** remove reverse iterator ([#509](https://github.com/taikoxyz/taiko-client/issues/509)) ([9929585](https://github.com/taikoxyz/taiko-client/commit/992958550c975bc2afa67a9164766e3a9f345265))
* **proposer:** add flag for adding tip to assignmenthook ([#540](https://github.com/taikoxyz/taiko-client/issues/540)) ([4619778](https://github.com/taikoxyz/taiko-client/commit/46197780f94e61c54409a043221060aca606e908))
* **proposer:** changes based on protocol `AssignmentHook` updates ([#502](https://github.com/taikoxyz/taiko-client/issues/502)) ([3908adb](https://github.com/taikoxyz/taiko-client/commit/3908adb79e1a5738b822b58cfa873f7d70357edb))
* **proposer:** improve some wording in blob transactions implementation ([#556](https://github.com/taikoxyz/taiko-client/issues/556)) ([192aa38](https://github.com/taikoxyz/taiko-client/commit/192aa385f62013181b0e132779193aa9d8704f32))
* **proposer:** improved shuffle function to preserve original prover endpoints slice ([#475](https://github.com/taikoxyz/taiko-client/issues/475)) ([6b25d9d](https://github.com/taikoxyz/taiko-client/commit/6b25d9d21ac787e7de0239e3eb4ebdc15376ac38))
* **proposer:** optimize proposer logs ([#464](https://github.com/taikoxyz/taiko-client/issues/464)) ([c7e899d](https://github.com/taikoxyz/taiko-client/commit/c7e899d547009b32e3d0762c55707cb4b85dcb8f))
* **proposer:** restore l2.suggestedFeeRecipient flag ([#550](https://github.com/taikoxyz/taiko-client/issues/550)) ([b93cfcf](https://github.com/taikoxyz/taiko-client/commit/b93cfcf8fc60e85d7223bf22540ce42ad13f416b))
* **prover:** add `--prover.enableLivenessBondProof` flag for guardian prover ([#530](https://github.com/taikoxyz/taiko-client/issues/530)) ([9fa5ab6](https://github.com/taikoxyz/taiko-client/commit/9fa5ab6174efce6ee747281a9a37c5afe2856640))
* **prover:** add more comments to prover package ([#491](https://github.com/taikoxyz/taiko-client/issues/491)) ([2156b49](https://github.com/taikoxyz/taiko-client/commit/2156b49202318447ecafdbf4b53a6209b711f1e0))
* **prover:** additional startup info for guardian prover ([#552](https://github.com/taikoxyz/taiko-client/issues/552)) ([6fefa6e](https://github.com/taikoxyz/taiko-client/commit/6fefa6e81f217a88d90afd55fb457be3978ac74d))
* **prover:** always send guardian proofs for guardian provers ([#470](https://github.com/taikoxyz/taiko-client/issues/470)) ([657f0e4](https://github.com/taikoxyz/taiko-client/commit/657f0e42d33447728c6028f7e7d4482343032962))
* **prover:** change block signing to use timestamp as key ([#466](https://github.com/taikoxyz/taiko-client/issues/466)) ([eb5bc7a](https://github.com/taikoxyz/taiko-client/commit/eb5bc7a8b541e17e52f8b32b3f7d2104ad6ce0eb))
* **prover:** check guardian prover contract address ([#497](https://github.com/taikoxyz/taiko-client/issues/497)) ([3794caf](https://github.com/taikoxyz/taiko-client/commit/3794caf8c0b3a6cc0d4b0692b0ca69e57fcabc05))
* **prover:** fix / upgrade integration test ([#496](https://github.com/taikoxyz/taiko-client/issues/496)) ([c63e681](https://github.com/taikoxyz/taiko-client/commit/c63e681910e03cea2e15eeb551f8fd1938736fc8))
* **prover:** fix a SGX proof producer issue ([#477](https://github.com/taikoxyz/taiko-client/issues/477)) ([cd742f7](https://github.com/taikoxyz/taiko-client/commit/cd742f754cd62d3b18033d1e1481a9e9f4ad896d))
* **prover:** fix a tier selection issue ([#534](https://github.com/taikoxyz/taiko-client/issues/534)) ([c73661e](https://github.com/taikoxyz/taiko-client/commit/c73661ebbf880556699020acc0a74a98f10a427b))
* **prover:** guardian prover startup ([#529](https://github.com/taikoxyz/taiko-client/issues/529)) ([5401a80](https://github.com/taikoxyz/taiko-client/commit/5401a802ca2cb47e3904326190bf9afec5b62fe2))
* **prover:** increase wait time before sending to `proofWindowExpiredCh`  ([#505](https://github.com/taikoxyz/taiko-client/issues/505)) ([6c52594](https://github.com/taikoxyz/taiko-client/commit/6c5259448b39513736645d544496562928908e2a))
* **prover:** introduce `SGXAndZkevmRpcdProducer` ([#476](https://github.com/taikoxyz/taiko-client/issues/476)) ([1750a4b](https://github.com/taikoxyz/taiko-client/commit/1750a4bd4e52db80ab281f2b4ba1153fd28e0e51))
* **prover:** move sub event logic into event function. ([#513](https://github.com/taikoxyz/taiko-client/issues/513)) ([d7aad5a](https://github.com/taikoxyz/taiko-client/commit/d7aad5a623e70bfea02eef9af78e2eea4f43b357))
* **prover:** refactor of guardian prover heartbeat signing / sending ([#472](https://github.com/taikoxyz/taiko-client/issues/472)) ([630924e](https://github.com/taikoxyz/taiko-client/commit/630924e4a331007e135dcfe61e9c48cf190d9647))
* **prover:** remove `result` channel in `proof_producer.go` ([#516](https://github.com/taikoxyz/taiko-client/issues/516)) ([46779ca](https://github.com/taikoxyz/taiko-client/commit/46779caabe1f1903dfe917896f69eaf49045cf9b))
* **prover:** remove capacity manager ([#478](https://github.com/taikoxyz/taiko-client/issues/478)) ([8972ee1](https://github.com/taikoxyz/taiko-client/commit/8972ee1d70ae08736f74348e3467880e712e9a30))
* **prover:** set `AssignmentHook` allowance ([#486](https://github.com/taikoxyz/taiko-client/issues/486)) ([a2af478](https://github.com/taikoxyz/taiko-client/commit/a2af4789b7b5975b1365b601eace18fdea4ee978))
* **prover:** set default `--prover.proveUnassignedBlocks` and `--mode.contester` value for guardian provers ([#492](https://github.com/taikoxyz/taiko-client/issues/492)) ([d5b798d](https://github.com/taikoxyz/taiko-client/commit/d5b798dbd8568af2e71285b6a29c0c4a327198e1))
* **prover:** support SGX prover with raiko-host ([#473](https://github.com/taikoxyz/taiko-client/issues/473)) ([a27d353](https://github.com/taikoxyz/taiko-client/commit/a27d35351c6a8f7232cdb098b7888ebc80c200f2))
* **prover:** update unretryable error check ([#532](https://github.com/taikoxyz/taiko-client/issues/532)) ([a5b067f](https://github.com/taikoxyz/taiko-client/commit/a5b067fde9301aa7b735f41a1fae0efa3fa48b54))
* **repo:** implement EIP-4844 in client ([#526](https://github.com/taikoxyz/taiko-client/issues/526)) ([103cad2](https://github.com/taikoxyz/taiko-client/commit/103cad295adf9d29a2e5603a377d223c303eedd4))
* **rpc:** improve reorg checks ([#510](https://github.com/taikoxyz/taiko-client/issues/510)) ([d375ee0](https://github.com/taikoxyz/taiko-client/commit/d375ee04f8a9dbc698d0c0b37492d2f4b4949329))
* **rpc:** simplify RPC clients ([#521](https://github.com/taikoxyz/taiko-client/issues/521)) ([bbe9ed7](https://github.com/taikoxyz/taiko-client/commit/bbe9ed764e00029f54baec9e7c51664ee36c489b))
* **test:** Upgrade test scripts ([#557](https://github.com/taikoxyz/taiko-client/issues/557)) ([940440c](https://github.com/taikoxyz/taiko-client/commit/940440cf918c3c3aebad622522243f3eb8d354b2))
* **test:** use dynamic docker port ([#517](https://github.com/taikoxyz/taiko-client/issues/517)) ([430abd6](https://github.com/taikoxyz/taiko-client/commit/430abd6deed8117b2287183a662276607adb50b9))


### Bug Fixes

* **bindings:** fix `AssignmentHookABI` variable typo ([#468](https://github.com/taikoxyz/taiko-client/issues/468)) ([3b057f3](https://github.com/taikoxyz/taiko-client/commit/3b057f321bf051c150319406a76a3bbf03127572))
* **docs:** fix swagger script ([#484](https://github.com/taikoxyz/taiko-client/issues/484)) ([a624c18](https://github.com/taikoxyz/taiko-client/commit/a624c183465fc0cfaea24f5b3db71eb11607ba3e))
* **protocol:** fix an issue for prover initialization ([#480](https://github.com/taikoxyz/taiko-client/issues/480)) ([c656ddb](https://github.com/taikoxyz/taiko-client/commit/c656ddb6699c5834b99c7a774566bbfb3253a7d6))
* **prover:** change separator ([#469](https://github.com/taikoxyz/taiko-client/issues/469)) ([8e8897f](https://github.com/taikoxyz/taiko-client/commit/8e8897fbe905fc14279988028407f3773e1d0a00))
* **prover:** fix `--prover.allowance` flag ([#490](https://github.com/taikoxyz/taiko-client/issues/490)) ([271fb6f](https://github.com/taikoxyz/taiko-client/commit/271fb6f5737a8b297c6a6aefee1ec7ff2a71b1c5))
* **prover:** fix `guardianProverSender.SendStartup` ([#533](https://github.com/taikoxyz/taiko-client/issues/533)) ([416ad68](https://github.com/taikoxyz/taiko-client/commit/416ad684a1ee128221ae1be2c6ed756e9de2b78a))
* **prover:** fix guardian prover `log` package import ([#485](https://github.com/taikoxyz/taiko-client/issues/485)) ([e294b0b](https://github.com/taikoxyz/taiko-client/commit/e294b0bfb8cd493af736df70d3478882bb016b39))
* **prover:** fix guardian prover database key ([#522](https://github.com/taikoxyz/taiko-client/issues/522)) ([35eee7c](https://github.com/taikoxyz/taiko-client/commit/35eee7c9fd5dc77d7eb61585f36d10fbf7179aaa))
* **prover:** only store signed block after successfully sending http request ([#489](https://github.com/taikoxyz/taiko-client/issues/489)) ([956e202](https://github.com/taikoxyz/taiko-client/commit/956e20290681337fa03638437b390c2423802d58))
* **rpc:** fix a bug / update logic ([#501](https://github.com/taikoxyz/taiko-client/issues/501)) ([0bb53b4](https://github.com/taikoxyz/taiko-client/commit/0bb53b406ed0fcebb9eba81700c3408ac54fc737))
* **rpc:** fix an issue in `checkSyncedL1SnippetFromAnchor` && add more logs ([#511](https://github.com/taikoxyz/taiko-client/issues/511)) ([b2f2f0b](https://github.com/taikoxyz/taiko-client/commit/b2f2f0b71c3b698934b4041adac8c932c9983e34))
* **test:** fix workflow errors ([#525](https://github.com/taikoxyz/taiko-client/issues/525)) ([60f128b](https://github.com/taikoxyz/taiko-client/commit/60f128b61fa48950b4b0afd6797626d4f03e070f))

## [0.18.0](https://github.com/taikoxyz/taiko-client/compare/v0.17.0...v0.18.0) (2023-12-03)


### Features

* **bindings:** update Go contract bindings ([#443](https://github.com/taikoxyz/taiko-client/issues/443)) ([b155b5a](https://github.com/taikoxyz/taiko-client/commit/b155b5a173eabb9ca5a13ae7f10c47d5f506b8ae))
* **bindings:** update Go contract bindings based on latest A6 protocol changes ([#435](https://github.com/taikoxyz/taiko-client/issues/435)) ([7e39dc2](https://github.com/taikoxyz/taiko-client/commit/7e39dc23eac6558de4de114725b5cb4020312d68))
* **bindings:** update Go contract bindings based on the latest contestable zkRollup protocol ([#429](https://github.com/taikoxyz/taiko-client/issues/429)) ([d33e19b](https://github.com/taikoxyz/taiko-client/commit/d33e19be64929f820a8841e49fad8d0d541bd368))
* **bindings:** update Go contract bindings for the latest protocol ([#441](https://github.com/taikoxyz/taiko-client/issues/441)) ([02c981d](https://github.com/taikoxyz/taiko-client/commit/02c981d4d700c3e1ca8032307945dee5723be3a2))
* **bindings:** updates related to TaikoToken && guardian prover changes ([#436](https://github.com/taikoxyz/taiko-client/issues/436)) ([9066722](https://github.com/taikoxyz/taiko-client/commit/9066722ae4dc7637c0db3acb2699ce11d63c5962))
* **docs:** host swagger doc by github page ([#427](https://github.com/taikoxyz/taiko-client/issues/427)) ([ab4e613](https://github.com/taikoxyz/taiko-client/commit/ab4e613de050d7e77b7942f02f9d596bf718fc75))
* **driver:** improve `ResetL1Current` method based on the latest protocol changes ([#445](https://github.com/taikoxyz/taiko-client/issues/445)) ([ddf6980](https://github.com/taikoxyz/taiko-client/commit/ddf6980a97d7c14239458cdde535066aea14912d))
* **driver:** update `anchorGasLimit` based on the latest `TaikoL2` contract ([#437](https://github.com/taikoxyz/taiko-client/issues/437)) ([171600a](https://github.com/taikoxyz/taiko-client/commit/171600ad7c107056081a4bac9e4a6d9eebd9c393))
* **pkg:** update `defaultMaxTransactionsPerBlock` to `150` ([#438](https://github.com/taikoxyz/taiko-client/issues/438)) ([93b9ecf](https://github.com/taikoxyz/taiko-client/commit/93b9ecf635869964eb12b3dae3e304184a83becb))
* **proposer:** remove `--l2.suggestedFeeRecipient` flag ([#442](https://github.com/taikoxyz/taiko-client/issues/442)) ([405b9ed](https://github.com/taikoxyz/taiko-client/commit/405b9ed03c7a2749f56fdb16849281a284bcc562))
* **prover:** add `--prover.blockSlippage` flag ([#449](https://github.com/taikoxyz/taiko-client/issues/449)) ([0ee8259](https://github.com/taikoxyz/taiko-client/commit/0ee82593c2fc2704a2c8f0130fd1887bc67f764b))
* **prover:** guardian prover block signature && bindings updates for based contestable zkRollup ([#450](https://github.com/taikoxyz/taiko-client/issues/450)) ([904d3e7](https://github.com/taikoxyz/taiko-client/commit/904d3e76dd67c71ea225144d12526e0291e2b39f))
* **prover:** improve `/status` API ([#444](https://github.com/taikoxyz/taiko-client/issues/444)) ([e688c25](https://github.com/taikoxyz/taiko-client/commit/e688c256109e20ed5ea29fc03e97433acf7002bf))
* **prover:** increase the assignment expiration waiting time ([#431](https://github.com/taikoxyz/taiko-client/issues/431)) ([579dcc5](https://github.com/taikoxyz/taiko-client/commit/579dcc50686f73f42961f1624f067ede52701b4e))
* **prover:** more accurate `provingWindowExpiresAt` calculation && update bindings ([#433](https://github.com/taikoxyz/taiko-client/issues/433)) ([72c528f](https://github.com/taikoxyz/taiko-client/commit/72c528f8df4994f13060c92cc1c1162a228dfd49))
* **test:** fix `suite.go` ([#453](https://github.com/taikoxyz/taiko-client/issues/453)) ([38fbb66](https://github.com/taikoxyz/taiko-client/commit/38fbb662c9ec46e4ea55689970faa70b56eeed4f))


### Bug Fixes

* **docs:** fix swagger generation ([#455](https://github.com/taikoxyz/taiko-client/issues/455)) ([9533761](https://github.com/taikoxyz/taiko-client/commit/9533761cfea43a5bf0d9093694ede881e0c95996))
* **prover:** fix guardian prover APIs ([#459](https://github.com/taikoxyz/taiko-client/issues/459)) ([08c77f2](https://github.com/taikoxyz/taiko-client/commit/08c77f244dfc4630c767b826b3156fad7b09dca4))
* **prover:** fix Guardian prover waiting ([#462](https://github.com/taikoxyz/taiko-client/issues/462)) ([8266845](https://github.com/taikoxyz/taiko-client/commit/82668458bb9050bca4d676b73299d7595c772851))
* **prover:** guardian prover sign wait ([#461](https://github.com/taikoxyz/taiko-client/issues/461)) ([51fd8f9](https://github.com/taikoxyz/taiko-client/commit/51fd8f9e31d9e44eb0e9b82a500ad83ab52b1e92))
* **prover:** reorder guardian prover signature && add allowance flag ([#457](https://github.com/taikoxyz/taiko-client/issues/457)) ([4bc2a63](https://github.com/taikoxyz/taiko-client/commit/4bc2a63c57c3897b2634abc40af72e55522d4af6))
* **server:** fix a typo in `license.url` ([#460](https://github.com/taikoxyz/taiko-client/issues/460)) ([d632109](https://github.com/taikoxyz/taiko-client/commit/d63210935f21173e8b03a4a09cb72eabf70c7ef0))
* **tests:** fix workflow errors ([#440](https://github.com/taikoxyz/taiko-client/issues/440)) ([8b3cef2](https://github.com/taikoxyz/taiko-client/commit/8b3cef2f7a90dfb9b08fdebe7bd8edd63776db00))

## [0.17.0](https://github.com/taikoxyz/taiko-client/compare/v0.16.0...v0.17.0) (2023-10-16)


### Features

* **all:** changes based on contestable zkRollup protocol design ([#414](https://github.com/taikoxyz/taiko-client/issues/414)) ([25a0c3b](https://github.com/taikoxyz/taiko-client/commit/25a0c3bc6507c22f28817c2a1e966ea7199699d8))


### Bug Fixes

* **prover:** fix L1 height used in `onBlockProven` handler ([#421](https://github.com/taikoxyz/taiko-client/issues/421)) ([4a1012a](https://github.com/taikoxyz/taiko-client/commit/4a1012ac702acc4d1d1bae5c295cdad02c99caef))

## [0.16.0](https://github.com/taikoxyz/taiko-client/compare/v0.15.0...v0.16.0) (2023-09-30)


### Features

* **all:** some client optimizations ([#376](https://github.com/taikoxyz/taiko-client/issues/376)) ([91bba90](https://github.com/taikoxyz/taiko-client/commit/91bba902febbf6ce8d4fd37dfb2b0fe7c181191d))
* **bindings:** update contract bindings ([#394](https://github.com/taikoxyz/taiko-client/issues/394)) ([5b9346b](https://github.com/taikoxyz/taiko-client/commit/5b9346b9587c155372cede757f048e2c9faea4a2))
* **flag:** fix some typo ([#391](https://github.com/taikoxyz/taiko-client/issues/391)) ([5f7f1dd](https://github.com/taikoxyz/taiko-client/commit/5f7f1dd8248a204d8451e0c5fd37ede870fa7f07))
* **proposer:** shuffle prover endpoints before assigning proof tasks ([#390](https://github.com/taikoxyz/taiko-client/issues/390)) ([96488d0](https://github.com/taikoxyz/taiko-client/commit/96488d0f7045174b227a20bc51b241d25f683098))
* **proposer:** update oracle proof assignment ([#393](https://github.com/taikoxyz/taiko-client/issues/393)) ([29c2d4b](https://github.com/taikoxyz/taiko-client/commit/29c2d4ba23e2d2d9d1d8389b68679b851a3fd33e))
* **proposer:** update prover endpoint scheme check ([#400](https://github.com/taikoxyz/taiko-client/issues/400)) ([ce8bd1d](https://github.com/taikoxyz/taiko-client/commit/ce8bd1d78002209227d283a89c08775fa06bc431))
* **prover_selector:** check prover's token balance ([#406](https://github.com/taikoxyz/taiko-client/issues/406)) ([834c0ea](https://github.com/taikoxyz/taiko-client/commit/834c0ea62353a5a92245ac5412b7d8714d92c4da))
* **prover:** add more capacity related logs ([#408](https://github.com/taikoxyz/taiko-client/issues/408)) ([22014b2](https://github.com/taikoxyz/taiko-client/commit/22014b2f2b9bf4f35590273c64b888920ce82ffc))
* **prover:** always use the oracle prover private key when an oracle prover starting a server ([#395](https://github.com/taikoxyz/taiko-client/issues/395)) ([cc28d63](https://github.com/taikoxyz/taiko-client/commit/cc28d631cb3c6ba0365034f0a9cbe3d6ce44492a))
* **prover:** check `transition.blockHash` before proof generation ([#415](https://github.com/taikoxyz/taiko-client/issues/415)) ([dd77f7a](https://github.com/taikoxyz/taiko-client/commit/dd77f7a07b56abb2724a7a46113b9f39e922a13b))
* **prover:** increase `gasTipCap` when resending `TaikoL1.proveBlock` transactions ([#411](https://github.com/taikoxyz/taiko-client/issues/411)) ([f192e0a](https://github.com/taikoxyz/taiko-client/commit/f192e0a6b8237fa5cbcdc80d91f4333e76a1afc3))
* **prover:** release capacity when the corresponding local proof generation is canceled ([#402](https://github.com/taikoxyz/taiko-client/issues/402)) ([1eab54d](https://github.com/taikoxyz/taiko-client/commit/1eab54deb024baa1e5c46a725153172ed289b9f8))
* **prover:** tie capacity to a specific block id ([#413](https://github.com/taikoxyz/taiko-client/issues/413)) ([bdca930](https://github.com/taikoxyz/taiko-client/commit/bdca930f47f7efd2e3661d57a3507eae09db339d))
* **prover:** update APIs && integrate swagger docs ([#386](https://github.com/taikoxyz/taiko-client/issues/386)) ([ebdb3da](https://github.com/taikoxyz/taiko-client/commit/ebdb3daba25921b572578fca2f5c981e4e014e54))
* **prover:** use `httptest.Server` to simplify the prover server tests ([#389](https://github.com/taikoxyz/taiko-client/issues/389)) ([84eedae](https://github.com/taikoxyz/taiko-client/commit/84eedaedfe01e736d7c6a8523e68c4fad878e8c4))


### Bug Fixes

* **ci:** fix workflow errors ([#410](https://github.com/taikoxyz/taiko-client/issues/410)) ([5a3b655](https://github.com/taikoxyz/taiko-client/commit/5a3b6551458ebe6212c2ad7dee0a9291be42fd86))
* **proposer:** fix proposing fee initialization ([#396](https://github.com/taikoxyz/taiko-client/issues/396)) ([2f2007d](https://github.com/taikoxyz/taiko-client/commit/2f2007d5810b8994172a59cb88052b9b8b8acb87))
* **prover:** capacity needs to be taken before generating proof ([#412](https://github.com/taikoxyz/taiko-client/issues/412)) ([7d9c244](https://github.com/taikoxyz/taiko-client/commit/7d9c2446a45f3d338c222ea5bd269ea49fcb135b))
* **prover:** check latest verified ID on proof submission ([#387](https://github.com/taikoxyz/taiko-client/issues/387)) ([8157550](https://github.com/taikoxyz/taiko-client/commit/81575502e88f06f34a2f36baa6bad66d0fa12884))
* **prover:** fix a capacity release issue ([#405](https://github.com/taikoxyz/taiko-client/issues/405)) ([4ab061f](https://github.com/taikoxyz/taiko-client/commit/4ab061f9f2c6fecfdcc164ade398e0acbacbf8cd))
* **prover:** prover rpc didnt have taiko token address ([#407](https://github.com/taikoxyz/taiko-client/issues/407)) ([4e0e390](https://github.com/taikoxyz/taiko-client/commit/4e0e390abebbd8ec3b56f0fe729a7573c26e1fdd))
* **test:** fix flags related tests ([#409](https://github.com/taikoxyz/taiko-client/issues/409)) ([4f0a602](https://github.com/taikoxyz/taiko-client/commit/4f0a6020b22473c83743450197f68393410adf2d))

## [0.15.0](https://github.com/taikoxyz/taiko-client/compare/v0.14.0...v0.15.0) (2023-09-04)


### Features

* **all:** update bindings based on latest tokenomics changes ([#367](https://github.com/taikoxyz/taiko-client/issues/367)) ([28ea4db](https://github.com/taikoxyz/taiko-client/commit/28ea4dbb658a7e708ffb7bc54a194a29d7013f18))
* **bindings:** rename fork choice to state transition ([#372](https://github.com/taikoxyz/taiko-client/issues/372)) ([e09fd97](https://github.com/taikoxyz/taiko-client/commit/e09fd977b0fe2fa2efa8642b419d3dda21d8f3b0))
* **bindings:** update bindings && remove unused files ([#360](https://github.com/taikoxyz/taiko-client/issues/360)) ([24b9309](https://github.com/taikoxyz/taiko-client/commit/24b9309532089f74ba0c3b04db721f6c6d6cd0a0))
* **bindings:** update contract bindings ([#377](https://github.com/taikoxyz/taiko-client/issues/377)) ([becdd73](https://github.com/taikoxyz/taiko-client/commit/becdd735e83a5b444ed04671e4957ce44ab222a1))
* **pkg:** add `isSyncing` method ([#379](https://github.com/taikoxyz/taiko-client/issues/379)) ([9c7a19a](https://github.com/taikoxyz/taiko-client/commit/9c7a19a1f32ea6a8ba7082bfff2deb04f8826a05))
* **proposer:** update proposing retry policy ([#366](https://github.com/taikoxyz/taiko-client/issues/366)) ([e0adf17](https://github.com/taikoxyz/taiko-client/commit/e0adf175b87ec1ba4c5b4068794e6842b1ca129f))


### Bug Fixes

* **all:** fix missing logs should be print in stderr ([#370](https://github.com/taikoxyz/taiko-client/issues/370)) ([af6531b](https://github.com/taikoxyz/taiko-client/commit/af6531bb1fe2cc43a32772d264b56b8e5f243786))
* **prover:** add to wait group in prover ([#373](https://github.com/taikoxyz/taiko-client/issues/373)) ([edf95a7](https://github.com/taikoxyz/taiko-client/commit/edf95a72a91005f6be5402b17b145928e55d9256))
* **prover:** fix `maxRetry` configuration when submitting proofs ([#364](https://github.com/taikoxyz/taiko-client/issues/364)) ([b6cd4db](https://github.com/taikoxyz/taiko-client/commit/b6cd4db1cffd15f95f383b2c5058d1c95d30d473))
* **prover:** fix some typo ([#374](https://github.com/taikoxyz/taiko-client/issues/374)) ([355e68b](https://github.com/taikoxyz/taiko-client/commit/355e68bc53bf01684198076fdd0c8a3ddb4bbed3))

## [0.14.0](https://github.com/taikoxyz/taiko-client/compare/v0.13.0...v0.14.0) (2023-08-09)


### Features

* **bindings:** update `TaikoL1BlockMetadataInput` ([#359](https://github.com/taikoxyz/taiko-client/issues/359)) ([1beae59](https://github.com/taikoxyz/taiko-client/commit/1beae59cfbe1345a5bb69714b25ba4397173be45))
* **bindings:** update go contract bindings ([#346](https://github.com/taikoxyz/taiko-client/issues/346)) ([c6454af](https://github.com/taikoxyz/taiko-client/commit/c6454afe28b3a86c8d33c8434cfd345318116076))
* **bindings:** update go contract bindings ([#352](https://github.com/taikoxyz/taiko-client/issues/352)) ([b9da8f6](https://github.com/taikoxyz/taiko-client/commit/b9da8f68e733a51255c1307d016d1ff9e241f3c9))
* **driver:** update `l1Current` check in `ProcessL1Blocks` ([#340](https://github.com/taikoxyz/taiko-client/issues/340)) ([d67f287](https://github.com/taikoxyz/taiko-client/commit/d67f287bd5cce08aa5b7ba9fd33fc00e91ad6190))
* **pkg:** add default timeout for `GetStorageRoot` ([#347](https://github.com/taikoxyz/taiko-client/issues/347)) ([9a4dee0](https://github.com/taikoxyz/taiko-client/commit/9a4dee04f90e521832efef5febeebb1231e22a19))
* **pkg:** improve archive node check ([#334](https://github.com/taikoxyz/taiko-client/issues/334)) ([c6cd1b0](https://github.com/taikoxyz/taiko-client/commit/c6cd1b0492499b3c686ac282d65743793bd162da))
* **pkg:** introduce `EthClient` with a timeout attached ([#337](https://github.com/taikoxyz/taiko-client/issues/337)) ([1608aba](https://github.com/taikoxyz/taiko-client/commit/1608abae268bbbe6671ec9eb89fed2846065852c))
* **pkg:** optimize `CheckL1ReorgFromL1Cursor` ([#329](https://github.com/taikoxyz/taiko-client/issues/329)) ([ed63c1f](https://github.com/taikoxyz/taiko-client/commit/ed63c1f8e4ba6a9fd40b1d1d5f3bba217d470f4b))
* **pkg:** Wait receipt timeout ([#343](https://github.com/taikoxyz/taiko-client/issues/343)) ([cf261d3](https://github.com/taikoxyz/taiko-client/commit/cf261d377f61ea0b0ff049be7e8c8eb75264f386))
* **proposer:** add `--proposeBlockTxGasTipCap` flag ([#349](https://github.com/taikoxyz/taiko-client/issues/349)) ([e40115b](https://github.com/taikoxyz/taiko-client/commit/e40115b97002661def8eed8dfb768ad28c19f0ea))
* **proposer:** update pool content query ([#341](https://github.com/taikoxyz/taiko-client/issues/341)) ([221a3b9](https://github.com/taikoxyz/taiko-client/commit/221a3b92b77f4b3d3e5499eb27fa289ae44b0151))
* **proposer:** use `TaikoConfig.blockMaxGasLimit` as proposed block gasLimit && remove some unused flags ([#344](https://github.com/taikoxyz/taiko-client/issues/344)) ([f0a3da7](https://github.com/taikoxyz/taiko-client/commit/f0a3da7d6bf8af222ae6e780218ccca2c7861137))
* **prover:** add `--proofSubmissionMaxRetry` flag ([#333](https://github.com/taikoxyz/taiko-client/issues/333)) ([8d92b7a](https://github.com/taikoxyz/taiko-client/commit/8d92b7aa96d22ca20de57fd02e52d7f3f6ff9a5f))
* **prover:** changes based on `proofVerifier` protocol updates ([#338](https://github.com/taikoxyz/taiko-client/issues/338)) ([6dcb34a](https://github.com/taikoxyz/taiko-client/commit/6dcb34aab3619731852a19a09b54aadce34de999))
* **prover:** prove block tx gas limit ([#357](https://github.com/taikoxyz/taiko-client/issues/357)) ([8ed4da2](https://github.com/taikoxyz/taiko-client/commit/8ed4da2f0bd0bf5f215767b1bd44106dd878431f))
* **rpc:** check if L1 rpc is an archive node ([#332](https://github.com/taikoxyz/taiko-client/issues/332)) ([b1aa1d3](https://github.com/taikoxyz/taiko-client/commit/b1aa1d388d407f2f5cb14275c006b1a22213b8ff))


### Bug Fixes

* **pkg:** fix returned context error from `WaitL1Origin` ([#331](https://github.com/taikoxyz/taiko-client/issues/331)) ([0ebf121](https://github.com/taikoxyz/taiko-client/commit/0ebf121dcae5e75d359bc7818aa98fa6f7b1bc20))
* **pkg:** set more RPC context timeout ([#356](https://github.com/taikoxyz/taiko-client/issues/356)) ([ffe2f90](https://github.com/taikoxyz/taiko-client/commit/ffe2f906808f99a48f6a848351c9a34ea63f02b7))
* **prover:** default prove unassigned blocks to false ([#354](https://github.com/taikoxyz/taiko-client/issues/354)) ([ed34ef6](https://github.com/taikoxyz/taiko-client/commit/ed34ef670a3deef5f4db88429cd13c5bdb108289))
* **prover:** fix `onBlockProposed` reorg detection ([#348](https://github.com/taikoxyz/taiko-client/issues/348)) ([4877e01](https://github.com/taikoxyz/taiko-client/commit/4877e01f7c35f0cbce329e14948dd78b5de0c911))

## [0.13.0](https://github.com/taikoxyz/taiko-client/compare/v0.12.0...v0.13.0) (2023-07-23)


### Features

* **cmd:** update `proveUnassignedBlocks` flag name ([#315](https://github.com/taikoxyz/taiko-client/issues/315)) ([df640d9](https://github.com/taikoxyz/taiko-client/commit/df640d9d49ceb84268801021ba70fea8e278f39e))
* **driver:** improve `ProcessL1Blocks` for reorg handling ([#325](https://github.com/taikoxyz/taiko-client/issues/325)) ([7272e15](https://github.com/taikoxyz/taiko-client/commit/7272e15650e9ab6aded598e9edcae2659b9d045d))
* **proposer:** add `--txpool.localsOnly` flag ([#326](https://github.com/taikoxyz/taiko-client/issues/326)) ([b292754](https://github.com/taikoxyz/taiko-client/commit/b2927541706e7827dad652140361f4ccf91d1afb))
* **proposer:** handle transaction replacement underpriced error ([#322](https://github.com/taikoxyz/taiko-client/issues/322)) ([2273d10](https://github.com/taikoxyz/taiko-client/commit/2273d105b5dfa6479dc2aa74c16fd0365d06e31a))
* **prover:** add `--oracleProofSubmissionDelay` flag ([#320](https://github.com/taikoxyz/taiko-client/issues/320)) ([85adc04](https://github.com/taikoxyz/taiko-client/commit/85adc04dceabd6218afee72f748e17d69182d81d))
* **prover:** add some prover metrics for Alpha-4 protocol ([#319](https://github.com/taikoxyz/taiko-client/issues/319)) ([d8ff623](https://github.com/taikoxyz/taiko-client/commit/d8ff623a441226c736bd4c52d95df69dd2ce4c86))
* **prover:** flag for proving unassigned proofs or not ([#314](https://github.com/taikoxyz/taiko-client/issues/314)) ([13e6d1d](https://github.com/taikoxyz/taiko-client/commit/13e6d1d87d661c1bdcd9e1537b10b42b33888298))
* **prover:** generate an oracle proof if the incoming proof is incorrect ([#311](https://github.com/taikoxyz/taiko-client/issues/311)) ([003a86b](https://github.com/taikoxyz/taiko-client/commit/003a86bfd3e8f00a4b3c35d048ede6177739a45e))
* **prover:** optimize `skipProofWindowExpiredCheck` check && update `NeedNewProof` check ([#313](https://github.com/taikoxyz/taiko-client/issues/313)) ([b0b4c25](https://github.com/taikoxyz/taiko-client/commit/b0b4c252291ff8d163d2eb71114aa7d63c821c7e))
* **prover:** update `l1Current` cursor to record L1 hash ([#327](https://github.com/taikoxyz/taiko-client/issues/327)) ([4a5adb5](https://github.com/taikoxyz/taiko-client/commit/4a5adb523374008a37831da5febff9a3501a4e81))
* **prover:** update open proving blocks check ([#316](https://github.com/taikoxyz/taiko-client/issues/316)) ([b34930c](https://github.com/taikoxyz/taiko-client/commit/b34930cd4982672bbea962f3706cb83d7e964963))


### Bug Fixes

* **ci:** fix workflow `pnpm install` error ([#321](https://github.com/taikoxyz/taiko-client/issues/321)) ([9eefc8d](https://github.com/taikoxyz/taiko-client/commit/9eefc8d401a35eee1c9b31f5e3c93e18e2754013))
* **prover:** add end height for block filtering if `startHeight` is not nil, and don't block when notifying ([#317](https://github.com/taikoxyz/taiko-client/issues/317)) ([aaec1bb](https://github.com/taikoxyz/taiko-client/commit/aaec1bbdd54df6d60ce39428febbb2747838c31a))
* **prover:** move concurrency guard ([#318](https://github.com/taikoxyz/taiko-client/issues/318)) ([af29c95](https://github.com/taikoxyz/taiko-client/commit/af29c9503def11c373c16555c020307348c5cff6))

## [0.12.0](https://github.com/taikoxyz/taiko-client/compare/v0.11.0...v0.12.0) (2023-07-10)


### Features

* **all:** update bindings && integrate new circuits for L3 ([#290](https://github.com/taikoxyz/taiko-client/issues/290)) ([59469fa](https://github.com/taikoxyz/taiko-client/commit/59469fac2fefe1046d805dc1f19911150e453d87))
* **bindings:** update contract bindings ([#310](https://github.com/taikoxyz/taiko-client/issues/310)) ([021f113](https://github.com/taikoxyz/taiko-client/commit/021f113c2add574843f889b525d55789752b1bd6))
* **prover:** add some prover logs ([#305](https://github.com/taikoxyz/taiko-client/issues/305)) ([e36c76c](https://github.com/taikoxyz/taiko-client/commit/e36c76c7ea6d912477dc8ce61e4639faef00eb5c))
* **prover:** implement staking based tokenomics in client ([#292](https://github.com/taikoxyz/taiko-client/issues/292)) ([7324547](https://github.com/taikoxyz/taiko-client/commit/7324547a80182e93193479089bd334fcce5df7ce))


### Bug Fixes

* **driver:** fix a P2P sync issue ([#298](https://github.com/taikoxyz/taiko-client/issues/298)) ([2ffa052](https://github.com/taikoxyz/taiko-client/commit/2ffa0528110db70f34dd3ef6f48008487caa78a2))
* **prover:** fix a fork choice checking issue ([#309](https://github.com/taikoxyz/taiko-client/issues/309)) ([a393ed8](https://github.com/taikoxyz/taiko-client/commit/a393ed85fed4046039b66bda51bb645ed84d8461))
* **prover:** fix an unlock issue ([#306](https://github.com/taikoxyz/taiko-client/issues/306)) ([392eb78](https://github.com/taikoxyz/taiko-client/commit/392eb78f3721fedea66bd2f361010e2495e385c6))

## [0.11.0](https://github.com/taikoxyz/taiko-client/compare/v0.10.0...v0.11.0) (2023-06-26)


### Features

* **all:** disable no beacon client seen warning  ([#279](https://github.com/taikoxyz/taiko-client/issues/279)) ([cdabcac](https://github.com/taikoxyz/taiko-client/commit/cdabcacb36303667560300775573a4db55fbd5d4))
* **driver:** check the mismatch of last verified block ([#296](https://github.com/taikoxyz/taiko-client/issues/296)) ([79fda87](https://github.com/taikoxyz/taiko-client/commit/79fda8792b29d506b5fa653ed78304d34e892003))
* **driver:** improve error messages ([#289](https://github.com/taikoxyz/taiko-client/issues/289)) ([90e365a](https://github.com/taikoxyz/taiko-client/commit/90e365a79759e0ea701619594b0bf71db4dd3b44))
* **driver:** improve sync progress information ([#288](https://github.com/taikoxyz/taiko-client/issues/288)) ([45d73b9](https://github.com/taikoxyz/taiko-client/commit/45d73b9da34232cf6a3c8636e97aef5854bb86bb))
* **flags:** add retry related flags ([#281](https://github.com/taikoxyz/taiko-client/issues/281)) ([2df4105](https://github.com/taikoxyz/taiko-client/commit/2df4105ab344fb118435b7ef53bcf13ac10f5dc7))
* **metrics:** add `ProverNormalProofRewardGauge` metrics ([#275](https://github.com/taikoxyz/taiko-client/issues/275)) ([cd4e40d](https://github.com/taikoxyz/taiko-client/commit/cd4e40dd477895746843021732a1beba14fa248a))
* **proposer:** add `waitReceiptTimeout` when proposing ([#282](https://github.com/taikoxyz/taiko-client/issues/282)) ([ebf3162](https://github.com/taikoxyz/taiko-client/commit/ebf31623dc491887a25a76da0078559d0b86865c))
* **prover:** improve retry policy for prover ([#280](https://github.com/taikoxyz/taiko-client/issues/280)) ([344bac1](https://github.com/taikoxyz/taiko-client/commit/344bac1435812770c5a1e39efad1545b98d4b106))


### Bug Fixes

* **driver:** fix an issue in `checkLastVerifiedBlockMismatch` ([#297](https://github.com/taikoxyz/taiko-client/issues/297)) ([a68730c](https://github.com/taikoxyz/taiko-client/commit/a68730c0d9cc1b15cdd314ad7939f8971104b362))
* **driver:** fix geth lag to verified block when syncing ([#294](https://github.com/taikoxyz/taiko-client/issues/294)) ([c57f6e8](https://github.com/taikoxyz/taiko-client/commit/c57f6e8ac84ad55c0d51bfae278c88f7694c2265))
* **pkg:** minor fixes for `WaitReceipt` ([#284](https://github.com/taikoxyz/taiko-client/issues/284)) ([feaa2b6](https://github.com/taikoxyz/taiko-client/commit/feaa2b6487e1578c4082ba0b4be087a627512c4b))
* **prover:** ensure L2 reorg finished before generating proofs && add `verificationCheckTicker` ([#277](https://github.com/taikoxyz/taiko-client/issues/277)) ([6fa24ea](https://github.com/taikoxyz/taiko-client/commit/6fa24ea2b4674865dc381098e57a2171c9fce95b))

## [0.10.0](https://github.com/taikoxyz/taiko-client/compare/v0.9.0...v0.10.0) (2023-06-08)


### Features

* **all:** improve proposer && prover logs ([#264](https://github.com/taikoxyz/taiko-client/issues/264)) ([6d0a724](https://github.com/taikoxyz/taiko-client/commit/6d0a7248d78fcd0a73e53a89a21adbeff7f3b61b))
* **driver:** add proof reward metric ([#273](https://github.com/taikoxyz/taiko-client/issues/273)) ([1e00560](https://github.com/taikoxyz/taiko-client/commit/1e00560a1564d61448687ad933fe39a301020bf9))
* **driver:** optimize error handling for `CalldataSyncer` ([#262](https://github.com/taikoxyz/taiko-client/issues/262)) ([580e354](https://github.com/taikoxyz/taiko-client/commit/580e35487b32566761721422bf8d0ca9e5071ed5))
* **pkg:** optimize `WaitL1Origin` ([#267](https://github.com/taikoxyz/taiko-client/issues/267)) ([2d1fda9](https://github.com/taikoxyz/taiko-client/commit/2d1fda90ec54fb25eee789968b9d2177017ace6f))
* **pkg:** update logs when dialing ethclients ([#263](https://github.com/taikoxyz/taiko-client/issues/263)) ([99c980b](https://github.com/taikoxyz/taiko-client/commit/99c980becd0ea2872e6f91b8f422fe66ca8ebfb2))
* **proposer:** add `--maxProposedTxListsPerEpoch` flag ([#258](https://github.com/taikoxyz/taiko-client/issues/258)) ([2cfcf81](https://github.com/taikoxyz/taiko-client/commit/2cfcf814200c2d41d539a427c94fe2a7fefcaf21))
* **prover:** check if a system proof has already been submitted by another system prover ([#274](https://github.com/taikoxyz/taiko-client/issues/274)) ([1fcb244](https://github.com/taikoxyz/taiko-client/commit/1fcb244b29467fcdb7972a724a1ace8b94a67eb8))
* **prover:** improve `onBlockProposed` listener ([#266](https://github.com/taikoxyz/taiko-client/issues/266)) ([5cbdcac](https://github.com/taikoxyz/taiko-client/commit/5cbdcacaa7f902875bb870ea909c7b5ad92220dd))
* **prover:** improve `ZkevmRpcdProducer` logs ([#265](https://github.com/taikoxyz/taiko-client/issues/265)) ([d3fdd94](https://github.com/taikoxyz/taiko-client/commit/d3fdd94f95593567350a86bead5750b12cfd31be))
* **prover:** update proof submission logs ([#261](https://github.com/taikoxyz/taiko-client/issues/261)) ([ea87f7f](https://github.com/taikoxyz/taiko-client/commit/ea87f7f8252073814007d9d54d71cc00171237d7))


### Bug Fixes

* **driver:** fix an issue for P2P sync timeout ([#268](https://github.com/taikoxyz/taiko-client/issues/268)) ([3aee10c](https://github.com/taikoxyz/taiko-client/commit/3aee10c0ba9170eb652e059c51ce029b2af8a3a4))
* **prover:** fix a `targetDelay` calculation issue ([#272](https://github.com/taikoxyz/taiko-client/issues/272)) ([ffcfb53](https://github.com/taikoxyz/taiko-client/commit/ffcfb53e1be7ffe04fdb67ef9a176cc37b7369da))

## [0.9.0](https://github.com/taikoxyz/taiko-client/compare/v0.8.0...v0.9.0) (2023-06-04)


### Features

* **all:** check L1 reorg before each operation ([#252](https://github.com/taikoxyz/taiko-client/issues/252)) ([e76b03f](https://github.com/taikoxyz/taiko-client/commit/e76b03f4af7ab1d300d206c246f736b0c5cb2241))
* **all:** rename `treasure` to `treasury` ([#233](https://github.com/taikoxyz/taiko-client/issues/233)) ([252959f](https://github.com/taikoxyz/taiko-client/commit/252959f6e80f731da7526c655aeac0eec3b428b2))
* **all:** update protocol bindings and some related changes ([#237](https://github.com/taikoxyz/taiko-client/issues/237)) ([3e12042](https://github.com/taikoxyz/taiko-client/commit/3e12042a9a5b5b9baca7de1b342788b22b2ca17e))
* **bindings:** update bindings with EthDeposit changes ([#255](https://github.com/taikoxyz/taiko-client/issues/255)) ([f91f2dd](https://github.com/taikoxyz/taiko-client/commit/f91f2dd64e1fe25bc55790a8a93ea0ffab54ca3b))
* **bindings:** update go contract bindings ([#243](https://github.com/taikoxyz/taiko-client/issues/243)) ([132500e](https://github.com/taikoxyz/taiko-client/commit/132500e27d135e6e5f89c96716a0bb2d17b6801b))
* **driver:** optimize reorg handling && add more tests ([#256](https://github.com/taikoxyz/taiko-client/issues/256)) ([20c38a1](https://github.com/taikoxyz/taiko-client/commit/20c38a171ef617ddeecbe325d29d64c963792c07))
* **pkg:** do not return error when genesis block not found ([#244](https://github.com/taikoxyz/taiko-client/issues/244)) ([8033e31](https://github.com/taikoxyz/taiko-client/commit/8033e31728c946a80fdd3d07f737241c7e19edf8))
* **proof_producer:** update request parameters based on new circuits changes ([#240](https://github.com/taikoxyz/taiko-client/issues/240)) ([31521ef](https://github.com/taikoxyz/taiko-client/commit/31521ef8b7362dacbf183dc8c7d9a6020d1b0fc4))
* **proposer:** add a `--minimalBlockGasLimit` flag to mitigate the potential gas estimation issue ([#225](https://github.com/taikoxyz/taiko-client/issues/225)) ([ab8305d](https://github.com/taikoxyz/taiko-client/commit/ab8305d39d1ca3375c6477b84d4afe5c729e815f))
* **proposer:** add a new metric to track block fee ([#224](https://github.com/taikoxyz/taiko-client/issues/224)) ([98c17f0](https://github.com/taikoxyz/taiko-client/commit/98c17f00ade4fa20251a59b3aba4cad9e1eb1bd8))
* **proposer:** propose multiple L2 blocks in one L1 block ([#254](https://github.com/taikoxyz/taiko-client/issues/254)) ([36ba5db](https://github.com/taikoxyz/taiko-client/commit/36ba5dbcc2863dc34fda2e59bf8a9d30d3665d04))
* **prover:** add `--expectedReward` flag ([#248](https://github.com/taikoxyz/taiko-client/issues/248)) ([f64a762](https://github.com/taikoxyz/taiko-client/commit/f64a7620726019a2e7f5eada7b92087663b273fd))
* **prover:** improve proof submission delay calculation ([#249](https://github.com/taikoxyz/taiko-client/issues/249)) ([7cc5d54](https://github.com/taikoxyz/taiko-client/commit/7cc5d541bef0eac9078bc93eb5f1d9954b164e9b))
* **prover:** normal prover should wait targetProofTime before submitting proofs ([#232](https://github.com/taikoxyz/taiko-client/issues/232)) ([2128ddc](https://github.com/taikoxyz/taiko-client/commit/2128ddc325aaf8acf538fdd50e299187da8543dd))
* **prover:** remove submission delay when running as a system prover ([#221](https://github.com/taikoxyz/taiko-client/issues/221)) ([49a25dd](https://github.com/taikoxyz/taiko-client/commit/49a25dd72888ee54209ddce51c6a701803728d86))
* **prover:** remove the unnecessary special proof delay ([#226](https://github.com/taikoxyz/taiko-client/issues/226)) ([dcead44](https://github.com/taikoxyz/taiko-client/commit/dcead44a32ec9d064af423af0f2effea8b819fca))
* **prover:** updates based on protocol `proofTimeTarget` changes ([#227](https://github.com/taikoxyz/taiko-client/issues/227)) ([c6ea860](https://github.com/taikoxyz/taiko-client/commit/c6ea860d736828fdb50e16447dee44733371c06f))
* **repo:** enable OpenAI-based review ([#235](https://github.com/taikoxyz/taiko-client/issues/235)) ([88e4dae](https://github.com/taikoxyz/taiko-client/commit/88e4dae2e37c58273438335daade21587f25ec27))


### Bug Fixes

* **driver:** handle reorg ([#216](https://github.com/taikoxyz/taiko-client/issues/216)) ([fc2ec63](https://github.com/taikoxyz/taiko-client/commit/fc2ec637f5509b67572bb4d978f7bc41860e9b43))
* **flag:** add a missing driver flag to configuration ([#246](https://github.com/taikoxyz/taiko-client/issues/246)) ([0b60243](https://github.com/taikoxyz/taiko-client/commit/0b60243fbc03bbfc2aceb8933ae9901d4b385117))
* **prover:** fix an issue in prover event loop ([#257](https://github.com/taikoxyz/taiko-client/issues/257)) ([c550f09](https://github.com/taikoxyz/taiko-client/commit/c550f09d33f638f38461e576684432d90d850ac3))
* **prover:** update bindings && fix a delay calculation issue ([#242](https://github.com/taikoxyz/taiko-client/issues/242)) ([49c3d69](https://github.com/taikoxyz/taiko-client/commit/49c3d6957b296b1312a53fcb5122fcd944b77c2d))
* **repo:** fix openAI review workflow ([#253](https://github.com/taikoxyz/taiko-client/issues/253)) ([f44530b](https://github.com/taikoxyz/taiko-client/commit/f44530b428396b8514f974cf8ec476078d20c9d6))

## [0.8.0](https://github.com/taikoxyz/taiko-client/compare/v0.7.0...v0.8.0) (2023-05-12)


### Features

* **proposer:** check tko balance and fee before proposing ([#205](https://github.com/taikoxyz/taiko-client/issues/205)) ([cc0da63](https://github.com/taikoxyz/taiko-client/commit/cc0da632c825c1379f039f489d7426548527cc80))
* **prover:** add oracle proof submission delay ([#199](https://github.com/taikoxyz/taiko-client/issues/199)) ([7b5ed94](https://github.com/taikoxyz/taiko-client/commit/7b5ed94d12b0982de46e5ed66b38cffcf9c0c0d4))
* **prover:** add special prover (system / oracle) ([#214](https://github.com/taikoxyz/taiko-client/issues/214)) ([1020377](https://github.com/taikoxyz/taiko-client/commit/1020377bec7115efd757a6c2ea78cfe9a97b6430))
* **prover:** cancel proof if it becomes verified ([#207](https://github.com/taikoxyz/taiko-client/issues/207)) ([74d1729](https://github.com/taikoxyz/taiko-client/commit/74d17296c48a323e3ed78424b98aea9a93e081ca))
* **prover:** implementing `--graffiti` flag for prover as input to block evidence ([#209](https://github.com/taikoxyz/taiko-client/issues/209)) ([2340210](https://github.com/taikoxyz/taiko-client/commit/2340210437a14618774265d2ad2f80989296aeae))
* **prover:** improve oracle proof submission delay ([#212](https://github.com/taikoxyz/taiko-client/issues/212)) ([20c1423](https://github.com/taikoxyz/taiko-client/commit/20c14235b087e4624427879aa587a1599690dbbb))
* **prover:** update `ZkevmRpcdProducer` to integrate new circuits ([#217](https://github.com/taikoxyz/taiko-client/issues/217)) ([81cf612](https://github.com/taikoxyz/taiko-client/commit/81cf6120c1610f7a8edaa183eb9a0fbbeb45b5f1))
* **prover:** update canceling proof logic ([#218](https://github.com/taikoxyz/taiko-client/issues/218)) ([21d7e78](https://github.com/taikoxyz/taiko-client/commit/21d7e78d2e83fdd060fbc0303b244dee9777fcc4))
* **prover:** update skip checking for system prover ([#215](https://github.com/taikoxyz/taiko-client/issues/215)) ([79ba210](https://github.com/taikoxyz/taiko-client/commit/79ba2104216dfee0a1b1556c4abc5abc76c5a266))


### Bug Fixes

* **driver:** fix `GetBasefee` parameters ([#210](https://github.com/taikoxyz/taiko-client/issues/210)) ([b5dc5c5](https://github.com/taikoxyz/taiko-client/commit/b5dc5c589d26b8e9e2420ecb38ea5c83b2ae7c2e))
* **prover:** fix some oracle proof submission issues ([#211](https://github.com/taikoxyz/taiko-client/issues/211)) ([e061540](https://github.com/taikoxyz/taiko-client/commit/e06154058127962b90d5ab4a95cfec7c71942de3))
* **prover:** submit L2 signal root with submitting proof ([#220](https://github.com/taikoxyz/taiko-client/issues/220)) ([8b030ed](https://github.com/taikoxyz/taiko-client/commit/8b030ed1a8fcf1a948a2272ff8ae3927c8957d84))
* **prover:** submit L2 signal service root instead of L1 when submitting proof ([#219](https://github.com/taikoxyz/taiko-client/issues/219)) ([74fe156](https://github.com/taikoxyz/taiko-client/commit/74fe1567d0cc43e2d26d3f4af777794bc6c3a9f5))

## [0.7.0](https://github.com/taikoxyz/taiko-client/compare/v0.6.0...v0.7.0) (2023-04-28)


### Features

* **all:** update client software based on the new protocol upgrade ([#185](https://github.com/taikoxyz/taiko-client/issues/185)) ([54f7a4c](https://github.com/taikoxyz/taiko-client/commit/54f7a4cb2db72a4ffa9a199e2af1f0d709a1ac27))
* **driver:** changes based on protocol L2 EIP-1559 design ([#188](https://github.com/taikoxyz/taiko-client/issues/188)) ([82e8b97](https://github.com/taikoxyz/taiko-client/commit/82e8b9741782258840696701993b6d009d0260e0))
* **prover:** add oracle prover flag ([#194](https://github.com/taikoxyz/taiko-client/issues/194)) ([ebbc725](https://github.com/taikoxyz/taiko-client/commit/ebbc72559a70c9aefc34286b05b1f4261bae8cd6))
* **prover:** proof skip ([#198](https://github.com/taikoxyz/taiko-client/issues/198)) ([8607af8](https://github.com/taikoxyz/taiko-client/commit/8607af826ed9561a6bdae74074a517f1424e7a69))

## [0.6.0](https://github.com/taikoxyz/taiko-client/compare/v0.5.0...v0.6.0) (2023-03-20)


### Features

* **docs:** remove concept docs and refer to website ([#180](https://github.com/taikoxyz/taiko-client/pull/180)) ([a8dcdac](https://github.com/taikoxyz/taiko-client/commit/a8dcdac77c1a5e3f85e4d7a4b912cfb3d903a3d9))
* **flags:** update txpool.locals flag usage ([#181](https://github.com/taikoxyz/taiko-client/pull/181)) ([dac6102](https://github.com/taikoxyz/taiko-client/commit/dac6102d7508b9bdcb248eab4dcf469022353aa8))
* **proposer:** add `proposeEmptyBlockGasLimit` ([#178](https://github.com/taikoxyz/taiko-client/issues/178)) ([e64d769](https://github.com/taikoxyz/taiko-client/commit/e64d769f45d072b151f429f61c1fe2ab07dec0dc))


## [0.5.0](https://github.com/taikoxyz/taiko-client/compare/v0.4.0...v0.5.0) (2023-03-08)


### Features

* **pkg:** improve `BlockBatchIterator` ([#173](https://github.com/taikoxyz/taiko-client/issues/173)) ([4fab06a](https://github.com/taikoxyz/taiko-client/commit/4fab06a9cba17c5e4da09acbe9b95949d6c4d47f))
* **proposer,prover:** make `context.Context` part of `proposer.waitTillSynced` && `ProofProducer.RequestProof`'s parameters ([#169](https://github.com/taikoxyz/taiko-client/issues/169)) ([4b11e29](https://github.com/taikoxyz/taiko-client/commit/4b11e29689b8fac85023669443c351f428a54fea))
* **proposer:** new flag to propose empty blocks ([#175](https://github.com/taikoxyz/taiko-client/issues/175)) ([6621a5c](https://github.com/taikoxyz/taiko-client/commit/6621a5c89a92e7593f702e4c82e69d1215b2ca59))
* **proposer:** remove `poolContentSplitter` in proposer ([#159](https://github.com/taikoxyz/taiko-client/issues/159)) ([e26c831](https://github.com/taikoxyz/taiko-client/commit/e26c831a42fdf448b32bcf75c1f1f87bd71df481))
* **proposer:** remove an unused flag ([#176](https://github.com/taikoxyz/taiko-client/issues/176)) ([7d2126e](https://github.com/taikoxyz/taiko-client/commit/7d2126efe256bcb698b3d4df7352efdbff957ace))
* **prover:** ensure L2 EE is fully synced when calling `initL1Current` ([#170](https://github.com/taikoxyz/taiko-client/issues/170)) ([6c85058](https://github.com/taikoxyz/taiko-client/commit/6c8505827c035cc7456967bc8aab8bec1861e19b))
* **prover:** new flags for `zkevm-chain` ([#166](https://github.com/taikoxyz/taiko-client/issues/166)) ([1c90a3d](https://github.com/taikoxyz/taiko-client/commit/1c90a3d6b7cada0b116875d88f0952993b54bb5f))
* **prover:** tracking for most recent block ID to ensure (relatively) consecutive proving by notification system ([#174](https://github.com/taikoxyz/taiko-client/issues/174)) ([e500039](https://github.com/taikoxyz/taiko-client/commit/e5000395a3a28bd282df64f54867fd771143a56a))


### Bug Fixes

* **proposer:** remove an unused metric from proposer ([#171](https://github.com/taikoxyz/taiko-client/issues/171)) ([8df5eea](https://github.com/taikoxyz/taiko-client/commit/8df5eea1d9f1482a10b7d395ae19953f5d6ea6ce))

## [0.4.0](https://github.com/taikoxyz/taiko-client/compare/v0.3.0...v0.4.0) (2023-02-22)


### Features

* **all:** update contract bindings && some improvements based on Alex's feedback ([#153](https://github.com/taikoxyz/taiko-client/issues/153)) ([bdaa292](https://github.com/taikoxyz/taiko-client/commit/bdaa2920bcb113d3887409edb17462b5e0d3a2c5))
* **bindings:** parse solidity custom errors ([#163](https://github.com/taikoxyz/taiko-client/issues/163)) ([9a79127](https://github.com/taikoxyz/taiko-client/commit/9a79127a5a3cddf4e95ac899943e6551b02cf432))


### Bug Fixes

* **driver:** fix an issue in sync status checking ([#162](https://github.com/taikoxyz/taiko-client/issues/162)) ([4b21027](https://github.com/taikoxyz/taiko-client/commit/4b2102720e2c1c2fcaef1853ad74b91c6d08aaaa))
* **proposer:** fix a proposer nonce order issue ([#157](https://github.com/taikoxyz/taiko-client/issues/157)) ([80fc0e9](https://github.com/taikoxyz/taiko-client/commit/80fc0e94d819f93ecdeac492eb1f35d5f2bb09ce))

## [0.3.0](https://github.com/taikoxyz/taiko-client/compare/v0.2.4...v0.3.0) (2023-02-15)


### Features

* **prover:** improve the check for whether the current block still needs a new proof ([#145](https://github.com/taikoxyz/taiko-client/issues/145)) ([6c00fc5](https://github.com/taikoxyz/taiko-client/commit/6c00fc544b1ed92a4e38860059ef463282648a42))
* **prover:** update `ZkevmRpcdProducer` to make it connecting to a real proverd service ([#121](https://github.com/taikoxyz/taiko-client/issues/121)) ([8c8ee9c](https://github.com/taikoxyz/taiko-client/commit/8c8ee9c2c3266e25e4233821034b89f50bb08c33))
* **repo:** implement release please ([#148](https://github.com/taikoxyz/taiko-client/issues/148)) ([d8f3ad8](https://github.com/taikoxyz/taiko-client/commit/d8f3ad80d358fe547d356b7f7d7fd6e6ca9279ce))
