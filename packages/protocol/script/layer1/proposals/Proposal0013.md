# PROPOSAL-0013: Register raiko2 v0.1.0 Shasta ZK Verifier IDs

## Executive Summary

This proposal registers the `raiko2` `v0.1.0` Shasta ZK verifier digests on taiko mainnet through
the standard DAO path.

It executes **6 L1 actions** from the DAO Controller and **no L2 actions**:

1. Register **2 RISC0 image IDs** on the Shasta RISC0 verifier.
2. Register **4 SP1 program digests** on the Shasta SP1 verifier.

This proposal is **additive only**. It does **not** upgrade protocol contracts, does **not** touch
L2, and does **not** update SGX attesters.

The source release is `raiko2` tag [`v0.1.0`](https://github.com/taikoxyz/raiko2/tree/v0.1.0),
tagged from commit `a3fb34237daeddab65b965c33b2f85570dd3ff74`. That release aligned chain specs for
mainnet readiness and refreshed the checked-in Shasta guest ELFs used to derive the verifier
digests below.

## Rationale

`raiko2` exports the Shasta verifier digests directly from the checked-in guest ELFs via the
offline `guest-digests` flow. Those digests are the values that the on-chain Shasta verifiers must
trust before they can accept proofs produced from the `v0.1.0` release artifacts.

This proposal keeps the scope intentionally narrow:

1. Shasta verifiers only.
2. Additive registration only.
3. No protocol implementation upgrades.
4. No SGX `MR_ENCLAVE` changes.

## Technical Specification

### Verifier Targets

| Constant                | Value                                        |
| ----------------------- | -------------------------------------------- |
| `RISC0_SHASTA_VERIFIER` | `0x059dAF31F571da48Ab4e74Ae12F64f907681Cd8b` |
| `SP1_SHASTA_VERIFIER`   | `0x96337327648dcFA22b014009cf10A2D5E2F305f6` |

### Guest Digests (`raiko2` `v0.1.0`)

These values are set in [`Proposal0013.s.sol`](./Proposal0013.s.sol).

| Constant                                         | Value (hex `bytes32`)                                                |
| ------------------------------------------------ | -------------------------------------------------------------------- |
| `RISC0_SHASTA_PROPOSAL_IMAGE_ID`                 | `0xbee1be4cbe2bdf9b0034a1ab6572061a76019e73189ff96322e58ab229b75f92` |
| `RISC0_SHASTA_BOUNDLESS_AGGREGATION_IMAGE_ID`    | `0xcecc85819e15d173c2991577727525b136e820728f7aaaede612f1281cac2249` |
| `SP1_SHASTA_PROPOSAL_PROGRAM_VKEY_BN254`         | `0x0033e2cccc3296e7def7b381a4fb96fafec64f45420b6d24686779ef6236dff1` |
| `SP1_SHASTA_PROPOSAL_PROGRAM_VKEY_HASH_BYTES`    | `0x19f166660ca5b9f75ef670344fb96faf76327a2a082db49150cef3de6236dff1` |
| `SP1_SHASTA_AGGREGATION_PROGRAM_VKEY_BN254`      | `0x009d26a03d10b4e70eef6a339187c258a7701d6a0150524684cb46b56cf9e540` |
| `SP1_SHASTA_AGGREGATION_PROGRAM_VKEY_HASH_BYTES` | `0x4e93501e442d39c35ded4672187c258a3b80eb500541491a09968d6a6cf9e540` |

### L1 Actions (6 total)

1. Call `setImageIdTrusted(RISC0_SHASTA_PROPOSAL_IMAGE_ID, true)` on `RISC0_SHASTA_VERIFIER`.
2. Call `setImageIdTrusted(RISC0_SHASTA_BOUNDLESS_AGGREGATION_IMAGE_ID, true)` on `RISC0_SHASTA_VERIFIER`.
3. Call `setProgramTrusted(SP1_SHASTA_PROPOSAL_PROGRAM_VKEY_BN254, true)` on `SP1_SHASTA_VERIFIER`.
4. Call `setProgramTrusted(SP1_SHASTA_PROPOSAL_PROGRAM_VKEY_HASH_BYTES, true)` on `SP1_SHASTA_VERIFIER`.
5. Call `setProgramTrusted(SP1_SHASTA_AGGREGATION_PROGRAM_VKEY_BN254, true)` on `SP1_SHASTA_VERIFIER`.
6. Call `setProgramTrusted(SP1_SHASTA_AGGREGATION_PROGRAM_VKEY_HASH_BYTES, true)` on `SP1_SHASTA_VERIFIER`.

There are no L2 actions in this proposal.

## Verification

### Digest Verification

1. Check out `raiko2` tag `v0.1.0`.
2. Export guest digests from the checked-in Shasta guest ELFs:

   ```bash
   cargo run -p xtask-build-guest --bin guest-digests -- \
     --output /tmp/raiko2-v0.1.0-guest-digests.json
   ```

3. Confirm the JSON contains these entries:
   - `risc0_shasta_proposal` `image_id`
   - `risc0_shasta_boundless_aggregation` `image_id`
   - `sp1_shasta_proposal` `vk_bn254`
   - `sp1_shasta_proposal` `vk_hash_bytes`
   - `sp1_shasta_aggregation` `vk_bn254`
   - `sp1_shasta_aggregation` `vk_hash_bytes`
4. Match those 6 digests to the **Guest Digests** table above.

### Proposal Verification

Before submission:

1. Generate proposal calldata:

   ```bash
   P=0013 pnpm proposal
   ```

2. Dryrun on L1:

   ```bash
   P=0013 pnpm proposal:dryrun:l1
   ```

After execution, confirm the verifier readbacks return `true`:

```bash
cast call 0x059dAF31F571da48Ab4e74Ae12F64f907681Cd8b \
  "isImageTrusted(bytes32)(bool)" \
  0xbee1be4cbe2bdf9b0034a1ab6572061a76019e73189ff96322e58ab229b75f92 \
  --rpc-url <RPC_URL>

cast call 0x96337327648dcFA22b014009cf10A2D5E2F305f6 \
  "isProgramTrusted(bytes32)(bool)" \
  0x0033e2cccc3296e7def7b381a4fb96fafec64f45420b6d24686779ef6236dff1 \
  --rpc-url <RPC_URL>
```

Repeat the same readback for the remaining registered digests.

## References

- [`raiko2` tag `v0.1.0`](https://github.com/taikoxyz/raiko2/tree/v0.1.0)
- [`raiko2` PR #43: `fix(config): align chain specs for mainnet readiness`](https://github.com/taikoxyz/raiko2/pull/43)
- [`raiko2` release operations guide](https://github.com/taikoxyz/raiko2/blob/v0.1.0/docs/operations.md#source-releases)

## Security Contacts

- security@taiko.xyz
