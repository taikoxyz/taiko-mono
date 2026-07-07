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
- impl: `0x91Cf5766Fbc35bb1a2226DE5052C308a5EDd1d47`
- owner: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - deployed on Oct 20, 2025 at commit `2dfbeca`

### erc20_vault

- proxy: `0x0857cd029937E7a119e492434c71CB9a9Bb59aB0`
- impl: `0x0C74010473C066Cdd20BA32044D1f6E28527A725`
- owner: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - deployed on Oct 20, 2025 at commit `2dfbeca`

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

- impl: `0xcF954A2f0346e3aD0d0119989CEdB253D8c3428B`
- logs:
  - deployed on Oct 20, 2025 at commit `2dfbeca`

### bridged_erc721

- impl: `0x1f81E8503bf2Fe8F44053261ad5976C255455034`
- logs:
  - deployed on Oct 20, 2025 at commit `2dfbeca`

### bridged_erc1155

- impl: `0xd763f72F20F62f6368D6a20bdeaE8f4A325f83c1`
- logs:
  - deployed on Oct 20, 2025 at commit `2dfbeca`

### ShastaInbox

- proxy: `0xeF4bB7A442Bd68150A3aa61A6a097B86b91700BF`
- impl: `0xaDeb8cF142991D2AE46e5Ab6BE3172979fE6D10F`
- owner: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - deployed on Feb 2, 2026 at commit `392bfa0`
  - upgraded on Feb 4, 2026 at commit `a01f51c`

### preconf_whitelist

- proxy : `0x8B969Fcf37122bC5eCB4E0e5Ad65CEEC3f1393ba`
- impl : `0xeB614BE0Fe964A26B71D8CC02F9D7876352d7d15`
- owner : `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- ejectors:
- operators:
  - taiko nethermind proposer `0x75141CD01F50A17a915d59D245aE6B2c947D37d9`(sequencer `0x75141CD01F50A17a915d59D245aE6B2c947D37d9`)
  - taiko chainbound proposer `0x205a600D515091b473b6c1A8477D967533D10749`(sequencer `0x205a600D515091b473b6c1A8477D967533D10749`)
  - taiko gattaca proposer `0x445179507C3b0B84ccA739398966236a35ad8Ea1`(sequencer `0x445179507C3b0B84ccA739398966236a35ad8Ea1`)
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

### mainnet_verifier

- impl : `0x145d0f2140ab6d662217c59641d535cbc21f30f9`
- note: immutable; the ShastaInbox (`0xeF4bB7A442Bd68150A3aa61A6a097B86b91700BF`) proof verifier — composes the sgx/risc0/sp1 verifiers below
- logs:
  - deployed on Feb 2, 2026 @tx`0x6d5d9eb6e4c40fa68555d9250049e708c5373d42f1cb12514d7db340c0e97d41`

### sgx_verifier_reth

- impl : `0x40CcAFC1C2D14bdD70984b221F2b49af5e7C6114`
- owner : `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - deployed on Feb 2, 2026 @tx`0xa7bdd35b6a68b3bff4c07ed6ed82a44006bfb16138bd62d64681cb84d54fbb5e`

### sgx_verifier_geth

- impl : `0x8e362ef5140B0b9BE4a1141b6367784b0A7cefB1`
- owner : `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - deployed on Feb 2, 2026 @tx`0xdf988ad004c423d2e34a75fe34b2268c2c4867bd132d4cf4151df44960cb1ad8`

### risc0_verifier

- impl : `0xfa0e7dAFe9785627df034c123A9B87497EB06b41`
- owner : `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - deployed on Feb 2, 2026 @tx`0xa36c84d44a16783cd272b077ee49f44bb97272da6a2ad3af7e8d3978d07659bb`

### sp1_verifier

- impl : `0xc42Ef1A7A606162e144F696A07A7D3Ad98bF4EE7`
- owner : `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - deployed on Feb 2, 2026 @tx`0x34fe3c84aab9278128cca65e7b32ef608fc2a0262e79704eed5caa36101caf2a`

- HorseToken: 0x0a5Db5597ADC81c871Ebd89e81cfa07bDc8fAfE3
- BullToken: 0xB7A4DE1200eaA20af19e4998281117497645ecC1

## L2 Contracts

### delegate_controller

- proxy: `0xF7176c3aC622be8bab1B839b113230396E6877ab`
- impl: `0xEe9E92E8C237B22c8bddA6FBfeFe941876d21887`
- owner: `0xF7176c3aC622be8bab1B839b113230396E6877ab`

### bridge

- proxy: `0x1670130000000000000000000000000000000001`
- impl: `0x237506C97895771Ae3177dF31FC40D27c99fD382`
- owner: `0xF7176c3aC622be8bab1B839b113230396E6877ab`
- logs:
  - transferred ownership to `0xF7176c3aC622be8bab1B839b113230396E6877ab` on Nov 26, 2025
  - upgraded on Feb 27, 2026 at commit `a8a3a06`

### erc20_vault

- proxy: `0x1670130000000000000000000000000000000002`
- impl: `0x87b43DB6B631F51EE80D098F2c07b7CE5667e0D1`
- owner: `0xF7176c3aC622be8bab1B839b113230396E6877ab`
- logs:
  - transferred ownership to `0xF7176c3aC622be8bab1B839b113230396E6877ab` on Nov 26, 2025
  - updated on Feb 13, 2026 at commit `22ef025`

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

### rollup_resolver

- proxy: `0x1670130000000000000000000000000000010002`
- impl: `0x0167013000000000000000000000000000010002`
- owner: `0xF7176c3aC622be8bab1B839b113230396E6877ab`
- logs:
  - transferred ownership to `0xF7176c3aC622be8bab1B839b113230396E6877ab` on Nov 26, 2025

### bridged_erc20

- impl: `0x0167013000000000000000000000000000010096`
- logs:

### bridged_erc721

- impl: `0x0167013000000000000000000000000000010097`
- logs:

### bridged_erc1155

- impl: `0x0167013000000000000000000000000000010098`
- logs:
