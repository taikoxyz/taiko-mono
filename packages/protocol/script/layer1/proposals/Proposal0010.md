# PROPOSAL-0010: Emergency Registration of Additional Shasta Verifier IDs

## Executive Summary

This proposal is an **emergency proposal** intended for the **Emergency Multisig** path, not the Standard Multisig path.

It additively registers a new set of RISC0/SP1 verifier IDs on the **Shasta verifiers only** on taiko mainnet, and additively registers new SGX `MR_ENCLAVE` hashes on the existing SGX attesters. The previously trusted values from [`Proposal0009.s.sol`](./Proposal0009.s.sol) remain enabled for now.

The goal is to unblock proving and finalization for the earliest Shasta mainnet proposals affected by the bootstrapping issue where the first 7 proposals had reverted anchor transactions.

The prover binaries and image build used for this emergency change come from the Raiko **hotfix** branch `hotfix/hotfix-based-on-1.16.1` (based on v1.16.1), **not** from a semver release tag.

## Rationale

The first seven Shasta proposals on taiko mainnet encountered reverted `anchorV4()` transactions during bootstrapping. Companion client/prover changes handle those proposals with a targeted exception, but the on-chain proving allowlists still need to trust the corresponding new prover identifiers:

- new RISC0/SP1 image/program IDs on the Shasta verifiers
- new SGX `MR_ENCLAVE` hashes on the existing SGX attesters

This proposal keeps scope intentionally narrow:

1. Shasta verifiers only
2. Additive registration only
3. Emergency governance path only

We are **not** revoking the IDs added in `Proposal0009` in this emergency change. A later cleanup proposal can remove superseded IDs once the new prover release is fully exercised.

## Technical Specification

### Verifier Targets

| Constant                | Value                                        |
| ----------------------- | -------------------------------------------- |
| `RISC0_SHASTA_VERIFIER` | `0x059dAF31F571da48Ab4e74Ae12F64f907681Cd8b` |
| `SP1_SHASTA_VERIFIER`   | `0x96337327648dcFA22b014009cf10A2D5E2F305f6` |
| `SGXRETH_ATTESTER`      | `0x8d7C954960a36a7596d7eA4945dDf891967ca8A3` |
| `SGXGETH_ATTESTER`      | `0x0ffa4A625ED9DB32B70F99180FD00759fc3e9261` |

### Prover / attester IDs (from hotfix build logs)

These values are set in [`Proposal0010.s.sol`](./Proposal0010.s.sol).

| Constant                                         | Value (hex `bytes32`)                                                                                 |
| ------------------------------------------------ | ----------------------------------------------------------------------------------------------------- |
| `RISC0_BATCH_IMAGE_ID`                           | `0x46efe5e0c74976548ee6856789fbfb4929b8f2f9118a119c57ced6e1062e727b` (`boundless-batch`)              |
| `RISC0_SHASTA_AGGREGATION_IMAGE_ID`              | `0xdfbce2039ad8b78b236b5a9dceba5d8cee0d9e4638fc8f1fe11a0b2d8bfa039e` (`boundless-shasta-aggregation`) |
| `SP1_BATCH_PROGRAM_VKEY_BN256`                   | `0x0079682c7b5af614273de79761aaad20d1c8e1a65091388b81be836632d382f8`                                  |
| `SP1_BATCH_PROGRAM_VKEY_HASH_BYTES`              | `0x3cb4163d56bd850967bcf2ec1aaad20d0e470d324244e22e037d06cc32d382f8`                                  |
| `SP1_SHASTA_AGGREGATION_PROGRAM_VKEY_BN256`      | `0x0002ac747570512099ca19c17f5a3b9f39697e5617a19ff2f2b2464229a50c7c`                                  |
| `SP1_SHASTA_AGGREGATION_PROGRAM_VKEY_HASH_BYTES` | `0x01563a3a5c1448263943382f75a3b9f34b4bf2b05e867fcb65648c8429a50c7c`                                  |
| `SGXRETH_MR_ENCLAVE_NON_EDMM`                    | `0x8f73135b83a84126c7fff37ea02f9363e134aea0f6446b13e198b20d94e75099`                                  |
| `SGXRETH_MR_ENCLAVE_EDMM`                        | `0x72258d3cae0e9901d0efc1f630064f1c44f11950bd25fee0b62ec8df84532da2`                                  |
| `SGXGETH_MR_ENCLAVE_NON_EDMM`                    | `0x398be8424f27802b38e6e8d3413bf6a0b187349e68522a218f5bfc00279006ac` (gaiko non-EDMM)                 |

**Notes**

### L1 Actions (9 total)

1. Call `setImageIdTrusted(RISC0_BATCH_IMAGE_ID, true)` on `RISC0_SHASTA_VERIFIER`.
2. Call `setImageIdTrusted(RISC0_SHASTA_AGGREGATION_IMAGE_ID, true)` on `RISC0_SHASTA_VERIFIER`.
3. Call `setProgramTrusted(SP1_BATCH_PROGRAM_VKEY_BN256, true)` on `SP1_SHASTA_VERIFIER`.
4. Call `setProgramTrusted(SP1_BATCH_PROGRAM_VKEY_HASH_BYTES, true)` on `SP1_SHASTA_VERIFIER`.
5. Call `setProgramTrusted(SP1_SHASTA_AGGREGATION_PROGRAM_VKEY_BN256, true)` on `SP1_SHASTA_VERIFIER`.
6. Call `setProgramTrusted(SP1_SHASTA_AGGREGATION_PROGRAM_VKEY_HASH_BYTES, true)` on `SP1_SHASTA_VERIFIER`.
7. Call `setMrEnclave(SGXRETH_MR_ENCLAVE_NON_EDMM, true)` on `SGXRETH_ATTESTER`.
8. Call `setMrEnclave(SGXRETH_MR_ENCLAVE_EDMM, true)` on `SGXRETH_ATTESTER`.
9. Call `setMrEnclave(SGXGETH_MR_ENCLAVE_NON_EDMM, true)` on `SGXGETH_ATTESTER`.

There are no L2 actions in this proposal.

## Verification

1. Check out Raiko branch **`hotfix/hotfix-based-on-1.16.1`** (this emergency hotfix is **not** published from a release tag).
2. From that tree, run the usual image build — typically `./script/publish-image.sh`. Some setups use `./script/publish-image.sh 0` or `1` for non-EDMM vs EDMM SGX builds; follow docs on that branch if they differ.
3. In the build log, find and compare:
   - **RISC0**: `risc0 elf image id:` (for `boundless-batch` and `boundless-shasta-aggregation`)
   - **SP1**: `sp1 elf vk bn256 is:` and `sp1 elf vk hash_bytes is:` for **`sp1-batch`** and **`sp1-shasta-aggregation`** (ignore `sp1-aggregation` for this proposal)
   - **SGX**: `mr_enclave:` for the raiko / gaiko images you ship

Match those strings to the **Prover / attester IDs** table above. Example log shapes (from a normal release build): [Proposal0004 — Verification Procedures](./Proposal0004.md#verification-procedures).

## Security Contacts

- security@taiko.xyz
