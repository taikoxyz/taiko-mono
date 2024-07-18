---
title: Testnet addresses
description: Network reference page describing various important addresses on Taiko.
---

## Ethereum L1 (Holesky) contracts

| Contract Name (Shared) | Address                                      |
| ---------------------- | -------------------------------------------- |
| SharedAddressManager   | `0x7D3338FD5e654CAC5B10028088624CA1D64e74f7` |
| TaikoToken             | `0x6490E12d480549D333499236fF2Ba6676C296011` |
| SignalService          | `0x6Fc2fe9D9dd0251ec5E0727e826Afbb0Db2CBe0D` |
| Bridge                 | `0xA098b76a3Dd499D3F6D58D8AcCaFC8efBFd06807` |
| ERC20Vault             | `0x2259662ed5dE0E09943Abe701bc5f5a108eABBAa` |
| ERC721Vault            | `0x046b82D9010b534c716742BE98ac3FEf3f2EC99f` |
| ERC1155Vault           | `0x9Ae5945Ab34f6182F75E16B73e037421F341fEe3` |

| Contract Name (Rollup-Specific) | Address                                      |
| ------------------------------- | -------------------------------------------- |
| TaikoL1                         | `0x79C9109b764609df928d16fC4a91e9081F7e87DB` |
| RollupAddressManager            | `0x1F027871F286Cf4B7F898B21298E7B3e090a8403` |
| GuardianProver                  | `0x92F195a8702da2104aE8E3E10779176E7C35d6BC` |
| AssignmentHook                  | `0x9e640a6aadf4f664CF467B795c31332f44AcBe6c` |
| SgxVerifier                     | `0x532EFBf6D62720D0B2a2Bb9d11066E8588cAE6D9` |
| AutomataDcapAttestation         | `0xC6cD3878Fc56F2b2BaB0769C580fc230A95e1398` |
| PemCertChainLib                 | `0x08d7865e7F534d743Aba5874A9AD04bcB223a92E` |

## Taiko L2 (Hekla) contracts

| Contract Name        | Address                                      |
| -------------------- | -------------------------------------------- |
| Bridge               | `0x1670090000000000000000000000000000000001` |
| ERC20Vault           | `0x1670090000000000000000000000000000000002` |
| ERC721Vault          | `0x1670090000000000000000000000000000000003` |
| ERC1155Vault         | `0x1670090000000000000000000000000000000004` |
| SignalService        | `0x1670090000000000000000000000000000000005` |
| SharedAddressManager | `0x1670090000000000000000000000000000000006` |
| TaikoL2              | `0x1670090000000000000000000000000000010001` |
| RollupAddressManager | `0x1670090000000000000000000000000000010002` |
| BridgedTaikoToken    | `0xebf1f662bf092ff0d913a9fe9d7179b0efef1611` |

## Contract owners

:::caution
The owner has the ability to upgrade the contracts.
:::

| Network               | Address                                      | ENS |
| --------------------- | -------------------------------------------- | --- |
| Ethereum L1 (Holesky) | `0x13cfc60c900a927C48f5c2a4923Ec9771a3A2805` | N/A |
| Taiko L2 (Hekla)      | `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190` | N/A |

## Taiko Labs' proposer and prover addresses

| Name                                                   | Address                                      |
| ------------------------------------------------------ | -------------------------------------------- |
| Proposer #1                                            | `0xEd1bA0Ba5661D648c7b3988DAC473F60403aff1e` |
| Prover #1                                              | `0x7B399987D24FC5951f3E94A4cb16E87414bF2229` |
| Prover #2 (with `--prover.proveUnassignedBlocks` flag) | `0x8Adb8C4d5214309612b53845E07C3Cb5BB4E8CF0` |

## Taiko Labs' bootnode addresses

Find the latest bootnodes here in [simple-taiko-node](https://github.com/taikoxyz/simple-taiko-node/blob/main/.env.sample).
