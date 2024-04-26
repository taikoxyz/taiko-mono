# Changelog

## [4.2.0](https://github.com/taikoxyz/taiko-mono/compare/bridge-ui-v4.1.0...bridge-ui-v4.2.0) (2024-04-24)


### Features

* **bridge-ui:** update to protocol 1.0, two step bridging ([#16230](https://github.com/taikoxyz/taiko-mono/issues/16230))
* **bridge-ui:** walletconnect not allowing to switch to unconfigured chains ([#16324](https://github.com/taikoxyz/taiko-mono/issues/16324))
* **bridge-ui:** add testnet name to header ([#16619](https://github.com/taikoxyz/taiko-mono/issues/16619)) ([294bb01](https://github.com/taikoxyz/taiko-mono/commit/294bb017d90e4b8c2e1338a09f1cef90cdb54831))
* **bridge-ui:** base64 NFT data ([#16645](https://github.com/taikoxyz/taiko-mono/issues/16645)) ([4516d0a](https://github.com/taikoxyz/taiko-mono/commit/4516d0aaa3c9ff0c50f16d1abc82999a8ac3d02f))
* **bridge-ui:** mobile style for claim dialogs ([#16823](https://github.com/taikoxyz/taiko-mono/issues/16823)) ([63f15c9](https://github.com/taikoxyz/taiko-mono/commit/63f15c9dcad96aba755f7d618064b4149526cc22))
* **bridge-ui:** prepare for hekla ([#16618](https://github.com/taikoxyz/taiko-mono/issues/16618)) ([6953b3c](https://github.com/taikoxyz/taiko-mono/commit/6953b3c141a1dec744a0e0bfa8c9aa0a1f405407))
* **bridge-ui:** processingFee from API ([#16708](https://github.com/taikoxyz/taiko-mono/issues/16708)) ([3cd7cce](https://github.com/taikoxyz/taiko-mono/commit/3cd7cce1c52f94276011f4581143390c26acb49e))
* **bridge-ui:** remove two step and change gasLimit ([#16765](https://github.com/taikoxyz/taiko-mono/issues/16765)) ([14576f7](https://github.com/taikoxyz/taiko-mono/commit/14576f78ae5a93fe5ec7972f3e32789f26723592))
* **bridge-ui:** retry dialog ([#16536](https://github.com/taikoxyz/taiko-mono/issues/16536)) ([3beba21](https://github.com/taikoxyz/taiko-mono/commit/3beba214e62ad196bafd716cadaa3f133ecdb021))
* **bridge-ui:** update to protocol 1.0, two step bridging ([#16230](https://github.com/taikoxyz/taiko-mono/issues/16230)) ([71babae](https://github.com/taikoxyz/taiko-mono/commit/71babae14645ff267c7baa101706860aa6f556f0))
* **protocol:** risc0 verifier contract ([#16331](https://github.com/taikoxyz/taiko-mono/issues/16331)) ([17abc18](https://github.com/taikoxyz/taiko-mono/commit/17abc189ca3d2752beb5400c036a650fd5b9c895))


### Bug Fixes

* **bridge-ui:** add dependency ([#15999](https://github.com/taikoxyz/taiko-mono/issues/15999)) ([14484a0](https://github.com/taikoxyz/taiko-mono/commit/14484a00c1d59332361fba32b74d39db2ae4b864))
* **bridge-ui:** add injected provider to connectors ([#16008](https://github.com/taikoxyz/taiko-mono/issues/16008)) ([0496ff4](https://github.com/taikoxyz/taiko-mono/commit/0496ff40e374354b83d17121e4760391fed90a31))
* **bridge-ui:** add missing labels to i18n ([#16633](https://github.com/taikoxyz/taiko-mono/issues/16633)) ([3854467](https://github.com/taikoxyz/taiko-mono/commit/38544675bf6578bc1016ecfd60cb3a1f93207516))
* **bridge-ui:** balance updating when connecting ([#16481](https://github.com/taikoxyz/taiko-mono/issues/16481)) ([2ec333f](https://github.com/taikoxyz/taiko-mono/commit/2ec333f5d3f3330c11dc0ab3afacc027c33cd5e0))
* **bridge-ui:** canonical check can use wrong chain, incorrect supported chain check ([#16526](https://github.com/taikoxyz/taiko-mono/issues/16526)) ([d826e88](https://github.com/taikoxyz/taiko-mono/commit/d826e886eba989c35b3f28145f815642684f84d7))
* **bridge-ui:** correct display of forward arrow and handling of invalid pagination input ([#16485](https://github.com/taikoxyz/taiko-mono/issues/16485)) ([d4d9ce9](https://github.com/taikoxyz/taiko-mono/commit/d4d9ce9bb7914b21f8ce6fc1ac5f986eb64d41f8))
* **bridge-ui:** custom and none fee selection overwritten by error fetching recommended fee ([#16737](https://github.com/taikoxyz/taiko-mono/issues/16737)) ([9166ee3](https://github.com/taikoxyz/taiko-mono/commit/9166ee3e0a968db19d8cec2002565413d79cd708))
* **bridge-ui:** defaulting to source chain explorer for link to canonical address ([#16701](https://github.com/taikoxyz/taiko-mono/issues/16701)) ([68bd435](https://github.com/taikoxyz/taiko-mono/commit/68bd4354d03429ceccd4b311db6e59066111af09))
* **bridge-ui:** fix ERC721 and ERC1155 detection in NFT bridge ([#16680](https://github.com/taikoxyz/taiko-mono/issues/16680)) ([ca45aa6](https://github.com/taikoxyz/taiko-mono/commit/ca45aa6da6101f15fe9ef4c485e5d61a64f66f84))
* **bridge-ui:** fix ETH self claiming ([#16344](https://github.com/taikoxyz/taiko-mono/issues/16344)) ([4271f0d](https://github.com/taikoxyz/taiko-mono/commit/4271f0d2b01da8179d604a0fbff0816a0d72e547))
* **bridge-ui:** fix issue where balance is shown for wrong token ([#16541](https://github.com/taikoxyz/taiko-mono/issues/16541)) ([1dd47cf](https://github.com/taikoxyz/taiko-mono/commit/1dd47cf5eca91d47375547b23203a9f942e22e80))
* **bridge-ui:** fix wrong balance updates on network switch ([#15980](https://github.com/taikoxyz/taiko-mono/issues/15980)) ([b556e00](https://github.com/taikoxyz/taiko-mono/commit/b556e000b25fc8d5405cba77f3eebb4152dc1497))
* **bridge-ui:** incorrectly detecting bridged tokens ([#16007](https://github.com/taikoxyz/taiko-mono/issues/16007)) ([b151bcb](https://github.com/taikoxyz/taiko-mono/commit/b151bcb2e159ece03da3c2014e35dbbbed7d8410))
* **bridge-ui:** manual import not resetting correctly ([#16347](https://github.com/taikoxyz/taiko-mono/issues/16347)) ([87398fe](https://github.com/taikoxyz/taiko-mono/commit/87398fe9606cf73ce66ed4f8321368fe8ac8fbb4))
* **bridge-ui:** move label to i18n, fix some typos ([#16522](https://github.com/taikoxyz/taiko-mono/issues/16522)) ([c8c4773](https://github.com/taikoxyz/taiko-mono/commit/c8c4773dd3fe41decf13306eace73d65a9829529))
* **bridge-ui:** preserve custom processing fee selection across components ([#16346](https://github.com/taikoxyz/taiko-mono/issues/16346)) ([9cf6b3a](https://github.com/taikoxyz/taiko-mono/commit/9cf6b3ae0981d1755d253cd7d6238771898fc3f4))
* **bridge-ui:** prevent reverse tabnabbing attacks ([#16583](https://github.com/taikoxyz/taiko-mono/issues/16583)) ([fc57d82](https://github.com/taikoxyz/taiko-mono/commit/fc57d82cb7c049a656c2f08d947f4a5a42ffacf3))
* **bridge-ui:** remove nft debug info from ui ([#16067](https://github.com/taikoxyz/taiko-mono/issues/16067)) ([5eddffe](https://github.com/taikoxyz/taiko-mono/commit/5eddffea3180e67c005d510ddaa7ffb90ce0a85a))
* **bridge-ui:** renamed configuredCustomToken to configuredCustomTokens ([#15905](https://github.com/taikoxyz/taiko-mono/issues/15905)) ([a9f60b8](https://github.com/taikoxyz/taiko-mono/commit/a9f60b8c114dfd277e8dc227e7fbbe8716698d53))
* **bridge-ui:** transactions view styling  ([#15997](https://github.com/taikoxyz/taiko-mono/issues/15997)) ([620a22d](https://github.com/taikoxyz/taiko-mono/commit/620a22dcb1ce77a9335dff8bbe0546c4c5065b23))
* **bridge-ui:** truncate selected token name to 5 characters ([#16066](https://github.com/taikoxyz/taiko-mono/issues/16066)) ([dc24155](https://github.com/taikoxyz/taiko-mono/commit/dc24155b306e447f0572d29918183570905866be))
* **bridge-ui:** update disabled for chainselector ([#16814](https://github.com/taikoxyz/taiko-mono/issues/16814)) ([406b15a](https://github.com/taikoxyz/taiko-mono/commit/406b15a301c7a3454957518a2cc33a44fbf21cde))
* **bridge-ui:** various small bugfixes ([#16078](https://github.com/taikoxyz/taiko-mono/issues/16078)) ([e610d19](https://github.com/taikoxyz/taiko-mono/commit/e610d1907ef47fb6e25d8bc26e9b7edf3954d886))
* **bridge-ui:** walletconnect not allowing to switch to unconfigured chains ([#16324](https://github.com/taikoxyz/taiko-mono/issues/16324)) ([d6ef79e](https://github.com/taikoxyz/taiko-mono/commit/d6ef79eae0836a9dabd481cd0953bc03eea9bf7a))

## [4.1.0](https://github.com/taikoxyz/taiko-mono/compare/bridge-ui-v4.0.0...bridge-ui-v4.1.0) (2024-04-24)


### Features

* **bridge-ui:** processingFee from API ([#16708](https://github.com/taikoxyz/taiko-mono/issues/16708)) ([3cd7cce](https://github.com/taikoxyz/taiko-mono/commit/3cd7cce1c52f94276011f4581143390c26acb49e))


### Bug Fixes

* **bridge-ui:** custom and none fee selection overwritten by error fetching recommended fee ([#16737](https://github.com/taikoxyz/taiko-mono/issues/16737)) ([9166ee3](https://github.com/taikoxyz/taiko-mono/commit/9166ee3e0a968db19d8cec2002565413d79cd708))
* **bridge-ui:** defaulting to source chain explorer for link to canonical address ([#16701](https://github.com/taikoxyz/taiko-mono/issues/16701)) ([68bd435](https://github.com/taikoxyz/taiko-mono/commit/68bd4354d03429ceccd4b311db6e59066111af09))
* **bridge-ui:** fix ERC721 and ERC1155 detection in NFT bridge ([#16680](https://github.com/taikoxyz/taiko-mono/issues/16680)) ([ca45aa6](https://github.com/taikoxyz/taiko-mono/commit/ca45aa6da6101f15fe9ef4c485e5d61a64f66f84))
* **bridge-ui:** update disabled for chainselector ([#16814](https://github.com/taikoxyz/taiko-mono/issues/16814)) ([406b15a](https://github.com/taikoxyz/taiko-mono/commit/406b15a301c7a3454957518a2cc33a44fbf21cde))

## [4.0.0](https://github.com/taikoxyz/taiko-mono/compare/bridge-ui-v3.0.0...bridge-ui-v4.0.0) (2024-04-04)


### ⚠ BREAKING CHANGES

* **bridge-ui:** update to protocol 1.0, two step bridging ([#16230](https://github.com/taikoxyz/taiko-mono/issues/16230))

### Features

* **bridge-ui:** add testnet name to header ([#16619](https://github.com/taikoxyz/taiko-mono/issues/16619)) ([294bb01](https://github.com/taikoxyz/taiko-mono/commit/294bb017d90e4b8c2e1338a09f1cef90cdb54831))
* **bridge-ui:** base64 NFT data ([#16645](https://github.com/taikoxyz/taiko-mono/issues/16645)) ([4516d0a](https://github.com/taikoxyz/taiko-mono/commit/4516d0aaa3c9ff0c50f16d1abc82999a8ac3d02f))
* **bridge-ui:** prepare for hekla ([#16618](https://github.com/taikoxyz/taiko-mono/issues/16618)) ([6953b3c](https://github.com/taikoxyz/taiko-mono/commit/6953b3c141a1dec744a0e0bfa8c9aa0a1f405407))
* **bridge-ui:** retry dialog ([#16536](https://github.com/taikoxyz/taiko-mono/issues/16536)) ([3beba21](https://github.com/taikoxyz/taiko-mono/commit/3beba214e62ad196bafd716cadaa3f133ecdb021))
* **bridge-ui:** update to protocol 1.0, two step bridging ([#16230](https://github.com/taikoxyz/taiko-mono/issues/16230)) ([71babae](https://github.com/taikoxyz/taiko-mono/commit/71babae14645ff267c7baa101706860aa6f556f0))
* **protocol:** risc0 verifier contract ([#16331](https://github.com/taikoxyz/taiko-mono/issues/16331)) ([17abc18](https://github.com/taikoxyz/taiko-mono/commit/17abc189ca3d2752beb5400c036a650fd5b9c895))


### Bug Fixes

* **bridge-ui:** add missing labels to i18n ([#16633](https://github.com/taikoxyz/taiko-mono/issues/16633)) ([3854467](https://github.com/taikoxyz/taiko-mono/commit/38544675bf6578bc1016ecfd60cb3a1f93207516))
* **bridge-ui:** balance updating when connecting ([#16481](https://github.com/taikoxyz/taiko-mono/issues/16481)) ([2ec333f](https://github.com/taikoxyz/taiko-mono/commit/2ec333f5d3f3330c11dc0ab3afacc027c33cd5e0))
* **bridge-ui:** canonical check can use wrong chain, incorrect supported chain check ([#16526](https://github.com/taikoxyz/taiko-mono/issues/16526)) ([d826e88](https://github.com/taikoxyz/taiko-mono/commit/d826e886eba989c35b3f28145f815642684f84d7))
* **bridge-ui:** correct display of forward arrow and handling of invalid pagination input ([#16485](https://github.com/taikoxyz/taiko-mono/issues/16485)) ([d4d9ce9](https://github.com/taikoxyz/taiko-mono/commit/d4d9ce9bb7914b21f8ce6fc1ac5f986eb64d41f8))
* **bridge-ui:** fix issue where balance is shown for wrong token ([#16541](https://github.com/taikoxyz/taiko-mono/issues/16541)) ([1dd47cf](https://github.com/taikoxyz/taiko-mono/commit/1dd47cf5eca91d47375547b23203a9f942e22e80))
* **bridge-ui:** move label to i18n, fix some typos ([#16522](https://github.com/taikoxyz/taiko-mono/issues/16522)) ([c8c4773](https://github.com/taikoxyz/taiko-mono/commit/c8c4773dd3fe41decf13306eace73d65a9829529))
* **bridge-ui:** prevent reverse tabnabbing attacks ([#16583](https://github.com/taikoxyz/taiko-mono/issues/16583)) ([fc57d82](https://github.com/taikoxyz/taiko-mono/commit/fc57d82cb7c049a656c2f08d947f4a5a42ffacf3))

## [3.0.0](https://github.com/taikoxyz/taiko-mono/compare/bridge-ui-v2.9.3...bridge-ui-v3.0.0) (2024-03-08)


### ⚠ BREAKING CHANGES

* **bridge-ui:** walletconnect not allowing to switch to unconfigured chains ([#16324](https://github.com/taikoxyz/taiko-mono/issues/16324))

### Bug Fixes

* **bridge-ui:** fix ETH self claiming ([#16344](https://github.com/taikoxyz/taiko-mono/issues/16344)) ([4271f0d](https://github.com/taikoxyz/taiko-mono/commit/4271f0d2b01da8179d604a0fbff0816a0d72e547))
* **bridge-ui:** manual import not resetting correctly ([#16347](https://github.com/taikoxyz/taiko-mono/issues/16347)) ([87398fe](https://github.com/taikoxyz/taiko-mono/commit/87398fe9606cf73ce66ed4f8321368fe8ac8fbb4))
* **bridge-ui:** preserve custom processing fee selection across components ([#16346](https://github.com/taikoxyz/taiko-mono/issues/16346)) ([9cf6b3a](https://github.com/taikoxyz/taiko-mono/commit/9cf6b3ae0981d1755d253cd7d6238771898fc3f4))
* **bridge-ui:** walletconnect not allowing to switch to unconfigured chains ([#16324](https://github.com/taikoxyz/taiko-mono/issues/16324)) ([d6ef79e](https://github.com/taikoxyz/taiko-mono/commit/d6ef79eae0836a9dabd481cd0953bc03eea9bf7a))

## [2.9.3](https://github.com/taikoxyz/taiko-mono/compare/bridge-ui-v2.9.2...bridge-ui-v2.9.3) (2024-02-26)


### Bug Fixes

* **bridge-ui:** remove nft debug info from ui ([#16067](https://github.com/taikoxyz/taiko-mono/issues/16067)) ([5eddffe](https://github.com/taikoxyz/taiko-mono/commit/5eddffea3180e67c005d510ddaa7ffb90ce0a85a))
* **bridge-ui:** truncate selected token name to 5 characters ([#16066](https://github.com/taikoxyz/taiko-mono/issues/16066)) ([dc24155](https://github.com/taikoxyz/taiko-mono/commit/dc24155b306e447f0572d29918183570905866be))
* **bridge-ui:** various small bugfixes ([#16078](https://github.com/taikoxyz/taiko-mono/issues/16078)) ([e610d19](https://github.com/taikoxyz/taiko-mono/commit/e610d1907ef47fb6e25d8bc26e9b7edf3954d886))

## [2.9.2](https://github.com/taikoxyz/taiko-mono/compare/bridge-ui-v2.9.1...bridge-ui-v2.9.2) (2024-02-23)


### Bug Fixes

* **bridge-ui:** add injected provider to connectors ([#16008](https://github.com/taikoxyz/taiko-mono/issues/16008)) ([0496ff4](https://github.com/taikoxyz/taiko-mono/commit/0496ff40e374354b83d17121e4760391fed90a31))
* **bridge-ui:** renamed configuredCustomToken to configuredCustomTokens ([#15905](https://github.com/taikoxyz/taiko-mono/issues/15905)) ([a9f60b8](https://github.com/taikoxyz/taiko-mono/commit/a9f60b8c114dfd277e8dc227e7fbbe8716698d53))

## [2.9.1](https://github.com/taikoxyz/taiko-mono/compare/bridge-ui-v2.9.0...bridge-ui-v2.9.1) (2024-02-22)


### Bug Fixes

* **bridge-ui:** add dependency ([#15999](https://github.com/taikoxyz/taiko-mono/issues/15999)) ([14484a0](https://github.com/taikoxyz/taiko-mono/commit/14484a00c1d59332361fba32b74d39db2ae4b864))
* **bridge-ui:** fix wrong balance updates on network switch ([#15980](https://github.com/taikoxyz/taiko-mono/issues/15980)) ([b556e00](https://github.com/taikoxyz/taiko-mono/commit/b556e000b25fc8d5405cba77f3eebb4152dc1497))
* **bridge-ui:** incorrectly detecting bridged tokens ([#16007](https://github.com/taikoxyz/taiko-mono/issues/16007)) ([b151bcb](https://github.com/taikoxyz/taiko-mono/commit/b151bcb2e159ece03da3c2014e35dbbbed7d8410))
* **bridge-ui:** transactions view styling  ([#15997](https://github.com/taikoxyz/taiko-mono/issues/15997)) ([620a22d](https://github.com/taikoxyz/taiko-mono/commit/620a22dcb1ce77a9335dff8bbe0546c4c5065b23))
* fix typos in tests and comments ([#15028](https://github.com/taikoxyz/taiko-mono/issues/15028)) ([54bf597](https://github.com/taikoxyz/taiko-mono/commit/54bf597c89a7f22161eeeffd13c20fe0acb4e2d7))

## [2.9.0](https://github.com/taikoxyz/taiko-mono/compare/bridge-ui-v2-v2.8.0...bridge-ui-v2-v2.9.0) (2023-10-18)


### Features

* **bridge-ui-v2:** dynamic import of NFT data via API ([#14928](https://github.com/taikoxyz/taiko-mono/issues/14928)) ([946c337](https://github.com/taikoxyz/taiko-mono/commit/946c337070eb2f2a9a2aa1f7314d7469ccd1b818))
* **bridge-ui-v2:** manual NFT import step ([#14842](https://github.com/taikoxyz/taiko-mono/issues/14842)) ([c85e162](https://github.com/taikoxyz/taiko-mono/commit/c85e1629d0b9b544880f65f0e4050456579c87d1))
* **bridge-ui-v2:** NFT bridging ([#14949](https://github.com/taikoxyz/taiko-mono/issues/14949)) ([36c5ccd](https://github.com/taikoxyz/taiko-mono/commit/36c5ccda09e0d7ef062aff33e98548314486e437))
* **bridge-ui-v2:** review step ([#14940](https://github.com/taikoxyz/taiko-mono/issues/14940)) ([c079223](https://github.com/taikoxyz/taiko-mono/commit/c0792230bab8c245ad3b779f695a7bdd0f598fc8))

## [2.8.0](https://github.com/taikoxyz/taiko-mono/compare/bridge-ui-v2-v2.7.0...bridge-ui-v2-v2.8.0) (2023-10-03)


### Features

* **bridge-ui-v2:** NFT bridge stepper ([#14811](https://github.com/taikoxyz/taiko-mono/issues/14811)) ([90e19fc](https://github.com/taikoxyz/taiko-mono/commit/90e19fc8b2e76d7f049b2ceedd7a54992b85b398))

## [2.7.0](https://github.com/taikoxyz/taiko-mono/compare/bridge-ui-v2-v2.6.0...bridge-ui-v2-v2.7.0) (2023-09-25)


### Features

* **bridge-ui-v2:** add BLL warning ([#14723](https://github.com/taikoxyz/taiko-mono/issues/14723)) ([6e5b789](https://github.com/taikoxyz/taiko-mono/commit/6e5b789e06d74c98c22a18af7f59ee94572d0866))
* **bridge-ui-v2:** add dialog for claim with insufficient funds ([#14742](https://github.com/taikoxyz/taiko-mono/issues/14742)) ([75a1c71](https://github.com/taikoxyz/taiko-mono/commit/75a1c71851d1ae348b503ccb8b318760e97e6b0e))
* **bridge-ui-v2:** allow bridging to all layers ([#14525](https://github.com/taikoxyz/taiko-mono/issues/14525)) ([e25e0cd](https://github.com/taikoxyz/taiko-mono/commit/e25e0cd060e651f1e626d2e8a104e261ff90e94e))
* **bridge-ui-v2:** close dialogs with ESC key ([#14700](https://github.com/taikoxyz/taiko-mono/issues/14700)) ([dbf7a24](https://github.com/taikoxyz/taiko-mono/commit/dbf7a24a32a4518f4a9dbbfbbead732ab8a9b548))
* **bridge-ui-v2:** Improve refreshing users balance ([#14651](https://github.com/taikoxyz/taiko-mono/issues/14651)) ([8028a49](https://github.com/taikoxyz/taiko-mono/commit/8028a49ea2dfc123b1c818afb722a029d3743e5c))
* **bridge-ui-v2:** insufficient funds modal ([#14759](https://github.com/taikoxyz/taiko-mono/issues/14759)) ([c6e23ad](https://github.com/taikoxyz/taiko-mono/commit/c6e23ad79eeb899551572b0a2a4abcac02339893))
* **bridge-ui-v2:** styling adjustments for dialogs ([#14666](https://github.com/taikoxyz/taiko-mono/issues/14666)) ([91c6284](https://github.com/taikoxyz/taiko-mono/commit/91c6284e2da231233fdb9ad8adfecb7790d6b90a))


### Bug Fixes

* **bridge-ui-v2:** Add z-index for close button on mobile ([#14769](https://github.com/taikoxyz/taiko-mono/issues/14769)) ([6dff6fc](https://github.com/taikoxyz/taiko-mono/commit/6dff6fc9990bab20cf2042cab0010fac826e14e1))
* **bridge-ui-v2:** approve button not updating ([#14746](https://github.com/taikoxyz/taiko-mono/issues/14746)) ([ccbfa9a](https://github.com/taikoxyz/taiko-mono/commit/ccbfa9a62d2f918a8c321e1c147ccc606f599bb0))
* **bridge-ui-v2:** build errors ([#14706](https://github.com/taikoxyz/taiko-mono/issues/14706)) ([f180bcd](https://github.com/taikoxyz/taiko-mono/commit/f180bcd188452f65542e18250652b9c243d4a303))
* **bridge-ui-v2:** button disable status ([#14674](https://github.com/taikoxyz/taiko-mono/issues/14674)) ([4b304dc](https://github.com/taikoxyz/taiko-mono/commit/4b304dc37369ba7775fb3669b1e6af5967f95db8))
* **bridge-ui-v2:** check destination funds for ETH ([#14762](https://github.com/taikoxyz/taiko-mono/issues/14762)) ([fa2e842](https://github.com/taikoxyz/taiko-mono/commit/fa2e842c256c28713c3ebd9a50a99f945048df12))
* **bridge-ui-v2:** custom tokens from local storage ([#14677](https://github.com/taikoxyz/taiko-mono/issues/14677)) ([3ebf022](https://github.com/taikoxyz/taiko-mono/commit/3ebf0226606b9561ee60fa47ef7d292a3b843678))
* **bridge-ui-v2:** fix unit tests ([#14679](https://github.com/taikoxyz/taiko-mono/issues/14679)) ([7ddd7ef](https://github.com/taikoxyz/taiko-mono/commit/7ddd7ef77e735fbcffecac538e206fb64e9c14bf))
* **bridge-ui-v2:** improve claim message when not enough funds ([#14738](https://github.com/taikoxyz/taiko-mono/issues/14738)) ([ff938a0](https://github.com/taikoxyz/taiko-mono/commit/ff938a00733d399710bc2fcabc5c42a0960ee8ab))
* **bridge-ui-v2:** missing TTKO icon  ([#14754](https://github.com/taikoxyz/taiko-mono/issues/14754)) ([3bb4fd2](https://github.com/taikoxyz/taiko-mono/commit/3bb4fd28d24e644554c7a607ab362e081bb4039d))
* **bridge-ui-v2:** processing fee ([#14696](https://github.com/taikoxyz/taiko-mono/issues/14696)) ([1103695](https://github.com/taikoxyz/taiko-mono/commit/1103695fa77265b8670be4ecaee2a5ead8e8e5c0))
* **bridge-ui-v2:** Show warnings on faucet correctly ([#14676](https://github.com/taikoxyz/taiko-mono/issues/14676)) ([861c7f3](https://github.com/taikoxyz/taiko-mono/commit/861c7f31f800813570579c4b0e7dc69956f4c04f))
* **bridge-ui-v2:** update mint button state ([#14720](https://github.com/taikoxyz/taiko-mono/issues/14720)) ([3ee161b](https://github.com/taikoxyz/taiko-mono/commit/3ee161b7a1ebac006594961457e9e7f426ed29a2))
* **bridge-ui-v2:** validate amount only if component is mounted ([#14757](https://github.com/taikoxyz/taiko-mono/issues/14757)) ([c506409](https://github.com/taikoxyz/taiko-mono/commit/c506409d6a41d84c110f6ba715f1bbf023d1e192))
* **bridge-ui-v2:** validation of token balance  ([#14755](https://github.com/taikoxyz/taiko-mono/issues/14755)) ([40bbaf1](https://github.com/taikoxyz/taiko-mono/commit/40bbaf13df1db158073299f9b1b9ffc5d1c8123a))

## [2.6.0](https://github.com/taikoxyz/taiko-mono/compare/bridge-ui-v2-v2.5.0...bridge-ui-v2-v2.6.0) (2023-09-05)


### Features

* **bridge-ui-v2:** AddressInput component ([#14572](https://github.com/taikoxyz/taiko-mono/issues/14572)) ([9f6a283](https://github.com/taikoxyz/taiko-mono/commit/9f6a283aef914efcf2284a93337179c402ee64ec))
* **bridge-ui-v2:** Style adjustments for dialogs ([#14632](https://github.com/taikoxyz/taiko-mono/issues/14632)) ([148d6aa](https://github.com/taikoxyz/taiko-mono/commit/148d6aa39dd269d000b964ff6553e8646885d8f4))
* **bridge-ui-v2:** Styling adjustments ([#14588](https://github.com/taikoxyz/taiko-mono/issues/14588)) ([85bef05](https://github.com/taikoxyz/taiko-mono/commit/85bef055c8778a473fff41318b06792c151efa52))
* **bridge-ui-v2:** truncate-chainname ([#14603](https://github.com/taikoxyz/taiko-mono/issues/14603)) ([bdc9c43](https://github.com/taikoxyz/taiko-mono/commit/bdc9c434ba43bb213c79b03da83b090693658a54))


### Bug Fixes

* **bridge-ui-v2:** Fix dialogs being offset ([#14624](https://github.com/taikoxyz/taiko-mono/issues/14624)) ([2367c89](https://github.com/taikoxyz/taiko-mono/commit/2367c89940bbdc67de14d6fb71d138f9a2157d17))

## [2.5.0](https://github.com/taikoxyz/taiko-mono/compare/bridge-ui-v2-v2.4.0...bridge-ui-v2-v2.5.0) (2023-08-22)


### Features

* **bridge-ui-v2:** destination token bridged ([#14448](https://github.com/taikoxyz/taiko-mono/issues/14448)) ([072afbf](https://github.com/taikoxyz/taiko-mono/commit/072afbf3e54efe813a3eb76000faa4861620caba))
* **bridge-ui-v2:** fix vercel routing ([#14522](https://github.com/taikoxyz/taiko-mono/issues/14522)) ([2ab5faf](https://github.com/taikoxyz/taiko-mono/commit/2ab5faf11789078730b3b3e3eab516fb6ca11d0a))
* **bridge-ui-v2:** light theme ([#14524](https://github.com/taikoxyz/taiko-mono/issues/14524)) ([4fe5ccd](https://github.com/taikoxyz/taiko-mono/commit/4fe5ccdc6d91f11d697beba76f6ad205bc6af2bf))
* **bridge-ui-v2:** Processing fee input box ([#14527](https://github.com/taikoxyz/taiko-mono/issues/14527)) ([886ab31](https://github.com/taikoxyz/taiko-mono/commit/886ab311812b4583c823976524d799b2b9e90d46))
* **bridge-ui-v2:** switch chain on wrong network ([#14511](https://github.com/taikoxyz/taiko-mono/issues/14511)) ([89b8a86](https://github.com/taikoxyz/taiko-mono/commit/89b8a86134fe9227d6011f69c7de0b8420ad25dc))
* **bridge-ui-v2:** update the style of chain selector ([#14517](https://github.com/taikoxyz/taiko-mono/issues/14517)) ([35ef27d](https://github.com/taikoxyz/taiko-mono/commit/35ef27db2df032b6639ce3ed719cb78c081b9c9f))
* **bridge-ui-v2:** update the style of switch chain button ([#14518](https://github.com/taikoxyz/taiko-mono/issues/14518)) ([6099842](https://github.com/taikoxyz/taiko-mono/commit/6099842821935066c99fcc0f5996ba183ea11a89))


### Bug Fixes

* **bridge-ui-v2:** refresh ETH balance at the top right ([#14539](https://github.com/taikoxyz/taiko-mono/issues/14539)) ([63a6d41](https://github.com/taikoxyz/taiko-mono/commit/63a6d41da3fe2e0e63032f13456d7a47d85ae45f))

## [2.4.0](https://github.com/taikoxyz/taiko-mono/compare/bridge-ui-v2-v2.3.0...bridge-ui-v2-v2.4.0) (2023-08-15)


### Features

* **bridge-ui-v2:** Activities page ([#14504](https://github.com/taikoxyz/taiko-mono/issues/14504)) ([4dff4b3](https://github.com/taikoxyz/taiko-mono/commit/4dff4b317e0ecda43c9804a9e04d2f22c8332a60))
* **bridge-ui-v2:** Addition of custom token ([#14365](https://github.com/taikoxyz/taiko-mono/issues/14365)) ([a82fecb](https://github.com/taikoxyz/taiko-mono/commit/a82fecb63fe357af4f1fbcf07ed8b2f39d66fa50))
* **bridge-ui-v2:** Claim & Release ([#14267](https://github.com/taikoxyz/taiko-mono/issues/14267)) ([6c6089e](https://github.com/taikoxyz/taiko-mono/commit/6c6089e75e3bb418bced2f230d481580971929e3))
* **bridge-ui-v2:** NFT Bridge UI initial setup ([#14261](https://github.com/taikoxyz/taiko-mono/issues/14261)) ([d634033](https://github.com/taikoxyz/taiko-mono/commit/d634033e6dd3459d30bd248b9d809c4c1b5f910f))
* **bridge-ui-v2:** Style adjustments ([#14350](https://github.com/taikoxyz/taiko-mono/issues/14350)) ([17bbf07](https://github.com/taikoxyz/taiko-mono/commit/17bbf07ac80b4f78f0d3b17e374e9d88ed634eaa))
* **protocol:** alpha-4 with staking-based tokenomics ([#14065](https://github.com/taikoxyz/taiko-mono/issues/14065)) ([1eeba9d](https://github.com/taikoxyz/taiko-mono/commit/1eeba9d97ed8e6e4a8d07a8b0af163a16fbc9ccf))

## [2.3.0](https://github.com/taikoxyz/taiko-mono/compare/bridge-ui-v2-v2.2.0...bridge-ui-v2-v2.3.0) (2023-07-24)


### Features

* **bridge-ui-v2:** account balance ([#14159](https://github.com/taikoxyz/taiko-mono/issues/14159)) ([081be64](https://github.com/taikoxyz/taiko-mono/commit/081be64591b48cfa4fb10baf3067cf974476e298))
* **bridge-ui-v2:** amount input validation ([#14213](https://github.com/taikoxyz/taiko-mono/issues/14213)) ([4b639d7](https://github.com/taikoxyz/taiko-mono/commit/4b639d7a5315c20a6766fb2b59d0ce5d3b973453))
* **bridge-ui-v2:** bridging ETH and ERC20 ([#14225](https://github.com/taikoxyz/taiko-mono/issues/14225)) ([c3375a4](https://github.com/taikoxyz/taiko-mono/commit/c3375a4ce43cea719568a6661428b78b2354ec51))
* **bridge-ui-v2:** Faucet ([#14145](https://github.com/taikoxyz/taiko-mono/issues/14145)) ([b2f2388](https://github.com/taikoxyz/taiko-mono/commit/b2f23889e903ca933dde00bc7f20d88f78bc72a7))
* **bridge-ui-v2:** Processing Fee ([#14170](https://github.com/taikoxyz/taiko-mono/issues/14170)) ([13ebf1c](https://github.com/taikoxyz/taiko-mono/commit/13ebf1c54f147bfb0ad754abc24271caf97c3775))


### Bug Fixes

* **bridge-ui-v2:** processing fee and amount input validation ([#14220](https://github.com/taikoxyz/taiko-mono/issues/14220)) ([61138a8](https://github.com/taikoxyz/taiko-mono/commit/61138a88b529d70df0e81468052971a4fc4fde16))
* **bridge-ui-v2:** token dropdown click away ([#14224](https://github.com/taikoxyz/taiko-mono/issues/14224)) ([4f879cb](https://github.com/taikoxyz/taiko-mono/commit/4f879cbbbd77f5f82ea150391756cc92879d5848))

## [2.2.0](https://github.com/taikoxyz/taiko-mono/compare/bridge-ui-v2-v2.1.0...bridge-ui-v2-v2.2.0) (2023-07-10)


### Features

* **bridge-ui-v2:** activities page ([#14089](https://github.com/taikoxyz/taiko-mono/issues/14089)) ([f4c6f84](https://github.com/taikoxyz/taiko-mono/commit/f4c6f8482cb2fd2242b95bc3495b64481f64ab3d))
* **bridge-ui-v2:** bridge form ([#14056](https://github.com/taikoxyz/taiko-mono/issues/14056)) ([b39b328](https://github.com/taikoxyz/taiko-mono/commit/b39b328cc602fc9ea05fcd4551b40cd91a6efe37))
* **bridge-ui-v2:** connect button ([#14106](https://github.com/taikoxyz/taiko-mono/issues/14106)) ([ccaa498](https://github.com/taikoxyz/taiko-mono/commit/ccaa4987680f2e3640d13ed5ed1798afaab8ca1e))
* **bridge-ui-v2:** generate abi ([#14116](https://github.com/taikoxyz/taiko-mono/issues/14116)) ([c962aac](https://github.com/taikoxyz/taiko-mono/commit/c962aac65791c9bc1836e10490ed15029dd173b3))
* **bridge-ui-v2:** switch chain ([#14117](https://github.com/taikoxyz/taiko-mono/issues/14117)) ([d51161d](https://github.com/taikoxyz/taiko-mono/commit/d51161d424921ee002812cf69d40f5ee27a464ad))


### Bug Fixes

* **bridge-ui-v2:** fix deployment ([#14096](https://github.com/taikoxyz/taiko-mono/issues/14096)) ([4197654](https://github.com/taikoxyz/taiko-mono/commit/419765484db6c3bd94b07f8803c9465d4260a2f6))
* **bridge-ui-v2:** fixed menus ([#14099](https://github.com/taikoxyz/taiko-mono/issues/14099)) ([fabefb2](https://github.com/taikoxyz/taiko-mono/commit/fabefb2ca20c91f1c08c858967505a991dafdf4e))

## [2.1.0](https://github.com/taikoxyz/taiko-mono/compare/bridge-ui-v2-v2.0.0...bridge-ui-v2-v2.1.0) (2023-06-26)

### Features

- **bridge-ui-v2:** env vars ([#14034](https://github.com/taikoxyz/taiko-mono/issues/14034)) ([fccc0a7](https://github.com/taikoxyz/taiko-mono/commit/fccc0a7252b93148559a0438ee23366f04fc86f6))
- **bridge-ui-v2:** initial setup v2 ([#14013](https://github.com/taikoxyz/taiko-mono/issues/14013)) ([429bf7a](https://github.com/taikoxyz/taiko-mono/commit/429bf7a1619b9554f999db29d236ce0c9c6236da))
- **bridge-ui-v2:** tailwind config and other setups ([#14016](https://github.com/taikoxyz/taiko-mono/issues/14016)) ([be294c6](https://github.com/taikoxyz/taiko-mono/commit/be294c66764d658423d58902076594afdc470e96))
- **bridge-ui-v2:** use web3modal ([#14043](https://github.com/taikoxyz/taiko-mono/issues/14043)) ([911c701](https://github.com/taikoxyz/taiko-mono/commit/911c701ae738a9f2e12c14455c23951845d0c4c2))

### Bug Fixes

- **bridge-ui-v2:** fixing vercel build ([#14052](https://github.com/taikoxyz/taiko-mono/issues/14052)) ([3332e70](https://github.com/taikoxyz/taiko-mono/commit/3332e70bb3b821ab4efbcfe4aed4dbc3ed614850))
