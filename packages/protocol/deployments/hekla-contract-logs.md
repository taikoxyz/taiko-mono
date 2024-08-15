# Taiko Hekla network Contract Logs

## Notes

1. Code used on Hekla must correspond to a commit on the main branch of the official repo: https://github.com/taikoxyz/taiko-mono.

## L1 Contracts

### shared_address_manager

- proxy: `0x7D3338FD5e654CAC5B10028088624CA1D64e74f7`
- impl: `0x27ef4e7b101e822Dd107FF14Ca2540e89cea8E3e`
- owner: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - upgraded on May 10, 2024 at commit `4903bec`
  - upgraded on Jun 10, 2024 at commit `d5965bb`
  - transfered ownership on Jul 8, 2024

### taiko_token

- proxy: `0x6490E12d480549D333499236fF2Ba6676C296011`
- impl: `0x01BB2fD6D80942CE95B43c1322530fe690F2bc0e`
- owner: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - deployed on Mar 29, 2024 at commit `b341a68d5`
  - upgraded on Jun 18, 2024, added `batchTransfer` method.
  - transfered ownership on Jul 8, 2024

### signal_service

- proxy: `0x6Fc2fe9D9dd0251ec5E0727e826Afbb0Db2CBe0D`
- impl: `0xE6371B30e500ff38ec809a652fdFE98174011B2D`
- owner: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - upgraded on May 10, 2024 at commit `4903bec`
  - upgraded on Jun 10, 2024 at commit `d5965bb`
  - transfered ownership on Jul 8, 2024

### bridge

- proxy: `0xA098b76a3Dd499D3F6D58D8AcCaFC8efBFd06807`
- impl: `0x339F4C5320a5C697EA10b4f35d546C330AB43d8D`
- owner: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - upgraded on May 10, 2024 at commit `4903bec`
  - upgraded on Jun 10, 2024 at commit `d5965bb`
  - transfered ownership on Jul 8, 2024

### erc20_vault

- proxy: `0x2259662ed5dE0E09943Abe701bc5f5a108eABBAa`
- impl: `0x1bf437b2f6e5959fe167210Ee2221ADa09a66846`
- owner: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - upgraded on May 10, 2024 at commit `4903bec`
  - upgraded on Jun 10, 2024 at commit `d5965bb`
  - transfered ownership on Jul 8, 2024

### erc721_vault

- proxy: `0x046b82D9010b534c716742BE98ac3FEf3f2EC99f`
- impl: `0x06467bab46598b887240044309A6ffE261A0E2e3`
- owner: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - upgraded on May 10, 2024 at commit `4903bec`
  - upgraded on Jun 10, 2024 at commit `d5965bb`
  - transfered ownership on Jul 8, 2024

### erc1155_vault

- proxy: `0x9Ae5945Ab34f6182F75E16B73e037421F341fEe3`
- impl: `0xBFCff65554d6e89A1aC280eE1E9f87764124B833`
- owner: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - upgraded on May 10, 2024 at commit `4903bec`
  - upgraded on Jun 10, 2024 at commit `d5965bb`
  - transfered ownership on Jul 8, 2024

### bridged_erc20

- impl: `0xe3661857941E4A711fa6b4Fc080bC5c5948a70f1`
- logs:
  - deployed on May 10, 2024 at commit `4903bec`
  - deployed on Jul 25, 2024 at commit `3d89d24`

### bridged_erc721

- impl: `0xbD832CAf65c8a73609EFd62E2A4FCB1292e4c9C1`
- logs:
  - deployed on May 10, 2024 at commit `4903bec`

### bridged_erc1155

- impl: `0x0B5B063dc89EcfCedf8aF570d82598F72a7dfF35`
- logs:
  - deployed on May 10, 2024 at commit `4903bec`

### rollup_address_manager

- proxy: `0x1F027871F286Cf4B7F898B21298E7B3e090a8403`
- impl: `0x68570e85Ca54bAE1B6f608d0929665146BA66B39`
- owner: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - upgraded on May 10, 2024 at commit `13ad99d`
  - upgraded on Jun 10, 2024 at commit `d5965bb`
  - transfered ownership on Jul 8, 2024

