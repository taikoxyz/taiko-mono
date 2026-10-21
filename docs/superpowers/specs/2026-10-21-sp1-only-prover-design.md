# SP1-only ZK proving in taiko-client

Date: 2026-10-21

## Intent

The operator expects Boundless ZK proving to stop on November 5 (see the [announcement supplied for this work](https://boundlessfdn.org/blog/zkc-the-ai-access-coin/)). The taiko-client prover must stop requesting RISC0 proofs and use its existing SP1 path for every ZK proof. Open the implementation as a draft pull request for review.

## Desired behavior

- The default prover requests an SP1 primary proof from Raiko and an SGX_GETH companion proof, aggregates both, and submits the existing ordered `[SGX_GETH, SP1]` pair.
- `--prover.sgxRethCompanionProof` continues to choose SGX_RETH as the companion, yielding `[SGX_RETH, SP1]`. Its current incompatibility with `--prover.forceSGXProof` remains.
- The separate `--prover.forceSGXProof` mode retains its existing SGX behavior; this work does not change the protocol verifier's acceptance rules. Operators still need a verifier that accepts that mode.
- Preserve the existing SP1 Raiko request and aggregation format, including the allowed empty individual SP1 proof response before aggregation. Preserve proof buffering, caching, polling, retries, proposal window checks, and transaction encoding where they are independent of RISC0.
- No runtime path may request, aggregate, retry, or submit a RISC0 proof. Remove the RISC0 proof type from the prover implementation, as well as the RISC0 verifier ID map entry, backlog control calls, fallback state, and RISC0-specific metrics.

## CLI and migration

Remove `--prover.maxRisc0ProofProposalDistance`, `--prover.forceSP1Proof`, and `--prover.sp1ProofPercentage` and their environment variables. SP1 is unconditional in the ZK path, so these controls have no remaining purpose. Remove `--prover.zkOnlyProofs` and its environment variable as agreed: that mode submits `[RISC0, SP1]`, and the current `ZkRequiredVerifier` requires two distinct sub-proofs, so a lone SP1 proof cannot replace it. Update help text and README with the new default and a concise operator migration note listing the removed flags. An old command line with a removed flag fails at startup rather than silently selecting a different proof path; environment variables for removed flags no longer configure the client.

## Code scope

Update the taiko-client prover, its CLI flag definitions, prover metrics, tests, README, and release note as appropriate. Delete code and tests dedicated exclusively to RISC0 selection, percentage sharing, backlog clearing, and ZK-only pairing. Adapt mixed-mode tests to assert the remaining SP1 and SGX modes, companion selection, and correct sub-proof order. Keep generic producer and transaction abstractions when they still serve SP1 or SGX.

Do not rewrite protocol contracts or generated contract bindings: the deployed contracts may still expose the historical RISC0 verifier, and changing their ABI is a separate protocol change. Do not edit historical CHANGELOG entries. Other packages are outside this PR unless compilation reveals a direct dependency on a removed taiko-client symbol.

## Verification and delivery

Run relevant Go unit tests and a taiko-client build. Verify by source search that no active non-generated taiko-client prover code, CLI help, metrics, or current README documentation retains a RISC0/Boundless path. Inspect the draft PR diff for accidental protocol or generated-binding changes. The draft PR description should state the November 5 motivation, the removed flags and `zkOnlyProofs` mode, the preserved SP1 plus SGX pairings, test results, and any test environment limitation.

## Builder decisions

Choose the smallest clear refactor of submitter construction and proof aggregation. Keep or simplify generic helpers according to their remaining use. Update tests with meaningful coverage of proof type selection and pair formation rather than preserving tests of deleted behavior.
