# Changelog

## [1.9.0](https://github.com/taikoxyz/taiko-mono/compare/protocol-v1.8.0...protocol-v1.9.0) (2024-09-09)


### Features

* **protocol:** add `DevnetTaikoL1` ([#17900](https://github.com/taikoxyz/taiko-mono/issues/17900)) ([d864cea](https://github.com/taikoxyz/taiko-mono/commit/d864cea2eb8346127992acfbd9012e675a3400cc))
* **protocol:** add `proveBlocks` method to `ProverSet` ([#18025](https://github.com/taikoxyz/taiko-mono/issues/18025)) ([36a2ae5](https://github.com/taikoxyz/taiko-mono/commit/36a2ae51c21a2359179755457a8933a346ccd8b3))
* **protocol:** add `proveBlocks` to TaikoL1.sol ([fe687b3](https://github.com/taikoxyz/taiko-mono/commit/fe687b378fcb440184fd423088432dc63cf5989e))
* **protocol:** add `TIER_ZKVM_RISC0` tier and `HeklaTierProvider` ([#17913](https://github.com/taikoxyz/taiko-mono/issues/17913)) ([64ed666](https://github.com/taikoxyz/taiko-mono/commit/64ed66628a18cb1b3fff2c4ab5d3c0149288dfe6))
* **protocol:** add a batch proposing block function ([#17864](https://github.com/taikoxyz/taiko-mono/issues/17864)) ([3649785](https://github.com/taikoxyz/taiko-mono/commit/36497857dd3d5edb718a5cb0057327f3cde39c02))
* **protocol:** add ComposeVerifier, TeeAnyVerifier, and ZkAnyVerifier ([ee464ca](https://github.com/taikoxyz/taiko-mono/commit/ee464caef68fdec325aa22758bb69e17dd039794))
* **protocol:** add EIP-2612 (permit extension) to bridged ERC20 tokens ([#17818](https://github.com/taikoxyz/taiko-mono/issues/17818)) ([185ef91](https://github.com/taikoxyz/taiko-mono/commit/185ef91d8debb0c3a88734f2552ca396c8d23a66))
* **protocol:** add preconfirmation support based on https://github.com/taikoxyz/taiko-mono/pull/17654 (with some renaming) (https://github.com/taikoxyz/taiko-mono/issues/14793) ([17d67d7](https://github.com/taikoxyz/taiko-mono/commit/17d67d74c511bc11c2b7d821d8a381f74ef7b6a1))
* **protocol:** add proposeBlock2 in TaikoL1.sol and approve2 in GuardianProver.sol ([17d67d7](https://github.com/taikoxyz/taiko-mono/commit/17d67d74c511bc11c2b7d821d8a381f74ef7b6a1))
* **protocol:** add proposer address to getMinTier func ([#17919](https://github.com/taikoxyz/taiko-mono/issues/17919)) ([d6ea6f3](https://github.com/taikoxyz/taiko-mono/commit/d6ea6f33d6bf54cba3bd6ab153e38d09abf19912))
* **protocol:** add SP1 verification support ([#17861](https://github.com/taikoxyz/taiko-mono/issues/17861)) ([2936312](https://github.com/taikoxyz/taiko-mono/commit/29363123233f9d2d749eb626095d0c645801e384))
* **protocol:** add withdraw eth function to proverset ([#17800](https://github.com/taikoxyz/taiko-mono/issues/17800)) ([bb2abc5](https://github.com/taikoxyz/taiko-mono/commit/bb2abc510c98e62c89e0bfd9382c11720fb9edc7))
* **protocol:** adjust gas excess once the gas target has changed ([a1e217e](https://github.com/taikoxyz/taiko-mono/commit/a1e217e457546d63a89da0b02135b3b63b22d19e))
* **protocol:** allow a grace period (4h) to defer proof submission to reduce cost ([fe687b3](https://github.com/taikoxyz/taiko-mono/commit/fe687b378fcb440184fd423088432dc63cf5989e))
* **protocol:** allow any address to withdraw token to the recipient address ([#17843](https://github.com/taikoxyz/taiko-mono/issues/17843)) ([3d89d24](https://github.com/taikoxyz/taiko-mono/commit/3d89d24b14fea7b9e59659e689c3011fbcf4b852))
* **protocol:** allow contract proposers to use calldata for DA ([17d67d7](https://github.com/taikoxyz/taiko-mono/commit/17d67d74c511bc11c2b7d821d8a381f74ef7b6a1))
* **protocol:** enhance nextTxId logics in  DelegateOwner ([#17718](https://github.com/taikoxyz/taiko-mono/issues/17718)) ([85b2cad](https://github.com/taikoxyz/taiko-mono/commit/85b2cad6216d93e3811bc3523ab8b3200cdfbdd3))
* **protocol:** improve L2 basefee calculation ([920bd68](https://github.com/taikoxyz/taiko-mono/commit/920bd6873d3e9e1bbb00751fb9c0056ac85b8554))
* **protocol:** introduce risc0 proof ([#17877](https://github.com/taikoxyz/taiko-mono/issues/17877)) ([bcb57cb](https://github.com/taikoxyz/taiko-mono/commit/bcb57cb81d12d0c09656582ad9140b38015b3a58))
* **protocol:** protocol monitors ([#18002](https://github.com/taikoxyz/taiko-mono/issues/18002)) ([45b2087](https://github.com/taikoxyz/taiko-mono/commit/45b2087495d4f9e20083ebe2c61ecfe8d252e4b2))
* **protocol:** relocate L2 base fee parameters to L1 configuration ([17d67d7](https://github.com/taikoxyz/taiko-mono/commit/17d67d74c511bc11c2b7d821d8a381f74ef7b6a1))
* **protocol:** return verification timestamp in getLastVerifiedBlock ([#17868](https://github.com/taikoxyz/taiko-mono/issues/17868)) ([1998288](https://github.com/taikoxyz/taiko-mono/commit/19982889f7f4c073d182a6076633c5e2c892c73a))
* **protocol:** revert removing time as input for L2 base fee calculation ([a1e217e](https://github.com/taikoxyz/taiko-mono/commit/a1e217e457546d63a89da0b02135b3b63b22d19e))
* **protocol:** script of `UpgradeRisc0Verifier` ([#17949](https://github.com/taikoxyz/taiko-mono/issues/17949)) ([fc12e04](https://github.com/taikoxyz/taiko-mono/commit/fc12e040c391e0f37c906b270743d3b57710f69d))
* **protocol:** support backward-compatible batch-proof verification ([#17968](https://github.com/taikoxyz/taiko-mono/issues/17968)) ([c476aab](https://github.com/taikoxyz/taiko-mono/commit/c476aabe130d151f5678cd35fab99f258997f629))
* **protocol:** update `HeklaTierProvider` to introduce sp1 proof ([#18022](https://github.com/taikoxyz/taiko-mono/issues/18022)) ([76b6514](https://github.com/taikoxyz/taiko-mono/commit/76b6514fd42ba7fa2124b44443728fa32304c324))
* **protocol:** update `ontakeForkHeight` to Sep 24, 2024 ([#18046](https://github.com/taikoxyz/taiko-mono/issues/18046)) ([30c9316](https://github.com/taikoxyz/taiko-mono/commit/30c9316aea083d187617f5342fb4a955e604226b))
* **protocol:** update Hekla `ontakeForkHeight` ([#17983](https://github.com/taikoxyz/taiko-mono/issues/17983)) ([8819e3a](https://github.com/taikoxyz/taiko-mono/commit/8819e3a5a59675dcc6a1f333620ce6e75b7d2887))
* **protocol:** update Hekla deployment ([#17795](https://github.com/taikoxyz/taiko-mono/issues/17795)) ([cadaef8](https://github.com/taikoxyz/taiko-mono/commit/cadaef882c0751496809c88ee03ff818e49c4b4a))
* **protocol:** update risc0 verifier contract to release-1.0 ([#17776](https://github.com/taikoxyz/taiko-mono/issues/17776)) ([2dd30ab](https://github.com/taikoxyz/taiko-mono/commit/2dd30ab2dc92b25105f19a4bcc1ddf7b40886039))
* **protocol:** update script of deploying sp1 ([#18019](https://github.com/taikoxyz/taiko-mono/issues/18019)) ([9464967](https://github.com/taikoxyz/taiko-mono/commit/94649671bdf0304d96bf83d7d18dcbe21eff6067))
* **protocol:** use SP1 1.2.0-rc with more proof verification tests ([#18001](https://github.com/taikoxyz/taiko-mono/issues/18001)) ([f7bcf1d](https://github.com/taikoxyz/taiko-mono/commit/f7bcf1d63d19b641ac6b9e0e972a7f6e2ec5b38f))


### Bug Fixes

* **protocol:** fix `chainId` in `HeklaTaikoL1` ([#17912](https://github.com/taikoxyz/taiko-mono/issues/17912)) ([8f31dd0](https://github.com/taikoxyz/taiko-mono/commit/8f31dd0ed519809f0ea0797b1e6b5937ee087108))
* **protocol:** fix BridgedERC20V2.sol initializer logic ([#17823](https://github.com/taikoxyz/taiko-mono/issues/17823)) ([d538d99](https://github.com/taikoxyz/taiko-mono/commit/d538d99f9542852821d958008d913c028629bbef))
* **protocol:** fix bug in adjustExcess ([920bd68](https://github.com/taikoxyz/taiko-mono/commit/920bd6873d3e9e1bbb00751fb9c0056ac85b8554))
* **protocol:** fix tier id conflicts ([#18004](https://github.com/taikoxyz/taiko-mono/issues/18004)) ([0df1ad4](https://github.com/taikoxyz/taiko-mono/commit/0df1ad4274e6ebc3db79acbbdaedbe2d519262d6))
* **protocol:** make sure new instance is not zero address in SgxVerifier ([#17918](https://github.com/taikoxyz/taiko-mono/issues/17918)) ([d559ce8](https://github.com/taikoxyz/taiko-mono/commit/d559ce80c1314e9ddbe02798f1c61a2e8349da6e))
* **protocol:** reduce MainnetTaikoL1 code size ([#17792](https://github.com/taikoxyz/taiko-mono/issues/17792)) ([45281b8](https://github.com/taikoxyz/taiko-mono/commit/45281b848f3ef3c45487bfcd1bfd38b382eff4d0))
* **protocol:** use block header's extraData for `basefeeSharingPctg` ([#17889](https://github.com/taikoxyz/taiko-mono/issues/17889)) ([5f3cbc9](https://github.com/taikoxyz/taiko-mono/commit/5f3cbc97cbe2636314c4a2945fdf01ef641702e7))


### Chores

* **protocol:** make two state variables in TaikoL2.sol public and add `adjustExcess` ([#17891](https://github.com/taikoxyz/taiko-mono/issues/17891)) ([ba21f68](https://github.com/taikoxyz/taiko-mono/commit/ba21f6836845ea0227116b701e701815f210d56d))
* **protocol:** move two files to simplify folder structure ([#17929](https://github.com/taikoxyz/taiko-mono/issues/17929)) ([9dca4fa](https://github.com/taikoxyz/taiko-mono/commit/9dca4faa43ad938880c8e1ac54236ab292bcce6e))
* **protocol:** revert `TAIKO_TOKEN` name changes in `DeployOnL1` ([#17927](https://github.com/taikoxyz/taiko-mono/issues/17927)) ([cf1a15f](https://github.com/taikoxyz/taiko-mono/commit/cf1a15f46344e60448c5fdcbcae02521fb5b7c04))


### Documentation

* **docs-site:** address docs and scripts friction points ([#17815](https://github.com/taikoxyz/taiko-mono/issues/17815)) ([c74968b](https://github.com/taikoxyz/taiko-mono/commit/c74968b61828babf218fbc8e8ded001a853a93c3))
* **protocol:** add L2 `DelegateOwner` address in Hekla deployment docs ([#17925](https://github.com/taikoxyz/taiko-mono/issues/17925)) ([fdec8db](https://github.com/taikoxyz/taiko-mono/commit/fdec8dbe8c8aef21f71c9c4ca2213944880c1a47))
* **protocol:** update `tier_router`with compatibility modifications ([#18028](https://github.com/taikoxyz/taiko-mono/issues/18028)) ([c43cb0c](https://github.com/taikoxyz/taiko-mono/commit/c43cb0c05f7cbba281076568f4e72033ebbcd0f3))
* **protocol:** update hekla change log about `tier_router` ([#18023](https://github.com/taikoxyz/taiko-mono/issues/18023)) ([11e27d6](https://github.com/taikoxyz/taiko-mono/commit/11e27d60b3da9a34e07bfafadb8ec3d3223867d2))
* **protocol:** update hekla change log about sp1 ([#18020](https://github.com/taikoxyz/taiko-mono/issues/18020)) ([434bf3c](https://github.com/taikoxyz/taiko-mono/commit/434bf3ccc1715171b8cd4e7581b282f85744ebe3))
* **protocol:** update Hekla deployment ([#17845](https://github.com/taikoxyz/taiko-mono/issues/17845)) ([d95cc36](https://github.com/taikoxyz/taiko-mono/commit/d95cc36260ee4bf2aaf69181fa6444f419cc44af))
* **protocol:** update Hekla deployment ([#17924](https://github.com/taikoxyz/taiko-mono/issues/17924)) ([46a3e00](https://github.com/taikoxyz/taiko-mono/commit/46a3e00659534a715fb315859463bd05bbdb65a9))
* **protocol:** update Hekla deployments ([#17975](https://github.com/taikoxyz/taiko-mono/issues/17975)) ([c96627f](https://github.com/taikoxyz/taiko-mono/commit/c96627fcdd9ba91f26eeea2b329f0eb96dd36660))
* **protocol:** update L1 deployment ([#17789](https://github.com/taikoxyz/taiko-mono/issues/17789)) ([a889f1a](https://github.com/taikoxyz/taiko-mono/commit/a889f1a3e6c27b6758e873572c371ac9399a3d9a))
* **protocol:** update L1 deployment ([#17804](https://github.com/taikoxyz/taiko-mono/issues/17804)) ([25ace9b](https://github.com/taikoxyz/taiko-mono/commit/25ace9bd2b18d91cbf165968cc27d34ccbd7067a))
* **protocol:** update L1 deployment ([#17812](https://github.com/taikoxyz/taiko-mono/issues/17812)) ([5b43df1](https://github.com/taikoxyz/taiko-mono/commit/5b43df170b6f97cb89360e2d210d4a768d9247c3))
* **protocol:** update L1 deployment ([#17817](https://github.com/taikoxyz/taiko-mono/issues/17817)) ([311c948](https://github.com/taikoxyz/taiko-mono/commit/311c948850e8b4d46218fd4aba92d03bc6349445))
* **protocol:** update mainnet deployment ([#17846](https://github.com/taikoxyz/taiko-mono/issues/17846)) ([ba6bf94](https://github.com/taikoxyz/taiko-mono/commit/ba6bf942213468310c6233051a90356268dea70f))
* **protocol:** update mainnet deployment ([#17847](https://github.com/taikoxyz/taiko-mono/issues/17847)) ([92344df](https://github.com/taikoxyz/taiko-mono/commit/92344dfb8c97bae370d722f887fb2c603f96c480))
* **protocol:** upgrade sp1 verifier in hekla ([#18027](https://github.com/taikoxyz/taiko-mono/issues/18027)) ([de27e6e](https://github.com/taikoxyz/taiko-mono/commit/de27e6e586e14410c309e68ce6b81504b9ba9a5b))


### Code Refactoring

* **protocol:** add MainnetGuardianProver ([#17805](https://github.com/taikoxyz/taiko-mono/issues/17805)) ([6f68316](https://github.com/taikoxyz/taiko-mono/commit/6f68316e89373670cf2c58bde5e64de196b9c139))
* **protocol:** add MainnetSgxVerifier ([#17803](https://github.com/taikoxyz/taiko-mono/issues/17803)) ([a4be247](https://github.com/taikoxyz/taiko-mono/commit/a4be247e181861300d79af6454b3fd3776100b48))
* **protocol:** added cached version of the bridge and vaults ([#17801](https://github.com/taikoxyz/taiko-mono/issues/17801)) ([b70cc57](https://github.com/taikoxyz/taiko-mono/commit/b70cc57704d750081a62a7e8e44f68f32efdc4c1))
* **protocol:** avoid writing `livenessBond`, `proposedAt`, and `proposedIn` to storage ([17d67d7](https://github.com/taikoxyz/taiko-mono/commit/17d67d74c511bc11c2b7d821d8a381f74ef7b6a1))
* **protocol:** convert metadata from V2 to V1 only once ([#17842](https://github.com/taikoxyz/taiko-mono/issues/17842)) ([55ced31](https://github.com/taikoxyz/taiko-mono/commit/55ced319d68fe40fe82d1c7e0a268735c3545923))
* **protocol:** delete packages/protocol/contracts/compiled ([#17849](https://github.com/taikoxyz/taiko-mono/issues/17849)) ([1fd907c](https://github.com/taikoxyz/taiko-mono/commit/1fd907cc81807027e730c0e27e258230670522df))
* **protocol:** extract an IBlockHash interface from TaikoL2 ([#18045](https://github.com/taikoxyz/taiko-mono/issues/18045)) ([bff481e](https://github.com/taikoxyz/taiko-mono/commit/bff481e8a2898fab8396d368de84f8f343c532f0))
* **protocol:** improve mainnet gas efficiency with addresses cached ([#17791](https://github.com/taikoxyz/taiko-mono/issues/17791)) ([b12227d](https://github.com/taikoxyz/taiko-mono/commit/b12227d4d2b2636fb80e04ee7ebc2dec3c17faa8))
* **protocol:** improve MainnetSgxVerifier ([#17811](https://github.com/taikoxyz/taiko-mono/issues/17811)) ([4e7a421](https://github.com/taikoxyz/taiko-mono/commit/4e7a421967a4cea897f1ffbeeae254fbcad27117))
* **protocol:** introduce BlockV2 for client-side compability ([#17935](https://github.com/taikoxyz/taiko-mono/issues/17935)) ([e46cf29](https://github.com/taikoxyz/taiko-mono/commit/e46cf294862c293b73b817574669115b85e973a7))
* **protocol:** name address manager param clearer ([#17806](https://github.com/taikoxyz/taiko-mono/issues/17806)) ([1d5a6ff](https://github.com/taikoxyz/taiko-mono/commit/1d5a6ff191e8457ee12c96cb73c074560c556a2a))
* **protocol:** refactor TierProvider implementations ([ee464ca](https://github.com/taikoxyz/taiko-mono/commit/ee464caef68fdec325aa22758bb69e17dd039794))
* **protocol:** remove ProposerAccess for easier composability ([#17994](https://github.com/taikoxyz/taiko-mono/issues/17994)) ([80176a1](https://github.com/taikoxyz/taiko-mono/commit/80176a1525c374039256c779f4a2408971759d22))
* **protocol:** remove the receive function from TaikoL1.sol ([#17865](https://github.com/taikoxyz/taiko-mono/issues/17865)) ([3542420](https://github.com/taikoxyz/taiko-mono/commit/35424204d9f41d49f4a12869ed4410b6de7f577e))
* **protocol:** remove uncessary init2() from TaikoL2 ([#17973](https://github.com/taikoxyz/taiko-mono/issues/17973)) ([4e08881](https://github.com/taikoxyz/taiko-mono/commit/4e0888190e172c950dc5e81a5115ee0fb6df3f11))
* **protocol:** simplify mainnet address caching ([ee464ca](https://github.com/taikoxyz/taiko-mono/commit/ee464caef68fdec325aa22758bb69e17dd039794))
* **protocol:** use npm to manage third-party solidity dependency ([#17881](https://github.com/taikoxyz/taiko-mono/issues/17881)) ([d524e69](https://github.com/taikoxyz/taiko-mono/commit/d524e693449de9d65154471786fa4f5e8c45a381))


### Tests

* **protocol:** add test case of risc0 groth16 ([#17904](https://github.com/taikoxyz/taiko-mono/issues/17904)) ([90bc01d](https://github.com/taikoxyz/taiko-mono/commit/90bc01dfbef1129be1bd94e85c9ecd7c7b28b1da))
* **taiko-client:** use env names which defined in flag configs ([#17921](https://github.com/taikoxyz/taiko-mono/issues/17921)) ([196b74e](https://github.com/taikoxyz/taiko-mono/commit/196b74eb2b4498bc3e6511915e011a885fcc530f))


### Workflow

* **protocol:** upgrade to use solc 0.8.27 ([#18037](https://github.com/taikoxyz/taiko-mono/issues/18037)) ([3a56b57](https://github.com/taikoxyz/taiko-mono/commit/3a56b5788b3e2473381429e5fddfaac2f10fa174))


### Build

* **deps:** bump merkletreejs from 0.3.11 to 0.4.0 ([#17942](https://github.com/taikoxyz/taiko-mono/issues/17942)) ([1624b71](https://github.com/taikoxyz/taiko-mono/commit/1624b711e3fe1862f000e1d2970d6aee1b8990c9))

## [1.8.0](https://github.com/taikoxyz/taiko-mono/compare/protocol-v1.7.0...protocol-v1.8.0) (2024-07-11)


### Features

* **protocol:** allow TAIKO token bonds deposits and withdrawal ([#17725](https://github.com/taikoxyz/taiko-mono/issues/17725)) ([e505392](https://github.com/taikoxyz/taiko-mono/commit/e505392068084faa37b4b0d138ac79012256c692))
* **protocol:** emit CalldataTxList when calldata is used for DA ([#17657](https://github.com/taikoxyz/taiko-mono/issues/17657)) ([f49aae8](https://github.com/taikoxyz/taiko-mono/commit/f49aae828e7c0695be359305c9d618977014c5af))
* **protocol:** update `tier_router` address in `L1RollupAddressManager` ([#17717](https://github.com/taikoxyz/taiko-mono/issues/17717)) ([57c8dc0](https://github.com/taikoxyz/taiko-mono/commit/57c8dc0f0cae430b54d47b12939f1484d6c87184))


### Bug Fixes

* **protocol:** fix an issue in DelegateOwner then refactor the code ([#17633](https://github.com/taikoxyz/taiko-mono/issues/17633)) ([fbeb4e4](https://github.com/taikoxyz/taiko-mono/commit/fbeb4e49d0c183cc687a20b9b5ba7dae5af47d63))
* **protocol:** revert Hekla ring buffer size changes ([#17779](https://github.com/taikoxyz/taiko-mono/issues/17779)) ([e18cb87](https://github.com/taikoxyz/taiko-mono/commit/e18cb8708b61ff1e0bdf2e99433328b1875b6a6c))
* **protocol:** revert last change in TaikoToken.sol ([#17781](https://github.com/taikoxyz/taiko-mono/issues/17781)) ([7805fd3](https://github.com/taikoxyz/taiko-mono/commit/7805fd3a517beb0426848067fbe7f541b4ec6ed3))
* **protocol:** use gasleft() in Bridge's retryMessage function ([#17708](https://github.com/taikoxyz/taiko-mono/issues/17708)) ([d86893c](https://github.com/taikoxyz/taiko-mono/commit/d86893cf0198a13f2710a701ea9c22e15c169de7))


### Chores

* **protocol:** check in data for the first token grant exercise ([#17707](https://github.com/taikoxyz/taiko-mono/issues/17707)) ([d2b00ce](https://github.com/taikoxyz/taiko-mono/commit/d2b00ce914076891c064fbbf280f363329c0f4cb))
* **protocol:** give more slots for verified blocks in ring buffer ([#17762](https://github.com/taikoxyz/taiko-mono/issues/17762)) ([8d6d489](https://github.com/taikoxyz/taiko-mono/commit/8d6d489619996b2749147bebee60ef59d81ac040))


### Documentation

* **docs-site,protocol:** deploy proverset guide and scripts ([#17702](https://github.com/taikoxyz/taiko-mono/issues/17702)) ([a3e1cf7](https://github.com/taikoxyz/taiko-mono/commit/a3e1cf72bc4ad925d3652359a2f4d5fb466b79b0))
* **docs-site,protocol:** streamline ProverSet deployment ([#17730](https://github.com/taikoxyz/taiko-mono/issues/17730)) ([919cb4c](https://github.com/taikoxyz/taiko-mono/commit/919cb4cd0064d1cfa994e53a30a73f98975cfe34))
* **protocol:** add more token unlock contracts ([#17749](https://github.com/taikoxyz/taiko-mono/issues/17749)) ([8c8c7d2](https://github.com/taikoxyz/taiko-mono/commit/8c8c7d27501bdac99de055e9c9a032d60a20f75a))
* **protocol:** deploy more token unlock contract ([#17763](https://github.com/taikoxyz/taiko-mono/issues/17763)) ([30631a9](https://github.com/taikoxyz/taiko-mono/commit/30631a97de10a61aef0938cbfb885af71c9f8dc1))
* **protocol:** transfer Hekla ownerships ([#17766](https://github.com/taikoxyz/taiko-mono/issues/17766)) ([e524782](https://github.com/taikoxyz/taiko-mono/commit/e52478247806437f08af6324cf6097d384ada516))
* **protocol:** update Hekla deployment ([#17646](https://github.com/taikoxyz/taiko-mono/issues/17646)) ([fc12586](https://github.com/taikoxyz/taiko-mono/commit/fc125862c6576ddcbce4d6b8b12161bd6882e304))
* **protocol:** update Hekla deployment ([#17780](https://github.com/taikoxyz/taiko-mono/issues/17780)) ([b3331d3](https://github.com/taikoxyz/taiko-mono/commit/b3331d3fae73b6536a03ab94a42b03042b5c0676))
* **protocol:** update L1 deployment ([#17736](https://github.com/taikoxyz/taiko-mono/issues/17736)) ([6fc318a](https://github.com/taikoxyz/taiko-mono/commit/6fc318afa044eb17d824b00d4d4a487eef2d15a0))
* **protocol:** update L2 deployment ([#17689](https://github.com/taikoxyz/taiko-mono/issues/17689)) ([71eea3f](https://github.com/taikoxyz/taiko-mono/commit/71eea3ff4f4ba9fe7eab89c236cf0b4232294500))


### Code Refactoring

* **protocol:** delete duplicate event and error definition from TaikoL1 ([#17722](https://github.com/taikoxyz/taiko-mono/issues/17722)) ([0607b14](https://github.com/taikoxyz/taiko-mono/commit/0607b14f937b3e461ccc54a8ace21d545d2607e0))
* **protocol:** refactor TaikoL1 contract ([#17678](https://github.com/taikoxyz/taiko-mono/issues/17678)) ([db6ccdf](https://github.com/taikoxyz/taiko-mono/commit/db6ccdfe0141452602ab79177d3c9aa7050ca46b))
* **protocol:** remove unused tier fee in TaikoData ([#17741](https://github.com/taikoxyz/taiko-mono/issues/17741)) ([50abed1](https://github.com/taikoxyz/taiko-mono/commit/50abed1d3a543076cf334263904ba578e961dcd0))

## [1.7.0](https://github.com/taikoxyz/taiko-mono/compare/protocol-v1.6.0...protocol-v1.7.0) (2024-06-20)


### Features

* **protocol:** add getLastVerifiedBlock and getLastSyncedBlock ([#17566](https://github.com/taikoxyz/taiko-mono/issues/17566)) ([cf0743f](https://github.com/taikoxyz/taiko-mono/commit/cf0743fcd48631dbf23cdba8a53343abfb7d5aae))
* **protocol:** add new tcb & add test case ([#17622](https://github.com/taikoxyz/taiko-mono/issues/17622)) ([2384b7c](https://github.com/taikoxyz/taiko-mono/commit/2384b7c73c7b8814cb21ea276865fd92ac509fb1))
* **protocol:** add new tcb & update related tests ([#17545](https://github.com/taikoxyz/taiko-mono/issues/17545)) ([97aa874](https://github.com/taikoxyz/taiko-mono/commit/97aa874e7637d29862f9b78af78e0c7a02bb424a))
* **protocol:** change guardian prover cooldown windows ([#17590](https://github.com/taikoxyz/taiko-mono/issues/17590)) ([cc10b04](https://github.com/taikoxyz/taiko-mono/commit/cc10b04cefa90420325df3626ae22bf3b8149451))
* **protocol:** improve DelegateOwner to have an optional L2 admin ([#17445](https://github.com/taikoxyz/taiko-mono/issues/17445)) ([1c59e8c](https://github.com/taikoxyz/taiko-mono/commit/1c59e8c42d71a900743ba6aaab8642297b29dc92))
* **protocol:** lower liveness, validity, and contestation bonds by 50% ([#17616](https://github.com/taikoxyz/taiko-mono/issues/17616)) ([c9b8d40](https://github.com/taikoxyz/taiko-mono/commit/c9b8d407240720bcf6328569a3c57c830ea79d01))
* **protocol:** persist and compare stateRoot only once per 16 blocks ([b7e12e3](https://github.com/taikoxyz/taiko-mono/commit/b7e12e3c36879361c1bb470e3d6132dfc63150ef))
* **protocol:** remove hook support completely ([b7e12e3](https://github.com/taikoxyz/taiko-mono/commit/b7e12e3c36879361c1bb470e3d6132dfc63150ef))
* **protocol:** require assigned prover to be the block proposer itself ([b7e12e3](https://github.com/taikoxyz/taiko-mono/commit/b7e12e3c36879361c1bb470e3d6132dfc63150ef))
* **protocol:** update Hekla deployment ([#17560](https://github.com/taikoxyz/taiko-mono/issues/17560)) ([bfeadd8](https://github.com/taikoxyz/taiko-mono/commit/bfeadd8f44dc7284e6e8c81cd13e8433ec04e410))
* **protocol:** verify blocks less frequently but more efficiently ([b7e12e3](https://github.com/taikoxyz/taiko-mono/commit/b7e12e3c36879361c1bb470e3d6132dfc63150ef))


### Bug Fixes

* **protocol:** fix an issue for `ProverSet.proposeBlock` ([#17521](https://github.com/taikoxyz/taiko-mono/issues/17521)) ([d3037ad](https://github.com/taikoxyz/taiko-mono/commit/d3037ad6551b5ae6353a360ae3677ec17cd00ec9))
* **protocol:** fix Bridge forwarded gas check and `getMessageMinGasLimit` ([#17529](https://github.com/taikoxyz/taiko-mono/issues/17529)) ([0082c6a](https://github.com/taikoxyz/taiko-mono/commit/0082c6a5dd6e383edf13b8505712d20a86d99cba))
* **protocol:** fix getLastSyncedBlock by writing the block's verifiedTransitionId ([6e07ab5](https://github.com/taikoxyz/taiko-mono/commit/6e07ab5089602ef552592985d230c879b5905312))
* **protocol:** fix in vesting scripts ([#17581](https://github.com/taikoxyz/taiko-mono/issues/17581)) ([5d7b256](https://github.com/taikoxyz/taiko-mono/commit/5d7b256b00e3903ae097ecd24e6ed296a6a17828))
* **protocol:** fix ProverSet permission issue ([#17527](https://github.com/taikoxyz/taiko-mono/issues/17527)) ([98b47d4](https://github.com/taikoxyz/taiko-mono/commit/98b47d421697694db1926486410c08adbf4a6155))
* **protocol:** fix seemingly quota issue ([#17544](https://github.com/taikoxyz/taiko-mono/issues/17544)) ([d083eeb](https://github.com/taikoxyz/taiko-mono/commit/d083eeb29cf7610b733b978e3cfdd0df2d7461f8))
* **protocol:** fix tip payment to L1 block builder ([6e07ab5](https://github.com/taikoxyz/taiko-mono/commit/6e07ab5089602ef552592985d230c879b5905312))


### Chores

* **protocol:** add assumption desc. for IBridgedERC20 ([#17546](https://github.com/taikoxyz/taiko-mono/issues/17546)) ([7fa3b55](https://github.com/taikoxyz/taiko-mono/commit/7fa3b55cc9322d79850bdbfb31def9c0501cf647))
* **protocol:** update TAIKO symbol in protocol deployment logs ([#17555](https://github.com/taikoxyz/taiko-mono/issues/17555)) ([04bb81e](https://github.com/taikoxyz/taiko-mono/commit/04bb81e692348ca7a16bf92588379e047a1bf5f5))


### Documentation

* **protocol:** add open_zeppelin_taiko_protocol_audit_june_2024.pdf ([#17621](https://github.com/taikoxyz/taiko-mono/issues/17621)) ([03cff67](https://github.com/taikoxyz/taiko-mono/commit/03cff6788c3ce1b8b2979beb110336d5383847cf))
* **protocol:** update Hekla deployment ([#17543](https://github.com/taikoxyz/taiko-mono/issues/17543)) ([98beab8](https://github.com/taikoxyz/taiko-mono/commit/98beab8a7de4f365ec76bd6fbffebfcc6fb4505d))
* **protocol:** update Hekla deployment ([#17592](https://github.com/taikoxyz/taiko-mono/issues/17592)) ([6bcda30](https://github.com/taikoxyz/taiko-mono/commit/6bcda306792ff8a15339b3f0ff217929cb7684cf))
* **protocol:** update L1 deployment ([#17513](https://github.com/taikoxyz/taiko-mono/issues/17513)) ([006e522](https://github.com/taikoxyz/taiko-mono/commit/006e522ea962adda0f42bde6e54d3d0e3f901d29))


### Code Refactoring

* **protocol:** avoid unnecessary Signal Service call ([#17516](https://github.com/taikoxyz/taiko-mono/issues/17516)) ([9fac584](https://github.com/taikoxyz/taiko-mono/commit/9fac584a5001d6b5246062cba3f24a374f6697fa))
* **protocol:** optimize storage reads/writes in proveBlock ([#17532](https://github.com/taikoxyz/taiko-mono/issues/17532)) ([ba5c25b](https://github.com/taikoxyz/taiko-mono/commit/ba5c25b4060865b7c36cce8a3d0d86ad930cbc4c))

## [1.6.0](https://github.com/taikoxyz/taiko-mono/compare/protocol-v1.5.0...protocol-v1.6.0) (2024-06-07)


### Features

* **protocol,supplementary-contracts:** relocate & allow TokenUnlock to deploy and own ProverSets ([#17251](https://github.com/taikoxyz/taiko-mono/issues/17251)) ([f3d6ca1](https://github.com/taikoxyz/taiko-mono/commit/f3d6ca1be680f5acb3ca5553954f46bbbfe253ca))
* **protocol:** add `ITierRouter` interface to `DevnetTierProvider` ([#17474](https://github.com/taikoxyz/taiko-mono/issues/17474)) ([d9dd337](https://github.com/taikoxyz/taiko-mono/commit/d9dd337cef43d281173d3484362c09cd4c9f2c79))
* **protocol:** add ProverSet to hold TKO tokens ([#17230](https://github.com/taikoxyz/taiko-mono/issues/17230)) ([b7802b1](https://github.com/taikoxyz/taiko-mono/commit/b7802b15f27a2e8e10a087d04aa1aa131705cca5))
* **protocol:** allow getTransition to be called for all blocks ([#17268](https://github.com/taikoxyz/taiko-mono/issues/17268)) ([bca493f](https://github.com/taikoxyz/taiko-mono/commit/bca493f686181a9bbe9b6722742efa3fa98eaf99))
* **protocol:** allow guardian prover to pause block proving & verification ([#17286](https://github.com/taikoxyz/taiko-mono/issues/17286)) ([b955e0e](https://github.com/taikoxyz/taiko-mono/commit/b955e0e5d592b47f019099043c9e17b88bbd6ae7))
* **protocol:** allow hooks to be empty if prover and proposer are the same addr ([#17511](https://github.com/taikoxyz/taiko-mono/issues/17511)) ([18b1abb](https://github.com/taikoxyz/taiko-mono/commit/18b1abb69f9cbbc1cce2ea01b5e1702f5b9cce46))
* **protocol:** allow L1 bridge to self-delegate any token's voting power ([#17204](https://github.com/taikoxyz/taiko-mono/issues/17204)) ([9bd5efa](https://github.com/taikoxyz/taiko-mono/commit/9bd5efabd8f77d6048517d798fd50595e0b739e6))
* **protocol:** allow QuotaManager to set quota period ([#17497](https://github.com/taikoxyz/taiko-mono/issues/17497)) ([1655aef](https://github.com/taikoxyz/taiko-mono/commit/1655aefee4ef94d4e7380ecee3cb33e8ff65cff8))
* **protocol:** allow tier configuration based on block numbers. ([#17399](https://github.com/taikoxyz/taiko-mono/issues/17399)) ([3e50e1c](https://github.com/taikoxyz/taiko-mono/commit/3e50e1cde3b39f067a3ed1815f2cc94b3dd10ef4))
* **protocol:** change blockMaxProposals from 432_000 to 324000 ([#17499](https://github.com/taikoxyz/taiko-mono/issues/17499)) ([c6d184a](https://github.com/taikoxyz/taiko-mono/commit/c6d184a6d0858860b6c8c258830814452bac6d04))
* **protocol:** deploy `ProverSet` in `DeployOnL1` script ([#17272](https://github.com/taikoxyz/taiko-mono/issues/17272)) ([6e56475](https://github.com/taikoxyz/taiko-mono/commit/6e56475413c3240d56d70d413ca5195cd1ced4cc))
* **protocol:** enable AddressManager not to load from storage ([#17250](https://github.com/taikoxyz/taiko-mono/issues/17250)) ([c8207d3](https://github.com/taikoxyz/taiko-mono/commit/c8207d38bf3356ecbb629e36831de021afb582c5))
* **protocol:** enable permissionless block-proposing ([#17303](https://github.com/taikoxyz/taiko-mono/issues/17303)) ([62dd749](https://github.com/taikoxyz/taiko-mono/commit/62dd74915c61fb9f2c2797c6beb5fdb1f15d6726))
* **protocol:** improve Bridge `gasleft()` validation ([#17422](https://github.com/taikoxyz/taiko-mono/issues/17422)) ([0febafe](https://github.com/taikoxyz/taiko-mono/commit/0febafecafc9d83bed3232db09444ae345798606))
* **protocol:** make AutomataDcapV3Attestation state variables public and emit events ([#17193](https://github.com/taikoxyz/taiko-mono/issues/17193)) ([3740dc0](https://github.com/taikoxyz/taiko-mono/commit/3740dc070ae57ab66051f4ba1c046dd732e90dab))
* **protocol:** optimize assignment hook and prover set for gas  ([#17481](https://github.com/taikoxyz/taiko-mono/issues/17481)) ([984e778](https://github.com/taikoxyz/taiko-mono/commit/984e7782c230fb08afe43230e8215336eb9b9aab))
* **protocol:** reduce gas cost by skipping reading storage for `delegates()` ([#17487](https://github.com/taikoxyz/taiko-mono/issues/17487)) ([f58d22f](https://github.com/taikoxyz/taiko-mono/commit/f58d22f6d0f6bd9bc53492b8efe7de3c642cdcde))
* **protocol:** reduce ring-buffer size to reduce proposer cost ([#17383](https://github.com/taikoxyz/taiko-mono/issues/17383)) ([b335b70](https://github.com/taikoxyz/taiko-mono/commit/b335b7043994cefe75ed56e1ddb658c882655298))
* **protocol:** refactor tier providers and added minority-guardian provers to all providers ([#17169](https://github.com/taikoxyz/taiko-mono/issues/17169)) ([cd51442](https://github.com/taikoxyz/taiko-mono/commit/cd514425511e48b9085cd8fe030d720ca73c0ba2))
* **protocol:** remove a few cached addresses ([#17346](https://github.com/taikoxyz/taiko-mono/issues/17346)) ([e79a367](https://github.com/taikoxyz/taiko-mono/commit/e79a367adb1491dfedd6f85dda87f1818f2bba23))
* **protocol:** update L2 deployment ([#17360](https://github.com/taikoxyz/taiko-mono/issues/17360)) ([e56e290](https://github.com/taikoxyz/taiko-mono/commit/e56e2907651c554b2b4408a304733605fcf2d46b))


### Bug Fixes

* **protocol:** add `receive` function to ProverSet ([#17334](https://github.com/taikoxyz/taiko-mono/issues/17334)) ([161fd8b](https://github.com/taikoxyz/taiko-mono/commit/161fd8bc58872f323e849f755b2a3c4137f865d2))
* **protocol:** be more strict with `changeBridgedToken` ([#17333](https://github.com/taikoxyz/taiko-mono/issues/17333)) ([8d14e84](https://github.com/taikoxyz/taiko-mono/commit/8d14e84e8a9be6816042f04f4f725a1d4ede65fc))
* **protocol:** check special addresses in recallMessage ([#17411](https://github.com/taikoxyz/taiko-mono/issues/17411)) ([304aec2](https://github.com/taikoxyz/taiko-mono/commit/304aec216b605e597b2d11201665adba20a35c2f))
* **protocol:** fix a proving window check bug ([#17376](https://github.com/taikoxyz/taiko-mono/issues/17376)) ([06f97d6](https://github.com/taikoxyz/taiko-mono/commit/06f97d69aeb2ad5526c4f9ddaffacc4ff20ebf70))
* **protocol:** fix AssignmentHook Ether payment issue ([#17495](https://github.com/taikoxyz/taiko-mono/issues/17495)) ([0b1ab18](https://github.com/taikoxyz/taiko-mono/commit/0b1ab18b02d90fe12a39cf6249cb6930716d00fb))
* **protocol:** fix bridge bugs in `getMessageMinGasLimit` ([#17284](https://github.com/taikoxyz/taiko-mono/issues/17284)) ([859f854](https://github.com/taikoxyz/taiko-mono/commit/859f854a6eede02e51da416d210cd0d8809ee226))
* **protocol:** fix Bridge message.fee double spending bug ([#17446](https://github.com/taikoxyz/taiko-mono/issues/17446)) ([1bd3285](https://github.com/taikoxyz/taiko-mono/commit/1bd32850f1014a53be0a67b1d9118c6e9c87442b))
* **protocol:** fix getTierProvider and apply additional gas optimization ([#17488](https://github.com/taikoxyz/taiko-mono/issues/17488)) ([daa7aa7](https://github.com/taikoxyz/taiko-mono/commit/daa7aa73f26b8375f011ba8715a3378cd6be853b))
* **protocol:** fix proving window logic ([#17378](https://github.com/taikoxyz/taiko-mono/issues/17378)) ([9ad6691](https://github.com/taikoxyz/taiko-mono/commit/9ad66915ed47d1eedb0a13f13213eb4d8dffe28f))
* **protocol:** fix tier ID check issue in `GuardianProver.approve()` ([#17170](https://github.com/taikoxyz/taiko-mono/issues/17170)) ([f3dc402](https://github.com/taikoxyz/taiko-mono/commit/f3dc402c798ed7c15a2664e129ef47b3c345f168))
* **protocol:** remove receive function from Bridge ([#17330](https://github.com/taikoxyz/taiko-mono/issues/17330)) ([4ef2847](https://github.com/taikoxyz/taiko-mono/commit/4ef28475dfc61d6a6c877f5d4e2ddee4932d0726))
* **protocol:** resolve conflict ([#17504](https://github.com/taikoxyz/taiko-mono/issues/17504)) ([a2daec6](https://github.com/taikoxyz/taiko-mono/commit/a2daec6c0769512b3dabf206295330280243366a))
* **protocol:** take calldata into account when calculating gas charge ([#17503](https://github.com/taikoxyz/taiko-mono/issues/17503)) ([b41faac](https://github.com/taikoxyz/taiko-mono/commit/b41faac6ef71c0d9588136ea20fbb41de060ccfe))
* **protocol:** verify target address is a contract address in DelegateOwner ([#17328](https://github.com/taikoxyz/taiko-mono/issues/17328)) ([0c3c0e1](https://github.com/taikoxyz/taiko-mono/commit/0c3c0e1b514a6a417d9c8a9e26ac057ef1f3c6e2))


### Reverts

* **protocol:** revert AssignmentHook to production version with only an event removed ([#17512](https://github.com/taikoxyz/taiko-mono/issues/17512)) ([a4a9b98](https://github.com/taikoxyz/taiko-mono/commit/a4a9b986e0f2c1672ba0aed038cca808a6939f12))

## [1.5.0](https://github.com/taikoxyz/taiko-mono/compare/protocol-v1.4.0...protocol-v1.5.0) (2024-05-10)


### Features

* **bridge-ui:** release  ([#17071](https://github.com/taikoxyz/taiko-mono/issues/17071)) ([2fa3ae0](https://github.com/taikoxyz/taiko-mono/commit/2fa3ae0b2b2317a467709110c381878a3a9f8ec6))
* **protocol:** add `BridgedTaikoToken` that inherits `ERC20VotesUpgradeable` ([97a328e](https://github.com/taikoxyz/taiko-mono/commit/97a328e2d947044e5a9bf2273d116ffdb7ad5978))
* **protocol:** add `PAUSE_BRIDGE` env to `DeployOnL1` script ([#16927](https://github.com/taikoxyz/taiko-mono/issues/16927)) ([1045a55](https://github.com/taikoxyz/taiko-mono/commit/1045a55d3499f5295ffb8f041533639ba409ae4d))
* **protocol:** add `PAUSE_TAIKO_L1` config to `DeployOnL1` script ([#16904](https://github.com/taikoxyz/taiko-mono/issues/16904)) ([d8c189f](https://github.com/taikoxyz/taiko-mono/commit/d8c189f79367c1182b5eb6dd6101cdbd8dc460b2))
* **protocol:** add bridge rate limiter for ETH and ERC20s ([#16970](https://github.com/taikoxyz/taiko-mono/issues/16970)) ([d048a28](https://github.com/taikoxyz/taiko-mono/commit/d048a284123706480260cf0435449a779c70209a))
* **protocol:** allow contract owner to mint/burn bridged ERC20 tokens (besides ERC20Vault) ([97a328e](https://github.com/taikoxyz/taiko-mono/commit/97a328e2d947044e5a9bf2273d116ffdb7ad5978))
* **protocol:** allow DelegateOwner to delegatecall for batching ([#17022](https://github.com/taikoxyz/taiko-mono/issues/17022)) ([7e1374e](https://github.com/taikoxyz/taiko-mono/commit/7e1374ee8d4d7b0bc498331949d315e418dca16f))
* **protocol:** allow first block proposer to skip EOA check signature ([#16899](https://github.com/taikoxyz/taiko-mono/issues/16899)) ([f1c6b41](https://github.com/taikoxyz/taiko-mono/commit/f1c6b4178f9a430e4265bae081520f7f7fab93f7))
* **protocol:** allow resetting genesis hash on L1 before 1st block is proposed ([#17078](https://github.com/taikoxyz/taiko-mono/issues/17078)) ([2b4816e](https://github.com/taikoxyz/taiko-mono/commit/2b4816e972da313235559489b6588480af9e45a4))
* **protocol:** bump `GAS_RESERVE` to `800_000` ([#16840](https://github.com/taikoxyz/taiko-mono/issues/16840)) ([63035fd](https://github.com/taikoxyz/taiko-mono/commit/63035fd79befda07af3d90c8b60c75a82201ee5d))
* **protocol:** change min base fee to 0.01 gwei ([#16914](https://github.com/taikoxyz/taiko-mono/issues/16914)) ([8028614](https://github.com/taikoxyz/taiko-mono/commit/8028614fa45983dee9df1d38ededb0620f8d4270))
* **protocol:** change to transfer-and-burn pattern with NFT vaults ([#17049](https://github.com/taikoxyz/taiko-mono/issues/17049)) ([22ac9ae](https://github.com/taikoxyz/taiko-mono/commit/22ac9ae74138ba35fbb02d54e2d914e1e8391085))
* **protocol:** disallow bridged token contract owner to trigger migration directly (must go through ERC20Vault) ([97a328e](https://github.com/taikoxyz/taiko-mono/commit/97a328e2d947044e5a9bf2273d116ffdb7ad5978))
* **protocol:** disallow migration within 90 days post the previous migration ([97a328e](https://github.com/taikoxyz/taiko-mono/commit/97a328e2d947044e5a9bf2273d116ffdb7ad5978))
* **protocol:** execute `enableTaikoTokenAllowance` in `DeployOnL1` script ([#16907](https://github.com/taikoxyz/taiko-mono/issues/16907)) ([83cdbe8](https://github.com/taikoxyz/taiko-mono/commit/83cdbe88fa63630c26d612929a6a122e13814296))
* **protocol:** fix vault name and symbol validation bug with more unit tests ([#17013](https://github.com/taikoxyz/taiko-mono/issues/17013)) ([8532b77](https://github.com/taikoxyz/taiko-mono/commit/8532b7750513b87732340030139513d2b2ee203b))
* **protocol:** implement timestamp based checkpoints for TKO & BridgedERC20 ([#16932](https://github.com/taikoxyz/taiko-mono/issues/16932)) ([56dddf2](https://github.com/taikoxyz/taiko-mono/commit/56dddf2b64778f7b119628b3a5fb50dc4825fd8a))
* **protocol:** improve `TransitionProved` event to include previous prover and contester ([#16967](https://github.com/taikoxyz/taiko-mono/issues/16967)) ([4b4a502](https://github.com/taikoxyz/taiko-mono/commit/4b4a50245184fa5cad24445ab040ddd4ebb4f83b))
* **protocol:** make bridge processMessage return message's status and reason ([277dade](https://github.com/taikoxyz/taiko-mono/commit/277dade2b625bc8eedb3aea58046a24bbc0050a0))
* **protocol:** put automata dcap v3 ra behind proxy ([#16867](https://github.com/taikoxyz/taiko-mono/issues/16867)) ([1282113](https://github.com/taikoxyz/taiko-mono/commit/1282113bb31dfdcf04fdafbeefec18e206d8ae03))
* **protocol:** remove more timelock related code ([#17018](https://github.com/taikoxyz/taiko-mono/issues/17018)) ([88a13b6](https://github.com/taikoxyz/taiko-mono/commit/88a13b65478d96b7538d43561ebd0641514d9511))
* **protocol:** rename `TierProviderV2` to `TierProviderV3` and add a new `TierProviderV2` ([#16908](https://github.com/taikoxyz/taiko-mono/issues/16908)) ([0d5b685](https://github.com/taikoxyz/taiko-mono/commit/0d5b685d3bc9a4ddcbfe788a30b577ebdb7064e1))
* **protocol:** revert [#16967](https://github.com/taikoxyz/taiko-mono/issues/16967) ([#16973](https://github.com/taikoxyz/taiko-mono/issues/16973)) ([a937943](https://github.com/taikoxyz/taiko-mono/commit/a93794323cffe54de922c931bc37339021d835a4))
* **protocol:** safeguard possible failing calls ([#16931](https://github.com/taikoxyz/taiko-mono/issues/16931)) ([0f6b6b5](https://github.com/taikoxyz/taiko-mono/commit/0f6b6b5e27b74ef6e724fa352d2fd5d6f5ea0458))
* **protocol:** update L1 / L2 deployment scripts ([#16913](https://github.com/taikoxyz/taiko-mono/issues/16913)) ([6f1194f](https://github.com/taikoxyz/taiko-mono/commit/6f1194fb139e79ca073239854baca09d6e4ecbdf))
* **protoocl:** make BridgedERC20 no longer inherit `ERC20VotesUpgradeable` ([97a328e](https://github.com/taikoxyz/taiko-mono/commit/97a328e2d947044e5a9bf2273d116ffdb7ad5978))


### Bug Fixes

* **protocol:** allow AddressManager to reference self ([#17070](https://github.com/taikoxyz/taiko-mono/issues/17070)) ([9fbfb84](https://github.com/taikoxyz/taiko-mono/commit/9fbfb8411505ca62136259551cd401d34ee22f81))
* **protocol:** allow TaikoL1 to be paused when initialized  ([#16893](https://github.com/taikoxyz/taiko-mono/issues/16893)) ([22d5d42](https://github.com/taikoxyz/taiko-mono/commit/22d5d42dad0b7f87a285406ba6b1ac9b688aed9e))
* **protocol:** fix a deployment issue in TaikoL1 ([#16897](https://github.com/taikoxyz/taiko-mono/issues/16897)) ([c8384f2](https://github.com/taikoxyz/taiko-mono/commit/c8384f29872f39479cc9af7a486e3483cfd8b26d))
* **protocol:** fix a workflow issue ([#16921](https://github.com/taikoxyz/taiko-mono/issues/16921)) ([a27fdbf](https://github.com/taikoxyz/taiko-mono/commit/a27fdbf60ef51f758c8bd64d37418266e8b22091))
* **protocol:** fix address manager init ([#17075](https://github.com/taikoxyz/taiko-mono/issues/17075)) ([b7bd29c](https://github.com/taikoxyz/taiko-mono/commit/b7bd29ce2041c30f7567b11566c424777fd0cc35))
* **protocol:** fix bridge quota processing in processMessage ([277dade](https://github.com/taikoxyz/taiko-mono/commit/277dade2b625bc8eedb3aea58046a24bbc0050a0))
* **protocol:** fix metadata retrieval in vaults ([#17003](https://github.com/taikoxyz/taiko-mono/issues/17003)) ([658775a](https://github.com/taikoxyz/taiko-mono/commit/658775a09dcbaefc2d1410cad34d88d73367bc49))
* **protocol:** fix vault test failures due to change of Bridge GAS_RESERVE ([#16844](https://github.com/taikoxyz/taiko-mono/issues/16844)) ([bc8708e](https://github.com/taikoxyz/taiko-mono/commit/bc8708e0646a07bcc971d8eeb717a6c05ce53873))
* **protocol:** remove L1/gov/ in favor of Aragon's  ([#16933](https://github.com/taikoxyz/taiko-mono/issues/16933)) ([1573735](https://github.com/taikoxyz/taiko-mono/commit/1573735ef4450d52cdfb00747a095127d3d734c3))
* **protocol:** revert "add batch transfer and burn for BridgedERC721 ([#17058](https://github.com/taikoxyz/taiko-mono/issues/17058)) ([#17066](https://github.com/taikoxyz/taiko-mono/issues/17066)) ([84e3000](https://github.com/taikoxyz/taiko-mono/commit/84e30000cabb24d3603262e91e98bc2abda2390a))
* **protocol:** revert adding batchBurn to IBridgedERC1155 ([#17077](https://github.com/taikoxyz/taiko-mono/issues/17077)) ([4903bec](https://github.com/taikoxyz/taiko-mono/commit/4903bec361a225f3fdbdb287f962a37ee72ae517))

## [1.4.0](https://github.com/taikoxyz/taiko-mono/compare/protocol-v1.3.0...protocol-v1.4.0) (2024-04-25)


### Features

* **protocol:** add `DeployTaikoToken` script ([#16771](https://github.com/taikoxyz/taiko-mono/issues/16771)) ([00f8954](https://github.com/taikoxyz/taiko-mono/commit/00f8954536c3572fe0062b7de0a9537921f38323))
* **protocol:** add a new tier B_TIER_GUARDIAN_MINORITY ([#16790](https://github.com/taikoxyz/taiko-mono/issues/16790)) ([cab4071](https://github.com/taikoxyz/taiko-mono/commit/cab4071e649bdcf122aeca8025d484d5a0a21a47))
* **protocol:** add a script to use native USDC token as the bridged token ([#16812](https://github.com/taikoxyz/taiko-mono/issues/16812)) ([63fe93d](https://github.com/taikoxyz/taiko-mono/commit/63fe93d4787f71f83c402d4603e874f3cd44f53b))
* **protocol:** add back EventProcessed event and improve gas logging in Bridge ([#16760](https://github.com/taikoxyz/taiko-mono/issues/16760)) ([530457b](https://github.com/taikoxyz/taiko-mono/commit/530457b5523057276ea290727af0cc64ec5b78f3))
* **protocol:** allow GuardianProver set TKO allowance for TaikoL1 ([#16831](https://github.com/taikoxyz/taiko-mono/issues/16831)) ([ce7076c](https://github.com/taikoxyz/taiko-mono/commit/ce7076ce8b19a6059bd16579f6366fd07ab38153))
* **protocol:** increase GAS_OVERHEAD value based on testnet data ([#16769](https://github.com/taikoxyz/taiko-mono/issues/16769)) ([fb9334c](https://github.com/taikoxyz/taiko-mono/commit/fb9334c3391dc42972ebf8c3aeac427dc9e8ed5b))
* **protocol:** pause ERC20Vault by default on L2 so owner can deploy native USDC ([#16791](https://github.com/taikoxyz/taiko-mono/issues/16791)) ([cd682a0](https://github.com/taikoxyz/taiko-mono/commit/cd682a02c47a46efd55000fc063dca979f74589f))
* **protocol:** redesign Bridge fee & gasLimit and remove 2-step processing ([#16739](https://github.com/taikoxyz/taiko-mono/issues/16739)) ([3049b0c](https://github.com/taikoxyz/taiko-mono/commit/3049b0c96812d8994117e3bda3bb56c1772b12a3))
* **protocol:** remove ERC20SnapshotUpgradeable from TaikoToken and BrigedERC20 tokens ([#16809](https://github.com/taikoxyz/taiko-mono/issues/16809)) ([f20a02f](https://github.com/taikoxyz/taiko-mono/commit/f20a02f048da1349269da2cc75b61cd8a3c8fd22))
* **protocol:** trigger simultaneous recurring TKO snapshots ([#16715](https://github.com/taikoxyz/taiko-mono/issues/16715)) ([bffc8dc](https://github.com/taikoxyz/taiko-mono/commit/bffc8dc7519d8805d1eebfe4594a7c38519adda7))


### Bug Fixes

* **protocol:** change to transfer and mint pattern with BridgedERC20 tokens ([#16796](https://github.com/taikoxyz/taiko-mono/issues/16796)) ([75841ec](https://github.com/taikoxyz/taiko-mono/commit/75841ecc21b982d48da9ac5576a8013574a39a56))
* **protocol:** fix an issue in `DevnetTierProvider` ([#16798](https://github.com/taikoxyz/taiko-mono/issues/16798)) ([2714dd2](https://github.com/taikoxyz/taiko-mono/commit/2714dd28d74f6e7b9636ffc93726d82993f7ea4d))
* **protocol:** renounce timelock_admin role from msg.sender ([#16751](https://github.com/taikoxyz/taiko-mono/issues/16751)) ([abd18e8](https://github.com/taikoxyz/taiko-mono/commit/abd18e83fe6dfec9e53753d2607af845925e9928))
* **protocol:** revert auto snapshot PR ([#16801](https://github.com/taikoxyz/taiko-mono/issues/16801)) ([ef00cae](https://github.com/taikoxyz/taiko-mono/commit/ef00caecb841c9a2697c4b37a4fe17bfed4665f2))

## [1.3.0](https://github.com/taikoxyz/taiko-mono/compare/protocol-v1.2.0...protocol-v1.3.0) (2024-04-10)


### Features

* **protocol:** add `TaikoL1.getTransition(blockId, transitionID)` function ([2c63cb0](https://github.com/taikoxyz/taiko-mono/commit/2c63cb0c796495948f1dd887662044397394d852))
* **protocol:** allow assigned prover to prove blocks outside proving window (liveness bond not returned) ([2c63cb0](https://github.com/taikoxyz/taiko-mono/commit/2c63cb0c796495948f1dd887662044397394d852))
* **protocol:** allow bridge to fail a message by the owner without retrying it ([#16669](https://github.com/taikoxyz/taiko-mono/issues/16669)) ([dce651e](https://github.com/taikoxyz/taiko-mono/commit/dce651e2647013b0d13d7947e0fd0115f38fe639))
* **protocol:** remove `contestations` from `TransitionState` and events (it's buggy) ([2c63cb0](https://github.com/taikoxyz/taiko-mono/commit/2c63cb0c796495948f1dd887662044397394d852))
* **protocol:** use 35000 as gas limit for sending Ether in Brdge ([#16666](https://github.com/taikoxyz/taiko-mono/issues/16666)) ([4909782](https://github.com/taikoxyz/taiko-mono/commit/4909782194ae025ff78438126c1e595f404e16a9))


### Bug Fixes

* **protocol:** add GovernorSettingsUpgradeable ([#16687](https://github.com/taikoxyz/taiko-mono/issues/16687)) ([eba82ba](https://github.com/taikoxyz/taiko-mono/commit/eba82bad1075afc695f3203304160f26e42627a9))
* **protocol:** check invocation gas limit also in `retryMessage` ([#16660](https://github.com/taikoxyz/taiko-mono/issues/16660)) ([8209a43](https://github.com/taikoxyz/taiko-mono/commit/8209a437436f9a84d1e75bbafe6780952401d6a2))
* **protocol:** check no loops in multi-hop in Bridge ([#16659](https://github.com/taikoxyz/taiko-mono/issues/16659)) ([447cd52](https://github.com/taikoxyz/taiko-mono/commit/447cd5252d141dfd38a2764d570b9168762c0d4b))
* **protocol:** fix potential 1271 signature replay if proposers are smart contracts ([#16665](https://github.com/taikoxyz/taiko-mono/issues/16665)) ([2b27477](https://github.com/taikoxyz/taiko-mono/commit/2b27477ec0f9e5f0e0326d302531f93ff2c65de3))
* **protocol:** return liveness bond only to assigned prover ([2c63cb0](https://github.com/taikoxyz/taiko-mono/commit/2c63cb0c796495948f1dd887662044397394d852))

## [1.2.0](https://github.com/taikoxyz/taiko-mono/compare/protocol-v1.1.0...protocol-v1.2.0) (2024-04-05)


### Features

* **protocol:** add `lastSyncedBlockId ` for L2 DAO vote aggregation ([#16654](https://github.com/taikoxyz/taiko-mono/issues/16654)) ([edbae8d](https://github.com/taikoxyz/taiko-mono/commit/edbae8d42a3929db13965ce5b445449b6372fc6b))
* **protocol:** add a view function isSignalReceived for Bridge relayer/UI ([#16591](https://github.com/taikoxyz/taiko-mono/issues/16591)) ([39d4be6](https://github.com/taikoxyz/taiko-mono/commit/39d4be6e003d5e1c9d182dbaa76c54abe09a6112))
* **protocol:** add readonly functions isMessageFailed & isMessageReceived to Bridge ([#16608](https://github.com/taikoxyz/taiko-mono/issues/16608)) ([2fbd948](https://github.com/taikoxyz/taiko-mono/commit/2fbd94866d5520864de59507239e00fa218ffd06))
* **protocol:** allow ERC20Airdrop.delegateBySig to fail ([#16622](https://github.com/taikoxyz/taiko-mono/issues/16622)) ([d375cc1](https://github.com/taikoxyz/taiko-mono/commit/d375cc13a245880951e71cd18b64a0e2e2d21ada))
* **protocol:** avoid proving-fee payment if amount is 0 ([#16595](https://github.com/taikoxyz/taiko-mono/issues/16595)) ([761a066](https://github.com/taikoxyz/taiko-mono/commit/761a06609cbe498b5ab5877ed81e5d663526c6e0))
* **protocol:** change `INSTANCE_VALIDITY_DELAY` to `0` at first ([#16656](https://github.com/taikoxyz/taiko-mono/issues/16656)) ([86a41ac](https://github.com/taikoxyz/taiko-mono/commit/86a41ac415e76caa3ebd69cea444cb556258f469))
* **protocol:** remove and clear `proposedIn` from TaikoData.Block ([#16630](https://github.com/taikoxyz/taiko-mono/issues/16630)) ([511c18d](https://github.com/taikoxyz/taiko-mono/commit/511c18d4dd949aecbf5892623c541ce50a17518e))
* **protocol:** remove banning address ([#16604](https://github.com/taikoxyz/taiko-mono/issues/16604)) ([c4b705b](https://github.com/taikoxyz/taiko-mono/commit/c4b705b3a977322268ce14eacf2e4f5327536593))
* **protocol:** remove the ETHDeposit feature completely ([#16638](https://github.com/taikoxyz/taiko-mono/issues/16638)) ([643b4b1](https://github.com/taikoxyz/taiko-mono/commit/643b4b1158ae645e9ee4416c4c2fec9dc9395fd7))


### Bug Fixes

* **protocol:** add 1 to _REENTRY_SLOT in EssentialContract ([#16593](https://github.com/taikoxyz/taiko-mono/issues/16593)) ([a381ddd](https://github.com/taikoxyz/taiko-mono/commit/a381dddeae95a715f80a9c21fb8990fe6549a94d))
* **protocol:** call _disableInitializers in AddressResolver's constructor. ([#16564](https://github.com/taikoxyz/taiko-mono/issues/16564)) ([f137077](https://github.com/taikoxyz/taiko-mono/commit/f1370778346db18bd2a85836aeb497314c6ca7d3))
* **protocol:** check 63/64 gasleft() not smaller than specified gaslimit ([#16613](https://github.com/taikoxyz/taiko-mono/issues/16613)) ([12f73cd](https://github.com/taikoxyz/taiko-mono/commit/12f73cda76800ee79d217e8e4b44312689defb05))
* **protocol:** check blob capability in LibProposing using LibNetwork.isDencunSupported ([#16657](https://github.com/taikoxyz/taiko-mono/issues/16657)) ([e787493](https://github.com/taikoxyz/taiko-mono/commit/e787493e02238735b3bb4ff1690f7a02004cbd0c))
* **protocol:** fix a SGX bug in pemCertChainLib ([#16639](https://github.com/taikoxyz/taiko-mono/issues/16639)) ([83db3da](https://github.com/taikoxyz/taiko-mono/commit/83db3da8cb477c3bc7d75254d8bb6b88b8defd36))
* **protocol:** fix bridge unpause will delay execution ([#16612](https://github.com/taikoxyz/taiko-mono/issues/16612)) ([381f8b8](https://github.com/taikoxyz/taiko-mono/commit/381f8b8b180958091187f26f32c514932bc1f7fe))
* **protocol:** fix Bridge.sol gap size ([#16594](https://github.com/taikoxyz/taiko-mono/issues/16594)) ([5f75dd8](https://github.com/taikoxyz/taiko-mono/commit/5f75dd89f4139c4415d874ee10cbb26a5e96d41c))
* **protocol:** fix ERC20Airdrop2.sol with an extended withdrawal window ([#16596](https://github.com/taikoxyz/taiko-mono/issues/16596)) ([bc542d8](https://github.com/taikoxyz/taiko-mono/commit/bc542d89f98bff34a6331a5ed6bb2c9bbe15b148))
* **protocol:** fix guardian prover ([#16606](https://github.com/taikoxyz/taiko-mono/issues/16606)) ([643bd17](https://github.com/taikoxyz/taiko-mono/commit/643bd17c393503ae685df465e58b450192731a6d))
* **protocol:** fix msg.sender == first_proposer bug ([#16605](https://github.com/taikoxyz/taiko-mono/issues/16605)) ([b019975](https://github.com/taikoxyz/taiko-mono/commit/b019975eb2d46251ddc80f0c3650e8e5a89d1dab))
* **protocol:** fix parent metahash check for the first block ([#16607](https://github.com/taikoxyz/taiko-mono/issues/16607)) ([ce9e67b](https://github.com/taikoxyz/taiko-mono/commit/ce9e67b35750b44c841346ed9fe7e8f2affd568f))
* **protocol:** fix signature reuse bug ([#16611](https://github.com/taikoxyz/taiko-mono/issues/16611)) ([ff2dc11](https://github.com/taikoxyz/taiko-mono/commit/ff2dc11f37e07299609c57ba2839a8216ab47b35))
* **protocol:** fix supportsInterface in BaseVault, fix typo and visibility ([#16600](https://github.com/taikoxyz/taiko-mono/issues/16600)) ([f6efe97](https://github.com/taikoxyz/taiko-mono/commit/f6efe975274cd95e33f98de6c6e5d7fc39d21966))
* **protocol:** revert removing `proposedIn` (being used by node/client) ([#16644](https://github.com/taikoxyz/taiko-mono/issues/16644)) ([2c311e1](https://github.com/taikoxyz/taiko-mono/commit/2c311e1aea456bca815f8cbbe42b2f5810d0db9f))
* **protocol:** use signature check to verify if msg.sender is EOA ([#16641](https://github.com/taikoxyz/taiko-mono/issues/16641)) ([b853c08](https://github.com/taikoxyz/taiko-mono/commit/b853c08eb82cf93bba81b51169c1add8b42f4b09))
* **repo:** typos ([#16589](https://github.com/taikoxyz/taiko-mono/issues/16589)) ([8836e50](https://github.com/taikoxyz/taiko-mono/commit/8836e5029d32ca3c7d45321a8e48910680626704))

## [1.1.0](https://github.com/taikoxyz/taiko-mono/compare/protocol-v1.0.0...protocol-v1.1.0) (2024-03-29)


### Features

* **protocol:** Adjust proving reward to increase valid contestation ROI ([37fa853](https://github.com/taikoxyz/taiko-mono/commit/37fa853bd4d560a8ef0301437303f35f0d0c4c92))
* **protocol:** allow L2 contracts to read L2's parent block timestamp ([#16425](https://github.com/taikoxyz/taiko-mono/issues/16425)) ([9b79359](https://github.com/taikoxyz/taiko-mono/commit/9b793599c1fa43620eff1f5e02068a7eb4c693c6))
* **protocol:** allow minGuardians be any value between 0 and numGuardians ([#16384](https://github.com/taikoxyz/taiko-mono/issues/16384)) ([0b1385e](https://github.com/taikoxyz/taiko-mono/commit/0b1385e37b9d17fb9ce41fcb48793fc2b8fc468e))
* **protocol:** Emit event for client / node (Requested by Huan) ([37fa853](https://github.com/taikoxyz/taiko-mono/commit/37fa853bd4d560a8ef0301437303f35f0d0c4c92))
* **protocol:** enable EIP712 signature for TimelockTokenPool ([#16335](https://github.com/taikoxyz/taiko-mono/issues/16335)) ([d93e4c5](https://github.com/taikoxyz/taiko-mono/commit/d93e4c54e37e13ac8a88ae01c732da77a5845c6c))
* **protocol:** improve `_authorizePause` for Bridge  ([#16544](https://github.com/taikoxyz/taiko-mono/issues/16544)) ([f76c705](https://github.com/taikoxyz/taiko-mono/commit/f76c7058cbc3aa6aeb86a147bc9bd041739f382e))
* **protocol:** Improve Bridge `_proveSignalReceived` code readability ([37fa853](https://github.com/taikoxyz/taiko-mono/commit/37fa853bd4d560a8ef0301437303f35f0d0c4c92))
* **protocol:** Improve bridged nft tokens ([37fa853](https://github.com/taikoxyz/taiko-mono/commit/37fa853bd4d560a8ef0301437303f35f0d0c4c92))
* **protocol:** Improve L2 1559 fee calculation code ([37fa853](https://github.com/taikoxyz/taiko-mono/commit/37fa853bd4d560a8ef0301437303f35f0d0c4c92))
* **protocol:** Introduce DelegateOwner to become the owner of all L2 contracts ([37fa853](https://github.com/taikoxyz/taiko-mono/commit/37fa853bd4d560a8ef0301437303f35f0d0c4c92))
* **protocol:** Make each transition contesting only dependent on it's own cooldown period ([37fa853](https://github.com/taikoxyz/taiko-mono/commit/37fa853bd4d560a8ef0301437303f35f0d0c4c92))
* **protocol:** Make testnets and mainnet have the same bridge configuration ([37fa853](https://github.com/taikoxyz/taiko-mono/commit/37fa853bd4d560a8ef0301437303f35f0d0c4c92))
* **protocol:** Rename tier providers ([37fa853](https://github.com/taikoxyz/taiko-mono/commit/37fa853bd4d560a8ef0301437303f35f0d0c4c92))
* **protocol:** risc0 verifier contract ([#16331](https://github.com/taikoxyz/taiko-mono/issues/16331)) ([17abc18](https://github.com/taikoxyz/taiko-mono/commit/17abc189ca3d2752beb5400c036a650fd5b9c895))
* **protocol:** Update chain id for the upcoming Hekla testnet ([37fa853](https://github.com/taikoxyz/taiko-mono/commit/37fa853bd4d560a8ef0301437303f35f0d0c4c92))
* **protocol:** Upgrade solhint to 4.5.2 ([37fa853](https://github.com/taikoxyz/taiko-mono/commit/37fa853bd4d560a8ef0301437303f35f0d0c4c92))
* **protocol:** upgrade to use  OZ 4.9.6 ([#16360](https://github.com/taikoxyz/taiko-mono/issues/16360)) ([2a0fe95](https://github.com/taikoxyz/taiko-mono/commit/2a0fe9526718bdf799874c7f2b0968f3dda7b6f2))
* **relayer:** two-step bridge + watchdog + full merkle proof ([#15669](https://github.com/taikoxyz/taiko-mono/issues/15669)) ([1039a96](https://github.com/taikoxyz/taiko-mono/commit/1039a960f8c0a0896821f067cca1137f108d847d))


### Bug Fixes

* **protocol:** add address manager to taiko token ([#16394](https://github.com/taikoxyz/taiko-mono/issues/16394)) ([c64ec19](https://github.com/taikoxyz/taiko-mono/commit/c64ec193c95113a4c33692289e23e8d9fa864073))
* **protocol:** fix a bug in changeBridgedToken ([#16403](https://github.com/taikoxyz/taiko-mono/issues/16403)) ([42c279f](https://github.com/taikoxyz/taiko-mono/commit/42c279f0c8d884e6c3f76a2750d72a856ea6fc70))
* **protocol:** Fix a proving bug when top-tier re-approves top-tier (reported by OpenZeppelin and Code4rena) ([37fa853](https://github.com/taikoxyz/taiko-mono/commit/37fa853bd4d560a8ef0301437303f35f0d0c4c92))
* **protocol:** fix bridge bug caused by incorrect check of `receivedAt` (by OZ) ([#16545](https://github.com/taikoxyz/taiko-mono/issues/16545)) ([c879124](https://github.com/taikoxyz/taiko-mono/commit/c8791241e190b884e1ab008ede0d6455f2c708b2))
* **protocol:** fix bridge prove message issue using staticcall ([#16404](https://github.com/taikoxyz/taiko-mono/issues/16404)) ([dd57560](https://github.com/taikoxyz/taiko-mono/commit/dd57560f1f7bad453696044080884533ece05876))
* **protocol:** fix custom coinbase `transferFrom` issue (alternative) ([#16327](https://github.com/taikoxyz/taiko-mono/issues/16327)) ([7423ffa](https://github.com/taikoxyz/taiko-mono/commit/7423ffa2fb2c5df870be9f1f2cab23c3409e5046))
* **protocol:** Fix genesis script by add missing state variables (reported by OpenZeppelin) ([37fa853](https://github.com/taikoxyz/taiko-mono/commit/37fa853bd4d560a8ef0301437303f35f0d0c4c92))
* **protocol:** Fix or improve comments (reported by Code4rena) ([37fa853](https://github.com/taikoxyz/taiko-mono/commit/37fa853bd4d560a8ef0301437303f35f0d0c4c92))
* **protocol:** Fix sender EOA check (reported by OpenZeppelin) ([37fa853](https://github.com/taikoxyz/taiko-mono/commit/37fa853bd4d560a8ef0301437303f35f0d0c4c92))
* **protocol:** make `snapshot` return value ([#16436](https://github.com/taikoxyz/taiko-mono/issues/16436)) ([dcae54a](https://github.com/taikoxyz/taiko-mono/commit/dcae54a8f859aadb4ede4df054cab976984573af))
* **protocol:** Make each transition contesting only dependent on it's own cooldown period (reported by OpenZeppelin) ([37fa853](https://github.com/taikoxyz/taiko-mono/commit/37fa853bd4d560a8ef0301437303f35f0d0c4c92))
* **protocol:** remove the blob-reuse feature ([284447b](https://github.com/taikoxyz/taiko-mono/commit/284447b369edde7b85e92da9ada5fd303c3446f7))

## [1.0.0](https://github.com/taikoxyz/taiko-mono/compare/protocol-v0.15.2...protocol-v1.0.0) (2024-03-01)


### ⚠ BREAKING CHANGES

* **protocol:** fix typos ([#16189](https://github.com/taikoxyz/taiko-mono/issues/16189))
* **protocol:** enforce naming convention ([#16168](https://github.com/taikoxyz/taiko-mono/issues/16168))
* **protocol:** improve signal service and remove ICrossChainSync ([#15859](https://github.com/taikoxyz/taiko-mono/issues/15859))
* **protocol:** re-implement multi-hop bridging with optional caching ([#15761](https://github.com/taikoxyz/taiko-mono/issues/15761))
* **protocol:** improve protocol based on Brecht's internal review ([#15740](https://github.com/taikoxyz/taiko-mono/issues/15740))

### Features

* **protocol, relayer:** Improved Taiko Protocol and Relayer Documentations ([#15440](https://github.com/taikoxyz/taiko-mono/issues/15440)) ([67ca2e1](https://github.com/taikoxyz/taiko-mono/commit/67ca2e1e0bfe5301efa854048cc5cb0f0dafe921))
* **protocol:** add `acceptOwnership` method in deployOnL1 ([#16103](https://github.com/taikoxyz/taiko-mono/issues/16103)) ([745d7d3](https://github.com/taikoxyz/taiko-mono/commit/745d7d38e865bcfed4b19b5e9de1fcb7b4fc8c1d))
* **protocol:** add `AuthorizeTaikoForMultihop ` script ([#15888](https://github.com/taikoxyz/taiko-mono/issues/15888)) ([45aff8e](https://github.com/taikoxyz/taiko-mono/commit/45aff8e971332fb5145aa0d1ec7a2b7ebd46305b))
* **protocol:** add `LibTiers.TIER_GUARDIAN` to `OptimisticTierProvider` ([#15647](https://github.com/taikoxyz/taiko-mono/issues/15647)) ([ee5c855](https://github.com/taikoxyz/taiko-mono/commit/ee5c855012fe4a8c0667111510dc917a465139b1))
* **protocol:** add `OptimisticTierProvider` for client testing ([#15645](https://github.com/taikoxyz/taiko-mono/issues/15645)) ([6569264](https://github.com/taikoxyz/taiko-mono/commit/6569264fc72ed9102fa7532cd8b0fb631f598d3d))
* **protocol:** add `UpgradeTierProvider` script ([#16017](https://github.com/taikoxyz/taiko-mono/issues/16017)) ([a01da46](https://github.com/taikoxyz/taiko-mono/commit/a01da4687f2b26a27dc12958109e5112e87baa60))
* **protocol:** add ERC20Airdrop test and deployment script ([#15752](https://github.com/taikoxyz/taiko-mono/issues/15752)) ([e60588c](https://github.com/taikoxyz/taiko-mono/commit/e60588cd5d455d0237ba7f7860d575a727f52103))
* **protocol:** add GuardianApproval event to GuardianProver ([#15817](https://github.com/taikoxyz/taiko-mono/issues/15817)) ([78f0481](https://github.com/taikoxyz/taiko-mono/commit/78f04812de1bcb22ed40c9ae9b16e42d3d3783c2))
* **protocol:** add message owner parameter to vault operations ([#15770](https://github.com/taikoxyz/taiko-mono/issues/15770)) ([136bdb7](https://github.com/taikoxyz/taiko-mono/commit/136bdb7395f4a30a76884c70310c02645ebaead2))
* **protocol:** add one missing `replaceUUPSImmutableValues` in genesis generation script ([#15479](https://github.com/taikoxyz/taiko-mono/issues/15479)) ([24d73e7](https://github.com/taikoxyz/taiko-mono/commit/24d73e7e8a2bc324068f296cdcaadd0d87441586))
* **protocol:** Add parent's metaHash to assignment ([#15498](https://github.com/taikoxyz/taiko-mono/issues/15498)) ([267e9a0](https://github.com/taikoxyz/taiko-mono/commit/267e9a083033d19adc7a78af1a191cbfa16937b6))
* **protocol:** add QuillAudits report ([#16186](https://github.com/taikoxyz/taiko-mono/issues/16186)) ([b0ce62e](https://github.com/taikoxyz/taiko-mono/commit/b0ce62ed8c55acce04660b39ae1eb677858aabf1))
* **protocol:** Add TaikoGovernor ([#15228](https://github.com/taikoxyz/taiko-mono/issues/15228)) ([f4a007b](https://github.com/taikoxyz/taiko-mono/commit/f4a007b024e5a868a59e9c97125dd9b9d884b45f))
* **protocol:** add various small fixes based on quill report ([#16031](https://github.com/taikoxyz/taiko-mono/issues/16031)) ([1f46b33](https://github.com/taikoxyz/taiko-mono/commit/1f46b336a3ed5c3961424e5182fa43f118349ac6))
* **protocol:** Add votes and snapshot plugin ([#15732](https://github.com/taikoxyz/taiko-mono/issues/15732)) ([45b549b](https://github.com/taikoxyz/taiko-mono/commit/45b549b9790457fe6b9ecb6caccbc4a2cd13abd0))
* **protocol:** added test case for ERC721Airdrop ([#16025](https://github.com/taikoxyz/taiko-mono/issues/16025)) ([c8f6e9b](https://github.com/taikoxyz/taiko-mono/commit/c8f6e9b71ac34b1afb25b9378a496f6a314c9ad3))
* **protocol:** adopt optimism new trie codebase ([#15608](https://github.com/taikoxyz/taiko-mono/issues/15608)) ([f5e7ee1](https://github.com/taikoxyz/taiko-mono/commit/f5e7ee14439c46f7322a0fb9c2cb11f21498b0ca))
* **protocol:** allow bridge to ban addresses ([#15577](https://github.com/taikoxyz/taiko-mono/issues/15577)) ([17b074b](https://github.com/taikoxyz/taiko-mono/commit/17b074bcf1ee15e40a88b7e21504c209f83993bc))
* **protocol:** allow disabling block reuse ([#15916](https://github.com/taikoxyz/taiko-mono/issues/15916)) ([0f314c5](https://github.com/taikoxyz/taiko-mono/commit/0f314c50db866b26998bb35b43d46d15f2083603))
* **protocol:** allow one-tx claim and delegation for bridged ERC20 tokens ([#15727](https://github.com/taikoxyz/taiko-mono/issues/15727)) ([603f24b](https://github.com/taikoxyz/taiko-mono/commit/603f24bb34e9db4378976b0c26312b60a3166318))
* **protocol:** allow setting L2 coinbase ([#15743](https://github.com/taikoxyz/taiko-mono/issues/15743)) ([e3fde54](https://github.com/taikoxyz/taiko-mono/commit/e3fde54c1bcbce1113b631705119d8356f5e8d1e))
* **protocol:** Based Contestable Rollup with multi-proofs and multi-hop bridging ([#14705](https://github.com/taikoxyz/taiko-mono/issues/14705)) ([28000b3](https://github.com/taikoxyz/taiko-mono/commit/28000b3ca67714e4edb00b6416e05303ae2893b5))
* **protocol:** change cooldown and proving window to minutes ([#16063](https://github.com/taikoxyz/taiko-mono/issues/16063)) ([f064224](https://github.com/taikoxyz/taiko-mono/commit/f0642241360630eb549e8125760f8786cd611864))
* **protocol:** check 4844 staticcall return values (TKO-22) ([#15574](https://github.com/taikoxyz/taiko-mono/issues/15574)) ([00a9cd7](https://github.com/taikoxyz/taiko-mono/commit/00a9cd7ee789d635c40f097c06b4dc5b1c5f545f))
* **protocol:** check if addresses ever reregistered in SGXProver ([#15665](https://github.com/taikoxyz/taiko-mono/issues/15665)) ([27c86c1](https://github.com/taikoxyz/taiko-mono/commit/27c86c183e21d6c3137ca63f44c31c3d26e353d9))
* **protocol:** enable remote attestation in SGX prover ([#15559](https://github.com/taikoxyz/taiko-mono/issues/15559)) ([95159d6](https://github.com/taikoxyz/taiko-mono/commit/95159d6c78f53fd490b7210618092dc89c492679))
* **protocol:** enable strike price to token grants ([#15522](https://github.com/taikoxyz/taiko-mono/issues/15522)) ([baefaef](https://github.com/taikoxyz/taiko-mono/commit/baefaef3d0c32fb42c7ed6747c5ce0aad7e66ef5))
* **protocol:** enforce an invocation delay for bridged messages ([#15555](https://github.com/taikoxyz/taiko-mono/issues/15555)) ([59c322d](https://github.com/taikoxyz/taiko-mono/commit/59c322d53775f62693d35f5674633993ba48fe6a))
* **protocol:** enforce initializer call with onlyInitializing modifier ([#16061](https://github.com/taikoxyz/taiko-mono/issues/16061)) ([f3d7d82](https://github.com/taikoxyz/taiko-mono/commit/f3d7d821440c89c42e72b611245077e2cbaf9bb7))
* **protocol:** extend SignalService interface  ([#15969](https://github.com/taikoxyz/taiko-mono/issues/15969)) ([d90e90a](https://github.com/taikoxyz/taiko-mono/commit/d90e90af3e9904f780ebda7c90ea858fdca4c61c))
* **protocol:** fix an function selector issue in `AddSGXVerifierInstances` ([#15392](https://github.com/taikoxyz/taiko-mono/issues/15392)) ([3bf2a01](https://github.com/taikoxyz/taiko-mono/commit/3bf2a0117f77cc575d7c47a97adaf0a5c0c203ce))
* **protocol:** fix issues in AssignmentHook ([#15486](https://github.com/taikoxyz/taiko-mono/issues/15486)) ([a394abd](https://github.com/taikoxyz/taiko-mono/commit/a394abd70575f4472d11bd11ae6767663fb7b324))
* **protocol:** Fix new token migration change ([#15470](https://github.com/taikoxyz/taiko-mono/issues/15470)) ([a7a93c1](https://github.com/taikoxyz/taiko-mono/commit/a7a93c138067e9fbd8f2fa046c8de7a11270fde2))
* **protocol:** fix signal service multi-hop proof verification bugs ([#15680](https://github.com/taikoxyz/taiko-mono/issues/15680)) ([b46269c](https://github.com/taikoxyz/taiko-mono/commit/b46269c891158887bf0a7be47c1370decea30ac8))
* **protocol:** force nonzero blockhash and signalroot ([#15538](https://github.com/taikoxyz/taiko-mono/issues/15538)) ([bc0ca8d](https://github.com/taikoxyz/taiko-mono/commit/bc0ca8d0c60aad14d4bb5952c1219611f651003a))
* **protocol:** get rid of new compiler warnings ([#15613](https://github.com/taikoxyz/taiko-mono/issues/15613)) ([ccee985](https://github.com/taikoxyz/taiko-mono/commit/ccee985408d938b992c65d90902069194dc5b54f))
* **protocol:** getBlock also returns the transition used to verify the block ([#15917](https://github.com/taikoxyz/taiko-mono/issues/15917)) ([e583d99](https://github.com/taikoxyz/taiko-mono/commit/e583d9916378513a17e7b5b06e17a6002ea7f024))
* **protocol:** grant `securityCouncil` the `PROPOSER` role ([#15355](https://github.com/taikoxyz/taiko-mono/issues/15355)) ([d50b276](https://github.com/taikoxyz/taiko-mono/commit/d50b276986379e4e67b22769debb815dd51850f6))
* **protocol:** improve protocol based on Brecht's internal review ([#15740](https://github.com/taikoxyz/taiko-mono/issues/15740)) ([791b139](https://github.com/taikoxyz/taiko-mono/commit/791b139bb0c8533a4f36230db0235afb9ddcd9e5))
* **protocol:** improve signal service and remove ICrossChainSync ([#15859](https://github.com/taikoxyz/taiko-mono/issues/15859)) ([58ffe10](https://github.com/taikoxyz/taiko-mono/commit/58ffe1011a67710277b19d813bd49b530d1ba335))
* **protocol:** make getInvocationDelays return non-zero values for base chains ([#15968](https://github.com/taikoxyz/taiko-mono/issues/15968)) ([bb8aaf4](https://github.com/taikoxyz/taiko-mono/commit/bb8aaf4b95e5ae81221521cd1292c1fc916a0c47))
* **protocol:** move prover assignment verification to hook ([#15208](https://github.com/taikoxyz/taiko-mono/issues/15208)) ([d61af90](https://github.com/taikoxyz/taiko-mono/commit/d61af90b54fba27ee5db074ad0c34c82c6642022))
* **protocol:** multiple improvements & bug fixes ([#15255](https://github.com/taikoxyz/taiko-mono/issues/15255)) ([337c57c](https://github.com/taikoxyz/taiko-mono/commit/337c57c70f3b4ed1df9e6f4b808d814d1f1452e4))
* **protocol:** One grant per address ([#15558](https://github.com/taikoxyz/taiko-mono/issues/15558)) ([0e24d2d](https://github.com/taikoxyz/taiko-mono/commit/0e24d2d3308468e6e74bb757380f85db476d883a))
* **protocol:** re-implement multi-hop bridging with optional caching ([#15761](https://github.com/taikoxyz/taiko-mono/issues/15761)) ([a3a12de](https://github.com/taikoxyz/taiko-mono/commit/a3a12de9accb77f9acada4e608b9c41e7c61bff0))
* **protocol:** remove `hardhat` dependency ([#15442](https://github.com/taikoxyz/taiko-mono/issues/15442)) ([b0ce57e](https://github.com/taikoxyz/taiko-mono/commit/b0ce57e6088dda3bf88329666bd9e7d2b5a1b3d3))
* **protocol:** reserve 2 slots for TaikoData.Transition ([#15716](https://github.com/taikoxyz/taiko-mono/issues/15716)) ([8099bd1](https://github.com/taikoxyz/taiko-mono/commit/8099bd1b1370129a5c9794157aa5028c7b5f29b2))
* **protocol:** Sgx improvements ([#15514](https://github.com/taikoxyz/taiko-mono/issues/15514)) ([47b07bb](https://github.com/taikoxyz/taiko-mono/commit/47b07bb86e082d22ce487fc569176e7d36c39550))
* **protocol:** sync state root rather than signal service's storage root ([#15671](https://github.com/taikoxyz/taiko-mono/issues/15671)) ([ea33e65](https://github.com/taikoxyz/taiko-mono/commit/ea33e655c5d497e29c01c3070c5be36b9e7429ed))
* **protocol:** update `AuthorizeTaikoForMultihop` script ([#16147](https://github.com/taikoxyz/taiko-mono/issues/16147)) ([0b1aa8b](https://github.com/taikoxyz/taiko-mono/commit/0b1aa8b6a77d9aa1fb084fb1bc7fbf7473063bcf))
* **protocol:** update `PlonkVerifier` for A6 ([#15388](https://github.com/taikoxyz/taiko-mono/issues/15388)) ([a510639](https://github.com/taikoxyz/taiko-mono/commit/a510639c7cd03abd21ab18d0e233d4b90d7048aa))
* **protocol:** update `SetRemoteBridgeSuites` to register remote signal services ([#15982](https://github.com/taikoxyz/taiko-mono/issues/15982)) ([11af1cc](https://github.com/taikoxyz/taiko-mono/commit/11af1ccb4ba671543084d1d5b99dfddf4749670f))
* **protocol:** update a protocol comment ([#15493](https://github.com/taikoxyz/taiko-mono/issues/15493)) ([45e79e3](https://github.com/taikoxyz/taiko-mono/commit/45e79e3382db39b25832a2d8dcc30de664986d9d))
* **protocol:** update signal service ownership transfer check in DeployOnL1 ([#16080](https://github.com/taikoxyz/taiko-mono/issues/16080)) ([06a774e](https://github.com/taikoxyz/taiko-mono/commit/06a774e2ff0dec652db07321698ca5fbdd8044e1))
* **protocol:** upgrade scripts for new proxies ([#15452](https://github.com/taikoxyz/taiko-mono/issues/15452)) ([37e6b62](https://github.com/taikoxyz/taiko-mono/commit/37e6b623474b93b5e350513261fb4d71ab00ea72))
* **protocol:** USDCAdaptor deployment script + documentation ([#15478](https://github.com/taikoxyz/taiko-mono/issues/15478)) ([f4b0955](https://github.com/taikoxyz/taiko-mono/commit/f4b0955e08388a7b9a1b741dd77659bed14f3fa1))
* **protocol:** use `blobhash()` and remove `BlobHashReader.yulp` ([#15610](https://github.com/taikoxyz/taiko-mono/issues/15610)) ([d886ad7](https://github.com/taikoxyz/taiko-mono/commit/d886ad7ad6a8b6ff58a2c9f31bbbe3b404ec06c7))
* **protocol:** use Ownable2StepUpgradeable for better security ([#16029](https://github.com/taikoxyz/taiko-mono/issues/16029)) ([9cbfd08](https://github.com/taikoxyz/taiko-mono/commit/9cbfd08f7e691553480b8932aac33cbe6b936156))
* **protocol:** Use taikoL2's address as the treasury address in circuits ([#15350](https://github.com/taikoxyz/taiko-mono/issues/15350)) ([161f4c6](https://github.com/taikoxyz/taiko-mono/commit/161f4c63ccb87f3d845887b933cccce3723d74a5))


### Bug Fixes

* **bug:** handle message.to == signal_service ([#15385](https://github.com/taikoxyz/taiko-mono/issues/15385)) ([cc2b66c](https://github.com/taikoxyz/taiko-mono/commit/cc2b66cc103423a8895bdb594df50090857c4e7c))
* fix an issue in `SetRemoteBridgeSuites` ([1783b5e](https://github.com/taikoxyz/taiko-mono/commit/1783b5ee6fad453c33f93f29dbbe02fe07552540))
* fix SetRemoteBridgeSuites ([#15312](https://github.com/taikoxyz/taiko-mono/issues/15312)) ([ed91300](https://github.com/taikoxyz/taiko-mono/commit/ed913001fe3070e62268c90fa7ed2f77e9545c87))
* fix typos in tests and comments ([#15028](https://github.com/taikoxyz/taiko-mono/issues/15028)) ([54bf597](https://github.com/taikoxyz/taiko-mono/commit/54bf597c89a7f22161eeeffd13c20fe0acb4e2d7))
* **protocol:** add access control to BridgedERC20Base.burn (TKO-08 ) ([#15566](https://github.com/taikoxyz/taiko-mono/issues/15566)) ([9004b04](https://github.com/taikoxyz/taiko-mono/commit/9004b041903a1a89b377f379fce88f944359a772))
* **protocol:** add delete-instance function (TKO16) ([#15629](https://github.com/taikoxyz/taiko-mono/issues/15629)) ([a62a137](https://github.com/taikoxyz/taiko-mono/commit/a62a137f03304f43484f01a61649fcff28ccdc45))
* **protocol:** address miscellaneous feedbacks from Sigma Prime (TKO26) ([#15600](https://github.com/taikoxyz/taiko-mono/issues/15600)) ([760d3dc](https://github.com/taikoxyz/taiko-mono/commit/760d3dc955b503da94d9bc9f2ca08965f07e0b4c))
* **protocol:** allow proposing when proving is paused ([#15796](https://github.com/taikoxyz/taiko-mono/issues/15796)) ([6b46943](https://github.com/taikoxyz/taiko-mono/commit/6b4694390176597dd195bd6fc23b4190e69f25e9))
* **protocol:** block reusability check error fixed (TKO-18) ([#15572](https://github.com/taikoxyz/taiko-mono/issues/15572)) ([27ce911](https://github.com/taikoxyz/taiko-mono/commit/27ce911c9c13650daed8c5da630850c1959106d1))
* **protocol:** Correct decoding (TKO-03) ([#15582](https://github.com/taikoxyz/taiko-mono/issues/15582)) ([dc46b27](https://github.com/taikoxyz/taiko-mono/commit/dc46b27612398dd05e818d7439a8e872a227b603))
* **protocol:** Deposit ether reentrancy (TKO-14) ([#15569](https://github.com/taikoxyz/taiko-mono/issues/15569)) ([7327ff0](https://github.com/taikoxyz/taiko-mono/commit/7327ff0dcd4dcdbcb94681332aad8c30a2ec14e1))
* **protocol:** disallow duplicate hooks ([#15492](https://github.com/taikoxyz/taiko-mono/issues/15492)) ([5bf916d](https://github.com/taikoxyz/taiko-mono/commit/5bf916d6b1bb8dadb1470092247aeb79bdad3229))
* **protocol:** fix Bridge bug in retrying message ([#15403](https://github.com/taikoxyz/taiko-mono/issues/15403)) ([8cb9a64](https://github.com/taikoxyz/taiko-mono/commit/8cb9a64bfeaf4af0116bc130be9d3b1a01afe715))
* **protocol:** fix bridge token transfer check ([#15422](https://github.com/taikoxyz/taiko-mono/issues/15422)) ([a31b91a](https://github.com/taikoxyz/taiko-mono/commit/a31b91afd6f05324257846679ebd8ab14867b7c4))
* **protocol:** fix bug in LibBytesUtils.toBytes32 (TKO-07) ([#15565](https://github.com/taikoxyz/taiko-mono/issues/15565)) ([6def8a3](https://github.com/taikoxyz/taiko-mono/commit/6def8a3598bb6baf21169c402468f973001b8d14))
* **protocol:** fix build error ([#15973](https://github.com/taikoxyz/taiko-mono/issues/15973)) ([f53130c](https://github.com/taikoxyz/taiko-mono/commit/f53130cae8ed108c2c36547130d6e7199db496ee))
* **protocol:** fix chainid check to allow the case where `chainid = type(uint64).max` to still be valid, per the implied intention of type downcasting ([#15792](https://github.com/taikoxyz/taiko-mono/issues/15792)) ([a401622](https://github.com/taikoxyz/taiko-mono/commit/a4016221197b67f6b7228772743380c94ee15969))
* **protocol:** fix cooldown/proof window caused by pausing (TKO-12) ([#15585](https://github.com/taikoxyz/taiko-mono/issues/15585)) ([b2176d3](https://github.com/taikoxyz/taiko-mono/commit/b2176d30868d55342c4ec19271d55999bf6bb0f2))
* **protocol:** fix cooldown/proof window caused by pausing proving (again) ([#15616](https://github.com/taikoxyz/taiko-mono/issues/15616)) ([e43b512](https://github.com/taikoxyz/taiko-mono/commit/e43b5120a9ca65453cefaac4acdd948106888bb8))
* **protocol:** fix encode eth deposit check ([#15793](https://github.com/taikoxyz/taiko-mono/issues/15793)) ([005a37a](https://github.com/taikoxyz/taiko-mono/commit/005a37ad574f59919f816220d728d6ea4002185a))
* **protocol:** fix governor bravo vulnerability ([#15947](https://github.com/taikoxyz/taiko-mono/issues/15947)) ([a631be6](https://github.com/taikoxyz/taiko-mono/commit/a631be668b0bc6829643ccf02023ce13cbf19bc7))
* **protocol:** fix guardian prover bug ([#15528](https://github.com/taikoxyz/taiko-mono/issues/15528)) ([ff8690e](https://github.com/taikoxyz/taiko-mono/commit/ff8690e52f1d4e5e506b156f7e4042cf13d8d858))
* **protocol:** fix isSignalSent bug ([#15970](https://github.com/taikoxyz/taiko-mono/issues/15970)) ([c001cfb](https://github.com/taikoxyz/taiko-mono/commit/c001cfb2cfa9acbee0c9fb19caab7a5f558f3e93))
* **protocol:** fix LibTrieProof.verifyMerkleProof by RLP-encoding the byte32 value first ([#16018](https://github.com/taikoxyz/taiko-mono/issues/16018)) ([e1f21c1](https://github.com/taikoxyz/taiko-mono/commit/e1f21c12cb1347fef6f7795cfd1b55e2f172312f))
* **protocol:** fix recall not working with bridged tokens ([#15679](https://github.com/taikoxyz/taiko-mono/issues/15679)) ([dd2c33d](https://github.com/taikoxyz/taiko-mono/commit/dd2c33d46f6c1b461a7a7a2fb0e6ec647b768973))
* **protocol:** fix revert reading blockhash (TKO-19) ([#15570](https://github.com/taikoxyz/taiko-mono/issues/15570)) ([465f7f4](https://github.com/taikoxyz/taiko-mono/commit/465f7f45511e8ab9c4fde66b2ddc11a9a114db34))
* **protocol:** fix singla service cannot be shared by multiple taiko L1/L2 contracts bug ([#15807](https://github.com/taikoxyz/taiko-mono/issues/15807)) ([a652ae8](https://github.com/taikoxyz/taiko-mono/commit/a652ae8dc0108e2799a449cce4e5f795f87908a1))
* **protocol:** fix some file names of the proxy upgrade scripts ([#15463](https://github.com/taikoxyz/taiko-mono/issues/15463)) ([3430d89](https://github.com/taikoxyz/taiko-mono/commit/3430d89de1d4bc6b4332744daaeac5df2a546fdf))
* **protocol:** Fix taiko token domain separator ([#15717](https://github.com/taikoxyz/taiko-mono/issues/15717)) ([6e2771c](https://github.com/taikoxyz/taiko-mono/commit/6e2771c54e62e73715cfbe2e7d4fc5a2fb54cf5c))
* **protocol:** improve bridge `_proveSignalReceived` and fix genesis test ([#15641](https://github.com/taikoxyz/taiko-mono/issues/15641)) ([15f6995](https://github.com/taikoxyz/taiko-mono/commit/15f6995f82d7456458eeecf098bd0d02bc3afec4))
* **protocol:** mandate bridge message only calls onMessageInvocation ([#15996](https://github.com/taikoxyz/taiko-mono/issues/15996)) ([f7a12b8](https://github.com/taikoxyz/taiko-mono/commit/f7a12b8601937eef97068c3029c91dff431c03a8))
* **protocol:** need to fix a bug in LibTrieProof (or its test) ([#15739](https://github.com/taikoxyz/taiko-mono/issues/15739)) ([ac1ca31](https://github.com/taikoxyz/taiko-mono/commit/ac1ca310846a075a663c119d404dc8f5f591eb9c))
* **protocol:** new way to calculate meta.difficulty (TKO-11) ([#15568](https://github.com/taikoxyz/taiko-mono/issues/15568)) ([8c4b48e](https://github.com/taikoxyz/taiko-mono/commit/8c4b48e4ae2b8300de2282c7843ecf66e2fe22ae))
* **protocol:** Non-recursive abi.encode for Zk Verifier ([#15344](https://github.com/taikoxyz/taiko-mono/issues/15344)) ([8fc51b4](https://github.com/taikoxyz/taiko-mono/commit/8fc51b47d731cee83d57a272601c641573caf77b))
* **protocol:** oz - use excessivelySafeCall instadd of `to.call(...)`  ([#16145](https://github.com/taikoxyz/taiko-mono/issues/16145)) ([8d79dde](https://github.com/taikoxyz/taiko-mono/commit/8d79ddedf1f44b54f0a1750af7997e1adfa0a850))
* **protocol:** prove signal with full merkle proofs against block state roots ([#15683](https://github.com/taikoxyz/taiko-mono/issues/15683)) ([e2f4bc2](https://github.com/taikoxyz/taiko-mono/commit/e2f4bc260c1bf0aa163927252dd737851ed6e63e))
* **protocol:** remove an unused event  ([#16054](https://github.com/taikoxyz/taiko-mono/issues/16054)) ([c7cca7d](https://github.com/taikoxyz/taiko-mono/commit/c7cca7de1c858fc63c4fbd729a031200ea23b203))
* **protocol:** replace `__self` in bytecode for all `EssentialContract`s when generating genesis JSON ([#15476](https://github.com/taikoxyz/taiko-mono/issues/15476)) ([552e983](https://github.com/taikoxyz/taiko-mono/commit/552e98396e9b4534dfb46798cb05d96eab07d448))
* **protocol:** set initial owner in the init() function without `acceptOwnership` ([#16071](https://github.com/taikoxyz/taiko-mono/issues/16071)) ([63cd7d3](https://github.com/taikoxyz/taiko-mono/commit/63cd7d3ba338b026c2d7836181dd9adb34bd6b45))
* **protocol:** sync submodule commits ([#15656](https://github.com/taikoxyz/taiko-mono/issues/15656)) ([986cb63](https://github.com/taikoxyz/taiko-mono/commit/986cb6368d0dac0cf3beb3e6239464091a767ffe))
* **protocol:** tstore is not suppported on L2 now ([#15802](https://github.com/taikoxyz/taiko-mono/issues/15802)) ([f44698e](https://github.com/taikoxyz/taiko-mono/commit/f44698ea21d70782d9b58c400aefda5c7e94ef6e))
* **protocol:** update amounts emitted to match length with tokenIds ([#15898](https://github.com/taikoxyz/taiko-mono/issues/15898)) ([bfa0ca2](https://github.com/taikoxyz/taiko-mono/commit/bfa0ca2a7bc517d10b3eb77962c7a10527f97f14))
* **protocol:** use IERC721Upgradeable instead of ERC721Upgradeable under ERC721Airdrop ([#16059](https://github.com/taikoxyz/taiko-mono/issues/16059)) ([b9ee868](https://github.com/taikoxyz/taiko-mono/commit/b9ee868d8893fd668be6cc209558794843e80b99))
* **protocol:** Use safeMint with ERC721 ([#15636](https://github.com/taikoxyz/taiko-mono/issues/15636)) ([c12e2d7](https://github.com/taikoxyz/taiko-mono/commit/c12e2d75fff02dcd1b0f1edaa1781a30a1d4b4e1))
* **protocol:** use safeTransferFrom (TKO-09) ([#15567](https://github.com/taikoxyz/taiko-mono/issues/15567)) ([30d771c](https://github.com/taikoxyz/taiko-mono/commit/30d771c42bc76a7115dc10a298cd8060fd5262cc))
* **repo:** fix some typos ([#15021](https://github.com/taikoxyz/taiko-mono/issues/15021)) ([5d5b72d](https://github.com/taikoxyz/taiko-mono/commit/5d5b72d7d53dc93abcc73f8d525a5e7dbfaf903d))


### Reverts

* **protocol:** revert update open-zeppelin contracts ([#15896](https://github.com/taikoxyz/taiko-mono/issues/15896)) ([994e29e](https://github.com/taikoxyz/taiko-mono/commit/994e29e67f68b2478c2e79ce28c9542fd048dc3c))


### Documentation

* **protocol:** fix typos ([#16189](https://github.com/taikoxyz/taiko-mono/issues/16189)) ([8546ef5](https://github.com/taikoxyz/taiko-mono/commit/8546ef5c59a7296bc9202afb85cb624df6373949))


### Miscellaneous Chores

* **protocol:** enforce naming convention ([#16168](https://github.com/taikoxyz/taiko-mono/issues/16168)) ([1f6a8af](https://github.com/taikoxyz/taiko-mono/commit/1f6a8afc472b5cbee45ee3cbf6635f140d329673))

## [0.15.2](https://github.com/taikoxyz/taiko-mono/compare/protocol-v0.15.1...protocol-v0.15.2) (2023-10-18)


### Bug Fixes

* **protocol:** fix a bug reported by Quillaudit ([#14938](https://github.com/taikoxyz/taiko-mono/issues/14938)) ([99b200b](https://github.com/taikoxyz/taiko-mono/commit/99b200bad93bcee0d0c9441d0393b2aa48636017))

## [0.15.1](https://github.com/taikoxyz/taiko-mono/compare/protocol-v0.15.0...protocol-v0.15.1) (2023-10-03)


### Bug Fixes

* **protocol:** Fix genesis tests ([#14813](https://github.com/taikoxyz/taiko-mono/issues/14813)) ([a38b1d4](https://github.com/taikoxyz/taiko-mono/commit/a38b1d4a87225b77f86989dc69cbbcebd7f1a7f0))

## [0.15.0](https://github.com/taikoxyz/taiko-mono/compare/protocol-v0.14.0...protocol-v0.15.0) (2023-09-25)


### Features

* **protocol:** make L2 1559 config upgradable ([#14715](https://github.com/taikoxyz/taiko-mono/issues/14715)) ([ee26881](https://github.com/taikoxyz/taiko-mono/commit/ee2688156733d49cbf43c5178211db95a7079b26))
* **protocol:** Modify LibProposing to accept oracle as assigned prover ([#14695](https://github.com/taikoxyz/taiko-mono/issues/14695)) ([52a50b7](https://github.com/taikoxyz/taiko-mono/commit/52a50b7fe5f771a249d6e39b66ebfb77317aa21e))
* **protocol:** update `PlonkVerifier` based on current public input ([#14647](https://github.com/taikoxyz/taiko-mono/issues/14647)) ([9808185](https://github.com/taikoxyz/taiko-mono/commit/9808185af79760f7a3e115ed9ed818f77ed930b2))


### Bug Fixes

* **protocol:** Remove duplicated events during mint and burn ([#14686](https://github.com/taikoxyz/taiko-mono/issues/14686)) ([3ff0018](https://github.com/taikoxyz/taiko-mono/commit/3ff0018e9a36c0aec6ad934a4607c6acbcb4d50b))

## [0.14.0](https://github.com/taikoxyz/taiko-mono/compare/protocol-v0.13.0...protocol-v0.14.0) (2023-09-05)


### Features

* **protocol:** remove an unused flag in `DeployOnL1` script ([#14589](https://github.com/taikoxyz/taiko-mono/issues/14589)) ([a42c17a](https://github.com/taikoxyz/taiko-mono/commit/a42c17ad4e4a3b24d7077b124bf685a04d72224c))
* **protocol:** validate `instance` the old way ([#14639](https://github.com/taikoxyz/taiko-mono/issues/14639)) ([8e8601b](https://github.com/taikoxyz/taiko-mono/commit/8e8601b44227f77444f4cb86406701cf00054ca1))


### Bug Fixes

* **protocol:** block reward must be minted ([#14595](https://github.com/taikoxyz/taiko-mono/issues/14595)) ([e92b1da](https://github.com/taikoxyz/taiko-mono/commit/e92b1da2ced73c2b28a825fce916acededab0a39))
* **protocol:** change transition ID from uint16 to uint32 ([#14620](https://github.com/taikoxyz/taiko-mono/issues/14620)) ([c8969b6](https://github.com/taikoxyz/taiko-mono/commit/c8969b64bbaacf9ec6d239608509424fdc02ee97))
* **protocol:** remove proof from calcInstance calculation ([#14623](https://github.com/taikoxyz/taiko-mono/issues/14623)) ([2eedc33](https://github.com/taikoxyz/taiko-mono/commit/2eedc33c213cb5d0abf9daa8bc9bd21b730ae6af))
* **protocol:** revert impl deployment V2 ([#14621](https://github.com/taikoxyz/taiko-mono/issues/14621)) ([7e59e0b](https://github.com/taikoxyz/taiko-mono/commit/7e59e0b0077e4d81bcd5333bc6f0900e0761d6ea))

## [0.13.0](https://github.com/taikoxyz/taiko-mono/compare/protocol-v0.12.0...protocol-v0.13.0) (2023-08-15)


### Features

* **protocol:** alpha-4 with staking-based tokenomics ([#14065](https://github.com/taikoxyz/taiko-mono/issues/14065)) ([1eeba9d](https://github.com/taikoxyz/taiko-mono/commit/1eeba9d97ed8e6e4a8d07a8b0af163a16fbc9ccf))
* **protocol:** Gas limit behavior changes ([#14339](https://github.com/taikoxyz/taiko-mono/issues/14339)) ([06710eb](https://github.com/taikoxyz/taiko-mono/commit/06710eb41132f7b920d80053ed8b906d90c18bb3))
* **protocol:** LibFixedPointMath contract library license different MAX_EXP_INPUT values ([#14344](https://github.com/taikoxyz/taiko-mono/issues/14344)) ([c6e391d](https://github.com/taikoxyz/taiko-mono/commit/c6e391d37c91623bf2673d86042c17892f5af54c))


### Bug Fixes

* **protocol:** Fix ProverPool bug, clear proverId when exit ([#14411](https://github.com/taikoxyz/taiko-mono/issues/14411)) ([8dd7481](https://github.com/taikoxyz/taiko-mono/commit/8dd7481887a89309154c1fe2be424e41e01d9a0c))

## [0.12.0](https://github.com/taikoxyz/taiko-mono/compare/protocol-v0.11.0...protocol-v0.12.0) (2023-07-24)


### Features

* **website:** Docs Taiko L2 EIP-1559 high level overview ([#14187](https://github.com/taikoxyz/taiko-mono/issues/14187)) ([ac52f57](https://github.com/taikoxyz/taiko-mono/commit/ac52f575b6ac5a173bc6e96679f0614fcd61aa27))


### Bug Fixes

* **repo:** fix typos ([#14165](https://github.com/taikoxyz/taiko-mono/issues/14165)) ([020972a](https://github.com/taikoxyz/taiko-mono/commit/020972acd0e71877b5f0d76e6a5319f5a814038e))

## [0.11.0](https://github.com/taikoxyz/taiko-mono/compare/protocol-v0.10.0...protocol-v0.11.0) (2023-07-10)


### Features

* **protocol:** update PlonkVerifier for new L3 circuits ([#14023](https://github.com/taikoxyz/taiko-mono/issues/14023)) ([9d7bc39](https://github.com/taikoxyz/taiko-mono/commit/9d7bc39c282c6ceb0e62146aa6271d5ceaee7633))

## [0.10.0](https://github.com/taikoxyz/taiko-mono/compare/protocol-v0.9.0...protocol-v0.10.0) (2023-06-26)


### Features

* **protocol:** use ring buffer for ETH deposit and optimize storage ([#13868](https://github.com/taikoxyz/taiko-mono/issues/13868)) ([acffb61](https://github.com/taikoxyz/taiko-mono/commit/acffb61b13b44fd4792e8f4a31498d788ca38961))

## [0.9.0](https://github.com/taikoxyz/taiko-mono/compare/protocol-v0.8.0...protocol-v0.9.0) (2023-06-12)


### Features

* **protocol:** proxy upgrade scripts ([#13944](https://github.com/taikoxyz/taiko-mono/issues/13944)) ([ccef198](https://github.com/taikoxyz/taiko-mono/commit/ccef19838ec3097860e6c6d91df143376c6fbb86))


### Bug Fixes

* **protocol:** fix issue for fee-collecting eth-deposit ([#13864](https://github.com/taikoxyz/taiko-mono/issues/13864)) ([c53b135](https://github.com/taikoxyz/taiko-mono/commit/c53b135aa2e78dc2f829a79c20f12bf2d48a247a))
* **protocol:** hash deposit IDs ([#13853](https://github.com/taikoxyz/taiko-mono/issues/13853)) ([d3aea36](https://github.com/taikoxyz/taiko-mono/commit/d3aea36ce715d45ba444dbc261a3efff4912e9b1))

## [0.8.0](https://github.com/taikoxyz/taiko-mono/compare/protocol-v0.7.0...protocol-v0.8.0) (2023-05-26)


### Features

* **protocol:** Add a setter where all fee calc params can be set with one go ([#13816](https://github.com/taikoxyz/taiko-mono/issues/13816)) ([a78a2f8](https://github.com/taikoxyz/taiko-mono/commit/a78a2f8d6a9f61d3b2ec94fefd7b1faa83da7b3c))
* **protocol:** add overridable getEIP1559Config() to TaikoL2 ([#13815](https://github.com/taikoxyz/taiko-mono/issues/13815)) ([e15a9c1](https://github.com/taikoxyz/taiko-mono/commit/e15a9c18cdecd2d753d3f7384c218ed7e65fab40))
* **protocol:** Add reward and fee fields to events ([#13808](https://github.com/taikoxyz/taiko-mono/issues/13808)) ([10be2fb](https://github.com/taikoxyz/taiko-mono/commit/10be2fbe57b154909c99818ac8f2196276541a9b))
* **protocol:** Add setter to IAddressManager of AddressResolver ([#13799](https://github.com/taikoxyz/taiko-mono/issues/13799)) ([34de89c](https://github.com/taikoxyz/taiko-mono/commit/34de89cdbdc99cd240571c24d6f0bc3770d7f916))
* **protocol:** do not allow using owner() as named address in AddressManager ([#13771](https://github.com/taikoxyz/taiko-mono/issues/13771)) ([12c810f](https://github.com/taikoxyz/taiko-mono/commit/12c810f7f8911bc6b6540bbab276433966f96715))
* **protocol:** Move proofTimeTarget to state var and adjust scripts/tests ([#13769](https://github.com/taikoxyz/taiko-mono/issues/13769)) ([40086b1](https://github.com/taikoxyz/taiko-mono/commit/40086b100e9394d8bb276d7f53018859b1684680))
* **protocol:** Scale up damping factor and flatten curve ([#13809](https://github.com/taikoxyz/taiko-mono/issues/13809)) ([b1dcb59](https://github.com/taikoxyz/taiko-mono/commit/b1dcb591729a382fc10617a409fae6557ac2f4fa))
* **protocol:** update `PlonkVerifier` ([#13805](https://github.com/taikoxyz/taiko-mono/issues/13805)) ([6f9f022](https://github.com/taikoxyz/taiko-mono/commit/6f9f02242b2830c7597f29c1a4d5ee5b2314510c))
* **protocol:** update `PlonkVerifier` based on the latest circuits changes ([#13767](https://github.com/taikoxyz/taiko-mono/issues/13767)) ([a9305d5](https://github.com/taikoxyz/taiko-mono/commit/a9305d552804e0b1b241615de78c1a75179c2f6b))
* **protocol:** update PlonkVerifer ([#13741](https://github.com/taikoxyz/taiko-mono/issues/13741)) ([523f95b](https://github.com/taikoxyz/taiko-mono/commit/523f95b2077dbe119f406d635a96376c169723b1))


### Bug Fixes

* **protocol:** fix `TaikoL1.init()` call arguments in `DeployOnL1` script ([#13774](https://github.com/taikoxyz/taiko-mono/issues/13774)) ([7bffff4](https://github.com/taikoxyz/taiko-mono/commit/7bffff40494c734acc880a976056a24cdea63749))
* **protocol:** Fix name mismatch(build) issue ([#13803](https://github.com/taikoxyz/taiko-mono/issues/13803)) ([e55e39a](https://github.com/taikoxyz/taiko-mono/commit/e55e39a7652e0af484dab9ac58cb2d3e8a668c38))
* **protocol:** rename treasure to treasury ([#13780](https://github.com/taikoxyz/taiko-mono/issues/13780)) ([ccecd70](https://github.com/taikoxyz/taiko-mono/commit/ccecd708276bce3eca84b92c7c48c95b2156dd18))
* **protocol:** Replace LibEthDeposit assembly ([#13781](https://github.com/taikoxyz/taiko-mono/issues/13781)) ([285c756](https://github.com/taikoxyz/taiko-mono/commit/285c756c270fa4041c10aa06d95e2067fcc1b69f))
* **relayer:** Out of gas ([#13778](https://github.com/taikoxyz/taiko-mono/issues/13778)) ([a42a33b](https://github.com/taikoxyz/taiko-mono/commit/a42a33b30bc0daec707ff51cc639c966642e50ca))

## [0.7.0](https://github.com/taikoxyz/taiko-mono/compare/protocol-v0.6.1...protocol-v0.7.0) (2023-05-11)

### Features

- **protocol:** add parentGasUsed to blockproven ([#13704](https://github.com/taikoxyz/taiko-mono/issues/13704)) ([2ce8787](https://github.com/taikoxyz/taiko-mono/commit/2ce8787b66537dd6142a040b223bd1f4d8b19f89))
- **protocol:** add TaikoGovernor and improve TaikoToken ([#13711](https://github.com/taikoxyz/taiko-mono/issues/13711)) ([ad75cd5](https://github.com/taikoxyz/taiko-mono/commit/ad75cd5476d10886b337c8da2e95a2c5ea043a57))
- **protocol:** Change back token decimals ([#13707](https://github.com/taikoxyz/taiko-mono/issues/13707)) ([82f1677](https://github.com/taikoxyz/taiko-mono/commit/82f1677b18c8dd90f2afc3fcefe5f60a9d8df670))
- **protocol:** Introduce oracle prover concept ([#13729](https://github.com/taikoxyz/taiko-mono/issues/13729)) ([e8ba716](https://github.com/taikoxyz/taiko-mono/commit/e8ba7168231f9a8bbef1378fa93448b11c4267ac))
- **protocol:** L2/L3 contracts proxied ([#13725](https://github.com/taikoxyz/taiko-mono/issues/13725)) ([7e6291f](https://github.com/taikoxyz/taiko-mono/commit/7e6291f3be215789759d5d36e2451fab3154979f))
- **protocol:** major protocol upgrade for alpha-3 testnet ([#13640](https://github.com/taikoxyz/taiko-mono/issues/13640)) ([02552f2](https://github.com/taikoxyz/taiko-mono/commit/02552f2aa001893d326062ce627004c61b46cd26))
- **protocol:** make sure system proof delay is proofTimeTarget ([#13742](https://github.com/taikoxyz/taiko-mono/issues/13742)) ([c359dd9](https://github.com/taikoxyz/taiko-mono/commit/c359dd9c39657ca4deac23d8cd7765a5ae58e8f3))

### Bug Fixes

- **protocol:** allow Bridge to receive ETHs from TaikoL1 ([#13737](https://github.com/taikoxyz/taiko-mono/issues/13737)) ([a75609c](https://github.com/taikoxyz/taiko-mono/commit/a75609c02c651e3b374391e5fc7c6c696658ff28))
- **protocol:** fix deployonl1 script ([#13740](https://github.com/taikoxyz/taiko-mono/issues/13740)) ([ec5349a](https://github.com/taikoxyz/taiko-mono/commit/ec5349a9bf3535f5fb5c111555438c156ec53719))

## [0.6.1](https://github.com/taikoxyz/taiko-mono/compare/protocol-v0.6.0...protocol-v0.6.1) (2023-04-08)

### Bug Fixes

- **repo:** fix multiple typos ([#13558](https://github.com/taikoxyz/taiko-mono/issues/13558)) ([f54242a](https://github.com/taikoxyz/taiko-mono/commit/f54242aa95e5c5563f8f0a7f9af0a1eab20ab67b))

## [0.6.0](https://github.com/taikoxyz/taiko-mono/compare/protocol-v0.5.0...protocol-v0.6.0) (2023-03-29)

### Features

- **protocol:** merge alpha 2 to main ([#13369](https://github.com/taikoxyz/taiko-mono/issues/13369)) ([2b9cc64](https://github.com/taikoxyz/taiko-mono/commit/2b9cc6466509372f35109b48c00948d2234b0d59))
- **relayer:** merge alpha-2 to main ([#13376](https://github.com/taikoxyz/taiko-mono/issues/13376)) ([3148f6b](https://github.com/taikoxyz/taiko-mono/commit/3148f6ba955e1b3918289332d2ee30f139edea8b))

### Bug Fixes

- **relayer:** new abi gen bindings ([#13342](https://github.com/taikoxyz/taiko-mono/issues/13342)) ([8655ff1](https://github.com/taikoxyz/taiko-mono/commit/8655ff16f3de7445f01b4fd502d183d93e394e1a))

## [0.5.0](https://github.com/taikoxyz/taiko-mono/compare/protocol-v0.4.0...protocol-v0.5.0) (2023-03-15)

### Features

- **protocol:** let `PlonkVerifier` return `keccak256("taiko")` ([#13277](https://github.com/taikoxyz/taiko-mono/issues/13277)) ([8ca632c](https://github.com/taikoxyz/taiko-mono/commit/8ca632ce9263219a37368d1f0f84a44cbb369794))
- **protocol:** optimize gas for processMessage & retryMessage ([#13181](https://github.com/taikoxyz/taiko-mono/issues/13181)) ([178e382](https://github.com/taikoxyz/taiko-mono/commit/178e3823d9ca8a0396ef2a7198c064368feaca90))
- **protocol:** tokens can only mint once ([#13252](https://github.com/taikoxyz/taiko-mono/issues/13252)) ([72d152b](https://github.com/taikoxyz/taiko-mono/commit/72d152b7d998b9f306a12823df964a2da18687dd))
- **protocol:** update `LibBlockHeader` to hash post Shanghai fork blocks ([#13278](https://github.com/taikoxyz/taiko-mono/issues/13278)) ([2e34634](https://github.com/taikoxyz/taiko-mono/commit/2e34634560a28c356404f2d837d21f2e5e85bfa3))

### Bug Fixes

- **protocol:** fix config.slotSmoothingFactor and getTimeAdjustedFee bug ([#13293](https://github.com/taikoxyz/taiko-mono/issues/13293)) ([18f3d9f](https://github.com/taikoxyz/taiko-mono/commit/18f3d9fcf99691f54b65198618c49e57590b0a84))
- **protocol:** make download solc script can run outside the protocol dir ([#13263](https://github.com/taikoxyz/taiko-mono/issues/13263)) ([7cd7787](https://github.com/taikoxyz/taiko-mono/commit/7cd77873d0ce1e5f8b43167a8009327cca4200c3))
- **protocol:** Wrong calculation when minting ERC20 tokens ([#13250](https://github.com/taikoxyz/taiko-mono/issues/13250)) ([5920b7e](https://github.com/taikoxyz/taiko-mono/commit/5920b7eee377e913c10b5b78384f24712808f179))

## [0.4.0](https://github.com/taikoxyz/taiko-mono/compare/protocol-v0.3.0...protocol-v0.4.0) (2023-03-01)

### Features

- **protocol:** add isEtherReleased to Bridge ([#13204](https://github.com/taikoxyz/taiko-mono/issues/13204)) ([f39e65d](https://github.com/taikoxyz/taiko-mono/commit/f39e65da022b6af6a3f573843743aae9337c0077))
- **protocol:** Additional integration tests, solidity bump, reduce ERC20Vault contract size ([#13155](https://github.com/taikoxyz/taiko-mono/issues/13155)) ([ffdf5db](https://github.com/taikoxyz/taiko-mono/commit/ffdf5db675404d463850fca0b97d37c23cde61a1))
- **protocol:** Change require to custom err in bridge contracts ([#13220](https://github.com/taikoxyz/taiko-mono/issues/13220)) ([6e8cb82](https://github.com/taikoxyz/taiko-mono/commit/6e8cb82b477fa1a3ebf842dc4bf0dd0820d19e07))
- **protocol:** Deploy a FreeMintERC20 and a MayFailFreeMintERC20 on deploy of L1 ([#13222](https://github.com/taikoxyz/taiko-mono/issues/13222)) ([0d3e769](https://github.com/taikoxyz/taiko-mono/commit/0d3e7692489c4ed5eadafae7aebde49000c03a7f))
- **protocol:** disable contracts as msg.sender ([#13206](https://github.com/taikoxyz/taiko-mono/issues/13206)) ([66316e9](https://github.com/taikoxyz/taiko-mono/commit/66316e9cb74a167e1ce437616e47afec95458c6f))
- **protocol:** make custom errors in L1 libs a part of the `TaikoL1.sol`'s ABI ([#13166](https://github.com/taikoxyz/taiko-mono/issues/13166)) ([2943e3e](https://github.com/taikoxyz/taiko-mono/commit/2943e3eeb18c12e5489c8974df6556caadfcb099))
- **protocol:** partially randomize prover reward ([#13184](https://github.com/taikoxyz/taiko-mono/issues/13184)) ([16993cd](https://github.com/taikoxyz/taiko-mono/commit/16993cdb081b831420c7e86d981afd11726197d1))
- **protocol:** update `PlonkVerifier` to accept new public inputs ([#13208](https://github.com/taikoxyz/taiko-mono/issues/13208)) ([9804099](https://github.com/taikoxyz/taiko-mono/commit/9804099ac477d320b3c2019f6565d3caadefdcfb))

### Bug Fixes

- **protocol:** fix `PlonkVerifier`'s name in `AddressManager` ([#13229](https://github.com/taikoxyz/taiko-mono/issues/13229)) ([7170bd9](https://github.com/taikoxyz/taiko-mono/commit/7170bd966b02d986b26baf5991f47015a46cca64))
- **protocol:** fix occasional test failure ([#13173](https://github.com/taikoxyz/taiko-mono/issues/13173)) ([3aaf5dd](https://github.com/taikoxyz/taiko-mono/commit/3aaf5dde644c8069050fcee52f1a9134144a746b))
- **protocol:** use prevrandao for L2 mixHash ([#13157](https://github.com/taikoxyz/taiko-mono/issues/13157)) ([93daca4](https://github.com/taikoxyz/taiko-mono/commit/93daca47e11c31192aaa7f6db93d399a215164ad))

## [0.3.0](https://github.com/taikoxyz/taiko-mono/compare/protocol-v0.2.0...protocol-v0.3.0) (2023-02-15)

### Features

- **protocol:** add a script to calculate `slotSmoothingFactor` ([#13109](https://github.com/taikoxyz/taiko-mono/issues/13109)) ([61dbc23](https://github.com/taikoxyz/taiko-mono/commit/61dbc2304227b8e844fd19a8b7c5f1cf46f79379))
- **protocol:** add more protocol/tokenomics tests ([#12988](https://github.com/taikoxyz/taiko-mono/issues/12988)) ([3a7523f](https://github.com/taikoxyz/taiko-mono/commit/3a7523f0008d58bee3e839bed37d62161aa39b36))
- **protocol:** change statevariables to return a struct ([#13113](https://github.com/taikoxyz/taiko-mono/issues/13113)) ([0bffeb0](https://github.com/taikoxyz/taiko-mono/commit/0bffeb0f3d17938bf2146772962719ae21ce22fa))
- **protocol:** check message.to on source chain as well ([#13107](https://github.com/taikoxyz/taiko-mono/issues/13107)) ([b55a646](https://github.com/taikoxyz/taiko-mono/commit/b55a6461f7bc665254825b7627cf0e2fb91c716f))
- **protocol:** deploy a test ERC-20 token to test bridge ([#13132](https://github.com/taikoxyz/taiko-mono/issues/13132)) ([95596e4](https://github.com/taikoxyz/taiko-mono/commit/95596e4e2bf3506d94d83e85494ddade1f35dc70))
- **protocol:** improve precision for slot-availability multipliers ([#13108](https://github.com/taikoxyz/taiko-mono/issues/13108)) ([3ed5138](https://github.com/taikoxyz/taiko-mono/commit/3ed513850eba361a5ee45fc7143e4dd30c4ed025))
- **protocol:** no longer delete commit records ([#13152](https://github.com/taikoxyz/taiko-mono/issues/13152)) ([edbdd3d](https://github.com/taikoxyz/taiko-mono/commit/edbdd3d2859e2769ef759ae0c1d8936eff4e4a06))
- **protocol:** re-implement bridge receive check ([#13134](https://github.com/taikoxyz/taiko-mono/issues/13134)) ([3c10706](https://github.com/taikoxyz/taiko-mono/commit/3c107066dabb1dda55814c10933d604d5069de93))
- **protocol:** restrict receive()'s msg.sender to vaults ([#13110](https://github.com/taikoxyz/taiko-mono/issues/13110)) ([2d8fa12](https://github.com/taikoxyz/taiko-mono/commit/2d8fa12a72f6850f75adb468d945af080671f3f8))
- **protocol:** revert Bridge receive() checks ([#13128](https://github.com/taikoxyz/taiko-mono/issues/13128)) ([675611d](https://github.com/taikoxyz/taiko-mono/commit/675611d2a765c706d6d308635a5820639cbd39c4))
- **protocol:** update Yul PlonkVerifier ([#13133](https://github.com/taikoxyz/taiko-mono/issues/13133)) ([5d9b063](https://github.com/taikoxyz/taiko-mono/commit/5d9b063ab260476023365856c4bbfee151029995))

### Bug Fixes

- **protocol:** allow resolver to return zero address for EtherVault ([#13083](https://github.com/taikoxyz/taiko-mono/issues/13083)) ([cb34cf0](https://github.com/taikoxyz/taiko-mono/commit/cb34cf0e0fd182feb6eed4abf6ca9f6a2801e5f1))

## [0.2.0](https://github.com/taikoxyz/taiko-mono/compare/protocol-v0.1.0...protocol-v0.2.0) (2023-01-31)

### Features

- **protocol:** add `proto_broker` / `oracle_prover` addresses into `AddressManager` in deploy_L1 script ([#13079](https://github.com/taikoxyz/taiko-mono/issues/13079)) ([f3bea40](https://github.com/taikoxyz/taiko-mono/commit/f3bea40fbcdf4139cc84903ab69d1e0daf641c7c))
- **protocol:** add special logics for alpha-2 testnet ([#12987](https://github.com/taikoxyz/taiko-mono/issues/12987)) ([3b71285](https://github.com/taikoxyz/taiko-mono/commit/3b712857b5d5ede2a3683d949d1974c8cceeb69a))
- **protocol:** deploy the generated Yul plonk verifier ([#13016](https://github.com/taikoxyz/taiko-mono/issues/13016)) ([eb5d564](https://github.com/taikoxyz/taiko-mono/commit/eb5d564ec469b1ec79619b4d563c3f9989d264c2))
- **protocol:** enable two dimensional circuit/verifier lookup. ([#13066](https://github.com/taikoxyz/taiko-mono/issues/13066)) ([51d1f67](https://github.com/taikoxyz/taiko-mono/commit/51d1f67aa45fec8e2de73c1ed5a992306c6339c1))
- **protocol:** implement `Bridge.proveMessageFailed` ([#13004](https://github.com/taikoxyz/taiko-mono/issues/13004)) ([45153d9](https://github.com/taikoxyz/taiko-mono/commit/45153d92cbcd0e80438c925d5ce5c52df3abd696))
- **protocol:** implement releaseEther & releaseERC20 ([#13008](https://github.com/taikoxyz/taiko-mono/issues/13008)) ([088933e](https://github.com/taikoxyz/taiko-mono/commit/088933e74f7163459e328d61d8331235ab87e388))
- **protocol:** improve sync header storage on L2 ([#13041](https://github.com/taikoxyz/taiko-mono/issues/13041)) ([86c9fe4](https://github.com/taikoxyz/taiko-mono/commit/86c9fe44a3200490032610c017bfc88c3a57a8dd))
- **protocol:** temporarily force an `oracle prover` to be the first prover ([#13070](https://github.com/taikoxyz/taiko-mono/issues/13070)) ([d7401a2](https://github.com/taikoxyz/taiko-mono/commit/d7401a20c66a3c52330c4f92c95c71c902d74452))

### Bug Fixes

- **protocol:** fix `test:integration` waiting node timeout ([#13006](https://github.com/taikoxyz/taiko-mono/issues/13006)) ([07debb7](https://github.com/taikoxyz/taiko-mono/commit/07debb779c1a142cf6050c31a5a8c9b72f26d376))
- **protocol:** fix a downloading `solc` binary script bug ([#13074](https://github.com/taikoxyz/taiko-mono/issues/13074)) ([8167e9d](https://github.com/taikoxyz/taiko-mono/commit/8167e9dda0b0f70405e969f590f714b45af5b192))
- **protocol:** fix two protocol bugs ([#13034](https://github.com/taikoxyz/taiko-mono/issues/13034)) ([1bfa69b](https://github.com/taikoxyz/taiko-mono/commit/1bfa69b4458f7edc4b72efe9c2d8cf9c7050853e))
- **protocol:** update `ProofVerifier` address name in `AddressManager` ([#13063](https://github.com/taikoxyz/taiko-mono/issues/13063)) ([4144f4b](https://github.com/taikoxyz/taiko-mono/commit/4144f4bda154116f5e34759ced173a16f409202f))

## [0.1.0](https://github.com/taikoxyz/taiko-mono/compare/protocol-v0.0.1...protocol-v0.1.0) (2023-01-19)

### Features

- **bridge:** add messageStatusSlot function ([#12940](https://github.com/taikoxyz/taiko-mono/issues/12940)) ([9837fa3](https://github.com/taikoxyz/taiko-mono/commit/9837fa3dceb5d702b2247879af52988be4da333d))
- **bridge:** bridge transactions ([#411](https://github.com/taikoxyz/taiko-mono/issues/411)) ([19dd7ab](https://github.com/taikoxyz/taiko-mono/commit/19dd7abd4a2f5bc83e43d31938e43501472ff108))
- **bridge:** implement the bridge relayer ([#191](https://github.com/taikoxyz/taiko-mono/issues/191)) ([9f49e4c](https://github.com/taikoxyz/taiko-mono/commit/9f49e4c87304853c9d94693434d23a6b8258eac6))
- **deployment:** fund L1 bridge ([#400](https://github.com/taikoxyz/taiko-mono/issues/400)) ([e7ef53e](https://github.com/taikoxyz/taiko-mono/commit/e7ef53e27cb906d7128a3e512e7082e4176786e4))
- **docs:** autocommit changes to solidity docs and omit private state vars and functions ([#490](https://github.com/taikoxyz/taiko-mono/issues/490)) ([dbf8db9](https://github.com/taikoxyz/taiko-mono/commit/dbf8db97635e4fa7c1808c55e62c20f5e987935d))
- **genesis:** support deterministic L2 pre-deployed contract addresses ([#358](https://github.com/taikoxyz/taiko-mono/issues/358)) ([cd34f17](https://github.com/taikoxyz/taiko-mono/commit/cd34f17382400f0ee3bfa85c8ef6a1f5acdb749a))
- migrate to nextra ([#12947](https://github.com/taikoxyz/taiko-mono/issues/12947)) ([ac11959](https://github.com/taikoxyz/taiko-mono/commit/ac1195940d1ab450e95367e6008162de1d22f0ab))
- **protocol:** add `TaikoL1.getBlockProvers` ([#340](https://github.com/taikoxyz/taiko-mono/issues/340)) ([c54f810](https://github.com/taikoxyz/taiko-mono/commit/c54f810d3251f97fcc1e061478044b93bfc0cf28))
- **protocol:** allow empty L2 blocks ([#406](https://github.com/taikoxyz/taiko-mono/issues/406)) ([6d1abf7](https://github.com/taikoxyz/taiko-mono/commit/6d1abf7bd8565bf0377a42b823a6ad98959c340a))
- **protocol:** allow whitelisting proposers ([#375](https://github.com/taikoxyz/taiko-mono/issues/375)) ([80b99a4](https://github.com/taikoxyz/taiko-mono/commit/80b99a4afe6f68f9bca6d7b07e584e57c2ea7f0b))
- **protocol:** enhance ZKP handling & change proofs order ([#288](https://github.com/taikoxyz/taiko-mono/issues/288)) ([5fdfdfa](https://github.com/taikoxyz/taiko-mono/commit/5fdfdfad4207792411f5e92dcee5c603dbeaeee3))
- **protocol:** expose getUncleProofDelay function ([#7058](https://github.com/taikoxyz/taiko-mono/issues/7058)) ([dd0f011](https://github.com/taikoxyz/taiko-mono/commit/dd0f01179ab328d0d8ebb20a07204df821b36a77))
- **protocol:** implement & simulate tokenomics ([#376](https://github.com/taikoxyz/taiko-mono/issues/376)) ([191eb11](https://github.com/taikoxyz/taiko-mono/commit/191eb110990d60b49883eb3f3d7841c33421d067))
- **protocol:** invalidBlock must from golden touch address with 0 gasprice ([#482](https://github.com/taikoxyz/taiko-mono/issues/482)) ([ecb9cc5](https://github.com/taikoxyz/taiko-mono/commit/ecb9cc543513e61ae9efbdfb17cacda87ce3f70d))
- **protocol:** preprocess variables for test ([#445](https://github.com/taikoxyz/taiko-mono/issues/445)) ([31584b4](https://github.com/taikoxyz/taiko-mono/commit/31584b47c11749711dcb3c61dc74581991141de3))
- **protocol:** whitelist provers & temporarily disable coverage check ([#296](https://github.com/taikoxyz/taiko-mono/issues/296)) ([06ceee2](https://github.com/taikoxyz/taiko-mono/commit/06ceee2599d01802683cca6b57e3fb6710946cd1))
- **ui:** Template / initial repo for UI ([#304](https://github.com/taikoxyz/taiko-mono/issues/304)) ([a396511](https://github.com/taikoxyz/taiko-mono/commit/a39651133d4c3bd8b6eea5db93daec7698600707))

### Bug Fixes

- **bridge:** Token Vault sendEther messages with processing fees are impossible to send ([#277](https://github.com/taikoxyz/taiko-mono/issues/277)) ([10d9bbc](https://github.com/taikoxyz/taiko-mono/commit/10d9bbc63ca624cc80c729942301eac334c960df))
- **pnpm:** conflict with eslint command and use pnpm instead of npm ([#273](https://github.com/taikoxyz/taiko-mono/issues/273)) ([134cd5a](https://github.com/taikoxyz/taiko-mono/commit/134cd5a75fcf3e78feac5762985d09658404735e))
- **preprocess:** fix hardhat preprocessor configs ([#368](https://github.com/taikoxyz/taiko-mono/issues/368)) ([8bdbb3e](https://github.com/taikoxyz/taiko-mono/commit/8bdbb3e3f5f30d11e4f9213690db316f2148568c))
- **protocol:** Add EtherTransferred event to EtherVault [#12971](https://github.com/taikoxyz/taiko-mono/issues/12971) ([5791f3a](https://github.com/taikoxyz/taiko-mono/commit/5791f3af85df462cc5aabbdf2b14d957d49c9f00))
- **protocol:** fix `BlockVerified` event ([#381](https://github.com/taikoxyz/taiko-mono/issues/381)) ([fe479c8](https://github.com/taikoxyz/taiko-mono/commit/fe479c8ff22b0da59ec75cc9e0dea04e38ebbb92))
- **protocol:** fix `ERC20Vault.sendERC20` ([#420](https://github.com/taikoxyz/taiko-mono/issues/420)) ([d42b953](https://github.com/taikoxyz/taiko-mono/commit/d42b953c51e66948d7a6563042f7a521ee2d557a))
- **protocol:** fix an occasional error in `test:tokenomics` ([#12950](https://github.com/taikoxyz/taiko-mono/issues/12950)) ([005364c](https://github.com/taikoxyz/taiko-mono/commit/005364c11c327f6dcaad7872c5064eb81e52f35b))
- **protocol:** Fix bug in getBlock ([#11679](https://github.com/taikoxyz/taiko-mono/issues/11679)) ([a6a596c](https://github.com/taikoxyz/taiko-mono/commit/a6a596cf10ecfa517a781e8c487b2d74f05a9526))
- **protocol:** let `LibZKP.verify` return `true` ([#12676](https://github.com/taikoxyz/taiko-mono/issues/12676)) ([d0f17a6](https://github.com/taikoxyz/taiko-mono/commit/d0f17a6dc8921df49a63831d91170a7c11476bd9))
- **protocol:** Remove enableDestChain functionality ([#12341](https://github.com/taikoxyz/taiko-mono/issues/12341)) ([362d083](https://github.com/taikoxyz/taiko-mono/commit/362d083497cc74b3bcd05a406beeff2101a422ef))
- **protocol:** update avg proof time and avg block time ([#391](https://github.com/taikoxyz/taiko-mono/issues/391)) ([3681483](https://github.com/taikoxyz/taiko-mono/commit/3681483efe97c38a488563594c003dabfa23b2de))
- **test:** fix the occasional `noNetwork` error in integration tests ([#7562](https://github.com/taikoxyz/taiko-mono/issues/7562)) ([a8e82d5](https://github.com/taikoxyz/taiko-mono/commit/a8e82d5c2d65d293d17953ff357816483eb25e00))
- **test:** fix two occasional errors when running bridge tests ([#305](https://github.com/taikoxyz/taiko-mono/issues/305)) ([fb91e0d](https://github.com/taikoxyz/taiko-mono/commit/fb91e0d482df9a510e582dcf267aadd8892fcebd))
- **test:** Fixed integration test case ([#483](https://github.com/taikoxyz/taiko-mono/issues/483)) ([4b0893e](https://github.com/taikoxyz/taiko-mono/commit/4b0893e3b0a723cd9115fd0c03e4ec4d1e0d1a38))
- **test:** making tests type-safe ([#318](https://github.com/taikoxyz/taiko-mono/issues/318)) ([66ec7cc](https://github.com/taikoxyz/taiko-mono/commit/66ec7cc143af58dda8fde0d6adc30a4758685d1e))
- **tests:** cleanup tests to prepare for tokenomics testing ([#11316](https://github.com/taikoxyz/taiko-mono/issues/11316)) ([d63fae3](https://github.com/taikoxyz/taiko-mono/commit/d63fae30f1e3415d6f377adeab90c062fed5ad42))
