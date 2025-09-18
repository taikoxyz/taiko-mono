# Changelog

## [1.11.0](https://github.com/taikoxyz/taiko-mono/compare/taiko-alethia-client-v1.10.1...taiko-alethia-client-v1.11.0) (2025-09-18)


### Features

* **taiko-client:** Add duration metrics to PreconfBlockApiServer ([#19969](https://github.com/taikoxyz/taiko-mono/issues/19969)) ([cb174ba](https://github.com/taikoxyz/taiko-mono/commit/cb174ba3342a88cf80818b9efe3a7add1859dac7))
* **taiko-client:** add HTTP 429 rate limit detection for Raiko ([#20129](https://github.com/taikoxyz/taiko-mono/issues/20129)) ([4a03fbd](https://github.com/taikoxyz/taiko-mono/commit/4a03fbd5ae1e74a7722121f88917b309c9828397))
* **taiko-client:** blacklist peers who publish blocks signed by sequencers who arent onchain ([#20006](https://github.com/taikoxyz/taiko-mono/issues/20006)) ([8b477d3](https://github.com/taikoxyz/taiko-mono/commit/8b477d35402a5c7f63c479df984879a460876923))
* **taiko-client:** fallback preconf ([#19546](https://github.com/taikoxyz/taiko-mono/issues/19546)) ([3a402ad](https://github.com/taikoxyz/taiko-mono/commit/3a402ad83b4dfbb929ba3c00bc6603722a545008))
* **taiko-client:** fallback to sgx proof ([#19967](https://github.com/taikoxyz/taiko-mono/issues/19967)) ([7a63b58](https://github.com/taikoxyz/taiko-mono/commit/7a63b58ca234997b2862063705d020bf3e72d90d))
* **taiko-client:** make the `beaconSyncer.getBlockPayload()` more compliant with the spec ([#19860](https://github.com/taikoxyz/taiko-mono/issues/19860)) ([747e898](https://github.com/taikoxyz/taiko-mono/commit/747e898f8187be6d4c10b88ec36ee5ed95db3580))
* **taiko-client:** read handover slots on chain ([#19987](https://github.com/taikoxyz/taiko-mono/issues/19987)) ([316fadc](https://github.com/taikoxyz/taiko-mono/commit/316fadcef6a55dd9da4ba2b8a83ddbe00aca1c77))
* **taiko-client:** remove dependency on geth undocumented `eth_getHeaderByHash` feature  ([#20035](https://github.com/taikoxyz/taiko-mono/issues/20035)) ([e1032ce](https://github.com/taikoxyz/taiko-mono/commit/e1032ceeea5657f0d2f4cb290321a2902287ec66))
* **taiko-client:** rpc/engine/ethclient metrics ([#20106](https://github.com/taikoxyz/taiko-mono/issues/20106)) ([d54c884](https://github.com/taikoxyz/taiko-mono/commit/d54c8841c77144a412ff7cf6859b3c99c5a0f60b))


### Bug Fixes

* **protocol:** fix devnet deployment ([#20098](https://github.com/taikoxyz/taiko-mono/issues/20098)) ([cbf0fc7](https://github.com/taikoxyz/taiko-mono/commit/cbf0fc71a2bde500bd8ce8e7f4cafee0d805996a))
* **taiko-client:** correct grammar and spelling issues ([#20175](https://github.com/taikoxyz/taiko-mono/issues/20175)) ([944aa01](https://github.com/taikoxyz/taiko-mono/commit/944aa01bd354e1ad1d8642d29397793ed5f4629c))
* **taiko-client:** elapsed time in histograms ([#19975](https://github.com/taikoxyz/taiko-mono/issues/19975)) ([3807dfc](https://github.com/taikoxyz/taiko-mono/commit/3807dfcdd3f2b7cc08a6b1260b62723d58e64162))
* **taiko-client:** enhance error handling in configuration and sync processes ([#20103](https://github.com/taikoxyz/taiko-mono/issues/20103)) ([0aeac9b](https://github.com/taikoxyz/taiko-mono/commit/0aeac9b1837e93ab7fe3391dde9e3d1865fb47fd))
* **taiko-client:** fix preconf router config ([#20074](https://github.com/taikoxyz/taiko-mono/issues/20074)) ([e0ba42f](https://github.com/taikoxyz/taiko-mono/commit/e0ba42f497743d6e442c95fa447bdceb2cb61980))
* **taiko-client:** revert pr-20035 ([#20066](https://github.com/taikoxyz/taiko-mono/issues/20066)) ([2ee7349](https://github.com/taikoxyz/taiko-mono/commit/2ee73496fa701f1decda06befe6f3b1297d29fef))
* **taiko-client:** use unique log key for block ID in fallback check ([#20026](https://github.com/taikoxyz/taiko-mono/issues/20026)) ([793a2d6](https://github.com/taikoxyz/taiko-mono/commit/793a2d69e1882adfe029f85a68e5079cd8c63310))


### Chores

* **relayer, taiko-client:** fix typo/grammar in comments ([#20071](https://github.com/taikoxyz/taiko-mono/issues/20071)) ([da74cf5](https://github.com/taikoxyz/taiko-mono/commit/da74cf532ec777eadbee5a6dd44fcc2a4b67d346))
* **taiko-client:** add emoji to quickly identify logs ([#19974](https://github.com/taikoxyz/taiko-mono/issues/19974)) ([8e979b6](https://github.com/taikoxyz/taiko-mono/commit/8e979b69aa00ba66140f1ab318b72b0f1a62d56b))
* **taiko-client:** correct misspelling in `taiko-client` comments ([#20052](https://github.com/taikoxyz/taiko-mono/issues/20052)) ([96e8507](https://github.com/taikoxyz/taiko-mono/commit/96e8507581aebbfabd4c3cec3475baf0d87026d0))
* **taiko-client:** refactor preconfblocks envelope terminology ([#20096](https://github.com/taikoxyz/taiko-mono/issues/20096)) ([922fd50](https://github.com/taikoxyz/taiko-mono/commit/922fd509e5e7ba20cec1c5aba09fab51e88b6535))
* **taiko-client:** remove unused prover fields from AssignmentExpiredEventHandler ([#20105](https://github.com/taikoxyz/taiko-mono/issues/20105)) ([fef006f](https://github.com/taikoxyz/taiko-mono/commit/fef006f760f35a5bc222c7348b2ca07e7db9a2b1))


### Documentation

* **taiko-client:** fix broken link ([#20078](https://github.com/taikoxyz/taiko-mono/issues/20078)) ([e066c1c](https://github.com/taikoxyz/taiko-mono/commit/e066c1cd3a6245eb1c2ad1fc69509c70e0b362d1))


### Code Refactoring

* **taiko-client:** use the built-in max/min to simplify the code ([#20022](https://github.com/taikoxyz/taiko-mono/issues/20022)) ([4bb93e2](https://github.com/taikoxyz/taiko-mono/commit/4bb93e2f57defcd81f160187696faaf7adc0bd5d))

## [1.10.1](https://github.com/taikoxyz/taiko-mono/compare/taiko-alethia-client-v1.10.0...taiko-alethia-client-v1.10.1) (2025-08-12)


### Bug Fixes

* **taiko-client:** add extended retry for missing trie node sync errors ([#19874](https://github.com/taikoxyz/taiko-mono/issues/19874)) ([65c00fd](https://github.com/taikoxyz/taiko-mono/commit/65c00fd2c2d78a6dc317c1fcf1911513d8d2250e))


### Chores

* **taiko-client:** lower request sync margin ([#19913](https://github.com/taikoxyz/taiko-mono/issues/19913)) ([48ffe13](https://github.com/taikoxyz/taiko-mono/commit/48ffe13ed43fc59cdc6850f7374f5e779a6ed6f7))

## [1.10.0](https://github.com/taikoxyz/taiko-mono/compare/taiko-alethia-client-v1.9.0...taiko-alethia-client-v1.10.0) (2025-08-05)


### Features

* **taiko-client:** add support for external signer from optimism module ([#19851](https://github.com/taikoxyz/taiko-mono/issues/19851)) ([0227770](https://github.com/taikoxyz/taiko-mono/commit/0227770f8baf256fd362b4393ab85da623e784f2))


### Bug Fixes

* **taiko-client:** fix the returned err about blob not found ([#19869](https://github.com/taikoxyz/taiko-mono/issues/19869)) ([45336b0](https://github.com/taikoxyz/taiko-mono/commit/45336b037b4d7f52c1ae2cd44139011587393631))

## [1.9.0](https://github.com/taikoxyz/taiko-mono/compare/taiko-alethia-client-v1.8.0...taiko-alethia-client-v1.9.0) (2025-07-30)


### Features

* **protocol:** implement Shasta fork ([#19664](https://github.com/taikoxyz/taiko-mono/issues/19664)) ([2f798ff](https://github.com/taikoxyz/taiko-mono/commit/2f798ff47ab115946ffda8856f9c673344ee1ae3))


### Bug Fixes

* **taiko-client:** fix swagger gen preconf blocks api ([#19794](https://github.com/taikoxyz/taiko-mono/issues/19794)) ([aae4af8](https://github.com/taikoxyz/taiko-mono/commit/aae4af8a3bb997a72d9205f15a94535ee3ca016d))
* **taiko-client:** p2p fixes ([#19841](https://github.com/taikoxyz/taiko-mono/issues/19841)) ([cac40c2](https://github.com/taikoxyz/taiko-mono/commit/cac40c2740ea2e065a71ac520ef43343df4ad5df))
* **taiko-client:** use zk error as the err of `g.Wait()` ([#19806](https://github.com/taikoxyz/taiko-mono/issues/19806)) ([211d8fb](https://github.com/taikoxyz/taiko-mono/commit/211d8fb76522eca0190b1df1b880f5960d26c653))


### Chores

* **taiko-client:** log PreconfOperatorAddress ([#19787](https://github.com/taikoxyz/taiko-mono/issues/19787)) ([3d84ea5](https://github.com/taikoxyz/taiko-mono/commit/3d84ea5ef6e71400ae7ae47a0f3fac51b83ecdd5))


### Code Refactoring

* **taiko-client:** reduce the number of requests ([#19802](https://github.com/taikoxyz/taiko-mono/issues/19802)) ([b57892f](https://github.com/taikoxyz/taiko-mono/commit/b57892fa1327072e6305badb88e9300093ef4adc))

## [1.8.0](https://github.com/taikoxyz/taiko-mono/compare/taiko-alethia-client-v1.7.0...taiko-alethia-client-v1.8.0) (2025-07-25)


### Features

* **taiko-client:** add proof generation time sum metrics ([#19781](https://github.com/taikoxyz/taiko-mono/issues/19781)) ([4d2d404](https://github.com/taikoxyz/taiko-mono/commit/4d2d40464c02201d3a0f0fcdbf2295fa89edd670))
* **taiko-client:** cache lookahead every l1 block ([#19785](https://github.com/taikoxyz/taiko-mono/issues/19785)) ([82c9308](https://github.com/taikoxyz/taiko-mono/commit/82c9308e8b30b3995608b23afb99b760b83513f6))


### Bug Fixes

* **taiko-client:** change to use `returnError` for some errors in `BuildPreconfBlock` ([#19753](https://github.com/taikoxyz/taiko-mono/issues/19753)) ([60320bc](https://github.com/taikoxyz/taiko-mono/commit/60320bcc1174c671e2efff431c891b6f4bea713f))


### Code Refactoring

* **taiko-client:** introduce `tryPutEnvelopeIntoCache` to reduce duplicated code ([#19769](https://github.com/taikoxyz/taiko-mono/issues/19769)) ([fb454b1](https://github.com/taikoxyz/taiko-mono/commit/fb454b19da004c00fe4c6cb8d731b16db4e14664))

## [1.7.0](https://github.com/taikoxyz/taiko-mono/compare/taiko-alethia-client-v1.6.3...taiko-alethia-client-v1.7.0) (2025-07-18)


### Features

* **protocol:** allow operators to register a new address(sequencer) ([#19722](https://github.com/taikoxyz/taiko-mono/issues/19722)) ([01cc55a](https://github.com/taikoxyz/taiko-mono/commit/01cc55acdcf8f933de92dc2ee1cd497abf15d542))
* **taiko-client:** add domain envelope type, update l1Origin with signature and forced inclusion marker ([#19719](https://github.com/taikoxyz/taiko-mono/issues/19719)) ([ee54a9d](https://github.com/taikoxyz/taiko-mono/commit/ee54a9dfee692106809ee7d21824bfef6027a720))
* **taiko-client:** introduce api key for raiko ([#19732](https://github.com/taikoxyz/taiko-mono/issues/19732)) ([2962e23](https://github.com/taikoxyz/taiko-mono/commit/2962e2341457c85fb91f1922c9f9801bd9258ff0))
* **taiko-client:** set highest unsafe l2 payload to latest head on server startup in driver ([#19696](https://github.com/taikoxyz/taiko-mono/issues/19696)) ([16ef25d](https://github.com/taikoxyz/taiko-mono/commit/16ef25d141f27bc4bc991e946c7ac9a63a1fef21))


### Bug Fixes

* **taiko-client:** should use blockID to get L1 origin ([#19713](https://github.com/taikoxyz/taiko-mono/issues/19713)) ([526018d](https://github.com/taikoxyz/taiko-mono/commit/526018d992e127e7feabd0b68412387b792ef3ad))
* **taiko-client:** update L1 origin of parent if the block is building on a orphaned parent ([#19701](https://github.com/taikoxyz/taiko-mono/issues/19701)) ([6632b6d](https://github.com/taikoxyz/taiko-mono/commit/6632b6d318e0501ec88f33e3a6f904b0ce02cf65))


### Chores

* fix some minor issues in comments ([#19740](https://github.com/taikoxyz/taiko-mono/issues/19740)) ([e39f4db](https://github.com/taikoxyz/taiko-mono/commit/e39f4db8406c0ec5f6ac383f32d9126cdb099ec4))
* **taiko-client:** fix some function names in comment ([#19724](https://github.com/taikoxyz/taiko-mono/issues/19724)) ([3c1d2cb](https://github.com/taikoxyz/taiko-mono/commit/3c1d2cbddd137354773e981a9f80929bc0cb9a57))
* **taiko-client:** rename `payload` to `envelope` ([#19752](https://github.com/taikoxyz/taiko-mono/issues/19752)) ([3df3a1e](https://github.com/taikoxyz/taiko-mono/commit/3df3a1e8d3f6eca6f02f0b32a79420168a3277e1))


### Tests

* **taiko-client:** remove the dependency of `debug_setHead` for better node implementations diversity support ([#19721](https://github.com/taikoxyz/taiko-mono/issues/19721)) ([958f2ac](https://github.com/taikoxyz/taiko-mono/commit/958f2ac50be2021b2456b6f6d3f8d1583cda980d))

## [1.6.3](https://github.com/taikoxyz/taiko-mono/compare/taiko-alethia-client-v1.6.2...taiko-alethia-client-v1.6.3) (2025-06-26)


### Bug Fixes

* **taiko-client:** handle reorg case when getting blobs ([#19660](https://github.com/taikoxyz/taiko-mono/issues/19660)) ([aeb9ddc](https://github.com/taikoxyz/taiko-mono/commit/aeb9ddca5c264581ebc409f64c29a300521d6725))


### Chores

* **taiko-client:** make function comment match function name ([#19649](https://github.com/taikoxyz/taiko-mono/issues/19649)) ([30bde71](https://github.com/taikoxyz/taiko-mono/commit/30bde714f9a8cd296d586d6a9da09222dbf41ab5))

## [1.6.2](https://github.com/taikoxyz/taiko-mono/compare/taiko-alethia-client-v1.6.1...taiko-alethia-client-v1.6.2) (2025-06-05)


### Bug Fixes

* **taiko-client:** dont use c.Request().Context() ([#19592](https://github.com/taikoxyz/taiko-mono/issues/19592)) ([f1bcc4a](https://github.com/taikoxyz/taiko-mono/commit/f1bcc4a54305f257ccbb0e29d0a7f37253603921))

## [1.6.1](https://github.com/taikoxyz/taiko-mono/compare/taiko-alethia-client-v1.6.0...taiko-alethia-client-v1.6.1) (2025-06-02)


### Bug Fixes

* **taiko-client:** filter genesis block verified for hekla ([#19576](https://github.com/taikoxyz/taiko-mono/issues/19576)) ([e76d61f](https://github.com/taikoxyz/taiko-mono/commit/e76d61fa5241a7853d64ec083b2ac06ea4485d47))

## [1.6.0](https://github.com/taikoxyz/taiko-mono/compare/taiko-alethia-client-v1.5.0...taiko-alethia-client-v1.6.0) (2025-05-31)


### Features

* **taiko-client:** add checks to ensure preconfirmation blocks are based on canonical chain ([#19379](https://github.com/taikoxyz/taiko-mono/issues/19379)) ([22e8a64](https://github.com/taikoxyz/taiko-mono/commit/22e8a645ffe329c17f74abec8ff1735c21efeb08))
* **taiko-client:** add more double-checks in `isKnownCanonicalBlock` ([#19473](https://github.com/taikoxyz/taiko-mono/issues/19473)) ([bf86754](https://github.com/taikoxyz/taiko-mono/commit/bf867543c2ecb7abdd753d882406827602d342bb))
* **taiko-client:** add more preconfirmation metrics ([#19523](https://github.com/taikoxyz/taiko-mono/issues/19523)) ([b599ffe](https://github.com/taikoxyz/taiko-mono/commit/b599ffe41bd8b3027d15be4dd392736839fc861c))
* **taiko-client:** check router on taiko wrapper before allowing preconf block to be made ([#19525](https://github.com/taikoxyz/taiko-mono/issues/19525)) ([0c4bd86](https://github.com/taikoxyz/taiko-mono/commit/0c4bd86386d3be19464bd5be871aca2fe7bf5d56))
* **taiko-client:** cherry-pick a missing proposer change in `0.43.2` ([#19482](https://github.com/taikoxyz/taiko-mono/issues/19482)) ([3a90600](https://github.com/taikoxyz/taiko-mono/commit/3a906000d2ab4f7a7d7c94e1d5ca303ec277aa39))
* **taiko-client:** gossip req/resp + endofsequencer mark + ws endpoint ([#19361](https://github.com/taikoxyz/taiko-mono/issues/19361)) ([efc6f91](https://github.com/taikoxyz/taiko-mono/commit/efc6f91832d5ca3154571efd883a2d74a4f05e5b))
* **taiko-client:** improve `FetchPacaya` ([#19438](https://github.com/taikoxyz/taiko-mono/issues/19438)) ([e903eec](https://github.com/taikoxyz/taiko-mono/commit/e903eec0e7c3f79e70fda07cf5162442b39b0bc4))
* **taiko-client:** improve `isBatchPreconfirmed` ([#19373](https://github.com/taikoxyz/taiko-mono/issues/19373)) ([efe2d99](https://github.com/taikoxyz/taiko-mono/commit/efe2d99f85920c7aabcefc36a97761e21c6d5f29))
* **taiko-client:** improve `RequestProof` ([#19433](https://github.com/taikoxyz/taiko-mono/issues/19433)) ([3580ac1](https://github.com/taikoxyz/taiko-mono/commit/3580ac1111d38154f94839ac797a94c7469de9f0))
* **taiko-client:** introduce `--prover.localProposerAddresses` flag ([#19517](https://github.com/taikoxyz/taiko-mono/issues/19517)) ([e7b8f05](https://github.com/taikoxyz/taiko-mono/commit/e7b8f05d62f47d6177c1cb2575cc24e29ac0671b))
* **taiko-client:** introduce `BuildPayloadArgsID` for `L1Origin` ([#19444](https://github.com/taikoxyz/taiko-mono/issues/19444)) ([883a356](https://github.com/taikoxyz/taiko-mono/commit/883a35649329b76a6e438e5f07d305f493546496))
* **taiko-client:** introduce `GET /status` for preconfirmation API server ([#19358](https://github.com/taikoxyz/taiko-mono/issues/19358)) ([1dce498](https://github.com/taikoxyz/taiko-mono/commit/1dce498d932455b84c478e6e3acbfd323f1d3c42))
* **taiko-client:** introduce `ImportPendingBlocksFromCache` in `PreconfBlockAPIServer` ([#19339](https://github.com/taikoxyz/taiko-mono/issues/19339)) ([0da05f5](https://github.com/taikoxyz/taiko-mono/commit/0da05f5e4e1f36b16ad97a90028c5a3cb0ac3623))
* **taiko-client:** introduce `payloadQueue` for P2P gossip messages ([#19195](https://github.com/taikoxyz/taiko-mono/issues/19195)) ([f981f59](https://github.com/taikoxyz/taiko-mono/commit/f981f59b63b9cdb5a838d0bfa2ced8b295e56710))
* **taiko-client:** lookahead sliding window ([#19322](https://github.com/taikoxyz/taiko-mono/issues/19322)) ([abcc6a6](https://github.com/taikoxyz/taiko-mono/commit/abcc6a6a6c9d606f3a04b4817d0e75370102098c))
* **taiko-client:** preconf handover skip slots ([#19271](https://github.com/taikoxyz/taiko-mono/issues/19271)) ([f7fef81](https://github.com/taikoxyz/taiko-mono/commit/f7fef81ecf21ea1565a741fa31a5ae48a74ca2e2))
* **taiko-client:** remove `DELETE /preconfBlocks` API ([#19537](https://github.com/taikoxyz/taiko-mono/issues/19537)) ([9678be5](https://github.com/taikoxyz/taiko-mono/commit/9678be5ce2673d89d1474af95c8f8036d6e8f78f))
* **taiko-client:** remove an unused field in `BatchProposedIterator` ([#19524](https://github.com/taikoxyz/taiko-mono/issues/19524)) ([827cd89](https://github.com/taikoxyz/taiko-mono/commit/827cd89b194496b1ad6209d4de11f1dc71d63474))
* **taiko-client:** remove Guardian Prover ABI ([#19506](https://github.com/taikoxyz/taiko-mono/issues/19506)) ([349ad4b](https://github.com/taikoxyz/taiko-mono/commit/349ad4b2c30a817d880aa88ea706bde4b123ae5c))
* **taiko-client:** remove two unused flags ([#19434](https://github.com/taikoxyz/taiko-mono/issues/19434)) ([84f5631](https://github.com/taikoxyz/taiko-mono/commit/84f56316b27de4afdf6ce23af9288d2cfc3337df))
* **taiko-client:** run tests post Pacaya fork ([#19313](https://github.com/taikoxyz/taiko-mono/issues/19313)) ([461bf65](https://github.com/taikoxyz/taiko-mono/commit/461bf653dd731240b2b143ff296358ef692bd659))
* **taiko-client:** set `pacayaForkHeightMainnet` ([#19448](https://github.com/taikoxyz/taiko-mono/issues/19448)) ([ddc2408](https://github.com/taikoxyz/taiko-mono/commit/ddc240805ba0d5429a036fb3e6996f7445af0585))
* **taiko-client:** validate the payload before caching it && only cache the preconf block request after sent ([#19487](https://github.com/taikoxyz/taiko-mono/issues/19487)) ([973929b](https://github.com/taikoxyz/taiko-mono/commit/973929b59603bb75c4fd02b5fae3002cf794f690))


### Bug Fixes

* **repo:** codecov integration fix ([#19326](https://github.com/taikoxyz/taiko-mono/issues/19326)) ([2d6673f](https://github.com/taikoxyz/taiko-mono/commit/2d6673ff4c80871fe26b79e1ae6b29631e94f637))
* **taiko-client:** a Pacaya height that the mainnet won't reach temporarily ([#19299](https://github.com/taikoxyz/taiko-mono/issues/19299)) ([fe7833b](https://github.com/taikoxyz/taiko-mono/commit/fe7833bf437c716aeb61f919571fea153f61666e))
* **taiko-client:** check pointer before logging ([#19466](https://github.com/taikoxyz/taiko-mono/issues/19466)) ([0310690](https://github.com/taikoxyz/taiko-mono/commit/0310690b471a001865cce033f01496ba8b252e26))
* **taiko-client:** curr range lookahead fix ([#19529](https://github.com/taikoxyz/taiko-mono/issues/19529)) ([38f7ad4](https://github.com/taikoxyz/taiko-mono/commit/38f7ad48860ec2ddc3e9b1902c5ce03722d7855e))
* **taiko-client:** fix an issue for inserting `Anchor` block after precomfirmation ([#19425](https://github.com/taikoxyz/taiko-mono/issues/19425)) ([d7b11d1](https://github.com/taikoxyz/taiko-mono/commit/d7b11d1495d26b509e4ae354fc7f19740582bb63))
* **taiko-client:** fix an issue in `isBatchPreconfirmed` ([#19314](https://github.com/taikoxyz/taiko-mono/issues/19314)) ([17346cf](https://github.com/taikoxyz/taiko-mono/commit/17346cf4f4731f04d221c822db46601f9473f415))
* **taiko-client:** fix an issue in `RemovePreconfBlocks` when no `HeadL1Origin` in L2 EE ([#19307](https://github.com/taikoxyz/taiko-mono/issues/19307)) ([602bdd3](https://github.com/taikoxyz/taiko-mono/commit/602bdd385cfd3a537ab22b47b48776b208131139))
* **taiko-client:** fix an issue in missing ancients search ([#19323](https://github.com/taikoxyz/taiko-mono/issues/19323)) ([ac7ba74](https://github.com/taikoxyz/taiko-mono/commit/ac7ba7465ddbf54252755147c32b4ed0cac5f4e6))
* **taiko-client:** fix an occasional `engine.SYNCING` error when receiving P2P preconf blocks ([#19262](https://github.com/taikoxyz/taiko-mono/issues/19262)) ([23e4bc5](https://github.com/taikoxyz/taiko-mono/commit/23e4bc5624247f5047fc9a7a6b254bef64385b56))
* **taiko-client:** make metrics about sgx-geth more accurate ([#19352](https://github.com/taikoxyz/taiko-mono/issues/19352)) ([b5c1f96](https://github.com/taikoxyz/taiko-mono/commit/b5c1f96ac326523927cd3ad4822fb4d97cf9e191))
* **taiko-client:** only update the lookahead once per epoch ([#19483](https://github.com/taikoxyz/taiko-mono/issues/19483)) ([5c32d6a](https://github.com/taikoxyz/taiko-mono/commit/5c32d6a6846dedb0213e7c0a4301b31b19aecbd8))
* **taiko-client:** reduce slot required for updating lookahead ([#19526](https://github.com/taikoxyz/taiko-mono/issues/19526)) ([a804cb2](https://github.com/taikoxyz/taiko-mono/commit/a804cb28da6c8d7b98a10c24b2bcf81e8b9be9f8))
* **taiko-client:** update `highestUnsafeL2PayloadBlockID` if reorging via `POST /preconfBlocks` ([#19490](https://github.com/taikoxyz/taiko-mono/issues/19490)) ([ecc71f5](https://github.com/taikoxyz/taiko-mono/commit/ecc71f5748cb9db2addd3457c17e102bdbbe1bcf))
* **taiko-client:** update highest unsafe payload on import child blocks ([#19556](https://github.com/taikoxyz/taiko-mono/issues/19556)) ([9a0a4aa](https://github.com/taikoxyz/taiko-mono/commit/9a0a4aa88aeab391dc2c9eebbe6232fd56739e47))
* **taiko-client:** update slots in epoch for handover ([#19282](https://github.com/taikoxyz/taiko-mono/issues/19282)) ([ea4a197](https://github.com/taikoxyz/taiko-mono/commit/ea4a197924181360b3f3b640bbcbef2c79cce973))


### Chores

* **protocol, taiko-client:** general typos fix ([#19272](https://github.com/taikoxyz/taiko-mono/issues/19272)) ([c22e86d](https://github.com/taikoxyz/taiko-mono/commit/c22e86df678537a3416f99c8fff98e08c51352ca))
* **taiko-client:** add a log for local proposer addresses ([#19518](https://github.com/taikoxyz/taiko-mono/issues/19518)) ([bb1fec4](https://github.com/taikoxyz/taiko-mono/commit/bb1fec4d96a1ead35d20ccae22ef21f84712ccb9))
* **taiko-client:** add more preconfirmation metrics ([#19342](https://github.com/taikoxyz/taiko-mono/issues/19342)) ([669ab99](https://github.com/taikoxyz/taiko-mono/commit/669ab99e298535aeb7af81f254a2b5480b4a4692))
* **taiko-client:** clean up the unused code ([#19547](https://github.com/taikoxyz/taiko-mono/issues/19547)) ([87fc74f](https://github.com/taikoxyz/taiko-mono/commit/87fc74f6f22cfbd368a3917502a5086ffa7c58a5))
* **taiko-client:** cleanup the `Ontake` fork decompression method ([#19528](https://github.com/taikoxyz/taiko-mono/issues/19528)) ([e30687c](https://github.com/taikoxyz/taiko-mono/commit/e30687c4df3fdc591e9a2a29f510d4093c56d7ac))
* **taiko-client:** improve error messages when initiating pacaya clients ([#19388](https://github.com/taikoxyz/taiko-mono/issues/19388)) ([bb54d0c](https://github.com/taikoxyz/taiko-mono/commit/bb54d0ce80bbef43c265c2ea45dace165bf7c339))
* **taiko-client:** remove an unused filed in `PreconfBlockAPIServer` ([#19386](https://github.com/taikoxyz/taiko-mono/issues/19386)) ([d8f6a17](https://github.com/taikoxyz/taiko-mono/commit/d8f6a172ea2e329484be7dc5e6f06878bf915c31))
* **taiko-client:** when removing preconf blocks, use the update method to log it ([#19515](https://github.com/taikoxyz/taiko-mono/issues/19515)) ([3fc156e](https://github.com/taikoxyz/taiko-mono/commit/3fc156ef68be72d37ddebca69b6899e86b6336eb))


### Code Refactoring

* **taiko-client:** cleanup `Ontake` fork implementation ([#19294](https://github.com/taikoxyz/taiko-mono/issues/19294)) ([e6c780d](https://github.com/taikoxyz/taiko-mono/commit/e6c780d28bef967441f96c38a22eba28e39d782d))
* **taiko-client:** polish [#19361](https://github.com/taikoxyz/taiko-mono/issues/19361) ([#19435](https://github.com/taikoxyz/taiko-mono/issues/19435)) ([6e5b8c8](https://github.com/taikoxyz/taiko-mono/commit/6e5b8c800c0128ecf080567dc6daadd75c79319d))
* **taiko-client:** refactor generated proof logs ([#19366](https://github.com/taikoxyz/taiko-mono/issues/19366)) ([3e3f295](https://github.com/taikoxyz/taiko-mono/commit/3e3f2955eef84520130065218d5f1b610c686c38))
* **taiko-client:** rename `blobSyncer` to `eventSyncer` ([#19340](https://github.com/taikoxyz/taiko-mono/issues/19340)) ([74751b9](https://github.com/taikoxyz/taiko-mono/commit/74751b9dc95df1436a783ad02325d23f1bb29099))


### Tests

* **taiko-client:** fix `taiko-client` CI tests ([#19422](https://github.com/taikoxyz/taiko-mono/issues/19422)) ([6ff056a](https://github.com/taikoxyz/taiko-mono/commit/6ff056a749ac066ef8840e8a05876e260ff3e682))

## [1.5.0](https://github.com/taikoxyz/taiko-mono/compare/taiko-alethia-client-v1.4.1...taiko-alethia-client-v1.5.0) (2025-04-11)


### Features

* **taiko-client:** check proof status in `BatchesProved` event handler ([#19184](https://github.com/taikoxyz/taiko-mono/issues/19184)) ([836aaf3](https://github.com/taikoxyz/taiko-mono/commit/836aaf3a21362d540f701f02be61b89943fb4a06))
* **taiko-client:** clear buffer & make `proofPollingInterval` configurable ([#19202](https://github.com/taikoxyz/taiko-mono/issues/19202)) ([8ec1dbd](https://github.com/taikoxyz/taiko-mono/commit/8ec1dbd03af87f5a8431a752fcce1705c8eadedb))
* **taiko-client:** enable pivot proof & refactor logging ([#19173](https://github.com/taikoxyz/taiko-mono/issues/19173)) ([4a6d079](https://github.com/taikoxyz/taiko-mono/commit/4a6d079622f7bfbfcf2a28dff3386d51fe308b1e))
* **taiko-client:** improve `BatchesProved` event handler in prover ([#19182](https://github.com/taikoxyz/taiko-mono/issues/19182)) ([ed94969](https://github.com/taikoxyz/taiko-mono/commit/ed9496991cf4455d15cdd096d4a494f14e31ed01))
* **taiko-client:** improve P2P message checks in `OnUnsafeL2Payload` ([#19187](https://github.com/taikoxyz/taiko-mono/issues/19187)) ([a33062e](https://github.com/taikoxyz/taiko-mono/commit/a33062e0c42d3e6dfb54d79f205f0a84858a44b6))
* **taiko-client:** introduce `isBatchPreconfirmed` check in `BatchProposed` event handler ([#19236](https://github.com/taikoxyz/taiko-mono/issues/19236)) ([9658915](https://github.com/taikoxyz/taiko-mono/commit/96589151400f7f85b60f359df5f6cd1a41a1af4d))
* **taiko-client:** remove some unused proposer flags ([#19180](https://github.com/taikoxyz/taiko-mono/issues/19180)) ([e17b57a](https://github.com/taikoxyz/taiko-mono/commit/e17b57af40f4d6165c2f09dbda86594d13380582))
* **taiko-client:** remove some unused variables in `rpc` package ([#19213](https://github.com/taikoxyz/taiko-mono/issues/19213)) ([b62731c](https://github.com/taikoxyz/taiko-mono/commit/b62731c4df09701c1d8a0a4449d3cd5001e08c48))


### Bug Fixes

* **taiko-client:** check `--prover.proveUnassignedBlocks` flag value before proving expired blocks ([#19172](https://github.com/taikoxyz/taiko-mono/issues/19172)) ([2803954](https://github.com/taikoxyz/taiko-mono/commit/280395485fce6b783f7e96b4c74d8ce587cec065))
* **taiko-client:** don't return err when single sp1 proof is null ([#19240](https://github.com/taikoxyz/taiko-mono/issues/19240)) ([92e9cf9](https://github.com/taikoxyz/taiko-mono/commit/92e9cf9685edf929b0e1d3970ac6d4481ccd101c))
* **taiko-client:** use proof type from raiko ([#19228](https://github.com/taikoxyz/taiko-mono/issues/19228)) ([44b0209](https://github.com/taikoxyz/taiko-mono/commit/44b0209394e6cae1ee6a5a3eb6b0d39a77074ddf))


### Chores

* **taiko-client:** improve `BatchesVerified` event handler ([#19178](https://github.com/taikoxyz/taiko-mono/issues/19178)) ([938256b](https://github.com/taikoxyz/taiko-mono/commit/938256bd11438b91220d5607a29d5ac054978c63))
* **taiko-client:** remove a duplicated check for P2P message ([#19189](https://github.com/taikoxyz/taiko-mono/issues/19189)) ([4a793f5](https://github.com/taikoxyz/taiko-mono/commit/4a793f5c993132185c3cf8283df3393499b8e5b0))
* **taiko-client:** rename some variables ([#19179](https://github.com/taikoxyz/taiko-mono/issues/19179)) ([d2904d1](https://github.com/taikoxyz/taiko-mono/commit/d2904d1210a71a0d8b09b0bc5bb966c1d4ce899c))
* **taiko-client:** use `golang:1.24-alpine` in Dockerfile ([#19181](https://github.com/taikoxyz/taiko-mono/issues/19181)) ([8d786f0](https://github.com/taikoxyz/taiko-mono/commit/8d786f0399d0ee77af32a25a886d12920103f77f))


### Code Refactoring

* **taiko-client:** rename pivot verifier ([#19243](https://github.com/taikoxyz/taiko-mono/issues/19243)) ([f7e3e56](https://github.com/taikoxyz/taiko-mono/commit/f7e3e567a837ea9542fc0c3944ea670efb1ce9cb))


### Tests

* **taiko-client:** improve `TestTxPoolContentWithMinTip` ([#19175](https://github.com/taikoxyz/taiko-mono/issues/19175)) ([df605ec](https://github.com/taikoxyz/taiko-mono/commit/df605ec2a917c1b806aec0bf7ee80b838f66a9c6))

## [1.4.1](https://github.com/taikoxyz/taiko-mono/compare/taiko-alethia-client-v1.4.0...taiko-alethia-client-v1.4.1) (2025-03-27)


### Bug Fixes

* **taiko-client:** fix firstBlockID ([#19170](https://github.com/taikoxyz/taiko-mono/issues/19170)) ([d0feff0](https://github.com/taikoxyz/taiko-mono/commit/d0feff026f857944ab0bca0db6cdcd4d22371e8b))

## [1.4.0](https://github.com/taikoxyz/taiko-mono/compare/taiko-alethia-client-v1.3.2...taiko-alethia-client-v1.4.0) (2025-03-27)


### Features

* **taiko-client:** improve `checkLastVerifiedBlockMismatch` ([#19162](https://github.com/taikoxyz/taiko-mono/issues/19162)) ([e6bd2d3](https://github.com/taikoxyz/taiko-mono/commit/e6bd2d3bee1585c1b651c21af14bd8f2844d40af))
* **taiko-client:** improve `initL1Current` && guardian prover ([#19163](https://github.com/taikoxyz/taiko-mono/issues/19163)) ([acac81b](https://github.com/taikoxyz/taiko-mono/commit/acac81bd2167e0aef08c51c049e989ca39d5fb16))
* **taiko-client:** stop proposing when `taikoWrapper.preconfRouter` is set ([#19158](https://github.com/taikoxyz/taiko-mono/issues/19158)) ([c8afa87](https://github.com/taikoxyz/taiko-mono/commit/c8afa875029d52b94ecd8d0d40eb9b3bc0da7a7d))


### Bug Fixes

* **taiko-client:** fix a `firstBlockID` calculation issue ([#19168](https://github.com/taikoxyz/taiko-mono/issues/19168)) ([a24896f](https://github.com/taikoxyz/taiko-mono/commit/a24896fd30bacaa64e53adc2503d92a28cd42cd6))
* **taiko-client:** fix a bug in `syncer.checkReorg()` ([#19166](https://github.com/taikoxyz/taiko-mono/issues/19166)) ([f62e9d5](https://github.com/taikoxyz/taiko-mono/commit/f62e9d567b8894039b923a5d7167f5e5e059bb87))
* **taiko-client:** improve `checkL1Reorg` method ([#19161](https://github.com/taikoxyz/taiko-mono/issues/19161)) ([dedd3d0](https://github.com/taikoxyz/taiko-mono/commit/dedd3d08391ac78009c5d72d7d1b51e7dc372488))
* **taiko-client:** update splitToBlobs to use MaxBlobDataSize constant for proper data segmentation ([#19150](https://github.com/taikoxyz/taiko-mono/issues/19150)) ([97edb45](https://github.com/taikoxyz/taiko-mono/commit/97edb456942cde3acfbc81ee62594c3222a455a6))
* **taiko-client:** use blobHashes to get blobs from BlobDataSource & introduce `MaxBlobNums` ([#19167](https://github.com/taikoxyz/taiko-mono/issues/19167)) ([cdc9452](https://github.com/taikoxyz/taiko-mono/commit/cdc9452e29b04c2b6b273521b719a33a8a96be76))


### Chores

* **taiko-client:** update Go contract bindings ([#19157](https://github.com/taikoxyz/taiko-mono/issues/19157)) ([cb055bd](https://github.com/taikoxyz/taiko-mono/commit/cb055bd913476212061a8abce225a1018730e7e2))

## [1.3.2](https://github.com/taikoxyz/taiko-mono/compare/taiko-alethia-client-v1.3.1...taiko-alethia-client-v1.3.2) (2025-03-24)


### Bug Fixes

* **taiko-client:** buffer size & error check ([#19148](https://github.com/taikoxyz/taiko-mono/issues/19148)) ([f7eaea9](https://github.com/taikoxyz/taiko-mono/commit/f7eaea981888c0baae278fc448f12c9c90ec2833))
* **taiko-client:** disable zk proof aggregation for Ontake ([#19149](https://github.com/taikoxyz/taiko-mono/issues/19149)) ([51003fe](https://github.com/taikoxyz/taiko-mono/commit/51003fea5fe394fced61ff9c006da9c67a3dd42d))


### Tests

* **taiko-client:** add revert protection tests ([#19145](https://github.com/taikoxyz/taiko-mono/issues/19145)) ([71f3a82](https://github.com/taikoxyz/taiko-mono/commit/71f3a82fdd0bf56c6579ee089396e4591d83bf4c))

## [1.3.1](https://github.com/taikoxyz/taiko-mono/compare/taiko-alethia-client-v1.3.0...taiko-alethia-client-v1.3.1) (2025-03-24)


### Bug Fixes

* **taiko-client:** make `prover.sgx.batchSize` & `prover.zkvm.batchSize` not required ([#19139](https://github.com/taikoxyz/taiko-mono/issues/19139)) ([f714cf4](https://github.com/taikoxyz/taiko-mono/commit/f714cf429979b0829f8cbe721c08b30662c1af72))

## [1.3.0](https://github.com/taikoxyz/taiko-mono/compare/taiko-alethia-client-v1.2.0...taiko-alethia-client-v1.3.0) (2025-03-21)


### Features

* **taiko-client:** introduce `DecompressPacaya` ([#19137](https://github.com/taikoxyz/taiko-mono/issues/19137)) ([c266637](https://github.com/taikoxyz/taiko-mono/commit/c266637c04d6531288f53971b1dc95f452c75c51))

## [1.2.0](https://github.com/taikoxyz/taiko-mono/compare/taiko-alethia-client-v1.1.0...taiko-alethia-client-v1.2.0) (2025-03-21)


### Features

* **taiko-client:** make `prover.dummy` available for producer again ([#19135](https://github.com/taikoxyz/taiko-mono/issues/19135)) ([39cc71b](https://github.com/taikoxyz/taiko-mono/commit/39cc71bd5af022de6d168d79c220f256775d478b))

## [1.1.0](https://github.com/taikoxyz/taiko-mono/compare/taiko-alethia-client-v1.0.1...taiko-alethia-client-v1.1.0) (2025-03-20)


### Features

* **protocol:** propose a batch blocks conditionally ([#18570](https://github.com/taikoxyz/taiko-mono/issues/18570)) ([e846f62](https://github.com/taikoxyz/taiko-mono/commit/e846f6289fea0b046ddcfcdfaf46f3727efbdf11))
* **taiko-client:** add chain ID to `TryDecompress()` ([#18444](https://github.com/taikoxyz/taiko-mono/issues/18444)) ([10d99d5](https://github.com/taikoxyz/taiko-mono/commit/10d99d50d3866a6e233d9e3749ea5eb753335815))
* **taiko-client:** add preconf whitelist + update method to check operator ([#18978](https://github.com/taikoxyz/taiko-mono/issues/18978)) ([75db2c2](https://github.com/taikoxyz/taiko-mono/commit/75db2c2082e966b51f09680b8c558a7068a3e001))
* **taiko-client:** add proof type to batch proof acceptance log messages ([#18885](https://github.com/taikoxyz/taiko-mono/issues/18885)) ([cad42a7](https://github.com/taikoxyz/taiko-mono/commit/cad42a797ebc97f43950d19c704339df9beb189d))
* **taiko-client:** add two metrics for preconfirmation ([#19128](https://github.com/taikoxyz/taiko-mono/issues/19128)) ([37a330d](https://github.com/taikoxyz/taiko-mono/commit/37a330dff294fdfa4db5ea962a09337c2327a808))
* **taiko-client:** beacon-sync to the latest non-preconfirmed head ([#19029](https://github.com/taikoxyz/taiko-mono/issues/19029)) ([d2d1ae1](https://github.com/taikoxyz/taiko-mono/commit/d2d1ae1b1700a4b97fb5f770d03801de45369230))
* **taiko-client:** build blob transactions when gas estimation failed ([#18712](https://github.com/taikoxyz/taiko-mono/issues/18712)) ([6c0ef37](https://github.com/taikoxyz/taiko-mono/commit/6c0ef3706ebae8059b9ff554f45c2dcad00c0535))
* **taiko-client:** catch raiko deserialization errors ([#18644](https://github.com/taikoxyz/taiko-mono/issues/18644)) ([98a98fd](https://github.com/taikoxyz/taiko-mono/commit/98a98fd4636e3cd5f3ec019493a72880e141f494))
* **taiko-client:** changes based on `Pacaya` fork ([#18746](https://github.com/taikoxyz/taiko-mono/issues/18746)) ([02ae1cf](https://github.com/taikoxyz/taiko-mono/commit/02ae1cf7163331914a350f65b9ccaef0923ae904))
* **taiko-client:** changes based on `taiko-geth` [#391](https://github.com/taikoxyz/taiko-mono/issues/391) ([#18988](https://github.com/taikoxyz/taiko-mono/issues/18988)) ([c7e9bfb](https://github.com/taikoxyz/taiko-mono/commit/c7e9bfbd65f3d7515b66933d96a5c910ab00f82a))
* **taiko-client:** changes based on the protocol forced inclusion feature ([#18909](https://github.com/taikoxyz/taiko-mono/issues/18909)) ([d351788](https://github.com/taikoxyz/taiko-mono/commit/d35178843968b133cf228fe3a156b16ef3983bbe))
* **taiko-client:** changes for `meta.blobCreatedIn` ([#18960](https://github.com/taikoxyz/taiko-mono/issues/18960)) ([c0e0901](https://github.com/taikoxyz/taiko-mono/commit/c0e09018f094964560e9d76be6a9fcd91226ec30))
* **taiko-client:** check `p2pSigner` before gossiping ([#18981](https://github.com/taikoxyz/taiko-mono/issues/18981)) ([e14cad6](https://github.com/taikoxyz/taiko-mono/commit/e14cad6f0acb4eb8589a5789589907fe3e88699f))
* **taiko-client:** check if the block is preconfirmed before calling `setHead ` ([#18864](https://github.com/taikoxyz/taiko-mono/issues/18864)) ([ba15a6a](https://github.com/taikoxyz/taiko-mono/commit/ba15a6aae15b44b689dcf7583843dec965a80640))
* **taiko-client:** check whether a submitted Pacaya batch proof is valid ([#18892](https://github.com/taikoxyz/taiko-mono/issues/18892)) ([1ef6589](https://github.com/taikoxyz/taiko-mono/commit/1ef6589e8d4c38a6b75adcf33b0d66f9b13b8250))
* **taiko-client:** cherry-pick changes in [#19116](https://github.com/taikoxyz/taiko-mono/issues/19116) ([#19129](https://github.com/taikoxyz/taiko-mono/issues/19129)) ([4f2a9fd](https://github.com/taikoxyz/taiko-mono/commit/4f2a9fdf7188c145968636bd4035d793a16a2763))
* **taiko-client:** client changes based on [#18150](https://github.com/taikoxyz/taiko-mono/issues/18150) ([#18350](https://github.com/taikoxyz/taiko-mono/issues/18350)) ([ddc6473](https://github.com/taikoxyz/taiko-mono/commit/ddc647327e8d58f5a2def5b902ad06800982544b))
* **taiko-client:** compatible changes for `lastProposedIn` ([#18442](https://github.com/taikoxyz/taiko-mono/issues/18442)) ([28f32a7](https://github.com/taikoxyz/taiko-mono/commit/28f32a790cc680ecb3e6345221e4183af4f34b2e))
* **taiko-client:** delete socialScan endpoint in driver  ([#19047](https://github.com/taikoxyz/taiko-mono/issues/19047)) ([ce5bcca](https://github.com/taikoxyz/taiko-mono/commit/ce5bcca7d2f94105c9dabdf2e644a29f1baf7b4d))
* **taiko-client:** enable proof aggregation (batch proofs) ([#18163](https://github.com/taikoxyz/taiko-mono/issues/18163)) ([7642961](https://github.com/taikoxyz/taiko-mono/commit/7642961a9031840183f4d00d0a4c19fdb8a68058))
* **taiko-client:** ensure the preconfirmation block number is greater than canonical head ([#19030](https://github.com/taikoxyz/taiko-mono/issues/19030)) ([044416b](https://github.com/taikoxyz/taiko-mono/commit/044416be6453de41e3e058da4c15cc9544c682e9))
* **taiko-client:** handle `blobParam.CreatedIn` being 0 ([#18974](https://github.com/taikoxyz/taiko-mono/issues/18974)) ([6c98bbf](https://github.com/taikoxyz/taiko-mono/commit/6c98bbf7edd73ee252c73096b131f0fc5b303a21))
* **taiko-client:** implement `PreconfGossipRuntimeConfig` interface for `PreconfBlockAPIServer` ([#19021](https://github.com/taikoxyz/taiko-mono/issues/19021)) ([856fe9c](https://github.com/taikoxyz/taiko-mono/commit/856fe9c061494551752f2ac8e24cc7a553b4b911))
* **taiko-client:** improve `P2PSequencerAddresses` ([#19024](https://github.com/taikoxyz/taiko-mono/issues/19024)) ([4999e12](https://github.com/taikoxyz/taiko-mono/commit/4999e123017d65e06d64254d6ed62f1da06ff1d6))
* **taiko-client:** improve `ProofBuffer` ([#18627](https://github.com/taikoxyz/taiko-mono/issues/18627)) ([c386589](https://github.com/taikoxyz/taiko-mono/commit/c3865896523712afa108be810e75b511e7ecc0c4))
* **taiko-client:** improve Pacaya proof submitter ([#19085](https://github.com/taikoxyz/taiko-mono/issues/19085)) ([8247754](https://github.com/taikoxyz/taiko-mono/commit/8247754a9668ce7a567329514d98d0693b0a0649))
* **taiko-client:** include `ParentMetaHash` for proposing Ontake blocks for better revert protection ([#18970](https://github.com/taikoxyz/taiko-mono/issues/18970)) ([16bbe5f](https://github.com/taikoxyz/taiko-mono/commit/16bbe5f85f2ae7c3b596211081684048f5834809))
* **taiko-client:** init proving workflow for pacaya ([#18992](https://github.com/taikoxyz/taiko-mono/issues/18992)) ([68b662a](https://github.com/taikoxyz/taiko-mono/commit/68b662a7e853cc9d07d371588fd818e286e2fad1))
* **taiko-client:** introduce `AnchorV3GasLimit` ([#18902](https://github.com/taikoxyz/taiko-mono/issues/18902)) ([cdeadc0](https://github.com/taikoxyz/taiko-mono/commit/cdeadc09401ed8f1dab4588c4296a46af68d73a6))
* **taiko-client:** introduce `TaikoL2.GetBasefeeV2` ([#18660](https://github.com/taikoxyz/taiko-mono/issues/18660)) ([4abfaa9](https://github.com/taikoxyz/taiko-mono/commit/4abfaa9e28a619c1edfa82548a00eae0790f784b))
* **taiko-client:** introduce `TxBuilderWithFallback` ([#18690](https://github.com/taikoxyz/taiko-mono/issues/18690)) ([f1d7b20](https://github.com/taikoxyz/taiko-mono/commit/f1d7b20b722b1e15db3f3f2953c8afb89287537f))
* **taiko-client:** lookahead cache && account for missed slots ([#19052](https://github.com/taikoxyz/taiko-mono/issues/19052)) ([0fcf70e](https://github.com/taikoxyz/taiko-mono/commit/0fcf70e4d02d859758b8a0e7c8f9fa34ac0a122e))
* **taiko-client:** make `--l1.beacon` required for driver ([#19097](https://github.com/taikoxyz/taiko-mono/issues/19097)) ([714c4a8](https://github.com/taikoxyz/taiko-mono/commit/714c4a8b527cbadd6b0565612f3ba5b7a36c8cad))
* **taiko-client:** make p2p-sync required ([#18571](https://github.com/taikoxyz/taiko-mono/issues/18571)) ([de92b28](https://github.com/taikoxyz/taiko-mono/commit/de92b28c03b747845a8a1aa26991307d1ed47fd0))
* **taiko-client:** move `numTransactions` and `timestamp` to blobs ([#19003](https://github.com/taikoxyz/taiko-mono/issues/19003)) ([e5c0bfb](https://github.com/taikoxyz/taiko-mono/commit/e5c0bfb33464a7539ed31c1be419eb16833e45c9))
* **taiko-client:** only check and trigger P2P sync progress right after starting ([#18745](https://github.com/taikoxyz/taiko-mono/issues/18745)) ([a05e4c9](https://github.com/taikoxyz/taiko-mono/commit/a05e4c99bbcfd5f6f6e37b4222616e40b31cfbaf))
* **taiko-client:** optimize aggregation logging again ([#18643](https://github.com/taikoxyz/taiko-mono/issues/18643)) ([688a426](https://github.com/taikoxyz/taiko-mono/commit/688a42646d185694c7cfd2bc091084dd782782f5))
* **taiko-client:** remove an unused flag for proposer ([#18709](https://github.com/taikoxyz/taiko-mono/issues/18709)) ([6fb1fd2](https://github.com/taikoxyz/taiko-mono/commit/6fb1fd25696a5251d864e8869c4a360e9915d787))
* **taiko-client:** remove an unused package ([#18668](https://github.com/taikoxyz/taiko-mono/issues/18668)) ([e1af55a](https://github.com/taikoxyz/taiko-mono/commit/e1af55abcf99ba4a1de6cc22072a457f45ad55be))
* **taiko-client:** remove signature verification in `PreconfBlockAPIServer.BuildPreconfBlock` ([#19042](https://github.com/taikoxyz/taiko-mono/issues/19042)) ([867f6c1](https://github.com/taikoxyz/taiko-mono/commit/867f6c1d724a909700cdf81155808e8551c82b71))
* **taiko-client:** remove soft blocks implementation ([#18744](https://github.com/taikoxyz/taiko-mono/issues/18744)) ([f645b23](https://github.com/taikoxyz/taiko-mono/commit/f645b23ae11bf5df9b5199d9a683d6b9f2c12d4b))
* **taiko-client:** revert changes based on `taiko-geth` [#391](https://github.com/taikoxyz/taiko-mono/issues/391) ([#19025](https://github.com/taikoxyz/taiko-mono/issues/19025)) ([aacccbb](https://github.com/taikoxyz/taiko-mono/commit/aacccbb4cfd35f5f563b12f97f4130d5d0f3dcf8))
* **taiko-client:** revert hardcode config and `ComposeVerifier` from flag ([#19126](https://github.com/taikoxyz/taiko-mono/issues/19126)) ([1e74a14](https://github.com/taikoxyz/taiko-mono/commit/1e74a146e0590c636c2caddbad950f82435e40d5))
* **taiko-client:** revert pr 18442 ([#18450](https://github.com/taikoxyz/taiko-mono/issues/18450)) ([0706f0a](https://github.com/taikoxyz/taiko-mono/commit/0706f0aee9c318d8de298f98480a46de6337937c))
* **taiko-client:** revert pr-18571 ([#18648](https://github.com/taikoxyz/taiko-mono/issues/18648)) ([842f812](https://github.com/taikoxyz/taiko-mono/commit/842f8122305f8cbf3153bb645e3107abb4af3cf4))
* **taiko-client:** revert protocol `timestamp` related changes ([#19016](https://github.com/taikoxyz/taiko-mono/issues/19016)) ([ba59d6b](https://github.com/taikoxyz/taiko-mono/commit/ba59d6bb6eaceeb5a460ce9633afeff9c2e432bc))
* **taiko-client:** soft block driver APIs ([#18273](https://github.com/taikoxyz/taiko-mono/issues/18273)) ([9fff7ff](https://github.com/taikoxyz/taiko-mono/commit/9fff7ff3cce99e915e8142a090a7fad2f1af5bd4))
* **taiko-client:** try aggregating Ontake proofs at first in `aggregateOpPacaya` ([#19104](https://github.com/taikoxyz/taiko-mono/issues/19104)) ([3bb0f79](https://github.com/taikoxyz/taiko-mono/commit/3bb0f796a0ab993a6e3dc47823d65ac81a279c97))
* **taiko-client:** update `OntakeForkHeight` in mainnet ([#18253](https://github.com/taikoxyz/taiko-mono/issues/18253)) ([21c6235](https://github.com/taikoxyz/taiko-mono/commit/21c62355575adae6d99e1a117f357c6429d79b4c))
* **taiko-client:** update Go contract bindings ([#18381](https://github.com/taikoxyz/taiko-mono/issues/18381)) ([71cfc5c](https://github.com/taikoxyz/taiko-mono/commit/71cfc5ce1ef06dcf099a4ce9b22bea6100406148))
* **taiko-client:** update Go contract bindings ([#18384](https://github.com/taikoxyz/taiko-mono/issues/18384)) ([8dd14a1](https://github.com/taikoxyz/taiko-mono/commit/8dd14a1b4b21ce77ed3aac935b1d2c950e11e729))
* **taiko-client:** update Go contract bindings ([#18462](https://github.com/taikoxyz/taiko-mono/issues/18462)) ([bc0ee99](https://github.com/taikoxyz/taiko-mono/commit/bc0ee9952234cc6722d3a0e9d9ebd92bca706999))
* **taiko-client:** use Keccak256 for packing difficulty calculation ([#18923](https://github.com/taikoxyz/taiko-mono/issues/18923)) ([afb15b7](https://github.com/taikoxyz/taiko-mono/commit/afb15b766270cce49dc5b34a747dbb3699b77e06))
* **taiko-client:** zk any for ontake fork ([#18922](https://github.com/taikoxyz/taiko-mono/issues/18922)) ([3679bc5](https://github.com/taikoxyz/taiko-mono/commit/3679bc58c8fe915e6b16b983d702e9362f238a27))


### Bug Fixes

* **protocol:** fix issue in mainnet deployment script ([#18283](https://github.com/taikoxyz/taiko-mono/issues/18283)) ([5c371a1](https://github.com/taikoxyz/taiko-mono/commit/5c371a181af444999f611e03774ec096ffbd1226))
* **taiko-client:** add [#18442](https://github.com/taikoxyz/taiko-mono/issues/18442) back ([#18685](https://github.com/taikoxyz/taiko-mono/issues/18685)) ([abc0554](https://github.com/taikoxyz/taiko-mono/commit/abc0554eb0b0a640a8b1a4e9762f7d691b089d40))
* **taiko-client:** add all rest transactions into payload ([#18931](https://github.com/taikoxyz/taiko-mono/issues/18931)) ([18b7205](https://github.com/taikoxyz/taiko-mono/commit/18b7205877bc073529f611caa940dedf3a7857c0))
* **taiko-client:** add timestamp as a new parameter to getBasefeeV2 ([#18691](https://github.com/taikoxyz/taiko-mono/issues/18691)) ([4a4d908](https://github.com/taikoxyz/taiko-mono/commit/4a4d908b0290046d1098d943a9ebc685c7ca533e))
* **taiko-client:** check if preconfirmation whitelist address is set before fetching it ([#18982](https://github.com/taikoxyz/taiko-mono/issues/18982)) ([1883e05](https://github.com/taikoxyz/taiko-mono/commit/1883e050ca0dc64a7e9fecf8628c71cd5fd23ac1))
* **taiko-client:** check inner iterator errors in `BlockProposedIterator` ([#18757](https://github.com/taikoxyz/taiko-mono/issues/18757)) ([404efcc](https://github.com/taikoxyz/taiko-mono/commit/404efcc0ad7c5494635a53df94ea72108fa69bf2))
* **taiko-client:** check the `blockID` of the last verified block before using it as `FinalizedBlockHash` ([#18739](https://github.com/taikoxyz/taiko-mono/issues/18739)) ([8c364b1](https://github.com/taikoxyz/taiko-mono/commit/8c364b1f493cfda2823e3efc49ec0e8a8985884a))
* **taiko-client:** decompress transactions list before inserting the preconfirmation blocks ([#18977](https://github.com/taikoxyz/taiko-mono/issues/18977)) ([5e3704d](https://github.com/taikoxyz/taiko-mono/commit/5e3704dfb3c85a4f2c227719b3859cd127ae8a13))
* **taiko-client:** fix `GetBasefeeV2` usage ([#18664](https://github.com/taikoxyz/taiko-mono/issues/18664)) ([03537c7](https://github.com/taikoxyz/taiko-mono/commit/03537c7d86700427976da556fed88ea4df5299d7))
* **taiko-client:** fix `lastVerifiedBlockHash` fetch ([#18277](https://github.com/taikoxyz/taiko-mono/issues/18277)) ([8512f45](https://github.com/taikoxyz/taiko-mono/commit/8512f456f033130ecb0e5493a3c36be025908228))
* **taiko-client:** fix `PayloadAttributes.GasLimit` for Pacaya blocks ([#18912](https://github.com/taikoxyz/taiko-mono/issues/18912)) ([a01785d](https://github.com/taikoxyz/taiko-mono/commit/a01785d1efca5ab0b4383555749db90dd7653fcd))
* **taiko-client:** fix a checking issue about `--l1.beacon` flag value check ([#19127](https://github.com/taikoxyz/taiko-mono/issues/19127)) ([a7ce246](https://github.com/taikoxyz/taiko-mono/commit/a7ce246a3e9f39ad76aeba56c8f354b291246e20))
* **taiko-client:** fix an issue for Pacaya block `TimeShift`  ([#18962](https://github.com/taikoxyz/taiko-mono/issues/18962)) ([500b366](https://github.com/taikoxyz/taiko-mono/commit/500b3665c7322c4ed878078536c5e6f52b5ed3e6))
* **taiko-client:** fix blob transactions estimation when proposing ([#18703](https://github.com/taikoxyz/taiko-mono/issues/18703)) ([395ac5f](https://github.com/taikoxyz/taiko-mono/commit/395ac5fdfb0d8eccae96fafda423d19766a94556))
* **taiko-client:** fix bug about nil interface check ([#18886](https://github.com/taikoxyz/taiko-mono/issues/18886)) ([645f0a0](https://github.com/taikoxyz/taiko-mono/commit/645f0a005683040a2730a3a5ac517f86f4866104))
* **taiko-client:** fix errors discovered in testing the upgrade from Ontake to Pacaya ([#19096](https://github.com/taikoxyz/taiko-mono/issues/19096)) ([54aed0b](https://github.com/taikoxyz/taiko-mono/commit/54aed0b3ea06bf89c6ba2fa4176bb0adae944be9))
* **taiko-client:** fix path parsing in `/eth/v1/config/spec` ([#18295](https://github.com/taikoxyz/taiko-mono/issues/18295)) ([6633c80](https://github.com/taikoxyz/taiko-mono/commit/6633c80fbcabb6f06ce5467501da4207bc84be84))
* **taiko-client:** fix proposing fee estimation ([#18702](https://github.com/taikoxyz/taiko-mono/issues/18702)) ([13a5b1b](https://github.com/taikoxyz/taiko-mono/commit/13a5b1b50e0bf9f030449af49cb0b58ce4288729))
* **taiko-client:** fix README link ([#18995](https://github.com/taikoxyz/taiko-mono/issues/18995)) ([b3f3e32](https://github.com/taikoxyz/taiko-mono/commit/b3f3e327e325ab469385508b18ac2f2d07bf715c))
* **taiko-client:** fix the workflow to get `proof_verifier` ([#18936](https://github.com/taikoxyz/taiko-mono/issues/18936)) ([0d97116](https://github.com/taikoxyz/taiko-mono/commit/0d9711614a5a67e49dc129e4a21d82ad231eb4b2))
* **taiko-client:** fix timestamp lower bound ([#19009](https://github.com/taikoxyz/taiko-mono/issues/19009)) ([0bae0af](https://github.com/taikoxyz/taiko-mono/commit/0bae0af865b591e935ac29eb4b10d59824944005))
* **taiko-client:** remove `finalizedBlock` info when P2P syncing ([#18735](https://github.com/taikoxyz/taiko-mono/issues/18735)) ([d81a630](https://github.com/taikoxyz/taiko-mono/commit/d81a6309c2e303eca57238c4e252b93083a55d2f))
* **taiko-client:** remove ontake info in log to avoid panic ([#18878](https://github.com/taikoxyz/taiko-mono/issues/18878)) ([4a9202f](https://github.com/taikoxyz/taiko-mono/commit/4a9202fffac67f14678a34daac6b0e6050fe7f64))
* **taiko-client:** remove the rest of signature check ([#19044](https://github.com/taikoxyz/taiko-mono/issues/19044)) ([b051d6c](https://github.com/taikoxyz/taiko-mono/commit/b051d6caa45a9db44b24a927e4c792f3ee72da57))
* **taiko-client:** remove unused param when inserting blocks ([#18968](https://github.com/taikoxyz/taiko-mono/issues/18968)) ([b8235ab](https://github.com/taikoxyz/taiko-mono/commit/b8235ab0758b1a58cb9c5146e8a52eacfe039a89))
* **taiko-client:** revert `tracker.triggered` related changes ([#18737](https://github.com/taikoxyz/taiko-mono/issues/18737)) ([e76d865](https://github.com/taikoxyz/taiko-mono/commit/e76d865a3f482b6165f2b7cc5bb0f4a5065b3bc2))
* **taiko-client:** set p2p node, taiko flag, update optimism lib ([#18920](https://github.com/taikoxyz/taiko-mono/issues/18920)) ([245b7ce](https://github.com/taikoxyz/taiko-mono/commit/245b7ce2e77e07ae08e58e11c05eab5b60e56614))
* **taiko-client:** skip `headL1Origin` check when chain only has the genesis block ([#19043](https://github.com/taikoxyz/taiko-mono/issues/19043)) ([edb2514](https://github.com/taikoxyz/taiko-mono/commit/edb2514e1bed3de681df5d9d19218bfebeda189d))
* **taiko-client:** update `op-lib`, don't return from `lookahead` ([#19098](https://github.com/taikoxyz/taiko-mono/issues/19098)) ([32ebc75](https://github.com/taikoxyz/taiko-mono/commit/32ebc75d0f7957447d41925adab5fcce8adce937))
* **taiko-client:** use bytes type that supports hex string unmarshalling on `ExecutableData` ([#18946](https://github.com/taikoxyz/taiko-mono/issues/18946)) ([848a097](https://github.com/taikoxyz/taiko-mono/commit/848a09762cf2ad1e22ed37cf7b8b4ab77b2eece0))
* **taiko-client:** use Pacaya abi for prover set ([#18893](https://github.com/taikoxyz/taiko-mono/issues/18893)) ([30428c2](https://github.com/taikoxyz/taiko-mono/commit/30428c20a2d6486d1789f42c1786ce34d3e77b26))
* **taiko-client:** valid status check in `BatchGetBlocksProofStatus` ([#18595](https://github.com/taikoxyz/taiko-mono/issues/18595)) ([ec5f599](https://github.com/taikoxyz/taiko-mono/commit/ec5f5999750f70efe58cc061c5856250dcef5ce2))


### Chores

* **main:** release taiko-alethia-client 0.41.0 ([#18655](https://github.com/taikoxyz/taiko-mono/issues/18655)) ([7ff64a4](https://github.com/taikoxyz/taiko-mono/commit/7ff64a41bba9a1a0b43ba4bff8cc31cb56c92b88))
* **main:** release taiko-alethia-client 0.41.1 ([#18673](https://github.com/taikoxyz/taiko-mono/issues/18673)) ([e0e1c4c](https://github.com/taikoxyz/taiko-mono/commit/e0e1c4c1caca323ea5846938575b12bd070bcfa8))
* **main:** release taiko-alethia-client 0.42.0 ([#18676](https://github.com/taikoxyz/taiko-mono/issues/18676)) ([43163d8](https://github.com/taikoxyz/taiko-mono/commit/43163d83f5adc2b04fe544a6ae6b0aac71d819c0))
* **main:** release taiko-alethia-client 0.42.1 ([#18720](https://github.com/taikoxyz/taiko-mono/issues/18720)) ([6356cd2](https://github.com/taikoxyz/taiko-mono/commit/6356cd2be89685bdcdf45c10a053f25aa8de074a))
* **main:** release taiko-alethia-client 0.43.0 ([#18729](https://github.com/taikoxyz/taiko-mono/issues/18729)) ([a525b2b](https://github.com/taikoxyz/taiko-mono/commit/a525b2b36b83f65465530566ab8ff47b2ba9c2a1))
* **main:** release taiko-alethia-client 0.43.1 ([#18773](https://github.com/taikoxyz/taiko-mono/issues/18773)) ([076f5f0](https://github.com/taikoxyz/taiko-mono/commit/076f5f0a3f3aca7852965999eabdc3ebd91142ed))
* **main:** release taiko-client 0.39.0 ([#18247](https://github.com/taikoxyz/taiko-mono/issues/18247)) ([be08e8b](https://github.com/taikoxyz/taiko-mono/commit/be08e8b846f798bb8259bfa0ae73bd729a5aaf79))
* **main:** release taiko-client 0.39.1 ([#18278](https://github.com/taikoxyz/taiko-mono/issues/18278)) ([191480d](https://github.com/taikoxyz/taiko-mono/commit/191480d06159951aa6db0c550a0cc576917a7935))
* **main:** release taiko-client 0.39.2 ([#18284](https://github.com/taikoxyz/taiko-mono/issues/18284)) ([52a9362](https://github.com/taikoxyz/taiko-mono/commit/52a936299487ee4db83e88ba740aec025561a2b9))
* **main:** release taiko-client 0.40.0 ([#18436](https://github.com/taikoxyz/taiko-mono/issues/18436)) ([2a82c94](https://github.com/taikoxyz/taiko-mono/commit/2a82c945a2f6436a36f393105621bb011d8a4325))
* **repo:** fix broken links ([#18635](https://github.com/taikoxyz/taiko-mono/issues/18635)) ([8e53a6e](https://github.com/taikoxyz/taiko-mono/commit/8e53a6e6a2654b8a599fe1df187e2fd88c22d96e))
* **repo:** fix link in taiko client README ([#18868](https://github.com/taikoxyz/taiko-mono/issues/18868)) ([d9be36c](https://github.com/taikoxyz/taiko-mono/commit/d9be36cc7be284ee598f871db7ad5cda12ffec1e))
* **taiko-client:** add `BaseFeeConfig.SharingPctg` to mainnet protocol config ([#18341](https://github.com/taikoxyz/taiko-mono/issues/18341)) ([75d14a7](https://github.com/taikoxyz/taiko-mono/commit/75d14a7afac83b4578a3c32456a28ae70373d5cb))
* **taiko-client:** add more logs for `BlockProposedIterator` ([#18772](https://github.com/taikoxyz/taiko-mono/issues/18772)) ([1b02bc0](https://github.com/taikoxyz/taiko-mono/commit/1b02bc08b5e87b66e1645e139a4804ec433cf2dd))
* **taiko-client:** add more metrics for `TxBuilderWithFallback` ([#18711](https://github.com/taikoxyz/taiko-mono/issues/18711)) ([b62d390](https://github.com/taikoxyz/taiko-mono/commit/b62d3906a650d8b58ad1d45b068638823ce05121))
* **taiko-client:** add more proof generation metrics ([#18715](https://github.com/taikoxyz/taiko-mono/issues/18715)) ([ae07365](https://github.com/taikoxyz/taiko-mono/commit/ae07365e560c51bcc197335d0ac0ba61964f0b49))
* **taiko-client:** add softBlock server start log ([#18731](https://github.com/taikoxyz/taiko-mono/issues/18731)) ([23594ff](https://github.com/taikoxyz/taiko-mono/commit/23594ff2e44f51b0409c76368429d2c3a156a802))
* **taiko-client:** always use `blockID` instead of `height` for L2 blocks in logs ([#18719](https://github.com/taikoxyz/taiko-mono/issues/18719)) ([a02b96d](https://github.com/taikoxyz/taiko-mono/commit/a02b96d609b17070fd0b071127d84c21e1f3a8ef))
* **taiko-client:** bump `taiko-geth` dep ([#18730](https://github.com/taikoxyz/taiko-mono/issues/18730)) ([554f679](https://github.com/taikoxyz/taiko-mono/commit/554f679b01199da363587adee0ec88a0c1846483))
* **taiko-client:** change `SetHeadL1Origin` && `UpdateL1Origin` to `taikoauth_` namespace ([#18950](https://github.com/taikoxyz/taiko-mono/issues/18950)) ([f314d6d](https://github.com/taikoxyz/taiko-mono/commit/f314d6d15b179c152dfaad6ea3542a059a7afd45))
* **taiko-client:** change back to use `taiko-geth:taiko` image in tests ([#19099](https://github.com/taikoxyz/taiko-mono/issues/19099)) ([0becea7](https://github.com/taikoxyz/taiko-mono/commit/0becea74fa7da45824992abbc5c4b1e54b222c16))
* **taiko-client:** changes based on `taiko-geth` upstream merge ([#19057](https://github.com/taikoxyz/taiko-mono/issues/19057)) ([304e98b](https://github.com/taikoxyz/taiko-mono/commit/304e98be7571785dbbf38bc46d3af9ce787db90f))
* **taiko-client:** cleanup pre-ontake proposer code ([#18672](https://github.com/taikoxyz/taiko-mono/issues/18672)) ([a52d9a7](https://github.com/taikoxyz/taiko-mono/commit/a52d9a79bb99027061f4719a62361157365a5625))
* **taiko-client:** cleanup pre-ontake prover code ([#18677](https://github.com/taikoxyz/taiko-mono/issues/18677)) ([fef6884](https://github.com/taikoxyz/taiko-mono/commit/fef6884bc318e4f09d9c59930a0565cc15e25996))
* **taiko-client:** cleanup some unused variables in `bindings` package ([#18752](https://github.com/taikoxyz/taiko-mono/issues/18752)) ([13ccc54](https://github.com/taikoxyz/taiko-mono/commit/13ccc5466e40422b971f426661f3d7adef8d3d17))
* **taiko-client:** deduplicate `compress()` function ([#18958](https://github.com/taikoxyz/taiko-mono/issues/18958)) ([ddfa310](https://github.com/taikoxyz/taiko-mono/commit/ddfa31096f0ae6d3f9506b591de25064f1d4ef1c))
* **taiko-client:** ensure event block IDs are continuous ([#18775](https://github.com/taikoxyz/taiko-mono/issues/18775)) ([b359be0](https://github.com/taikoxyz/taiko-mono/commit/b359be028cdd19f3b40ed414f641ea799a2fe055))
* **taiko-client:** export encoding parameters ([#18942](https://github.com/taikoxyz/taiko-mono/issues/18942)) ([0ea6104](https://github.com/taikoxyz/taiko-mono/commit/0ea61049d40676c3da646b5110f27e79603b307d))
* **taiko-client:** fix docs ([#18698](https://github.com/taikoxyz/taiko-mono/issues/18698)) ([fc545ee](https://github.com/taikoxyz/taiko-mono/commit/fc545ee89fd907a20161195ef174e7d96d4beae3))
* **taiko-client:** improve `BlobFetcher` ([#18786](https://github.com/taikoxyz/taiko-mono/issues/18786)) ([fc32df8](https://github.com/taikoxyz/taiko-mono/commit/fc32df89baf5838092d3bbea8c2babee304a4c8d))
* **taiko-client:** improve `proofBuffer` logs ([#18669](https://github.com/taikoxyz/taiko-mono/issues/18669)) ([3b0d786](https://github.com/taikoxyz/taiko-mono/commit/3b0d786fe42205394a8a293aa6e5913e158323c4))
* **taiko-client:** improve `TxBuilderWithFallback` logs ([#18738](https://github.com/taikoxyz/taiko-mono/issues/18738)) ([01ebba3](https://github.com/taikoxyz/taiko-mono/commit/01ebba3a61d0bbd8251bed1f91b09b9abfcc99c7))
* **taiko-client:** improve proposer gas estimation ([#18727](https://github.com/taikoxyz/taiko-mono/issues/18727)) ([6aed5b3](https://github.com/taikoxyz/taiko-mono/commit/6aed5b3bc5f46e089784405133fcf83c6befe495))
* **taiko-client:** improve prover logs ([#18718](https://github.com/taikoxyz/taiko-mono/issues/18718)) ([3246071](https://github.com/taikoxyz/taiko-mono/commit/32460713052351789f3d7b452ccd0251a000e2f8))
* **taiko-client:** make full sync to sync to the latest header ([#18771](https://github.com/taikoxyz/taiko-mono/issues/18771)) ([65f763b](https://github.com/taikoxyz/taiko-mono/commit/65f763b5629c75056abc49e824e1bb5536d7cd4e))
* **taiko-client:** more cost estimation metrics ([#18713](https://github.com/taikoxyz/taiko-mono/issues/18713)) ([b9bd6ea](https://github.com/taikoxyz/taiko-mono/commit/b9bd6ea479da8943b96ddca00a3bbb0e8148774c))
* **taiko-client:** more logs for `BlockBatchIterator` ([#18774](https://github.com/taikoxyz/taiko-mono/issues/18774)) ([3945f60](https://github.com/taikoxyz/taiko-mono/commit/3945f60171e2733a0888e7bde914634dfa260958))
* **taiko-client:** optimize logging ([#18674](https://github.com/taikoxyz/taiko-mono/issues/18674)) ([60bda60](https://github.com/taikoxyz/taiko-mono/commit/60bda60df922e5dd04f6186f8a67d7cb56351c6d))
* **taiko-client:** optimize proof generation logs ([#19007](https://github.com/taikoxyz/taiko-mono/issues/19007)) ([ce6df2b](https://github.com/taikoxyz/taiko-mono/commit/ce6df2b2161fb2455c0de7bc88c4a921fcfa0b04))
* **taiko-client:** remove an unused argument in `NewProofSubmitterPacaya` ([#18890](https://github.com/taikoxyz/taiko-mono/issues/18890)) ([16d2817](https://github.com/taikoxyz/taiko-mono/commit/16d2817d30a0f0015d63273429abfa2461c57f73))
* **taiko-client:** remove some unused flags ([#18678](https://github.com/taikoxyz/taiko-mono/issues/18678)) ([63f9d26](https://github.com/taikoxyz/taiko-mono/commit/63f9d26b42518a995e093d7db6bc43ef3b57ecca))
* **taiko-client:** rename `io.EOF` in iterators ([#18777](https://github.com/taikoxyz/taiko-mono/issues/18777)) ([c634425](https://github.com/taikoxyz/taiko-mono/commit/c6344250bcbfe9acfae84fcbd003a7bfefe24146))
* **taiko-client:** update CI badge and path ([#18441](https://github.com/taikoxyz/taiko-mono/issues/18441)) ([6aef03e](https://github.com/taikoxyz/taiko-mono/commit/6aef03e87eaf3cdbfb7637bd6122525f75c611f0))
* **taiko-client:** update docker-compose config ([#18330](https://github.com/taikoxyz/taiko-mono/issues/18330)) ([74e4ca4](https://github.com/taikoxyz/taiko-mono/commit/74e4ca4aaef07af4958a7b61c95e385022b1cf3c))
* **taiko-client:** update Go contract bindings ([#18882](https://github.com/taikoxyz/taiko-mono/issues/18882)) ([d8fa41f](https://github.com/taikoxyz/taiko-mono/commit/d8fa41fcbd9c759b5868667ac545730f04358480))
* **taiko-client:** update Go contract bindings ([#18930](https://github.com/taikoxyz/taiko-mono/issues/18930)) ([c420ba2](https://github.com/taikoxyz/taiko-mono/commit/c420ba294ad1c81ca42e24d9a4a5b1aaacee2282))
* **taiko-client:** update Go contract bindings ([#18934](https://github.com/taikoxyz/taiko-mono/issues/18934)) ([d9fb5b1](https://github.com/taikoxyz/taiko-mono/commit/d9fb5b165ffc6cf23eac177db56d6f5029630f32))
* **taiko-client:** update Go contract bindings generation script ([#18324](https://github.com/taikoxyz/taiko-mono/issues/18324)) ([4f698a0](https://github.com/taikoxyz/taiko-mono/commit/4f698a02bb1714caf527629a637323a9964cdb11))
* **taiko-client:** update Hekla Pacaya fork height ([#19130](https://github.com/taikoxyz/taiko-mono/issues/19130)) ([6206411](https://github.com/taikoxyz/taiko-mono/commit/620641166a82f0befaf2e07da2cafc6d6a6affaa))
* **taiko-client:** update some comments ([#18908](https://github.com/taikoxyz/taiko-mono/issues/18908)) ([45b3055](https://github.com/taikoxyz/taiko-mono/commit/45b30552678d86b787bfab627311d0f1b86e5c61))
* **taiko-client:** use `EncodeAndCompressTxList()` instead of `EncodeToBytes()` then `Compress()` ([#18972](https://github.com/taikoxyz/taiko-mono/issues/18972)) ([05e43ab](https://github.com/taikoxyz/taiko-mono/commit/05e43ab2322c4d0c45877a6ae634e1327cc70227))


### Documentation

* **taiko-client:** update readme how to do integration test ([#18256](https://github.com/taikoxyz/taiko-mono/issues/18256)) ([b12b32e](https://github.com/taikoxyz/taiko-mono/commit/b12b32e92b5803f15047a6da2b73135f12b9406d))


### Code Refactoring

* **taiko-client:** improve `ProofSubmitterPacaya` ([#19115](https://github.com/taikoxyz/taiko-mono/issues/19115)) ([c96e676](https://github.com/taikoxyz/taiko-mono/commit/c96e676862bbc6d9c1ba6b472c2adc8ede9f92fd))
* **taiko-client:** introduce `requestHttpProof` to remove duplicated code in `proofProducer` package ([#19106](https://github.com/taikoxyz/taiko-mono/issues/19106)) ([19e0243](https://github.com/taikoxyz/taiko-mono/commit/19e0243e7f38b81607090653843f43325c2aeda8))
* **taiko-client:** move `utils` package from `internal/` to `pkg/`  ([#18516](https://github.com/taikoxyz/taiko-mono/issues/18516)) ([b674857](https://github.com/taikoxyz/taiko-mono/commit/b67485732832fb90849179a7a8c8093f2228eb5a))
* **taiko-client:** remove duplicated code for getting verifiers ([#19119](https://github.com/taikoxyz/taiko-mono/issues/19119)) ([02ef8b7](https://github.com/taikoxyz/taiko-mono/commit/02ef8b7f8687da58b278b9f972a69b22f62b18bc))
* **taiko-client:** remove duplicated code for raiko response validation ([#19124](https://github.com/taikoxyz/taiko-mono/issues/19124)) ([4f57537](https://github.com/taikoxyz/taiko-mono/commit/4f5753780a3853baa14700c021ab185611efe09d))
* **taiko-client:** remove duplicated code in `proofProducer` ([#19123](https://github.com/taikoxyz/taiko-mono/issues/19123)) ([c806615](https://github.com/taikoxyz/taiko-mono/commit/c8066151fa2f18679818232b13a32a13d6fd475b))


### Tests

* **taiko-client:** add more fallback proposing tests ([#18705](https://github.com/taikoxyz/taiko-mono/issues/18705)) ([0e8ef0d](https://github.com/taikoxyz/taiko-mono/commit/0e8ef0d6df36cc05956574b38dabdbbd83f7ce5a))
* **taiko-client:** add more preconfirmation P2P network tests ([#18944](https://github.com/taikoxyz/taiko-mono/issues/18944)) ([3f52b11](https://github.com/taikoxyz/taiko-mono/commit/3f52b1164a845630a2c8de1e5847f823663096fd))
* **taiko-client:** add multi-blobs tests for proposer ([#18881](https://github.com/taikoxyz/taiko-mono/issues/18881)) ([e368750](https://github.com/taikoxyz/taiko-mono/commit/e3687500d08505358ece548a51399ec35a21721b))
* **taiko-client:** cleanup pre-ontake tests ([#18647](https://github.com/taikoxyz/taiko-mono/issues/18647)) ([b577b3b](https://github.com/taikoxyz/taiko-mono/commit/b577b3b40f51bf35efe46151e459d37b87548614))
* **taiko-client:** fix some lint issues for `taiko-client` ([#18517](https://github.com/taikoxyz/taiko-mono/issues/18517)) ([ac7eba6](https://github.com/taikoxyz/taiko-mono/commit/ac7eba69bfe13f026bc6e08074ebaec5dcb067eb))
* **taiko-client:** improve tests for blob sync ([#18764](https://github.com/taikoxyz/taiko-mono/issues/18764)) ([4df3edc](https://github.com/taikoxyz/taiko-mono/commit/4df3edc04b0d241b2bb540f4f664ff0c3dd0449a))
* **taiko-client:** introduce `MemoryBlobServer` for tests ([#18880](https://github.com/taikoxyz/taiko-mono/issues/18880)) ([7943979](https://github.com/taikoxyz/taiko-mono/commit/794397957a87aa0ffbbfac81e90907af54044a9a))
* **taiko-client:** introduce `TestInvalidPacayaProof` ([#19068](https://github.com/taikoxyz/taiko-mono/issues/19068)) ([c140982](https://github.com/taikoxyz/taiko-mono/commit/c1409823c686e104fbe7210dbd08511d99351e3a))
* **taiko-client:** introduce `TestOntakeToPacayaVerification` ([#19079](https://github.com/taikoxyz/taiko-mono/issues/19079)) ([2162596](https://github.com/taikoxyz/taiko-mono/commit/2162596e2c065a26d5637038a610c046ee3bc232))
* **taiko-client:** introduce TestTxPoolContentWithMinTip test case ([#18285](https://github.com/taikoxyz/taiko-mono/issues/18285)) ([d572f4c](https://github.com/taikoxyz/taiko-mono/commit/d572f4c412e59094ea9a4c5ff0b0667c9c04bd66))
* **taiko-client:** skip `TestCheckL1ReorgToSameHeightFork` temporarily ([#18522](https://github.com/taikoxyz/taiko-mono/issues/18522)) ([385fed2](https://github.com/taikoxyz/taiko-mono/commit/385fed2ce273d131635c54e99a11704a4ed385b8))


### Workflow

* **protocol:** trigger patch release (1.10.1) ([#18358](https://github.com/taikoxyz/taiko-mono/issues/18358)) ([f4f4796](https://github.com/taikoxyz/taiko-mono/commit/f4f4796488059b02c79d6fb15170df58dd31dc4e))
* **repo:** change to trigger hive test manually ([#18514](https://github.com/taikoxyz/taiko-mono/issues/18514)) ([63dec66](https://github.com/taikoxyz/taiko-mono/commit/63dec6695b3e330ba7bd69857743741d7608e2a4))
* **repo:** update go mod and use random port ([#18515](https://github.com/taikoxyz/taiko-mono/issues/18515)) ([3c2e943](https://github.com/taikoxyz/taiko-mono/commit/3c2e943ab2d6ff636ad69dc7e93df34d8f549c4d))


### Build

* **deps:** bump github.com/stretchr/testify from 1.9.0 to 1.10.0 ([#18539](https://github.com/taikoxyz/taiko-mono/issues/18539)) ([79f3fab](https://github.com/taikoxyz/taiko-mono/commit/79f3fab5f1d1ec1bb4ee18afb9268b622e894780))
* **deps:** bump golang.org/x/sync from 0.9.0 to 0.10.0 ([#18560](https://github.com/taikoxyz/taiko-mono/issues/18560)) ([3d51970](https://github.com/taikoxyz/taiko-mono/commit/3d51970aa0953bbfecaeebf76ea7e664c875c0e4))

## [0.43.1](https://github.com/taikoxyz/taiko-mono/compare/taiko-alethia-client-v0.43.0...taiko-alethia-client-v0.43.1) (2025-01-17)


### Chores

* **taiko-client:** add more logs for `BlockProposedIterator` ([#18772](https://github.com/taikoxyz/taiko-mono/issues/18772)) ([1b02bc0](https://github.com/taikoxyz/taiko-mono/commit/1b02bc08b5e87b66e1645e139a4804ec433cf2dd))
* **taiko-client:** ensure event block IDs are continuous ([#18775](https://github.com/taikoxyz/taiko-mono/issues/18775)) ([b359be0](https://github.com/taikoxyz/taiko-mono/commit/b359be028cdd19f3b40ed414f641ea799a2fe055))
* **taiko-client:** improve `BlobFetcher` ([#18786](https://github.com/taikoxyz/taiko-mono/issues/18786)) ([fc32df8](https://github.com/taikoxyz/taiko-mono/commit/fc32df89baf5838092d3bbea8c2babee304a4c8d))
* **taiko-client:** make full sync to sync to the latest header ([#18771](https://github.com/taikoxyz/taiko-mono/issues/18771)) ([65f763b](https://github.com/taikoxyz/taiko-mono/commit/65f763b5629c75056abc49e824e1bb5536d7cd4e))
* **taiko-client:** more logs for `BlockBatchIterator` ([#18774](https://github.com/taikoxyz/taiko-mono/issues/18774)) ([3945f60](https://github.com/taikoxyz/taiko-mono/commit/3945f60171e2733a0888e7bde914634dfa260958))
* **taiko-client:** rename `io.EOF` in iterators ([#18777](https://github.com/taikoxyz/taiko-mono/issues/18777)) ([c634425](https://github.com/taikoxyz/taiko-mono/commit/c6344250bcbfe9acfae84fcbd003a7bfefe24146))

## [0.43.0](https://github.com/taikoxyz/taiko-mono/compare/taiko-alethia-client-v0.42.1...taiko-alethia-client-v0.43.0) (2025-01-14)


### Features

* **taiko-client:** only check and trigger P2P sync progress right after starting ([#18745](https://github.com/taikoxyz/taiko-mono/issues/18745)) ([a05e4c9](https://github.com/taikoxyz/taiko-mono/commit/a05e4c99bbcfd5f6f6e37b4222616e40b31cfbaf))
* **taiko-client:** remove soft blocks implementation ([#18744](https://github.com/taikoxyz/taiko-mono/issues/18744)) ([f645b23](https://github.com/taikoxyz/taiko-mono/commit/f645b23ae11bf5df9b5199d9a683d6b9f2c12d4b))
* **taiko-client:** soft block driver APIs ([#18273](https://github.com/taikoxyz/taiko-mono/issues/18273)) ([9fff7ff](https://github.com/taikoxyz/taiko-mono/commit/9fff7ff3cce99e915e8142a090a7fad2f1af5bd4))


### Bug Fixes

* **taiko-client:** check inner iterator errors in `BlockProposedIterator` ([#18757](https://github.com/taikoxyz/taiko-mono/issues/18757)) ([404efcc](https://github.com/taikoxyz/taiko-mono/commit/404efcc0ad7c5494635a53df94ea72108fa69bf2))
* **taiko-client:** check the `blockID` of the last verified block before using it as `FinalizedBlockHash` ([#18739](https://github.com/taikoxyz/taiko-mono/issues/18739)) ([8c364b1](https://github.com/taikoxyz/taiko-mono/commit/8c364b1f493cfda2823e3efc49ec0e8a8985884a))
* **taiko-client:** remove `finalizedBlock` info when P2P syncing ([#18735](https://github.com/taikoxyz/taiko-mono/issues/18735)) ([d81a630](https://github.com/taikoxyz/taiko-mono/commit/d81a6309c2e303eca57238c4e252b93083a55d2f))
* **taiko-client:** revert `tracker.triggered` related changes ([#18737](https://github.com/taikoxyz/taiko-mono/issues/18737)) ([e76d865](https://github.com/taikoxyz/taiko-mono/commit/e76d865a3f482b6165f2b7cc5bb0f4a5065b3bc2))


### Chores

* **taiko-client:** add softBlock server start log ([#18731](https://github.com/taikoxyz/taiko-mono/issues/18731)) ([23594ff](https://github.com/taikoxyz/taiko-mono/commit/23594ff2e44f51b0409c76368429d2c3a156a802))
* **taiko-client:** bump `taiko-geth` dep ([#18730](https://github.com/taikoxyz/taiko-mono/issues/18730)) ([554f679](https://github.com/taikoxyz/taiko-mono/commit/554f679b01199da363587adee0ec88a0c1846483))
* **taiko-client:** cleanup some unused variables in `bindings` package ([#18752](https://github.com/taikoxyz/taiko-mono/issues/18752)) ([13ccc54](https://github.com/taikoxyz/taiko-mono/commit/13ccc5466e40422b971f426661f3d7adef8d3d17))
* **taiko-client:** improve `TxBuilderWithFallback` logs ([#18738](https://github.com/taikoxyz/taiko-mono/issues/18738)) ([01ebba3](https://github.com/taikoxyz/taiko-mono/commit/01ebba3a61d0bbd8251bed1f91b09b9abfcc99c7))


### Tests

* **taiko-client:** improve tests for blob sync ([#18764](https://github.com/taikoxyz/taiko-mono/issues/18764)) ([4df3edc](https://github.com/taikoxyz/taiko-mono/commit/4df3edc04b0d241b2bb540f4f664ff0c3dd0449a))

## [0.42.1](https://github.com/taikoxyz/taiko-mono/compare/taiko-alethia-client-v0.42.0...taiko-alethia-client-v0.42.1) (2025-01-07)


### Chores

* **taiko-client:** always use `blockID` instead of `height` for L2 blocks in logs ([#18719](https://github.com/taikoxyz/taiko-mono/issues/18719)) ([a02b96d](https://github.com/taikoxyz/taiko-mono/commit/a02b96d609b17070fd0b071127d84c21e1f3a8ef))
* **taiko-client:** improve proposer gas estimation ([#18727](https://github.com/taikoxyz/taiko-mono/issues/18727)) ([6aed5b3](https://github.com/taikoxyz/taiko-mono/commit/6aed5b3bc5f46e089784405133fcf83c6befe495))

## [0.42.0](https://github.com/taikoxyz/taiko-mono/compare/taiko-alethia-client-v0.41.1...taiko-alethia-client-v0.42.0) (2025-01-06)


### Features

* **taiko-client:** build blob transactions when gas estimation failed ([#18712](https://github.com/taikoxyz/taiko-mono/issues/18712)) ([6c0ef37](https://github.com/taikoxyz/taiko-mono/commit/6c0ef3706ebae8059b9ff554f45c2dcad00c0535))
* **taiko-client:** introduce `TxBuilderWithFallback` ([#18690](https://github.com/taikoxyz/taiko-mono/issues/18690)) ([f1d7b20](https://github.com/taikoxyz/taiko-mono/commit/f1d7b20b722b1e15db3f3f2953c8afb89287537f))
* **taiko-client:** remove an unused flag for proposer ([#18709](https://github.com/taikoxyz/taiko-mono/issues/18709)) ([6fb1fd2](https://github.com/taikoxyz/taiko-mono/commit/6fb1fd25696a5251d864e8869c4a360e9915d787))


### Bug Fixes

* **taiko-client:** add [#18442](https://github.com/taikoxyz/taiko-mono/issues/18442) back ([#18685](https://github.com/taikoxyz/taiko-mono/issues/18685)) ([abc0554](https://github.com/taikoxyz/taiko-mono/commit/abc0554eb0b0a640a8b1a4e9762f7d691b089d40))
* **taiko-client:** add timestamp as a new parameter to getBasefeeV2 ([#18691](https://github.com/taikoxyz/taiko-mono/issues/18691)) ([4a4d908](https://github.com/taikoxyz/taiko-mono/commit/4a4d908b0290046d1098d943a9ebc685c7ca533e))
* **taiko-client:** fix blob transactions estimation when proposing ([#18703](https://github.com/taikoxyz/taiko-mono/issues/18703)) ([395ac5f](https://github.com/taikoxyz/taiko-mono/commit/395ac5fdfb0d8eccae96fafda423d19766a94556))
* **taiko-client:** fix proposing fee estimation ([#18702](https://github.com/taikoxyz/taiko-mono/issues/18702)) ([13a5b1b](https://github.com/taikoxyz/taiko-mono/commit/13a5b1b50e0bf9f030449af49cb0b58ce4288729))


### Chores

* **taiko-client:** add more metrics for `TxBuilderWithFallback` ([#18711](https://github.com/taikoxyz/taiko-mono/issues/18711)) ([b62d390](https://github.com/taikoxyz/taiko-mono/commit/b62d3906a650d8b58ad1d45b068638823ce05121))
* **taiko-client:** add more proof generation metrics ([#18715](https://github.com/taikoxyz/taiko-mono/issues/18715)) ([ae07365](https://github.com/taikoxyz/taiko-mono/commit/ae07365e560c51bcc197335d0ac0ba61964f0b49))
* **taiko-client:** cleanup pre-ontake prover code ([#18677](https://github.com/taikoxyz/taiko-mono/issues/18677)) ([fef6884](https://github.com/taikoxyz/taiko-mono/commit/fef6884bc318e4f09d9c59930a0565cc15e25996))
* **taiko-client:** fix docs ([#18698](https://github.com/taikoxyz/taiko-mono/issues/18698)) ([fc545ee](https://github.com/taikoxyz/taiko-mono/commit/fc545ee89fd907a20161195ef174e7d96d4beae3))
* **taiko-client:** improve prover logs ([#18718](https://github.com/taikoxyz/taiko-mono/issues/18718)) ([3246071](https://github.com/taikoxyz/taiko-mono/commit/32460713052351789f3d7b452ccd0251a000e2f8))
* **taiko-client:** more cost estimation metrics ([#18713](https://github.com/taikoxyz/taiko-mono/issues/18713)) ([b9bd6ea](https://github.com/taikoxyz/taiko-mono/commit/b9bd6ea479da8943b96ddca00a3bbb0e8148774c))
* **taiko-client:** optimize logging ([#18674](https://github.com/taikoxyz/taiko-mono/issues/18674)) ([60bda60](https://github.com/taikoxyz/taiko-mono/commit/60bda60df922e5dd04f6186f8a67d7cb56351c6d))
* **taiko-client:** remove some unused flags ([#18678](https://github.com/taikoxyz/taiko-mono/issues/18678)) ([63f9d26](https://github.com/taikoxyz/taiko-mono/commit/63f9d26b42518a995e093d7db6bc43ef3b57ecca))


### Tests

* **taiko-client:** add more fallback proposing tests ([#18705](https://github.com/taikoxyz/taiko-mono/issues/18705)) ([0e8ef0d](https://github.com/taikoxyz/taiko-mono/commit/0e8ef0d6df36cc05956574b38dabdbbd83f7ce5a))

## [0.41.1](https://github.com/taikoxyz/taiko-mono/compare/taiko-alethia-client-v0.41.0...taiko-alethia-client-v0.41.1) (2024-12-30)


### Chores

* **taiko-client:** cleanup pre-ontake proposer code ([#18672](https://github.com/taikoxyz/taiko-mono/issues/18672)) ([a52d9a7](https://github.com/taikoxyz/taiko-mono/commit/a52d9a79bb99027061f4719a62361157365a5625))

## [0.41.0](https://github.com/taikoxyz/taiko-mono/compare/taiko-alethia-client-v0.40.0...taiko-alethia-client-v0.41.0) (2024-12-30)


### Features

* **protocol:** introduce `AssembleAnchorV2Tx` method in `AnchorTxConstructor` ([#17850](https://github.com/taikoxyz/taiko-mono/issues/17850)) ([f71b178](https://github.com/taikoxyz/taiko-mono/commit/f71b1780eb98ff3cbbcf7def4388837f33e3fe37))
* **protocol:** introduce risc0 proof ([#17877](https://github.com/taikoxyz/taiko-mono/issues/17877)) ([bcb57cb](https://github.com/taikoxyz/taiko-mono/commit/bcb57cb81d12d0c09656582ad9140b38015b3a58))
* **protocol:** propose a batch blocks conditionally ([#18570](https://github.com/taikoxyz/taiko-mono/issues/18570)) ([e846f62](https://github.com/taikoxyz/taiko-mono/commit/e846f6289fea0b046ddcfcdfaf46f3727efbdf11))
* **taiko-client:** add `proposer_pool_content_fetch_time` metric ([#18190](https://github.com/taikoxyz/taiko-mono/issues/18190)) ([35579df](https://github.com/taikoxyz/taiko-mono/commit/35579dfa938562969da2395492f4472c300574dd))
* **taiko-client:** add `RaikoZKVMHostEndpoint` and rename ([#17926](https://github.com/taikoxyz/taiko-mono/issues/17926)) ([0838f79](https://github.com/taikoxyz/taiko-mono/commit/0838f7993015fc9fc9cacfb3da7b100d52bc856c))
* **taiko-client:** add chain ID to `TryDecompress()` ([#18444](https://github.com/taikoxyz/taiko-mono/issues/18444)) ([10d99d5](https://github.com/taikoxyz/taiko-mono/commit/10d99d50d3866a6e233d9e3749ea5eb753335815))
* **taiko-client:** add optional `l1.private` ([#17962](https://github.com/taikoxyz/taiko-mono/issues/17962)) ([9274f2d](https://github.com/taikoxyz/taiko-mono/commit/9274f2dc90f18c58cc208146f584c9f9715d3d60))
* **taiko-client:** add two more new ZK related metrics ([#18043](https://github.com/taikoxyz/taiko-mono/issues/18043)) ([e43eeac](https://github.com/taikoxyz/taiko-mono/commit/e43eeacb5b7a3d1fc412ffafc39f329f68ff7b40))
* **taiko-client:** allow `--l1.beacon` to be optional when a blob server is given ([#18094](https://github.com/taikoxyz/taiko-mono/issues/18094)) ([f4d47a3](https://github.com/taikoxyz/taiko-mono/commit/f4d47a3f988462605f04106b14394bb400fc9669))
* **taiko-client:** catch raiko deserialization errors ([#18644](https://github.com/taikoxyz/taiko-mono/issues/18644)) ([98a98fd](https://github.com/taikoxyz/taiko-mono/commit/98a98fd4636e3cd5f3ec019493a72880e141f494))
* **taiko-client:** changes based on the latest basefee improvements ([#17911](https://github.com/taikoxyz/taiko-mono/issues/17911)) ([0c10ac9](https://github.com/taikoxyz/taiko-mono/commit/0c10ac9c4973d3ef8a5e35a8646516639b328fa0))
* **taiko-client:** client changes based on [#18150](https://github.com/taikoxyz/taiko-mono/issues/18150) ([#18350](https://github.com/taikoxyz/taiko-mono/issues/18350)) ([ddc6473](https://github.com/taikoxyz/taiko-mono/commit/ddc647327e8d58f5a2def5b902ad06800982544b))
* **taiko-client:** client changes for `ontake` fork ([#17746](https://github.com/taikoxyz/taiko-mono/issues/17746)) ([2aabf3d](https://github.com/taikoxyz/taiko-mono/commit/2aabf3de3456ce8cbd56d15be336d08445b9f242))
* **taiko-client:** client updates based on [#17871](https://github.com/taikoxyz/taiko-mono/issues/17871) ([#17873](https://github.com/taikoxyz/taiko-mono/issues/17873)) ([dbed3ab](https://github.com/taikoxyz/taiko-mono/commit/dbed3aba3d7f49f982f6335b79f5d5b096f890a3))
* **taiko-client:** compatible changes for `lastProposedIn` ([#18442](https://github.com/taikoxyz/taiko-mono/issues/18442)) ([28f32a7](https://github.com/taikoxyz/taiko-mono/commit/28f32a790cc680ecb3e6345221e4183af4f34b2e))
* **taiko-client:** enable proof aggregation (batch proofs) ([#18163](https://github.com/taikoxyz/taiko-mono/issues/18163)) ([7642961](https://github.com/taikoxyz/taiko-mono/commit/7642961a9031840183f4d00d0a4c19fdb8a68058))
* **taiko-client:** improve `ProofBuffer` ([#18627](https://github.com/taikoxyz/taiko-mono/issues/18627)) ([c386589](https://github.com/taikoxyz/taiko-mono/commit/c3865896523712afa108be810e75b511e7ecc0c4))
* **taiko-client:** improve some logs in zk producer ([#18117](https://github.com/taikoxyz/taiko-mono/issues/18117)) ([109595e](https://github.com/taikoxyz/taiko-mono/commit/109595e7b285709833a782ee0959fd1a815ef706))
* **taiko-client:** introduce `BasefeeSharingPctg` in `BlockMetadata` ([#17853](https://github.com/taikoxyz/taiko-mono/issues/17853)) ([5f2d696](https://github.com/taikoxyz/taiko-mono/commit/5f2d6961b9d077e47f34bf7f5d1fbffaf380bde1))
* **taiko-client:** introduce `CalculateBaseFee()` method ([#17989](https://github.com/taikoxyz/taiko-mono/issues/17989)) ([fdee419](https://github.com/taikoxyz/taiko-mono/commit/fdee4195541e5c675561cf34c5e1a9e3e3990bbf))
* **taiko-client:** introduce `TaikoDataBlockV2` ([#17936](https://github.com/taikoxyz/taiko-mono/issues/17936)) ([c608116](https://github.com/taikoxyz/taiko-mono/commit/c608116523922fa4664968dc73608a118b5b97ba))
* **taiko-client:** introduce `TaikoL2.GetBasefeeV2` ([#18660](https://github.com/taikoxyz/taiko-mono/issues/18660)) ([4abfaa9](https://github.com/taikoxyz/taiko-mono/commit/4abfaa9e28a619c1edfa82548a00eae0790f784b))
* **taiko-client:** introduce `TierZkVMRisc0ID` ([#17915](https://github.com/taikoxyz/taiko-mono/issues/17915)) ([96aa5c2](https://github.com/taikoxyz/taiko-mono/commit/96aa5c2a5cd096ac3560fe17106ec042a877bfc1))
* **taiko-client:** introduce `TxMgrSelector` for proposer / prover ([#17986](https://github.com/taikoxyz/taiko-mono/issues/17986)) ([6eb298f](https://github.com/taikoxyz/taiko-mono/commit/6eb298f31723e838ac4261fbecbfcfce371d8606))
* **taiko-client:** introduce sp1 zk proof ([#18003](https://github.com/taikoxyz/taiko-mono/issues/18003)) ([492c208](https://github.com/taikoxyz/taiko-mono/commit/492c208b97e8fa08eb3e11b0a8712a5542eba660))
* **taiko-client:** make p2p-sync required ([#18571](https://github.com/taikoxyz/taiko-mono/issues/18571)) ([de92b28](https://github.com/taikoxyz/taiko-mono/commit/de92b28c03b747845a8a1aa26991307d1ed47fd0))
* **taiko-client:** optimizing statistics on proof request times ([#17976](https://github.com/taikoxyz/taiko-mono/issues/17976)) ([791f44f](https://github.com/taikoxyz/taiko-mono/commit/791f44f381fa362f24c4beff5b5b25c47929bbc4))
* **taiko-client:** optimize aggregation logging again ([#18643](https://github.com/taikoxyz/taiko-mono/issues/18643)) ([688a426](https://github.com/taikoxyz/taiko-mono/commit/688a42646d185694c7cfd2bc091084dd782782f5))
* **taiko-client:** remove `basefeeSharingPctg` from metadata ([#17890](https://github.com/taikoxyz/taiko-mono/issues/17890)) ([57c8f6f](https://github.com/taikoxyz/taiko-mono/commit/57c8f6f3a8f920bab8fecd75bfa36a6b71ef808d))
* **taiko-client:** remove an unused field in prover ([#18024](https://github.com/taikoxyz/taiko-mono/issues/18024)) ([5d416d2](https://github.com/taikoxyz/taiko-mono/commit/5d416d2366e485b242818fb1a15eb0281cb7cedf))
* **taiko-client:** remove an unused filed in proposer ([#18021](https://github.com/taikoxyz/taiko-mono/issues/18021)) ([64fdf5c](https://github.com/taikoxyz/taiko-mono/commit/64fdf5c80708b14d2cefadfbd78ee59810df3f65))
* **taiko-client:** remove an unused package ([#18668](https://github.com/taikoxyz/taiko-mono/issues/18668)) ([e1af55a](https://github.com/taikoxyz/taiko-mono/commit/e1af55abcf99ba4a1de6cc22072a457f45ad55be))
* **taiko-client:** remove the legacy `290` tier ([#18035](https://github.com/taikoxyz/taiko-mono/issues/18035)) ([5064037](https://github.com/taikoxyz/taiko-mono/commit/50640377db773763c3ccba1bc4f342cd1e497147))
* **taiko-client:** revert pr 18442 ([#18450](https://github.com/taikoxyz/taiko-mono/issues/18450)) ([0706f0a](https://github.com/taikoxyz/taiko-mono/commit/0706f0aee9c318d8de298f98480a46de6337937c))
* **taiko-client:** revert pr-18571 ([#18648](https://github.com/taikoxyz/taiko-mono/issues/18648)) ([842f812](https://github.com/taikoxyz/taiko-mono/commit/842f8122305f8cbf3153bb645e3107abb4af3cf4))
* **taiko-client:** support `TaikoL1.proposeBlocksV2` ([#18116](https://github.com/taikoxyz/taiko-mono/issues/18116)) ([d0c0fed](https://github.com/taikoxyz/taiko-mono/commit/d0c0fed57c8b8ba139b65d0215df1976358e7635))
* **taiko-client:** update `BlockParamsV2` struct ([#17893](https://github.com/taikoxyz/taiko-mono/issues/17893)) ([a1043a8](https://github.com/taikoxyz/taiko-mono/commit/a1043a85631892e0b03e0f9f4bb850d4e9a70967))
* **taiko-client:** update `OntakeForkHeight` in mainnet ([#18253](https://github.com/taikoxyz/taiko-mono/issues/18253)) ([21c6235](https://github.com/taikoxyz/taiko-mono/commit/21c62355575adae6d99e1a117f357c6429d79b4c))
* **taiko-client:** update `ontakeForkHeight` to Sep 24, 2024 ([#18047](https://github.com/taikoxyz/taiko-mono/issues/18047)) ([a1ff620](https://github.com/taikoxyz/taiko-mono/commit/a1ff620507e4a8077705c981c3622e3787a55ecd))
* **taiko-client:** update contract binding & add `Proposer` ([#18053](https://github.com/taikoxyz/taiko-mono/issues/18053)) ([d0554a2](https://github.com/taikoxyz/taiko-mono/commit/d0554a208c4913751ff5b273f3e96ca298279d14))
* **taiko-client:** update contract bingdings ([#18182](https://github.com/taikoxyz/taiko-mono/issues/18182)) ([8954764](https://github.com/taikoxyz/taiko-mono/commit/8954764d96c256408c1cfd77deb1621da288a33c))
* **taiko-client:** update Go contract bindings ([#17869](https://github.com/taikoxyz/taiko-mono/issues/17869)) ([d9bd72b](https://github.com/taikoxyz/taiko-mono/commit/d9bd72b76aa0bed4ccfe834053f6561a53e1367d))
* **taiko-client:** update Go contract bindings ([#17885](https://github.com/taikoxyz/taiko-mono/issues/17885)) ([3179074](https://github.com/taikoxyz/taiko-mono/commit/31790747cfc743b218d5a3568b9d70b64df5a86c))
* **taiko-client:** update Go contract bindings ([#17997](https://github.com/taikoxyz/taiko-mono/issues/17997)) ([606114f](https://github.com/taikoxyz/taiko-mono/commit/606114faa0b5642055455f07cbd7ec2c3c23b00c))
* **taiko-client:** update Go contract bindings ([#18012](https://github.com/taikoxyz/taiko-mono/issues/18012)) ([7f054ca](https://github.com/taikoxyz/taiko-mono/commit/7f054ca4505313f8fc500cdb28bf223a254424e2))
* **taiko-client:** update Go contract bindings ([#18381](https://github.com/taikoxyz/taiko-mono/issues/18381)) ([71cfc5c](https://github.com/taikoxyz/taiko-mono/commit/71cfc5ce1ef06dcf099a4ce9b22bea6100406148))
* **taiko-client:** update Go contract bindings ([#18384](https://github.com/taikoxyz/taiko-mono/issues/18384)) ([8dd14a1](https://github.com/taikoxyz/taiko-mono/commit/8dd14a1b4b21ce77ed3aac935b1d2c950e11e729))
* **taiko-client:** update Go contract bindings ([#18462](https://github.com/taikoxyz/taiko-mono/issues/18462)) ([bc0ee99](https://github.com/taikoxyz/taiko-mono/commit/bc0ee9952234cc6722d3a0e9d9ebd92bca706999))
* **taiko-client:** update Go contract bindings after protocol restructure ([#18075](https://github.com/taikoxyz/taiko-mono/issues/18075)) ([57f4953](https://github.com/taikoxyz/taiko-mono/commit/57f49530828e6da2d28ab3979576befdee626c7d))
* **taiko-client:** update hekla's protocol config ([#17955](https://github.com/taikoxyz/taiko-mono/issues/17955)) ([4b6a70d](https://github.com/taikoxyz/taiko-mono/commit/4b6a70dd4fb22146ee6702b8484a4a2b4fbce6c2))
* **taiko-client:** update ontake basefee calculation ([#17892](https://github.com/taikoxyz/taiko-mono/issues/17892)) ([6972dea](https://github.com/taikoxyz/taiko-mono/commit/6972dea313edbc9a30617d2f7aea2dfc9230c432))
* **taiko-client:** update protocol configs temporarily ([#17999](https://github.com/taikoxyz/taiko-mono/issues/17999)) ([7893700](https://github.com/taikoxyz/taiko-mono/commit/789370090ffb7d985b2d9d55bf4efec8495df6bd))
* **taiko-client:** update prover balance check to include bond balance ([#18092](https://github.com/taikoxyz/taiko-mono/issues/18092)) ([5d5ca74](https://github.com/taikoxyz/taiko-mono/commit/5d5ca74970f88493ea75b14a13fe852f840f019a))
* **taiko-client:** use `proveBlocks` by default for post ontake blocks ([#18042](https://github.com/taikoxyz/taiko-mono/issues/18042)) ([15709af](https://github.com/taikoxyz/taiko-mono/commit/15709af1520251f4baeba7d2bbbc8de841bee718))


### Bug Fixes

* **protocol:** fix issue in mainnet deployment script ([#18283](https://github.com/taikoxyz/taiko-mono/issues/18283)) ([5c371a1](https://github.com/taikoxyz/taiko-mono/commit/5c371a181af444999f611e03774ec096ffbd1226))
* **taiko-client:** dont check l1heightInAnchor vs l1Height when detecting reorg ([#18110](https://github.com/taikoxyz/taiko-mono/issues/18110)) ([7ed9b6f](https://github.com/taikoxyz/taiko-mono/commit/7ed9b6f647fd1611e036ce12e4fd96696ef231ea))
* **taiko-client:** fix `GetBasefeeV2` usage ([#18664](https://github.com/taikoxyz/taiko-mono/issues/18664)) ([03537c7](https://github.com/taikoxyz/taiko-mono/commit/03537c7d86700427976da556fed88ea4df5299d7))
* **taiko-client:** fix `lastVerifiedBlockHash` fetch ([#18277](https://github.com/taikoxyz/taiko-mono/issues/18277)) ([8512f45](https://github.com/taikoxyz/taiko-mono/commit/8512f456f033130ecb0e5493a3c36be025908228))
* **taiko-client:** fix blob server API URL when fetching blob data ([#18109](https://github.com/taikoxyz/taiko-mono/issues/18109)) ([7230dfd](https://github.com/taikoxyz/taiko-mono/commit/7230dfd1150edc7c08be6f97a46c1184a0b2d289))
* **taiko-client:** fix CallOpts and `TestTreasuryIncome` test case ([#18000](https://github.com/taikoxyz/taiko-mono/issues/18000)) ([5707a08](https://github.com/taikoxyz/taiko-mono/commit/5707a08ffab3c981f0f23bcb8c7833176903d183))
* **taiko-client:** fix path parsing in `/eth/v1/config/spec` ([#18295](https://github.com/taikoxyz/taiko-mono/issues/18295)) ([6633c80](https://github.com/taikoxyz/taiko-mono/commit/6633c80fbcabb6f06ce5467501da4207bc84be84))
* **taiko-client:** fix process in handling empty proof ([#18128](https://github.com/taikoxyz/taiko-mono/issues/18128)) ([d6d90d8](https://github.com/taikoxyz/taiko-mono/commit/d6d90d887be8955f844c52c4fb100fa46d66fa47))
* **taiko-client:** fix revert case when propose blob blocks ([#18185](https://github.com/taikoxyz/taiko-mono/issues/18185)) ([656e757](https://github.com/taikoxyz/taiko-mono/commit/656e757d629131cb03af894269ef447c39e9741e))
* **taiko-client:** fix some issues about `calculateBaseFee` ([#17978](https://github.com/taikoxyz/taiko-mono/issues/17978)) ([b010efe](https://github.com/taikoxyz/taiko-mono/commit/b010efe195259e7c98e0ad6fb91b0c6484ae2b80))
* **taiko-client:** fix timestamp calculation n `CalculateBaseFee()` ([#18057](https://github.com/taikoxyz/taiko-mono/issues/18057)) ([78c876e](https://github.com/taikoxyz/taiko-mono/commit/78c876e5df27d9e0fffc9e0fbf7ecbe518533025))
* **taiko-client:** fix zk status recognition ([#17946](https://github.com/taikoxyz/taiko-mono/issues/17946)) ([164e476](https://github.com/taikoxyz/taiko-mono/commit/164e47686f41cbb119a230c7a1ad56ef4d0b3117))
* **taiko-client:** improve prover balance check based on 18092 ([#18129](https://github.com/taikoxyz/taiko-mono/issues/18129)) ([b6cd50b](https://github.com/taikoxyz/taiko-mono/commit/b6cd50b61577d1eaa7aa29bd3e728271bcd4996f))
* **taiko-client:** initialize private mempool transaction sender in `InitFromConfig` ([#18005](https://github.com/taikoxyz/taiko-mono/issues/18005)) ([58f1c85](https://github.com/taikoxyz/taiko-mono/commit/58f1c85ad471a545f8f00bfd32b3241657f38e8f))
* **taiko-client:** prints logs when using `privateTxMgr` ([#17980](https://github.com/taikoxyz/taiko-mono/issues/17980)) ([a0c3388](https://github.com/taikoxyz/taiko-mono/commit/a0c33882ca00fb834001abac95b6ade656d55e87))
* **taiko-client:** record `lastProposedAt` after ontake fork ([#18166](https://github.com/taikoxyz/taiko-mono/issues/18166)) ([ea0ca90](https://github.com/taikoxyz/taiko-mono/commit/ea0ca9040cc3d1d9fec50777d40b3cf69803c115))
* **taiko-client:** revert path changes about SocialScan endpoint ([#18119](https://github.com/taikoxyz/taiko-mono/issues/18119)) ([38fa03a](https://github.com/taikoxyz/taiko-mono/commit/38fa03ab78d9cf4e70df8c623a74a4d69cf85682))
* **taiko-client:** temp support tier 290 ([#18030](https://github.com/taikoxyz/taiko-mono/issues/18030)) ([f1aeac3](https://github.com/taikoxyz/taiko-mono/commit/f1aeac39d3c2ce06578a64bbe8a2fe4343d212f4))
* **taiko-client:** use proposed at, not timestamp when fetching blob ([#18055](https://github.com/taikoxyz/taiko-mono/issues/18055)) ([32d95c1](https://github.com/taikoxyz/taiko-mono/commit/32d95c1d9e887e886da57e580554413b4f3a19c5))
* **taiko-client:** valid status check in `BatchGetBlocksProofStatus` ([#18595](https://github.com/taikoxyz/taiko-mono/issues/18595)) ([ec5f599](https://github.com/taikoxyz/taiko-mono/commit/ec5f5999750f70efe58cc061c5856250dcef5ce2))


### Chores

* **main:** release taiko-client 0.30.0 ([#17770](https://github.com/taikoxyz/taiko-mono/issues/17770)) ([92879e9](https://github.com/taikoxyz/taiko-mono/commit/92879e91fba74118e701065513c5a0937393d299))
* **main:** release taiko-client 0.31.0 ([#17952](https://github.com/taikoxyz/taiko-mono/issues/17952)) ([1d09fd2](https://github.com/taikoxyz/taiko-mono/commit/1d09fd229376c211914cdb3ec59a46774deed70b))
* **main:** release taiko-client 0.32.0 ([#17956](https://github.com/taikoxyz/taiko-mono/issues/17956)) ([3a0bfa7](https://github.com/taikoxyz/taiko-mono/commit/3a0bfa7173345d35e2a7d2b0303a6ab4cfc9da0f))
* **main:** release taiko-client 0.33.0 ([#17988](https://github.com/taikoxyz/taiko-mono/issues/17988)) ([c4653e5](https://github.com/taikoxyz/taiko-mono/commit/c4653e5f67a57e1debc02b98cabfed95e2edc2b4))
* **main:** release taiko-client 0.33.1 ([#18008](https://github.com/taikoxyz/taiko-mono/issues/18008)) ([af794de](https://github.com/taikoxyz/taiko-mono/commit/af794de19672b7890e82fed1f58671ec574eb159))
* **main:** release taiko-client 0.34.0 ([#18013](https://github.com/taikoxyz/taiko-mono/issues/18013)) ([cd5a6d9](https://github.com/taikoxyz/taiko-mono/commit/cd5a6d99a49237edfe417d82847cc47821bccbfd))
* **main:** release taiko-client 0.34.1 ([#18031](https://github.com/taikoxyz/taiko-mono/issues/18031)) ([428dd49](https://github.com/taikoxyz/taiko-mono/commit/428dd49fb678ddeb5a942d4ed924ce760709a350))
* **main:** release taiko-client 0.35.0 ([#18036](https://github.com/taikoxyz/taiko-mono/issues/18036)) ([61f31b6](https://github.com/taikoxyz/taiko-mono/commit/61f31b6a0fedd53c6e6cce3e208dc731f8b0ce4c))
* **main:** release taiko-client 0.36.0 ([#18076](https://github.com/taikoxyz/taiko-mono/issues/18076)) ([d895cd8](https://github.com/taikoxyz/taiko-mono/commit/d895cd8c0b9a7ab6de94fe80ac8f6d6f686d11f4))
* **main:** release taiko-client 0.37.0 ([#18093](https://github.com/taikoxyz/taiko-mono/issues/18093)) ([02a71dd](https://github.com/taikoxyz/taiko-mono/commit/02a71dd26e0650b39754fbac7100e6e9b5d0ce38))
* **main:** release taiko-client 0.38.0 ([#18191](https://github.com/taikoxyz/taiko-mono/issues/18191)) ([f3ed20b](https://github.com/taikoxyz/taiko-mono/commit/f3ed20bca65cfb87a182f6876795983a4b3cd792))
* **main:** release taiko-client 0.39.0 ([#18247](https://github.com/taikoxyz/taiko-mono/issues/18247)) ([be08e8b](https://github.com/taikoxyz/taiko-mono/commit/be08e8b846f798bb8259bfa0ae73bd729a5aaf79))
* **main:** release taiko-client 0.39.1 ([#18278](https://github.com/taikoxyz/taiko-mono/issues/18278)) ([191480d](https://github.com/taikoxyz/taiko-mono/commit/191480d06159951aa6db0c550a0cc576917a7935))
* **main:** release taiko-client 0.39.2 ([#18284](https://github.com/taikoxyz/taiko-mono/issues/18284)) ([52a9362](https://github.com/taikoxyz/taiko-mono/commit/52a936299487ee4db83e88ba740aec025561a2b9))
* **main:** release taiko-client 0.40.0 ([#18436](https://github.com/taikoxyz/taiko-mono/issues/18436)) ([2a82c94](https://github.com/taikoxyz/taiko-mono/commit/2a82c945a2f6436a36f393105621bb011d8a4325))
* **protocol:** remove reliance on taiko contracts and update golangci-lint ([#18151](https://github.com/taikoxyz/taiko-mono/issues/18151)) ([92f571a](https://github.com/taikoxyz/taiko-mono/commit/92f571a15daa4ad300b4665bbace9248c439fd11))
* **protocol:** revert `TAIKO_TOKEN` name changes in `DeployOnL1` ([#17927](https://github.com/taikoxyz/taiko-mono/issues/17927)) ([cf1a15f](https://github.com/taikoxyz/taiko-mono/commit/cf1a15f46344e60448c5fdcbcae02521fb5b7c04))
* **repo:** fix broken links ([#18635](https://github.com/taikoxyz/taiko-mono/issues/18635)) ([8e53a6e](https://github.com/taikoxyz/taiko-mono/commit/8e53a6e6a2654b8a599fe1df187e2fd88c22d96e))
* **taiko-client:** add `BaseFeeConfig.SharingPctg` to mainnet protocol config ([#18341](https://github.com/taikoxyz/taiko-mono/issues/18341)) ([75d14a7](https://github.com/taikoxyz/taiko-mono/commit/75d14a7afac83b4578a3c32456a28ae70373d5cb))
* **taiko-client:** add hive tests to workflow ([#17897](https://github.com/taikoxyz/taiko-mono/issues/17897)) ([323d728](https://github.com/taikoxyz/taiko-mono/commit/323d7285d83b83adfd220747fb3f55b5cd72d877))
* **taiko-client:** bump dependencies ([#18202](https://github.com/taikoxyz/taiko-mono/issues/18202)) ([219a7e8](https://github.com/taikoxyz/taiko-mono/commit/219a7e87c09c7e4ac8d545c65c77a29e6f818701))
* **taiko-client:** don't use color prefix in log's terminal handler ([#17991](https://github.com/taikoxyz/taiko-mono/issues/17991)) ([1675cec](https://github.com/taikoxyz/taiko-mono/commit/1675cecab5773d1c4fdf82b8e000a6f5bebddfc6))
* **taiko-client:** fix lint errors ([#17969](https://github.com/taikoxyz/taiko-mono/issues/17969)) ([eedec99](https://github.com/taikoxyz/taiko-mono/commit/eedec991c92d5fcd418cde4db9d16c9b36122a0a))
* **taiko-client:** improve `proofBuffer` logs ([#18669](https://github.com/taikoxyz/taiko-mono/issues/18669)) ([3b0d786](https://github.com/taikoxyz/taiko-mono/commit/3b0d786fe42205394a8a293aa6e5913e158323c4))
* **taiko-client:** keep env vars same with the flag name ([#17964](https://github.com/taikoxyz/taiko-mono/issues/17964)) ([d08a1de](https://github.com/taikoxyz/taiko-mono/commit/d08a1de8a36a4bac484bf0390728cb8ed87b3a0b))
* **taiko-client:** revert building changes ([#18174](https://github.com/taikoxyz/taiko-mono/issues/18174)) ([485b2ee](https://github.com/taikoxyz/taiko-mono/commit/485b2ee9a4bf4e16b9d0ab7b704eba0b0a46996c))
* **taiko-client:** try cross-compile taiko-client to speed up docker building ([#18171](https://github.com/taikoxyz/taiko-mono/issues/18171)) ([9dbad24](https://github.com/taikoxyz/taiko-mono/commit/9dbad24cefcd260e2b452c9e8a46fcbe5f327cb4))
* **taiko-client:** update `hive_tests.sh` ([#17923](https://github.com/taikoxyz/taiko-mono/issues/17923)) ([05d49b0](https://github.com/taikoxyz/taiko-mono/commit/05d49b07f9131bc034d00ad6cb7b7868a9af2bfc))
* **taiko-client:** update CI badge and path ([#18441](https://github.com/taikoxyz/taiko-mono/issues/18441)) ([6aef03e](https://github.com/taikoxyz/taiko-mono/commit/6aef03e87eaf3cdbfb7637bd6122525f75c611f0))
* **taiko-client:** update docker-compose config ([#18330](https://github.com/taikoxyz/taiko-mono/issues/18330)) ([74e4ca4](https://github.com/taikoxyz/taiko-mono/commit/74e4ca4aaef07af4958a7b61c95e385022b1cf3c))
* **taiko-client:** update Go contract bindings generation script ([#18324](https://github.com/taikoxyz/taiko-mono/issues/18324)) ([4f698a0](https://github.com/taikoxyz/taiko-mono/commit/4f698a02bb1714caf527629a637323a9964cdb11))


### Documentation

* **taiko-client:** update readme how to do integration test ([#18256](https://github.com/taikoxyz/taiko-mono/issues/18256)) ([b12b32e](https://github.com/taikoxyz/taiko-mono/commit/b12b32e92b5803f15047a6da2b73135f12b9406d))


### Code Refactoring

* **taiko-client:** move `utils` package from `internal/` to `pkg/`  ([#18516](https://github.com/taikoxyz/taiko-mono/issues/18516)) ([b674857](https://github.com/taikoxyz/taiko-mono/commit/b67485732832fb90849179a7a8c8093f2228eb5a))


### Tests

* **taiko-client:** cleanup pre-ontake tests ([#18647](https://github.com/taikoxyz/taiko-mono/issues/18647)) ([b577b3b](https://github.com/taikoxyz/taiko-mono/commit/b577b3b40f51bf35efe46151e459d37b87548614))
* **taiko-client:** disable docker pull in hive test ([#18101](https://github.com/taikoxyz/taiko-mono/issues/18101)) ([95c9da2](https://github.com/taikoxyz/taiko-mono/commit/95c9da29fdd432de156f331802b79703a2311898))
* **taiko-client:** fix some lint issues for `taiko-client` ([#18517](https://github.com/taikoxyz/taiko-mono/issues/18517)) ([ac7eba6](https://github.com/taikoxyz/taiko-mono/commit/ac7eba69bfe13f026bc6e08074ebaec5dcb067eb))
* **taiko-client:** introduce `taiko-reth` as another L2 node in testing ([#18223](https://github.com/taikoxyz/taiko-mono/issues/18223)) ([e856273](https://github.com/taikoxyz/taiko-mono/commit/e85627365d423fd8353b5bff92e80978774e9c50))
* **taiko-client:** introduce `TestProposeTxListOntake` ([#18167](https://github.com/taikoxyz/taiko-mono/issues/18167)) ([5023226](https://github.com/taikoxyz/taiko-mono/commit/5023226a7aa2e7355e835f9447b17eb85c60032a))
* **taiko-client:** introduce blob-server and blob-l1-beacon hive tests ([#18121](https://github.com/taikoxyz/taiko-mono/issues/18121)) ([c544fe8](https://github.com/taikoxyz/taiko-mono/commit/c544fe8c33e26bfae951fb15c423aec2b749d092))
* **taiko-client:** introduce multi nodes hive test ([#17981](https://github.com/taikoxyz/taiko-mono/issues/17981)) ([9910863](https://github.com/taikoxyz/taiko-mono/commit/9910863865ecf7f583552e74f6a5d2e1a4060dca))
* **taiko-client:** introduce reorg hive test ([#17965](https://github.com/taikoxyz/taiko-mono/issues/17965)) ([ab601ee](https://github.com/taikoxyz/taiko-mono/commit/ab601eea813190a314555c1773a982de16da0e59))
* **taiko-client:** introduce TestTxPoolContentWithMinTip test case ([#18285](https://github.com/taikoxyz/taiko-mono/issues/18285)) ([d572f4c](https://github.com/taikoxyz/taiko-mono/commit/d572f4c412e59094ea9a4c5ff0b0667c9c04bd66))
* **taiko-client:** open container logs and close build image logs ([#17959](https://github.com/taikoxyz/taiko-mono/issues/17959)) ([b541201](https://github.com/taikoxyz/taiko-mono/commit/b54120141f0e18f1912db66d28390d2a92af36c9))
* **taiko-client:** remove an unnecessary test ([#18218](https://github.com/taikoxyz/taiko-mono/issues/18218)) ([d624e29](https://github.com/taikoxyz/taiko-mono/commit/d624e29ce1c0ae9ef6704d96516d632600213e13))
* **taiko-client:** skip `TestCheckL1ReorgToSameHeightFork` temporarily ([#18522](https://github.com/taikoxyz/taiko-mono/issues/18522)) ([385fed2](https://github.com/taikoxyz/taiko-mono/commit/385fed2ce273d131635c54e99a11704a4ed385b8))
* **taiko-client:** support full sync and snap sync in hive test ([#17995](https://github.com/taikoxyz/taiko-mono/issues/17995)) ([831198b](https://github.com/taikoxyz/taiko-mono/commit/831198baecc5f0e10c5c8fac1c04f9dad320c63c))
* **taiko-client:** support multi clusters reorg hive test ([#17987](https://github.com/taikoxyz/taiko-mono/issues/17987)) ([28d9072](https://github.com/taikoxyz/taiko-mono/commit/28d90729adc391cb04b58fa2c32a9e3bfbd989a5))
* **taiko-client:** update hive dependence and fix bug about hive test ([#17930](https://github.com/taikoxyz/taiko-mono/issues/17930)) ([dd40a4e](https://github.com/taikoxyz/taiko-mono/commit/dd40a4e6696b9c27135823cd545e7e5249a66e8c))
* **taiko-client:** update HIVE test configurations ([#17950](https://github.com/taikoxyz/taiko-mono/issues/17950)) ([4818274](https://github.com/taikoxyz/taiko-mono/commit/4818274860e8d626e5456479a520229e7c17f31c))
* **taiko-client:** upgrade full sync and snap sync hive tests ([#18010](https://github.com/taikoxyz/taiko-mono/issues/18010)) ([1d18c17](https://github.com/taikoxyz/taiko-mono/commit/1d18c170566aed645e2e03b024e7fe2f2a01756d))
* **taiko-client:** use env names which defined in flag configs ([#17921](https://github.com/taikoxyz/taiko-mono/issues/17921)) ([196b74e](https://github.com/taikoxyz/taiko-mono/commit/196b74eb2b4498bc3e6511915e011a885fcc530f))


### Workflow

* **protocol:** avoid installing `netcat` in action ([#18159](https://github.com/taikoxyz/taiko-mono/issues/18159)) ([7e27d1d](https://github.com/taikoxyz/taiko-mono/commit/7e27d1de388755b167d864df37133bfedafa2462))
* **protocol:** trigger patch release (1.10.1) ([#18358](https://github.com/taikoxyz/taiko-mono/issues/18358)) ([f4f4796](https://github.com/taikoxyz/taiko-mono/commit/f4f4796488059b02c79d6fb15170df58dd31dc4e))
* **repo:** change to trigger hive test manually ([#18514](https://github.com/taikoxyz/taiko-mono/issues/18514)) ([63dec66](https://github.com/taikoxyz/taiko-mono/commit/63dec6695b3e330ba7bd69857743741d7608e2a4))
* **repo:** update go mod and use random port ([#18515](https://github.com/taikoxyz/taiko-mono/issues/18515)) ([3c2e943](https://github.com/taikoxyz/taiko-mono/commit/3c2e943ab2d6ff636ad69dc7e93df34d8f549c4d))


### Build

* **deps:** bump github.com/stretchr/testify from 1.9.0 to 1.10.0 ([#18539](https://github.com/taikoxyz/taiko-mono/issues/18539)) ([79f3fab](https://github.com/taikoxyz/taiko-mono/commit/79f3fab5f1d1ec1bb4ee18afb9268b622e894780))
* **deps:** bump golang.org/x/sync from 0.9.0 to 0.10.0 ([#18560](https://github.com/taikoxyz/taiko-mono/issues/18560)) ([3d51970](https://github.com/taikoxyz/taiko-mono/commit/3d51970aa0953bbfecaeebf76ea7e664c875c0e4))

## [0.40.0](https://github.com/taikoxyz/taiko-mono/compare/taiko-client-v0.39.2...taiko-client-v0.40.0) (2024-12-23)


### Features

* **protocol:** propose a batch blocks conditionally ([#18570](https://github.com/taikoxyz/taiko-mono/issues/18570)) ([e846f62](https://github.com/taikoxyz/taiko-mono/commit/e846f6289fea0b046ddcfcdfaf46f3727efbdf11))
* **taiko-client:** add chain ID to `TryDecompress()` ([#18444](https://github.com/taikoxyz/taiko-mono/issues/18444)) ([10d99d5](https://github.com/taikoxyz/taiko-mono/commit/10d99d50d3866a6e233d9e3749ea5eb753335815))
* **taiko-client:** client changes based on [#18150](https://github.com/taikoxyz/taiko-mono/issues/18150) ([#18350](https://github.com/taikoxyz/taiko-mono/issues/18350)) ([ddc6473](https://github.com/taikoxyz/taiko-mono/commit/ddc647327e8d58f5a2def5b902ad06800982544b))
* **taiko-client:** compatible changes for `lastProposedIn` ([#18442](https://github.com/taikoxyz/taiko-mono/issues/18442)) ([28f32a7](https://github.com/taikoxyz/taiko-mono/commit/28f32a790cc680ecb3e6345221e4183af4f34b2e))
* **taiko-client:** enable proof aggregation (batch proofs) ([#18163](https://github.com/taikoxyz/taiko-mono/issues/18163)) ([7642961](https://github.com/taikoxyz/taiko-mono/commit/7642961a9031840183f4d00d0a4c19fdb8a68058))
* **taiko-client:** improve `ProofBuffer` ([#18627](https://github.com/taikoxyz/taiko-mono/issues/18627)) ([c386589](https://github.com/taikoxyz/taiko-mono/commit/c3865896523712afa108be810e75b511e7ecc0c4))
* **taiko-client:** make p2p-sync required ([#18571](https://github.com/taikoxyz/taiko-mono/issues/18571)) ([de92b28](https://github.com/taikoxyz/taiko-mono/commit/de92b28c03b747845a8a1aa26991307d1ed47fd0))
* **taiko-client:** revert pr 18442 ([#18450](https://github.com/taikoxyz/taiko-mono/issues/18450)) ([0706f0a](https://github.com/taikoxyz/taiko-mono/commit/0706f0aee9c318d8de298f98480a46de6337937c))
* **taiko-client:** update Go contract bindings ([#18381](https://github.com/taikoxyz/taiko-mono/issues/18381)) ([71cfc5c](https://github.com/taikoxyz/taiko-mono/commit/71cfc5ce1ef06dcf099a4ce9b22bea6100406148))
* **taiko-client:** update Go contract bindings ([#18384](https://github.com/taikoxyz/taiko-mono/issues/18384)) ([8dd14a1](https://github.com/taikoxyz/taiko-mono/commit/8dd14a1b4b21ce77ed3aac935b1d2c950e11e729))
* **taiko-client:** update Go contract bindings ([#18462](https://github.com/taikoxyz/taiko-mono/issues/18462)) ([bc0ee99](https://github.com/taikoxyz/taiko-mono/commit/bc0ee9952234cc6722d3a0e9d9ebd92bca706999))


### Bug Fixes

* **taiko-client:** valid status check in `BatchGetBlocksProofStatus` ([#18595](https://github.com/taikoxyz/taiko-mono/issues/18595)) ([ec5f599](https://github.com/taikoxyz/taiko-mono/commit/ec5f5999750f70efe58cc061c5856250dcef5ce2))


### Chores

* **taiko-client:** add `BaseFeeConfig.SharingPctg` to mainnet protocol config ([#18341](https://github.com/taikoxyz/taiko-mono/issues/18341)) ([75d14a7](https://github.com/taikoxyz/taiko-mono/commit/75d14a7afac83b4578a3c32456a28ae70373d5cb))
* **taiko-client:** update CI badge and path ([#18441](https://github.com/taikoxyz/taiko-mono/issues/18441)) ([6aef03e](https://github.com/taikoxyz/taiko-mono/commit/6aef03e87eaf3cdbfb7637bd6122525f75c611f0))
* **taiko-client:** update docker-compose config ([#18330](https://github.com/taikoxyz/taiko-mono/issues/18330)) ([74e4ca4](https://github.com/taikoxyz/taiko-mono/commit/74e4ca4aaef07af4958a7b61c95e385022b1cf3c))
* **taiko-client:** update Go contract bindings generation script ([#18324](https://github.com/taikoxyz/taiko-mono/issues/18324)) ([4f698a0](https://github.com/taikoxyz/taiko-mono/commit/4f698a02bb1714caf527629a637323a9964cdb11))


### Code Refactoring

* **taiko-client:** move `utils` package from `internal/` to `pkg/`  ([#18516](https://github.com/taikoxyz/taiko-mono/issues/18516)) ([b674857](https://github.com/taikoxyz/taiko-mono/commit/b67485732832fb90849179a7a8c8093f2228eb5a))


### Tests

* **taiko-client:** fix some lint issues for `taiko-client` ([#18517](https://github.com/taikoxyz/taiko-mono/issues/18517)) ([ac7eba6](https://github.com/taikoxyz/taiko-mono/commit/ac7eba69bfe13f026bc6e08074ebaec5dcb067eb))
* **taiko-client:** introduce TestTxPoolContentWithMinTip test case ([#18285](https://github.com/taikoxyz/taiko-mono/issues/18285)) ([d572f4c](https://github.com/taikoxyz/taiko-mono/commit/d572f4c412e59094ea9a4c5ff0b0667c9c04bd66))
* **taiko-client:** skip `TestCheckL1ReorgToSameHeightFork` temporarily ([#18522](https://github.com/taikoxyz/taiko-mono/issues/18522)) ([385fed2](https://github.com/taikoxyz/taiko-mono/commit/385fed2ce273d131635c54e99a11704a4ed385b8))


### Workflow

* **protocol:** trigger patch release (1.10.1) ([#18358](https://github.com/taikoxyz/taiko-mono/issues/18358)) ([f4f4796](https://github.com/taikoxyz/taiko-mono/commit/f4f4796488059b02c79d6fb15170df58dd31dc4e))
* **repo:** change to trigger hive test manually ([#18514](https://github.com/taikoxyz/taiko-mono/issues/18514)) ([63dec66](https://github.com/taikoxyz/taiko-mono/commit/63dec6695b3e330ba7bd69857743741d7608e2a4))
* **repo:** update go mod and use random port ([#18515](https://github.com/taikoxyz/taiko-mono/issues/18515)) ([3c2e943](https://github.com/taikoxyz/taiko-mono/commit/3c2e943ab2d6ff636ad69dc7e93df34d8f549c4d))


### Build

* **deps:** bump github.com/stretchr/testify from 1.9.0 to 1.10.0 ([#18539](https://github.com/taikoxyz/taiko-mono/issues/18539)) ([79f3fab](https://github.com/taikoxyz/taiko-mono/commit/79f3fab5f1d1ec1bb4ee18afb9268b622e894780))
* **deps:** bump golang.org/x/sync from 0.9.0 to 0.10.0 ([#18560](https://github.com/taikoxyz/taiko-mono/issues/18560)) ([3d51970](https://github.com/taikoxyz/taiko-mono/commit/3d51970aa0953bbfecaeebf76ea7e664c875c0e4))

## [0.39.2](https://github.com/taikoxyz/taiko-mono/compare/taiko-client-v0.39.1...taiko-client-v0.39.2) (2024-10-24)


### Bug Fixes

* **protocol:** fix issue in mainnet deployment script ([#18283](https://github.com/taikoxyz/taiko-mono/issues/18283)) ([5c371a1](https://github.com/taikoxyz/taiko-mono/commit/5c371a181af444999f611e03774ec096ffbd1226))
* **taiko-client:** fix path parsing in `/eth/v1/config/spec` ([#18295](https://github.com/taikoxyz/taiko-mono/issues/18295)) ([6633c80](https://github.com/taikoxyz/taiko-mono/commit/6633c80fbcabb6f06ce5467501da4207bc84be84))

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
* **taiko-client:** optimizing statistics on proof request times ([#17976](https://github.com/taikoxyz/taiko-mono/issues/17976)) ([791f44f](https://github.com/taikoxyz/taiko-mono/commit/791f44f381fa362f24c4beff5b5b25c47929bbc4))


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
