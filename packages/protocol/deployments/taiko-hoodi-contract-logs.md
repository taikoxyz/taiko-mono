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
- impl: `0x9403EdED7bF886F49025Eb65AAba56E04aFF5243`
- owner: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - deployed on Oct 20, 2025 at commit `2dfbeca`
  - upgraded on Feb 3, 2026 at commit `392bfa0` (will do)

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

### rollup_address_resolver

- proxy: `0x0d006d8d394dD69fAfEfF62D21Fc03E7F50eDaF4`
- impl: `0x977836Ff9A19a930ebBc174226eF2fF990088eAB`
- owner: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - deployed on Oct 20, 2025 at commit `2dfbeca`

### PacayaInbox

- proxy: `0xf6eA848c7d7aC83de84db45Ae28EAbf377fe0eF9`
- impl: `0x28dA65D1B6ceFab4BF9Fb7f7C5438604d438552C`
- owner: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - deployed on Oct 20, 2025 at commit `2dfbeca`
  - updated on Oct 20, 2025 at commit `520ed22`
  - updated on Dec 3, 2025 at commit ``

### ShastaInbox
- proxy: `0xeF4bB7A442Bd68150A3aa61A6a097B86b91700BF`
- impl: `0x2f3090807e76D613f8F2b92d4793e678Dd19Ae23`
- owner: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - deployed on Feb 2, 2026 at commit `392bfa0`

### forced_inclusion_store

- proxy : `0xA7F175Aff7C62854d0A0498a0da17b66A9D452D0`
- impl : `0x49d661f2c0c3Ba054a9e756AA4FD55983c58Ac48`
- owner : `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - deployed on Oct 20, 2025 at commit `2dfbeca`

### preconf_whitelist

- proxy : `0x8B969Fcf37122bC5eCB4E0e5Ad65CEEC3f1393ba`
- impl : `0xF7DC03615231C4219F6AE4B78884a63fB37Df9Fc`
- owner : `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- ejectors:
- operators:
  - taiko nethermind proposer `0x75141CD01F50A17a915d59D245aE6B2c947D37d9`(sequencer `0x75141CD01F50A17a915d59D245aE6B2c947D37d9`)
  - taiko chainbound proposer `0x205a600D515091b473b6c1A8477D967533D10749`(sequencer `0x205a600D515091b473b6c1A8477D967533D10749`)
  - taiko gattaca proposer `0x445179507C3b0B84ccA739398966236a35ad8Ea1`(sequencer `0x445179507C3b0B84ccA739398966236a35ad8Ea1`)
- logs:
  - deployed on Oct 20, 2025 at commit `2dfbeca`
  - upgraded on Feb 3, 2026 at commit `392bfa0` (will do)

### prover_whitelist

- proxy : `0xa9a84b6667A2c60BFdE8c239918d0d9a11c77E89`
- impl : `0x8bc913253BbB2EcCAf1F74C35cdeb4F5Eebe3785`
- owner : `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- provers:
  - taiko prover `0x7B399987D24FC5951f3E94A4cb16E87414bF2229`
- logs:
  - deployed on Feb 2, 2026 at commit `392bfa0`

### preconf_router

- proxy : `0xCD15bdEc91BbD45E56D81b4b76d4f97f5a84e555`
- impl : `0x8ab91D91c80e923280D866c447a7B993b017A8B2`
- owner : `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - deployed on Oct 20, 2025 at commit `2dfbeca`
  - upgraded on Oct 20, 2025 at commit `7217552`

### taiko_wrapper

- proxy : `0xB843132A26C13D751470a6bAf5F926EbF5d0E4b8`
- impl : `0xa3d20eab2922E85ce7Ef2De66249F5dbDB039527`
- owner : `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - deployed on Oct 20, 2025 at commit `2dfbeca`

### proof_verifier(Pacaya)

- proxy : `0xd9F11261AE4B873bE0f09D0Fc41d2E3F70CD8C59`
- impl : `0xbE3CA2aF1bc74b22E96799e998E0a19f8A40bcbC`
- owner : `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - deployed on Oct 20, 2025 at commit `2dfbeca`
  - updated on Oct 20, 2025 at commit `7217552`

