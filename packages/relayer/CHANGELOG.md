# Changelog

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
