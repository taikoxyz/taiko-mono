# Changelog

## [0.12.0](https://github.com/taikoxyz/taiko-mono/compare/relayer-v0.11.0...relayer-v0.12.0) (2023-10-18)


### Features

* **eventindexer:** API documentation, swagger, github pages ([#14948](https://github.com/taikoxyz/taiko-mono/issues/14948)) ([5455267](https://github.com/taikoxyz/taiko-mono/commit/54552674fe8a6b0b4321afe1ef4d90d00d62f0e8))


### Bug Fixes

* **eventindexer:** update config tests ([#14912](https://github.com/taikoxyz/taiko-mono/issues/14912)) ([beab49b](https://github.com/taikoxyz/taiko-mono/commit/beab49bd8f085b1e285fb3a16e9b493f3c5f5932))
* **relayer:** ERC1155 bridging, amount =&gt; amounts ([#14959](https://github.com/taikoxyz/taiko-mono/issues/14959)) ([d42c59d](https://github.com/taikoxyz/taiko-mono/commit/d42c59d5150c9c41941458e25fac75121d73da76))

## [0.11.0](https://github.com/taikoxyz/taiko-mono/compare/relayer-v0.10.0...relayer-v0.11.0) (2023-09-25)


### Features

* **eventindexer:** Track proposer/prover rewards, + generate tasks for total/per day ([#14690](https://github.com/taikoxyz/taiko-mono/issues/14690)) ([cc477b9](https://github.com/taikoxyz/taiko-mono/commit/cc477b97c00e8339a87c4d4502a0ee8ad811c10f))
* **relayer:** fix cost calculation for isProfitable ([#14767](https://github.com/taikoxyz/taiko-mono/issues/14767)) ([8e1c897](https://github.com/taikoxyz/taiko-mono/commit/8e1c89748fcb42e354d2219ceac2be1c668bcf31))
* **relayer:** queue processor Prefetch ([#14765](https://github.com/taikoxyz/taiko-mono/issues/14765)) ([a37797a](https://github.com/taikoxyz/taiko-mono/commit/a37797a6115fda37e933b0742881649a411a29ef))
* **relayer:** Relayer indexer/processor separation and refactor, messaging queue ([#14605](https://github.com/taikoxyz/taiko-mono/issues/14605)) ([15b0e50](https://github.com/taikoxyz/taiko-mono/commit/15b0e50c130687cac32eef97ba5f396f79ad933f))
* **relayer:** support L2-L2 bridging ([#14711](https://github.com/taikoxyz/taiko-mono/issues/14711)) ([1410217](https://github.com/taikoxyz/taiko-mono/commit/1410217363077ea6179080fca4a7aeadc6c7d149))


### Bug Fixes

* **relayer:** Relayer cors flag was not being used ([#14661](https://github.com/taikoxyz/taiko-mono/issues/14661)) ([19f35f7](https://github.com/taikoxyz/taiko-mono/commit/19f35f74e8a955c2776defe6e5cac48a9b6456a3))
* **relayer:** Relayer paid gas ([#14748](https://github.com/taikoxyz/taiko-mono/issues/14748)) ([b4cb3ff](https://github.com/taikoxyz/taiko-mono/commit/b4cb3ffe9d4bad67682a8217621b8b67cb263f65))

## [0.10.0](https://github.com/taikoxyz/taiko-mono/compare/relayer-v0.9.1...relayer-v0.10.0) (2023-09-05)


### Features

* **eventindexer:** Eventindexer and relayer a5 updates ([#14597](https://github.com/taikoxyz/taiko-mono/issues/14597)) ([87c9d53](https://github.com/taikoxyz/taiko-mono/commit/87c9d53fa9c6911aada78a1746839d14e4401916))


### Bug Fixes

* **relayer:** Eth bridge ([#14609](https://github.com/taikoxyz/taiko-mono/issues/14609)) ([f5207ae](https://github.com/taikoxyz/taiko-mono/commit/f5207ae19c48d9aaa83dab2739cd05d9c2985112))

## [0.9.1](https://github.com/taikoxyz/taiko-mono/compare/relayer-v0.9.0...relayer-v0.9.1) (2023-08-22)


### Bug Fixes

* **relayer:** use erc20vault not token vault for required end var ([#14519](https://github.com/taikoxyz/taiko-mono/issues/14519)) ([a49c65c](https://github.com/taikoxyz/taiko-mono/commit/a49c65c6ba9535a761f4ef2abd7be2b2213a71c2))

## [0.9.0](https://github.com/taikoxyz/taiko-mono/compare/relayer-v0.8.0...relayer-v0.9.0) (2023-08-15)


### Features

* **eventindexer:** Index nfts ([#14418](https://github.com/taikoxyz/taiko-mono/issues/14418)) ([364b09b](https://github.com/taikoxyz/taiko-mono/commit/364b09b52344dff8782be7333eac4fdb3e5d1597))
* **protocol:** alpha-4 with staking-based tokenomics ([#14065](https://github.com/taikoxyz/taiko-mono/issues/14065)) ([1eeba9d](https://github.com/taikoxyz/taiko-mono/commit/1eeba9d97ed8e6e4a8d07a8b0af163a16fbc9ccf))

## [0.8.0](https://github.com/taikoxyz/taiko-mono/compare/relayer-v0.7.0...relayer-v0.8.0) (2023-06-26)


### Features

* **protocol:** use ring buffer for ETH deposit and optimize storage ([#13868](https://github.com/taikoxyz/taiko-mono/issues/13868)) ([acffb61](https://github.com/taikoxyz/taiko-mono/commit/acffb61b13b44fd4792e8f4a31498d788ca38961))
* **relayer:** use gas tip cap if available ([#14024](https://github.com/taikoxyz/taiko-mono/issues/14024)) ([773331b](https://github.com/taikoxyz/taiko-mono/commit/773331bebb509ef66f3a9aab51a8927432e11dc3))


### Bug Fixes

* **relayer:** cancel waiting for receipts ([#14019](https://github.com/taikoxyz/taiko-mono/issues/14019)) ([c9fcffe](https://github.com/taikoxyz/taiko-mono/commit/c9fcffe1d1227219b244b97555e96a49a865f868))
* **relayer:** fix scanning blocks twice ([#14047](https://github.com/taikoxyz/taiko-mono/issues/14047)) ([9ee6723](https://github.com/taikoxyz/taiko-mono/commit/9ee67238eccc5218346f7cbcf936a76919bf7ae4))
* **relayer:** make sure to return nil for first by msg hash ([#13967](https://github.com/taikoxyz/taiko-mono/issues/13967)) ([bf69226](https://github.com/taikoxyz/taiko-mono/commit/bf692264ede4545089515372002ee176e0783729))
* **relayer:** only need to find first msg hash ([#13966](https://github.com/taikoxyz/taiko-mono/issues/13966)) ([87c6e20](https://github.com/taikoxyz/taiko-mono/commit/87c6e20340757d3bdd6075afb8b5cd264cc511a3))
* **relayer:** relayer is slow due to inefficient indexing in sql ([#13964](https://github.com/taikoxyz/taiko-mono/issues/13964)) ([edd643c](https://github.com/taikoxyz/taiko-mono/commit/edd643cda2ba883d8060ea4921b726b499927575))
* **relayer:** Relayer reorg ([#14033](https://github.com/taikoxyz/taiko-mono/issues/14033)) ([4794f45](https://github.com/taikoxyz/taiko-mono/commit/4794f45006aff0287bc6cf4630910a1ec3a01fbd))
* **relayer:** return nil, not error, if we dont have a previous msghash ([#13968](https://github.com/taikoxyz/taiko-mono/issues/13968)) ([22a1171](https://github.com/taikoxyz/taiko-mono/commit/22a1171a151e26f136771b8bc303bbfefe1dcca8))

## [0.7.0](https://github.com/taikoxyz/taiko-mono/compare/relayer-v0.6.0...relayer-v0.7.0) (2023-06-12)


### Features

* **eventindexer:** handle reorg ([#13841](https://github.com/taikoxyz/taiko-mono/issues/13841)) ([0a26ce5](https://github.com/taikoxyz/taiko-mono/commit/0a26ce58422d2674f1b5cd151c74bb40f2bec17d))
* **status-page:** updates for a3 ([#13821](https://github.com/taikoxyz/taiko-mono/issues/13821)) ([7ed816d](https://github.com/taikoxyz/taiko-mono/commit/7ed816d8db7ac75468faa235c09f147db5009034))

## [0.6.0](https://github.com/taikoxyz/taiko-mono/compare/relayer-v0.5.0...relayer-v0.6.0) (2023-05-26)


### Features

* **eventindexer:** add stats tracking ([#13810](https://github.com/taikoxyz/taiko-mono/issues/13810)) ([bfbbb97](https://github.com/taikoxyz/taiko-mono/commit/bfbbb97fcb67dc33749f0f08f84b8bd54eae9aeb))
* **relayer:** hardcode gas limit to determine if a message needs extra gas to deploy a contract ([#13764](https://github.com/taikoxyz/taiko-mono/issues/13764)) ([0615bf6](https://github.com/taikoxyz/taiko-mono/commit/0615bf6dfc9d5109c7a70d55dd57e79c2a69925f))


### Bug Fixes

* **protocol:** rename treasure to treasury ([#13780](https://github.com/taikoxyz/taiko-mono/issues/13780)) ([ccecd70](https://github.com/taikoxyz/taiko-mono/commit/ccecd708276bce3eca84b92c7c48c95b2156dd18))
* **relayer:** catch relayer message processing up to latest protocol changes ([#13746](https://github.com/taikoxyz/taiko-mono/issues/13746)) ([e3746ee](https://github.com/taikoxyz/taiko-mono/commit/e3746ee1980dade609ac190d27183a6a5b94f4df))
* **relayer:** Out of gas ([#13778](https://github.com/taikoxyz/taiko-mono/issues/13778)) ([a42a33b](https://github.com/taikoxyz/taiko-mono/commit/a42a33b30bc0daec707ff51cc639c966642e50ca))

## [0.5.0](https://github.com/taikoxyz/taiko-mono/compare/relayer-v0.4.1...relayer-v0.5.0) (2023-05-11)


### Features

* **protocol:** major protocol upgrade for alpha-3 testnet ([#13640](https://github.com/taikoxyz/taiko-mono/issues/13640)) ([02552f2](https://github.com/taikoxyz/taiko-mono/commit/02552f2aa001893d326062ce627004c61b46cd26))

## [0.4.1](https://github.com/taikoxyz/taiko-mono/compare/relayer-v0.4.0...relayer-v0.4.1) (2023-04-08)


### Bug Fixes

* **repo:** fix multiple typos ([#13558](https://github.com/taikoxyz/taiko-mono/issues/13558)) ([f54242a](https://github.com/taikoxyz/taiko-mono/commit/f54242aa95e5c5563f8f0a7f9af0a1eab20ab67b))

## [0.4.0](https://github.com/taikoxyz/taiko-mono/compare/relayer-v0.3.0...relayer-v0.4.0) (2023-03-29)


### Features

* **eventindexer:** Event indexer ([#13439](https://github.com/taikoxyz/taiko-mono/issues/13439)) ([08b26d2](https://github.com/taikoxyz/taiko-mono/commit/08b26d21577ed8ecd14beed5a600108fe7a0f765))
* **protocol:** merge alpha 2 to main ([#13369](https://github.com/taikoxyz/taiko-mono/issues/13369)) ([2b9cc64](https://github.com/taikoxyz/taiko-mono/commit/2b9cc6466509372f35109b48c00948d2234b0d59))
* **relayer:** add failed status to Stringer interface impl for eventstatus ([#13495](https://github.com/taikoxyz/taiko-mono/issues/13495)) ([858f485](https://github.com/taikoxyz/taiko-mono/commit/858f485a858a59fe196de22a3d4eed78278ba4a4))
* **relayer:** big Gas price ([#13492](https://github.com/taikoxyz/taiko-mono/issues/13492)) ([cb3f7b9](https://github.com/taikoxyz/taiko-mono/commit/cb3f7b9529addc25fe4d3067f2e2c3da3ae1b2bf))
* **relayer:** handle fail status ([#13493](https://github.com/taikoxyz/taiko-mono/issues/13493)) ([dfac2c4](https://github.com/taikoxyz/taiko-mono/commit/dfac2c4cf84d247f4aa1434e52e403d18253951a))
* **relayer:** merge alpha-2 to main ([#13376](https://github.com/taikoxyz/taiko-mono/issues/13376)) ([3148f6b](https://github.com/taikoxyz/taiko-mono/commit/3148f6ba955e1b3918289332d2ee30f139edea8b))


### Bug Fixes

* **relayer:** 3m =&gt; 1.5 gas ([#13494](https://github.com/taikoxyz/taiko-mono/issues/13494)) ([02a582e](https://github.com/taikoxyz/taiko-mono/commit/02a582ebda4a8993c4fad221e88e2b65d57ceb25))
* **relayer:** new abi gen bindings ([#13342](https://github.com/taikoxyz/taiko-mono/issues/13342)) ([8655ff1](https://github.com/taikoxyz/taiko-mono/commit/8655ff16f3de7445f01b4fd502d183d93e394e1a))

## [0.3.0](https://github.com/taikoxyz/taiko-mono/compare/relayer-v0.2.1...relayer-v0.3.0) (2023-03-15)


### Features

* **relayer:** add msgHash and event type lookups to findallbyaddress ([#13310](https://github.com/taikoxyz/taiko-mono/issues/13310)) ([8b753ee](https://github.com/taikoxyz/taiko-mono/commit/8b753ee07eeee51adf48e72343b62abcde3b2338))
* **relayer:** Event filter ([#13318](https://github.com/taikoxyz/taiko-mono/issues/13318)) ([f20d419](https://github.com/taikoxyz/taiko-mono/commit/f20d4195ac9d700dfd4a51192232c3fe7c4c0b43))
* **relayer:** MessageStatusChanged events ([#13272](https://github.com/taikoxyz/taiko-mono/issues/13272)) ([f5f4fc4](https://github.com/taikoxyz/taiko-mono/commit/f5f4fc4af16520a34e805e8f16c50e0de4902815))
* **relayer:** Pagination ([#13311](https://github.com/taikoxyz/taiko-mono/issues/13311)) ([9350006](https://github.com/taikoxyz/taiko-mono/commit/9350006aefa8f6423c663ea3a0377f7334a5b749))


### Bug Fixes

* **relayer:** estimate gas for tx, set gas to 2.5mil if not estimatable. works now. ([#13271](https://github.com/taikoxyz/taiko-mono/issues/13271)) ([3913ca5](https://github.com/taikoxyz/taiko-mono/commit/3913ca52242913dfb9502488f0a5558724f9ef2b))

## [0.2.1](https://github.com/taikoxyz/taiko-mono/compare/relayer-v0.2.0...relayer-v0.2.1) (2023-03-01)


### Bug Fixes

* **relayer:** estimate gas, now that gas estimation works again ([#13176](https://github.com/taikoxyz/taiko-mono/issues/13176)) ([b7ae677](https://github.com/taikoxyz/taiko-mono/commit/b7ae677ec2d84dce3e3ae50d369bf31dedc547c3))
* **relayer:** Save block progress when caught up and subscribing to new events ([#13177](https://github.com/taikoxyz/taiko-mono/issues/13177)) ([5ef2c0f](https://github.com/taikoxyz/taiko-mono/commit/5ef2c0f5d78764189d168aa527cec62238f1d6c6))

## [0.2.0](https://github.com/taikoxyz/taiko-mono/compare/relayer-v0.1.0...relayer-v0.2.0) (2023-02-15)


### Features

* **protocol:** change statevariables to return a struct ([#13113](https://github.com/taikoxyz/taiko-mono/issues/13113)) ([0bffeb0](https://github.com/taikoxyz/taiko-mono/commit/0bffeb0f3d17938bf2146772962719ae21ce22fa))
* **relayer:** catch relayer & status page up to new testnet ([#13114](https://github.com/taikoxyz/taiko-mono/issues/13114)) ([543f242](https://github.com/taikoxyz/taiko-mono/commit/543f242bfbf18b155f3476c2d172e79d3041ffc9))
* **relayer:** prepare bridge relayer API for frontend ([#13124](https://github.com/taikoxyz/taiko-mono/issues/13124)) ([ef1f691](https://github.com/taikoxyz/taiko-mono/commit/ef1f691ac9e6b3138b1ee80bc7bebcf53b749581))

## [0.1.0](https://github.com/taikoxyz/taiko-mono/compare/relayer-v0.0.1...relayer-v0.1.0) (2023-01-19)


### Features

* **bridge-ui:** process message ([#387](https://github.com/taikoxyz/taiko-mono/issues/387)) ([d1781c0](https://github.com/taikoxyz/taiko-mono/commit/d1781c0107110e70c87e76d3fc1f6a9bc2aa1a46))
* **bridge:** add faucet link to announcement ([#485](https://github.com/taikoxyz/taiko-mono/issues/485)) ([d1a4921](https://github.com/taikoxyz/taiko-mono/commit/d1a492183fd4ab8f195697864f54c35349dca93d))
* **bridge:** bridge design ([#369](https://github.com/taikoxyz/taiko-mono/issues/369)) ([04702db](https://github.com/taikoxyz/taiko-mono/commit/04702db23e3fd705133408e077b8d1a040951202))
* **bridge:** bridge transactions ([#411](https://github.com/taikoxyz/taiko-mono/issues/411)) ([19dd7ab](https://github.com/taikoxyz/taiko-mono/commit/19dd7abd4a2f5bc83e43d31938e43501472ff108))
* **bridge:** implement the bridge relayer ([#191](https://github.com/taikoxyz/taiko-mono/issues/191)) ([9f49e4c](https://github.com/taikoxyz/taiko-mono/commit/9f49e4c87304853c9d94693434d23a6b8258eac6))
* implement release-please workflow ([#12967](https://github.com/taikoxyz/taiko-mono/issues/12967)) ([b0c8b60](https://github.com/taikoxyz/taiko-mono/commit/b0c8b60da0af3160db758f83c1f6368a3a712593))
* **protocol:** implement & simulate tokenomics ([#376](https://github.com/taikoxyz/taiko-mono/issues/376)) ([191eb11](https://github.com/taikoxyz/taiko-mono/commit/191eb110990d60b49883eb3f3d7841c33421d067))
* **relayer:** Allow resync flag option to restart processing from block 0 ([#266](https://github.com/taikoxyz/taiko-mono/issues/266)) ([6b01cbe](https://github.com/taikoxyz/taiko-mono/commit/6b01cbe986d61795fc9a2ef256dbe85409251720))
* **relayer:** Asynchronous message processing, error handling, nonce management, and indexer folder structuring ([#259](https://github.com/taikoxyz/taiko-mono/issues/259)) ([ed6d551](https://github.com/taikoxyz/taiko-mono/commit/ed6d551744965440153eaa7a8c42c887fa26938c))
* **relayer:** header sync check before processing messages ([#441](https://github.com/taikoxyz/taiko-mono/issues/441)) ([e9fda8b](https://github.com/taikoxyz/taiko-mono/commit/e9fda8bb80ecfefcfd7d64062b50ebf5b5eec2ef))
* **relayer:** HTTP api for exposing events table for bridge UI ([#271](https://github.com/taikoxyz/taiko-mono/issues/271)) ([7b5e6b8](https://github.com/taikoxyz/taiko-mono/commit/7b5e6b809c0e2f6a8615896d57e2b0d2db98c80b))
* **relayer:** only process profitable transactions ([#408](https://github.com/taikoxyz/taiko-mono/issues/408)) ([b5d8180](https://github.com/taikoxyz/taiko-mono/commit/b5d81802e32b038b5bcdd26f233b0cd4b3eca3fa))
* **relayer:** run in http only mode, so we can scale up if necessary for requests and only have one indexer ([6500234](https://github.com/taikoxyz/taiko-mono/commit/6500234991702b203e6e8baeb496e5473b631f83))
* **relayer:** Wait N confirmations on source chain before processing message on destination chain ([#270](https://github.com/taikoxyz/taiko-mono/issues/270)) ([7ab1291](https://github.com/taikoxyz/taiko-mono/commit/7ab129193f3e08faf04cd1b7e09b5b5994636775))


### Bug Fixes

* **bridge-ui:** Eth fix ([#475](https://github.com/taikoxyz/taiko-mono/issues/475)) ([08175b8](https://github.com/taikoxyz/taiko-mono/commit/08175b803aaabdf6195f5a7a3ed8e0baf9558cc5))
* **protocol:** Remove enableDestChain functionality ([#12341](https://github.com/taikoxyz/taiko-mono/issues/12341)) ([362d083](https://github.com/taikoxyz/taiko-mono/commit/362d083497cc74b3bcd05a406beeff2101a422ef))
* **relayer:** fix migrations ([#300](https://github.com/taikoxyz/taiko-mono/issues/300)) ([151415e](https://github.com/taikoxyz/taiko-mono/commit/151415e71f2b6ac62c607d5cc928fa258064a679))
* **relayer:** gas limit + use loading as priorioty on bridge form ([#487](https://github.com/taikoxyz/taiko-mono/issues/487)) ([3747d4c](https://github.com/taikoxyz/taiko-mono/commit/3747d4c41e836ab533e864ec44073ae681bf4b36))
* **relayer:** save block by chain id ([#379](https://github.com/taikoxyz/taiko-mono/issues/379)) ([608e3e3](https://github.com/taikoxyz/taiko-mono/commit/608e3e3723586f8b412d71118d15f6bab86ad596))
* **tests:** cleanup tests to prepare for tokenomics testing ([#11316](https://github.com/taikoxyz/taiko-mono/issues/11316)) ([d63fae3](https://github.com/taikoxyz/taiko-mono/commit/d63fae30f1e3415d6f377adeab90c062fed5ad42))
