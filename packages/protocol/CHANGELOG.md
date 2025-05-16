# Changelog

## [2.3.0](https://github.com/taikoxyz/taiko-mono/compare/taiko-alethia-protocol-v2.2.0...taiko-alethia-protocol-v2.3.0) (2025-05-06)


### Features

* **protocol:** add a few governance/treasury related contracts ([#19229](https://github.com/taikoxyz/taiko-mono/issues/19229)) ([194bb48](https://github.com/taikoxyz/taiko-mono/commit/194bb487023336a8cab061f4ae5aa9606f369c1f))
* **protocol:** add an IPreconfWhitelist implementation with delayed activation & deactivation ([#19101](https://github.com/taikoxyz/taiko-mono/issues/19101)) ([8d8d5b8](https://github.com/taikoxyz/taiko-mono/commit/8d8d5b89b71e58ceb92f94ae077b519093987c7b))
* **protocol:** allow operators to remove themselves from the whitelist ([9e02dce](https://github.com/taikoxyz/taiko-mono/commit/9e02dce64ee8b1774bf87ac4546e03b7ebdd897d))
* **protocol:** allow owner to change "operator change delay" (even to zero) ([9e02dce](https://github.com/taikoxyz/taiko-mono/commit/9e02dce64ee8b1774bf87ac4546e03b7ebdd897d))
* **protocol:** fix wrong genesis holesky timestamp ([#19331](https://github.com/taikoxyz/taiko-mono/issues/19331)) ([43edba1](https://github.com/taikoxyz/taiko-mono/commit/43edba127fa2672467a4dddfa213f62315b38c93))
* **protocol:** rename pivot verifier to geth verifier ([#19242](https://github.com/taikoxyz/taiko-mono/issues/19242)) ([78ffb92](https://github.com/taikoxyz/taiko-mono/commit/78ffb923289be45a59b25fad8fdb52d874e26087))
* **protocol:** scripts for Pacaya upgrade ([#19112](https://github.com/taikoxyz/taiko-mono/issues/19112)) ([045fd19](https://github.com/taikoxyz/taiko-mono/commit/045fd19b13aa1b954c6729f1a287db793e047abe))
* **protocol:** support fallback preconfer when whitelist returns address(0) ([#19111](https://github.com/taikoxyz/taiko-mono/issues/19111)) ([d9047f2](https://github.com/taikoxyz/taiko-mono/commit/d9047f2828d72541f2ebcf7800b26a8ce67ffb1a))
* **protocol:** support hekla pivot setup ([#19209](https://github.com/taikoxyz/taiko-mono/issues/19209)) ([31493d2](https://github.com/taikoxyz/taiko-mono/commit/31493d24ffb40dfad53dded08fe1e0c7dd27d095))
* **protocol:** update config script ([#19196](https://github.com/taikoxyz/taiko-mono/issues/19196)) ([25af05a](https://github.com/taikoxyz/taiko-mono/commit/25af05a14def3d6bc111bede018ca4039a723538))
* **protocol:** update config script's pacaya address ([#19143](https://github.com/taikoxyz/taiko-mono/issues/19143)) ([d39c850](https://github.com/taikoxyz/taiko-mono/commit/d39c850d8a61aa485372cc60b98d04a9aab78579))
* **protocol:** use constant liveness bond per batch ([#19255](https://github.com/taikoxyz/taiko-mono/issues/19255)) ([6bebf99](https://github.com/taikoxyz/taiko-mono/commit/6bebf99fc9eb4d2f87e13a80146edf7f35466056))
* **protocol:** using latest risc0 2.0.0 & sp1 4.0.0 verifier ([#19265](https://github.com/taikoxyz/taiko-mono/issues/19265)) ([e729d62](https://github.com/taikoxyz/taiko-mono/commit/e729d622cf8c702e7144333af799379c81fadef1))
* **taiko-client:** run tests post Pacaya fork ([#19313](https://github.com/taikoxyz/taiko-mono/issues/19313)) ([461bf65](https://github.com/taikoxyz/taiko-mono/commit/461bf653dd731240b2b143ff296358ef692bd659))


### Bug Fixes

* **protocol:** add `signal_service` deployment & rm debug event ([#19177](https://github.com/taikoxyz/taiko-mono/issues/19177)) ([8d77889](https://github.com/taikoxyz/taiko-mono/commit/8d778895cff9257782c35ee2a9e5cbbb64a1c65b))
* **protocol:** change modifier to `onlyOwner` ([#19201](https://github.com/taikoxyz/taiko-mono/issues/19201)) ([0f1f7d8](https://github.com/taikoxyz/taiko-mono/commit/0f1f7d8ee703bd3bab7e36008cebed5b996b5628))
* **protocol:** ensure empty blobHashes for normal proposals in TaikoWrapper ([#19378](https://github.com/taikoxyz/taiko-mono/issues/19378)) ([2170978](https://github.com/taikoxyz/taiko-mono/commit/2170978314117b758ecc46074dd3528eeb9a0029))
* **protocol:** fix constructor in `HeklaVerifier` ([#19147](https://github.com/taikoxyz/taiko-mono/issues/19147)) ([d09224d](https://github.com/taikoxyz/taiko-mono/commit/d09224d057d7e3d3bf52e984960005f7e0587f1a))
* **protocol:** fix deployment in `DeployProtocolOnL1` ([#19232](https://github.com/taikoxyz/taiko-mono/issues/19232)) ([d01bb8c](https://github.com/taikoxyz/taiko-mono/commit/d01bb8cf5f36d35b9a1ce877a56d3ebd4837e786))
* **protocol:** fix l2 genesis ([#19233](https://github.com/taikoxyz/taiko-mono/issues/19233)) ([56fd5bc](https://github.com/taikoxyz/taiko-mono/commit/56fd5bcfb90da60cd7b8539128c14a47ece3563f))
* **protocol:** fix PreconfRouter permission check issue ([#19349](https://github.com/taikoxyz/taiko-mono/issues/19349)) ([51e7545](https://github.com/taikoxyz/taiko-mono/commit/51e754507063d5c066b08deb9cfcf849d7d17f9e))
* **protocol:** register L2 bridge to L1 resolver ([#19154](https://github.com/taikoxyz/taiko-mono/issues/19154)) ([bb40493](https://github.com/taikoxyz/taiko-mono/commit/bb404934baaf4ca102566ffd11fd6031d20f4856))
* **protocol:** remove bridge stuff & fix some issue ([#19159](https://github.com/taikoxyz/taiko-mono/issues/19159)) ([0336dca](https://github.com/taikoxyz/taiko-mono/commit/0336dca738518d1d130b6c09cf080db260bf0b6a))
* **protocol:** some issue caused by Hekla upgrade ([#19203](https://github.com/taikoxyz/taiko-mono/issues/19203)) ([9af37d8](https://github.com/taikoxyz/taiko-mono/commit/9af37d8d1a8d8e8bde4df8851723f9cb3b0c6221))
* **protocol:** use seconds in slot, not seconds in epoch ([#19327](https://github.com/taikoxyz/taiko-mono/issues/19327)) ([07a6d5c](https://github.com/taikoxyz/taiko-mono/commit/07a6d5c00c22a4947a17692e1e3c954ef12dd796))
* **taiko-client:** fix an issue in `RemovePreconfBlocks` when no `HeadL1Origin` in L2 EE ([#19307](https://github.com/taikoxyz/taiko-mono/issues/19307)) ([602bdd3](https://github.com/taikoxyz/taiko-mono/commit/602bdd385cfd3a537ab22b47b48776b208131139))


### Chores

* **main:** fix spelling issues ([#19269](https://github.com/taikoxyz/taiko-mono/issues/19269)) ([7b36376](https://github.com/taikoxyz/taiko-mono/commit/7b3637640eede1b34916c66733bcdf2672049a3b))
* **protocol, taiko-client:** general typos fix ([#19272](https://github.com/taikoxyz/taiko-mono/issues/19272)) ([c22e86d](https://github.com/taikoxyz/taiko-mono/commit/c22e86df678537a3416f99c8fff98e08c51352ca))
* **protocol:** add Ethereum Hoodi network configs ([#19102](https://github.com/taikoxyz/taiko-mono/issues/19102)) ([6267b5f](https://github.com/taikoxyz/taiko-mono/commit/6267b5f9a42008da8f3c67fba1721211b1e31684))
* **protocol:** add extra comments to TaikoInbox ([#19226](https://github.com/taikoxyz/taiko-mono/issues/19226)) ([8de4add](https://github.com/taikoxyz/taiko-mono/commit/8de4add071cfb4e9304a70e98e60c1e4af07ccee))
* **protocol:** allow IPreconfWhitelist to return address(0) ([#19103](https://github.com/taikoxyz/taiko-mono/issues/19103)) ([8184d42](https://github.com/taikoxyz/taiko-mono/commit/8184d422d3a28a65248aba14c98d649177967804))
* **protocol:** change base fee min value and share percentage ([#19293](https://github.com/taikoxyz/taiko-mono/issues/19293)) ([2dd28f5](https://github.com/taikoxyz/taiko-mono/commit/2dd28f500318486c17e65ac3a32d700b0309874f))
* **protocol:** change mainnet stateRootSyncInternal from 12 to 4 ([#19060](https://github.com/taikoxyz/taiko-mono/issues/19060)) ([1fd282f](https://github.com/taikoxyz/taiko-mono/commit/1fd282f5d5804881946fed90dad28bde106f513b))
* **protocol:** correct spelling in mainnet contract logs ([#19284](https://github.com/taikoxyz/taiko-mono/issues/19284)) ([df2b939](https://github.com/taikoxyz/taiko-mono/commit/df2b9395a4d50bb385423b9187bc4c9386a2378e))
* **protocol:** fix deployment scripts for Pacaya cleanup ([#19315](https://github.com/taikoxyz/taiko-mono/issues/19315)) ([b362044](https://github.com/taikoxyz/taiko-mono/commit/b36204427ab1b308912f8489b74c9c534ca3d393))
* **protocol:** fix typo ([#19389](https://github.com/taikoxyz/taiko-mono/issues/19389)) ([866ae99](https://github.com/taikoxyz/taiko-mono/commit/866ae99ffa6d7d56a4ae8970974b564b0fe29936))
* **protocol:** fix typos ([#19259](https://github.com/taikoxyz/taiko-mono/issues/19259)) ([7f2556b](https://github.com/taikoxyz/taiko-mono/commit/7f2556b505006ef0c4bf637cbf24551adf3b28d4))
* **protocol:** improve contract var naming ([#19244](https://github.com/taikoxyz/taiko-mono/issues/19244)) ([8df82ad](https://github.com/taikoxyz/taiko-mono/commit/8df82ad8a344c608d26c383aae70185dd7d9307d))
* **protocol:** make base fee change 4 times slower than Ethereum ([#19212](https://github.com/taikoxyz/taiko-mono/issues/19212)) ([1f577b2](https://github.com/taikoxyz/taiko-mono/commit/1f577b29dc3b31bbbc77eb0324b6be728a621b41))
* **protocol:** remove PreconfInbox.sol ([#19288](https://github.com/taikoxyz/taiko-mono/issues/19288)) ([5c58378](https://github.com/taikoxyz/taiko-mono/commit/5c58378611ec7ed97ad1c3b4290a090a429e21be))
* **protocol:** remove selfDelegate from Bridge ([#19364](https://github.com/taikoxyz/taiko-mono/issues/19364)) ([5ac7eda](https://github.com/taikoxyz/taiko-mono/commit/5ac7eda8202115e23bf76fd554c0a62b5aee765c))
* **protocol:** rename MinimalOwner to IntermediateOwner ([#19360](https://github.com/taikoxyz/taiko-mono/issues/19360)) ([74550e6](https://github.com/taikoxyz/taiko-mono/commit/74550e696955208ec95997f5a299eb82a2ac69f4))
* **protocol:** rename verifier identifiers ([#19308](https://github.com/taikoxyz/taiko-mono/issues/19308)) ([4913c1e](https://github.com/taikoxyz/taiko-mono/commit/4913c1e9f89f2ae3c582a64265a6bafe722a87ae))
* **protocol:** revert [#19212](https://github.com/taikoxyz/taiko-mono/issues/19212) ([#19296](https://github.com/taikoxyz/taiko-mono/issues/19296)) ([13157fd](https://github.com/taikoxyz/taiko-mono/commit/13157fda7aecfeb5a3ead076c194f76909e9f001))
* **protocol:** temporarily lower liveness bond for whitelisted preconfers ([#19205](https://github.com/taikoxyz/taiko-mono/issues/19205)) ([aa82224](https://github.com/taikoxyz/taiko-mono/commit/aa82224b28030d87e3519e61d5a07fb15395c893))
* **protocol:** update Hekla contract logs for Pacaya ([#19134](https://github.com/taikoxyz/taiko-mono/issues/19134)) ([f3a4273](https://github.com/taikoxyz/taiko-mono/commit/f3a42732b93f4c440ac5a712d59b07a40b200562))
* **protocol:** update Hekla Pacaya fork height ([#19131](https://github.com/taikoxyz/taiko-mono/issues/19131)) ([1135ed4](https://github.com/taikoxyz/taiko-mono/commit/1135ed41aa662a0b179d5b6240057f4d0dec3747))


### Documentation

* **protocol:** add halborn-taiko-dao-contract-audit.pdf ([#19152](https://github.com/taikoxyz/taiko-mono/issues/19152)) ([f78dc19](https://github.com/taikoxyz/taiko-mono/commit/f78dc19208366a7cb3d2b05b604263ad3c4db225))
* **protocol:** add new l2 resolver for Pacaya ([#19204](https://github.com/taikoxyz/taiko-mono/issues/19204)) ([07e39b1](https://github.com/taikoxyz/taiko-mono/commit/07e39b11fa6cbe248dea5ea478afda6000adc278))
* **protocol:** change logs of `minGasExcess` and `sharingPctg` on Hekla ([#19295](https://github.com/taikoxyz/taiko-mono/issues/19295)) ([9fcdd56](https://github.com/taikoxyz/taiko-mono/commit/9fcdd56396a212fde96ce2b92982e7cb13103d93))
* **protocol:** change logs of `minGasExcess` and `sharingPctg` on Hekla ([#19297](https://github.com/taikoxyz/taiko-mono/issues/19297)) ([a56a060](https://github.com/taikoxyz/taiko-mono/commit/a56a0601c7932e464eda48a292d1e33558bdc3e7))
* **protocol:** document vault upgrades on Hekla ([#19210](https://github.com/taikoxyz/taiko-mono/issues/19210)) ([9d9fbab](https://github.com/taikoxyz/taiko-mono/commit/9d9fbab95e2465b9b462a117cb05ff7a9cb563c5))
* **protocol:** fixed dead links ([#19186](https://github.com/taikoxyz/taiko-mono/issues/19186)) ([f05c842](https://github.com/taikoxyz/taiko-mono/commit/f05c8424d48c11eaa16f57787ccc147ca46ce01e))
* **protocol:** rename verifier identifiers  ([#19263](https://github.com/taikoxyz/taiko-mono/issues/19263)) ([30de547](https://github.com/taikoxyz/taiko-mono/commit/30de5479023e99d63804846da95ca44916a0399b))
* **protocol:** update contract logs related pivot proof ([#19199](https://github.com/taikoxyz/taiko-mono/issues/19199)) ([c64590e](https://github.com/taikoxyz/taiko-mono/commit/c64590ee3f06369ceeef3e841d140f44ba22c0ad))
* **protocol:** update verifier names in `UpgradeDevnetPacayaL1` contract ([#19289](https://github.com/taikoxyz/taiko-mono/issues/19289)) ([8da2086](https://github.com/taikoxyz/taiko-mono/commit/8da20860b4df8dd6018789d837d831a9db23f2b0))
* **protocol:** updated broken links ([#19191](https://github.com/taikoxyz/taiko-mono/issues/19191)) ([67ae95a](https://github.com/taikoxyz/taiko-mono/commit/67ae95afd86c9daea5d2abef266f81762dd1182b))
* **protocol:** upgrade bridge related stuff on Hekla ([#19153](https://github.com/taikoxyz/taiko-mono/issues/19153)) ([7ab4bcb](https://github.com/taikoxyz/taiko-mono/commit/7ab4bcb97f3e2ed1acaecd77a6736fceade8a3a5))
* **protocol:** upgrade Hekla `signal_service` ([#19176](https://github.com/taikoxyz/taiko-mono/issues/19176)) ([8dc4e1e](https://github.com/taikoxyz/taiko-mono/commit/8dc4e1ed6e216e0572b00ec2391032e7ebc2e061))
* **protocol:** upgrade renamed contracts ([#19252](https://github.com/taikoxyz/taiko-mono/issues/19252)) ([3386925](https://github.com/taikoxyz/taiko-mono/commit/3386925334d07aa58897bce02723b0f15e818685))
* **protocol:** upgrade sgx-geth verifier on Hekla ([#19268](https://github.com/taikoxyz/taiko-mono/issues/19268)) ([707beab](https://github.com/taikoxyz/taiko-mono/commit/707beabe4cb485baf5b13d72a3372baca6abe243))


### Code Refactoring

* **protocol:** deploy PreconfWhitelist2 in DeployProtocolOnL1.s.sol ([#19121](https://github.com/taikoxyz/taiko-mono/issues/19121)) ([097135d](https://github.com/taikoxyz/taiko-mono/commit/097135dc1b95e85092b55df88c9247717204db44))
* **protocol:** improve LibPreconfUtils.getBeaconBlockRoot() ([#19100](https://github.com/taikoxyz/taiko-mono/issues/19100)) ([36c7c1d](https://github.com/taikoxyz/taiko-mono/commit/36c7c1d041533bb7936c376ba10f330e9668fa81))
* **protocol:** optimize getOperatorForCurrentEpoch gas cost ([9e02dce](https://github.com/taikoxyz/taiko-mono/commit/9e02dce64ee8b1774bf87ac4546e03b7ebdd897d))
* **protocol:** replace PreconfWhitelist with PreconfWhitelist2 ([#19122](https://github.com/taikoxyz/taiko-mono/issues/19122)) ([294334c](https://github.com/taikoxyz/taiko-mono/commit/294334cc81980dd08274d3100d3b187bed95f383))


### Tests

* **protocol:** rename some variables (by [@leopardracer](https://github.com/leopardracer)) ([#19208](https://github.com/taikoxyz/taiko-mono/issues/19208)) ([591a55c](https://github.com/taikoxyz/taiko-mono/commit/591a55c8ab39144ef8cd8fec583812cb8d9b610a))


### Workflow

* **protocol:** move layout files ([#19301](https://github.com/taikoxyz/taiko-mono/issues/19301)) ([8a7c22a](https://github.com/taikoxyz/taiko-mono/commit/8a7c22a654681db0c1a78607032ebffa80509db4))

## [2.2.0](https://github.com/taikoxyz/taiko-mono/compare/taiko-alethia-protocol-v2.1.0...taiko-alethia-protocol-v2.2.0) (2025-03-17)


### Features

* **protocol:** add `ITaikoInbox.Config` to `ITaikoInbox.BatchInfo` ([#19004](https://github.com/taikoxyz/taiko-mono/issues/19004)) ([6afec95](https://github.com/taikoxyz/taiko-mono/commit/6afec955d8ea1e804e485f6aa5e26a2328684cd0))
* **protocol:** add helder constants for preconf ([#18993](https://github.com/taikoxyz/taiko-mono/issues/18993)) ([f67f616](https://github.com/taikoxyz/taiko-mono/commit/f67f616e2c1145172da19b15cd1e50693c398086))
* **protocol:** add new tcb & add test case  ([#19008](https://github.com/taikoxyz/taiko-mono/issues/19008)) ([12ddb55](https://github.com/taikoxyz/taiko-mono/commit/12ddb55c1bfb462c508a77177841620402d56d46))
* **protocol:** add pivot verifier ([#18990](https://github.com/taikoxyz/taiko-mono/issues/18990)) ([e0763e2](https://github.com/taikoxyz/taiko-mono/commit/e0763e27df48218c8e43f0612184791bca917885))
* **protocol:** allow ForcedInclusionStore to be paused (disabled) ([#19063](https://github.com/taikoxyz/taiko-mono/issues/19063)) ([2d6cd46](https://github.com/taikoxyz/taiko-mono/commit/2d6cd467243028c83318ceaf65c159625ef2d027))
* **protocol:** enforce first block time shift to be 0 ([#19090](https://github.com/taikoxyz/taiko-mono/issues/19090)) ([bbc7700](https://github.com/taikoxyz/taiko-mono/commit/bbc770067aafd3662c3a727dce789be6b4ac72dd))
* **protocol:** invalidate existing conflicting transition ([#19014](https://github.com/taikoxyz/taiko-mono/issues/19014)) ([b3b9569](https://github.com/taikoxyz/taiko-mono/commit/b3b9569124f85510941432e2e7e830cedb82275b))
* **protocol:** revert 3 previous PRs ([#19012](https://github.com/taikoxyz/taiko-mono/issues/19012)) ([4a348e7](https://github.com/taikoxyz/taiko-mono/commit/4a348e762e81c4dfa67afc799c0c9847460007a3))
* **taiko-client:** changes based on the protocol forced inclusion feature ([#18909](https://github.com/taikoxyz/taiko-mono/issues/18909)) ([d351788](https://github.com/taikoxyz/taiko-mono/commit/d35178843968b133cf228fe3a156b16ef3983bbe))
* **taiko-client:** init proving workflow for pacaya ([#18992](https://github.com/taikoxyz/taiko-mono/issues/18992)) ([68b662a](https://github.com/taikoxyz/taiko-mono/commit/68b662a7e853cc9d07d371588fd818e286e2fad1))


### Bug Fixes

* **protocol:** 1 block per forced transaction ([#19001](https://github.com/taikoxyz/taiko-mono/issues/19001)) ([fa63bb3](https://github.com/taikoxyz/taiko-mono/commit/fa63bb3bb49b7402a3b98ef84ecc2b4f5595fe88))
* **protocol:** burn solver fee correctly in ERC20Vault ([#19048](https://github.com/taikoxyz/taiko-mono/issues/19048)) ([fc664f8](https://github.com/taikoxyz/taiko-mono/commit/fc664f8311fd0320b54872f15c504d129add694c))
* **protocol:** check bridgeOp's to address on src chain ([#19040](https://github.com/taikoxyz/taiko-mono/issues/19040)) ([57beec8](https://github.com/taikoxyz/taiko-mono/commit/57beec8fb84bd658b896667fe13c9849c5b7d35c))
* **protocol:** deploy new verifiers for Pacaya in upgrade script ([#19082](https://github.com/taikoxyz/taiko-mono/issues/19082)) ([1791d6a](https://github.com/taikoxyz/taiko-mono/commit/1791d6a1573edfd2899208cada90aebfe75daffe))
* **protocol:** enforce 1 block per forced inclusion ([#19013](https://github.com/taikoxyz/taiko-mono/issues/19013)) ([c8e6499](https://github.com/taikoxyz/taiko-mono/commit/c8e6499561f2fc2c8b5a7b470c533191edf1cedf))
* **protocol:** ensure each forced inclusion request use a dedicated blob ([#19070](https://github.com/taikoxyz/taiko-mono/issues/19070)) ([8759bc2](https://github.com/taikoxyz/taiko-mono/commit/8759bc232ef17c28af92ac58020d1e04483c1982))
* **protocol:** fix a `blobParams.createdIn` issue ([#18967](https://github.com/taikoxyz/taiko-mono/issues/18967)) ([a9d9e43](https://github.com/taikoxyz/taiko-mono/commit/a9d9e4362c47f32906d0556d4ee1ba63b4dbb4b7))
* **protocol:** fix a bug in proving logics ([#19056](https://github.com/taikoxyz/taiko-mono/issues/19056)) ([98847d6](https://github.com/taikoxyz/taiko-mono/commit/98847d69b182fdc540ec2ce6a5252fbcd8a10436))
* **protocol:** fix dcap script ([#19049](https://github.com/taikoxyz/taiko-mono/issues/19049)) ([892f931](https://github.com/taikoxyz/taiko-mono/commit/892f931b452d0a701ce43fb99a932a2b955f2bcf))
* **protocol:** fix deployment script for preconf proverSet ([#19031](https://github.com/taikoxyz/taiko-mono/issues/19031)) ([12de741](https://github.com/taikoxyz/taiko-mono/commit/12de7410a2eece5e62a5adbb7b0a0b5774729fe6))
* **protocol:** fix Ether surplus transfer issue ([#19026](https://github.com/taikoxyz/taiko-mono/issues/19026)) ([c9edab8](https://github.com/taikoxyz/taiko-mono/commit/c9edab82888f6577f1c42c336a23a7f432946da1))
* **protocol:** fix the same or the conflicted transaction ([#19017](https://github.com/taikoxyz/taiko-mono/issues/19017)) ([a790640](https://github.com/taikoxyz/taiko-mono/commit/a7906400d1d42767f0a8d0fdd2cab5c690b07605))
* **protocol:** fix two issues in `DeployProtocolOnL1` ([#19067](https://github.com/taikoxyz/taiko-mono/issues/19067)) ([dbc21f2](https://github.com/taikoxyz/taiko-mono/commit/dbc21f2130625a5a98dfc8091995353f6956c7a1))
* **protocol:** move numTransactions and timestamp to blobs ([#18998](https://github.com/taikoxyz/taiko-mono/issues/18998)) ([67ff89b](https://github.com/taikoxyz/taiko-mono/commit/67ff89b3877a6ee3d5b88d1b8ae19e0e56322d0f))


### Chores

* **protocol:** add back ERC20Vault (without solver) as ERC20VaultOriginal ([#19020](https://github.com/taikoxyz/taiko-mono/issues/19020)) ([8b1c3f9](https://github.com/taikoxyz/taiko-mono/commit/8b1c3f95d5439500f702c58985b5cdaf078bb225))
* **protocol:** change Hekla stateRootSyncInternal from 12 to 4 ([#19061](https://github.com/taikoxyz/taiko-mono/issues/19061)) ([e3cd564](https://github.com/taikoxyz/taiko-mono/commit/e3cd564216f156b6ec4ab0f2f92978004db7e04a))
* **protocol:** check shasta fork height ([#19076](https://github.com/taikoxyz/taiko-mono/issues/19076)) ([b0e5fd2](https://github.com/taikoxyz/taiko-mono/commit/b0e5fd26b5120ab4df8012620bff44b7a45a5cca))
* **protocol:** fix lint issue ([#19074](https://github.com/taikoxyz/taiko-mono/issues/19074)) ([a3f1721](https://github.com/taikoxyz/taiko-mono/commit/a3f172173e2a662670865a7a18172e74c69d7956))
* **protocol:** improve comment for timeshift ([#19086](https://github.com/taikoxyz/taiko-mono/issues/19086)) ([544132b](https://github.com/taikoxyz/taiko-mono/commit/544132bf9186bc0fd7df5d9a0fe732b175ee5c3d))
* **protocol:** measure gas used per batch ([#19058](https://github.com/taikoxyz/taiko-mono/issues/19058)) ([27dfe8c](https://github.com/taikoxyz/taiko-mono/commit/27dfe8c68ff0cf8a9fe3b20c078a5e20c74fa703))
* **protocol:** remove unused _consumeTokenQuota from ERC20Vault ([#19064](https://github.com/taikoxyz/taiko-mono/issues/19064)) ([8abe756](https://github.com/taikoxyz/taiko-mono/commit/8abe756aff5aa9af74722b63209f94825f6a5a6f))
* **protocol:** update `anchorGasLimit` in `MainnetInbox` ([#19038](https://github.com/taikoxyz/taiko-mono/issues/19038)) ([719252c](https://github.com/taikoxyz/taiko-mono/commit/719252c414c542b009dc48356ab381efd49f1aa7))
* **protocol:** update `DevnetInbox.chainId` ([#18969](https://github.com/taikoxyz/taiko-mono/issues/18969)) ([ef188e0](https://github.com/taikoxyz/taiko-mono/commit/ef188e0b1016a5f90080fac78c81e4533bcf51e8))
* **protocol:** update Inbox configs ([#18965](https://github.com/taikoxyz/taiko-mono/issues/18965)) ([650cb1f](https://github.com/taikoxyz/taiko-mono/commit/650cb1febe0f6e872947ec9eb9bf15904189d4b0))


### Documentation

* **protocol:** add halborn-taiko-alethia-protocol-audit-for-pacaya-upgrade.pdf ([#19083](https://github.com/taikoxyz/taiko-mono/issues/19083)) ([9c383ba](https://github.com/taikoxyz/taiko-mono/commit/9c383ba0b93fa0945764801fed896c81c4c3ae71))
* **protocol:** update mainnet deployment docs ([#18987](https://github.com/taikoxyz/taiko-mono/issues/18987)) ([49e7774](https://github.com/taikoxyz/taiko-mono/commit/49e7774fc432d09f95ea016587c70645a8d0d0eb))


### Code Refactoring

* **protocol:** do not delete old transition as it will not refund enough gas ([#18984](https://github.com/taikoxyz/taiko-mono/issues/18984)) ([a0be0fa](https://github.com/taikoxyz/taiko-mono/commit/a0be0faac0ce95375d35409c865e70c55b268597))
* **protocol:** fix tests due to recent foundry change ([#19092](https://github.com/taikoxyz/taiko-mono/issues/19092)) ([c8193ff](https://github.com/taikoxyz/taiko-mono/commit/c8193ff757bea386dad04db4ff02c3451392a53d))
* **protocol:** make it explicit that Ether as bond must be deposited beforehand. ([#19028](https://github.com/taikoxyz/taiko-mono/issues/19028)) ([a7cf79e](https://github.com/taikoxyz/taiko-mono/commit/a7cf79e127e9a8f1b792db5f77731d7ef744ea6b))


### Tests

* **protocol:** add an extra test from Halborn to verify ERC20 bugs are fixed ([#19069](https://github.com/taikoxyz/taiko-mono/issues/19069)) ([af0ee79](https://github.com/taikoxyz/taiko-mono/commit/af0ee79d4711f548f73f15242a1685bbbdd74a40))
* **protocol:** add test from Halborn to verify solver lose funds ([#19091](https://github.com/taikoxyz/taiko-mono/issues/19091)) ([f8f77ef](https://github.com/taikoxyz/taiko-mono/commit/f8f77efaef21299262becaa07b20c379b7f732ab))

## [2.1.0](https://github.com/taikoxyz/taiko-mono/compare/taiko-alethia-protocol-v2.0.0...taiko-alethia-protocol-v2.1.0) (2025-02-19)


### Features

* **protocol:** add `lastProposedIn` to slotB ([#18379](https://github.com/taikoxyz/taiko-mono/issues/18379)) ([96b380a](https://github.com/taikoxyz/taiko-mono/commit/96b380a452f1055da960146b4bf1e94c1842da73))
* **protocol:** add `proposeBlocksV2` method to `ProverSet` ([#18115](https://github.com/taikoxyz/taiko-mono/issues/18115)) ([0743a99](https://github.com/taikoxyz/taiko-mono/commit/0743a99ee6ab403024bab5834178399fbeebb4e5))
* **protocol:** add aggregated sgx verify test ([#18160](https://github.com/taikoxyz/taiko-mono/issues/18160)) ([8dda47b](https://github.com/taikoxyz/taiko-mono/commit/8dda47bf9ee47faa8a0d16dde0b4398d5e7019f8))
* **protocol:** add blobCreatedIn to BlobParams ([#18954](https://github.com/taikoxyz/taiko-mono/issues/18954)) ([adaf808](https://github.com/taikoxyz/taiko-mono/commit/adaf808a4baebf231953893a54e1e51c91bb88b7))
* **protocol:** add function in preconf whitelist to retrieve operator for next epoch ([#18935](https://github.com/taikoxyz/taiko-mono/issues/18935)) ([b22ed04](https://github.com/taikoxyz/taiko-mono/commit/b22ed04f6f5c91165e169c7acd18188985a908aa))
* **protocol:** add Hekla Ontake hardfork upgrade scripts ([#18103](https://github.com/taikoxyz/taiko-mono/issues/18103)) ([a3436e8](https://github.com/taikoxyz/taiko-mono/commit/a3436e8cafbc96ebfa5742ada995adae39c572ce))
* **protocol:** add scripts back for testing bridge ([#18910](https://github.com/taikoxyz/taiko-mono/issues/18910)) ([1151d38](https://github.com/taikoxyz/taiko-mono/commit/1151d3859518e561fc702ea40847e0fbcbfadb67))
* **protocol:** add solver support for l2 to l1 eth bridging ([#18805](https://github.com/taikoxyz/taiko-mono/issues/18805)) ([320ef05](https://github.com/taikoxyz/taiko-mono/commit/320ef0598b4ad357afb8805102c411c0e53c2a43))
* **protocol:** adjust the zk ratio(risc0 & sp1) ([#18613](https://github.com/taikoxyz/taiko-mono/issues/18613)) ([431435e](https://github.com/taikoxyz/taiko-mono/commit/431435e6e74799caea94f53438238c63831cf07c))
* **protocol:** adjust zk(risc0 & sp1) ratio ([#18684](https://github.com/taikoxyz/taiko-mono/issues/18684)) ([a0c21a3](https://github.com/taikoxyz/taiko-mono/commit/a0c21a382c779de54b119a6f9b2d5cd869f47f1d))
* **protocol:** allow `local.params.parentMetaHash` to remain as 0 ([#18451](https://github.com/taikoxyz/taiko-mono/issues/18451)) ([94185fe](https://github.com/taikoxyz/taiko-mono/commit/94185feb207b9a2e74fb05a4898d25ce2008f826))
* **protocol:** allow any ERC20 tokens or Ether to be used as bonds ([#18380](https://github.com/taikoxyz/taiko-mono/issues/18380)) ([1920521](https://github.com/taikoxyz/taiko-mono/commit/1920521a2478d1e31745742f1ddbb296cdd98f6f))
* **protocol:** allow msg.sender to customize block proposer addresses ([#18048](https://github.com/taikoxyz/taiko-mono/issues/18048)) ([22055cc](https://github.com/taikoxyz/taiko-mono/commit/22055cc95e51d07b6b57ab5cb2e4ccd9a97d594a))
* **protocol:** allow owner to update recipient in TokenUnlock ([#18184](https://github.com/taikoxyz/taiko-mono/issues/18184)) ([773ae1b](https://github.com/taikoxyz/taiko-mono/commit/773ae1b11f309ee8c4e0b1c0d22b9bfa41beae0d))
* **protocol:** allow per-block signals ([#18905](https://github.com/taikoxyz/taiko-mono/issues/18905)) ([980912a](https://github.com/taikoxyz/taiko-mono/commit/980912a1efa656ee0cd58a831d4bda5901cef959))
* **protocol:** change HeklaTaikoToken's clock mode to timestamp to test the DAO ([#18597](https://github.com/taikoxyz/taiko-mono/issues/18597)) ([ccc9500](https://github.com/taikoxyz/taiko-mono/commit/ccc9500d861d5cc666f038ddb8ceed00a353ee94))
* **protocol:** check `lastVerifiedBatchId` with Pacaya fork height in `getLastVerifiedTransition` ([#18906](https://github.com/taikoxyz/taiko-mono/issues/18906)) ([d97d726](https://github.com/taikoxyz/taiko-mono/commit/d97d72667468ea3e4b5d125fc6e589f4e90d5a1c))
* **protocol:** check-in `HeklaTaikoToken` ([#18189](https://github.com/taikoxyz/taiko-mono/issues/18189)) ([60c38d8](https://github.com/taikoxyz/taiko-mono/commit/60c38d8d179f2c02a0ed87f97bd34dc708b38df4))
* **protocol:** decrease the rate of risc0 in Hekla ([#18553](https://github.com/taikoxyz/taiko-mono/issues/18553)) ([57d20db](https://github.com/taikoxyz/taiko-mono/commit/57d20db59ffa23f7038ad80a4322634cc71251ea))
* **protocol:** enable sp1 batch aggregation ([#18199](https://github.com/taikoxyz/taiko-mono/issues/18199)) ([038cd32](https://github.com/taikoxyz/taiko-mono/commit/038cd326668b3a882798ecb4e7f9e3ecadc6dc28))
* **protocol:** improve `getTransitions` ([#18181](https://github.com/taikoxyz/taiko-mono/issues/18181)) ([868d733](https://github.com/taikoxyz/taiko-mono/commit/868d733db962a76261036c3e583cb50feaec901f))
* **protocol:** increase risc0 frequency in Hekla ([#18407](https://github.com/taikoxyz/taiko-mono/issues/18407)) ([350264c](https://github.com/taikoxyz/taiko-mono/commit/350264c98d6a96ea11d5b1cef684a81605d3826b))
* **protocol:** Increase the probability of sgx proof for lab proposer ([#18288](https://github.com/taikoxyz/taiko-mono/issues/18288)) ([fd0dbbb](https://github.com/taikoxyz/taiko-mono/commit/fd0dbbbb3df0db27873e0ba87e45a5165fb7c0f1))
* **protocol:** increase zk(risc0 & sp1) rate in mainnet ([#18481](https://github.com/taikoxyz/taiko-mono/issues/18481)) ([f24a908](https://github.com/taikoxyz/taiko-mono/commit/f24a908e60c062ad789a34765de5a1037bdb1ff0))
* **protocol:** introduce `getTransitions` in TaikoL1 ([#18154](https://github.com/taikoxyz/taiko-mono/issues/18154)) ([273bf53](https://github.com/taikoxyz/taiko-mono/commit/273bf53fad763b8504353e7cc14c8585e341f9d0))
* **protocol:** introduce ForkManager to improve protocol fork management ([#18508](https://github.com/taikoxyz/taiko-mono/issues/18508)) ([ff5c196](https://github.com/taikoxyz/taiko-mono/commit/ff5c1964a303e21dfeb87f8f9c01fc82ef43a03e))
* **protocol:** make `TaikoL2Deprecated` ABI go-ethereum compatible ([#18659](https://github.com/taikoxyz/taiko-mono/issues/18659)) ([05594cf](https://github.com/taikoxyz/taiko-mono/commit/05594cfe6fd188573f9db2de4e1f039ea7317c9b))
* **protocol:** make sure `init()` covers logics in `init2()`, `init3()`.. ([#18292](https://github.com/taikoxyz/taiko-mono/issues/18292)) ([9d06958](https://github.com/taikoxyz/taiko-mono/commit/9d06958e713e530fdd610c439c7b93199d0dcc69))
* **protocol:** measure gas per block using a debug event ([#18470](https://github.com/taikoxyz/taiko-mono/issues/18470)) ([e84e472](https://github.com/taikoxyz/taiko-mono/commit/e84e472e4a0479301d5ce1d4268d964705dcbbd0))
* **protocol:** pacaya fork with simplified based rollup protocol ([#18535](https://github.com/taikoxyz/taiko-mono/issues/18535)) ([3d85f7c](https://github.com/taikoxyz/taiko-mono/commit/3d85f7ce0420392f4e28db4554ab540e1e5e079a))
* **protocol:** propose a batch blocks conditionally ([#18570](https://github.com/taikoxyz/taiko-mono/issues/18570)) ([e846f62](https://github.com/taikoxyz/taiko-mono/commit/e846f6289fea0b046ddcfcdfaf46f3727efbdf11))
* **protocol:** rename B_BLOCK_PROPOSER to B_PRECONF_REGISTRY ([#18255](https://github.com/taikoxyz/taiko-mono/issues/18255)) ([bf3caf7](https://github.com/taikoxyz/taiko-mono/commit/bf3caf7d986d7b03cf3bd0aa69ea97602bff80aa))
* **protocol:** request zk proofs(risc0 & sp1) in mainnet ([#18467](https://github.com/taikoxyz/taiko-mono/issues/18467)) ([1fab427](https://github.com/taikoxyz/taiko-mono/commit/1fab427005708036c981f2b8fb47d9aa408e0d94))
* **protocol:** scripts to deploy new mainnet implementation contracts ([#18356](https://github.com/taikoxyz/taiko-mono/issues/18356)) ([269759b](https://github.com/taikoxyz/taiko-mono/commit/269759bccefba399f0aa6f45482f4a24330a5e47))
* **protocol:** support delayed forced inclusion of txs ([#18883](https://github.com/taikoxyz/taiko-mono/issues/18883)) ([a244be2](https://github.com/taikoxyz/taiko-mono/commit/a244be2f138a660e5d67dca8d57dc33d7906b099))
* **protocol:** tolerate invalid BaseFeeConfig on L2 ([#18338](https://github.com/taikoxyz/taiko-mono/issues/18338)) ([f9f5d15](https://github.com/taikoxyz/taiko-mono/commit/f9f5d156f9fef622d921f6e007ecb43ded0130ad))
* **protocol:** update `B_TIER_ROUTER` in `RollupAddressCache` ([#18370](https://github.com/taikoxyz/taiko-mono/issues/18370)) ([9748ae5](https://github.com/taikoxyz/taiko-mono/commit/9748ae527a75124f8674bb66280b9161ce79d046))
* **protocol:** update `ontakeForkHeight` to Sep 24, 2024 ([#18046](https://github.com/taikoxyz/taiko-mono/issues/18046)) ([30c9316](https://github.com/taikoxyz/taiko-mono/commit/30c9316aea083d187617f5342fb4a955e604226b))
* **protocol:** update `RollupAddressCache` with new `MainnetTierRouter` address ([#18619](https://github.com/taikoxyz/taiko-mono/issues/18619)) ([b2ca63c](https://github.com/taikoxyz/taiko-mono/commit/b2ca63cd4ed7eca385c317d9a6ade794bf156c79))
* **protocol:** update mainnet `ontakeForkHeight` config ([#18252](https://github.com/taikoxyz/taiko-mono/issues/18252)) ([7550882](https://github.com/taikoxyz/taiko-mono/commit/75508828d3755e1a831380cdd2ab321e67fa22fc))
* **protocol:** update ric0 & sp1 verification contract ([#18269](https://github.com/taikoxyz/taiko-mono/issues/18269)) ([684a909](https://github.com/taikoxyz/taiko-mono/commit/684a909e83705c59b2b7a0a991424b7a8e9e03ad))
* **protocol:** update sp1 contracts ([#18097](https://github.com/taikoxyz/taiko-mono/issues/18097)) ([6f26434](https://github.com/taikoxyz/taiko-mono/commit/6f264342fe48f8d193559ac0712cc875d643b6fd))
* **protocol:** update sp1 to 3.0.0 prod version ([#18465](https://github.com/taikoxyz/taiko-mono/issues/18465)) ([0b11101](https://github.com/taikoxyz/taiko-mono/commit/0b1110159201f94ff5a4df528eab60b306d4fb25))
* **protocol:** upgrade script ([#18334](https://github.com/taikoxyz/taiko-mono/issues/18334)) ([2c41dd1](https://github.com/taikoxyz/taiko-mono/commit/2c41dd10989566c1b6af691c92ab2cbde734a13a))
* **protocol:** upgrade sp1 contract to v4.0.0-rc.3 ([#18740](https://github.com/taikoxyz/taiko-mono/issues/18740)) ([a58852f](https://github.com/taikoxyz/taiko-mono/commit/a58852fd84357487b82b965dd0ab61b56de49b53))
* **protocol:** use immutables and add verifiers in `ComposeVerifier` ([#18937](https://github.com/taikoxyz/taiko-mono/issues/18937)) ([d5a7fe1](https://github.com/taikoxyz/taiko-mono/commit/d5a7fe1836361ccd43c3fd8a554afd2c4eeda1d0))
* **protocol:** user smaller cooldown windows ([#18345](https://github.com/taikoxyz/taiko-mono/issues/18345)) ([63455f9](https://github.com/taikoxyz/taiko-mono/commit/63455f91d202d88583d70bce69e799032523eb18))
* **taiko-client:** changes based on `Pacaya` fork ([#18746](https://github.com/taikoxyz/taiko-mono/issues/18746)) ([02ae1cf](https://github.com/taikoxyz/taiko-mono/commit/02ae1cf7163331914a350f65b9ccaef0923ae904))
* **taiko-client:** soft block driver APIs ([#18273](https://github.com/taikoxyz/taiko-mono/issues/18273)) ([9fff7ff](https://github.com/taikoxyz/taiko-mono/commit/9fff7ff3cce99e915e8142a090a7fad2f1af5bd4))


### Bug Fixes

* **protocl:** check blockId in getBlock and getBlockV2 ([#18327](https://github.com/taikoxyz/taiko-mono/issues/18327)) ([4288fb6](https://github.com/taikoxyz/taiko-mono/commit/4288fb6e0c8c76651d2db866cab55f32a9a25075))
* **protocol:** add timestamp as a new parameter to getBasefeeV2 ([#18686](https://github.com/taikoxyz/taiko-mono/issues/18686)) ([361c26a](https://github.com/taikoxyz/taiko-mono/commit/361c26adc62a6358c4d38c6a4d707274c84d7552))
* **protocol:** avoid invocation in Bridge message processing if calldata is "" and value is 0 ([#18137](https://github.com/taikoxyz/taiko-mono/issues/18137)) ([10c2972](https://github.com/taikoxyz/taiko-mono/commit/10c29727081bd8f8b94bbfc4472b162ec552ef64))
* **protocol:** avoid setting stateRoot = 0 in `ContextV2` ([#18858](https://github.com/taikoxyz/taiko-mono/issues/18858)) ([3055175](https://github.com/taikoxyz/taiko-mono/commit/3055175c00bba0374149577feed34ed66af835ac))
* **protocol:** correct the wrong router address for mainnet ([#18291](https://github.com/taikoxyz/taiko-mono/issues/18291)) ([ae0a9da](https://github.com/taikoxyz/taiko-mono/commit/ae0a9daf83ab8f323c216978724ebcb71de54cfe))
* **protocol:** deep copy context transition ([#18859](https://github.com/taikoxyz/taiko-mono/issues/18859)) ([0f4db9b](https://github.com/taikoxyz/taiko-mono/commit/0f4db9bc2c30ea58644e382d38dc26b11050851f))
* **protocol:** fix `tid` in `getTransitionByParentHash` ([#18895](https://github.com/taikoxyz/taiko-mono/issues/18895)) ([0071fcb](https://github.com/taikoxyz/taiko-mono/commit/0071fcb3e7f0a777d8013de4d9aa00dd0514d206))
* **protocol:** fix a new bug in LibProposing ([#18328](https://github.com/taikoxyz/taiko-mono/issues/18328)) ([7436bae](https://github.com/taikoxyz/taiko-mono/commit/7436bae9660cfcf1d430ca111df8c75d50908eae))
* **protocol:** fix an issue in same transition check ([#18254](https://github.com/taikoxyz/taiko-mono/issues/18254)) ([233806e](https://github.com/taikoxyz/taiko-mono/commit/233806e4838aa12e8de436a37979ff3e614119f2))
* **protocol:** fix DCAP configuration script ([#18088](https://github.com/taikoxyz/taiko-mono/issues/18088)) ([e8618c5](https://github.com/taikoxyz/taiko-mono/commit/e8618c54a58993499e852ec2ffc2468d4f0274ba))
* **protocol:** fix debitBond bug and add additional tests ([#18443](https://github.com/taikoxyz/taiko-mono/issues/18443)) ([75ff1f8](https://github.com/taikoxyz/taiko-mono/commit/75ff1f87412c763e6ed3431d13689a629a2dd668))
* **protocol:** fix issue in mainnet deployment script ([#18283](https://github.com/taikoxyz/taiko-mono/issues/18283)) ([5c371a1](https://github.com/taikoxyz/taiko-mono/commit/5c371a181af444999f611e03774ec096ffbd1226))
* **protocol:** fix LibAddress.supportsInterface to handle undecodeable return data ([#18286](https://github.com/taikoxyz/taiko-mono/issues/18286)) ([299b4c9](https://github.com/taikoxyz/taiko-mono/commit/299b4c9ecf96644c909df70a3527ae5c2e728a07))
* **protocol:** fix permission in ComposeVerifier ([#18302](https://github.com/taikoxyz/taiko-mono/issues/18302)) ([4c45d8b](https://github.com/taikoxyz/taiko-mono/commit/4c45d8bcdb52521ac1738ca271316d82689537b0))
* **protocol:** fix proposeBlock()'s block id check ([#18227](https://github.com/taikoxyz/taiko-mono/issues/18227)) ([3a9d6c1](https://github.com/taikoxyz/taiko-mono/commit/3a9d6c166b7c6666eb2515893b6a3fbd00f4b1ea))
* **protocol:** fix test related to SendMessageToDelegateOwner.s.sol ([#18300](https://github.com/taikoxyz/taiko-mono/issues/18300)) ([65daa3e](https://github.com/taikoxyz/taiko-mono/commit/65daa3e631b471d17dbffb1001dab66efa67c499))
* **protocol:** fix wrong Bridged ERC20 address cache ([#18287](https://github.com/taikoxyz/taiko-mono/issues/18287)) ([49267ab](https://github.com/taikoxyz/taiko-mono/commit/49267abaa6d27d16fe4fb62ca0bb28d49b09d2f9))
* **protocol:** make `RegularERC20` predeployed in genesis ([#18876](https://github.com/taikoxyz/taiko-mono/issues/18876)) ([149ddef](https://github.com/taikoxyz/taiko-mono/commit/149ddef32ae4a7281e2fa42f94d0db9caba509d5))
* **protocol:** make `TaikoAnchor` named `taiko` in L2 genesis ([#18877](https://github.com/taikoxyz/taiko-mono/issues/18877)) ([589797d](https://github.com/taikoxyz/taiko-mono/commit/589797dceca153a2da291519e4e7da83cc9d0f05))
* **protocol:** revert `B_TIER_OPTIMISTIC` back to `""` ([#18446](https://github.com/taikoxyz/taiko-mono/issues/18446)) ([9549e7f](https://github.com/taikoxyz/taiko-mono/commit/9549e7f3e899b22ff8c9ff7d731aa3ce250fd071))
* **protocol:** revert a change to maintain taiko-geth compatibility  ([#18331](https://github.com/taikoxyz/taiko-mono/issues/18331)) ([9d18d59](https://github.com/taikoxyz/taiko-mono/commit/9d18d598fe3e890a1f35e2d39916d554282ee4a0))
* **protocol:** revert changes related to `proposedIn` and `proposedAt` to fix a bug ([#18333](https://github.com/taikoxyz/taiko-mono/issues/18333)) ([5cb43ab](https://github.com/taikoxyz/taiko-mono/commit/5cb43ab1e29422353de549f8386eff613291c7df))
* **protocol:** reward non-assigned prover 7/8 liveness bond ([#18132](https://github.com/taikoxyz/taiko-mono/issues/18132)) ([9f99099](https://github.com/taikoxyz/taiko-mono/commit/9f99099ac271e6e2a0973a43084e29169386f2cd))
* **protocol:** small fix to 1559 error check ([#18339](https://github.com/taikoxyz/taiko-mono/issues/18339)) ([4428661](https://github.com/taikoxyz/taiko-mono/commit/44286615a0e0b0a17892fe83aad96546a6b1aca1))
* **protocol:** use `PacayaForkRouter` instead of `ForkRouter` ([#18891](https://github.com/taikoxyz/taiko-mono/issues/18891)) ([1dab819](https://github.com/taikoxyz/taiko-mono/commit/1dab8197c7067f093d9208701650698cf2df7aaa))
* **taiko-client:** fix the workflow to get `proof_verifier` ([#18936](https://github.com/taikoxyz/taiko-mono/issues/18936)) ([0d97116](https://github.com/taikoxyz/taiko-mono/commit/0d9711614a5a67e49dc129e4a21d82ad231eb4b2))


### Chores

* **docs:** redirect the contribution.md path ([#18316](https://github.com/taikoxyz/taiko-mono/issues/18316)) ([0607ef7](https://github.com/taikoxyz/taiko-mono/commit/0607ef718dbe34c0ffe125825b12001b36a43fc5))
* **main:** fix misspelled ([#18581](https://github.com/taikoxyz/taiko-mono/issues/18581)) ([3687c4e](https://github.com/taikoxyz/taiko-mono/commit/3687c4e060b4b316fb185c649e9b089b97d53eda))
* **main:** release protocol 1.10.0 ([#18077](https://github.com/taikoxyz/taiko-mono/issues/18077)) ([3d12cb2](https://github.com/taikoxyz/taiko-mono/commit/3d12cb24b16c7eede1930b928408c1462134f5a7))
* **main:** release protocol 1.10.0 ([#18365](https://github.com/taikoxyz/taiko-mono/issues/18365)) ([9345f14](https://github.com/taikoxyz/taiko-mono/commit/9345f1419a1e5d0f975e15bb372b6101da9f0c48))
* **main:** release protocol 1.11.0 ([#18433](https://github.com/taikoxyz/taiko-mono/issues/18433)) ([75359cc](https://github.com/taikoxyz/taiko-mono/commit/75359cc1f76151cdb2e087d0000ad9052f50e3c4))
* **main:** release protocol 1.9.0 ([#17783](https://github.com/taikoxyz/taiko-mono/issues/17783)) ([7bfd28a](https://github.com/taikoxyz/taiko-mono/commit/7bfd28a2b332c927cd8b6358623551814260f94e))
* **main:** release protocol 1.9.0 ([#18051](https://github.com/taikoxyz/taiko-mono/issues/18051)) ([2547ba9](https://github.com/taikoxyz/taiko-mono/commit/2547ba9409705bb759b62e59a7e5d5821349c71a))
* **main:** release protocol 1.9.0 ([#18052](https://github.com/taikoxyz/taiko-mono/issues/18052)) ([bf45889](https://github.com/taikoxyz/taiko-mono/commit/bf45889e18e97f1186cd60fd55e1b2664dc4bf43))
* **main:** release taiko-alethia-protocol 1.11.0 ([#18663](https://github.com/taikoxyz/taiko-mono/issues/18663)) ([42cd90d](https://github.com/taikoxyz/taiko-mono/commit/42cd90d3f0937b96095076f733f60ca26d3b5751))
* **main:** release taiko-alethia-protocol 1.11.0 ([#18695](https://github.com/taikoxyz/taiko-mono/issues/18695)) ([7802e7f](https://github.com/taikoxyz/taiko-mono/commit/7802e7f33c445417473dcba799dd1dfc68a9aa31))
* **main:** release taiko-alethia-protocol 1.11.0 ([#18761](https://github.com/taikoxyz/taiko-mono/issues/18761)) ([70942ea](https://github.com/taikoxyz/taiko-mono/commit/70942ea0a3307e049d5c0efaf90837b84453aa66))
* **main:** release taiko-alethia-protocol 1.12.0 ([#18762](https://github.com/taikoxyz/taiko-mono/issues/18762)) ([9d2aac8](https://github.com/taikoxyz/taiko-mono/commit/9d2aac8ea36559c20d6ef5e1d7614c8c99eefacc))
* **main:** release taiko-alethia-protocol 2.1.0 ([#18875](https://github.com/taikoxyz/taiko-mono/issues/18875)) ([c047077](https://github.com/taikoxyz/taiko-mono/commit/c047077e6cace1505dd150c2717206b397ce58a8))
* **protocol:** add a placeholder for Shasta fork height in config ([#18932](https://github.com/taikoxyz/taiko-mono/issues/18932)) ([2fe0c87](https://github.com/taikoxyz/taiko-mono/commit/2fe0c87028772a11bf47870e4667cb2a4fd27bab))
* **protocol:** add comment about signals in anchor ([#18901](https://github.com/taikoxyz/taiko-mono/issues/18901)) ([c4d4d46](https://github.com/taikoxyz/taiko-mono/commit/c4d4d4608a095e2f867109edd47be799706ebb56))
* **protocol:** add functions to ITaikoL1 for Nethermind Preconf ([#18217](https://github.com/taikoxyz/taiko-mono/issues/18217)) ([e349d22](https://github.com/taikoxyz/taiko-mono/commit/e349d2237a1830edab305b2f0eaaeb0eaf3c623f))
* **protocol:** change bond amounts, proving windows, and cooldown windows ([#18371](https://github.com/taikoxyz/taiko-mono/issues/18371)) ([fac5c16](https://github.com/taikoxyz/taiko-mono/commit/fac5c167357f430cfb030e7ceaa41bb8e4b938d4))
* **protocol:** change Hekla gas issuance per sec to 100000 ([#18335](https://github.com/taikoxyz/taiko-mono/issues/18335)) ([3d448d4](https://github.com/taikoxyz/taiko-mono/commit/3d448d4a78608ea7daf1d50e877c32f8d30f1e7a))
* **protocol:** change Hekla sharingPctg to 80% & gasIssuancePerSecond to 1000000 ([#18322](https://github.com/taikoxyz/taiko-mono/issues/18322)) ([75feb5b](https://github.com/taikoxyz/taiko-mono/commit/75feb5b36560b786a54e97280352c0d70c3e2f06))
* **protocol:** delete gas debug event ([#18620](https://github.com/taikoxyz/taiko-mono/issues/18620)) ([06128e8](https://github.com/taikoxyz/taiko-mono/commit/06128e8f64b7bf2997b70959c78ab256404ebab3))
* **protocol:** deploy `MainnetTierRouter` and update `RollupAddressCache` ([#18359](https://github.com/taikoxyz/taiko-mono/issues/18359)) ([aa351ab](https://github.com/taikoxyz/taiko-mono/commit/aa351ab0f90e442a8b15adb8de6a48d9ae6d1c42))
* **protocol:** fix documentation ([#18694](https://github.com/taikoxyz/taiko-mono/issues/18694)) ([c7c01a1](https://github.com/taikoxyz/taiko-mono/commit/c7c01a156e05d9126ba6fab7bd910dfa3602169a))
* **protocol:** fix lint issue in SP1Verifier ([#18213](https://github.com/taikoxyz/taiko-mono/issues/18213)) ([7874dd3](https://github.com/taikoxyz/taiko-mono/commit/7874dd3ff8a6053da8c09377b52c83e7a506f45f))
* **protocol:** fix typos in documentation files ([#18490](https://github.com/taikoxyz/taiko-mono/issues/18490)) ([8d1f9ea](https://github.com/taikoxyz/taiko-mono/commit/8d1f9eab8e02b1868f2e24005699a8ed1d2937fa))
* **protocol:** improve the usage of `initializer` and `reinitializer` ([#18319](https://github.com/taikoxyz/taiko-mono/issues/18319)) ([13cc007](https://github.com/taikoxyz/taiko-mono/commit/13cc0074a2295c5939cf83e23f531cb25c43bd64))
* **protocol:** optimize Taiko L1 gas cost ([#18376](https://github.com/taikoxyz/taiko-mono/issues/18376)) ([ea0158f](https://github.com/taikoxyz/taiko-mono/commit/ea0158f0cbaa974f90f9174410c705e6cbdc48aa))
* **protocol:** re-generate layout files with diff order for comparison with new PR ([#18067](https://github.com/taikoxyz/taiko-mono/issues/18067)) ([078d336](https://github.com/taikoxyz/taiko-mono/commit/078d3367dce86a57d71d48291537e925cb1b4b91))
* **protocol:** remove `TIER_ZKVM_ANY` in `MainnetTierRouter` ([#18357](https://github.com/taikoxyz/taiko-mono/issues/18357)) ([500a8bb](https://github.com/taikoxyz/taiko-mono/commit/500a8bbc46a3d1962ae5cc6d7f10e990f03d07c7))
* **protocol:** remove repetitive words in audit report ([#18584](https://github.com/taikoxyz/taiko-mono/issues/18584)) ([8092ee5](https://github.com/taikoxyz/taiko-mono/commit/8092ee56e00ed3e422471a9ed85c42fad6c19a13))
* **protocol:** restore proving window changes ([#18368](https://github.com/taikoxyz/taiko-mono/issues/18368)) ([9182fba](https://github.com/taikoxyz/taiko-mono/commit/9182fbaf05d309f9827310f3616992c0cc88a22d))
* **protocol:** revert Hekla `baseFeeConfig` updates ([#18340](https://github.com/taikoxyz/taiko-mono/issues/18340)) ([ae8ac3c](https://github.com/taikoxyz/taiko-mono/commit/ae8ac3c2e686b136de8c68853ecb91a39260a93f))
* **protocol:** revert releasing protocol 1.9.0 ([#17783](https://github.com/taikoxyz/taiko-mono/issues/17783)) ([#18049](https://github.com/taikoxyz/taiko-mono/issues/18049)) ([c033810](https://github.com/taikoxyz/taiko-mono/commit/c033810ecc4c80a4581a95b06ab5127747efd191))
* **protocol:** set mainnet Ontake fork height ([#18112](https://github.com/taikoxyz/taiko-mono/issues/18112)) ([8812eb2](https://github.com/taikoxyz/taiko-mono/commit/8812eb2a8de367311b8ada6bd3587bfe5efee090))
* **protocol:** shorten imports in solidity files ([#18221](https://github.com/taikoxyz/taiko-mono/issues/18221)) ([9b2ba6a](https://github.com/taikoxyz/taiko-mono/commit/9b2ba6a2a2fae24d1fb34e23b29b3146e96f575e))
* **protocol:** undo 1.10.0 release ([#18363](https://github.com/taikoxyz/taiko-mono/issues/18363)) ([116578e](https://github.com/taikoxyz/taiko-mono/commit/116578ef8a4391611bd1b3c469f4068cec8a8447))
* **protoco:** remove unused delegate owner deployment ([#18290](https://github.com/taikoxyz/taiko-mono/issues/18290)) ([63ba863](https://github.com/taikoxyz/taiko-mono/commit/63ba863dcf322b2cf04d7dcaf6d8905bf28de6bc))
* **protoocl:** optimize code based on OZ defender suggestions ([#18879](https://github.com/taikoxyz/taiko-mono/issues/18879)) ([760fb56](https://github.com/taikoxyz/taiko-mono/commit/760fb56d8c698fce75b4fa163b717fa773cb4006))
* **repo:** improve documentation and changelog ([#18489](https://github.com/taikoxyz/taiko-mono/issues/18489)) ([c7b9b4f](https://github.com/taikoxyz/taiko-mono/commit/c7b9b4f01098d4fab337b9ff456ce394cdaf3a79))
* **taiko-client:** update Go contract bindings ([#18930](https://github.com/taikoxyz/taiko-mono/issues/18930)) ([c420ba2](https://github.com/taikoxyz/taiko-mono/commit/c420ba294ad1c81ca42e24d9a4a5b1aaacee2282))
* **taiko-client:** update Go contract bindings ([#18934](https://github.com/taikoxyz/taiko-mono/issues/18934)) ([d9fb5b1](https://github.com/taikoxyz/taiko-mono/commit/d9fb5b165ffc6cf23eac177db56d6f5029630f32))


### Documentation

* **protocol:** add mainnet zkVM verifiers deployment ([#18454](https://github.com/taikoxyz/taiko-mono/issues/18454)) ([3481b68](https://github.com/taikoxyz/taiko-mono/commit/3481b68e8d377c1ae6fc5a1a0e08d8411f94c613))
* **protocol:** add Ontake fork audit report from OpenZeppelin ([#18491](https://github.com/taikoxyz/taiko-mono/issues/18491)) ([e83adc0](https://github.com/taikoxyz/taiko-mono/commit/e83adc06ac4ce8ebe7e34feaad5691176dba27e2))
* **protocol:** fix invalid links in docs ([#18144](https://github.com/taikoxyz/taiko-mono/issues/18144)) ([c62f3f6](https://github.com/taikoxyz/taiko-mono/commit/c62f3f6b4a21f3af44f7df908fd8aac198721d5b))
* **protocol:** update `tier_router` for zk any on Hekla ([#18945](https://github.com/taikoxyz/taiko-mono/issues/18945)) ([4090528](https://github.com/taikoxyz/taiko-mono/commit/4090528773dad30e34edfb709e100abc5852caba))
* **protocol:** update `tier_router` in hekla ([#18352](https://github.com/taikoxyz/taiko-mono/issues/18352)) ([7c91a7d](https://github.com/taikoxyz/taiko-mono/commit/7c91a7d486c22e0f1a5386978086dfca5b73cfe0))
* **protocol:** update code4rena-2024-03-taiko-final-report.md ([#18062](https://github.com/taikoxyz/taiko-mono/issues/18062)) ([fd68794](https://github.com/taikoxyz/taiko-mono/commit/fd68794a2de24b7a32d2d5a1c3f52c2156b6d61a))
* **protocol:** update Hekla deployment ([#18856](https://github.com/taikoxyz/taiko-mono/issues/18856)) ([f0d876c](https://github.com/taikoxyz/taiko-mono/commit/f0d876ce3076b84d9d5fae439a01e166acecaca5))
* **protocol:** update Hekla deployment ([#18860](https://github.com/taikoxyz/taiko-mono/issues/18860)) ([ac3075c](https://github.com/taikoxyz/taiko-mono/commit/ac3075c4fa6718b4e5c4b0bd7a6f240111dfc914))
* **protocol:** update Hekla deployments ([#18152](https://github.com/taikoxyz/taiko-mono/issues/18152)) ([6c7ff61](https://github.com/taikoxyz/taiko-mono/commit/6c7ff617b913b21b8b12b035f0d653c068830de3))
* **protocol:** update Hekla deployments ([#18257](https://github.com/taikoxyz/taiko-mono/issues/18257)) ([fbb1c82](https://github.com/taikoxyz/taiko-mono/commit/fbb1c824e35adb452176d988f32cf06d0c72b9bf))
* **protocol:** update Hekla deployments ([#18598](https://github.com/taikoxyz/taiko-mono/issues/18598)) ([a095c69](https://github.com/taikoxyz/taiko-mono/commit/a095c69a240d64606b09a26f2e80ad6daf18c273))
* **protocol:** update L1 deployment ([#18299](https://github.com/taikoxyz/taiko-mono/issues/18299)) ([f60ce3e](https://github.com/taikoxyz/taiko-mono/commit/f60ce3e78bb9a2717718c3a9d7016346d5305488))
* **protocol:** update mainnet deployment ([#18258](https://github.com/taikoxyz/taiko-mono/issues/18258)) ([eeeb4af](https://github.com/taikoxyz/taiko-mono/commit/eeeb4afeff8572115c2cf82db149cee7a723f30c))
* **protocol:** update mainnet deployment docs ([#18366](https://github.com/taikoxyz/taiko-mono/issues/18366)) ([bbd69ca](https://github.com/taikoxyz/taiko-mono/commit/bbd69ca583257ade30ac9ea2601509af5bc0789a))
* **protocol:** update mainnet deployment docs ([#18482](https://github.com/taikoxyz/taiko-mono/issues/18482)) ([9da8499](https://github.com/taikoxyz/taiko-mono/commit/9da849989249072e3a03e611b9c08b00295cf42c))
* **protocol:** update mainnet deployment docs ([#18621](https://github.com/taikoxyz/taiko-mono/issues/18621)) ([eb542bf](https://github.com/taikoxyz/taiko-mono/commit/eb542bf67dea51fd42c0f5c40ee987e5acadc3fd))
* **protocol:** update mainnet deployment docs ([#18645](https://github.com/taikoxyz/taiko-mono/issues/18645)) ([59d4f10](https://github.com/taikoxyz/taiko-mono/commit/59d4f107edc1aaac5716067634735bad03e75269))
* **protocol:** update mainnet deployment docs ([#18754](https://github.com/taikoxyz/taiko-mono/issues/18754)) ([45f5cdc](https://github.com/taikoxyz/taiko-mono/commit/45f5cdc514d47042b6aa810c188062a85b050adf))
* **protocol:** update mainnet deployment docs ([#18933](https://github.com/taikoxyz/taiko-mono/issues/18933)) ([7481810](https://github.com/taikoxyz/taiko-mono/commit/748181073d34bc1a4f4f7616ed15bdccea32bd7f))
* **protocol:** update README.md ([#18938](https://github.com/taikoxyz/taiko-mono/issues/18938)) ([13b6d32](https://github.com/taikoxyz/taiko-mono/commit/13b6d3224b5c668f164684a00a03900d3f45e73e))
* **protocol:** upgrade protocol version in hekla to 1.10.0 ([#18343](https://github.com/taikoxyz/taiko-mono/issues/18343)) ([4805024](https://github.com/taikoxyz/taiko-mono/commit/4805024c15ab63bf345dcc5f5868a4a16af0ba48))
* **protocol:** upgrade sp1 plonk verifier 2.0.0 ([#18098](https://github.com/taikoxyz/taiko-mono/issues/18098)) ([cfd0e9e](https://github.com/taikoxyz/taiko-mono/commit/cfd0e9e4af2e42ead309e0c571b09dd20ddfe0f9))
* **protocol:** upgrade sp1 remote verifier in Hekla ([#18469](https://github.com/taikoxyz/taiko-mono/issues/18469)) ([051b619](https://github.com/taikoxyz/taiko-mono/commit/051b619c6ce93a09c7e14dd8fafc99681c9261ad))
* **protocol:** upgrade verifiers to support proof aggregation in Hekla ([#18453](https://github.com/taikoxyz/taiko-mono/issues/18453)) ([bfb0386](https://github.com/taikoxyz/taiko-mono/commit/bfb03864ee83ccc3bce989f3e9fd2309eb90c277))
* **protocol:** upgrade zk verifiers in Hekla ([#18279](https://github.com/taikoxyz/taiko-mono/issues/18279)) ([e98a1d5](https://github.com/taikoxyz/taiko-mono/commit/e98a1d5cdaa14af86340081ee42ad263a41bfdb5))
* **repo:** improve grammar and readability ([#18501](https://github.com/taikoxyz/taiko-mono/issues/18501)) ([61994ff](https://github.com/taikoxyz/taiko-mono/commit/61994ffefcf29981beb567b84a3a55706300cf13))


### Code Refactoring

* **protocol:** extra a new function in LibProposing ([#18456](https://github.com/taikoxyz/taiko-mono/issues/18456)) ([5b4b0cd](https://github.com/taikoxyz/taiko-mono/commit/5b4b0cd271534aa72d865afa5fc55e0ee4b16b73))
* **protocol:** extract an IBlockHash interface from TaikoL2 ([#18045](https://github.com/taikoxyz/taiko-mono/issues/18045)) ([bff481e](https://github.com/taikoxyz/taiko-mono/commit/bff481e8a2898fab8396d368de84f8f343c532f0))
* **protocol:** improve comments in TaikoAnchor ([#18959](https://github.com/taikoxyz/taiko-mono/issues/18959)) ([d698944](https://github.com/taikoxyz/taiko-mono/commit/d698944ecb2fddd3a8c51e69507c8703b51a2e80))
* **protocol:** remove unused code post Ontake fork ([#18150](https://github.com/taikoxyz/taiko-mono/issues/18150)) ([8543cec](https://github.com/taikoxyz/taiko-mono/commit/8543cecdef9d10d038bc5a7313230006acd26e22))
* **protocol:** restructure solidity code to match compilation targets ([#18059](https://github.com/taikoxyz/taiko-mono/issues/18059)) ([adc47f4](https://github.com/taikoxyz/taiko-mono/commit/adc47f408282c25c7a50c26e31130fc495734dcc))
* **protocol:** simplify some protocol code based on OpenZeppelin's recommendation ([#18308](https://github.com/taikoxyz/taiko-mono/issues/18308)) ([fbad703](https://github.com/taikoxyz/taiko-mono/commit/fbad703739f09d4524f9d808c3bad31d0122ec2c))
* **protocol:** slightly change defender monitors ([#18086](https://github.com/taikoxyz/taiko-mono/issues/18086)) ([b93d056](https://github.com/taikoxyz/taiko-mono/commit/b93d056479adfc4a1f557578d8b66eda48b104a9))
* **protocol:** slightly improve EssentialContract ([#18445](https://github.com/taikoxyz/taiko-mono/issues/18445)) ([3d077f8](https://github.com/taikoxyz/taiko-mono/commit/3d077f8ee520a116028711391c323c7badd1f2c6))
* **protocol:** use immutables to avoid address resolving ([#18913](https://github.com/taikoxyz/taiko-mono/issues/18913)) ([d5f9fe5](https://github.com/taikoxyz/taiko-mono/commit/d5f9fe58a0076173f7bed42ade724e135a55b0e9))


### Tests

* **protocol:** check LibEIP1559 function results in fuzz tests ([#18475](https://github.com/taikoxyz/taiko-mono/issues/18475)) ([06e190c](https://github.com/taikoxyz/taiko-mono/commit/06e190c01bc4c4aae25664e8c2c154d8cf46efa5))
* **protocol:** fix another L2 test failure ([#18304](https://github.com/taikoxyz/taiko-mono/issues/18304)) ([b3dd4dc](https://github.com/taikoxyz/taiko-mono/commit/b3dd4dccd261a9ebda69325661d2941001268ec2))


### Workflow

* **protocol:** fix issue in gen-layouts.sh ([#18871](https://github.com/taikoxyz/taiko-mono/issues/18871)) ([6a24166](https://github.com/taikoxyz/taiko-mono/commit/6a2416664ac4652e3420d9de68580278885310ee))
* **protocol:** make the storage layout table clearer ([#18633](https://github.com/taikoxyz/taiko-mono/issues/18633)) ([7394458](https://github.com/taikoxyz/taiko-mono/commit/73944585586686ad1ce5548ce59e9ea583c4b2ee))
* **protocol:** revert "chore(main): release taiko-alethia-protocol 1.11.0 ([#18663](https://github.com/taikoxyz/taiko-mono/issues/18663))" ([#18688](https://github.com/taikoxyz/taiko-mono/issues/18688)) ([7e6bce4](https://github.com/taikoxyz/taiko-mono/commit/7e6bce4a0dac9e4f2984ffe2d3da2fc1277fab27))
* **protocol:** revert "chore(main): release taiko-alethia-protocol 1.11.0 ([#18695](https://github.com/taikoxyz/taiko-mono/issues/18695))" ([#18760](https://github.com/taikoxyz/taiko-mono/issues/18760)) ([e8ab39a](https://github.com/taikoxyz/taiko-mono/commit/e8ab39a9ffa0e3e3ec79efbd476864cef5e5eab4))
* **protocol:** revert "chore(main): release taiko-alethia-protocol 2.1.0 ([#18875](https://github.com/taikoxyz/taiko-mono/issues/18875))" ([#18927](https://github.com/taikoxyz/taiko-mono/issues/18927)) ([b38a6be](https://github.com/taikoxyz/taiko-mono/commit/b38a6be8d03b1107e014f2260bc9739eed1450e4))
* **protocol:** revert releasing protocol 1.11.0 ([#18662](https://github.com/taikoxyz/taiko-mono/issues/18662)) ([29ce093](https://github.com/taikoxyz/taiko-mono/commit/29ce093100ae76b9eb51eef0f560207422496990))
* **protocol:** trigger patch release (1.10.1) ([#18358](https://github.com/taikoxyz/taiko-mono/issues/18358)) ([f4f4796](https://github.com/taikoxyz/taiko-mono/commit/f4f4796488059b02c79d6fb15170df58dd31dc4e))


### Build

* **deps:** bump github.com/stretchr/testify from 1.9.0 to 1.10.0 ([#18539](https://github.com/taikoxyz/taiko-mono/issues/18539)) ([79f3fab](https://github.com/taikoxyz/taiko-mono/commit/79f3fab5f1d1ec1bb4ee18afb9268b622e894780))
* **deps:** bump golang.org/x/sync from 0.9.0 to 0.10.0 ([#18560](https://github.com/taikoxyz/taiko-mono/issues/18560)) ([3d51970](https://github.com/taikoxyz/taiko-mono/commit/3d51970aa0953bbfecaeebf76ea7e664c875c0e4))

## [1.12.0](https://github.com/taikoxyz/taiko-mono/compare/taiko-alethia-protocol-v1.11.0...taiko-alethia-protocol-v1.12.0) (2025-02-04)


### Features

* **protocol:** adjust zk(risc0 & sp1) ratio ([#18684](https://github.com/taikoxyz/taiko-mono/issues/18684)) ([a0c21a3](https://github.com/taikoxyz/taiko-mono/commit/a0c21a382c779de54b119a6f9b2d5cd869f47f1d))
* **protocol:** upgrade sp1 contract to v4.0.0-rc.3 ([#18740](https://github.com/taikoxyz/taiko-mono/issues/18740)) ([a58852f](https://github.com/taikoxyz/taiko-mono/commit/a58852fd84357487b82b965dd0ab61b56de49b53))
* **taiko-client:** soft block driver APIs ([#18273](https://github.com/taikoxyz/taiko-mono/issues/18273)) ([9fff7ff](https://github.com/taikoxyz/taiko-mono/commit/9fff7ff3cce99e915e8142a090a7fad2f1af5bd4))


### Bug Fixes

* **protocol:** add timestamp as a new parameter to getBasefeeV2 ([#18686](https://github.com/taikoxyz/taiko-mono/issues/18686)) ([361c26a](https://github.com/taikoxyz/taiko-mono/commit/361c26adc62a6358c4d38c6a4d707274c84d7552))
* **protocol:** avoid setting stateRoot = 0 in `ContextV2` ([#18858](https://github.com/taikoxyz/taiko-mono/issues/18858)) ([3055175](https://github.com/taikoxyz/taiko-mono/commit/3055175c00bba0374149577feed34ed66af835ac))
* **protocol:** deep copy context transition ([#18859](https://github.com/taikoxyz/taiko-mono/issues/18859)) ([0f4db9b](https://github.com/taikoxyz/taiko-mono/commit/0f4db9bc2c30ea58644e382d38dc26b11050851f))


### Chores

* **main:** release taiko-alethia-protocol 1.11.0 ([#18695](https://github.com/taikoxyz/taiko-mono/issues/18695)) ([7802e7f](https://github.com/taikoxyz/taiko-mono/commit/7802e7f33c445417473dcba799dd1dfc68a9aa31))
* **main:** release taiko-alethia-protocol 1.11.0 ([#18761](https://github.com/taikoxyz/taiko-mono/issues/18761)) ([70942ea](https://github.com/taikoxyz/taiko-mono/commit/70942ea0a3307e049d5c0efaf90837b84453aa66))
* **protocol:** fix documentation ([#18694](https://github.com/taikoxyz/taiko-mono/issues/18694)) ([c7c01a1](https://github.com/taikoxyz/taiko-mono/commit/c7c01a156e05d9126ba6fab7bd910dfa3602169a))


### Documentation

* **protocol:** update Hekla deployment ([#18856](https://github.com/taikoxyz/taiko-mono/issues/18856)) ([f0d876c](https://github.com/taikoxyz/taiko-mono/commit/f0d876ce3076b84d9d5fae439a01e166acecaca5))
* **protocol:** update Hekla deployment ([#18860](https://github.com/taikoxyz/taiko-mono/issues/18860)) ([ac3075c](https://github.com/taikoxyz/taiko-mono/commit/ac3075c4fa6718b4e5c4b0bd7a6f240111dfc914))
* **protocol:** update mainnet deployment docs ([#18754](https://github.com/taikoxyz/taiko-mono/issues/18754)) ([45f5cdc](https://github.com/taikoxyz/taiko-mono/commit/45f5cdc514d47042b6aa810c188062a85b050adf))


### Workflow

* **protocol:** revert "chore(main): release taiko-alethia-protocol 1.11.0 ([#18663](https://github.com/taikoxyz/taiko-mono/issues/18663))" ([#18688](https://github.com/taikoxyz/taiko-mono/issues/18688)) ([7e6bce4](https://github.com/taikoxyz/taiko-mono/commit/7e6bce4a0dac9e4f2984ffe2d3da2fc1277fab27))
* **protocol:** revert "chore(main): release taiko-alethia-protocol 1.11.0 ([#18695](https://github.com/taikoxyz/taiko-mono/issues/18695))" ([#18760](https://github.com/taikoxyz/taiko-mono/issues/18760)) ([e8ab39a](https://github.com/taikoxyz/taiko-mono/commit/e8ab39a9ffa0e3e3ec79efbd476864cef5e5eab4))

## [1.11.0](https://github.com/taikoxyz/taiko-mono/compare/taiko-alethia-protocol-v1.10.0...taiko-alethia-protocol-v1.11.0) (2025-01-13)


### Features

* **protocol:** add `lastProposedIn` to slotB ([#18379](https://github.com/taikoxyz/taiko-mono/issues/18379)) ([96b380a](https://github.com/taikoxyz/taiko-mono/commit/96b380a452f1055da960146b4bf1e94c1842da73))
* **protocol:** add `proposeBlocksV2` method to `ProverSet` ([#18115](https://github.com/taikoxyz/taiko-mono/issues/18115)) ([0743a99](https://github.com/taikoxyz/taiko-mono/commit/0743a99ee6ab403024bab5834178399fbeebb4e5))
* **protocol:** add `proveBlocks` method to `ProverSet` ([#18025](https://github.com/taikoxyz/taiko-mono/issues/18025)) ([36a2ae5](https://github.com/taikoxyz/taiko-mono/commit/36a2ae51c21a2359179755457a8933a346ccd8b3))
* **protocol:** add `TIER_ZKVM_RISC0` tier and `HeklaTierProvider` ([#17913](https://github.com/taikoxyz/taiko-mono/issues/17913)) ([64ed666](https://github.com/taikoxyz/taiko-mono/commit/64ed66628a18cb1b3fff2c4ab5d3c0149288dfe6))
* **protocol:** add aggregated sgx verify test ([#18160](https://github.com/taikoxyz/taiko-mono/issues/18160)) ([8dda47b](https://github.com/taikoxyz/taiko-mono/commit/8dda47bf9ee47faa8a0d16dde0b4398d5e7019f8))
* **protocol:** add ComposeVerifier, TeeAnyVerifier, and ZkAnyVerifier ([ee464ca](https://github.com/taikoxyz/taiko-mono/commit/ee464caef68fdec325aa22758bb69e17dd039794))
* **protocol:** add Hekla Ontake hardfork upgrade scripts ([#18103](https://github.com/taikoxyz/taiko-mono/issues/18103)) ([a3436e8](https://github.com/taikoxyz/taiko-mono/commit/a3436e8cafbc96ebfa5742ada995adae39c572ce))
* **protocol:** add proposer address to getMinTier func ([#17919](https://github.com/taikoxyz/taiko-mono/issues/17919)) ([d6ea6f3](https://github.com/taikoxyz/taiko-mono/commit/d6ea6f33d6bf54cba3bd6ab153e38d09abf19912))
* **protocol:** adjust the zk ratio(risc0 & sp1) ([#18613](https://github.com/taikoxyz/taiko-mono/issues/18613)) ([431435e](https://github.com/taikoxyz/taiko-mono/commit/431435e6e74799caea94f53438238c63831cf07c))
* **protocol:** adjust zk(risc0 & sp1) ratio ([#18684](https://github.com/taikoxyz/taiko-mono/issues/18684)) ([a0c21a3](https://github.com/taikoxyz/taiko-mono/commit/a0c21a382c779de54b119a6f9b2d5cd869f47f1d))
* **protocol:** allow `local.params.parentMetaHash` to remain as 0 ([#18451](https://github.com/taikoxyz/taiko-mono/issues/18451)) ([94185fe](https://github.com/taikoxyz/taiko-mono/commit/94185feb207b9a2e74fb05a4898d25ce2008f826))
* **protocol:** allow any ERC20 tokens or Ether to be used as bonds ([#18380](https://github.com/taikoxyz/taiko-mono/issues/18380)) ([1920521](https://github.com/taikoxyz/taiko-mono/commit/1920521a2478d1e31745742f1ddbb296cdd98f6f))
* **protocol:** allow msg.sender to customize block proposer addresses ([#18048](https://github.com/taikoxyz/taiko-mono/issues/18048)) ([22055cc](https://github.com/taikoxyz/taiko-mono/commit/22055cc95e51d07b6b57ab5cb2e4ccd9a97d594a))
* **protocol:** allow owner to update recipient in TokenUnlock ([#18184](https://github.com/taikoxyz/taiko-mono/issues/18184)) ([773ae1b](https://github.com/taikoxyz/taiko-mono/commit/773ae1b11f309ee8c4e0b1c0d22b9bfa41beae0d))
* **protocol:** change HeklaTaikoToken's clock mode to timestamp to test the DAO ([#18597](https://github.com/taikoxyz/taiko-mono/issues/18597)) ([ccc9500](https://github.com/taikoxyz/taiko-mono/commit/ccc9500d861d5cc666f038ddb8ceed00a353ee94))
* **protocol:** check-in `HeklaTaikoToken` ([#18189](https://github.com/taikoxyz/taiko-mono/issues/18189)) ([60c38d8](https://github.com/taikoxyz/taiko-mono/commit/60c38d8d179f2c02a0ed87f97bd34dc708b38df4))
* **protocol:** decrease the rate of risc0 in Hekla ([#18553](https://github.com/taikoxyz/taiko-mono/issues/18553)) ([57d20db](https://github.com/taikoxyz/taiko-mono/commit/57d20db59ffa23f7038ad80a4322634cc71251ea))
* **protocol:** enable sp1 batch aggregation ([#18199](https://github.com/taikoxyz/taiko-mono/issues/18199)) ([038cd32](https://github.com/taikoxyz/taiko-mono/commit/038cd326668b3a882798ecb4e7f9e3ecadc6dc28))
* **protocol:** improve `getTransitions` ([#18181](https://github.com/taikoxyz/taiko-mono/issues/18181)) ([868d733](https://github.com/taikoxyz/taiko-mono/commit/868d733db962a76261036c3e583cb50feaec901f))
* **protocol:** improve L2 basefee calculation ([920bd68](https://github.com/taikoxyz/taiko-mono/commit/920bd6873d3e9e1bbb00751fb9c0056ac85b8554))
* **protocol:** increase risc0 frequency in Hekla ([#18407](https://github.com/taikoxyz/taiko-mono/issues/18407)) ([350264c](https://github.com/taikoxyz/taiko-mono/commit/350264c98d6a96ea11d5b1cef684a81605d3826b))
* **protocol:** Increase the probability of sgx proof for lab proposer ([#18288](https://github.com/taikoxyz/taiko-mono/issues/18288)) ([fd0dbbb](https://github.com/taikoxyz/taiko-mono/commit/fd0dbbbb3df0db27873e0ba87e45a5165fb7c0f1))
* **protocol:** increase zk(risc0 & sp1) rate in mainnet ([#18481](https://github.com/taikoxyz/taiko-mono/issues/18481)) ([f24a908](https://github.com/taikoxyz/taiko-mono/commit/f24a908e60c062ad789a34765de5a1037bdb1ff0))
* **protocol:** introduce `getTransitions` in TaikoL1 ([#18154](https://github.com/taikoxyz/taiko-mono/issues/18154)) ([273bf53](https://github.com/taikoxyz/taiko-mono/commit/273bf53fad763b8504353e7cc14c8585e341f9d0))
* **protocol:** introduce ForkManager to improve protocol fork management ([#18508](https://github.com/taikoxyz/taiko-mono/issues/18508)) ([ff5c196](https://github.com/taikoxyz/taiko-mono/commit/ff5c1964a303e21dfeb87f8f9c01fc82ef43a03e))
* **protocol:** make `TaikoL2Deprecated` ABI go-ethereum compatible ([#18659](https://github.com/taikoxyz/taiko-mono/issues/18659)) ([05594cf](https://github.com/taikoxyz/taiko-mono/commit/05594cfe6fd188573f9db2de4e1f039ea7317c9b))
* **protocol:** make sure `init()` covers logics in `init2()`, `init3()`.. ([#18292](https://github.com/taikoxyz/taiko-mono/issues/18292)) ([9d06958](https://github.com/taikoxyz/taiko-mono/commit/9d06958e713e530fdd610c439c7b93199d0dcc69))
* **protocol:** measure gas per block using a debug event ([#18470](https://github.com/taikoxyz/taiko-mono/issues/18470)) ([e84e472](https://github.com/taikoxyz/taiko-mono/commit/e84e472e4a0479301d5ce1d4268d964705dcbbd0))
* **protocol:** propose a batch blocks conditionally ([#18570](https://github.com/taikoxyz/taiko-mono/issues/18570)) ([e846f62](https://github.com/taikoxyz/taiko-mono/commit/e846f6289fea0b046ddcfcdfaf46f3727efbdf11))
* **protocol:** protocol monitors ([#18002](https://github.com/taikoxyz/taiko-mono/issues/18002)) ([45b2087](https://github.com/taikoxyz/taiko-mono/commit/45b2087495d4f9e20083ebe2c61ecfe8d252e4b2))
* **protocol:** rename B_BLOCK_PROPOSER to B_PRECONF_REGISTRY ([#18255](https://github.com/taikoxyz/taiko-mono/issues/18255)) ([bf3caf7](https://github.com/taikoxyz/taiko-mono/commit/bf3caf7d986d7b03cf3bd0aa69ea97602bff80aa))
* **protocol:** request zk proofs(risc0 & sp1) in mainnet ([#18467](https://github.com/taikoxyz/taiko-mono/issues/18467)) ([1fab427](https://github.com/taikoxyz/taiko-mono/commit/1fab427005708036c981f2b8fb47d9aa408e0d94))
* **protocol:** script of `UpgradeRisc0Verifier` ([#17949](https://github.com/taikoxyz/taiko-mono/issues/17949)) ([fc12e04](https://github.com/taikoxyz/taiko-mono/commit/fc12e040c391e0f37c906b270743d3b57710f69d))
* **protocol:** scripts to deploy new mainnet implementation contracts ([#18356](https://github.com/taikoxyz/taiko-mono/issues/18356)) ([269759b](https://github.com/taikoxyz/taiko-mono/commit/269759bccefba399f0aa6f45482f4a24330a5e47))
* **protocol:** support backward-compatible batch-proof verification ([#17968](https://github.com/taikoxyz/taiko-mono/issues/17968)) ([c476aab](https://github.com/taikoxyz/taiko-mono/commit/c476aabe130d151f5678cd35fab99f258997f629))
* **protocol:** tolerate invalid BaseFeeConfig on L2 ([#18338](https://github.com/taikoxyz/taiko-mono/issues/18338)) ([f9f5d15](https://github.com/taikoxyz/taiko-mono/commit/f9f5d156f9fef622d921f6e007ecb43ded0130ad))
* **protocol:** update `B_TIER_ROUTER` in `RollupAddressCache` ([#18370](https://github.com/taikoxyz/taiko-mono/issues/18370)) ([9748ae5](https://github.com/taikoxyz/taiko-mono/commit/9748ae527a75124f8674bb66280b9161ce79d046))
* **protocol:** update `HeklaTierProvider` to introduce sp1 proof ([#18022](https://github.com/taikoxyz/taiko-mono/issues/18022)) ([76b6514](https://github.com/taikoxyz/taiko-mono/commit/76b6514fd42ba7fa2124b44443728fa32304c324))
* **protocol:** update `ontakeForkHeight` to Sep 24, 2024 ([#18046](https://github.com/taikoxyz/taiko-mono/issues/18046)) ([30c9316](https://github.com/taikoxyz/taiko-mono/commit/30c9316aea083d187617f5342fb4a955e604226b))
* **protocol:** update `RollupAddressCache` with new `MainnetTierRouter` address ([#18619](https://github.com/taikoxyz/taiko-mono/issues/18619)) ([b2ca63c](https://github.com/taikoxyz/taiko-mono/commit/b2ca63cd4ed7eca385c317d9a6ade794bf156c79))
* **protocol:** update Hekla `ontakeForkHeight` ([#17983](https://github.com/taikoxyz/taiko-mono/issues/17983)) ([8819e3a](https://github.com/taikoxyz/taiko-mono/commit/8819e3a5a59675dcc6a1f333620ce6e75b7d2887))
* **protocol:** update mainnet `ontakeForkHeight` config ([#18252](https://github.com/taikoxyz/taiko-mono/issues/18252)) ([7550882](https://github.com/taikoxyz/taiko-mono/commit/75508828d3755e1a831380cdd2ab321e67fa22fc))
* **protocol:** update ric0 & sp1 verification contract ([#18269](https://github.com/taikoxyz/taiko-mono/issues/18269)) ([684a909](https://github.com/taikoxyz/taiko-mono/commit/684a909e83705c59b2b7a0a991424b7a8e9e03ad))
* **protocol:** update script of deploying sp1 ([#18019](https://github.com/taikoxyz/taiko-mono/issues/18019)) ([9464967](https://github.com/taikoxyz/taiko-mono/commit/94649671bdf0304d96bf83d7d18dcbe21eff6067))
* **protocol:** update sp1 contracts ([#18097](https://github.com/taikoxyz/taiko-mono/issues/18097)) ([6f26434](https://github.com/taikoxyz/taiko-mono/commit/6f264342fe48f8d193559ac0712cc875d643b6fd))
* **protocol:** update sp1 to 3.0.0 prod version ([#18465](https://github.com/taikoxyz/taiko-mono/issues/18465)) ([0b11101](https://github.com/taikoxyz/taiko-mono/commit/0b1110159201f94ff5a4df528eab60b306d4fb25))
* **protocol:** upgrade script ([#18334](https://github.com/taikoxyz/taiko-mono/issues/18334)) ([2c41dd1](https://github.com/taikoxyz/taiko-mono/commit/2c41dd10989566c1b6af691c92ab2cbde734a13a))
* **protocol:** upgrade sp1 contract to v4.0.0-rc.3 ([#18740](https://github.com/taikoxyz/taiko-mono/issues/18740)) ([a58852f](https://github.com/taikoxyz/taiko-mono/commit/a58852fd84357487b82b965dd0ab61b56de49b53))
* **protocol:** use SP1 1.2.0-rc with more proof verification tests ([#18001](https://github.com/taikoxyz/taiko-mono/issues/18001)) ([f7bcf1d](https://github.com/taikoxyz/taiko-mono/commit/f7bcf1d63d19b641ac6b9e0e972a7f6e2ec5b38f))
* **protocol:** user smaller cooldown windows ([#18345](https://github.com/taikoxyz/taiko-mono/issues/18345)) ([63455f9](https://github.com/taikoxyz/taiko-mono/commit/63455f91d202d88583d70bce69e799032523eb18))
* **taiko-client:** soft block driver APIs ([#18273](https://github.com/taikoxyz/taiko-mono/issues/18273)) ([9fff7ff](https://github.com/taikoxyz/taiko-mono/commit/9fff7ff3cce99e915e8142a090a7fad2f1af5bd4))


### Bug Fixes

* **protocl:** check blockId in getBlock and getBlockV2 ([#18327](https://github.com/taikoxyz/taiko-mono/issues/18327)) ([4288fb6](https://github.com/taikoxyz/taiko-mono/commit/4288fb6e0c8c76651d2db866cab55f32a9a25075))
* **protocol:** add timestamp as a new parameter to getBasefeeV2 ([#18686](https://github.com/taikoxyz/taiko-mono/issues/18686)) ([361c26a](https://github.com/taikoxyz/taiko-mono/commit/361c26adc62a6358c4d38c6a4d707274c84d7552))
* **protocol:** avoid invocation in Bridge message processing if calldata is "" and value is 0 ([#18137](https://github.com/taikoxyz/taiko-mono/issues/18137)) ([10c2972](https://github.com/taikoxyz/taiko-mono/commit/10c29727081bd8f8b94bbfc4472b162ec552ef64))
* **protocol:** correct the wrong router address for mainnet ([#18291](https://github.com/taikoxyz/taiko-mono/issues/18291)) ([ae0a9da](https://github.com/taikoxyz/taiko-mono/commit/ae0a9daf83ab8f323c216978724ebcb71de54cfe))
* **protocol:** fix `chainId` in `HeklaTaikoL1` ([#17912](https://github.com/taikoxyz/taiko-mono/issues/17912)) ([8f31dd0](https://github.com/taikoxyz/taiko-mono/commit/8f31dd0ed519809f0ea0797b1e6b5937ee087108))
* **protocol:** fix a new bug in LibProposing ([#18328](https://github.com/taikoxyz/taiko-mono/issues/18328)) ([7436bae](https://github.com/taikoxyz/taiko-mono/commit/7436bae9660cfcf1d430ca111df8c75d50908eae))
* **protocol:** fix an issue in same transition check ([#18254](https://github.com/taikoxyz/taiko-mono/issues/18254)) ([233806e](https://github.com/taikoxyz/taiko-mono/commit/233806e4838aa12e8de436a37979ff3e614119f2))
* **protocol:** fix bug in adjustExcess ([920bd68](https://github.com/taikoxyz/taiko-mono/commit/920bd6873d3e9e1bbb00751fb9c0056ac85b8554))
* **protocol:** fix DCAP configuration script ([#18088](https://github.com/taikoxyz/taiko-mono/issues/18088)) ([e8618c5](https://github.com/taikoxyz/taiko-mono/commit/e8618c54a58993499e852ec2ffc2468d4f0274ba))
* **protocol:** fix debitBond bug and add additional tests ([#18443](https://github.com/taikoxyz/taiko-mono/issues/18443)) ([75ff1f8](https://github.com/taikoxyz/taiko-mono/commit/75ff1f87412c763e6ed3431d13689a629a2dd668))
* **protocol:** fix issue in mainnet deployment script ([#18283](https://github.com/taikoxyz/taiko-mono/issues/18283)) ([5c371a1](https://github.com/taikoxyz/taiko-mono/commit/5c371a181af444999f611e03774ec096ffbd1226))
* **protocol:** fix LibAddress.supportsInterface to handle undecodeable return data ([#18286](https://github.com/taikoxyz/taiko-mono/issues/18286)) ([299b4c9](https://github.com/taikoxyz/taiko-mono/commit/299b4c9ecf96644c909df70a3527ae5c2e728a07))
* **protocol:** fix permission in ComposeVerifier ([#18302](https://github.com/taikoxyz/taiko-mono/issues/18302)) ([4c45d8b](https://github.com/taikoxyz/taiko-mono/commit/4c45d8bcdb52521ac1738ca271316d82689537b0))
* **protocol:** fix proposeBlock()'s block id check ([#18227](https://github.com/taikoxyz/taiko-mono/issues/18227)) ([3a9d6c1](https://github.com/taikoxyz/taiko-mono/commit/3a9d6c166b7c6666eb2515893b6a3fbd00f4b1ea))
* **protocol:** fix test related to SendMessageToDelegateOwner.s.sol ([#18300](https://github.com/taikoxyz/taiko-mono/issues/18300)) ([65daa3e](https://github.com/taikoxyz/taiko-mono/commit/65daa3e631b471d17dbffb1001dab66efa67c499))
* **protocol:** fix tier id conflicts ([#18004](https://github.com/taikoxyz/taiko-mono/issues/18004)) ([0df1ad4](https://github.com/taikoxyz/taiko-mono/commit/0df1ad4274e6ebc3db79acbbdaedbe2d519262d6))
* **protocol:** fix wrong Bridged ERC20 address cache ([#18287](https://github.com/taikoxyz/taiko-mono/issues/18287)) ([49267ab](https://github.com/taikoxyz/taiko-mono/commit/49267abaa6d27d16fe4fb62ca0bb28d49b09d2f9))
* **protocol:** make sure new instance is not zero address in SgxVerifier ([#17918](https://github.com/taikoxyz/taiko-mono/issues/17918)) ([d559ce8](https://github.com/taikoxyz/taiko-mono/commit/d559ce80c1314e9ddbe02798f1c61a2e8349da6e))
* **protocol:** revert `B_TIER_OPTIMISTIC` back to `""` ([#18446](https://github.com/taikoxyz/taiko-mono/issues/18446)) ([9549e7f](https://github.com/taikoxyz/taiko-mono/commit/9549e7f3e899b22ff8c9ff7d731aa3ce250fd071))
* **protocol:** revert a change to maintain taiko-geth compatibility  ([#18331](https://github.com/taikoxyz/taiko-mono/issues/18331)) ([9d18d59](https://github.com/taikoxyz/taiko-mono/commit/9d18d598fe3e890a1f35e2d39916d554282ee4a0))
* **protocol:** revert changes related to `proposedIn` and `proposedAt` to fix a bug ([#18333](https://github.com/taikoxyz/taiko-mono/issues/18333)) ([5cb43ab](https://github.com/taikoxyz/taiko-mono/commit/5cb43ab1e29422353de549f8386eff613291c7df))
* **protocol:** reward non-assigned prover 7/8 liveness bond ([#18132](https://github.com/taikoxyz/taiko-mono/issues/18132)) ([9f99099](https://github.com/taikoxyz/taiko-mono/commit/9f99099ac271e6e2a0973a43084e29169386f2cd))
* **protocol:** small fix to 1559 error check ([#18339](https://github.com/taikoxyz/taiko-mono/issues/18339)) ([4428661](https://github.com/taikoxyz/taiko-mono/commit/44286615a0e0b0a17892fe83aad96546a6b1aca1))


### Chores

* **docs:** redirect the contribution.md path ([#18316](https://github.com/taikoxyz/taiko-mono/issues/18316)) ([0607ef7](https://github.com/taikoxyz/taiko-mono/commit/0607ef718dbe34c0ffe125825b12001b36a43fc5))
* **main:** fix misspelled ([#18581](https://github.com/taikoxyz/taiko-mono/issues/18581)) ([3687c4e](https://github.com/taikoxyz/taiko-mono/commit/3687c4e060b4b316fb185c649e9b089b97d53eda))
* **main:** release protocol 1.10.0 ([#18077](https://github.com/taikoxyz/taiko-mono/issues/18077)) ([3d12cb2](https://github.com/taikoxyz/taiko-mono/commit/3d12cb24b16c7eede1930b928408c1462134f5a7))
* **main:** release protocol 1.10.0 ([#18365](https://github.com/taikoxyz/taiko-mono/issues/18365)) ([9345f14](https://github.com/taikoxyz/taiko-mono/commit/9345f1419a1e5d0f975e15bb372b6101da9f0c48))
* **main:** release protocol 1.11.0 ([#18433](https://github.com/taikoxyz/taiko-mono/issues/18433)) ([75359cc](https://github.com/taikoxyz/taiko-mono/commit/75359cc1f76151cdb2e087d0000ad9052f50e3c4))
* **main:** release protocol 1.9.0 ([#17783](https://github.com/taikoxyz/taiko-mono/issues/17783)) ([7bfd28a](https://github.com/taikoxyz/taiko-mono/commit/7bfd28a2b332c927cd8b6358623551814260f94e))
* **main:** release protocol 1.9.0 ([#18051](https://github.com/taikoxyz/taiko-mono/issues/18051)) ([2547ba9](https://github.com/taikoxyz/taiko-mono/commit/2547ba9409705bb759b62e59a7e5d5821349c71a))
* **main:** release protocol 1.9.0 ([#18052](https://github.com/taikoxyz/taiko-mono/issues/18052)) ([bf45889](https://github.com/taikoxyz/taiko-mono/commit/bf45889e18e97f1186cd60fd55e1b2664dc4bf43))
* **main:** release taiko-alethia-protocol 1.11.0 ([#18663](https://github.com/taikoxyz/taiko-mono/issues/18663)) ([42cd90d](https://github.com/taikoxyz/taiko-mono/commit/42cd90d3f0937b96095076f733f60ca26d3b5751))
* **main:** release taiko-alethia-protocol 1.11.0 ([#18695](https://github.com/taikoxyz/taiko-mono/issues/18695)) ([7802e7f](https://github.com/taikoxyz/taiko-mono/commit/7802e7f33c445417473dcba799dd1dfc68a9aa31))
* **protocol:** add functions to ITaikoL1 for Nethermind Preconf ([#18217](https://github.com/taikoxyz/taiko-mono/issues/18217)) ([e349d22](https://github.com/taikoxyz/taiko-mono/commit/e349d2237a1830edab305b2f0eaaeb0eaf3c623f))
* **protocol:** change bond amounts, proving windows, and cooldown windows ([#18371](https://github.com/taikoxyz/taiko-mono/issues/18371)) ([fac5c16](https://github.com/taikoxyz/taiko-mono/commit/fac5c167357f430cfb030e7ceaa41bb8e4b938d4))
* **protocol:** change Hekla gas issuance per sec to 100000 ([#18335](https://github.com/taikoxyz/taiko-mono/issues/18335)) ([3d448d4](https://github.com/taikoxyz/taiko-mono/commit/3d448d4a78608ea7daf1d50e877c32f8d30f1e7a))
* **protocol:** change Hekla sharingPctg to 80% & gasIssuancePerSecond to 1000000 ([#18322](https://github.com/taikoxyz/taiko-mono/issues/18322)) ([75feb5b](https://github.com/taikoxyz/taiko-mono/commit/75feb5b36560b786a54e97280352c0d70c3e2f06))
* **protocol:** delete gas debug event ([#18620](https://github.com/taikoxyz/taiko-mono/issues/18620)) ([06128e8](https://github.com/taikoxyz/taiko-mono/commit/06128e8f64b7bf2997b70959c78ab256404ebab3))
* **protocol:** deploy `MainnetTierRouter` and update `RollupAddressCache` ([#18359](https://github.com/taikoxyz/taiko-mono/issues/18359)) ([aa351ab](https://github.com/taikoxyz/taiko-mono/commit/aa351ab0f90e442a8b15adb8de6a48d9ae6d1c42))
* **protocol:** fix documentation ([#18694](https://github.com/taikoxyz/taiko-mono/issues/18694)) ([c7c01a1](https://github.com/taikoxyz/taiko-mono/commit/c7c01a156e05d9126ba6fab7bd910dfa3602169a))
* **protocol:** fix lint issue in SP1Verifier ([#18213](https://github.com/taikoxyz/taiko-mono/issues/18213)) ([7874dd3](https://github.com/taikoxyz/taiko-mono/commit/7874dd3ff8a6053da8c09377b52c83e7a506f45f))
* **protocol:** fix typos in documentation files ([#18490](https://github.com/taikoxyz/taiko-mono/issues/18490)) ([8d1f9ea](https://github.com/taikoxyz/taiko-mono/commit/8d1f9eab8e02b1868f2e24005699a8ed1d2937fa))
* **protocol:** improve the usage of `initializer` and `reinitializer` ([#18319](https://github.com/taikoxyz/taiko-mono/issues/18319)) ([13cc007](https://github.com/taikoxyz/taiko-mono/commit/13cc0074a2295c5939cf83e23f531cb25c43bd64))
* **protocol:** move two files to simplify folder structure ([#17929](https://github.com/taikoxyz/taiko-mono/issues/17929)) ([9dca4fa](https://github.com/taikoxyz/taiko-mono/commit/9dca4faa43ad938880c8e1ac54236ab292bcce6e))
* **protocol:** optimize Taiko L1 gas cost ([#18376](https://github.com/taikoxyz/taiko-mono/issues/18376)) ([ea0158f](https://github.com/taikoxyz/taiko-mono/commit/ea0158f0cbaa974f90f9174410c705e6cbdc48aa))
* **protocol:** re-generate layout files with diff order for comparison with new PR ([#18067](https://github.com/taikoxyz/taiko-mono/issues/18067)) ([078d336](https://github.com/taikoxyz/taiko-mono/commit/078d3367dce86a57d71d48291537e925cb1b4b91))
* **protocol:** remove `TIER_ZKVM_ANY` in `MainnetTierRouter` ([#18357](https://github.com/taikoxyz/taiko-mono/issues/18357)) ([500a8bb](https://github.com/taikoxyz/taiko-mono/commit/500a8bbc46a3d1962ae5cc6d7f10e990f03d07c7))
* **protocol:** remove repetitive words in audit report ([#18584](https://github.com/taikoxyz/taiko-mono/issues/18584)) ([8092ee5](https://github.com/taikoxyz/taiko-mono/commit/8092ee56e00ed3e422471a9ed85c42fad6c19a13))
* **protocol:** restore proving window changes ([#18368](https://github.com/taikoxyz/taiko-mono/issues/18368)) ([9182fba](https://github.com/taikoxyz/taiko-mono/commit/9182fbaf05d309f9827310f3616992c0cc88a22d))
* **protocol:** revert `TAIKO_TOKEN` name changes in `DeployOnL1` ([#17927](https://github.com/taikoxyz/taiko-mono/issues/17927)) ([cf1a15f](https://github.com/taikoxyz/taiko-mono/commit/cf1a15f46344e60448c5fdcbcae02521fb5b7c04))
* **protocol:** revert Hekla `baseFeeConfig` updates ([#18340](https://github.com/taikoxyz/taiko-mono/issues/18340)) ([ae8ac3c](https://github.com/taikoxyz/taiko-mono/commit/ae8ac3c2e686b136de8c68853ecb91a39260a93f))
* **protocol:** revert releasing protocol 1.9.0 ([#17783](https://github.com/taikoxyz/taiko-mono/issues/17783)) ([#18049](https://github.com/taikoxyz/taiko-mono/issues/18049)) ([c033810](https://github.com/taikoxyz/taiko-mono/commit/c033810ecc4c80a4581a95b06ab5127747efd191))
* **protocol:** set mainnet Ontake fork height ([#18112](https://github.com/taikoxyz/taiko-mono/issues/18112)) ([8812eb2](https://github.com/taikoxyz/taiko-mono/commit/8812eb2a8de367311b8ada6bd3587bfe5efee090))
* **protocol:** shorten imports in solidity files ([#18221](https://github.com/taikoxyz/taiko-mono/issues/18221)) ([9b2ba6a](https://github.com/taikoxyz/taiko-mono/commit/9b2ba6a2a2fae24d1fb34e23b29b3146e96f575e))
* **protocol:** undo 1.10.0 release ([#18363](https://github.com/taikoxyz/taiko-mono/issues/18363)) ([116578e](https://github.com/taikoxyz/taiko-mono/commit/116578ef8a4391611bd1b3c469f4068cec8a8447))
* **protoco:** remove unused delegate owner deployment ([#18290](https://github.com/taikoxyz/taiko-mono/issues/18290)) ([63ba863](https://github.com/taikoxyz/taiko-mono/commit/63ba863dcf322b2cf04d7dcaf6d8905bf28de6bc))
* **repo:** improve documentation and changelog ([#18489](https://github.com/taikoxyz/taiko-mono/issues/18489)) ([c7b9b4f](https://github.com/taikoxyz/taiko-mono/commit/c7b9b4f01098d4fab337b9ff456ce394cdaf3a79))


### Documentation

* **protocol:** add L2 `DelegateOwner` address in Hekla deployment docs ([#17925](https://github.com/taikoxyz/taiko-mono/issues/17925)) ([fdec8db](https://github.com/taikoxyz/taiko-mono/commit/fdec8dbe8c8aef21f71c9c4ca2213944880c1a47))
* **protocol:** add mainnet zkVM verifiers deployment ([#18454](https://github.com/taikoxyz/taiko-mono/issues/18454)) ([3481b68](https://github.com/taikoxyz/taiko-mono/commit/3481b68e8d377c1ae6fc5a1a0e08d8411f94c613))
* **protocol:** add Ontake fork audit report from OpenZeppelin ([#18491](https://github.com/taikoxyz/taiko-mono/issues/18491)) ([e83adc0](https://github.com/taikoxyz/taiko-mono/commit/e83adc06ac4ce8ebe7e34feaad5691176dba27e2))
* **protocol:** fix invalid links in docs ([#18144](https://github.com/taikoxyz/taiko-mono/issues/18144)) ([c62f3f6](https://github.com/taikoxyz/taiko-mono/commit/c62f3f6b4a21f3af44f7df908fd8aac198721d5b))
* **protocol:** update `tier_router` in hekla ([#18352](https://github.com/taikoxyz/taiko-mono/issues/18352)) ([7c91a7d](https://github.com/taikoxyz/taiko-mono/commit/7c91a7d486c22e0f1a5386978086dfca5b73cfe0))
* **protocol:** update `tier_router`with compatibility modifications ([#18028](https://github.com/taikoxyz/taiko-mono/issues/18028)) ([c43cb0c](https://github.com/taikoxyz/taiko-mono/commit/c43cb0c05f7cbba281076568f4e72033ebbcd0f3))
* **protocol:** update code4rena-2024-03-taiko-final-report.md ([#18062](https://github.com/taikoxyz/taiko-mono/issues/18062)) ([fd68794](https://github.com/taikoxyz/taiko-mono/commit/fd68794a2de24b7a32d2d5a1c3f52c2156b6d61a))
* **protocol:** update hekla change log about `tier_router` ([#18023](https://github.com/taikoxyz/taiko-mono/issues/18023)) ([11e27d6](https://github.com/taikoxyz/taiko-mono/commit/11e27d60b3da9a34e07bfafadb8ec3d3223867d2))
* **protocol:** update hekla change log about sp1 ([#18020](https://github.com/taikoxyz/taiko-mono/issues/18020)) ([434bf3c](https://github.com/taikoxyz/taiko-mono/commit/434bf3ccc1715171b8cd4e7581b282f85744ebe3))
* **protocol:** update Hekla deployment ([#17924](https://github.com/taikoxyz/taiko-mono/issues/17924)) ([46a3e00](https://github.com/taikoxyz/taiko-mono/commit/46a3e00659534a715fb315859463bd05bbdb65a9))
* **protocol:** update Hekla deployments ([#17975](https://github.com/taikoxyz/taiko-mono/issues/17975)) ([c96627f](https://github.com/taikoxyz/taiko-mono/commit/c96627fcdd9ba91f26eeea2b329f0eb96dd36660))
* **protocol:** update Hekla deployments ([#18152](https://github.com/taikoxyz/taiko-mono/issues/18152)) ([6c7ff61](https://github.com/taikoxyz/taiko-mono/commit/6c7ff617b913b21b8b12b035f0d653c068830de3))
* **protocol:** update Hekla deployments ([#18257](https://github.com/taikoxyz/taiko-mono/issues/18257)) ([fbb1c82](https://github.com/taikoxyz/taiko-mono/commit/fbb1c824e35adb452176d988f32cf06d0c72b9bf))
* **protocol:** update Hekla deployments ([#18598](https://github.com/taikoxyz/taiko-mono/issues/18598)) ([a095c69](https://github.com/taikoxyz/taiko-mono/commit/a095c69a240d64606b09a26f2e80ad6daf18c273))
* **protocol:** update L1 deployment ([#18299](https://github.com/taikoxyz/taiko-mono/issues/18299)) ([f60ce3e](https://github.com/taikoxyz/taiko-mono/commit/f60ce3e78bb9a2717718c3a9d7016346d5305488))
* **protocol:** update mainnet deployment ([#18258](https://github.com/taikoxyz/taiko-mono/issues/18258)) ([eeeb4af](https://github.com/taikoxyz/taiko-mono/commit/eeeb4afeff8572115c2cf82db149cee7a723f30c))
* **protocol:** update mainnet deployment docs ([#18366](https://github.com/taikoxyz/taiko-mono/issues/18366)) ([bbd69ca](https://github.com/taikoxyz/taiko-mono/commit/bbd69ca583257ade30ac9ea2601509af5bc0789a))
* **protocol:** update mainnet deployment docs ([#18482](https://github.com/taikoxyz/taiko-mono/issues/18482)) ([9da8499](https://github.com/taikoxyz/taiko-mono/commit/9da849989249072e3a03e611b9c08b00295cf42c))
* **protocol:** update mainnet deployment docs ([#18621](https://github.com/taikoxyz/taiko-mono/issues/18621)) ([eb542bf](https://github.com/taikoxyz/taiko-mono/commit/eb542bf67dea51fd42c0f5c40ee987e5acadc3fd))
* **protocol:** update mainnet deployment docs ([#18645](https://github.com/taikoxyz/taiko-mono/issues/18645)) ([59d4f10](https://github.com/taikoxyz/taiko-mono/commit/59d4f107edc1aaac5716067634735bad03e75269))
* **protocol:** update mainnet deployment docs ([#18754](https://github.com/taikoxyz/taiko-mono/issues/18754)) ([45f5cdc](https://github.com/taikoxyz/taiko-mono/commit/45f5cdc514d47042b6aa810c188062a85b050adf))
* **protocol:** upgrade protocol version in hekla to 1.10.0 ([#18343](https://github.com/taikoxyz/taiko-mono/issues/18343)) ([4805024](https://github.com/taikoxyz/taiko-mono/commit/4805024c15ab63bf345dcc5f5868a4a16af0ba48))
* **protocol:** upgrade sp1 plonk verifier 2.0.0 ([#18098](https://github.com/taikoxyz/taiko-mono/issues/18098)) ([cfd0e9e](https://github.com/taikoxyz/taiko-mono/commit/cfd0e9e4af2e42ead309e0c571b09dd20ddfe0f9))
* **protocol:** upgrade sp1 remote verifier in Hekla ([#18469](https://github.com/taikoxyz/taiko-mono/issues/18469)) ([051b619](https://github.com/taikoxyz/taiko-mono/commit/051b619c6ce93a09c7e14dd8fafc99681c9261ad))
* **protocol:** upgrade sp1 verifier in hekla ([#18027](https://github.com/taikoxyz/taiko-mono/issues/18027)) ([de27e6e](https://github.com/taikoxyz/taiko-mono/commit/de27e6e586e14410c309e68ce6b81504b9ba9a5b))
* **protocol:** upgrade verifiers to support proof aggregation in Hekla ([#18453](https://github.com/taikoxyz/taiko-mono/issues/18453)) ([bfb0386](https://github.com/taikoxyz/taiko-mono/commit/bfb03864ee83ccc3bce989f3e9fd2309eb90c277))
* **protocol:** upgrade zk verifiers in Hekla ([#18279](https://github.com/taikoxyz/taiko-mono/issues/18279)) ([e98a1d5](https://github.com/taikoxyz/taiko-mono/commit/e98a1d5cdaa14af86340081ee42ad263a41bfdb5))
* **repo:** improve grammar and readability ([#18501](https://github.com/taikoxyz/taiko-mono/issues/18501)) ([61994ff](https://github.com/taikoxyz/taiko-mono/commit/61994ffefcf29981beb567b84a3a55706300cf13))


### Code Refactoring

* **protocol:** extra a new function in LibProposing ([#18456](https://github.com/taikoxyz/taiko-mono/issues/18456)) ([5b4b0cd](https://github.com/taikoxyz/taiko-mono/commit/5b4b0cd271534aa72d865afa5fc55e0ee4b16b73))
* **protocol:** extract an IBlockHash interface from TaikoL2 ([#18045](https://github.com/taikoxyz/taiko-mono/issues/18045)) ([bff481e](https://github.com/taikoxyz/taiko-mono/commit/bff481e8a2898fab8396d368de84f8f343c532f0))
* **protocol:** introduce BlockV2 for client-side compability ([#17935](https://github.com/taikoxyz/taiko-mono/issues/17935)) ([e46cf29](https://github.com/taikoxyz/taiko-mono/commit/e46cf294862c293b73b817574669115b85e973a7))
* **protocol:** refactor TierProvider implementations ([ee464ca](https://github.com/taikoxyz/taiko-mono/commit/ee464caef68fdec325aa22758bb69e17dd039794))
* **protocol:** remove ProposerAccess for easier composability ([#17994](https://github.com/taikoxyz/taiko-mono/issues/17994)) ([80176a1](https://github.com/taikoxyz/taiko-mono/commit/80176a1525c374039256c779f4a2408971759d22))
* **protocol:** remove uncessary init2() from TaikoL2 ([#17973](https://github.com/taikoxyz/taiko-mono/issues/17973)) ([4e08881](https://github.com/taikoxyz/taiko-mono/commit/4e0888190e172c950dc5e81a5115ee0fb6df3f11))
* **protocol:** remove unused code post Ontake fork ([#18150](https://github.com/taikoxyz/taiko-mono/issues/18150)) ([8543cec](https://github.com/taikoxyz/taiko-mono/commit/8543cecdef9d10d038bc5a7313230006acd26e22))
* **protocol:** restructure solidity code to match compilation targets ([#18059](https://github.com/taikoxyz/taiko-mono/issues/18059)) ([adc47f4](https://github.com/taikoxyz/taiko-mono/commit/adc47f408282c25c7a50c26e31130fc495734dcc))
* **protocol:** simplify mainnet address caching ([ee464ca](https://github.com/taikoxyz/taiko-mono/commit/ee464caef68fdec325aa22758bb69e17dd039794))
* **protocol:** simplify some protocol code based on OpenZeppelin's recommendation ([#18308](https://github.com/taikoxyz/taiko-mono/issues/18308)) ([fbad703](https://github.com/taikoxyz/taiko-mono/commit/fbad703739f09d4524f9d808c3bad31d0122ec2c))
* **protocol:** slightly change defender monitors ([#18086](https://github.com/taikoxyz/taiko-mono/issues/18086)) ([b93d056](https://github.com/taikoxyz/taiko-mono/commit/b93d056479adfc4a1f557578d8b66eda48b104a9))
* **protocol:** slightly improve EssentialContract ([#18445](https://github.com/taikoxyz/taiko-mono/issues/18445)) ([3d077f8](https://github.com/taikoxyz/taiko-mono/commit/3d077f8ee520a116028711391c323c7badd1f2c6))


### Tests

* **protocol:** check LibEIP1559 function results in fuzz tests ([#18475](https://github.com/taikoxyz/taiko-mono/issues/18475)) ([06e190c](https://github.com/taikoxyz/taiko-mono/commit/06e190c01bc4c4aae25664e8c2c154d8cf46efa5))
* **protocol:** fix another L2 test failure ([#18304](https://github.com/taikoxyz/taiko-mono/issues/18304)) ([b3dd4dc](https://github.com/taikoxyz/taiko-mono/commit/b3dd4dccd261a9ebda69325661d2941001268ec2))
* **taiko-client:** use env names which defined in flag configs ([#17921](https://github.com/taikoxyz/taiko-mono/issues/17921)) ([196b74e](https://github.com/taikoxyz/taiko-mono/commit/196b74eb2b4498bc3e6511915e011a885fcc530f))


### Workflow

* **protocol:** make the storage layout table clearer ([#18633](https://github.com/taikoxyz/taiko-mono/issues/18633)) ([7394458](https://github.com/taikoxyz/taiko-mono/commit/73944585586686ad1ce5548ce59e9ea583c4b2ee))
* **protocol:** revert "chore(main): release taiko-alethia-protocol 1.11.0 ([#18663](https://github.com/taikoxyz/taiko-mono/issues/18663))" ([#18688](https://github.com/taikoxyz/taiko-mono/issues/18688)) ([7e6bce4](https://github.com/taikoxyz/taiko-mono/commit/7e6bce4a0dac9e4f2984ffe2d3da2fc1277fab27))
* **protocol:** revert "chore(main): release taiko-alethia-protocol 1.11.0 ([#18695](https://github.com/taikoxyz/taiko-mono/issues/18695))" ([#18760](https://github.com/taikoxyz/taiko-mono/issues/18760)) ([e8ab39a](https://github.com/taikoxyz/taiko-mono/commit/e8ab39a9ffa0e3e3ec79efbd476864cef5e5eab4))
* **protocol:** revert releasing protocol 1.11.0 ([#18662](https://github.com/taikoxyz/taiko-mono/issues/18662)) ([29ce093](https://github.com/taikoxyz/taiko-mono/commit/29ce093100ae76b9eb51eef0f560207422496990))
* **protocol:** trigger patch release (1.10.1) ([#18358](https://github.com/taikoxyz/taiko-mono/issues/18358)) ([f4f4796](https://github.com/taikoxyz/taiko-mono/commit/f4f4796488059b02c79d6fb15170df58dd31dc4e))
* **protocol:** upgrade to use solc 0.8.27 ([#18037](https://github.com/taikoxyz/taiko-mono/issues/18037)) ([3a56b57](https://github.com/taikoxyz/taiko-mono/commit/3a56b5788b3e2473381429e5fddfaac2f10fa174))


### Build

* **deps:** bump github.com/stretchr/testify from 1.9.0 to 1.10.0 ([#18539](https://github.com/taikoxyz/taiko-mono/issues/18539)) ([79f3fab](https://github.com/taikoxyz/taiko-mono/commit/79f3fab5f1d1ec1bb4ee18afb9268b622e894780))
* **deps:** bump golang.org/x/sync from 0.9.0 to 0.10.0 ([#18560](https://github.com/taikoxyz/taiko-mono/issues/18560)) ([3d51970](https://github.com/taikoxyz/taiko-mono/commit/3d51970aa0953bbfecaeebf76ea7e664c875c0e4))
* **deps:** bump merkletreejs from 0.3.11 to 0.4.0 ([#17942](https://github.com/taikoxyz/taiko-mono/issues/17942)) ([1624b71](https://github.com/taikoxyz/taiko-mono/commit/1624b711e3fe1862f000e1d2970d6aee1b8990c9))

## [1.10.0](https://github.com/taikoxyz/taiko-mono/compare/protocol-v1.9.0...protocol-v1.10.0) (2024-11-01)


### Features

* **protocol:** add `proposeBlocksV2` method to `ProverSet` ([#18115](https://github.com/taikoxyz/taiko-mono/issues/18115)) ([0743a99](https://github.com/taikoxyz/taiko-mono/commit/0743a99ee6ab403024bab5834178399fbeebb4e5))
* **protocol:** add aggregated sgx verify test ([#18160](https://github.com/taikoxyz/taiko-mono/issues/18160)) ([8dda47b](https://github.com/taikoxyz/taiko-mono/commit/8dda47bf9ee47faa8a0d16dde0b4398d5e7019f8))
* **protocol:** add Hekla Ontake hardfork upgrade scripts ([#18103](https://github.com/taikoxyz/taiko-mono/issues/18103)) ([a3436e8](https://github.com/taikoxyz/taiko-mono/commit/a3436e8cafbc96ebfa5742ada995adae39c572ce))
* **protocol:** allow owner to update recipient in TokenUnlock ([#18184](https://github.com/taikoxyz/taiko-mono/issues/18184)) ([773ae1b](https://github.com/taikoxyz/taiko-mono/commit/773ae1b11f309ee8c4e0b1c0d22b9bfa41beae0d))
* **protocol:** check-in `HeklaTaikoToken` ([#18189](https://github.com/taikoxyz/taiko-mono/issues/18189)) ([60c38d8](https://github.com/taikoxyz/taiko-mono/commit/60c38d8d179f2c02a0ed87f97bd34dc708b38df4))
* **protocol:** enable sp1 batch aggregation ([#18199](https://github.com/taikoxyz/taiko-mono/issues/18199)) ([038cd32](https://github.com/taikoxyz/taiko-mono/commit/038cd326668b3a882798ecb4e7f9e3ecadc6dc28))
* **protocol:** improve `getTransitions` ([#18181](https://github.com/taikoxyz/taiko-mono/issues/18181)) ([868d733](https://github.com/taikoxyz/taiko-mono/commit/868d733db962a76261036c3e583cb50feaec901f))
* **protocol:** Increase the probability of sgx proof for lab proposer ([#18288](https://github.com/taikoxyz/taiko-mono/issues/18288)) ([fd0dbbb](https://github.com/taikoxyz/taiko-mono/commit/fd0dbbbb3df0db27873e0ba87e45a5165fb7c0f1))
* **protocol:** introduce `getTransitions` in TaikoL1 ([#18154](https://github.com/taikoxyz/taiko-mono/issues/18154)) ([273bf53](https://github.com/taikoxyz/taiko-mono/commit/273bf53fad763b8504353e7cc14c8585e341f9d0))
* **protocol:** make sure `init()` covers logics in `init2()`, `init3()`.. ([#18292](https://github.com/taikoxyz/taiko-mono/issues/18292)) ([9d06958](https://github.com/taikoxyz/taiko-mono/commit/9d06958e713e530fdd610c439c7b93199d0dcc69))
* **protocol:** rename B_BLOCK_PROPOSER to B_PRECONF_REGISTRY ([#18255](https://github.com/taikoxyz/taiko-mono/issues/18255)) ([bf3caf7](https://github.com/taikoxyz/taiko-mono/commit/bf3caf7d986d7b03cf3bd0aa69ea97602bff80aa))
* **protocol:** scripts to deploy new mainnet implementation contracts ([#18356](https://github.com/taikoxyz/taiko-mono/issues/18356)) ([269759b](https://github.com/taikoxyz/taiko-mono/commit/269759bccefba399f0aa6f45482f4a24330a5e47))
* **protocol:** update mainnet `ontakeForkHeight` config ([#18252](https://github.com/taikoxyz/taiko-mono/issues/18252)) ([7550882](https://github.com/taikoxyz/taiko-mono/commit/75508828d3755e1a831380cdd2ab321e67fa22fc))
* **protocol:** update ric0 & sp1 verification contract ([#18269](https://github.com/taikoxyz/taiko-mono/issues/18269)) ([684a909](https://github.com/taikoxyz/taiko-mono/commit/684a909e83705c59b2b7a0a991424b7a8e9e03ad))
* **protocol:** update sp1 contracts ([#18097](https://github.com/taikoxyz/taiko-mono/issues/18097)) ([6f26434](https://github.com/taikoxyz/taiko-mono/commit/6f264342fe48f8d193559ac0712cc875d643b6fd))
* **protocol:** upgrade script ([#18334](https://github.com/taikoxyz/taiko-mono/issues/18334)) ([2c41dd1](https://github.com/taikoxyz/taiko-mono/commit/2c41dd10989566c1b6af691c92ab2cbde734a13a))
* **protocol:** user smaller cooldown windows ([#18345](https://github.com/taikoxyz/taiko-mono/issues/18345)) ([63455f9](https://github.com/taikoxyz/taiko-mono/commit/63455f91d202d88583d70bce69e799032523eb18))


### Bug Fixes

* **protocol:** check blockId in getBlock and getBlockV2 ([#18327](https://github.com/taikoxyz/taiko-mono/issues/18327)) ([4288fb6](https://github.com/taikoxyz/taiko-mono/commit/4288fb6e0c8c76651d2db866cab55f32a9a25075))
* **protocol:** avoid invocation in Bridge message processing if calldata is "" and value is 0 ([#18137](https://github.com/taikoxyz/taiko-mono/issues/18137)) ([10c2972](https://github.com/taikoxyz/taiko-mono/commit/10c29727081bd8f8b94bbfc4472b162ec552ef64))
* **protocol:** correct the wrong router address for mainnet ([#18291](https://github.com/taikoxyz/taiko-mono/issues/18291)) ([ae0a9da](https://github.com/taikoxyz/taiko-mono/commit/ae0a9daf83ab8f323c216978724ebcb71de54cfe))
* **protocol:** fix a new bug in LibProposing ([#18328](https://github.com/taikoxyz/taiko-mono/issues/18328)) ([7436bae](https://github.com/taikoxyz/taiko-mono/commit/7436bae9660cfcf1d430ca111df8c75d50908eae))
* **protocol:** fix an issue in same transition check ([#18254](https://github.com/taikoxyz/taiko-mono/issues/18254)) ([233806e](https://github.com/taikoxyz/taiko-mono/commit/233806e4838aa12e8de436a37979ff3e614119f2))
* **protocol:** fix DCAP configuration script ([#18088](https://github.com/taikoxyz/taiko-mono/issues/18088)) ([e8618c5](https://github.com/taikoxyz/taiko-mono/commit/e8618c54a58993499e852ec2ffc2468d4f0274ba))
* **protocol:** fix issue in mainnet deployment script ([#18283](https://github.com/taikoxyz/taiko-mono/issues/18283)) ([5c371a1](https://github.com/taikoxyz/taiko-mono/commit/5c371a181af444999f611e03774ec096ffbd1226))
* **protocol:** fix LibAddress.supportsInterface to handle undecodable return data ([#18286](https://github.com/taikoxyz/taiko-mono/issues/18286)) ([299b4c9](https://github.com/taikoxyz/taiko-mono/commit/299b4c9ecf96644c909df70a3527ae5c2e728a07))
* **protocol:** fix permission in ComposeVerifier ([#18302](https://github.com/taikoxyz/taiko-mono/issues/18302)) ([4c45d8b](https://github.com/taikoxyz/taiko-mono/commit/4c45d8bcdb52521ac1738ca271316d82689537b0))
* **protocol:** fix proposeBlock()'s block id check ([#18227](https://github.com/taikoxyz/taiko-mono/issues/18227)) ([3a9d6c1](https://github.com/taikoxyz/taiko-mono/commit/3a9d6c166b7c6666eb2515893b6a3fbd00f4b1ea))
* **protocol:** fix test related to SendMessageToDelegateOwner.s.sol ([#18300](https://github.com/taikoxyz/taiko-mono/issues/18300)) ([65daa3e](https://github.com/taikoxyz/taiko-mono/commit/65daa3e631b471d17dbffb1001dab66efa67c499))
* **protocol:** fix wrong Bridged ERC20 address cache ([#18287](https://github.com/taikoxyz/taiko-mono/issues/18287)) ([49267ab](https://github.com/taikoxyz/taiko-mono/commit/49267abaa6d27d16fe4fb62ca0bb28d49b09d2f9))
* **protocol:** revert a change to maintain taiko-geth compatibility  ([#18331](https://github.com/taikoxyz/taiko-mono/issues/18331)) ([9d18d59](https://github.com/taikoxyz/taiko-mono/commit/9d18d598fe3e890a1f35e2d39916d554282ee4a0))
* **protocol:** revert changes related to `proposedIn` and `proposedAt` to fix a bug ([#18333](https://github.com/taikoxyz/taiko-mono/issues/18333)) ([5cb43ab](https://github.com/taikoxyz/taiko-mono/commit/5cb43ab1e29422353de549f8386eff613291c7df))
* **protocol:** reward non-assigned prover 7/8 liveness bond ([#18132](https://github.com/taikoxyz/taiko-mono/issues/18132)) ([9f99099](https://github.com/taikoxyz/taiko-mono/commit/9f99099ac271e6e2a0973a43084e29169386f2cd))
* **protocol:** small fix to 1559 error check ([#18339](https://github.com/taikoxyz/taiko-mono/issues/18339)) ([4428661](https://github.com/taikoxyz/taiko-mono/commit/44286615a0e0b0a17892fe83aad96546a6b1aca1))


### Chores

* **docs:** redirect the contribution.md path ([#18316](https://github.com/taikoxyz/taiko-mono/issues/18316)) ([0607ef7](https://github.com/taikoxyz/taiko-mono/commit/0607ef718dbe34c0ffe125825b12001b36a43fc5))
* **main:** release protocol 1.10.0 ([#18077](https://github.com/taikoxyz/taiko-mono/issues/18077)) ([3d12cb2](https://github.com/taikoxyz/taiko-mono/commit/3d12cb24b16c7eede1930b928408c1462134f5a7))
* **protocol:** add functions to ITaikoL1 for Nethermind Preconf ([#18217](https://github.com/taikoxyz/taiko-mono/issues/18217)) ([e349d22](https://github.com/taikoxyz/taiko-mono/commit/e349d2237a1830edab305b2f0eaaeb0eaf3c623f))
* **protocol:** change Hekla gas issuance per sec to 100000 ([#18335](https://github.com/taikoxyz/taiko-mono/issues/18335)) ([3d448d4](https://github.com/taikoxyz/taiko-mono/commit/3d448d4a78608ea7daf1d50e877c32f8d30f1e7a))
* **protocol:** change Hekla sharingPctg to 80% & gasIssuancePerSecond to 1000000 ([#18322](https://github.com/taikoxyz/taiko-mono/issues/18322)) ([75feb5b](https://github.com/taikoxyz/taiko-mono/commit/75feb5b36560b786a54e97280352c0d70c3e2f06))
* **protocol:** deploy `MainnetTierRouter` and update `RollupAddressCache` ([#18359](https://github.com/taikoxyz/taiko-mono/issues/18359)) ([aa351ab](https://github.com/taikoxyz/taiko-mono/commit/aa351ab0f90e442a8b15adb8de6a48d9ae6d1c42))
* **protocol:** fix lint issue in SP1Verifier ([#18213](https://github.com/taikoxyz/taiko-mono/issues/18213)) ([7874dd3](https://github.com/taikoxyz/taiko-mono/commit/7874dd3ff8a6053da8c09377b52c83e7a506f45f))
* **protocol:** improve the usage of `initializer` and `reinitializer` ([#18319](https://github.com/taikoxyz/taiko-mono/issues/18319)) ([13cc007](https://github.com/taikoxyz/taiko-mono/commit/13cc0074a2295c5939cf83e23f531cb25c43bd64))
* **protocol:** remove `TIER_ZKVM_ANY` in `MainnetTierRouter` ([#18357](https://github.com/taikoxyz/taiko-mono/issues/18357)) ([500a8bb](https://github.com/taikoxyz/taiko-mono/commit/500a8bbc46a3d1962ae5cc6d7f10e990f03d07c7))
* **protocol:** revert Hekla `baseFeeConfig` updates ([#18340](https://github.com/taikoxyz/taiko-mono/issues/18340)) ([ae8ac3c](https://github.com/taikoxyz/taiko-mono/commit/ae8ac3c2e686b136de8c68853ecb91a39260a93f))
* **protocol:** set mainnet Ontake fork height ([#18112](https://github.com/taikoxyz/taiko-mono/issues/18112)) ([8812eb2](https://github.com/taikoxyz/taiko-mono/commit/8812eb2a8de367311b8ada6bd3587bfe5efee090))
* **protocol:** shorten imports in solidity files ([#18221](https://github.com/taikoxyz/taiko-mono/issues/18221)) ([9b2ba6a](https://github.com/taikoxyz/taiko-mono/commit/9b2ba6a2a2fae24d1fb34e23b29b3146e96f575e))
* **protocol:** undo 1.10.0 release ([#18363](https://github.com/taikoxyz/taiko-mono/issues/18363)) ([116578e](https://github.com/taikoxyz/taiko-mono/commit/116578ef8a4391611bd1b3c469f4068cec8a8447))
* **protocol:** remove unused delegate owner deployment ([#18290](https://github.com/taikoxyz/taiko-mono/issues/18290)) ([63ba863](https://github.com/taikoxyz/taiko-mono/commit/63ba863dcf322b2cf04d7dcaf6d8905bf28de6bc))


### Documentation

* **protocol:** fix invalid links in docs ([#18144](https://github.com/taikoxyz/taiko-mono/issues/18144)) ([c62f3f6](https://github.com/taikoxyz/taiko-mono/commit/c62f3f6b4a21f3af44f7df908fd8aac198721d5b))
* **protocol:** update `tier_router` in hekla ([#18352](https://github.com/taikoxyz/taiko-mono/issues/18352)) ([7c91a7d](https://github.com/taikoxyz/taiko-mono/commit/7c91a7d486c22e0f1a5386978086dfca5b73cfe0))
* **protocol:** update code4rena-2024-03-taiko-final-report.md ([#18062](https://github.com/taikoxyz/taiko-mono/issues/18062)) ([fd68794](https://github.com/taikoxyz/taiko-mono/commit/fd68794a2de24b7a32d2d5a1c3f52c2156b6d61a))
* **protocol:** update Hekla deployments ([#18152](https://github.com/taikoxyz/taiko-mono/issues/18152)) ([6c7ff61](https://github.com/taikoxyz/taiko-mono/commit/6c7ff617b913b21b8b12b035f0d653c068830de3))
* **protocol:** update Hekla deployments ([#18257](https://github.com/taikoxyz/taiko-mono/issues/18257)) ([fbb1c82](https://github.com/taikoxyz/taiko-mono/commit/fbb1c824e35adb452176d988f32cf06d0c72b9bf))
* **protocol:** update L1 deployment ([#18299](https://github.com/taikoxyz/taiko-mono/issues/18299)) ([f60ce3e](https://github.com/taikoxyz/taiko-mono/commit/f60ce3e78bb9a2717718c3a9d7016346d5305488))
* **protocol:** update mainnet deployment ([#18258](https://github.com/taikoxyz/taiko-mono/issues/18258)) ([eeeb4af](https://github.com/taikoxyz/taiko-mono/commit/eeeb4afeff8572115c2cf82db149cee7a723f30c))
* **protocol:** upgrade protocol version in hekla to 1.10.0 ([#18343](https://github.com/taikoxyz/taiko-mono/issues/18343)) ([4805024](https://github.com/taikoxyz/taiko-mono/commit/4805024c15ab63bf345dcc5f5868a4a16af0ba48))
* **protocol:** upgrade sp1 plonk verifier 2.0.0 ([#18098](https://github.com/taikoxyz/taiko-mono/issues/18098)) ([cfd0e9e](https://github.com/taikoxyz/taiko-mono/commit/cfd0e9e4af2e42ead309e0c571b09dd20ddfe0f9))
* **protocol:** upgrade zk verifiers in Hekla ([#18279](https://github.com/taikoxyz/taiko-mono/issues/18279)) ([e98a1d5](https://github.com/taikoxyz/taiko-mono/commit/e98a1d5cdaa14af86340081ee42ad263a41bfdb5))


### Code Refactoring

* **protocol:** simplify some protocol code based on OpenZeppelin's recommendation ([#18308](https://github.com/taikoxyz/taiko-mono/issues/18308)) ([fbad703](https://github.com/taikoxyz/taiko-mono/commit/fbad703739f09d4524f9d808c3bad31d0122ec2c))
* **protocol:** slightly change defender monitors ([#18086](https://github.com/taikoxyz/taiko-mono/issues/18086)) ([b93d056](https://github.com/taikoxyz/taiko-mono/commit/b93d056479adfc4a1f557578d8b66eda48b104a9))


### Tests

* **protocol:** fix another L2 test failure ([#18304](https://github.com/taikoxyz/taiko-mono/issues/18304)) ([b3dd4dc](https://github.com/taikoxyz/taiko-mono/commit/b3dd4dccd261a9ebda69325661d2941001268ec2))


### Workflow

* **protocol:** trigger patch release (1.10.1) ([#18358](https://github.com/taikoxyz/taiko-mono/issues/18358)) ([f4f4796](https://github.com/taikoxyz/taiko-mono/commit/f4f4796488059b02c79d6fb15170df58dd31dc4e))

## [1.10.0](https://github.com/taikoxyz/taiko-mono/compare/protocol-v1.9.0...protocol-v1.10.0) (2024-10-29)


### Features

* **protocol:** add `proposeBlocksV2` method to `ProverSet` ([#18115](https://github.com/taikoxyz/taiko-mono/issues/18115)) ([0743a99](https://github.com/taikoxyz/taiko-mono/commit/0743a99ee6ab403024bab5834178399fbeebb4e5))
* **protocol:** add aggregated sgx verify test ([#18160](https://github.com/taikoxyz/taiko-mono/issues/18160)) ([8dda47b](https://github.com/taikoxyz/taiko-mono/commit/8dda47bf9ee47faa8a0d16dde0b4398d5e7019f8))
* **protocol:** add Hekla Ontake hardfork upgrade scripts ([#18103](https://github.com/taikoxyz/taiko-mono/issues/18103)) ([a3436e8](https://github.com/taikoxyz/taiko-mono/commit/a3436e8cafbc96ebfa5742ada995adae39c572ce))
* **protocol:** allow owner to update recipient in TokenUnlock ([#18184](https://github.com/taikoxyz/taiko-mono/issues/18184)) ([773ae1b](https://github.com/taikoxyz/taiko-mono/commit/773ae1b11f309ee8c4e0b1c0d22b9bfa41beae0d))
* **protocol:** check-in `HeklaTaikoToken` ([#18189](https://github.com/taikoxyz/taiko-mono/issues/18189)) ([60c38d8](https://github.com/taikoxyz/taiko-mono/commit/60c38d8d179f2c02a0ed87f97bd34dc708b38df4))
* **protocol:** enable sp1 batch aggregation ([#18199](https://github.com/taikoxyz/taiko-mono/issues/18199)) ([038cd32](https://github.com/taikoxyz/taiko-mono/commit/038cd326668b3a882798ecb4e7f9e3ecadc6dc28))
* **protocol:** improve `getTransitions` ([#18181](https://github.com/taikoxyz/taiko-mono/issues/18181)) ([868d733](https://github.com/taikoxyz/taiko-mono/commit/868d733db962a76261036c3e583cb50feaec901f))
* **protocol:** Increase the probability of sgx proof for lab proposer ([#18288](https://github.com/taikoxyz/taiko-mono/issues/18288)) ([fd0dbbb](https://github.com/taikoxyz/taiko-mono/commit/fd0dbbbb3df0db27873e0ba87e45a5165fb7c0f1))
* **protocol:** introduce `getTransitions` in TaikoL1 ([#18154](https://github.com/taikoxyz/taiko-mono/issues/18154)) ([273bf53](https://github.com/taikoxyz/taiko-mono/commit/273bf53fad763b8504353e7cc14c8585e341f9d0))
* **protocol:** make sure `init()` covers logics in `init2()`, `init3()`.. ([#18292](https://github.com/taikoxyz/taiko-mono/issues/18292)) ([9d06958](https://github.com/taikoxyz/taiko-mono/commit/9d06958e713e530fdd610c439c7b93199d0dcc69))
* **protocol:** rename B_BLOCK_PROPOSER to B_PRECONF_REGISTRY ([#18255](https://github.com/taikoxyz/taiko-mono/issues/18255)) ([bf3caf7](https://github.com/taikoxyz/taiko-mono/commit/bf3caf7d986d7b03cf3bd0aa69ea97602bff80aa))
* **protocol:** update mainnet `ontakeForkHeight` config ([#18252](https://github.com/taikoxyz/taiko-mono/issues/18252)) ([7550882](https://github.com/taikoxyz/taiko-mono/commit/75508828d3755e1a831380cdd2ab321e67fa22fc))
* **protocol:** update ric0 & sp1 verification contract ([#18269](https://github.com/taikoxyz/taiko-mono/issues/18269)) ([684a909](https://github.com/taikoxyz/taiko-mono/commit/684a909e83705c59b2b7a0a991424b7a8e9e03ad))
* **protocol:** update sp1 contracts ([#18097](https://github.com/taikoxyz/taiko-mono/issues/18097)) ([6f26434](https://github.com/taikoxyz/taiko-mono/commit/6f264342fe48f8d193559ac0712cc875d643b6fd))


### Bug Fixes

* **protocol:** check blockId in getBlock and getBlockV2 ([#18327](https://github.com/taikoxyz/taiko-mono/issues/18327)) ([4288fb6](https://github.com/taikoxyz/taiko-mono/commit/4288fb6e0c8c76651d2db866cab55f32a9a25075))
* **protocol:** avoid invocation in Bridge message processing if calldata is "" and value is 0 ([#18137](https://github.com/taikoxyz/taiko-mono/issues/18137)) ([10c2972](https://github.com/taikoxyz/taiko-mono/commit/10c29727081bd8f8b94bbfc4472b162ec552ef64))
* **protocol:** correct the wrong router address for mainnet ([#18291](https://github.com/taikoxyz/taiko-mono/issues/18291)) ([ae0a9da](https://github.com/taikoxyz/taiko-mono/commit/ae0a9daf83ab8f323c216978724ebcb71de54cfe))
* **protocol:** fix a new bug in LibProposing ([#18328](https://github.com/taikoxyz/taiko-mono/issues/18328)) ([7436bae](https://github.com/taikoxyz/taiko-mono/commit/7436bae9660cfcf1d430ca111df8c75d50908eae))
* **protocol:** fix an issue in same transition check ([#18254](https://github.com/taikoxyz/taiko-mono/issues/18254)) ([233806e](https://github.com/taikoxyz/taiko-mono/commit/233806e4838aa12e8de436a37979ff3e614119f2))
* **protocol:** fix DCAP configuration script ([#18088](https://github.com/taikoxyz/taiko-mono/issues/18088)) ([e8618c5](https://github.com/taikoxyz/taiko-mono/commit/e8618c54a58993499e852ec2ffc2468d4f0274ba))
* **protocol:** fix issue in mainnet deployment script ([#18283](https://github.com/taikoxyz/taiko-mono/issues/18283)) ([5c371a1](https://github.com/taikoxyz/taiko-mono/commit/5c371a181af444999f611e03774ec096ffbd1226))
* **protocol:** fix LibAddress.supportsInterface to handle undecodeable return data ([#18286](https://github.com/taikoxyz/taiko-mono/issues/18286)) ([299b4c9](https://github.com/taikoxyz/taiko-mono/commit/299b4c9ecf96644c909df70a3527ae5c2e728a07))
* **protocol:** fix permission in ComposeVerifier ([#18302](https://github.com/taikoxyz/taiko-mono/issues/18302)) ([4c45d8b](https://github.com/taikoxyz/taiko-mono/commit/4c45d8bcdb52521ac1738ca271316d82689537b0))
* **protocol:** fix proposeBlock()'s block id check ([#18227](https://github.com/taikoxyz/taiko-mono/issues/18227)) ([3a9d6c1](https://github.com/taikoxyz/taiko-mono/commit/3a9d6c166b7c6666eb2515893b6a3fbd00f4b1ea))
* **protocol:** fix test related to SendMessageToDelegateOwner.s.sol ([#18300](https://github.com/taikoxyz/taiko-mono/issues/18300)) ([65daa3e](https://github.com/taikoxyz/taiko-mono/commit/65daa3e631b471d17dbffb1001dab66efa67c499))
* **protocol:** fix wrong Bridged ERC20 address cache ([#18287](https://github.com/taikoxyz/taiko-mono/issues/18287)) ([49267ab](https://github.com/taikoxyz/taiko-mono/commit/49267abaa6d27d16fe4fb62ca0bb28d49b09d2f9))
* **protocol:** revert a change to maintain taiko-geth compatibility  ([#18331](https://github.com/taikoxyz/taiko-mono/issues/18331)) ([9d18d59](https://github.com/taikoxyz/taiko-mono/commit/9d18d598fe3e890a1f35e2d39916d554282ee4a0))
* **protocol:** revert changes related to `proposedIn` and `proposedAt` to fix a bug ([#18333](https://github.com/taikoxyz/taiko-mono/issues/18333)) ([5cb43ab](https://github.com/taikoxyz/taiko-mono/commit/5cb43ab1e29422353de549f8386eff613291c7df))
* **protocol:** reward non-assigned prover 7/8 liveness bond ([#18132](https://github.com/taikoxyz/taiko-mono/issues/18132)) ([9f99099](https://github.com/taikoxyz/taiko-mono/commit/9f99099ac271e6e2a0973a43084e29169386f2cd))
* **protocol:** small fix to 1559 error check ([#18339](https://github.com/taikoxyz/taiko-mono/issues/18339)) ([4428661](https://github.com/taikoxyz/taiko-mono/commit/44286615a0e0b0a17892fe83aad96546a6b1aca1))


### Chores

* **docs:** redirect the contribution.md path ([#18316](https://github.com/taikoxyz/taiko-mono/issues/18316)) ([0607ef7](https://github.com/taikoxyz/taiko-mono/commit/0607ef718dbe34c0ffe125825b12001b36a43fc5))
* **protocol:** add functions to ITaikoL1 for Nethermind Preconf ([#18217](https://github.com/taikoxyz/taiko-mono/issues/18217)) ([e349d22](https://github.com/taikoxyz/taiko-mono/commit/e349d2237a1830edab305b2f0eaaeb0eaf3c623f))
* **protocol:** change Hekla gas issuance per sec to 100000 ([#18335](https://github.com/taikoxyz/taiko-mono/issues/18335)) ([3d448d4](https://github.com/taikoxyz/taiko-mono/commit/3d448d4a78608ea7daf1d50e877c32f8d30f1e7a))
* **protocol:** change Hekla sharingPctg to 80% & gasIssuancePerSecond to 1000000 ([#18322](https://github.com/taikoxyz/taiko-mono/issues/18322)) ([75feb5b](https://github.com/taikoxyz/taiko-mono/commit/75feb5b36560b786a54e97280352c0d70c3e2f06))
* **protocol:** fix lint issue in SP1Verifier ([#18213](https://github.com/taikoxyz/taiko-mono/issues/18213)) ([7874dd3](https://github.com/taikoxyz/taiko-mono/commit/7874dd3ff8a6053da8c09377b52c83e7a506f45f))
* **protocol:** improve the usage of `initializer` and `reinitializer` ([#18319](https://github.com/taikoxyz/taiko-mono/issues/18319)) ([13cc007](https://github.com/taikoxyz/taiko-mono/commit/13cc0074a2295c5939cf83e23f531cb25c43bd64))
* **protocol:** revert Hekla `baseFeeConfig` updates ([#18340](https://github.com/taikoxyz/taiko-mono/issues/18340)) ([ae8ac3c](https://github.com/taikoxyz/taiko-mono/commit/ae8ac3c2e686b136de8c68853ecb91a39260a93f))
* **protocol:** set mainnet Ontake fork height ([#18112](https://github.com/taikoxyz/taiko-mono/issues/18112)) ([8812eb2](https://github.com/taikoxyz/taiko-mono/commit/8812eb2a8de367311b8ada6bd3587bfe5efee090))
* **protocol:** shorten imports in solidity files ([#18221](https://github.com/taikoxyz/taiko-mono/issues/18221)) ([9b2ba6a](https://github.com/taikoxyz/taiko-mono/commit/9b2ba6a2a2fae24d1fb34e23b29b3146e96f575e))
* **protoco:** remove unused delegate owner deployment ([#18290](https://github.com/taikoxyz/taiko-mono/issues/18290)) ([63ba863](https://github.com/taikoxyz/taiko-mono/commit/63ba863dcf322b2cf04d7dcaf6d8905bf28de6bc))


### Documentation

* **protocol:** fix invalid links in docs ([#18144](https://github.com/taikoxyz/taiko-mono/issues/18144)) ([c62f3f6](https://github.com/taikoxyz/taiko-mono/commit/c62f3f6b4a21f3af44f7df908fd8aac198721d5b))
* **protocol:** update code4rena-2024-03-taiko-final-report.md ([#18062](https://github.com/taikoxyz/taiko-mono/issues/18062)) ([fd68794](https://github.com/taikoxyz/taiko-mono/commit/fd68794a2de24b7a32d2d5a1c3f52c2156b6d61a))
* **protocol:** update Hekla deployments ([#18152](https://github.com/taikoxyz/taiko-mono/issues/18152)) ([6c7ff61](https://github.com/taikoxyz/taiko-mono/commit/6c7ff617b913b21b8b12b035f0d653c068830de3))
* **protocol:** update Hekla deployments ([#18257](https://github.com/taikoxyz/taiko-mono/issues/18257)) ([fbb1c82](https://github.com/taikoxyz/taiko-mono/commit/fbb1c824e35adb452176d988f32cf06d0c72b9bf))
* **protocol:** update L1 deployment ([#18299](https://github.com/taikoxyz/taiko-mono/issues/18299)) ([f60ce3e](https://github.com/taikoxyz/taiko-mono/commit/f60ce3e78bb9a2717718c3a9d7016346d5305488))
* **protocol:** update mainnet deployment ([#18258](https://github.com/taikoxyz/taiko-mono/issues/18258)) ([eeeb4af](https://github.com/taikoxyz/taiko-mono/commit/eeeb4afeff8572115c2cf82db149cee7a723f30c))
* **protocol:** upgrade sp1 plonk verifier 2.0.0 ([#18098](https://github.com/taikoxyz/taiko-mono/issues/18098)) ([cfd0e9e](https://github.com/taikoxyz/taiko-mono/commit/cfd0e9e4af2e42ead309e0c571b09dd20ddfe0f9))
* **protocol:** upgrade zk verifiers in Hekla ([#18279](https://github.com/taikoxyz/taiko-mono/issues/18279)) ([e98a1d5](https://github.com/taikoxyz/taiko-mono/commit/e98a1d5cdaa14af86340081ee42ad263a41bfdb5))


### Code Refactoring

* **protocol:** simplify some protocol code based on OpenZeppelin's recommendation ([#18308](https://github.com/taikoxyz/taiko-mono/issues/18308)) ([fbad703](https://github.com/taikoxyz/taiko-mono/commit/fbad703739f09d4524f9d808c3bad31d0122ec2c))
* **protocol:** slightly change defender monitors ([#18086](https://github.com/taikoxyz/taiko-mono/issues/18086)) ([b93d056](https://github.com/taikoxyz/taiko-mono/commit/b93d056479adfc4a1f557578d8b66eda48b104a9))


### Tests

* **protocol:** fix another L2 test failure ([#18304](https://github.com/taikoxyz/taiko-mono/issues/18304)) ([b3dd4dc](https://github.com/taikoxyz/taiko-mono/commit/b3dd4dccd261a9ebda69325661d2941001268ec2))

## [1.9.0](https://github.com/taikoxyz/taiko-mono/compare/protocol-v1.8.0...protocol-v1.9.0) (2024-09-12)


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
* **protocol:** allow msg.sender to customize block proposer addresses ([#18048](https://github.com/taikoxyz/taiko-mono/issues/18048)) ([22055cc](https://github.com/taikoxyz/taiko-mono/commit/22055cc95e51d07b6b57ab5cb2e4ccd9a97d594a))
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

* **main:** release protocol 1.9.0 ([#17783](https://github.com/taikoxyz/taiko-mono/issues/17783)) ([7bfd28a](https://github.com/taikoxyz/taiko-mono/commit/7bfd28a2b332c927cd8b6358623551814260f94e))
* **main:** release protocol 1.9.0 ([#18051](https://github.com/taikoxyz/taiko-mono/issues/18051)) ([2547ba9](https://github.com/taikoxyz/taiko-mono/commit/2547ba9409705bb759b62e59a7e5d5821349c71a))
* **protocol:** make two state variables in TaikoL2.sol public and add `adjustExcess` ([#17891](https://github.com/taikoxyz/taiko-mono/issues/17891)) ([ba21f68](https://github.com/taikoxyz/taiko-mono/commit/ba21f6836845ea0227116b701e701815f210d56d))
* **protocol:** move two files to simplify folder structure ([#17929](https://github.com/taikoxyz/taiko-mono/issues/17929)) ([9dca4fa](https://github.com/taikoxyz/taiko-mono/commit/9dca4faa43ad938880c8e1ac54236ab292bcce6e))
* **protocol:** re-generate layout files with diff order for comparison with new PR ([#18067](https://github.com/taikoxyz/taiko-mono/issues/18067)) ([078d336](https://github.com/taikoxyz/taiko-mono/commit/078d3367dce86a57d71d48291537e925cb1b4b91))
* **protocol:** revert `TAIKO_TOKEN` name changes in `DeployOnL1` ([#17927](https://github.com/taikoxyz/taiko-mono/issues/17927)) ([cf1a15f](https://github.com/taikoxyz/taiko-mono/commit/cf1a15f46344e60448c5fdcbcae02521fb5b7c04))
* **protocol:** revert releasing protocol 1.9.0 ([#17783](https://github.com/taikoxyz/taiko-mono/issues/17783)) ([#18049](https://github.com/taikoxyz/taiko-mono/issues/18049)) ([c033810](https://github.com/taikoxyz/taiko-mono/commit/c033810ecc4c80a4581a95b06ab5127747efd191))


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
* **protocol:** restructure solidity code to match compilation targets ([#18059](https://github.com/taikoxyz/taiko-mono/issues/18059)) ([adc47f4](https://github.com/taikoxyz/taiko-mono/commit/adc47f408282c25c7a50c26e31130fc495734dcc))
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
