# taiko-client

[![CI](https://github.com/taikoxyz/taiko-mono/actions/workflows/taiko-client--test.yml/badge.svg)](https://github.com/taikoxyz/taiko-mono/actions/workflows/taiko-client--test.yml)

[![Codecov](https://codecov.io/gh/taikoxyz/taiko-mono/graph/badge.svg?&token=E468X2PTJC&flag=taiko-client)](https://codecov.io/gh/taikoxyz/taiko-mono/packages/taiko-client)

Taiko Alethia protocol's client software implementation in Go. Learn more about Taiko Alethia nodes with [the docs](https://docs.taiko.xyz/guides/run-a-node).

## Project structure

| Path                  | Description                                                                                                                                                   |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `bindings/`           | [Go contract bindings](https://geth.ethereum.org/docs/developers/dapp-developer/native-bindings) for Taiko smart contracts, and few related utility functions |
| `cmd/`                | Main executable for this project                                                                                                                              |
| `docs/`               | Documentation                                                                                                                                                 |
| `driver/`             | Driver sub-command                                                                                                                                            |
| `integration_test/`   | Scripts to do the integration testing of all client software                                                                                                  |
| `internal/metrics/`   | Metrics related                                                                                                                                               |
| `pkg/`                | Library code which used by all sub-commands                                                                                                                   |
| `proposer/`           | Proposer sub-command                                                                                                                                          |
| `prover/`             | Prover sub-command                                                                                                                                            |
| `scripts/`            | Helpful scripts                                                                                                                                               |
| `internal/testutils/` | Test utils                                                                                                                                                    |
| `internal/version/`   | Version information                                                                                                                                           |

## Build the source

Building the `taiko-client` binary requires a Go compiler. Once installed, run:

```sh
make build
```

## Usage

Review all available sub-commands:

```sh
bin/taiko-client --help
```

Review each sub-command's command line flags:

```sh
bin/taiko-client <sub-command> --help
```

### RISC0 proofs and SP1 fallback

After the Shasta fork, the prover proves every proposal with SP1 by default:
`--prover.maxRisc0ProofProposalDistance` defaults to `0`, so it never requests
RISC0 proofs or calls the Raiko RISC0 backlog endpoints.

To enable RISC0, set the distance to `N > 0`. The prover then requests RISC0
proofs while `proposalID <= lastFinalizedProposalID + N`. Beyond that it falls
back to SP1, clears the Raiko RISC0 backlog (`POST /v4/prover/clear`), and
resumes RISC0 once finalization has caught up with the proposals it proved with
SP1 and `GET /v4/prover/status?proof_type=risc0` reports clean (if that request
fails, the finalization check alone decides). Set a distance only when the
configured Raiko host serves `risc0` proofs.

`--prover.sp1ProofPercentage X` proves the first `X` of every 100 proposals
(`proposalID % 100 < X`) with SP1 and the rest through the RISC0 flow above, so
it only matters with a positive distance. For `0 < X < 100`, both `X` and
`100 - X` must be multiples of `--prover.zkvm.batchSize`.

`--prover.forceSP1Proof` always requests SP1, ignoring the distance and the SP1
share. `--prover.zkOnlyProofs` proves every proposal with both RISC0 and SP1 and
submits `[RISC0, SP1]`; it needs a Raiko host that serves `risc0` proofs and
`ZkRequiredVerifier` as the inbox's proof verifier.

| Flag                                     | Environment variable                       | Default |
| ---------------------------------------- | ------------------------------------------ | ------- |
| `--prover.maxRisc0ProofProposalDistance` | `PROVER_MAX_RISC0_PROOF_PROPOSAL_DISTANCE` | `0`     |
| `--prover.sp1ProofPercentage`            | `PROVER_SP1_PROOF_PERCENTAGE`              | `0`     |
| `--prover.forceSP1Proof`                 | `PROVER_FORCE_SP1_PROOF`                   | `false` |
| `--prover.zkOnlyProofs`                  | `PROVER_ZK_ONLY_PROOFS`                    | `false` |

### SGX_RETH companion proofs

After the Shasta fork, enable `--prover.sgxRethCompanionProof` when the prover
should pair each RISC0 or SP1 proof with SGX_RETH instead of SGX_GETH. The flag
defaults to `false`, preserving the SGX_GETH companion, and keeps the existing
RISC0/SP1 selection and fallback behavior.

Add `--prover.sgxRethCompanionProof` to your existing prover command, keeping all
required connection, contract, and signing options. Alternatively, enable it in
the prover's environment:

```sh
export PROVER_SGX_RETH_COMPANION_PROOF=true
```

Before enabling this mode, ensure that the configured Raiko host serves `sgx`
(SGX_RETH) proofs, including aggregation, and that its SGX signer has a valid
registered instance in the SGX_RETH verifier. The inbox's proof verifier must
accept both `[SGX_RETH, RISC0]` and `[SGX_RETH, SP1]`; `MainnetVerifier` and
`ZkRequiredVerifier` support these pairs. Submissions revert if the configured
verifier does not accept the selected pair.

Do not combine this flag with `--prover.forceSGXProof`: startup rejects that
combination. With `--prover.zkOnlyProofs`, the companion flag is ignored and the
prover still submits `[RISC0, SP1]`.

## L1 beacon node requirements

The driver reads each proposal's blobs from the L1 beacon node set by `--l1.beacon`, through `GET /eth/v1/beacon/blobs/{block_id}?versioned_hashes=...`, and checks every blob against its versioned hash. On Prysm, use v7.1.8 or later: v6.1.0 to v7.1.7 drop the connection when a requested blob appears twice in its block ([OffchainLabs/prysm#17199](https://github.com/OffchainLabs/prysm/pull/17199)), and the driver then needs the blob server set by `--blob.server`.

Since Fulu (PeerDAS), a beacon node keeps only the data columns it custodies, so only a **supernode** (custodies every column) or a **semi-supernode** (custodies half of them, enough to reconstruct every blob) can serve full blobs. Point `--l1.beacon` at such a node, or set `--blob.server` to another blob source: when the beacon node cannot return a blob, the driver asks the blob server, and without one derivation stalls until the blob is available.

Beacon nodes also prune blobs after 4096 epochs (about 18 days), so syncing older proposals needs `--blob.server` as well.

## Testing

Ensure you have Docker running, and pnpm installed.

Then, run the integration tests:

1. Start Docker locally
2. Perform a `pnpm install` in `taiko-mono/packages/protocol`
3. Execute:

```sh
make test
```
