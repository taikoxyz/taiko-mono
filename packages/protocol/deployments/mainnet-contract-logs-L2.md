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
  - register TKO token to the bridged TKO token?
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
- impl: `0x0167000000000000000000000000000000000001`
- owner: `0xf8ff2AF0DC1D5BA4811f22aCb02936A1529fd2Be`
- todo:
  - change owner to DelegateOwner
- logs:
  - deployed on May 1, 2024 @commit `56dddf2b6`
  - redeployed on May 22, 2024 @commit `b955e0e`

#### erc20_vault

- proxy: `0x1670000000000000000000000000000000000002`
- impl: `0x0167000000000000000000000000000000000002`
- owner: `0xf8ff2AF0DC1D5BA4811f22aCb02936A1529fd2Be`
- todo:
  - change owner to DelegateOwner
- logs:
  - deployed on May 1, 2024 @commit `56dddf2b6`
  - redeployed on May 22, 2024 @commit `b955e0e`
  - linked bridged TKO to `0xA9d23408b9bA935c230493c40C73824Df71A0975` @tx`0xe25d05320b95fbc3bffe0b7cbfe351dd5fa6413db307d5c28f7b70983567a43b`

#### erc721_vault

- proxy: `0x1670000000000000000000000000000000000003`
- impl: `0x0167000000000000000000000000000000000003`
- owner: `0xf8ff2AF0DC1D5BA4811f22aCb02936A1529fd2Be`
- todo:
  - change owner to DelegateOwner
- logs:
  - deployed on May 1, 2024 @commit `56dddf2b6`
  - redeployed on May 22, 2024 @commit `b955e0e`

#### erc1155_vault

- proxy: `0x1670000000000000000000000000000000000004`
- impl: `0x0167000000000000000000000000000000000004`
- owner: `0xf8ff2AF0DC1D5BA4811f22aCb02936A1529fd2Be`
- todo:
  - change owner to DelegateOwner
- logs:
  - deployed on May 1, 2024 @commit `56dddf2b6`
  - redeployed on May 22, 2024 @commit `b955e0e`

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

#### bridged_taiko_token

- proxy: `0xA9d23408b9bA935c230493c40C73824Df71A0975`
- impl: `0x473dBf07E06f5aE693F0c44b3ce7b5b8fA71d260`
- owner: `0xf8ff2AF0DC1D5BA4811f22aCb02936A1529fd2Be`
- logs:
  - deployed @tx`0x3e0c2c3f7593b8af888c2b8fe3af79152426bdf2d0529f058722ae08c80c8991`

## Other EOAs/Contracts

- `davidcai.eth`:`0x56706F118e42AE069F20c5636141B844D1324AE1`
- `admin.taiko.eth`: `0x9CBeE534B5D8a6280e01a14844Ee8aF350399C7F`
- `labs.taiko.eth`: `0xB73b0FC4C0Cfc73cF6e034Af6f6b42Ebe6c8b49D`
