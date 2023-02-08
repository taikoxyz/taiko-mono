# Changelog

## [0.2.0](https://github.com/taikoxyz/taiko-mono/compare/protocol-v0.1.0...protocol-v0.2.0) (2023-01-31)

### Features

- **protocol:** add `proto_broker` / `oracle_prover` addresses into `AddressManager` in deploy_L1 script ([#13079](https://github.com/taikoxyz/taiko-mono/issues/13079)) ([f3bea40](https://github.com/taikoxyz/taiko-mono/commit/f3bea40fbcdf4139cc84903ab69d1e0daf641c7c))
- **protocol:** add special logics for alpha-2 testnet ([#12987](https://github.com/taikoxyz/taiko-mono/issues/12987)) ([3b71285](https://github.com/taikoxyz/taiko-mono/commit/3b712857b5d5ede2a3683d949d1974c8cceeb69a))
- **protocol:** deploy the generated Yul plonk verifier ([#13016](https://github.com/taikoxyz/taiko-mono/issues/13016)) ([eb5d564](https://github.com/taikoxyz/taiko-mono/commit/eb5d564ec469b1ec79619b4d563c3f9989d264c2))
- **protocol:** enable two dimensional circuit/verifier lookup. ([#13066](https://github.com/taikoxyz/taiko-mono/issues/13066)) ([51d1f67](https://github.com/taikoxyz/taiko-mono/commit/51d1f67aa45fec8e2de73c1ed5a992306c6339c1))
- **protocol:** implement `Bridge.isMessageFailed` ([#13004](https://github.com/taikoxyz/taiko-mono/issues/13004)) ([45153d9](https://github.com/taikoxyz/taiko-mono/commit/45153d92cbcd0e80438c925d5ce5c52df3abd696))
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

- **bridge:** add getMessageStatusSlot function ([#12940](https://github.com/taikoxyz/taiko-mono/issues/12940)) ([9837fa3](https://github.com/taikoxyz/taiko-mono/commit/9837fa3dceb5d702b2247879af52988be4da333d))
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
- **protocol:** fix `TokenVault.sendERC20` ([#420](https://github.com/taikoxyz/taiko-mono/issues/420)) ([d42b953](https://github.com/taikoxyz/taiko-mono/commit/d42b953c51e66948d7a6563042f7a521ee2d557a))
- **protocol:** fix an occasional error in `test:tokenomics` ([#12950](https://github.com/taikoxyz/taiko-mono/issues/12950)) ([005364c](https://github.com/taikoxyz/taiko-mono/commit/005364c11c327f6dcaad7872c5064eb81e52f35b))
- **protocol:** Fix bug in getProposedBlock ([#11679](https://github.com/taikoxyz/taiko-mono/issues/11679)) ([a6a596c](https://github.com/taikoxyz/taiko-mono/commit/a6a596cf10ecfa517a781e8c487b2d74f05a9526))
- **protocol:** let `LibZKP.verify` return `true` ([#12676](https://github.com/taikoxyz/taiko-mono/issues/12676)) ([d0f17a6](https://github.com/taikoxyz/taiko-mono/commit/d0f17a6dc8921df49a63831d91170a7c11476bd9))
- **protocol:** Remove enableDestChain functionality ([#12341](https://github.com/taikoxyz/taiko-mono/issues/12341)) ([362d083](https://github.com/taikoxyz/taiko-mono/commit/362d083497cc74b3bcd05a406beeff2101a422ef))
- **protocol:** update avg proof time and avg block time ([#391](https://github.com/taikoxyz/taiko-mono/issues/391)) ([3681483](https://github.com/taikoxyz/taiko-mono/commit/3681483efe97c38a488563594c003dabfa23b2de))
- **test:** fix the occasional `noNetwork` error in integration tests ([#7562](https://github.com/taikoxyz/taiko-mono/issues/7562)) ([a8e82d5](https://github.com/taikoxyz/taiko-mono/commit/a8e82d5c2d65d293d17953ff357816483eb25e00))
- **test:** fix two occasional errors when running bridge tests ([#305](https://github.com/taikoxyz/taiko-mono/issues/305)) ([fb91e0d](https://github.com/taikoxyz/taiko-mono/commit/fb91e0d482df9a510e582dcf267aadd8892fcebd))
- **test:** Fixed integration test case ([#483](https://github.com/taikoxyz/taiko-mono/issues/483)) ([4b0893e](https://github.com/taikoxyz/taiko-mono/commit/4b0893e3b0a723cd9115fd0c03e4ec4d1e0d1a38))
- **test:** making tests type-safe ([#318](https://github.com/taikoxyz/taiko-mono/issues/318)) ([66ec7cc](https://github.com/taikoxyz/taiko-mono/commit/66ec7cc143af58dda8fde0d6adc30a4758685d1e))
- **tests:** cleanup tests to prepare for tokenomics testing ([#11316](https://github.com/taikoxyz/taiko-mono/issues/11316)) ([d63fae3](https://github.com/taikoxyz/taiko-mono/commit/d63fae30f1e3415d6f377adeab90c062fed5ad42))