### taikoL1

- proxy: `0x79C9109b764609df928d16fC4a91e9081F7e87DB`
- impl: `0x67a3eBd5D313cB21b4Aab7099455f4dfCC11Af47.`
- owner: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - upgraded on May 10, 2024 at commit `4903bec`
  - upgraded on Jun 10, 2024 at [PR #17532](https://github.com/taikoxyz/taiko-mono/pull/17532)
  - upgraded on Jun 12, 2024 at commit `07b073d`
  - upgraded on Jun 12, 2024 at [PR #17553](https://github.com/taikoxyz/taiko-mono/pull/17553)
  - upgraded on Jun 14, 2024 at [PR #17553](https://github.com/taikoxyz/taiko-mono/pull/17553) @commit `baed5b5`
  - upgraded on Jun 19, 2024 at commit `b7e12e3`
  - upgraded on Jun 20, 2024 at commit `6e07ab5`
  - transfered ownership on Jul 8, 2024
  - upgraded on Jul 11, 2024 at [PR #17779](https://github.com/taikoxyz/taiko-mono/pull/17779)
  - upgraded on Jul 15, 2024 at commit `45281b8`

### assignmentHook

- proxy: `0x9e640a6aadf4f664CF467B795c31332f44AcBe6c`
- impl: `0xfcb5B945dbd08AfdB08e6C358193B23b0E6eFa23`
- owner: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - upgraded on May 10, 2024 at commit `4903bec`
  - upgraded on Jun 12, 2024 at commit `04bb81e`
  - transfered ownership on Jul 8, 2024

### tierProvider

- impl: `0xDDfaA6F5E9ed78229660953439958636C9e26A34.`
- logs:
  - upgraded on May 14, 2024 at commit `0ef7b8caa`
  - upgraded on Jun 14, 2024 at commit `cc10b04`
  - upgraded on Jun 19, 2024 at commit `b7e12e3`

### tierRouter

- impl: `0x18277Dfb30309360Fd4B8FbdD48283D1C71BDB65.`
- logs:
  - deployed on Jun 10, 2024 at commit `d5965bb`
  - upgraded on Jun 14, 2024 at commit `cc10b04`
  - upgraded on Jun 19, 2024 at commit `b7e12e3`

### prover_set

- proxy: `0xD3f681bD6B49887A48cC9C9953720903967E9DC0`
- impl: `0x4ABc9874bca5bc33cB62396754BdcC5811D98fcd.`
- owner: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - deployed on Jun 17, 2024 at commit `b7e12e3`
  - upgraded on Jul 11, 2024 at commit `30631a9`

### prover_set_contester

- proxy: `0x335103c4fa2F55451975082136F1478eCFeB84B9`
- impl: `0x4ABc9874bca5bc33cB62396754BdcC5811D98fcd.`
- owner: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - deployed on Jun 21, 2024 at commit `099ce22`
  - upgraded on Jul 11, 2024 at commit `30631a9`

### guardian_prover

- proxy: `0x92F195a8702da2104aE8E3E10779176E7C35d6BC`
- impl: `0x23bDb18995266c1Ac4c1BDBF69aE977A2DCE0750`
- owner: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - upgraded on May 10, 2024 at commit `4903bec`
  - upgraded on Jun 10, 2024 at commit `d5965bb`
  - transfered ownership on Jul 8, 2024

### guardian_minority

- proxy: `0x31d4d27da5c299d4b6CE19c869B8891C0002795d`
- impl: `0x7eA0a9d62cF26Bd81D62AEf6D6D67a86A580aFA3`
- owner: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - deployed on May 20, 2024 at commit `6e56475`
  - upgraded on Jun 10, 2024 at commit `d5965bb`
  - transfered ownership on Jul 8, 2024

### risc0_groth16_verifier

- addr : 0xc2c2676E31b59085dfDA9b1B066519b20e756D9d
- logs:
  - deployed on August 14, 2024 at commit `cba2a1e`

### tier_zkvm_risc0

- proxy : 0x4fEd801C5a876D4289e869cbEfA1E1A448b10714
- impl : 0x33BD79aA6a24d8ED4413E01FEc546D4d49bF6C39
- owner : 0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190
- logs:
  - deployed on August 14, 2024 at commit `cba2a1e`

## L2 Contracts

### bridge

- proxy: `0x1670090000000000000000000000000000000001`
- impl: `0xD981DaF607bb6D4249f943d1b13a9AE071E8E3B4`
- owner: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - upgraded on May 10, 2024 at commit `4903bec`
  - upgraded on Jun 10, 2024 at commit `d5965bb`

### erc20_vault

- proxy: `0x1670090000000000000000000000000000000002`
- impl: `0x18D098279287b3e72A9BC5c6CCfa05475567Ee32`
- owner: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - upgraded on May 10, 2024 at commit `4903bec`
  - upgraded on Jun 10, 2024 at commit `d5965bb`

### erc721_vault

- proxy: `0x1670090000000000000000000000000000000003`
- impl: `0x7bbacc9FFd29442DF3173b7685560fCE96E01b62`
- owner: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - upgraded on May 10, 2024 at commit `4903bec`
  - upgraded on Jun 10, 2024 at commit `d5965bb`

### erc1155_vault

- proxy: `0x1670090000000000000000000000000000000004`
- impl: `0xEEF23D0aa5d19Ba17A652d98378c670b9A3aD30A`
- owner: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - upgraded on May 10, 2024 at commit `4903bec`
  - upgraded on Jun 10, 2024 at commit `d5965bb`

### signal_service

- proxy: `0x1670090000000000000000000000000000000005`
- impl: `0x4c70b7F5E153D497faFa0476575903F9299ed811`
- owner: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - upgraded on May 10, 2024 at commit `4903bec`
  - upgraded on Jun 10, 2024 at commit `d5965bb`

### shared_address_manager

- proxy: `0x1670090000000000000000000000000000000006`
- impl: `0x91Cf5766Fbc35bb1a2226DE5052C308a5EDd1d47`
- owner: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - upgraded on May 10, 2024 at commit `4903bec`
  - upgraded on Jun 10, 2024 at commit `d5965bb`

### taikoL2

- proxy: `0x1670090000000000000000000000000000010001`
- impl: `0x0C74010473C066Cdd20BA32044D1f6E28527A725`
- owner: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - upgraded on May 10, 2024 at commit `4903bec`
  - upgraded on Jun 10, 2024 at commit `d5965bb`

### rollup_address_manager

- proxy: `0x1670090000000000000000000000000000010002`
- impl: `0xd41f03dF5f46a0686807d9DBDd94a1223FC73AEe`
- owner: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - upgraded on May 10, 2024 at commit `4903bec`
  - upgraded on Jun 10, 2024 at commit `d5965bb`

### bridged_erc20

- impl: `0xBF040d7C27cddFE9b4a91ebD79a4dc94e5bec677`
- logs:
  - deployed on May 10, 2024 at commit `4903bec`
  - deployed on Jul 25, 2024 at commit `3d89d24`

### bridged_erc721

- impl: `0x45327BDbe23c1a3F0b437C78a19E813f9b11E566`
- logs:
  - deployed on May 10, 2024 at commit `4903bec`

### bridged_erc1155

- impl: `0xb190786090Fc4308c4C40808f3bEB55c4463c152`
- logs:
  - deployed on May 10, 2024 at commit `4903bec`

### delegate_owner

- proxy: `0x95F6077C7786a58FA070D98043b16DF2B1593D2b`
- impl: `0x36dD2d50C08Ee22553ef34583B367D86c3D44fBd`
- owner: `0x95F6077C7786a58FA070D98043b16DF2B1593D2b`
- admin: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - deployed on Aug 15, 2024 at commit `46a3e00`
