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
  - signal_service@1: `0x0000000000000000000000000000000000000000` ???
  - bridge: `0x1670000000000000000000000000000000000001`
  - bridge@1: `0x0000000000000000000000000000000000000000`???
  - erc20_vault: `0x1670000000000000000000000000000000000002`
  - erc20_vault@1: `0x0000000000000000000000000000000000000000`???
  - erc721_vault: `0x1670000000000000000000000000000000000003`
  - erc721_vault@1: `0x0000000000000000000000000000000000000000`???
  - erc1155_vault: `0x1670000000000000000000000000000000000004`
  - erc1155_vault@1: `0x0000000000000000000000000000000000000000`???
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

## Other EOAs/Contracts

- `davidcai.eth`:`0x56706F118e42AE069F20c5636141B844D1324AE1`
- `admin.taiko.eth`: `0x9CBeE534B5D8a6280e01a14844Ee8aF350399C7F`
- `labs.taiko.eth`: `0xB73b0FC4C0Cfc73cF6e034Af6f6b42Ebe6c8b49D`
