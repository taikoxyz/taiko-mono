# PROPOSAL-0010: Emergency Registration of Additional Shasta Verifier IDs

## Executive Summary

This proposal is an **emergency proposal** intended for the **Emergency Multisig** path, not the Standard Multisig path.

It additively registers a new set of RISC0/SP1 verifier IDs on the **Shasta verifiers only** on taiko mainnet, and additively registers new SGX `MR_ENCLAVE` hashes on the existing SGX attesters. The previously trusted values from [`Proposal0009.s.sol`](./Proposal0009.s.sol) remain enabled for now.

The goal is to unblock proving and finalization for the earliest Shasta mainnet proposals affected by the bootstrapping issue where the first 7 proposals had reverted anchor transactions.

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

### Placeholder IDs To Fill

Replace the placeholder constants in [`Proposal0010.s.sol`](./Proposal0010.s.sol) before generating calldata or running dryruns:

| Constant                                         | Current placeholder        |
| ------------------------------------------------ | -------------------------- |
| `RISC0_BATCH_IMAGE_ID`                           | `bytes32(uint256(0x1001))` |
| `RISC0_SHASTA_AGGREGATION_IMAGE_ID`              | `bytes32(uint256(0x1002))` |
| `SP1_BATCH_PROGRAM_VKEY_BN256`                   | `bytes32(uint256(0x2001))` |
| `SP1_BATCH_PROGRAM_VKEY_HASH_BYTES`              | `bytes32(uint256(0x2002))` |
| `SP1_SHASTA_AGGREGATION_PROGRAM_VKEY_BN256`      | `bytes32(uint256(0x2003))` |
| `SP1_SHASTA_AGGREGATION_PROGRAM_VKEY_HASH_BYTES` | `bytes32(uint256(0x2004))` |
| `SGXRETH_MR_ENCLAVE_NON_EDMM`                    | `bytes32(uint256(0x3001))` |
| `SGXRETH_MR_ENCLAVE_EDMM`                        | `bytes32(uint256(0x3002))` |
| `SGXGETH_MR_ENCLAVE_NON_EDMM`                    | `bytes32(uint256(0x3003))` |

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

1. Confirm each new RISC0 image ID is trusted:

   ```bash
   cast call 0x059dAF31F571da48Ab4e74Ae12F64f907681Cd8b "isImageTrusted(bytes32)(bool)" <IMAGE_ID> --rpc-url <ETHEREUM_RPC>
   ```

2. Confirm each new SP1 program ID is trusted:

   ```bash
   cast call 0x96337327648dcFA22b014009cf10A2D5E2F305f6 "isProgramTrusted(bytes32)(bool)" <PROGRAM_ID> --rpc-url <ETHEREUM_RPC>
   ```

3. Confirm each new SGX `MR_ENCLAVE` is trusted:

   ```bash
   cast call 0x8d7C954960a36a7596d7eA4945dDf891967ca8A3 "trustedUserMrEnclave(bytes32)(bool)" <MR_ENCLAVE> --rpc-url <ETHEREUM_RPC>
   cast call 0x0ffa4A625ED9DB32B70F99180FD00759fc3e9261 "trustedUserMrEnclave(bytes32)(bool)" <MR_ENCLAVE> --rpc-url <ETHEREUM_RPC>
   ```

4. Confirm the older `Proposal0009` IDs and `MR_ENCLAVE` hashes remain trusted unless and until a later cleanup proposal removes them.

## Security Contacts

- security@taiko.xyz
