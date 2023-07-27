# Changelog

## [0.9.0](https://github.com/taikoxyz/taiko-mono/compare/eventindexer-v0.8.0...eventindexer-v0.9.0) (2023-07-24)


### Features

* **eventindexer:** speed up sync ([#14258](https://github.com/taikoxyz/taiko-mono/issues/14258)) ([d337174](https://github.com/taikoxyz/taiko-mono/commit/d337174742bfd8d9c220fda0a0e1c9626fd571c2))

## [0.8.0](https://github.com/taikoxyz/taiko-mono/compare/eventindexer-v0.7.0...eventindexer-v0.8.0) (2023-07-10)


### Features

* **eventindexer:** galaxe api, 2 indexing, http only mode, event query optimizations ([#14122](https://github.com/taikoxyz/taiko-mono/issues/14122)) ([9c6d918](https://github.com/taikoxyz/taiko-mono/commit/9c6d918c8c7c474da88912fafa59e2a2f054f3b7))
* **eventindexer:** store swap sender correctly, plus check min amt ([#14128](https://github.com/taikoxyz/taiko-mono/issues/14128)) ([67ba5e4](https://github.com/taikoxyz/taiko-mono/commit/67ba5e44eca82c301dcd2a8d3c0909ac080a804c))
* **eventindexer:** support multiple swap pairs ([#14130](https://github.com/taikoxyz/taiko-mono/issues/14130)) ([2f4a0be](https://github.com/taikoxyz/taiko-mono/commit/2f4a0beb1a431c5c7ff40c3c4b7fcecb094d2e52))


### Bug Fixes

* **eventindexer:** missing swap route ([#14126](https://github.com/taikoxyz/taiko-mono/issues/14126)) ([dc7edce](https://github.com/taikoxyz/taiko-mono/commit/dc7edce0163e252600e15e745728d7f476efec4c))
* **eventindexer:** route fix ([#14127](https://github.com/taikoxyz/taiko-mono/issues/14127)) ([03eb96f](https://github.com/taikoxyz/taiko-mono/commit/03eb96fad45365ace3b9662c27bd6bc4c972a676))

## [0.7.0](https://github.com/taikoxyz/taiko-mono/compare/eventindexer-v0.6.0...eventindexer-v0.7.0) (2023-06-26)


### Features

* **eventindexer:** add get events by address/name param for community ([#14025](https://github.com/taikoxyz/taiko-mono/issues/14025)) ([146f8d5](https://github.com/taikoxyz/taiko-mono/commit/146f8d52100c3aa7412549e0703c4fc363a6ec29))
* **protocol:** use ring buffer for ETH deposit and optimize storage ([#13868](https://github.com/taikoxyz/taiko-mono/issues/13868)) ([acffb61](https://github.com/taikoxyz/taiko-mono/commit/acffb61b13b44fd4792e8f4a31498d788ca38961))

## [0.6.0](https://github.com/taikoxyz/taiko-mono/compare/eventindexer-v0.5.0...eventindexer-v0.6.0) (2023-06-12)


### Features

* **eventindexer:** add indexes to querying optimizations ([#13951](https://github.com/taikoxyz/taiko-mono/issues/13951)) ([66649bd](https://github.com/taikoxyz/taiko-mono/commit/66649bd60d163e13b4e91258b4bdc51e204aa110))
* **eventindexer:** handle reorg ([#13841](https://github.com/taikoxyz/taiko-mono/issues/13841)) ([0a26ce5](https://github.com/taikoxyz/taiko-mono/commit/0a26ce58422d2674f1b5cd151c74bb40f2bec17d))
* **status-page:** disable L3 on boolean env var ([#13838](https://github.com/taikoxyz/taiko-mono/issues/13838)) ([fed0ca0](https://github.com/taikoxyz/taiko-mono/commit/fed0ca0e9a9176c3feaae38b426df45e09d9af3a))
* **status-page:** updates for a3 ([#13821](https://github.com/taikoxyz/taiko-mono/issues/13821)) ([7ed816d](https://github.com/taikoxyz/taiko-mono/commit/7ed816d8db7ac75468faa235c09f147db5009034))


### Bug Fixes

* **eventindexer:** Ei lint ([#13959](https://github.com/taikoxyz/taiko-mono/issues/13959)) ([184dd80](https://github.com/taikoxyz/taiko-mono/commit/184dd8043721c18e225bdc6e6b2c71d1a591896c))
* **eventindexer:** int =&gt; string ([#13828](https://github.com/taikoxyz/taiko-mono/issues/13828)) ([d72b97f](https://github.com/taikoxyz/taiko-mono/commit/d72b97fa4163a2e91eda62d9787760d922447429))

## [0.5.0](https://github.com/taikoxyz/taiko-mono/compare/eventindexer-v0.4.0...eventindexer-v0.5.0) (2023-05-26)


### Features

* **eventindexer:** add stats tracking ([#13810](https://github.com/taikoxyz/taiko-mono/issues/13810)) ([bfbbb97](https://github.com/taikoxyz/taiko-mono/commit/bfbbb97fcb67dc33749f0f08f84b8bd54eae9aeb))
* **eventindexer:** Event indexer metrics ([#13762](https://github.com/taikoxyz/taiko-mono/issues/13762)) ([59ed335](https://github.com/taikoxyz/taiko-mono/commit/59ed3355a05c7438813fa11d2f63dc0676602dd6))


### Bug Fixes

* **protocol:** rename treasure to treasury ([#13780](https://github.com/taikoxyz/taiko-mono/issues/13780)) ([ccecd70](https://github.com/taikoxyz/taiko-mono/commit/ccecd708276bce3eca84b92c7c48c95b2156dd18))

## [0.4.0](https://github.com/taikoxyz/taiko-mono/compare/eventindexer-v0.3.0...eventindexer-v0.4.0) (2023-05-11)


### Features

* **protocol:** major protocol upgrade for alpha-3 testnet ([#13640](https://github.com/taikoxyz/taiko-mono/issues/13640)) ([02552f2](https://github.com/taikoxyz/taiko-mono/commit/02552f2aa001893d326062ce627004c61b46cd26))

## [0.3.0](https://github.com/taikoxyz/taiko-mono/compare/eventindexer-v0.2.1...eventindexer-v0.3.0) (2023-04-27)


### Features

* **eventindexer:** ProposeEvents filtering, API exposing, and getting count by address/event + tests ([#13624](https://github.com/taikoxyz/taiko-mono/issues/13624)) ([839a0be](https://github.com/taikoxyz/taiko-mono/commit/839a0bef7c64dd2b1e2ecc5194cf9a1e29f9a0cd))

## [0.2.1](https://github.com/taikoxyz/taiko-mono/compare/eventindexer-v0.2.0...eventindexer-v0.2.1) (2023-04-08)


### Bug Fixes

* **repo:** fix multiple typos ([#13558](https://github.com/taikoxyz/taiko-mono/issues/13558)) ([f54242a](https://github.com/taikoxyz/taiko-mono/commit/f54242aa95e5c5563f8f0a7f9af0a1eab20ab67b))

## [0.2.0](https://github.com/taikoxyz/taiko-mono/compare/eventindexer-v0.1.0...eventindexer-v0.2.0) (2023-03-29)


### Features

* **eventindexer:** Event indexer ([#13439](https://github.com/taikoxyz/taiko-mono/issues/13439)) ([08b26d2](https://github.com/taikoxyz/taiko-mono/commit/08b26d21577ed8ecd14beed5a600108fe7a0f765))
* **repo:** add eventindexer to the monorepo ([#13471](https://github.com/taikoxyz/taiko-mono/issues/13471)) ([a10d1fe](https://github.com/taikoxyz/taiko-mono/commit/a10d1fe7f7202dd029883ce62a00e188021e09e2))
