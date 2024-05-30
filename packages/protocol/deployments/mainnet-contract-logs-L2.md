# Taiko Mainnet Contract Logs - L2

## Notes

1. Code used on mainnet must correspond to a commit on the main branch of the official repo: https://github.com/taikoxyz/taiko-mono.

## Shared

#### shared_address_manager (sam)

- proxy: `0x1670000000000000000000000000000000000006`
- impl: `0x0167000000000000000000000000000000000006`
- owner: `0xf8ff2AF0DC1D5BA4811f22aCb02936A1529fd2Be`
- names:
  - signal_service: `0x1670000000000000000000000000000000000005`
  - signal_service@1: `0x9e0a24964e5397B566c1ed39258e21aB5E35C77C`
  - bridge: `0x1670000000000000000000000000000000000001`
  - bridge@1: `0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC`
  - erc20_vault: `0x1670000000000000000000000000000000000002`
  - erc20_vault@1: `0x996282cA11E5DEb6B5D122CC3B9A1FcAAD4415Ab`
  - erc721_vault: `0x1670000000000000000000000000000000000003`
  - erc721_vault@1: `0x0b470dd3A0e1C41228856Fb319649E7c08f419Aa`
  - erc1155_vault: `0x1670000000000000000000000000000000000004`
  - erc1155_vault@1: `0xaf145913EA4a56BE22E120ED9C24589659881702`
  - bridged_erc20: `0x0167000000000000000000000000000000010096`
  - bridged_erc721: `0x0167000000000000000000000000000000010097`
  - bridged_erc1155: `0x0167000000000000000000000000000000010098`
  - quota_manager: `0x0000000000000000000000000000000000000000`
  - bridge_watchdog: `0x0000000000000000000000000000000000000000`
- todo:
  - change owner to DelegateOwner
- logs:
  - deployed on May 1, 2024 @commit `56dddf2b6`
  - redeployed on May 22, 2024 @commit `b955e0e`
  - set signal_service@1 to `0x9e0a24964e5397B566c1ed39258e21aB5E35C77C` @tx`0xc50b269f961973eafc2e39d4c668efa3f7457632940a2dc74fb627d6feba0680`
  - set bridge@1 to `0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC` @tx`0xca295b7251c1e812e4d07145f061f18ccee62c6c4ee175483ec9f134c537a6e8`
  - set erc20_vault@1 to `0x996282cA11E5DEb6B5D122CC3B9A1FcAAD4415Ab` @tx`0x82e4550eadd0d255ab930ef2257d9b8eedf1cec0198eea628661d2a3e1d0c503`
  - set erc721_vault@1 to `0x0b470dd3A0e1C41228856Fb319649E7c08f419Aa` @tx`0x3b836123cd6073aff8d441ebf38b9133ba553c4625eb529811b855be67937d69`
  - set erc1155_vault@1 to `0xaf145913EA4a56BE22E120ED9C24589659881702` @tx`0x4a16a8a7d02f696b753208bbf8e7e3501d6b70b9a764fa2b4e115add46c13cb3`

#### bridge

- proxy: `0x1670000000000000000000000000000000000001`
- impl: `0x98C5De7670aA7d47C6c0551fAD27Bfe464A6751a.`
- owner: `0xf8ff2AF0DC1D5BA4811f22aCb02936A1529fd2Be`
- todo:
  - change owner to DelegateOwner
- logs:
  - deployed on May 1, 2024 @commit `56dddf2b6`
  - redeployed on May 22, 2024 @commit `b955e0e`
  - upgrade to `0xf961854D68368cFFc86d90AEe8a19E9781dACA3e` @tx`0x094dd9452d79cbd74711f2b8065566e4431a05d0727c56d2b38195e40fd62805`
  - upgraded from `0xf961854D68368cFFc86d90AEe8a19E9781dACA3e` to `0x98C5De7670aA7d47C6c0551fAD27Bfe464A6751a..` @commit`` in @tx`0x0b5d6acc9c5b8ef193920246081ec5ce7268111acfc1dce1f058bea06f3953c7`

#### erc20_vault

- proxy: `0x1670000000000000000000000000000000000002`
- impl: `0x33fBcde27fBA21e90582Df31DFB427D4dbdBefC1`
- owner: `0xf8ff2AF0DC1D5BA4811f22aCb02936A1529fd2Be`
- todo:
  - change owner to DelegateOwner
- logs:
  - deployed on May 1, 2024 @commit `56dddf2b6`
  - redeployed on May 22, 2024 @commit `b955e0e`
  - upgrade to `0x33fBcde27fBA21e90582Df31DFB427D4dbdBefC1` @tx`0x8a12626b2f2c9464b5f2525edc2010f371397ff12fe00cf49287a9b2a6b7ab99`
  - linked bridged TKO to `0xA9d23408b9bA935c230493c40C73824Df71A0975` @tx`0xe25d05320b95fbc3bffe0b7cbfe351dd5fa6413db307d5c28f7b70983567a43b`
  - linked bridged USDC to `0x07d83526730c7438048D55A4fc0b850e2aaB6f0b` @tx`0xf1752ac712779e9ae53d408abdc5eec70e63582433143d6d91a489a1e8fc4778`

