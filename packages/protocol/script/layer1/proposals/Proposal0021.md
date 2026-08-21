# PROPOSAL-0021: Rotate raiko2 Proving IDs to v0.8.0-rc1

## Executive Summary

This proposal rotates the trusted proving identifiers from the raiko2 v0.6.0 set enabled by
[`Proposal0019.s.sol`](./Proposal0019.s.sol) to the
[`raiko2 v0.8.0-rc1`](https://github.com/taikoxyz/raiko2/releases/tag/v0.8.0-rc1)
release set.

The main motivation for this release is the RISC0/Boundless path: raiko2 v0.8.0-rc1 includes
[`perf(guest): reduce zkVM crypto setup cycles`](https://github.com/taikoxyz/raiko2/commit/8b2147a0e74ba6387938cf35544797fb1b61cc07),
which updates the guest crypto dependency graph and regenerates the RISC0 proposal and aggregation
artifacts. Because those guest and build changes are shared by the raiko2 proving codebase, the same
release also produces new SP1 artifacts and new TEE enclave measurements. This proposal therefore
aligns all proving lanes to the same v0.8.0-rc1 artifact set instead of mixing RISC0 from v0.8.0-rc1
with SP1 and TEE artifacts from v0.6.0.

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

After actions 19-20 execute, both SGX verifier registries are intentionally empty until the new
v0.8.0-rc1 enclaves register fresh instances under the rotated MRENCLAVE allowlist. This mirrors
the Proposal0019 delete-then-reregister sequence. In the interim, proving can continue through the
`RISC0 + SP1` combination accepted by the active `ZkRequiredVerifier`.

## raiko2 v0.8.0-rc1 Release Artifacts

The ZK and TEE identifiers in [`Proposal0021.s.sol`](./Proposal0021.s.sol) come from
[`raiko2 v0.8.0-rc1`](https://github.com/taikoxyz/raiko2/releases/tag/v0.8.0-rc1), commit
`8b2147a0e74ba6387938cf35544797fb1b61cc07`.

| Artifact                 | Value                                                                                                                      |
| ------------------------ | -------------------------------------------------------------------------------------------------------------------------- |
| Runtime image            | `us-docker.pkg.dev/evmchain/images/raiko2@sha256:41fbcaaf8bbf0e18087e59ebaec6701e0f345017c98a42e7d4878a517bc525c0`         |
| `raiko2-sgx` image       | `us-docker.pkg.dev/evmchain/images/raiko2-sgx@sha256:d6d533a41ce91b72411e67668f2fd52ca28c783871a58580a3bccc95ef6579db`     |
| `raiko2-sgx-edmm` image  | `us-docker.pkg.dev/evmchain/images/raiko2-sgx@sha256:ed863323daa73f942c3662e46e513cc64dcb3a10d1243d03f19b2d33f29ad48b`     |
| `gaiko2-sgxgeth` image   | `us-docker.pkg.dev/evmchain/images/gaiko2-sgxgeth@sha256:5365edef438602446dbac09cc388a22ed43c8a7c0d53bae79ec33a9e36ed4863` |
| `gaiko2` source commit   | `f866bb22916559243ec2161f5e36d6b729434066`                                                                                 |
| Release manifest         | `release-manifest-v0.8.0-rc1.json`                                                                                         |
| ZK digest summary        | `guest-digests-summary.json`                                                                                               |
| TEE attestation manifest | `tee-attestation-manifest-v0.8.0-rc1.json`                                                                                 |

Reproduce the ZK guest digests from the release checkout. `guest-digests` reads the checked-in
ELF/VK artifacts under `crates/guests/elf`; run the guest build first when the goal is to verify
those artifacts from source rather than only re-hash the release checkout:

```bash
export TAG=v0.8.0-rc1
export REPRO_DIR=target/releases/${TAG}/zk-digest-repro

git fetch --tags origin "${TAG}"
git checkout "${TAG}"
mkdir -p "${REPRO_DIR}"

just build-guest all --force

cargo run -r -p xtask-build-guest --bin guest-digests --features digests -- \
  --output "${REPRO_DIR}/from-source.json"

gh release download "${TAG}" --repo taikoxyz/raiko2 \
  --pattern guest-digests-summary.json \
  --dir "${REPRO_DIR}" \
  --clobber

jq -S '.digests | sort_by(.proof_system, .object_name, .stage, .digest_source)' \
  "${REPRO_DIR}/guest-digests-summary.json" > "${REPRO_DIR}/release-digests.sorted.json"
jq -S '.digests | sort_by(.proof_system, .object_name, .stage, .digest_source)' \
  "${REPRO_DIR}/from-source.json" > "${REPRO_DIR}/source-digests.sorted.json"
diff -u "${REPRO_DIR}/release-digests.sorted.json" "${REPRO_DIR}/source-digests.sorted.json"
```

Do not compare the whole `guest-digests-summary.json` file directly: `created_at_unix` is generated
per run. The canonical comparison is the sorted `.digests` projection above.

Reproduce the TEE provider metadata from the release checkout. Official reproduction requires the
release enclave signing key; a disposable local key can reproduce `mr_enclave`, but produces a
different `mr_signer`.

```bash
export TAG=v0.8.0-rc1
export REPRO_DIR=target/releases/${TAG}/tee-provider-repro

git fetch --tags origin "${TAG}"
git checkout "${TAG}"

GCP_ENCLAVE_KEY_SECRET=<secret-name> \
GCP_ENCLAVE_KEY_VERSION=<secret-version> \
GCP_ENCLAVE_KEY_PROJECT=<gcp-project> \
cargo run -r -p xtask -- release-tee-providers --tag "${TAG}" --no-push

mkdir -p "${REPRO_DIR}"
cp "target/releases/${TAG}/tee-attestation-manifest-${TAG}.json" \
  "${REPRO_DIR}/from-source.json"

gh release download "${TAG}" --repo taikoxyz/raiko2 \
  --pattern "tee-attestation-manifest-${TAG}.json" \
  --dir "${REPRO_DIR}" \
  --clobber

jq -S '[.providers[]
  | {lane, provider, source, attestation}]
  | sort_by(.lane, .provider)' \
  "${REPRO_DIR}/tee-attestation-manifest-${TAG}.json" > "${REPRO_DIR}/release-tee.sorted.json"
jq -S '[.providers[]
  | {lane, provider, source, attestation}]
  | sort_by(.lane, .provider)' \
  "${REPRO_DIR}/from-source.json" > "${REPRO_DIR}/source-tee.sorted.json"
diff -u "${REPRO_DIR}/release-tee.sorted.json" "${REPRO_DIR}/source-tee.sorted.json"
```

Do not compare the whole TEE manifest directly: `generated_at` is generated per run. With the
official signing key, compare the sorted `{ lane, provider, source, attestation }` projection above.
With a disposable local key, compare the same projection without `attestation.mr_signer`, because
the signer key intentionally changes. `release-tee-providers --no-push` is metadata-only; verify the
published immutable image digests in the artifact table separately against the registry:

```bash
docker buildx imagetools inspect us-docker.pkg.dev/evmchain/images/raiko2:v0.8.0-rc1
docker buildx imagetools inspect us-docker.pkg.dev/evmchain/images/raiko2-sgx:v0.8.0-rc1
docker buildx imagetools inspect us-docker.pkg.dev/evmchain/images/raiko2-sgx:v0.8.0-rc1-edmm
docker buildx imagetools inspect us-docker.pkg.dev/evmchain/images/gaiko2-sgxgeth:v0.8.0-rc1
```

Each reported digest must match the corresponding immutable `@sha256:...` reference in the
artifact table.

## Action Order

1. `RISC0_RETH_VERIFIER.setImageIdTrusted(OLD_RISC0_PROPOSAL_IMAGE_ID, false)`
2. `RISC0_RETH_VERIFIER.setImageIdTrusted(OLD_RISC0_AGGREGATION_IMAGE_ID, false)`
3. `RISC0_RETH_VERIFIER.setImageIdTrusted(NEW_RISC0_PROPOSAL_IMAGE_ID, true)`
4. `RISC0_RETH_VERIFIER.setImageIdTrusted(NEW_RISC0_AGGREGATION_IMAGE_ID, true)`
5. `SP1_RETH_VERIFIER.setProgramTrusted(OLD_SP1_PROPOSAL_PROGRAM_VKEY_BN254, false)`
6. `SP1_RETH_VERIFIER.setProgramTrusted(OLD_SP1_PROPOSAL_PROGRAM_VKEY_HASH_BYTES, false)`
7. `SP1_RETH_VERIFIER.setProgramTrusted(OLD_SP1_AGGREGATION_PROGRAM_VKEY_BN254, false)`
8. `SP1_RETH_VERIFIER.setProgramTrusted(OLD_SP1_AGGREGATION_PROGRAM_VKEY_HASH_BYTES, false)`
9. `SP1_RETH_VERIFIER.setProgramTrusted(NEW_SP1_PROPOSAL_PROGRAM_VKEY_BN254, true)`
10. `SP1_RETH_VERIFIER.setProgramTrusted(NEW_SP1_PROPOSAL_PROGRAM_VKEY_HASH_BYTES, true)`
11. `SP1_RETH_VERIFIER.setProgramTrusted(NEW_SP1_AGGREGATION_PROGRAM_VKEY_BN254, true)`
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

Before submission, confirm the current mainnet preconditions. The old values must return `true`,
the new values must return `false`, and both SGX verifiers must still have ID `1` registered:

```bash
export RPC_URL=<RPC_URL>

# Old RISC0 IDs: must return true before execution.
cast call 0x059dAF31F571da48Ab4e74Ae12F64f907681Cd8b \
  "isImageTrusted(bytes32)(bool)" \
  0x5a818b4c7dc80e9ba85d55492c20c263c67238724e3982f76d15a158e501210b \
  --rpc-url "${RPC_URL}"
cast call 0x059dAF31F571da48Ab4e74Ae12F64f907681Cd8b \
  "isImageTrusted(bytes32)(bool)" \
  0x9cfcc1b34a98853c3c5873a4d456726e528246f7f03a4ea35f27c2543aa6e7f0 \
  --rpc-url "${RPC_URL}"

# New RISC0 IDs: must return false before execution.
cast call 0x059dAF31F571da48Ab4e74Ae12F64f907681Cd8b \
  "isImageTrusted(bytes32)(bool)" \
  0xd6ab71c22201c23ef512b706f2e2d720f6da1b559fb76834aa9d4e35276f6e10 \
  --rpc-url "${RPC_URL}"
cast call 0x059dAF31F571da48Ab4e74Ae12F64f907681Cd8b \
  "isImageTrusted(bytes32)(bool)" \
  0xdd9b8abff96c409ae2418edfb51d893ea2bd10f4873a0226f17a6998c1afc1b7 \
  --rpc-url "${RPC_URL}"

# Old SP1 IDs: must return true before execution.
cast call 0x73A0Db393ef87ce781ac7957bE10D6628432100F \
  "isProgramTrusted(bytes32)(bool)" \
  0x00ad090221a8fa0f09e1be7a53feb67be010f01310d4b2314a69d10152ee1ce0 \
  --rpc-url "${RPC_URL}"
cast call 0x73A0Db393ef87ce781ac7957bE10D6628432100F \
  "isProgramTrusted(bytes32)(bool)" \
  0x568481106a3e83c23c37cf4a3feb67be008780984352c8c514d3a20252ee1ce0 \
  --rpc-url "${RPC_URL}"
cast call 0x73A0Db393ef87ce781ac7957bE10D6628432100F \
  "isProgramTrusted(bytes32)(bool)" \
  0x000b11691352e55fcf64f62620cefaa700161600093f2751032fe71ea912264d \
  --rpc-url "${RPC_URL}"
cast call 0x73A0Db393ef87ce781ac7957bE10D6628432100F \
  "isProgramTrusted(bytes32)(bool)" \
  0x0588b48954b957f36c9ec4c40cefaa7000b0b00024fc9d44065fce3d2912264d \
  --rpc-url "${RPC_URL}"

# New SP1 IDs: must return false before execution.
cast call 0x73A0Db393ef87ce781ac7957bE10D6628432100F \
  "isProgramTrusted(bytes32)(bool)" \
  0x0025425c22e827507428a3d9c7b0f89635be5462f34bb6780563e3d6086be7c7 \
  --rpc-url "${RPC_URL}"
cast call 0x73A0Db393ef87ce781ac7957bE10D6628432100F \
  "isProgramTrusted(bytes32)(bool)" \
  0x12a12e113a09d41d05147b387b0f89632df2a3174d2ed9e00ac7c7ac086be7c7 \
  --rpc-url "${RPC_URL}"
cast call 0x73A0Db393ef87ce781ac7957bE10D6628432100F \
  "isProgramTrusted(bytes32)(bool)" \
  0x0051ac1d9e8cfd4196e37f9cfefd08e9b0f7ce653bad4634cd1ee84b71ca3be6 \
  --rpc-url "${RPC_URL}"
cast call 0x73A0Db393ef87ce781ac7957bE10D6628432100F \
  "isProgramTrusted(bytes32)(bool)" \
  0x28d60ecf233f50655c6ff39f6fd08e9b07be73296eb518d31a3dd09671ca3be6 \
  --rpc-url "${RPC_URL}"

# Old SGX MRENCLAVEs: must return true before execution.
cast call 0x0ffa4A625ED9DB32B70F99180FD00759fc3e9261 \
  "trustedUserMrEnclave(bytes32)(bool)" \
  0x2d2216efbe9d8e80ba24b86606ccd5ce9faf11033d31ad9e5d3c5c89965c8a57 \
  --rpc-url "${RPC_URL}"
cast call 0x8d7C954960a36a7596d7eA4945dDf891967ca8A3 \
  "trustedUserMrEnclave(bytes32)(bool)" \
  0x90c79e65d6d0f83d658ff96cd0ef1204438f20b406c93cf1d4fafa0cff29842e \
  --rpc-url "${RPC_URL}"
cast call 0x8d7C954960a36a7596d7eA4945dDf891967ca8A3 \
  "trustedUserMrEnclave(bytes32)(bool)" \
  0x041cadb0541bf8249c368482172d218608f3693975b65f74beb2ed6f0044f951 \
  --rpc-url "${RPC_URL}"

# New SGX MRENCLAVEs: must return false before execution.
cast call 0x0ffa4A625ED9DB32B70F99180FD00759fc3e9261 \
  "trustedUserMrEnclave(bytes32)(bool)" \
  0x5f7da556f3b75dcc71465030e1b7274e82df9e9120c0b3eaf5bb76246a514005 \
  --rpc-url "${RPC_URL}"
cast call 0x8d7C954960a36a7596d7eA4945dDf891967ca8A3 \
  "trustedUserMrEnclave(bytes32)(bool)" \
  0x3564b6a30089fcb3e2f69c19b22d23f84ce148387cd7a15f5c1df165b2ae5847 \
  --rpc-url "${RPC_URL}"
cast call 0x8d7C954960a36a7596d7eA4945dDf891967ca8A3 \
  "trustedUserMrEnclave(bytes32)(bool)" \
  0xae2c7b92b2a71238226cb624ecd1171b66bf943cc372314affca0e6748ccecdf \
  --rpc-url "${RPC_URL}"

# Both must return 2 before execution.
cast call 0x41e79EB4F03aBB5DF8716B759528dc5d8f6a84Ee \
  "nextInstanceId()(uint256)" \
  --rpc-url "${RPC_URL}"
cast call 0x9D3C595BFf6Ff7D2b2CbdEcF94aD917eB2fCFFd8 \
  "nextInstanceId()(uint256)" \
  --rpc-url "${RPC_URL}"

# Both ID 1 registrations must be non-zero before execution.
cast call 0x41e79EB4F03aBB5DF8716B759528dc5d8f6a84Ee \
  "instances(uint256)(address,uint64)" \
  1 \
  --rpc-url "${RPC_URL}"
cast call 0x9D3C595BFf6Ff7D2b2CbdEcF94aD917eB2fCFFd8 \
  "instances(uint256)(address,uint64)" \
  1 \
  --rpc-url "${RPC_URL}"
```

Regenerate the calldata:

```bash
cd packages/protocol
P=0021 pnpm proposal
```

The generated action file should then be formatted with the repo formatter (the pre-commit hook
does this automatically), or reviewers should compare only the calldata line.

Dryrun the L1 action bundle:

```bash
cd packages/protocol
P=0021 pnpm proposal:dryrun:l1
```

After execution:

1. Confirm the old RISC0 image IDs return `false` and the new image IDs return `true`.
2. Confirm the old SP1 program vkeys return `false` and the new program vkeys return `true`.
3. Confirm the old SGX MRENCLAVEs return `false` and the new MRENCLAVEs return `true`.
4. Confirm `instances(1)` returns zero on both SGX verifiers.
5. Register the new v0.8.0-rc1 SGX instances under the rotated MRENCLAVE allowlist.
