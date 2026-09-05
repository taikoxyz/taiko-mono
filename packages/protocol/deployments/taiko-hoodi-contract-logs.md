# Taiko Hoodi network Contract Logs

## Notes

1. Code used on Taiko Hoodi must correspond to a commit on the main branch of the official repo: https://github.com/taikoxyz/taiko-mono.

## L1 Contracts

### shared_resolver

- proxy: `0x7bbacc9FFd29442DF3173b7685560fCE96E01b62`
- impl: `0xB2eAdD09D28bB9b21a3b31d6106d547989A333A0`
- owner: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - deployed on Oct 20, 2025 at commit `2dfbeca`

### taiko_token

- proxy: `0xf3b83e226202ECf7E7bb2419a4C6e3eC99e963DA`
- impl: `0x791a16ed5D4728CAEC441DDDa38f1A2991349b6c`
- owner: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - deployed on Oct 20, 2025 at commit `2dfbeca`

### signal_service

- proxy: `0x4c70b7F5E153D497faFa0476575903F9299ed811`
- impl: `0x2D0DF6900fBe181bE5246268Aafd1ecb6c4C8B35`
- owner: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - deployed on Oct 20, 2025 at commit `2dfbeca`
  - upgraded on Feb 4, 2026 at commit `a01f51c`
  - upgraded on Mar 4, 2026 at commit `a01f51c`

### bridge

- proxy: `0x6a4cf607DaC2C4784B7D934Bcb3AD7F2ED18Ed80`
- impl: `0x865acC241162575f887a0f926436a75a34ef5291`
- owner: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - deployed on Oct 20, 2025 at commit `2dfbeca`
  - upgraded on Sep 3, 2026 at commit `dd6aad6`

### erc20_vault

- proxy: `0x0857cd029937E7a119e492434c71CB9a9Bb59aB0`
- impl: `0x4E385c0D2D285a790Af70786ED138E6e667719ea`
- owner: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - deployed on Oct 20, 2025 at commit `2dfbeca`
  - upgraded on Sep 3, 2026 at commit `dd6aad6`

### erc721_vault

- proxy: `0x4876e7993dD40C22526c8B01F2D52AD8FdbdF768`
- impl: `0xd2751F9E5374a027E99E7a161d00cf220AD06312`
- owner: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - deployed on Oct 20, 2025 at commit `2dfbeca`

### erc1155_vault

- proxy: `0x81Ff6CcE1e5cFd6ebE83922F5A9608d1752C92c6`
- impl: `0x2288051cac7d137De4e571f45be6cBeF165D4293`
- owner: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - deployed on Oct 20, 2025 at commit `2dfbeca`

### bridged_erc20

- impl: `0xC56b5528C7A26E39ea61c4D7A6BeE65ffc9459e1`
- logs:
  - deployed on Oct 20, 2025 at commit `2dfbeca`
  - deployed BridgedERC20V2 `0xC56b5528C7A26E39ea61c4D7A6BeE65ffc9459e1` on Sep 3, 2026 at commit `dd6aad6` and registered it as `bridged_erc20`

### bridged_erc721

- impl: `0x1f81E8503bf2Fe8F44053261ad5976C255455034`
- logs:
  - deployed on Oct 20, 2025 at commit `2dfbeca`

### bridged_erc1155

- impl: `0xd763f72F20F62f6368D6a20bdeaE8f4A325f83c1`
- logs:
  - deployed on Oct 20, 2025 at commit `2dfbeca`

### inbox

- proxy: `0xeF4bB7A442Bd68150A3aa61A6a097B86b91700BF`
- impl: `0xB401C28719D45CfD40b423c786059d1B8dD0AA86`
- owner: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - deployed on Feb 2, 2026 at commit `392bfa0`
  - upgraded on Feb 4, 2026 at commit `a01f51c`
  - upgraded on Jul 9, 2026 at commit `a01f51c`

### preconf_whitelist

- proxy : `0x8B969Fcf37122bC5eCB4E0e5Ad65CEEC3f1393ba`
- impl : `0xeB614BE0Fe964A26B71D8CC02F9D7876352d7d15`
- owner : `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - deployed on Oct 20, 2025 at commit `2dfbeca`
  - upgraded on Feb 5, 2026 at commit `99429e4`

### prover_whitelist

- proxy : `0xa9a84b6667A2c60BFdE8c239918d0d9a11c77E89`
- impl : `0x8bc913253BbB2EcCAf1F74C35cdeb4F5Eebe3785`
- owner : `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- provers:
  - taiko prover `0x7B399987D24FC5951f3E94A4cb16E87414bF2229`