#### erc721_vault

- proxy: `0x1670000000000000000000000000000000000003`
- impl: `0xD68BFe63E0f2983D89cbB225BEd068a8f19f5e08`
- owner: `0xf8ff2AF0DC1D5BA4811f22aCb02936A1529fd2Be`
- todo:
  - change owner to DelegateOwner
- logs:
  - deployed on May 1, 2024 @commit `56dddf2b6`
  - redeployed on May 22, 2024 @commit `b955e0e`
  - upgrade to `0xD68BFe63E0f2983D89cbB225BEd068a8f19f5e08` @`0x8705703a93cb4cfc1ae69d1277f4464f807c7615237f2b04ff010c6e45708d34`

#### erc1155_vault

- proxy: `0x1670000000000000000000000000000000000004`
- impl: `0x3918a2910C393A1A2EF7AAc807970EFE47A54b7e`
- owner: `0xf8ff2AF0DC1D5BA4811f22aCb02936A1529fd2Be`
- todo:
  - change owner to DelegateOwner
- logs:
  - deployed on May 1, 2024 @commit `56dddf2b6`
  - redeployed on May 22, 2024 @commit `b955e0e`
  - upgrade to `0x3918a2910C393A1A2EF7AAc807970EFE47A54b7e` @tx`0x264a2a553672a5480141638c3ca00a7bdf2c54e48c53f41867ca4f64703e16d7`

#### signal_service

- proxy: `0x1670000000000000000000000000000000000005`
- impl: `0x0167000000000000000000000000000000000005`
- owner: `0xf8ff2AF0DC1D5BA4811f22aCb02936A1529fd2Be`
- todo:
  - change owner to DelegateOwner
- logs:
  - deployed on May 1, 2024 @commit `56dddf2b6`
  - redeployed on May 22, 2024 @commit `b955e0e`

## Rollup Specific

#### rollup_address_manager (ram)

- proxy: `0x1670000000000000000000000000000000010002`
- impl: `0x0167000000000000000000000000000000010002`
- owner: `0xf8ff2AF0DC1D5BA4811f22aCb02936A1529fd2Be`
- names:
  - signal_service: `0x1670000000000000000000000000000000000005`
  - bridge: `0x1670000000000000000000000000000000000001`
  - taiko: `0x1670000000000000000000000000000000010001`
- todo:
  - change owner to DelegateOwner
- logs:
  - deployed on May 1, 2024 @commit `56dddf2b6`
  - redeployed on May 22, 2024 @commit `b955e0e`

#### taikoL2

- proxy: `0x1670000000000000000000000000000000010001`
- impl: `0x0167000000000000000000000000000000010001`
- owner: `0xf8ff2AF0DC1D5BA4811f22aCb02936A1529fd2Be`
- todo:
  - change owner to DelegateOwner
- logs:
  - deployed on May 1, 2024 @commit `56dddf2b6`
  - redeployed on May 22, 2024 @commit `b955e0e`

#### weth9

- impl: `0xA51894664A773981C6C112C43ce576f315d5b1B6`
- logs:
  - deployed on May 27, 2024 @tx`0x704bc67389b2abb316f98091627e980d27fc40e07aff9a869696886960c5d82b`

#### bridged_taiko_token

- proxy: `0xA9d23408b9bA935c230493c40C73824Df71A0975`
- impl: `0x473dBf07E06f5aE693F0c44b3ce7b5b8fA71d260`
- owner: `0xf8ff2AF0DC1D5BA4811f22aCb02936A1529fd2Be`
- logs:
  - deployed @tx`0x3e0c2c3f7593b8af888c2b8fe3af79152426bdf2d0529f058722ae08c80c8991`

#### bridged_usdc_token (native)

- proxy: `0x07d83526730c7438048D55A4fc0b850e2aaB6f0b`
- impl: `0x996a7A32C387Fd83e127A358fBc192e110459f2d`
- logs:
  - deployed @tx`0xbd87fc07b1accbce04174c479cf9af6bb9c50b7e4677ec7417c4c6b327c30d01`
  - set erc20_vault as a minter @tx`0x71cc56f3209b375f5734fb5041e425ce2ba445baa407e0a7019598f46b32993b`

## Other EOAs/Contracts

- safe-singleton-factory: `0x914d7Fec6aaC8cd542e72Bca78B30650d45643d7`
- multicall3: `0x174EB72C7d94a6D7dBAE3e4d20337B57088bB246`
- `davidcai.eth`:`0x56706F118e42AE069F20c5636141B844D1324AE1`
- `admin.taiko.eth`: `0x9CBeE534B5D8a6280e01a14844Ee8aF350399C7F`
- `labs.taiko.eth`: `0xB73b0FC4C0Cfc73cF6e034Af6f6b42Ebe6c8b49D`
