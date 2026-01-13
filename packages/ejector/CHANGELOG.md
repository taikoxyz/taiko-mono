# Changelog

## [0.4.0](https://github.com/taikoxyz/taiko-mono/compare/ejector-v0.3.0...ejector-v0.4.0) (2025-12-30)


### Features

* **relayer:** fix few issues in relayer ([#21056](https://github.com/taikoxyz/taiko-mono/issues/21056)) ([25ea270](https://github.com/taikoxyz/taiko-mono/commit/25ea270b7a6d12a49433e29aca5a03e223f76f79))


### Bug Fixes

* **ejector:** make metrics target proposers not sequencers ([#21086](https://github.com/taikoxyz/taiko-mono/issues/21086)) ([29e82a0](https://github.com/taikoxyz/taiko-mono/commit/29e82a0f9b3f4cdfa85d97492d78eed5078e1c76))


### Chores

* **ejector,repo,taiko-client-rs:** improve code comments clarity ([#21055](https://github.com/taikoxyz/taiko-mono/issues/21055)) ([486a6e3](https://github.com/taikoxyz/taiko-mono/commit/486a6e3b1aee009bb963d16e8482643c9a868730))

## [0.3.0](https://github.com/taikoxyz/taiko-mono/compare/ejector-v0.2.0...ejector-v0.3.0) (2025-12-19)


### Features

* **ejector:** add check if L2 is not syncing ([#21034](https://github.com/taikoxyz/taiko-mono/issues/21034)) ([fad36d1](https://github.com/taikoxyz/taiko-mono/commit/fad36d1632b7d3ba14158f2a1ddfb53fb808febe))
* **ejector:** fix the tick duration and simplify config ([#21037](https://github.com/taikoxyz/taiko-mono/issues/21037)) ([461c662](https://github.com/taikoxyz/taiko-mono/commit/461c66257205105440c769742cdc2c1792cef9c6))

## [0.2.0](https://github.com/taikoxyz/taiko-mono/compare/ejector-v0.1.2...ejector-v0.2.0) (2025-12-15)


### Features

* **ejector:** add last_reorged_to metric ([#20953](https://github.com/taikoxyz/taiko-mono/issues/20953)) ([7fa649a](https://github.com/taikoxyz/taiko-mono/commit/7fa649ace7a617a2d4981663060f7128c5706f10))

## [0.1.2](https://github.com/taikoxyz/taiko-mono/compare/ejector-v0.1.1...ejector-v0.1.2) (2025-11-26)


### Bug Fixes

* **ejector:** eject correct operator on reorg, add flag to enable/disable ([#20837](https://github.com/taikoxyz/taiko-mono/issues/20837)) ([ba8fc96](https://github.com/taikoxyz/taiko-mono/commit/ba8fc96649bfde29339bf7ebf60c1d8bd06f8b94))


### Chores

* **deps:** bump the cargo group across 2 directories with 2 updates ([#20822](https://github.com/taikoxyz/taiko-mono/issues/20822)) ([405b4b5](https://github.com/taikoxyz/taiko-mono/commit/405b4b5c9fc605161d3c469febd1ffa1efa22612))

## [0.1.1](https://github.com/taikoxyz/taiko-mono/compare/ejector-v0.1.0...ejector-v0.1.1) (2025-11-21)


### Bug Fixes

* **ejector:** lowercase addresses before metrics init ([#20796](https://github.com/taikoxyz/taiko-mono/issues/20796)) ([3661d09](https://github.com/taikoxyz/taiko-mono/commit/3661d0990243e7cdab7fcba76dd943694420d228))

## [0.1.0](https://github.com/taikoxyz/taiko-mono/compare/ejector-v0.1.0...ejector-v0.1.0) (2025-11-04)


### Features

* **ejector:** check if L1 is syncing and don't eject ([#20577](https://github.com/taikoxyz/taiko-mono/issues/20577)) ([cb70056](https://github.com/taikoxyz/taiko-mono/commit/cb700564998120213a86ea90e0832ca491957037))
* **ejector:** init metrics for each operator so they can be tracked accurately by the alerting system ([#20588](https://github.com/taikoxyz/taiko-mono/issues/20588)) ([b9effdd](https://github.com/taikoxyz/taiko-mono/commit/b9effdde78a9e5f0b2e8f5d2d730038b80c108f4))
* **ejector:** make `ejector` an independent crate ([#20395](https://github.com/taikoxyz/taiko-mono/issues/20395)) ([c0553f2](https://github.com/taikoxyz/taiko-mono/commit/c0553f2ff977f3512f642230ee685c38f2b9cdfc))
* **ejector:** read handover slots from PreconfRouter at epoch start with safe fallback ([#20424](https://github.com/taikoxyz/taiko-mono/issues/20424)) ([5f9eca1](https://github.com/taikoxyz/taiko-mono/commit/5f9eca1084a698ac20051ca0b1be46e8b11f6767))
* **ejector:** track reorgs and eject if greater than threshold ([#20631](https://github.com/taikoxyz/taiko-mono/issues/20631)) ([74bb531](https://github.com/taikoxyz/taiko-mono/commit/74bb5318a5dffd5c54a2f86057f86b5ac1ef5df5))
* **repo:** add whitelist ejector package ([#19907](https://github.com/taikoxyz/taiko-mono/issues/19907)) ([2b592d6](https://github.com/taikoxyz/taiko-mono/commit/2b592d6e6793067ac0568419864d583ca0ae2265))


### Bug Fixes

* **ejector, repo:** refactor ejector `Cargo.toml` into `./packages`, fix `release-please` ([#20391](https://github.com/taikoxyz/taiko-mono/issues/20391)) ([359db1c](https://github.com/taikoxyz/taiko-mono/commit/359db1cc59275188b21cb436d981c9a4b2d4dd24))
* **ejector:** fix docker ci errors ([#20403](https://github.com/taikoxyz/taiko-mono/issues/20403)) ([168350d](https://github.com/taikoxyz/taiko-mono/commit/168350daca5f50103be4023565ad197468348733))


### Chores

* **ejector:** add addtl ejector metrics ([#20570](https://github.com/taikoxyz/taiko-mono/issues/20570)) ([dec0083](https://github.com/taikoxyz/taiko-mono/commit/dec0083cf4b8c9b9db3a4c10885befa1453751f0))
* **ejector:** move root `rust-toolchain.toml` and `rustfmt.toml` into `ejector` ([#20393](https://github.com/taikoxyz/taiko-mono/issues/20393)) ([dda4e37](https://github.com/taikoxyz/taiko-mono/commit/dda4e37dcf21b44e328b1eda56a7675042b25e37))
* **ejector:** validate beacon spec invariants and harden lookahead assert ([#20122](https://github.com/taikoxyz/taiko-mono/issues/20122)) ([29512d4](https://github.com/taikoxyz/taiko-mono/commit/29512d4e481e3f81f095993e121b318bcd4f8f24))