### sgx_reth_verifier(Pacaya)

- proxy : `0xd46c13B67396cD1e74Bb40e298fbABeA7DC01f11`
- impl : `0xD35d8408A50b5F9002f53BFeEFcA053d333d35BA`
- owner : `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - deployed on Oct 20, 2025 at commit `2dfbeca`
  - updated on Oct 20, 2025 at commit `520ed22`

### risc0_reth_verifier(Pacaya)

- proxy : `0xbf285Dd2FD56BF4893D207Fba4c738D1029edFfd`
- impl : `0xF0BabD64159D3A711bC0A412B9DfCd7d08d8FF75`
- owner : `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - deployed on Oct 20, 2025 at commit `2dfbeca`
  - updated on Oct 20, 2025 at commit `7217552`

### sp1_reth_verifier(Pacaya)

- proxy : `0x3B3bb4A1Cb8B1A0D65F96a5A93415375C039Eda3`
- impl : `0x801dcb74ed6c45764c91b9e818ec204b41eada9b`
- owner : `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - deployed on Oct 20, 2025 at commit `2dfbeca`
  - updated on Oct 20, 2025 at commit `7217552`

### sgx_geth_verifier(Pacaya)

- proxy : `0xCdBB6C1751413e78a40735b6D9Aaa7D55e8c038e`
- impl : `0xD6b1EF918E6d31749424806b65D126C237774970`
- owner : `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - deployed on Oct 20, 2025 at commit `2dfbeca`
  - updated on Oct 20, 2025 at commit `520ed22`

- HorseToken: 0x0a5Db5597ADC81c871Ebd89e81cfa07bDc8fAfE3
- BullToken: 0xB7A4DE1200eaA20af19e4998281117497645ecC1

## L2 Contracts

### delegate_controller

- proxy: `0xF7176c3aC622be8bab1B839b113230396E6877ab`
- impl: `0xEe9E92E8C237B22c8bddA6FBfeFe941876d21887`
- owner: `0xF7176c3aC622be8bab1B839b113230396E6877ab`

### bridge

- proxy: `0x1670130000000000000000000000000000000001`
- impl: `0x0167013000000000000000000000000000000001`
- owner: `0xF7176c3aC622be8bab1B839b113230396E6877ab`
- logs:
  - transferred ownership to `0xF7176c3aC622be8bab1B839b113230396E6877ab` on Nov 26, 2025

### erc20_vault

- proxy: `0x1670130000000000000000000000000000000002`
- impl: `0x0167013000000000000000000000000000000002`
- owner: `0xF7176c3aC622be8bab1B839b113230396E6877ab`
- logs:
  - transferred ownership to `0xF7176c3aC622be8bab1B839b113230396E6877ab` on Nov 26, 2025

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
- impl: `0x0167013000000000000000000000000000000005`
- owner: `0xF7176c3aC622be8bab1B839b113230396E6877ab`
- logs:
  - transferred ownership to `0xF7176c3aC622be8bab1B839b113230396E6877ab` on Nov 26, 2025

### shared_resolver

- proxy: `0x1670130000000000000000000000000000000006`
- impl: `0x0167013000000000000000000000000000000006`
- owner: `0xF7176c3aC622be8bab1B839b113230396E6877ab`
- logs:
  - transferred ownership to `0xF7176c3aC622be8bab1B839b113230396E6877ab` on Nov 26, 2025

### taiko_anchor

- proxy: `0x1670130000000000000000000000000000010001`
- impl: `0x5E652dC4033C6860b27d6860164369D15b421A42`
- owner: `0xF7176c3aC622be8bab1B839b113230396E6877ab`
- logs:
  - transferred ownership to `0xF7176c3aC622be8bab1B839b113230396E6877ab` on Nov 26, 2025
  - updated on Dec 19, 2025 at commit `7492388`

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
