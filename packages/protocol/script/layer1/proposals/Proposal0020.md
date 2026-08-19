# PROPOSAL-0020: Rotate raiko2 Proving IDs to v0.8.0-rc1

## Executive Summary

This proposal rotates the trusted proving identifiers from the raiko2 v0.6.0 set enabled by
[`Proposal0019.s.sol`](./Proposal0019.s.sol) to the
[`raiko2 v0.8.0-rc1`](https://github.com/taikoxyz/raiko2/releases/tag/v0.8.0-rc1)
release set.

It executes **20 L1 actions** and **no L2 actions**:

- **Actions 1-4**: rotate RISC0 proposal and aggregation image IDs.
- **Actions 5-12**: rotate SP1 proposal and aggregation program vkeys.
- **Actions 13-18**: rotate SGX MRENCLAVE allowlists for SGX-geth, SGX-reth, and SGX-reth EDMM.
- **Actions 19-20**: delete the currently registered raiko2 v0.6.0 SGX instance ID `1` from both
  SGX verifiers.

The SGX MRSIGNER remains unchanged:
`0x48fa5bbad91d274735d238715913c8712a7505bb6d0dd832764bedb46d587013`.

## Scope

The proposal reuses the active verifier contracts:

| Component         | Address                                      |
| ----------------- | -------------------------------------------- |
| RISC0 verifier    | `0x059dAF31F571da48Ab4e74Ae12F64f907681Cd8b` |
| SP1 verifier      | `0x73A0Db393ef87ce781ac7957bE10D6628432100F` |
| SGX-geth verifier | `0x41e79EB4F03aBB5DF8716B759528dc5d8f6a84Ee` |
| SGX-reth verifier | `0x9D3C595BFf6Ff7D2b2CbdEcF94aD917eB2fCFFd8` |
| SGX-geth attester | `0x0ffa4A625ED9DB32B70F99180FD00759fc3e9261` |
| SGX-reth attester | `0x8d7C954960a36a7596d7eA4945dDf891967ca8A3` |

No verifier implementation is upgraded and no SGX ATTRIBUTES policy is changed in this proposal.

## ZK IDs

The old IDs are the raiko2 v0.6.0 values currently trusted by Proposal0019:

| Role                            | Old value disabled                                                   |
| ------------------------------- | -------------------------------------------------------------------- |
| RISC0 proposal image ID         | `0x5a818b4c7dc80e9ba85d55492c20c263c67238724e3982f76d15a158e501210b` |
| RISC0 aggregation image ID      | `0x9cfcc1b34a98853c3c5873a4d456726e528246f7f03a4ea35f27c2543aa6e7f0` |
| SP1 proposal vkey BN254         | `0x00ad090221a8fa0f09e1be7a53feb67be010f01310d4b2314a69d10152ee1ce0` |
| SP1 proposal vkey hash bytes    | `0x568481106a3e83c23c37cf4a3feb67be008780984352c8c514d3a20252ee1ce0` |
| SP1 aggregation vkey BN254      | `0x000b11691352e55fcf64f62620cefaa700161600093f2751032fe71ea912264d` |
| SP1 aggregation vkey hash bytes | `0x0588b48954b957f36c9ec4c40cefaa7000b0b00024fc9d44065fce3d2912264d` |

The new IDs come from `guest-digests-summary.json` in the raiko2 v0.8.0-rc1 release:

| Role                            | New value enabled                                                    |
| ------------------------------- | -------------------------------------------------------------------- |
| RISC0 proposal image ID         | `0xd6ab71c22201c23ef512b706f2e2d720f6da1b559fb76834aa9d4e35276f6e10` |
| RISC0 aggregation image ID      | `0xdd9b8abff96c409ae2418edfb51d893ea2bd10f4873a0226f17a6998c1afc1b7` |
| SP1 proposal vkey BN254         | `0x0025425c22e827507428a3d9c7b0f89635be5462f34bb6780563e3d6086be7c7` |
| SP1 proposal vkey hash bytes    | `0x12a12e113a09d41d05147b387b0f89632df2a3174d2ed9e00ac7c7ac086be7c7` |
| SP1 aggregation vkey BN254      | `0x0051ac1d9e8cfd4196e37f9cfefd08e9b0f7ce653bad4634cd1ee84b71ca3be6` |
| SP1 aggregation vkey hash bytes | `0x28d60ecf233f50655c6ff39f6fd08e9b07be73296eb518d31a3dd09671ca3be6` |

## SGX MRENCLAVEs

The old MRENCLAVEs are the raiko2 v0.6.0 values currently trusted by Proposal0019:

| Path          | Old value disabled                                                   |
| ------------- | -------------------------------------------------------------------- |
| SGX-geth      | `0x2d2216efbe9d8e80ba24b86606ccd5ce9faf11033d31ad9e5d3c5c89965c8a57` |
| SGX-reth      | `0x90c79e65d6d0f83d658ff96cd0ef1204438f20b406c93cf1d4fafa0cff29842e` |
| SGX-reth EDMM | `0x041cadb0541bf8249c368482172d218608f3693975b65f74beb2ed6f0044f951` |

The new MRENCLAVEs come from `tee-attestation-manifest-v0.8.0-rc1.json`:

| Path          | New value enabled                                                    | Release artifact             |
| ------------- | -------------------------------------------------------------------- | ---------------------------- |
| SGX-geth      | `0x5f7da556f3b75dcc71465030e1b7274e82df9e9120c0b3eaf5bb76246a514005` | `gaiko2-sgxgeth:v0.8.0-rc1`  |
| SGX-reth      | `0x3564b6a30089fcb3e2f69c19b22d23f84ce148387cd7a15f5c1df165b2ae5847` | `raiko2-sgx:v0.8.0-rc1`      |
| SGX-reth EDMM | `0xae2c7b92b2a71238226cb624ecd1171b66bf943cc372314affca0e6748ccecdf` | `raiko2-sgx:v0.8.0-rc1-edmm` |

The existing SGX verifiers currently have `nextInstanceId() == 2` on mainnet. Instance ID `0` was
deleted by Proposal0019, and ID `1` is the active v0.6.0 registration on both verifiers. This
proposal deletes ID `1` from both SGX verifiers, because the deployed instance registry does not
re-check MRENCLAVE trust at proof time.

## Action Order

1. `RISC0_RETH_VERIFIER.setImageIdTrusted(OLD_RISC0_PROPOSAL_IMAGE_ID, false)`
2. `RISC0_RETH_VERIFIER.setImageIdTrusted(OLD_RISC0_AGGREGATION_IMAGE_ID, false)`
3. `RISC0_RETH_VERIFIER.setImageIdTrusted(NEW_RISC0_PROPOSAL_IMAGE_ID, true)`
4. `RISC0_RETH_VERIFIER.setImageIdTrusted(NEW_RISC0_AGGREGATION_IMAGE_ID, true)`
5. `SP1_RETH_VERIFIER.setProgramTrusted(OLD_SP1_PROPOSAL_PROGRAM_VKEY_BN256, false)`
6. `SP1_RETH_VERIFIER.setProgramTrusted(OLD_SP1_PROPOSAL_PROGRAM_VKEY_HASH_BYTES, false)`
7. `SP1_RETH_VERIFIER.setProgramTrusted(OLD_SP1_AGGREGATION_PROGRAM_VKEY_BN256, false)`
8. `SP1_RETH_VERIFIER.setProgramTrusted(OLD_SP1_AGGREGATION_PROGRAM_VKEY_HASH_BYTES, false)`
9. `SP1_RETH_VERIFIER.setProgramTrusted(NEW_SP1_PROPOSAL_PROGRAM_VKEY_BN256, true)`
10. `SP1_RETH_VERIFIER.setProgramTrusted(NEW_SP1_PROPOSAL_PROGRAM_VKEY_HASH_BYTES, true)`
11. `SP1_RETH_VERIFIER.setProgramTrusted(NEW_SP1_AGGREGATION_PROGRAM_VKEY_BN256, true)`
12. `SP1_RETH_VERIFIER.setProgramTrusted(NEW_SP1_AGGREGATION_PROGRAM_VKEY_HASH_BYTES, true)`
13. `SGXGETH_ATTESTER.setMrEnclave(OLD_SGXGETH_MR_ENCLAVE, false)`
14. `SGXRETH_ATTESTER.setMrEnclave(OLD_SGXRETH_NON_EDMM_MR_ENCLAVE, false)`
15. `SGXRETH_ATTESTER.setMrEnclave(OLD_SGXRETH_EDMM_MR_ENCLAVE, false)`
16. `SGXGETH_ATTESTER.setMrEnclave(NEW_SGXGETH_MR_ENCLAVE, true)`
17. `SGXRETH_ATTESTER.setMrEnclave(NEW_SGXRETH_NON_EDMM_MR_ENCLAVE, true)`
18. `SGXRETH_ATTESTER.setMrEnclave(NEW_SGXRETH_EDMM_MR_ENCLAVE, true)`
19. `SGXGETH_VERIFIER.deleteInstances([1])`
20. `SGXRETH_VERIFIER.deleteInstances([1])`

## Verification

Regenerate the calldata:

```bash
cd packages/protocol
P=0020 pnpm proposal
```

Dryrun the L1 action bundle:

```bash
cd packages/protocol
P=0020 pnpm proposal:dryrun:l1
```

Before execution, confirm the old values still match the live mainnet state:

- v0.6.0 RISC0 image IDs return `true` from `isImageTrusted(bytes32)`.
- v0.6.0 SP1 program vkeys return `true` from `isProgramTrusted(bytes32)`.
- v0.6.0 SGX MRENCLAVEs return `true` from `trustedUserMrEnclave(bytes32)`.
- `nextInstanceId()` returns `2` on both SGX verifiers and instance ID `1` is the active v0.6.0
  instance.
