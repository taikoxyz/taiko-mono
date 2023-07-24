# Changelog

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
- **protocol:** Introduce oracle and system prover concept ([#13729](https://github.com/taikoxyz/taiko-mono/issues/13729)) ([e8ba716](https://github.com/taikoxyz/taiko-mono/commit/e8ba7168231f9a8bbef1378fa93448b11c4267ac))
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
- **protocol:** Additional integration tests, solidity bump, reduce TokenVault contract size ([#13155](https://github.com/taikoxyz/taiko-mono/issues/13155)) ([ffdf5db](https://github.com/taikoxyz/taiko-mono/commit/ffdf5db675404d463850fca0b97d37c23cde61a1))
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
- **protocol:** Fix bug in getBlock ([#11679](https://github.com/taikoxyz/taiko-mono/issues/11679)) ([a6a596c](https://github.com/taikoxyz/taiko-mono/commit/a6a596cf10ecfa517a781e8c487b2d74f05a9526))
- **protocol:** let `LibZKP.verify` return `true` ([#12676](https://github.com/taikoxyz/taiko-mono/issues/12676)) ([d0f17a6](https://github.com/taikoxyz/taiko-mono/commit/d0f17a6dc8921df49a63831d91170a7c11476bd9))
- **protocol:** Remove enableDestChain functionality ([#12341](https://github.com/taikoxyz/taiko-mono/issues/12341)) ([362d083](https://github.com/taikoxyz/taiko-mono/commit/362d083497cc74b3bcd05a406beeff2101a422ef))
- **protocol:** update avg proof time and avg block time ([#391](https://github.com/taikoxyz/taiko-mono/issues/391)) ([3681483](https://github.com/taikoxyz/taiko-mono/commit/3681483efe97c38a488563594c003dabfa23b2de))
- **test:** fix the occasional `noNetwork` error in integration tests ([#7562](https://github.com/taikoxyz/taiko-mono/issues/7562)) ([a8e82d5](https://github.com/taikoxyz/taiko-mono/commit/a8e82d5c2d65d293d17953ff357816483eb25e00))
- **test:** fix two occasional errors when running bridge tests ([#305](https://github.com/taikoxyz/taiko-mono/issues/305)) ([fb91e0d](https://github.com/taikoxyz/taiko-mono/commit/fb91e0d482df9a510e582dcf267aadd8892fcebd))
- **test:** Fixed integration test case ([#483](https://github.com/taikoxyz/taiko-mono/issues/483)) ([4b0893e](https://github.com/taikoxyz/taiko-mono/commit/4b0893e3b0a723cd9115fd0c03e4ec4d1e0d1a38))
- **test:** making tests type-safe ([#318](https://github.com/taikoxyz/taiko-mono/issues/318)) ([66ec7cc](https://github.com/taikoxyz/taiko-mono/commit/66ec7cc143af58dda8fde0d6adc30a4758685d1e))
- **tests:** cleanup tests to prepare for tokenomics testing ([#11316](https://github.com/taikoxyz/taiko-mono/issues/11316)) ([d63fae3](https://github.com/taikoxyz/taiko-mono/commit/d63fae30f1e3415d6f377adeab90c062fed5ad42))