- logs:
  - deployed on Feb 2, 2026 at commit `392bfa0`

## L2 Contracts

### delegate_controller

- proxy: `0xF7176c3aC622be8bab1B839b113230396E6877ab`
- impl: `0xEe9E92E8C237B22c8bddA6FBfeFe941876d21887`
- owner: `0xF7176c3aC622be8bab1B839b113230396E6877ab`

### bridge

- proxy: `0x1670130000000000000000000000000000000001`
- impl: `0x0B5B11A78aB89F1465c72D959e630138fD416047`
- owner: `0xF7176c3aC622be8bab1B839b113230396E6877ab`
- logs:
  - transferred ownership to `0xF7176c3aC622be8bab1B839b113230396E6877ab` on Nov 26, 2025
  - upgraded on Feb 27, 2026 at commit `a8a3a06`
  - upgraded on Sep 3, 2026 at commit `dd6aad6`

### erc20_vault

- proxy: `0x1670130000000000000000000000000000000002`
- impl: `0x9F147D8E70685E19119c33Bda7c9FBF59eCb75F3`
- owner: `0xF7176c3aC622be8bab1B839b113230396E6877ab`
- logs:
  - transferred ownership to `0xF7176c3aC622be8bab1B839b113230396E6877ab` on Nov 26, 2025
  - updated on Feb 13, 2026 at commit `22ef025`
  - upgraded on Sep 3, 2026 at commit `dd6aad6`

### erc721_vault

- proxy: `0x1670130000000000000000000000000000000003`
- impl: `0x0167013000000000000000000000000000000003`
- owner: `0xF7176c3aC622be8bab1B839b113230396E6877ab`
- logs:
  - transferred ownership to `0xF7176c3aC622be8bab1B839b113230396E6877ab` on Nov 26, 2025

### erc1155_vault

- proxy: `0x1670130000000000000000000000000000000004`
- impl: `0x0167013000000000000000000000000000000004`
- owner: `0xF7176c3aC622be8bab1B839b113230396E6877ab`
- logs:
  - transferred ownership to `0xF7176c3aC622be8bab1B839b113230396E6877ab` on Nov 26, 2025

### signal_service

- proxy: `0x1670130000000000000000000000000000000005`
- impl: `0x22efa1915629712320C60E90E44CD412F0Ee98FE`
- owner: `0xF7176c3aC622be8bab1B839b113230396E6877ab`
- logs:
  - transferred ownership to `0xF7176c3aC622be8bab1B839b113230396E6877ab` on Nov 26, 2025
  - upgraded on Feb 4, 2026 at commit `a01f51c`
  - upgraded on Mar 2, 2026 at commit `a01f51c`

### shared_resolver

- proxy: `0x1670130000000000000000000000000000000006`
- impl: `0x0167013000000000000000000000000000000006`
- owner: `0xF7176c3aC622be8bab1B839b113230396E6877ab`
- logs:
  - transferred ownership to `0xF7176c3aC622be8bab1B839b113230396E6877ab` on Nov 26, 2025

### taiko_anchor

- proxy: `0x1670130000000000000000000000000000010001`
- impl: `0x70A65dDf64960b9901Df488825c1CBFBc9AE9685`
- owner: `0xF7176c3aC622be8bab1B839b113230396E6877ab`
- logs:
  - transferred ownership to `0xF7176c3aC622be8bab1B839b113230396E6877ab` on Nov 26, 2025
  - updated on Dec 19, 2025 at commit `7492388`
  - upgraded on Feb 4, 2026 at commit `a01f51c`
  - upgraded on Mar 2, 2026 at commit `a01f51c`

### bridged_erc20

- impl: `0xD7B40cff2Cd1f746246c50091653F1179e6Cd500`
- logs:
  - deployed BridgedERC20V2 `0xD7B40cff2Cd1f746246c50091653F1179e6Cd500` on Sep 3, 2026 at commit `dd6aad6` and registered it as `bridged_erc20`

### bridged_erc721

- impl: `0x0167013000000000000000000000000000010097`
- logs:

### bridged_erc1155

- impl: `0x0167013000000000000000000000000000010098`
- logs:
